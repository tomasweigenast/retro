import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:retro/retro.dart';

/// The default [QueryTranslator] that translate a [Filter] to a [cf.Query]
class FirestoreQueryTranslator<T> implements QueryTranslator<cf.Query<T>, cf.Query<T>> {
  const FirestoreQueryTranslator();

  @override
  cf.Query<T> translate(cf.Query<T> data, Filter filter) {
    switch (filter.operator) {
      case FilterOperator.equals:
        if (filter.value == null) {
          return data.where(filter.field, isNull: true);
        }
        return data.where(filter.field, isEqualTo: filter.value);

      case FilterOperator.notEquals:
        return data.where(filter.field, isNotEqualTo: filter.value);

      case FilterOperator.greaterThan:
        return data.where(filter.field, isGreaterThan: filter.value);

      case FilterOperator.lessThan:
        return data.where(filter.field, isLessThan: filter.value);

      case FilterOperator.greaterThanOrEquals:
        return data.where(filter.field, isGreaterThanOrEqualTo: filter.value);

      case FilterOperator.lessThanOrEquals:
        return data.where(filter.field, isLessThanOrEqualTo: filter.value);

      case FilterOperator.between:
        var low = (filter.value as List)[0];
        var high = filter.value[1];
        return data
            .where(filter.field, isGreaterThanOrEqualTo: low)
            .where(filter.field, isLessThanOrEqualTo: high);

      case FilterOperator.inArray:
        return data.where(filter.field, whereIn: filter.value as List);

      case FilterOperator.notInArray:
        return data.where(filter.field, whereNotIn: filter.value as List);

      case FilterOperator.contains:
        return data.where(filter.field, arrayContains: filter.value);

      case FilterOperator.containsAny:
        return data.where(filter.field, arrayContainsAny: filter.value as List);

      default:
        throw UnsupportedError("Operator ${filter.operator} not supported in MemoryRepository.");
    }
  }
}
