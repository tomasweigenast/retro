import 'dart:async';

import 'package:retro/retro.dart';

/// Provides the minimal operations that can be done on a [Repository] transaction.
abstract interface class RepositoryTransaction<T, Id> {
  FutureOr<T?> get(Id id);
  FutureOr<List<T>> list(Query query);
  void delete(Id id);
  void insert(T data);
  void update(Id id, Update<T> update);
}

/// A [Transactional] provides a method to pull recent transaction changes in order to hydrate other repostiories.
abstract interface class Transactional<T, Id> {
  List<WriteOperation<T, Id>>? pollRecentTransactionResults();
}
