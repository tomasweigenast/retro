import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:retro/retro.dart';
import 'package:retro/src/models/types.dart';

final class FirestoreRepository<T> extends AsyncRepository<T, String> {
  final cf.CollectionReference<T> _collection;
  final IdGetter<T, String> _idGetter;
  final QueryTranslator<cf.Query<T>, cf.Query<T>> _queryTranslator;

  FirestoreRepository(
      {required cf.CollectionReference<T> collection,
      required IdGetter<T, String> idGetter,
      QueryTranslator<cf.Query<T>, cf.Query<T>>? queryTranslator,
      super.name = kDefaultRepositoryName})
      : _collection = collection,
        _queryTranslator = queryTranslator ?? FirestoreQueryTranslator<T>(),
        _idGetter = idGetter;

  @override
  Future<void> delete(String id) => _collection.doc(id).delete();

  @override
  Future<T?> get(String id) async {
    final snapshot = await _collection.doc(id).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return data;
  }

  @override
  Future<void> insert(T data) => _collection.doc(_idGetter(data)).set(data);

  @override
  Future<PagedResult<T>> list(Query query) async {
    cf.Query<T> firestoreQuery = _collection;
    if (query.sortBy.isEmpty) {
      firestoreQuery = firestoreQuery.orderBy(cf.FieldPath.documentId);
    }

    for (final sort in query.sortBy) {
      firestoreQuery =
          firestoreQuery.orderBy(sort.field, descending: sort.descending);
    }

    for (final filter in query.filters) {
      firestoreQuery = _queryTranslator.translate(firestoreQuery, filter);
    }

    switch (query.pagination) {
      case CursorPagination(pageSize: var pageSize, pageToken: var pageToken):
        final pageTokenData = decodePageToken(pageToken);
        if (pageTokenData.isNotEmpty) {
          firestoreQuery =
              firestoreQuery.startAt(pageTokenData.values.toList());
        }

        firestoreQuery = firestoreQuery.limit(pageSize + 1);
        break;

      case OffsetPagination():
        throw Exception("Firestore does not support offset pagination.");
    }

    final snapshot = await firestoreQuery.get();
    final docs = snapshot.docs;
    String? nextPageToken;

    switch (query.pagination) {
      case CursorPagination(pageSize: var pageSize):
        if (snapshot.size > pageSize) {
          final lastElement = docs.removeLast();
          final tokens = <String, dynamic>{};
          for (final sort in query.sortBy) {
            tokens[sort.field] = lastElement.get(sort.field);
          }
          nextPageToken = encodePageToken(tokens);
        }
        break;

      // this will never be called
      default:
        throw "";
    }

    return PagedResult(
        resultset: docs.map((e) => e.data()).toList(growable: false),
        nextPageToken: nextPageToken);
  }

  @override
  Future<T> update(String id, Update<T, String> operation) async {
    if (operation.data != null) {
      final data = operation.data as T;
      await _collection.doc(id).set(data);
      return data;
    } else {
      final ref = _collection.doc(id);
      return await _collection.firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        final data = snapshot.data();
        if (data == null) {
          throw Exception("Entity '$id' not found.");
        }

        operation.updater!(data);
        transaction.set(ref, data);
        return data;
      });
    }
  }
}

class FirestoreQueryTranslator<T>
    implements QueryTranslator<cf.Query<T>, cf.Query<T>> {
  const FirestoreQueryTranslator();

  @override
  cf.Query<T> translate(cf.Query<T> data, Filter filter) {
    switch (filter.operator) {
      case FilterOperator.equals:
        return data.where(filter.field, isEqualTo: filter.value);

      case FilterOperator.notEquals:
        return data.where(filter.field, isNotEqualTo: filter.value);

      case FilterOperator.greaterThan:
        return data.where(filter.field, isGreaterThan: filter.value);

      case FilterOperator.lessThan:
        return data.where(filter.field, isLessThan: filter.value);

      case FilterOperator.greaterThanOrEquals:
        return data.where(filter.field, isGreaterThanOrEqualTo: filter.value);

      case FilterOperator.lessThanOrEquals:
        return data.where(filter.field, isLessThanOrEqualTo: filter.value);

      case FilterOperator.between:
        var low = (filter.value as List)[0];
        var high = filter.value[1];
        return data
            .where(filter.field, isGreaterThanOrEqualTo: low)
            .where(filter.field, isLessThanOrEqualTo: high);

      case FilterOperator.inArray:
        return data.where(filter.field, whereIn: filter.value as List);

      case FilterOperator.notInArray:
        return data.where(filter.field, whereNotIn: filter.value as List);

      case FilterOperator.contains:
        return data.where(filter.field, arrayContains: filter.value);

      case FilterOperator.containsAny:
        return data.where(filter.field, arrayContainsAny: filter.value as List);

      default:
        throw UnsupportedError(
            "Operator ${filter.operator} not supported in MemoryRepository.");
    }
  }
}
