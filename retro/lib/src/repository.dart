import 'dart:async';

import 'package:retro/retro.dart';

const kDefaultRepositoryName = "default";

abstract class Repository<T, Id> {
  final String name;

  Repository({required this.name});

  FutureOr<T?> get(Id id);
  FutureOr<PagedResult<T>> list(Query query);
  FutureOr<void> delete(Id id);
  FutureOr<void> insert(T data);
  FutureOr<T> update(Id id, Update<T, Id> operation);
}

abstract class AsyncRepository<T, Id> extends Repository<T, Id> {
  AsyncRepository({required super.name});

  @override
  Future<T?> get(Id id);

  @override
  Future<PagedResult<T>> list(Query query);

  @override
  Future<void> delete(Id id);

  @override
  Future<void> insert(T data);

  @override
  Future<T> update(Id id, Update<T, Id> operation);
}

abstract class SyncRepository<T, Id> extends Repository<T, Id> {
  SyncRepository({required super.name});

  @override
  T? get(Id id);

  @override
  PagedResult<T> list(Query query);

  @override
  void delete(Id id);

  @override
  void insert(T data);

  @override
  T update(Id id, Update<T, Id> operation);
}
