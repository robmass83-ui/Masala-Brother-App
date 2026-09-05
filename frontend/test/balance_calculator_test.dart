import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/balance_calculator.dart';

void main() {
  const calc = BalanceCalculator();
  const rob = 'rob';
  const lau = 'lau';

  test('example totals: Laura owes Roberto € 4.386,50', () {
    final snap = calc.calculate(
      expenses: const [
        ExpenseBalanceInput(
          amountDueCents: 9764138,
          paidRobCents: 5320719,
          paidLauCents: 4443419,
        ),
      ],
      transfers: const [],
      robUid: rob,
      lauUid: lau,
    );

    expect(snap.paidRobCents, 5320719);
    expect(snap.paidLauCents, 4443419);
    expect(snap.totalPaidCents, 9764138);
    expect(snap.halfEachCents, 4882069);
    expect(snap.creditRobCents, 438650);
    expect(snap.lauraOwesRoberto, isTrue);
  });

  test('50/50 credit equals half the paid difference', () {
    final snap = calc.calculate(
      expenses: const [
        ExpenseBalanceInput(
          amountDueCents: 10000,
          paidRobCents: 10000,
          paidLauCents: 0,
        ),
        ExpenseBalanceInput(
          amountDueCents: 4000,
          paidRobCents: 0,
          paidLauCents: 4000,
        ),
      ],
      transfers: const [],
      robUid: rob,
      lauUid: lau,
    );
    expect(snap.creditRobCents, 3000);
    expect(snap.creditRobCents, (snap.paidRobCents - snap.paidLauCents) ~/ 2);
  });

  test('transfer Rob→Lau increases creditRob', () {
    final after = calc.calculate(
      expenses: const [],
      transfers: const [
        TransferBalanceInput(fromUid: rob, toUid: lau, amountCents: 150000),
      ],
      robUid: rob,
      lauUid: lau,
    );
    expect(after.creditRobCents, 150000);
    expect(after.paidRobCents, 150000);
    expect(after.paidLauCents, -150000);
  });

  test('unpaid expense does not move credit', () {
    final snap = calc.calculate(
      expenses: const [
        ExpenseBalanceInput(
          amountDueCents: 50000,
          paidRobCents: 0,
          paidLauCents: 0,
        ),
      ],
      transfers: const [],
      robUid: rob,
      lauUid: lau,
    );
    expect(snap.totalDueCents, 50000);
    expect(snap.creditRobCents, 0);
  });

  test('odd cent share favors higher payer via truncation', () {
    final snap = calc.calculate(
      expenses: const [
        ExpenseBalanceInput(
          amountDueCents: 101,
          paidRobCents: 101,
          paidLauCents: 0,
        ),
      ],
      transfers: const [],
      robUid: rob,
      lauUid: lau,
    );
    expect(snap.creditRobCents, 51);
  });

  test('expenseStatus mapping', () {
    expect(
      expenseStatus(amountDueCents: 100, paidTotalCents: 0),
      ExpenseStatus.daPagare,
    );
    expect(
      expenseStatus(amountDueCents: 100, paidTotalCents: 40),
      ExpenseStatus.parziale,
    );
    expect(
      expenseStatus(amountDueCents: 100, paidTotalCents: 100),
      ExpenseStatus.pagato,
    );
  });
}
