import 'package:flutter/foundation.dart';

import 'balance_calculator.dart';
import 'expense_models.dart';
import 'report_period.dart';
import 'task_models.dart';
import 'transfer_models.dart';

@immutable
class NamedAmount {
  const NamedAmount({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.count,
  });

  final String id;
  final String name;
  final int amountCents;
  final int count;
}

@immutable
class ReportSnapshot {
  const ReportSnapshot({
    required this.period,
    required this.expenses,
    required this.transfers,
    required this.tasks,
    required this.byProperty,
    required this.byCategory,
    required this.totalDueCents,
    required this.paidRobCents,
    required this.paidLauCents,
  });

  final ReportPeriod period;
  final List<Expense> expenses;
  final List<Transfer> transfers;
  final List<HouseholdTask> tasks;
  final List<NamedAmount> byProperty;
  final List<NamedAmount> byCategory;
  final int totalDueCents;
  final int paidRobCents;
  final int paidLauCents;

  int get expenseCount => expenses.length;

  int get totalPaidCents => paidRobCents + paidLauCents;

  double get robPaidShare {
    if (totalPaidCents == 0) return 0.5;
    return paidRobCents / totalPaidCents;
  }

  int get maxPropertyCents => byProperty.isEmpty
      ? 0
      : byProperty.map((e) => e.amountCents).reduce((a, b) => a > b ? a : b);

  int get maxCategoryCents => byCategory.isEmpty
      ? 0
      : byCategory.map((e) => e.amountCents).reduce((a, b) => a > b ? a : b);
}

class ReportAggregator {
  const ReportAggregator();

  static const nonePropertyId = '__none__';

  ReportSnapshot build({
    required List<Expense> expenses,
    required List<Transfer> transfers,
    required List<HouseholdTask> tasks,
    required ReportPeriod period,
    Map<String, String> categoryNames = const {},
    Map<String, String> propertyNames = const {},
    bool unpaidOrPartialOnly = false,
  }) {
    final filteredExpenses = expenses.where((e) {
      if (e.isDeleted) return false;
      if (!period.contains(e.date)) return false;
      if (unpaidOrPartialOnly && e.status == ExpenseStatus.pagato) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final filteredTransfers = transfers.where((t) {
      if (t.isDeleted) return false;
      return period.contains(t.date);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final filteredTasks = tasks.where((t) => !t.isDeleted).toList()
      ..sort(compareOpenFirst);

    var totalDue = 0;
    var paidRob = 0;
    var paidLau = 0;
    final propSums = <String, int>{};
    final propCounts = <String, int>{};
    final catSums = <String, int>{};
    final catCounts = <String, int>{};

    for (final e in filteredExpenses) {
      totalDue += e.amountDueCents;
      paidRob += e.paidRobCents;
      paidLau += e.paidLauCents;
      final pid = (e.propertyId == null || e.propertyId!.isEmpty)
          ? nonePropertyId
          : e.propertyId!;
      propSums[pid] = (propSums[pid] ?? 0) + e.amountDueCents;
      propCounts[pid] = (propCounts[pid] ?? 0) + 1;
      final cid = e.categoryId.isEmpty ? 'altro' : e.categoryId;
      catSums[cid] = (catSums[cid] ?? 0) + e.amountDueCents;
      catCounts[cid] = (catCounts[cid] ?? 0) + 1;
    }

    List<NamedAmount> named(
      Map<String, int> sums,
      Map<String, int> counts,
      String Function(String id) nameOf,
    ) {
      final items = [
        for (final id in sums.keys)
          NamedAmount(
            id: id,
            name: nameOf(id),
            amountCents: sums[id]!,
            count: counts[id] ?? 0,
          ),
      ]..sort((a, b) {
          final byAmount = b.amountCents.compareTo(a.amountCents);
          if (byAmount != 0) return byAmount;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return items;
    }

    return ReportSnapshot(
      period: period,
      expenses: filteredExpenses,
      transfers: filteredTransfers,
      tasks: filteredTasks,
      byProperty: named(propSums, propCounts, (id) {
        if (id == nonePropertyId) return 'Senza immobile';
        return propertyNames[id] ?? id;
      }),
      byCategory: named(catSums, catCounts, (id) => categoryNames[id] ?? id),
      totalDueCents: totalDue,
      paidRobCents: paidRob,
      paidLauCents: paidLau,
    );
  }
}

String expenseStatusLabel(ExpenseStatus status, {bool excel = false}) {
  if (excel) {
    return switch (status) {
      ExpenseStatus.daPagare => 'DA PAGARE',
      ExpenseStatus.parziale => 'PARZIALE',
      ExpenseStatus.pagato => 'PAGATO',
    };
  }
  return switch (status) {
    ExpenseStatus.daPagare => 'Da pagare',
    ExpenseStatus.parziale => 'Parziale',
    ExpenseStatus.pagato => 'Pagato',
  };
}

BalanceSnapshot periodBalance({
  required ReportSnapshot snapshot,
  required String robUid,
  required String lauUid,
  bool includeTransfers = true,
}) {
  return const BalanceCalculator().calculate(
    expenses: snapshot.expenses.map((e) => e.toBalanceInput()).toList(),
    transfers: includeTransfers
        ? snapshot.transfers.map((t) => t.toBalanceInput()).toList()
        : const [],
    robUid: robUid,
    lauUid: lauUid,
  );
}
