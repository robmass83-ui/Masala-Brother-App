import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_models.dart';

const bootLocation = '/avvio';
const loginLocation = '/login';
const privateLocation = '/privata';
const homeLocation = '/';

/// Decides where to send the user. Accedi is never shown: a signed-out session
/// stays on boot while Google silent/interactive restore runs.
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
    case AuthStatus.signedOut:
      if (loggingIn) return bootLocation;
      return booting ? null : bootLocation;
    case AuthStatus.unauthorized:
      return privatePage ? null : privateLocation;
    case AuthStatus.authorized:
      if (loggingIn || privatePage || booting) return homeLocation;
      return null;
  }
}
