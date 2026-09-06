/// Two-person household identity.
///
/// Excel import may store the placeholders `rob` / `lau` before both people
/// have logged in. Live screens must treat those as Roberto / Laura.
class PersonUid {
  const PersonUid._();

  static const rob = 'rob';
  static const lau = 'lau';

  static bool isRob(String uid, String robUid) =>
      uid == robUid || uid == rob;

  /// Laura: her live uid, the import placeholder, or any other non-Roberto id
  /// (stale Firebase uid from before she was in `members`).
  static bool isLau(
    String uid, {
    required String robUid,
    required String lauUid,
  }) {
    if (uid.isEmpty || isRob(uid, robUid)) return false;
    // Known Laura ids, or a leftover Firebase uid from before remap.
    return uid == lauUid || uid == lau || uid != robUid;
  }
}
