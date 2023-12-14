import 'dart:async';
import 'dart:collection';

import 'package:retro/retro.dart';

/// A [ZipRepository] combines many repositories into one.
///
/// By convention, the first repository is the "remote" data source.
/// Any write operation will start from the 0-index repository and, if succeeds, it will advance
/// one position and do the same operation. If an operation fails in a repository, it will break
/// the execution and will not continue, by default, but it can be changed with the [breakOnFail] property.
///
/// The [update] operation is a bit different. For the first repository, it will perform the desired update
/// operation as normal, but for the subsequent repositories, it will perform a Update.write.
///
/// In the [ZipRepository], the refresh operation functions by having the last added repository pull data from its adjacent repository, if it's a [DataProvider].
/// For instance, the repository at index 4 will pull data from the repository at index 3, the repository at index 3 will pull data from the repository at index 2, and so forth.
/// If N repository can't provide data to N+1 repository, N+1 repository will try to take data from N-1 repository and then
/// hydrate itself as well as N repository.
/// The default [refreshInterval] is 5 minutes. If you don't want refreshing, set [refreshInterval] to [Duration.zero].
/// Also, if you want refresh capabilities, you must supply a [KvStore] instance. It will be used to save the date and time
/// of the last refresh. [KvStore] will use the [ZipRepository]'s name to save the data, so make sure you don't duplicate it.
class ZipRepository<T, Id> extends AsyncRepository<T, Id> implements Refreshable, Disposable {
  final List<Repository<T, Id>> _repositories;
  final KvStore? _kvStore;

  final bool breakOnFail;
  final ReadType readType;
  final Duration refreshInterval;

  Timer? _refreshTimer;
  Completer? _refreshCompleter;
  bool _canRefresh = true;
  DateTime? _lastRefresh;

  bool get isRefreshEnabled => refreshInterval != Duration.zero;
  List<Repository<T, Id>> get repositories => UnmodifiableListView(_repositories);

  ZipRepository(
      {required List<Repository<T, Id>> repositories,
      super.name = kDefaultRepositoryName,
      this.readType = ReadType.lastIn,
      this.breakOnFail = true,
      this.refreshInterval = const Duration(minutes: 5),
      KvStore? kvStore})
      : _repositories = repositories,
        _kvStore = kvStore {
    if (isRefreshEnabled) {
      assert(kvStore != null, "If you enable refresh, you must supply a KvStore.");
      _refreshTimer = Timer.periodic(refreshInterval, (timer) {
        _onRefresh();
      });
    }
  }

  @override
  Future<void> delete(Id id) async {
    for (final repo in _repositories) {
      try {
        await repo.delete(id);
      } catch (err) {
        if (breakOnFail) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<void> insert(T data) async {
    for (final repo in _repositories) {
      try {
        await repo.insert(data);
      } catch (err) {
        if (breakOnFail) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<T> update(Id id, Update<T, Id> operation) async {
    final remoteRepo = _repositories[0];
    final updatedData = await remoteRepo.update(id, operation);

    for (int i = 1; i < _repositories.length; i++) {
      final repo = _repositories[i];
      try {
        await repo.update(id, Update.write(updatedData));
      } catch (err) {
        // todo: decide what to do if it fails, maybe hydrate later
      }
    }

    return updatedData;
  }

  @override
  Future<T?> get(Id id) async {
    int start = readType == ReadType.firstIn ? 0 : _repositories.length - 1;
    int end = readType == ReadType.firstIn ? _repositories.length : -1;
    int step = readType == ReadType.firstIn ? 1 : -1;
    for (int i = start; i != end; i += step) {
      final repository = _repositories[i];
      final entry = await repository.get(id);
      if (entry != null) {
        return entry;
      }
    }

    return null;
  }

  @override
  Future<PagedResult<T>> list(Query query) async {
    int start = readType == ReadType.firstIn ? 0 : _repositories.length - 1;
    int end = readType == ReadType.firstIn ? _repositories.length : 0;
    int step = readType == ReadType.firstIn ? 1 : -1;
    for (int i = start; i < end; i += step) {
      final repository = _repositories[i];
      final resultset = await repository.list(query);
      if (resultset.isNotEmpty) {
        return resultset;
      }
    }

    return const PagedResult.empty();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _repositories.clear();
  }

  @override
  Future<void> refresh() async {
    // at least two repositories are needed
    if (_repositories.length < 2) {
      _canRefresh = false;
      return;
    }

    // try to get from kvStore
    _lastRefresh ??= _loadLastRefresh();

    // the index of the repository which will be used to pull data from
    int? pollFrom;

    // skip the first repository
    for (int i = _repositories.length - 2; i >= 0; i--) {
      final repository = _repositories[i];
      if (repository is! DataProvider<T>) {
        continue;
      }

      pollFrom = i;
      break;
    }

    if (pollFrom == null) {
      _canRefresh = false;
      return;
    }

    // poll data
    final pollRepository = _repositories[pollFrom] as DataProvider<T>;
    String? continuationToken;

    do {
      final batch = await pollRepository.poll(continuationToken: continuationToken);
      continuationToken = batch.continuationToken;
      if (batch.data.isNotEmpty) {
        final hydratableRepos = _repositories.indexed
            .where((element) => element.$1 > pollFrom! && element.$2 is Hydratable<T>);

        await Future.wait(hydratableRepos.map((e) => (e.$2 as Hydratable<T>).hydrate(batch.data)));
      }
    } while (continuationToken != null);

    // todo: if poll failed, skip the refresh. Only save lastRefreshTime if succeeded
    _lastRefresh = DateTime.now();
    await _saveLastRefresh();
  }

  Future<void> _onRefresh() async {
    // if can't refresh (because there are no DataProvider repository, stop the timer)
    if (!_canRefresh) {
      _refreshCompleter = null;
      _refreshTimer?.cancel();
      return;
    }

    // avoid running twice at the same time
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return;
    }

    _refreshCompleter = Completer();
    await refresh();
    _refreshCompleter!.complete();
  }

  @pragma("vm:prefer-inline")
  DateTime? _loadLastRefresh() {
    try {
      int? millis = _kvStore!.get('__ZipRepositorySync[$name]__');
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (_) {}

    return null;
  }

  @pragma("vm:prefer-inline")
  Future<void> _saveLastRefresh() {
    return _kvStore!.set('__ZipRepositorySync[$name]__', _lastRefresh!.millisecondsSinceEpoch);
  }
}
