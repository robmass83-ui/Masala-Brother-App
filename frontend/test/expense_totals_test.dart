import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/balance_calculator.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/features/expenses/payer_dialog.dart';

void main() {
  test('withTotals denormalizes payments and status', () {
    final dated = Expense(
      id: 'e1',
      description: 'Bolletta',
      amountDueCents: 10000,
      date: DateTime(2026, 9, 5),
      categoryId: 'bollette',
      payments: [
        ExpensePayment(
          id: 'p1',
          payerUid: 'rob',
          amountCents: 4000,
          date: DateTime(2026, 9, 5),
        ),
      ],
    ).withTotals(robUid: 'rob', lauUid: 'lau');

    expect(dated.paidRobCents, 4000);
    expect(dated.paidLauCents, 0);
    expect(dated.paidTotalCents, 4000);
    expect(dated.status, ExpenseStatus.parziale);
    expect(dated.missingCents, 6000);
  });

  test('withTotals counts import placeholder payments after Laura joins', () {
    final dated = Expense(
      id: 'e1',
      description: 'Bolletta',
      amountDueCents: 10000,
      date: DateTime(2026, 9, 5),
      categoryId: 'bollette',
      payments: [
        ExpensePayment(
          id: 'p1',
          payerUid: 'lau',
          amountCents: 10000,
          date: DateTime(2026, 9, 5),
        ),
      ],
    ).withTotals(robUid: 'firebase-rob', lauUid: 'firebase-lau');

    expect(dated.paidLauCents, 10000);
    expect(dated.paidRobCents, 0);
    expect(dated.status, ExpenseStatus.pagato);
  });

  test('splitAmongSelected divides the total when both pay', () {
    final both = splitAmongSelected(
      totalCents: 250000,
      rob: true,
      lau: true,
      robUid: 'rob',
      lauUid: 'lau',
    );
    expect(both.map((p) => p.amountCents).toList(), [125000, 125000]);

    final odd = splitAmongSelected(
      totalCents: 101,
      rob: true,
      lau: true,
      robUid: 'rob',
      lauUid: 'lau',
    );
    expect(odd.first.amountCents + odd.last.amountCents, 101);

    final onlyRob = splitAmongSelected(
      totalCents: 5000,
      rob: true,
      lau: false,
      robUid: 'rob',
      lauUid: 'lau',
    );
    expect(onlyRob.single.payerUid, 'rob');
    expect(onlyRob.single.amountCents, 5000);
  });
}
