import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/features/auth/auth_models.dart';
import 'package:brotherapp/router/auth_redirect.dart';

void main() {
  const loading = AsyncLoading<AuthSession>();
  const signedOut = AsyncData(AuthSession.signedOut());
  const unknown = AsyncData(AuthSession.unknown());
  final authorized = AsyncData(
    AuthSession(
      status: AuthStatus.authorized,
      user: const AppUser(
        uid: 'rob',
        email: 'rob@example.com',
        displayName: 'Roberto',
      ),
    ),
  );
  final unauthorized = AsyncData(
    AuthSession(
      status: AuthStatus.unauthorized,
      user: const AppUser(
        uid: 'x',
        email: 'altro@gmail.com',
        displayName: 'Ospite',
      ),
    ),
  );

  test('while restoring session never shows login', () {
    expect(authRedirect(auth: loading, loc: loginLocation), bootLocation);
    expect(authRedirect(auth: loading, loc: bootLocation), isNull);
    expect(authRedirect(auth: loading, loc: homeLocation), isNull);
  });

  test('unknown session stays on boot, not login', () {
    expect(authRedirect(auth: unknown, loc: bootLocation), isNull);
    expect(authRedirect(auth: unknown, loc: homeLocation), bootLocation);
    expect(authRedirect(auth: unknown, loc: loginLocation), bootLocation);
  });

  test('signed out stays on boot and never opens Accedi', () {
    expect(authRedirect(auth: signedOut, loc: bootLocation), isNull);
    expect(authRedirect(auth: signedOut, loc: loginLocation), bootLocation);
    expect(authRedirect(auth: signedOut, loc: homeLocation), bootLocation);
  });

  test('authorized skips login and boot', () {
    expect(authRedirect(auth: authorized, loc: bootLocation), homeLocation);
    expect(authRedirect(auth: authorized, loc: loginLocation), homeLocation);
    expect(authRedirect(auth: authorized, loc: homeLocation), isNull);
  });

  test('unauthorized goes to private page', () {
    expect(authRedirect(auth: unauthorized, loc: bootLocation), privateLocation);
    expect(authRedirect(auth: unauthorized, loc: privateLocation), isNull);
  });
}
