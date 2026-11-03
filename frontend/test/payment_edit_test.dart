import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/expense_repository.dart';

ExpensePayment _pay(String id, String payer, int cents, {int day = 1}) =>
    ExpensePayment(
      id: id,
      payerUid: payer,
      amountCents: cents,
      date: DateTime(2026, 9, day),
      method: PaymentMethod.values.first,
    );

Expense _expense(List<ExpensePayment> payments) => Expense(
      id: '',
      description: 'Bolletta',
      amountDueCents: 10000,
      date: DateTime(2026, 9, 1),
      categoryId: 'bollette',
      payments: payments,
    );

void main() {
  group('reconcilePayments', () {
    final repo = ExpenseRepository();

    test('resizes the payer\'s payment keeping id and date', () {
      final out = repo.reconcilePayments(
        existing: [_pay('p1', 'rob', 3000, day: 5)],
        targets: {'rob': 4500},
      );
      expect(out, hasLength(1));
      expect(out.single.id, 'p1');
      expect(out.single.amountCents, 4500);
      expect(out.single.date, DateTime(2026, 9, 5));
    });

    test('keeps several payments untouched when the sum is unchanged', () {
      final existing = [_pay('p1', 'rob', 2000), _pay('p2', 'rob', 1000)];
      final out = repo.reconcilePayments(
        existing: existing,
        targets: {'rob': 3000},
      );
      expect(out.map((p) => p.id), ['p1', 'p2']);
    });

    test('collapses into the first payment when the sum changes', () {
      final out = repo.reconcilePayments(
        existing: [_pay('p1', 'rob', 2000), _pay('p2', 'rob', 1000)],
        targets: {'rob': 5000},
      );
      expect(out, hasLength(1));
      expect(out.single.id, 'p1');
      expect(out.single.amountCents, 5000);
    });

    test('adds the new payer and drops the one no longer paying', () {
      final out = repo.reconcilePayments(
        existing: [_pay('p1', 'rob', 3000)],
        targets: {'lau': 2000},
      );
      expect(out, hasLength(1));
      expect(out.single.payerUid, 'lau');
      expect(out.single.amountCents, 2000);
    });

    test('custom split between both', () {
      final out = repo.reconcilePayments(
        existing: [_pay('p1', 'rob', 5000), _pay('p2', 'lau', 5000)],
        targets: {'rob': 7000, 'lau': 3000},
      );
      expect(out.map((p) => (p.id, p.amountCents)), [('p1', 7000), ('p2', 3000)]);
    });
  });

  group('replacePayment', () {
    test('changes the amount and keeps the rest', () async {
      final repo = ExpenseRepository();
      final saved = await repo.save(
        draft: _expense([_pay('p1', 'rob', 3000, day: 5), _pay('p2', 'lau', 1000)]),
        actorUid: 'rob',
        robUid: 'rob',
        lauUid: 'lau',
      );
      final out = await repo.replacePayment(
        expense: saved,
        paymentId: 'p1',
        parts: [(payerUid: 'rob', amountCents: 4000)],
        actorUid: 'rob',
        robUid: 'rob',
        lauUid: 'lau',
      );
      expect(out.payments.map((p) => (p.id, p.amountCents)), [('p1', 4000), ('p2', 1000)]);
      expect(out.payments.first.date, DateTime(2026, 9, 5));
      expect(out.paidRobCents, 4000);
      expect(out.paidTotalCents, 5000);
    });

    test('splits one payment between both', () async {
      final repo = ExpenseRepository();
      final saved = await repo.save(
        draft: _expense([_pay('p1', 'lau', 6000)]),
        actorUid: 'rob',
        robUid: 'rob',
        lauUid: 'lau',
      );
      final out = await repo.replacePayment(
        expense: saved,
        paymentId: 'p1',
        parts: [
          (payerUid: 'rob', amountCents: 2000),
          (payerUid: 'lau', amountCents: 4000),
        ],
        actorUid: 'rob',
        robUid: 'rob',
        lauUid: 'lau',
      );
      expect(out.payments, hasLength(2));
      final lau = out.payments.firstWhere((p) => p.payerUid == 'lau');
      expect(lau.id, 'p1');
      expect(lau.amountCents, 4000);
      expect(out.paidRobCents, 2000);
    });
  });
}
