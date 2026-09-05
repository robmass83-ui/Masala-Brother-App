import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../features/auth/auth_models.dart';
import 'seed_data.dart';

class HouseholdRepository {
  HouseholdRepository({FirebaseFirestore? firestore}) : _db = firestore;

  final FirebaseFirestore? _db;

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
      return (await fetchHousehold())!;
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
    return (await fetchHousehold())!;
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
        batch.set(_properties.doc(p.id), {
          'name': p.name,
          'shortName': p.shortName,
          'order': p.order,
        });
      }
      await batch.commit();
      debugPrint('Seeded ${SeedData.properties.length} properties');
    }
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
