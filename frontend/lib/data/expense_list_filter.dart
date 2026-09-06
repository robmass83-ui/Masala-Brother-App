import 'package:flutter/foundation.dart';

import 'report_aggregator.dart';
import 'report_period.dart';

@immutable
class ExpenseListFilter {
  const ExpenseListFilter({
    this.propertyId,
    this.categoryId,
    this.from,
    this.to,
  });

  final String? propertyId;
  final String? categoryId;
  final DateTime? from;
  final DateTime? to;

  bool get isActive =>
      propertyId != null || categoryId != null || from != null || to != null;

  bool matches({
    required String? expensePropertyId,
    required String categoryId,
    required DateTime date,
  }) {
    if (propertyId != null) {
      if (propertyId == ReportAggregator.nonePropertyId) {
        if (expensePropertyId != null && expensePropertyId.isNotEmpty) {
          return false;
        }
      } else if (expensePropertyId != propertyId) {
        return false;
      }
    }
    if (this.categoryId != null && categoryId != this.categoryId) {
      return false;
    }
    if (from != null || to != null) {
      final window = ReportPeriod(
        kind: ReportPeriodKind.custom,
        from: from,
        to: to,
      );
      if (!window.contains(date)) return false;
    }
    return true;
  }

  ExpenseListFilter copyWith({
    String? propertyId,
    String? categoryId,
    DateTime? from,
    DateTime? to,
    bool clearProperty = false,
    bool clearCategory = false,
    bool clearDates = false,
  }) {
    return ExpenseListFilter(
      propertyId: clearProperty ? null : (propertyId ?? this.propertyId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
    );
  }
}
