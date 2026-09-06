import 'package:flutter/foundation.dart';

enum ColorKey { rob, lau }

@immutable
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  String get initial {
    final n = displayName.trim();
    if (n.isNotEmpty) return n[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }
}

@immutable
class HouseholdMember {
  const HouseholdMember({
    required this.uid,
    required this.name,
    required this.initial,
    required this.colorKey,
  });

  final String uid;
  final String name;
  final String initial;
  final ColorKey colorKey;

  Map<String, dynamic> toMap() => {
        'name': name,
        'initial': initial,
        'colorKey': colorKey == ColorKey.rob ? 'rob' : 'lau',
      };

  factory HouseholdMember.fromMap(String uid, Map<String, dynamic> map) {
    final key = map['colorKey'] as String? ?? 'rob';
    return HouseholdMember(
      uid: uid,
      name: map['name'] as String? ?? '',
      initial: map['initial'] as String? ?? '?',
      colorKey: key == 'lau' ? ColorKey.lau : ColorKey.rob,
    );
  }
}

@immutable
class Household {
  const Household({
    required this.id,
    required this.memberEmails,
    required this.members,
    this.enableAttachments = false,
  });

  final String id;
  final List<String> memberEmails;
  final Map<String, HouseholdMember> members;
  final bool enableAttachments;

  bool isEmailAllowed(String email) {
    final lower = email.toLowerCase();
    return memberEmails.any((e) => e.toLowerCase() == lower);
  }

  String get robUid {
    for (final e in members.entries) {
      if (e.value.colorKey == ColorKey.rob) return e.key;
    }
    return members.keys.isEmpty ? 'rob' : members.keys.first;
  }

  String get lauUid {
    for (final e in members.entries) {
      if (e.value.colorKey == ColorKey.lau) return e.key;
    }
    if (members.length > 1) return members.keys.elementAt(1);
    return 'lau';
  }

  HouseholdMember? memberByUid(String uid) => members[uid];

  /// True for Laura's live uid, the import placeholder `lau`, or her colorKey.
  bool isLauUid(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    if (uid == lauUid || uid == 'lau') return true;
    if (uid == robUid || uid == 'rob') return false;
    return members[uid]?.colorKey == ColorKey.lau ||
        (members[uid] == null && uid != robUid);
  }

  bool isRobUid(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    if (uid == robUid || uid == 'rob') return true;
    return members[uid]?.colorKey == ColorKey.rob;
  }
}

enum AuthStatus { unknown, signedOut, authorized, unauthorized }

@immutable
class AuthSession {
  const AuthSession({
    required this.status,
    this.user,
    this.household,
    this.message,
  });

  const AuthSession.unknown() : this(status: AuthStatus.unknown);
  const AuthSession.signedOut() : this(status: AuthStatus.signedOut);

  final AuthStatus status;
  final AppUser? user;
  final Household? household;
  final String? message;

  bool get isAuthorized => status == AuthStatus.authorized;
}
