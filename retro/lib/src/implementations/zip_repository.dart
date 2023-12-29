import 'dart:async';
import 'dart:collection';

import 'package:retro/retro.dart';
import 'package:retry/retry.dart';

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
///
/// On [ZipRepository], [pollRecentTransactionResults] will always throw [UnsupportedError].
abstract class ZipRepository<T, Id> extends AsyncRepository<T, Id>
    implements Refreshable, Disposable, Transactional<T, Id> {
  final List<Repository<T, dynamic>> _repositories;
  final ZipRepositoryOptions _options;

  Repository<T, dynamic>? _runningForcedOn;
  Completer? _txnCompleter;

  /// All the repositories registered in this [ZipRepository].
  ///
  /// It is not recommended to use the repositories from here, as it may cause sync problems.
  List<Repository<T, dynamic>> get repositories =>
      UnmodifiableListView(_repositories);

  ZipRepository._internal(this._repositories, this._options, String? name)
      : super(name: name);

  /// Creates a new [ZipRepository].
  factory ZipRepository(
      {required List<Repository<T, Id>> repositories,
      ZipRepositoryOptions options}) = _ZipRepositoryImpl;

  /// Creates a new [DynamicIdZipRepository]
  factory ZipRepository.dynamic(
      {required List<IdTransformer<T, Id>> repositories,
      ZipRepositoryOptions options,
      String? name}) = DynamicIdZipRepository;

  /// Forces the desired [callback] to run only in the specified repository's [repositoryIndex].
  Future<R> forceRunOn<R>(int repositoryIndex,
      FutureOr<R> Function(ZipRepository<T, Id> repository) callback) async {
    try {
      _runningForcedOn = _repositories[repositoryIndex];
    } catch (_) {
      throw Exception("There is no repository at index $repositoryIndex");
    }

    R result = await callback(this);
    _runningForcedOn = null;
    return result;
  }

  @override
  Future<K> runTransaction<K>(
      FutureOr<K> Function(RepositoryTransaction<T, Id> transaction)
          callback) async {
    if (_txnCompleter != null) {
      await _txnCompleter!.future;
    }

    _txnCompleter = Completer();

    K? result;
    int? repositoryIndex;
    List<WriteOperation<T, Id>>? operationsDone;
    for (int i = 0; i < _repositories.length;) {
      final repo = _repositories[i];
      if (repo is Transactional<T, Id>) {
        try {
          repositoryIndex = i;
          result = await (repo as Repository<T, Id>).runTransaction(callback);
          operationsDone =
              (repo as Transactional<T, Id>).pollRecentTransactionResults();
          break;
        } catch (err) {
          throw Exception(
              "Transaction on repository ${repo.name} failed. Error [$err]");
        }
      }
    }

    if (result == null) {
      throw Exception(
          "ZipRepository does not contain a repository that implements Transactional<$T, $Id>");
    }

    // poll recent changes
    if (operationsDone != null) {
      for (int i = 0; i < _repositories.length; i++) {
        if (i == repositoryIndex) {
          continue;
        }

        final repo = _repositories[i];
        if (repo is Hydratable<T, Id>) {
          await (repo as Hydratable<T, Id>).hydrate(operationsDone);
        }
      }
    }

    _txnCompleter!.complete();
    _txnCompleter = null;

    return result;
  }

  @override
  List<WriteOperation<T, Id>>? pollRecentTransactionResults() =>
      throw UnsupportedError(
          "ZipRepository does not run any explicit transaction on data.");
}

