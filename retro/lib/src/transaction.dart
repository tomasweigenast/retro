import 'dart:async';

import 'package:retro/retro.dart';

abstract interface class RepositoryTransaction<T, Id> {
  FutureOr<T?> get(Id id);
  void delete(Id id);
  void insert(T data);
  void update(Id id, Update<T> update);
}

abstract interface class Transactional<T, Id> {
  FutureOr<K> runTransaction<K>(
      FutureOr<K> Function(RepositoryTransaction<T, Id> transaction) callback);
}
