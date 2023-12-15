import 'package:retro/retro.dart';

abstract interface class DataProvider<T, Id> {
  Future<Snapshot<T, Id>> poll({DateTime? from, String? continuationToken});
}

final class Snapshot<T, Id> {
  final List<WriteOperation<T, Id>> data;
  final String? continuationToken;

  bool get hasMoreData => continuationToken != null;

  Snapshot({required this.data, this.continuationToken});
}
