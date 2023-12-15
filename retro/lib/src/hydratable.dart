abstract interface class Hydratable<T, Id> {
  Future<void> hydrate(List<WriteOperation<T, Id>> data);
}

final class WriteOperation<T, Id> {
  final OperationType type;
  final dynamic _data;

  dynamic get data => _data;

  T get asData {
    if (type != OperationType.insert) {
      throw Exception("Operation type is not insert.");
    }

    return _data as T;
  }

  Id get asId {
    if (type != OperationType.delete) {
      throw Exception("Operation type is not delete.");
    }

    return _data as Id;
  }

  WriteOperation.insert(T data)
      : type = OperationType.insert,
        _data = data;

  WriteOperation.delete(Id id)
      : type = OperationType.delete,
        _data = id;
}

enum OperationType { insert, delete }
