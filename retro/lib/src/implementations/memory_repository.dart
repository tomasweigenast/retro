import 'package:retro/retro.dart';
import 'package:retro/src/models/types.dart';

typedef ToJson<T> = Map<String, dynamic> Function(T data);
typedef FromJson<T> = T Function(Map<String, dynamic> json);
typedef Json = Map<String, dynamic>;
typedef EqualityComparer<T> = int Function(T a, T b);

const _kInternalIdFieldName = "__id__";

class MemoryRepository<T, Id> extends SyncRepository<T, Id> {
  final Map<Id, Json> _data;
  final QueryTranslator _queryTranslator;
  final ToJson<T> _toJson;
  final FromJson<T> _fromJson;
  final Map<Type, EqualityComparer> _equalityComparers;
  final IdGetter<T, Id> _idGetter;

  MemoryRepository(
      {required ToJson<T> toJson,
      required FromJson<T> fromJson,
      required IdGetter<T, Id> idGetter,
      Map<Id, T>? initialData,
      QueryTranslator queryTranslator = const MemoryQueryTranslator(),
      Map<Type, EqualityComparer>? equalityComparers,
      super.name = kDefaultRepositoryName})
      : _toJson = toJson,
        _fromJson = fromJson,
        _idGetter = idGetter,
        _data = {},
        _equalityComparers = equalityComparers ?? const {},
        _queryTranslator = queryTranslator {
    if (initialData != null) {
      _data.addAll(initialData.map((key, value) => MapEntry(key, _toJson(value))));
    }
  }

  @override
  void delete(Id id) {
    _data.remove(id);
  }

  @override
  T? get(Id id) {
    final data = _data[id];
    if (data == null) {
      return null;
    }

    return _fromJson(data);
  }

  @override
  void insert(T data) {
    final json = _toJson(data);
    final id = _idGetter(data);
    json[_kInternalIdFieldName] = id;
    _data[id] = json;
  }

  @override
  PagedResult<T> list(Query query) {
    final list = _data.values.toList(growable: false);
    var sort = query.sortBy;
    if (sort.isEmpty) {
      sort = const [Sort.ascending(_kInternalIdFieldName)];
    }
    list.sort((a, b) {
      for (final sort in query.sortBy) {
        final aValue = a[sort.field];
        final bValue = b[sort.field];

        int result = sort.descending ? _compare(bValue, aValue) : _compare(aValue, bValue);

        if (result != 0) {
          return result;
        }

        continue;
      }

      return 0;
    });

    Iterable<Json> iterable = list;
    for (final filter in query.filters) {
      iterable = _queryTranslator.translate(iterable, filter);
    }

    switch (query.pagination) {
      case CursorPagination(pageSize: var pageSize, pageToken: var pageToken):
        final pageTokenData = decodePageToken(pageToken);
        if (pageTokenData.isNotEmpty) {
          for (final MapEntry(:key, :value) in pageTokenData.entries) {
            iterable = iterable.where((element) => _compare(element[key], value) >= 0);
          }
        }

        iterable = iterable.take(pageSize + 1);
        break;

      case OffsetPagination(pageSize: var pageSize, page: var page):
        int skip = page * pageSize;
        iterable = iterable.skip(skip).take(pageSize + 1);
        break;
    }

    final resultset = iterable.map((e) => _fromJson(e)).toList();
    int? nextPage;
    String? nextPageToken;

    switch (query.pagination) {
      case CursorPagination(pageSize: var pageSize):
        if (resultset.length > pageSize) {
          final lastElement = _toJson(resultset.removeLast());
          final pageTokenFields = Map<String, dynamic>.fromEntries(lastElement.entries
              .where((element) => sort.any((sort) => sort.field == element.key)));
          nextPageToken = encodePageToken(pageTokenFields);
        }
        break;

      case OffsetPagination(pageSize: var pageSize, page: var page):
        if (resultset.length > pageSize) {
          nextPage = page + 1;
        }
        break;
    }

    return PagedResult(resultset: resultset, nextPage: nextPage, nextPageToken: nextPageToken);
  }

  @override
  T update(Id id, Update<T, Id> operation) {
    final data = _data[id];
    if (data == null) {
      throw Exception("Entity with id $id not found.");
    }

    if (operation.data != null) {
      _data[id] = _toJson(operation.data as T);
    } else {
      final entry = _fromJson(data);
      operation.updater!(entry);
      _data[id] = _toJson(entry);
    }

    return _fromJson(_data[id]!);
  }

  Map<Id, T> getCurrentData() => _data.map((key, value) => MapEntry(key, _fromJson(value)));

  int _compare(dynamic a, dynamic b) {
    try {
      return a.compareTo(b);
    } catch (_) {
      final comparer = _equalityComparers[a.runtimeType];
      if (comparer == null) {
        throw UnsupportedError(
            "Unable to compare ${a.runtimeType} types because it does not have a compareTo method and an EqualityComparer is not registered for it.");
      }
      return comparer(a, b);
    }
  }
}

class MemoryQueryTranslator implements QueryTranslator<Iterable<Json>, Iterable<Json>> {
  const MemoryQueryTranslator();

  @override
  Iterable<Json> translate(Iterable<Json> data, Filter filter) {
    final filterValue = _sanitize(filter.value);

    switch (filter.operator) {
      case FilterOperator.equals:
        return data.where((element) => element[filter.field] == filterValue);

      case FilterOperator.notEquals:
        return data.where((element) => element[filter.field] != filterValue);

      case FilterOperator.greaterThan:
        return data.where((element) => element[filter.field].compareTo(filterValue) > 0);

      case FilterOperator.lessThan:
        return data.where((element) => element[filter.field].compareTo(filterValue) < 0);

      case FilterOperator.greaterThanOrEquals:
        return data.where((element) => element[filter.field].compareTo(filterValue) >= 0);

      case FilterOperator.lessThanOrEquals:
        return data.where((element) => element[filter.field].compareTo(filterValue) <= 0);

      case FilterOperator.between:
        var low = (filterValue as List)[0];
        var high = (filterValue)[1];
        return data.where((element) =>
            element[filter.field].compareTo(low) >= 0 &&
            element[filter.field].compareTo(high) <= 0);

      case FilterOperator.inArray:
        return data.where((element) => (filterValue as List).contains(element[filter.field]));

      case FilterOperator.notInArray:
        return data.where((element) => !(filterValue as List).contains(element[filter.field]));

      case FilterOperator.contains:
        return data.where((element) => element[filter.field].contains(filterValue));

      case FilterOperator.containsAny:
        return data.where((element) =>
            (filterValue as List).any((a) => (element[filter.field] as List).contains(a)));

      default:
        throw UnsupportedError("Operator ${filter.operator} not supported in MemoryRepository.");
    }
  }

  dynamic _sanitize(dynamic value) {
    return switch (value) {
      List() => value.map((e) => _sanitize(e)).toList(growable: false),
      Map() => value.map((key, value) => MapEntry(key, _sanitize(value))),
      DateTime() => value.millisecondsSinceEpoch,
      null => null,
      _ => value
    };
  }
}
