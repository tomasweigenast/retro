abstract interface class Hydratable<T> {
  Future<void> hydrate(List<WriteOperation<T>> data);
}

final class WriteOperation<T> {
  final OperationType type;
  final T data;

  WriteOperation({required this.type, required this.data});

  WriteOperation.insert(this.data) : type = OperationType.insert;
  WriteOperation.delete(this.data) : type = OperationType.delete;
}

enum OperationType { insert, delete }
