import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/widgets/discard_guard.dart';
import 'package:brotherapp/data/balance_calculator.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/expense_repository.dart';
import 'package:brotherapp/data/local_first.dart';
import 'package:brotherapp/features/export/pdf_exporter.dart';

/// Regression tests for the November 2026 functional audit.
void main() {
  group('localFirst', () {
    test('returns after the grace period when the server never answers', () async {
      final never = Completer<void>().future;
      final sw = Stopwatch()..start();
      await localFirst(never, grace: const Duration(milliseconds: 50));
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('rethrows an error that arrives within the grace period', () async {
      final failing = Future<void>.error(StateError('rifiutato'));
      expect(
        () => localFirst(failing, grace: const Duration(seconds: 1)),
        throwsStateError,
      );
    });
  });

  group('payments', () {
    Future<(ExpenseRepository, Expense)> seed() async {
      final repo = ExpenseRepository();
      final e = await repo.save(
        draft: Expense(
          id: '',
          description: 'Condominio',
          amountDueCents: 10000,
          date: DateTime(2026, 3, 1),
          categoryId: 'condominio',
        ),
        actorUid: 'rob',
        robUid: 'rob',
        lauUid: 'lau',
      );
      return (repo, e);
    }

    test('a split payment is saved in one go', () async {
      final (repo, e) = await seed();
      final saved = await repo.addPayments(
        expense: e,
        parts: const [
          (payerUid: 'rob', amountCents: 6000),
          (payerUid: 'lau', amountCents: 4000),
        ],
        actorUid: 'rob',
        robUid: 'rob',
        lauUid: 'lau',
      );
      expect(saved.payments, hasLength(2));
      expect(saved.paidRobCents, 6000);
      expect(saved.paidLauCents, 4000);
      expect(saved.status, ExpenseStatus.pagato);
    });

    test('a payment added from an old screen keeps the other person\'s one',
        () async {
      final (repo, stale) = await seed();
      // The other person pays meanwhile…
      await repo.addPayment(
        expense: stale,
        payment: repo.newPayment(payerUid: 'lau', amountCents: 3000),
        actorUid: 'lau',
        robUid: 'rob',
        lauUid: 'lau',
      );
      // …and this screen still holds the version without that payment.
      final saved = await repo.addPayments(
        expense: stale,
        parts: const [(payerUid: 'rob', amountCents: 2000)],
        actorUid: 'rob',
        robUid: 'rob',
        lauUid: 'lau',
      );
      expect(saved.paidLauCents, 3000);
      expect(saved.paidRobCents, 2000);
    });
  });

  group('balance with a custom split', () {
    const calc = BalanceCalculator();

    int credit(int robPaid, int lauPaid, int pct) => calc
        .calculate(
          expenses: [
            ExpenseBalanceInput(
              amountDueCents: robPaid + lauPaid,
              paidRobCents: robPaid,
              paidLauCents: lauPaid,
              shareRobPct: pct,
            ),
            // Forces the per-expense path (a non-50% share exists).
            const ExpenseBalanceInput(
              amountDueCents: 0,
              paidRobCents: 0,
              paidLauCents: 0,
              shareRobPct: 30,
            ),
          ],
          transfers: const [],
          robUid: 'rob',
          lauUid: 'lau',
        )
        .creditRobCents;

    test('the odd cent stays with whoever paid, Roberto or Laura', () {
      // € 1,01 at 50%: the payer is credited 51 cents either way.
      expect(credit(101, 0, 50), 51);
      expect(credit(0, 101, 50), -51);
    });
  });

  test('PDF text is reduced to characters the built-in font has', () {
    expect(pdfSafe('L’Enel – “luce” € 5…'),
        "L'Enel - \"luce\" EUR 5...");
    expect(pdfSafe('Caffè città'), 'Caffè città');
    expect(pdfSafe('Casa \u{1F3E0}'), 'Casa ?');
  });

  group('DiscardGuard', () {
    Future<void> pumpGuarded(WidgetTester tester, {required bool dirty}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DiscardGuard(
                      isDirty: () => dirty,
                      child: Builder(
                        builder: (ctx) => Scaffold(
                          appBar: AppBar(
                            leading: BackButton(
                              onPressed: () => DiscardGuard.back(ctx),
                            ),
                          ),
                          body: const Text('modulo'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
    }

    testWidgets('leaves at once when nothing was typed', (tester) async {
      await pumpGuarded(tester, dirty: false);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('modulo'), findsNothing);
    });

    testWidgets('asks before throwing away what was typed', (tester) async {
      await pumpGuarded(tester, dirty: true);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Scartare le modifiche?'), findsOneWidget);

      await tester.tap(find.text('Continua a modificare'));
      await tester.pumpAndSettle();
      expect(find.text('modulo'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scarta'));
      await tester.pumpAndSettle();
      expect(find.text('modulo'), findsNothing);
    });
  });
}
