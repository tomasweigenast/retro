import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:retro/retro.dart';

final class FirestoreTransaction<T> implements RepositoryTransaction<T, String> {
  final Transaction _transaction;
  final CollectionReference<T> _collectionReference;
  final IdGetter<T, String> _idGetter;

  FirestoreTransaction(
      {required Transaction tx,
      required CollectionReference<T> collectionReference,
      required IdGetter<T, String> idGetter})
      : _transaction = tx,
        _idGetter = idGetter,
        _collectionReference = collectionReference;

  @override
  void delete(String id) {
    _transaction.delete(_collectionReference.doc(id));
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
}
