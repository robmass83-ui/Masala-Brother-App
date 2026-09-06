import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/balance_calculator.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/report_aggregator.dart';
import 'package:brotherapp/data/report_period.dart';
import 'package:brotherapp/data/task_models.dart';
import 'package:brotherapp/data/transfer_models.dart';

Expense _expense({
  required String id,
  required DateTime date,
  required int due,
  int rob = 0,
  int lau = 0,
  String categoryId = 'bollette',
  String? propertyId = 'forlanini',
  bool deleted = false,
}) {
  final total = rob + lau;
  return Expense(
    id: id,
    description: id,
    amountDueCents: due,
    date: date,
    categoryId: categoryId,
    propertyId: propertyId,
    paidRobCents: rob,
    paidLauCents: lau,
    paidTotalCents: total,
    status: expenseStatus(amountDueCents: due, paidTotalCents: total),
    deletedAt: deleted ? date : null,
  );
}

void main() {
  const agg = ReportAggregator();

  test('current year keeps only expenses in that year', () {
    final period = ReportPeriod.currentYear(now: DateTime(2026, 9, 5));
    final snap = agg.build(
      expenses: [
        _expense(id: 'a', date: DateTime(2025, 12, 31), due: 1000, rob: 1000),
        _expense(id: 'b', date: DateTime(2026, 1, 1), due: 2000, rob: 2000),
        _expense(id: 'c', date: DateTime(2026, 12, 31), due: 3000, lau: 3000),
        _expense(id: 'd', date: DateTime(2027, 1, 1), due: 4000, lau: 4000),
      ],
      transfers: const [],
      tasks: const [],
      period: period,
    );
    expect(snap.expenseCount, 2);
    expect(snap.totalDueCents, 5000);
    expect(snap.paidRobCents, 2000);
    expect(snap.paidLauCents, 3000);
  });

  test('all includes every non-deleted expense', () {
    final snap = agg.build(
      expenses: [
        _expense(id: 'a', date: DateTime(2023, 1, 1), due: 100, rob: 100),
        _expense(
          id: 'gone',
          date: DateTime(2026, 1, 1),
          due: 999,
          rob: 999,
          deleted: true,
        ),
      ],
      transfers: const [],
      tasks: const [],
      period: ReportPeriod.all(),
    );
    expect(snap.expenseCount, 1);
    expect(snap.totalDueCents, 100);
  });

  test('groups by property and category, sorted by amount', () {
    final snap = agg.build(
      expenses: [
        _expense(
          id: '1',
          date: DateTime(2026, 2, 1),
          due: 10000,
          rob: 10000,
          propertyId: 'forlanini',
          categoryId: 'lavori',
        ),
        _expense(
          id: '2',
          date: DateTime(2026, 3, 1),
          due: 2000,
          lau: 2000,
          propertyId: 'addis',
          categoryId: 'bollette',
        ),
        _expense(
          id: '3',
          date: DateTime(2026, 4, 1),
          due: 500,
          rob: 500,
          propertyId: null,
          categoryId: 'bollette',
        ),
      ],
      transfers: const [],
      tasks: const [],
      period: ReportPeriod.all(),
      categoryNames: const {
        'lavori': 'Lavori e fatture',
        'bollette': 'Bollette',
      },
      propertyNames: const {
        'forlanini': 'Forlanini 9',
        'addis': 'Via Addis',
      },
    );
    expect(snap.byProperty.first.name, 'Forlanini 9');
    expect(snap.byProperty.first.amountCents, 10000);
    expect(snap.byProperty.last.name, 'Senza immobile');
    expect(snap.byCategory.first.name, 'Lavori e fatture');
    expect(snap.byCategory.last.name, 'Bollette');
    expect(snap.byCategory.last.amountCents, 2500);
  });

  test('unpaidOrPartialOnly drops pagato expenses', () {
    final snap = agg.build(
      expenses: [
        _expense(id: 'paid', date: DateTime(2026, 1, 1), due: 100, rob: 100),
        _expense(id: 'open', date: DateTime(2026, 1, 2), due: 200, rob: 50),
      ],
      transfers: const [],
      tasks: const [],
      period: ReportPeriod.all(),
      unpaidOrPartialOnly: true,
    );
    expect(snap.expenses.single.id, 'open');
    expect(snap.paidRobCents, 50);
  });

  test('transfers are filtered by period independently of expenses', () {
    final snap = agg.build(
      expenses: const [],
      transfers: [
        Transfer(
          id: 't1',
          fromUid: 'rob',
          toUid: 'lau',
          amountCents: 150000,
          date: DateTime(2026, 6, 1),
        ),
        Transfer(
          id: 't2',
          fromUid: 'lau',
          toUid: 'rob',
          amountCents: 1000,
          date: DateTime(2025, 1, 1),
        ),
      ],
      tasks: const [],
      period: ReportPeriod.currentYear(now: DateTime(2026, 9, 1)),
    );
    expect(snap.transfers.single.id, 't1');
  });

  test('period balance on filtered rows matches calculator', () {
    final snap = agg.build(
      expenses: [
        _expense(id: 'a', date: DateTime(2026, 1, 1), due: 10000, rob: 10000),
        _expense(id: 'b', date: DateTime(2026, 2, 1), due: 4000, lau: 4000),
      ],
      transfers: [
        Transfer(
          id: 't',
          fromUid: 'lau',
          toUid: 'rob',
          amountCents: 1000,
          date: DateTime(2026, 3, 1),
        ),
      ],
      tasks: [
        HouseholdTask(id: 'k', title: 'Chiama notaio'),
      ],
      period: ReportPeriod.all(),
    );
    final bal = periodBalance(
      snapshot: snap,
      robUid: 'rob',
      lauUid: 'lau',
    );
    expect(bal.creditRobCents, (10000 - 4000) ~/ 2 - 1000);
    expect(snap.tasks.single.title, 'Chiama notaio');
  });
}
