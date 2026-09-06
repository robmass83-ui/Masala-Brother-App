import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_models.dart';

const bootLocation = '/avvio';
const loginLocation = '/login';
const privateLocation = '/privata';
const homeLocation = '/';

/// Decides where to send the user. Login is only for a real signed-out session,
/// never while Firebase is still restoring the last Google account.
String? authRedirect({
  required AsyncValue<AuthSession> auth,
  required String loc,
}) {
  final booting = loc == bootLocation;
  final loggingIn = loc == loginLocation;
  final privatePage = loc == privateLocation;

  if (auth.isLoading || auth.isRefreshing) {
    if (loggingIn || privatePage) return bootLocation;
    return null;
  }

  final session = auth.valueOrNull ?? const AuthSession.unknown();
  switch (session.status) {
    case AuthStatus.unknown:
      return booting ? null : bootLocation;
    case AuthStatus.signedOut:
      return loggingIn ? null : loginLocation;
    case AuthStatus.unauthorized:
      return privatePage ? null : privateLocation;
    case AuthStatus.authorized:
      if (loggingIn || privatePage || booting) return homeLocation;
      return null;
  }
}
