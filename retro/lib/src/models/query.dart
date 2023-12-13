final class Query {
  final List<Filter> filters;
  final List<Sort> sortBy;
  final Pagination pagination;

  const Query(
      {this.filters = const [],
      this.sortBy = const [],
      required this.pagination});
}

sealed class Pagination {
  final int pageSize;

  const Pagination._({required this.pageSize});
}

class CursorPagination extends Pagination {
  final String? pageToken;

  const CursorPagination({this.pageToken, super.pageSize = 100}) : super._();
}

class OffsetPagination extends Pagination {
  final int page;

  const OffsetPagination({this.page = 0, super.pageSize = 100}) : super._();
}

final class Filter {
  final String field;
  final FilterOperator operator;
  final dynamic value;

  const Filter(
      {required this.field, required this.operator, required this.value});

  const Filter.equals({required this.field, required this.value})
      : operator = FilterOperator.equals;

  const Filter.notEquals({required this.field, required this.value})
      : operator = FilterOperator.notEquals;

  const Filter.greaterThan({required this.field, required this.value})
      : operator = FilterOperator.greaterThan;

  const Filter.greaterThanOrEquals({required this.field, required this.value})
      : operator = FilterOperator.greaterThanOrEquals;

  const Filter.lessThan({required this.field, required this.value})
      : operator = FilterOperator.lessThan;

  const Filter.lessThanOrEquals({required this.field, required this.value})
      : operator = FilterOperator.lessThanOrEquals;

  const Filter.between({required this.field, required List<dynamic> values})
      : operator = FilterOperator.between,
        value = values;

  const Filter.inArray({required this.field, required List<dynamic> values})
      : operator = FilterOperator.inArray,
        value = values;

  const Filter.notInArray({required this.field, required List<dynamic> values})
      : operator = FilterOperator.notInArray,
        value = values;

  const Filter.contains({required this.field, required this.value})
      : operator = FilterOperator.contains;

  const Filter.containsAny({required this.field, required List values})
      : operator = FilterOperator.containsAny,
        value = values;
}

class FilterOperator {
  /// The name of the operator
  final String name;

  const FilterOperator(this.name);

  static const FilterOperator equals = FilterOperator("==");
  static const FilterOperator notEquals = FilterOperator("!=");
  static const FilterOperator greaterThan = FilterOperator(">");
  static const FilterOperator greaterThanOrEquals = FilterOperator(">=");
  static const FilterOperator lessThan = FilterOperator("<");
  static const FilterOperator lessThanOrEquals = FilterOperator("<=");
  static const FilterOperator between = FilterOperator("between");
  static const FilterOperator inArray = FilterOperator("in");
  static const FilterOperator notInArray = FilterOperator("not-in");
  static const FilterOperator contains = FilterOperator("contains");
  static const FilterOperator containsAny = FilterOperator("contains-any");

  @override
  String toString() => name;
}

final class Sort {
  final String field;
  final bool descending;

  const Sort.ascending(this.field) : descending = false;
  const Sort.descending(this.field) : descending = true;
  const Sort({required this.field, required this.descending});
}
