import 'dart:async';

import 'package:retro/src/models/update.dart';

const kDefaultRepositoryName = "default";

abstract class Repository<T, Id> {
  final String name;

  Repository({required this.name});

  FutureOr<T?> get(Id id);
  FutureOr<List<T>> list();
  FutureOr<void> delete(Id id);
  FutureOr<void> insert(Id id, T data);
  FutureOr<T> update(Id id, Update<T, Id> operation);
}

abstract class AsyncRepository<T, Id> extends Repository<T, Id> {
  AsyncRepository({required super.name});

  @override
  Future<T?> get(Id id);

  @override
  Future<List<T>> list();

  @override
  Future<void> delete(Id id);

  @override
  Future<void> insert(Id id, T data);

  @override
  Future<T> update(Id id, Update<T, Id> operation);
}

abstract class SyncRepository<T, Id> extends Repository<T, Id> {
  SyncRepository({required super.name});

  @override
  T? get(Id id);

  @override
  List<T> list();

  @override
  void delete(Id id);

  @override
  void insert(Id id, T data);

  @override
  T update(Id id, Update<T, Id> operation);
}
