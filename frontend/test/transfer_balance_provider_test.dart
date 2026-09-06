import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/data_providers.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/transfer_models.dart';
import 'package:brotherapp/features/auth/auth_providers.dart';
import 'package:brotherapp/features/auth/auth_repository.dart';

void main() {
  test('balanceProvider includes transfers from the in-memory repository', () async {
    final auth = AuthRepository(forceDemo: true);
    final session = await auth.signInWithGoogle();
    final household = session.household!;

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => auth),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);

    container.listen(authSessionProvider, (_, __) {});
    container.listen(expensesProvider, (_, __) {});
    container.listen(transfersProvider, (_, __) {});
    await container.read(authSessionProvider.future);
    await container.read(expensesProvider.future);
    await container.read(transfersProvider.future);

    await container.read(expenseRepositoryProvider).save(
          draft: Expense(
            id: '',
            description: 'Acconto',
            amountDueCents: 10000,
            date: DateTime(2026, 9, 1),
            categoryId: 'altro',
            payments: [
              ExpensePayment(
                id: 'p1',
                payerUid: household.robUid,
                amountCents: 10000,
                date: DateTime(2026, 9, 1),
              ),
            ],
          ),
          actorUid: household.robUid,
          robUid: household.robUid,
          lauUid: household.lauUid,
        );
    await pumpEventQueue();

    var snap = container.read(balanceProvider);
    expect(snap.creditRobCents, 5000);
    expect(snap.lauraOwesRoberto, isTrue);

    await container.read(transferRepositoryProvider).save(
          draft: Transfer(
            id: '',
            fromUid: household.lauUid,
            toUid: household.robUid,
            amountCents: 5000,
            date: DateTime(2026, 9, 5),
            note: 'Pareggio',
          ),
          actorUid: household.robUid,
        );
    await pumpEventQueue();

    snap = container.read(balanceProvider);
    expect(snap.creditRobCents, 0);
    expect(snap.isEven, isTrue);
  });
}
