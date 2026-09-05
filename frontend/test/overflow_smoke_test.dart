import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/theme/app_theme.dart';
import 'package:brotherapp/core/utils/date_format.dart';
import 'package:brotherapp/features/auth/auth_providers.dart';
import 'package:brotherapp/features/auth/auth_repository.dart';
import 'package:brotherapp/router/app_router.dart';

void main() {
  setUpAll(() async {
    await AppDateFormat.ensureInitialized();
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'home shell no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          final repo = AuthRepository(forceDemo: true);
          await repo.signInWithGoogle();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authRepositoryProvider.overrideWith((ref) {
                  ref.onDispose(repo.dispose);
                  return repo;
                }),
              ],
              child: Consumer(
                builder: (context, ref, _) {
                  final router = ref.watch(appRouterProvider);
                  return MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 800),
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: MaterialApp.router(
                      theme: AppTheme.light(),
                      darkTheme: AppTheme.dark(),
                      themeMode: ThemeMode.dark,
                      routerConfig: router,
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