class _ZipRepositoryImpl<T, Id> extends ZipRepository<T, Id>
    with _RefreshMixin<T, Id> {
  _ZipRepositoryImpl(
      {required List<Repository<T, Id>> repositories,
      ZipRepositoryOptions options = const ZipRepositoryOptions(),
      String? name})
      : super._internal(repositories, options, name) {
    _setupRefresh();
  }

  @override
  Future<void> delete(Id id) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.delete(id);
    }

    for (final repo in _repositories) {
      try {
        await repo.delete(id);
      } catch (err) {
        if (_options.breakOnFail) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<void> insert(T data) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.insert(data);
    }

    for (final repo in _repositories) {
      try {
        await repo.insert(data);
      } catch (err) {
        if (_options.breakOnFail) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<T> update(Id id, Update<T> operation) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.update(id, operation);
    }

    final remoteRepo = _repositories[0];
    final updatedData = await remoteRepo.update(id, operation);

    for (int i = 1; i < _repositories.length; i++) {
      final repo = _repositories[i];
      try {
        await repo.update(id, Update.write(updatedData));
      } catch (err) {
        print(err);
        // todo: decide what to do if it fails, maybe hydrate later
      }
    }

    return updatedData;
  }

  @override
  Future<T?> get(Id id) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.get(id);
    }

    int start =
        _options.readType == ReadType.firstIn ? 0 : _repositories.length - 1;
    int end = _options.readType == ReadType.firstIn ? _repositories.length : -1;
    int step = _options.readType == ReadType.firstIn ? 1 : -1;
    List<int> hydrateOn = [];
    for (int i = start; i != end; i += step) {
      final repository = _repositories[i];
      final entry = await repository.get(id);
      if (entry != null) {
        final op = WriteOperation<T, Id>.insert(entry);
        Future.microtask(() => Future.wait(hydrateOn.map(
            (e) => (_repositories[e] as Hydratable<T, Id>).hydrate([op]))));
        return entry;
      }

      if (repository is Hydratable<T, Id>) {
        hydrateOn.add(i);
      }
    }

    return null;
  }

  @override
  Future<PagedResult<T>> list(Query query) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.list(query);
    }

    int start =
        _options.readType == ReadType.firstIn ? 0 : _repositories.length - 1;
    int end = _options.readType == ReadType.firstIn ? _repositories.length : -1;
    int step = _options.readType == ReadType.firstIn ? 1 : -1;
    List<int> hydrateOn = [];
    for (int i = start; i != end; i += step) {
      final repository = _repositories[i];
      final resultset = await repository.list(query);
      if (resultset.isNotEmpty) {
        final ops = resultset.resultset
            .map((e) => WriteOperation<T, Id>.insert(e))
            .toList(growable: false);
        Future.microtask(() => Future.wait(hydrateOn
            .map((e) => (_repositories[e] as Hydratable<T, Id>).hydrate(ops))));
        return resultset;
      }

      if (repository is Hydratable<T, Id>) {
        hydrateOn.add(i);
      }
    }

    return const PagedResult.empty();
  }
}

/// A [ZipRepository] that allows repositories that uses different types of ids.
///
/// This is useful when you have a repository that strictly uses specific type for ids and other repository that strictly uses another.
/// For example, Firestore only allows string ids and you may have a local repository that only supports int ids, for those situations, use [DynamicIdZipRepository].
/// [Id] is the principal type of id used. If your [T] model uses integer ids, [Id] must be [int]. If [T] uses string ids, [Id] must be [String].
///
/// Keep in mind that converting to/from ids may not be the best for performance, so use with caution.
///
/// When you define a [DynamicIdZipRepository] you must define the list of [repositories], like in any other repository implementation, but that list is of type
/// [IdTransformer], a class that allows you to define a function that will be used to map to the repository's specific id's type.
final class DynamicIdZipRepository<T, Id> extends ZipRepository<T, Id>
    with _RefreshMixin<T, Id> {
  final List<dynamic Function(Id id)> _transformers;

  DynamicIdZipRepository(
      {required List<IdTransformer<T, Id>> repositories,
      ZipRepositoryOptions options = const ZipRepositoryOptions(),
      String? name})
      : _transformers =
            repositories.map((e) => e.transform).toList(growable: false),
        super._internal(
            repositories.map((e) => e.repository).toList(growable: false),
            options,
            name) {
    _setupRefresh();
  }

  @override
  Future<void> delete(Id id) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.delete(id);
    }

    for (int i = 0; i < _repositories.length; i++) {
      final repo = _repositories[i];
      try {
        await repo.delete(_transformers[i](id));
      } catch (err) {
        if (_options.breakOnFail) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<T?> get(Id id) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.get(id);
    }

    int start =
        _options.readType == ReadType.firstIn ? 0 : _repositories.length - 1;
    int end = _options.readType == ReadType.firstIn ? _repositories.length : -1;
    int step = _options.readType == ReadType.firstIn ? 1 : -1;
    for (int i = start; i != end; i += step) {
      final repo = _repositories[i];
      final entry = await repo.get(_transformers[i](id));
      if (entry != null) {
        return entry;
      }
    }

    return null;
  }

  @override
  Future<void> insert(T data) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.insert(data);
    }

    for (final repo in _repositories) {
      try {
        await repo.insert(data);
      } catch (err) {
        if (_options.breakOnFail) {
          rethrow;
        }
      }
    }
  }

  @override
  Future<PagedResult<T>> list(Query query) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.list(query);
    }

    int start =
        _options.readType == ReadType.firstIn ? 0 : _repositories.length - 1;
    int end = _options.readType == ReadType.firstIn ? _repositories.length : 0;
    int step = _options.readType == ReadType.firstIn ? 1 : -1;
    for (int i = start; i < end; i += step) {
      final repo = _repositories[i];
      final resultset = await repo.list(query);
      if (resultset.isNotEmpty) {
        return resultset;
      }
    }

    return const PagedResult.empty();
  }

  @override
  Future<T> update(Id id, Update<T> operation) async {
    if (_runningForcedOn != null) {
      return await _runningForcedOn!.update(id, operation);
    }

    final remoteRepo = _repositories[0];
    final updatedData =
        await remoteRepo.update(_transformers[0](id), operation);

    for (int i = 1; i < _repositories.length; i++) {
      final repo = _repositories[i];
      try {
        await repo.update(_transformers[i](id), Update.write(updatedData));
      } catch (err) {
        // todo: decide what to do if it fails, maybe hydrate later
      }
    }

    return updatedData;
  }
}

