import 'package:retro/retro.dart';

class MemoryRepository<T, Id> extends SyncRepository<T, Id> {
  final Map<Id, T> _data;

  MemoryRepository({Map<Id, T>? initialData, super.name = kDefaultRepositoryName})
      : _data = initialData ?? {};

  @override
  void delete(Id id) {
    _data.remove(id);
  }

  @override
  T? get(Id id) => _data[id];

  @override
  void insert(Id id, T data) {
    _data[id] = data;
  }

  @override
  List<T> list() {
    return _data.values.toList(growable: false);
  }

  @override
  T update(Id id, Update<T, Id> operation) {
    final data = _data[id];
    if (data == null) {
      throw Exception("Entity with id $id not found.");
    }

    if (operation.data != null) {
      _data[id] = operation.data as T;
    } else {
      operation.updater!(data);
    }

    return _data[id]!;
  }

  Map<Id, T> getCurrentData() => _data;
}
