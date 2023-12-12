final class PagedResult<T> {
  final List<T> resultset;
  final String? nextPageToken;
  final int? nextPage;

  int get length => resultset.length;
  bool get isEmpty => resultset.isEmpty;
  bool get isNotEmpty => resultset.isNotEmpty;

  PagedResult({required this.resultset, this.nextPageToken, this.nextPage});

  const PagedResult.empty()
      : resultset = const [],
        nextPage = null,
        nextPageToken = null;
}