/// Transforms an id of type [Id] into another type.
final class IdTransformer<T, Id> {
  final dynamic Function(Id id) transform;
  final Repository<T, dynamic> repository;

  /// Creates a new [IdTransformer] with the specified [transform] function for the specific [repository].
  IdTransformer({required this.transform, required this.repository});

  /// Defines an [IdTransformer] that does nothing with the id, just passes it to the repository without converting it.
  factory IdTransformer.noTransform(
          {required Repository<T, dynamic> repository}) =>
      IdTransformer(transform: _noTransformFunction, repository: repository);
}

dynamic _noTransformFunction(dynamic id) => id;

/// Contains a list of options to configure a [ZipRepository]
final class ZipRepositoryOptions {
  /// The [KvStore] used to store last refresh date and any other information that is needed.
  final KvStore? kvStore;

  /// A flag that indicates that an operation should break it's execution if any replicated operation fails in a repository.
  final bool breakOnFail;

  /// The repositories [ReadType] order used in read operations.
  final ReadType readType;

  /// The interval duration between automatic refresh calls. Set to [Duration.zero] to disable refresh.
  final Duration refreshInterval;

  /// A flag that indicates if the repository should retry a refresh if it fails.
  final bool refreshRetry;

  const ZipRepositoryOptions(
      {this.readType = ReadType.lastIn,
      this.breakOnFail = true,
      this.refreshInterval = const Duration(minutes: 5),
      this.refreshRetry = false,
      this.kvStore});
}

enum ReadType {
  /// Indicates that read operations will start from the first added repository.
  firstIn,

  /// Indicates that read operations will start from the last added repository.
  lastIn
}

mixin _RefreshMixin<T, Id> on ZipRepository<T, Id> {
  Timer? _refreshTimer;
  Completer? _refreshCompleter;
  bool _canRefresh = true;
  DateTime? _lastRefresh;

  bool get isRefreshEnabled => _canRefresh;

  void _setupRefresh() {
    if (_options.refreshInterval == Duration.zero) {
      _canRefresh = false;
    } else {
      assert(_options.kvStore != null,
          "If you enable refresh, you must supply a KvStore.");
      _refreshTimer = Timer.periodic(_options.refreshInterval, (timer) {
        _onRefresh();
      });
    }
  }

  @override
  Future<void> refresh() async {
    // at least two repositories are needed
    if (!_canRefresh || _repositories.length < 2) {
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
      if (repository is! DataProvider<T, Id>) {
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
    final pollRepository = _repositories[pollFrom] as DataProvider<T, Id>;
    String? continuationToken;

    // retry is only done while polling, hydrating isn't
    do {
      Snapshot<T, Id> snapshot;
      try {
        snapshot = await retry(
            () => pollRepository.poll(
                from: _lastRefresh, continuationToken: continuationToken),
            retryIf: (p0) => _options.refreshRetry);
      } catch (err) {
        // ignore this attemp on error
        return;
      }

      continuationToken = snapshot.continuationToken;
      if (snapshot.data.isNotEmpty) {
        final hydratableRepos = _repositories.indexed.where((element) =>
            element.$1 > pollFrom! && element.$2 is Hydratable<T, Id>);

        try {
          await Future.wait(
              hydratableRepos.map(
                  (e) => (e.$2 as Hydratable<T, Id>).hydrate(snapshot.data)),
              eagerError: false);
        } catch (_) {} // ignore any hydrate error
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
      int? millis = _options.kvStore!.get('__ZipRepositorySync[$name]__');
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (_) {}

    return null;
  }

  @pragma("vm:prefer-inline")
  Future<void> _saveLastRefresh() {
    return _options.kvStore!.set(
        '__ZipRepositorySync[$name]__', _lastRefresh!.millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _repositories.clear();
  }
}
