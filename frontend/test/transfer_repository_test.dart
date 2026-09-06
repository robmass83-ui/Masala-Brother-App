import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/transfer_models.dart';
import 'package:brotherapp/data/transfer_repository.dart';

void main() {
  test('TransferValidation rejects zero amount and same people', () {
    expect(
      TransferValidation.validate(
        amountCents: 0,
        date: DateTime(2026, 9, 5),
        fromUid: 'lau',
        toUid: 'rob',
      ),
      isNotNull,
    );
    expect(
      TransferValidation.validate(
        amountCents: 100,
        date: DateTime(2026, 9, 5),
        fromUid: 'rob',
        toUid: 'rob',
      ),
      isNotNull,
    );
    expect(
      TransferValidation.validate(
        amountCents: 100,
        date: DateTime(2026, 9, 5),
        fromUid: 'lau',
        toUid: 'rob',
      ),
      isNull,
    );
  });

  test('TransferValidation rejects dates more than a year ahead', () {
    expect(
      TransferValidation.validate(
        amountCents: 100,
        date: DateTime.now().add(const Duration(days: 400)),
        fromUid: 'lau',
        toUid: 'rob',
      ),
      isNotNull,
    );
  });

  test('in-memory repository save, stream, soft delete and restore', () async {
    final repo = TransferRepository();
    addTearDown(repo.dispose);

    final events = <int>[];
    final sub = repo.watchTransfers().listen((list) => events.add(list.length));
    addTearDown(sub.cancel);

    await pumpEventQueue();
    expect(events, isNotEmpty);
    expect(events.last, 0);

    final saved = await repo.save(
      draft: Transfer(
        id: '',
        fromUid: 'demo-laura',
        toUid: 'demo-roberto',
        amountCents: 438650,
        date: DateTime(2026, 9, 5),
        note: 'Conguaglio',
      ),
      actorUid: 'demo-roberto',
    );
    await pumpEventQueue();
    expect(saved.id, isNotEmpty);
    expect(saved.amountCents, 438650);
    expect(events.last, 1);

    await repo.softDelete(saved.id, 'demo-roberto');
    await pumpEventQueue();
    expect(events.last, 0);

    await repo.restore(saved.id, 'demo-roberto');
    await pumpEventQueue();
    expect(events.last, 1);
    expect(
      (await repo.watchTransfers().first).single.note,
      'Conguaglio',
    );
  });

  test('toBalanceInput marks deleted transfers', () {
    final live = Transfer(
      id: 't1',
      fromUid: 'lau',
      toUid: 'rob',
      amountCents: 100,
      date: DateTime(2026, 1, 1),
    ).toBalanceInput();
    expect(live.deleted, isFalse);

    final gone = Transfer(
      id: 't2',
      fromUid: 'lau',
      toUid: 'rob',
      amountCents: 100,
      date: DateTime(2026, 1, 1),
      deletedAt: DateTime(2026, 1, 2),
    ).toBalanceInput();
    expect(gone.deleted, isTrue);
  });
}
