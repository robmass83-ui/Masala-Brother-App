import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/features/auth/auth_models.dart';
import 'package:brotherapp/features/auth/auth_repository.dart';

void main() {
  test('demo Google sign-in authorizes Roberto', () async {
    final repo = AuthRepository(forceDemo: true);
    addTearDown(repo.dispose);

    expect((await repo.currentSession()).status, AuthStatus.signedOut);

    final session = await repo.signInWithGoogle();
    expect(session.status, AuthStatus.authorized);
    expect(session.user?.email, 'roberto@example.com');
    expect(session.household?.isEmailAllowed('roberto@example.com'), isTrue);

    await repo.signOut();
    expect((await repo.currentSession()).status, AuthStatus.signedOut);
  });

  test('unauthorized demo lands on privata status', () async {
    final repo = AuthRepository(forceDemo: true);
    addTearDown(repo.dispose);

    final session = await repo.signInUnauthorizedDemo();
    expect(session.status, AuthStatus.unauthorized);
    expect(session.user?.email, 'altro@gmail.com');
    expect(session.household?.isEmailAllowed('altro@gmail.com'), isFalse);
  });

  test('household email allow-list is case-insensitive', () {
    const h = Household(
      id: 'main',
      memberEmails: ['Roberto@Example.com', 'laura@example.com'],
      members: {},
    );
    expect(h.isEmailAllowed('roberto@example.com'), isTrue);
    expect(h.isEmailAllowed('LAURA@EXAMPLE.COM'), isTrue);
    expect(h.isEmailAllowed('altro@gmail.com'), isFalse);
  });
}
