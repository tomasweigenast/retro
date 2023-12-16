import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:retro/retro.dart';
import 'package:retro_firestore/retro_firestore.dart';

part 'firestore_transaction.dart';

/// An [AsyncRepository] that uses Firestore as it's backend.
final class FirestoreRepository<T> extends AsyncRepository<T, String>
    implements Transactional<T, String> {
  final cf.CollectionReference<T> _collection;
  final IdGetter<T, String> _idGetter;
  final QueryTranslator<cf.Query<T>, cf.Query<T>> _queryTranslator;

  List<WriteOperation<T, String>>? _lastTransactionOperations;
  Completer? _txnCompleter;

  /// Creates a new [FirestoreRepository] for the specified [cf.CollectionReference]
  FirestoreRepository(
      {required cf.CollectionReference<T> collection,
      required IdGetter<T, String> idGetter,
      QueryTranslator<cf.Query<T>, cf.Query<T>>? queryTranslator,
      super.name})
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
      firestoreQuery = firestoreQuery.orderBy(sort.field, descending: sort.descending);
    }

    for (final filter in query.filters) {
      firestoreQuery = _queryTranslator.translate(firestoreQuery, filter);
    }

    switch (query.pagination) {
      case CursorPagination(pageSize: var pageSize, pageToken: var pageToken):
        final pageTokenData = decodePageToken(pageToken);
        if (pageTokenData.isNotEmpty) {
          firestoreQuery = firestoreQuery.startAt(pageTokenData.values.toList());
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
        resultset: docs.map((e) => e.data()).toList(growable: false), nextPageToken: nextPageToken);
  }

  @override
  Future<T> update(String id, Update<T> operation) async {
    if (operation.data != null) {
      final data = operation.data as T;
      await _collection.doc(id).set(data);
      return data;
    } else {
      final ref = _collection.doc(id);
      return await _collection.firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        var data = snapshot.data();
        if (data == null) {
          throw Exception("Entity '$id' not found.");
        }

        data = operation.updater!(data);
        transaction.set(ref, data);
        return data as T;
      });
    }
  }

  @override
  Future<K> runTransaction<K>(
      FutureOr<K> Function(RepositoryTransaction<T, String> transaction) callback) async {
    if (_txnCompleter != null) {
      await _txnCompleter!.future;
    }

    _txnCompleter = Completer();

    return _collection.firestore.runTransaction((transaction) async {
      final repositoryTxn = FirestoreTransaction(
          tx: transaction,
          collectionReference: _collection,
          idGetter: _idGetter,
          queryTranslator: _queryTranslator);
      final result = await callback(repositoryTxn);
      _lastTransactionOperations = repositoryTxn._operationsDone;
      _txnCompleter!.complete();
      _txnCompleter = null;
      return result;
    });
  }

  @override
  List<WriteOperation<T, String>>? pollRecentTransactionResults() {
    if (_lastTransactionOperations == null) {
      return null;
    }

    final operations = _lastTransactionOperations;
    _lastTransactionOperations = null;
    return operations;
  }
}
