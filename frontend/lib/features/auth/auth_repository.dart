import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import '../../data/household_repository.dart';
import 'auth_models.dart';

/// Google Sign-In + household membership.
///
/// With [AppConfig.demoAuth] (or when Firebase is not initialized) uses an
/// in-memory Roberto session so routing/UI work without credentials.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    HouseholdRepository? householdRepository,
    this.forceDemo,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']),
        _household = householdRepository ??
            HouseholdRepository(
              firestore: Firebase.apps.isNotEmpty
                  ? FirebaseFirestore.instance
                  : null,
            ),
        _authOverride = auth;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn _googleSignIn;
  final HouseholdRepository _household;
  final bool? forceDemo;

  final _demoController = StreamController<AuthSession>.broadcast();
  AuthSession _demoSession = const AuthSession.signedOut();

  bool get _demoMode =>
      forceDemo ?? (AppConfig.demoAuth || Firebase.apps.isEmpty);

  FirebaseAuth? get _auth {
    if (_authOverride != null) return _authOverride;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance;
  }

  Future<AuthSession>? _restoreFuture;

  Stream<AuthSession> watchSession() {
    if (_demoMode) {
      return Stream<AuthSession>.multi((listener) {
        listener.add(_demoSession);
        final sub = _demoController.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener.onCancel = sub.cancel;
      });
    }
    unawaited(restoreSession());
    return _auth!.authStateChanges().asyncMap(_mapFirebaseUser);
  }

  Future<AuthSession> currentSession() async {
    if (_demoMode) return _demoSession;
    return _mapFirebaseUser(_auth!.currentUser);
  }

  Future<AuthSession> signInWithGoogle() async {
    if (_demoMode) {
      _demoSession = AuthSession(
        status: AuthStatus.authorized,
        user: const AppUser(
          uid: 'demo-roberto',
          email: 'robmass83@gmail.com',
          displayName: 'Roberto',
        ),
        household: Household(
          id: AppConfig.householdId,
          memberEmails: AppConfig.defaultMemberEmails,
          members: {
            'demo-roberto': const HouseholdMember(
              uid: 'demo-roberto',
              name: 'Roberto',
              initial: 'R',
              colorKey: ColorKey.rob,
            ),
            'demo-laura': const HouseholdMember(
              uid: 'demo-laura',
              name: 'Laura',
              initial: 'L',
              colorKey: ColorKey.lau,
            ),
          },
        ),
        message: 'Modalità demo (senza Firebase)',
      );
      _demoController.add(_demoSession);
      return _demoSession;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return currentSession();
    return _completeGoogleSignIn(googleUser);
  }

  /// Re-enters with the last Google account. Shows the system account picker
  /// only if silent restore cannot find a session — never the Accedi screen.
  Future<AuthSession> restoreSession({bool forcePrompt = false}) {
    if (!forcePrompt && _restoreFuture != null) return _restoreFuture!;
    final future = _restoreSession(forcePrompt: forcePrompt);
    _restoreFuture = future;
    return future.whenComplete(() {
      if (identical(_restoreFuture, future)) _restoreFuture = null;
    });
  }

  Future<AuthSession> _restoreSession({required bool forcePrompt}) async {
    if (_demoMode) {
      if (_demoSession.isAuthorized && !forcePrompt) return _demoSession;
      return signInWithGoogle();
    }

    final existing = _auth?.currentUser;
    if (existing != null && !forcePrompt) {
      return _mapFirebaseUser(existing);
    }

    try {
      GoogleSignInAccount? googleUser;
      if (!forcePrompt) {
        googleUser = await _googleSignIn.signInSilently();
      }
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) return await currentSession();
      return await _completeGoogleSignIn(googleUser);
    } catch (e, st) {
      debugPrint('Google restore failed: $e\n$st');
      return currentSession();
    }
  }

  Future<AuthSession> _completeGoogleSignIn(GoogleSignInAccount googleUser) async {
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth!.signInWithCredential(credential);
    return _mapFirebaseUser(cred.user);
  }

  /// Dev helper: simulate an unauthorized Google account.
  Future<AuthSession> signInUnauthorizedDemo() async {
    _demoSession = AuthSession(
      status: AuthStatus.unauthorized,
      user: const AppUser(
        uid: 'demo-outsider',
        email: 'altro@gmail.com',
        displayName: 'Ospite',
      ),
      household: Household(
        id: AppConfig.householdId,
        memberEmails: AppConfig.defaultMemberEmails,
        members: const {},
      ),
    );
    _demoController.add(_demoSession);
    return _demoSession;
  }

  Future<void> signOut() async {
    if (_demoMode) {
      _demoSession = const AuthSession.signedOut();
      _demoController.add(_demoSession);
      return;
    }
    await Future.wait([
      _auth!.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<AuthSession> _mapFirebaseUser(User? user) async {
    if (user == null || user.email == null) {
      return const AuthSession.signedOut();
    }
    final appUser = AppUser(
      uid: user.uid,
      email: user.email!,
      displayName: user.displayName ?? user.email!,
      photoUrl: user.photoURL,
    );

    try {
      await _household.ensureHouseholdDocument();
      final household = await _household.fetchHousehold();
      if (household == null || !household.isEmailAllowed(appUser.email)) {
        return AuthSession(
          status: AuthStatus.unauthorized,
          user: appUser,
          household: household,
        );
      }
      final updated = await _household.ensureMember(appUser);
      return AuthSession(
        status: AuthStatus.authorized,
        user: appUser,
        household: updated,
      );
    } on FirebaseException catch (e, st) {
      debugPrint('Household error: $e\n$st');
      return AuthSession(
        status: AuthStatus.unauthorized,
        user: appUser,
        message: e.message,
      );
    }
  }

  void dispose() {
    _demoController.close();
    _household.dispose();
  }
}
