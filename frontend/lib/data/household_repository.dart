import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../features/auth/auth_models.dart';
import 'expense_models.dart';
import 'person_uid.dart';
import 'seed_data.dart';

class HouseholdRepository {
  HouseholdRepository({FirebaseFirestore? firestore}) : _db = firestore {
    _seedMemory();
  }

  final FirebaseFirestore? _db;
  final _uuid = const Uuid();
  final _catMemory = <String, CatalogCategory>{};
  final _propMemory = <String, CatalogProperty>{};
  final _catCtrl = StreamController<List<CatalogCategory>>.broadcast();
  final _propCtrl = StreamController<List<CatalogProperty>>.broadcast();

  bool get _available => _db != null;

  DocumentReference<Map<String, dynamic>> get _householdRef =>
      _db!.collection('households').doc(AppConfig.householdId);

  CollectionReference<Map<String, dynamic>> get _categories =>
      _householdRef.collection('categories');

  CollectionReference<Map<String, dynamic>> get _properties =>
      _householdRef.collection('properties');

  Future<Household?> fetchHousehold() async {
    if (!_available) return null;
    final snap = await _householdRef.get();
    if (!snap.exists || snap.data() == null) return null;
    return _fromDoc(snap.id, snap.data()!);
  }

  Future<void> ensureHouseholdDocument({
    List<String> memberEmails = AppConfig.defaultMemberEmails,
  }) async {
    if (!_available) return;
    final snap = await _householdRef.get();
    if (snap.exists) return;
    await _householdRef.set({
      'memberEmails': memberEmails,
      'members': <String, dynamic>{},
      'enableAttachments': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Household> ensureMember(AppUser user) async {
    await ensureHouseholdDocument();
    final household = await fetchHousehold();
    if (household == null) {
      throw StateError('Household mancante');
    }
    if (!household.isEmailAllowed(user.email)) {
      throw StateError('Email non autorizzata: ${user.email}');
    }
    if (household.members.containsKey(user.uid)) {
      await ensureSeedData();
      final current = (await fetchHousehold())!;
      await remapPlaceholderUids(current);
      return current;
    }

    final colorKey = _colorKeyForEmail(user.email, household.memberEmails);
    final member = HouseholdMember(
      uid: user.uid,
      name: user.displayName.isNotEmpty ? user.displayName : user.email,
      initial: user.initial,
      colorKey: colorKey,
    );

    await _householdRef.update({
      'members.${user.uid}': member.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await ensureSeedData();
    final updated = (await fetchHousehold())!;
    await remapPlaceholderUids(updated);
    return updated;
  }

  /// After Laura (or Roberto) joins, rewrite import placeholders `lau` / `rob`
  /// on expenses, transfers and tasks to the live Firebase uids.
  Future<int> remapPlaceholderUids(Household household) async {
    if (!_available) return 0;
    final replacements = <String, String>{
      if (household.robUid != PersonUid.rob) PersonUid.rob: household.robUid,
      if (household.lauUid != PersonUid.lau) PersonUid.lau: household.lauUid,
    };
    if (replacements.isEmpty) return 0;

    var n = 0;
    n += await _remapUidFields(
      _householdRef.collection('transfers'),
      const ['fromUid', 'toUid'],
      replacements,
    );
    n += await _remapExpensePayers(replacements);
    n += await _remapUidFields(
      _householdRef.collection('tasks'),
      const ['assigneeUid', 'doneBy', 'listOwnerUid'],
      replacements,
    );
    n += await _remapUidFields(
      _householdRef.collection('taskLists'),
      const ['ownerUid'],
      replacements,
    );
    if (n > 0) {
      debugPrint('Remapped placeholder person uids on $n documents');
    }
    return n;
  }

  Future<int> _remapUidFields(
    CollectionReference<Map<String, dynamic>> col,
    List<String> fields,
    Map<String, String> replacements,
  ) async {
    final snap = await col.get();
    final writes = <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final patch = <String, dynamic>{};
      for (final field in fields) {
        final current = data[field];
        if (current is String && replacements.containsKey(current)) {
          patch[field] = replacements[current];
        }
      }
      if (patch.isEmpty) continue;
      patch['updatedAt'] = FieldValue.serverTimestamp();
      writes[doc.reference] = patch;
    }
    await _commitPatches(writes);
    return writes.length;
  }

  Future<int> _remapExpensePayers(Map<String, String> replacements) async {
    final snap = await _householdRef.collection('expenses').get();
    final writes = <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final raw = data['payments'] as List<dynamic>? ?? const [];
      var changed = false;
      final payments = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final payer = map['payerUid'];
        if (payer is String && replacements.containsKey(payer)) {
          map['payerUid'] = replacements[payer];
          changed = true;
        }
        payments.add(map);
      }
      if (!changed) continue;
      writes[doc.reference] = {
        'payments': payments,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }
    await _commitPatches(writes);
    return writes.length;
  }

  Future<void> _commitPatches(
    Map<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>> writes,
  ) async {
    if (writes.isEmpty) return;
    const chunk = 400;
    final entries = writes.entries.toList();
    for (var i = 0; i < entries.length; i += chunk) {
      final batch = _db!.batch();
      final end = i + chunk > entries.length ? entries.length : i + chunk;
      for (final e in entries.sublist(i, end)) {
        batch.set(e.key, e.value, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Future<void> ensureSeedData() async {
    if (!_available) return;

    final cats = await _categories.limit(1).get();
    if (cats.docs.isEmpty) {
      final batch = _db!.batch();
      for (final c in SeedData.categories) {
        batch.set(_categories.doc(c.id), {
          'name': c.name,
          'order': c.order,
          'isDefault': true,
        });
      }
      await batch.commit();
      debugPrint('Seeded ${SeedData.categories.length} categories');
    }

    final props = await _properties.limit(1).get();
    if (props.docs.isEmpty) {
      final batch = _db!.batch();
      for (final p in SeedData.properties) {
        batch.set(_properties.doc(p.id), _seedPropertyMap(p));
      }
      await batch.commit();
      debugPrint('Seeded ${SeedData.properties.length} properties');
    } else {
      await _backfillKnownPropertyAddresses();
    }
  }

  Map<String, dynamic> _seedPropertyMap(
    ({
      String id,
      String name,
      String shortName,
      int order,
      String street,
      String houseNumber,
      String city,
    }) p,
  ) {
    return {
      'name': p.name,
      'shortName': p.shortName,
      'order': p.order,
      'street': p.street,
      'houseNumber': p.houseNumber,
      'interno': '',
      'scala': '',
      'floor': '',
      'postalCode': '',
      'city': p.city,
      'notes': '',
    };
  }

  /// Fills empty address fields on seeded properties without renaming them.
  Future<void> _backfillKnownPropertyAddresses() async {
    if (!_available) return;
    for (final p in SeedData.properties) {
      final snap = await _properties.doc(p.id).get();
      if (!snap.exists) continue;
      final data = snap.data();
      if (data == null) continue;
      final street = (data['street'] as String?)?.trim() ?? '';
      if (street.isNotEmpty) continue;
      final patch = <String, dynamic>{};
      if (p.street.isNotEmpty) patch['street'] = p.street;
      if (p.houseNumber.isNotEmpty &&
          ((data['houseNumber'] as String?)?.trim() ?? '').isEmpty) {
        patch['houseNumber'] = p.houseNumber;
      }
      if (p.city.isNotEmpty &&
          ((data['city'] as String?)?.trim() ?? '').isEmpty) {
        patch['city'] = p.city;
      }
      if (patch.isEmpty) continue;
      await _properties.doc(p.id).set(patch, SetOptions(merge: true));
    }
  }

  Stream<List<CatalogCategory>> watchCategories() {
    if (!_available) {
      return Stream<List<CatalogCategory>>.multi((listener) {
        listener.add(_activeCats());
        final sub = _catCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _categories.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => _categoryFrom(d.id, d.data()))
          .where((c) => !c.isDeleted)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return items;
    });
  }

  Stream<List<CatalogProperty>> watchProperties() {
    if (!_available) {
      return Stream<List<CatalogProperty>>.multi((listener) {
        listener.add(_activeProps());
        final sub = _propCtrl.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });
    }
    return _properties.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => _propertyFrom(d.id, d.data()))
          .where((p) => !p.isDeleted)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return items;
    });
  }

  Future<CatalogCategory> saveCategory(CatalogCategory draft) async {
    final isCreate = draft.id.isEmpty;
    final id = isCreate ? _uuid.v4() : draft.id;
    var order = draft.order;
    if (!_available && isCreate) {
      final live = _activeCats();
      order = live.isEmpty
          ? 0
          : live.map((c) => c.order).reduce((a, b) => a > b ? a : b) + 1;
    }
    final saved = CatalogCategory(
      id: id,
      name: draft.name.trim(),
      order: order,
      isDefault: isCreate ? false : draft.isDefault,
      deletedAt: draft.deletedAt,
    );

    if (!_available) {
      _catMemory[id] = saved;
      _catCtrl.add(_activeCats());
      return saved;
    }

    await _categories.doc(id).set({
      'name': saved.name,
      'order': saved.order,
      'isDefault': saved.isDefault,
      'deletedAt': saved.deletedAt == null
          ? null
          : Timestamp.fromDate(saved.deletedAt!),
    }, SetOptions(merge: true));
    return saved;
  }

  Future<CatalogProperty> saveProperty(CatalogProperty draft) async {
    final isCreate = draft.id.isEmpty;
    final id = isCreate ? _uuid.v4() : draft.id;
    var order = draft.order;
    if (!_available && isCreate) {
      final live = _activeProps();
      order = live.isEmpty
          ? 0
          : live.map((p) => p.order).reduce((a, b) => a > b ? a : b) + 1;
    }
    final name = draft.name.trim();
    final saved = CatalogProperty(
      id: id,
      name: name,
      shortName: draft.shortName.trim().isEmpty ? name : draft.shortName.trim(),
      order: order,
      street: draft.street.trim(),
      houseNumber: draft.houseNumber.trim(),
      interno: draft.interno.trim(),
      scala: draft.scala.trim(),
      floor: draft.floor.trim(),
      postalCode: draft.postalCode.trim(),
      city: draft.city.trim(),
      notes: draft.notes.trim(),
      deletedAt: draft.deletedAt,
    );

    if (!_available) {
      _propMemory[id] = saved;
      _propCtrl.add(_activeProps());
      return saved;
    }

    await _properties.doc(id).set({
      ...saved.toMap(),
      'deletedAt': saved.deletedAt == null
          ? null
          : Timestamp.fromDate(saved.deletedAt!),
    }, SetOptions(merge: true));
    return saved;
  }

  Future<void> reorderCategories(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final current = _catMemory[ids[i]];
      if (!_available) {
        if (current == null) continue;
        _catMemory[ids[i]] = current.copyWith(order: i);
      } else {
        await _categories.doc(ids[i]).set(
          {'order': i},
          SetOptions(merge: true),
        );
      }
    }
    if (!_available) _catCtrl.add(_activeCats());
  }

  Future<void> reorderProperties(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final current = _propMemory[ids[i]];
      if (!_available) {
        if (current == null) continue;
        _propMemory[ids[i]] = current.copyWith(order: i);
      } else {
        await _properties.doc(ids[i]).set(
          {'order': i},
          SetOptions(merge: true),
        );
      }
    }
    if (!_available) _propCtrl.add(_activeProps());
  }

  Future<void> archiveCategory(String id) async {
    if (!_available) {
      final current = _catMemory[id];
      if (current == null || current.isDefault) return;
      _catMemory[id] = current.copyWith(deletedAt: DateTime.now());
      _catCtrl.add(_activeCats());
      return;
    }
    final snap = await _categories.doc(id).get();
    if (snap.data()?['isDefault'] == true) return;
    await _categories.doc(id).set({
      'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> archiveProperty(String id) async {
    if (!_available) {
      final current = _propMemory[id];
      if (current == null) return;
      _propMemory[id] = current.copyWith(deletedAt: DateTime.now());
      _propCtrl.add(_activeProps());
      return;
    }
    await _properties.doc(id).set({
      'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void dispose() {
    _catCtrl.close();
    _propCtrl.close();
  }

  void _seedMemory() {
    for (final c in SeedData.categories) {
      _catMemory[c.id] = CatalogCategory(
        id: c.id,
        name: c.name,
        order: c.order,
        isDefault: true,
      );
    }
    for (final p in SeedData.properties) {
      _propMemory[p.id] = CatalogProperty(
        id: p.id,
        name: p.name,
        shortName: p.shortName,
        order: p.order,
        street: p.street,
        houseNumber: p.houseNumber,
        city: p.city,
      );
    }
  }

  List<CatalogCategory> _activeCats() => _catMemory.values
      .where((c) => !c.isDeleted)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  List<CatalogProperty> _activeProps() => _propMemory.values
      .where((p) => !p.isDeleted)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  CatalogCategory _categoryFrom(String id, Map<String, dynamic> data) {
    return CatalogCategory(
      id: id,
      name: data['name'] as String? ?? id,
      order: (data['order'] as num?)?.toInt() ?? 0,
      isDefault: data['isDefault'] as bool? ??
          SeedData.categories.any((c) => c.id == id),
      deletedAt: _readDate(data['deletedAt']),
    );
  }

  CatalogProperty _propertyFrom(String id, Map<String, dynamic> data) {
    return CatalogProperty.fromMap(id, data).copyWith(
      deletedAt: _readDate(data['deletedAt']),
    );
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  ColorKey _colorKeyForEmail(String email, List<String> memberEmails) {
    final idx = memberEmails
        .indexWhere((e) => e.toLowerCase() == email.toLowerCase());
    if (idx <= 0) return ColorKey.rob;
    return ColorKey.lau;
  }

  Household _fromDoc(String id, Map<String, dynamic> data) {
    final emails = (data['memberEmails'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final rawMembers = data['members'] as Map<String, dynamic>? ?? {};
    final members = <String, HouseholdMember>{};
    for (final entry in rawMembers.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        members[entry.key] = HouseholdMember.fromMap(entry.key, value);
      } else if (value is Map) {
        members[entry.key] = HouseholdMember.fromMap(
          entry.key,
          Map<String, dynamic>.from(value),
        );
      }
    }
    return Household(
      id: id,
      memberEmails: emails,
      members: members,
      enableAttachments: data['enableAttachments'] as bool? ?? false,
    );
  }
}
