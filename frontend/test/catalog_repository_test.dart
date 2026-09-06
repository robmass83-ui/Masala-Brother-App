import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/household_repository.dart';
import 'package:brotherapp/data/expense_models.dart';

void main() {
  test('memory catalog starts from seed and supports add, rename, reorder, archive',
      () async {
    final repo = HouseholdRepository();
    addTearDown(repo.dispose);

    final cats = await repo.watchCategories().first;
    expect(cats.map((c) => c.id), containsAll(['bollette', 'altro']));
    expect(cats.firstWhere((c) => c.id == 'bollette').isDefault, isTrue);

    final added = await repo.saveCategory(
      const CatalogCategory(id: '', name: 'Giardino', order: 0),
    );
    expect(added.id, isNotEmpty);
    expect(added.isDefault, isFalse);

    final afterAdd = await repo.watchCategories().first;
    expect(afterAdd.map((c) => c.name), contains('Giardino'));

    await repo.saveCategory(added.copyWith(name: 'Giardino e piante'));
    expect(
      (await repo.watchCategories().first)
          .firstWhere((c) => c.id == added.id)
          .name,
      'Giardino e piante',
    );

    final ids = [
      added.id,
      ...afterAdd.where((c) => c.id != added.id).map((c) => c.id),
    ];
    await repo.reorderCategories(ids);
    expect((await repo.watchCategories().first).first.id, added.id);

    await repo.archiveCategory(added.id);
    expect(
      (await repo.watchCategories().first).map((c) => c.id),
      isNot(contains(added.id)),
    );

    await repo.archiveCategory('bollette');
    expect(
      (await repo.watchCategories().first).map((c) => c.id),
      contains('bollette'),
    );
  });

  test('memory properties add and archive', () async {
    final repo = HouseholdRepository();
    addTearDown(repo.dispose);

    final added = await repo.saveProperty(
      const CatalogProperty(
        id: '',
        name: 'Via Roma',
        shortName: 'Roma',
        order: 0,
      ),
    );
    expect(
      (await repo.watchProperties().first).map((p) => p.id),
      contains(added.id),
    );
    await repo.archiveProperty(added.id);
    expect(
      (await repo.watchProperties().first).map((p) => p.id),
      isNot(contains(added.id)),
    );
  });

  test('property list label stays the name; detail builds the address line', () {
    const property = CatalogProperty(
      id: 'forlanini',
      name: 'Via Forlanini',
      shortName: 'Forlanini',
      order: 0,
      street: 'Via Forlanini',
      houseNumber: '9',
      interno: '4',
      scala: 'B',
      floor: '2',
      postalCode: '20134',
      city: 'Milano',
    );
    expect(property.name, 'Via Forlanini');
    expect(
      property.addressLine,
      'Via Forlanini 9 · interno 4 · scala B · piano 2 · 20134 Milano',
    );
    expect(property.listSubtitle, property.addressLine);
  });

  test('memory properties persist street and civic number', () async {
    final repo = HouseholdRepository();
    addTearDown(repo.dispose);

    final added = await repo.saveProperty(
      const CatalogProperty(
        id: '',
        name: 'Via Forlanini',
        shortName: 'Forlanini',
        order: 0,
        street: 'Via Forlanini',
        houseNumber: '12',
        interno: '3',
        city: 'Milano',
        notes: 'Secondo piano',
      ),
    );
    final saved = (await repo.watchProperties().first)
        .firstWhere((p) => p.id == added.id);
    expect(saved.name, 'Via Forlanini');
    expect(saved.street, 'Via Forlanini');
    expect(saved.houseNumber, '12');
    expect(saved.interno, '3');
    expect(saved.city, 'Milano');
    expect(saved.notes, 'Secondo piano');
    expect(saved.addressLine, 'Via Forlanini 12 · interno 3 · Milano');
  });
}
