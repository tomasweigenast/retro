part of 'firestore_repository.dart';

final class FirestoreTransaction<T> implements RepositoryTransaction<T, String> {
  final cf.Transaction _transaction;
  final cf.CollectionReference<T> _collectionReference;
  final IdGetter<T, String> _idGetter;
  final QueryTranslator<cf.Query<T>, cf.Query<T>> _queryTranslator;
  final List<WriteOperation<T, String>> _operationsDone = [];

  FirestoreTransaction(
      {required cf.Transaction tx,
      required cf.CollectionReference<T> collectionReference,
      required IdGetter<T, String> idGetter,
      required QueryTranslator<cf.Query<T>, cf.Query<T>> queryTranslator})
      : _transaction = tx,
        _idGetter = idGetter,
        _queryTranslator = queryTranslator,
        _collectionReference = collectionReference;

  @override
  void delete(String id) {
    _transaction.delete(_collectionReference.doc(id));
    _operationsDone.add(WriteOperation.delete(id));
  }

  @override
  FutureOr<T?> get(String id) async {
    final snapshot = await _transaction.get(_collectionReference.doc(id));
    return snapshot.data();
  }

  @override
  void insert(T data) {
    _transaction.set(_collectionReference.doc(_idGetter(data)), data);
  }

  @override
  void update(String id, Update<T> update) {
    final ref = _collectionReference.doc(id);
    if (update.data != null) {
      final data = update.data as T;
      _transaction.set(ref, data);
    } else {
      throw Exception("Update.updater is forbidden in a Firestore transaction.");
    }
  }

  @override
  FutureOr<List<T>> list(Query query) async {
    cf.Query<T> firestoreQuery = _collectionReference;
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
      case CursorPagination(pageSize: var pageSize):
        firestoreQuery = firestoreQuery.limit(pageSize);
        break;

      case OffsetPagination():
        throw Exception("Firestore does not support offset pagination.");
    }

    final snapshot = await firestoreQuery.get();
    return snapshot.docs.map((e) => e.data()).toList(growable: false);
  }
}
