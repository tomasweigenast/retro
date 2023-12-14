abstract interface class DataProvider<T> {
  Future<Batch<T>> poll({DateTime? from, String? continuationToken});
}

final class Batch<T> {
  final List<T> data;
  final String? continuationToken;

  bool get hasMoreData => continuationToken != null;

  Batch({required this.data, this.continuationToken});
}
