import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/connectivity/connectivity_provider.dart';
import 'package:brotherapp/core/theme/app_theme.dart';
import 'package:brotherapp/core/utils/date_format.dart';
import 'package:brotherapp/features/auth/auth_providers.dart';
import 'package:brotherapp/features/auth/auth_repository.dart';
import 'package:brotherapp/router/app_router.dart';

Future<void> _pumpShell(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required String location,
}) async {
  final repo = AuthRepository(forceDemo: true);
  await repo.signInWithGoogle();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) {
          ref.onDispose(repo.dispose);
          return repo;
        }),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final router = ref.watch(appRouterProvider);
          return MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              padding: const EdgeInsets.only(bottom: 48),
              viewPadding: const EdgeInsets.only(bottom: 48),
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
  final ctx = tester.element(find.byType(MaterialApp));
  final container = ProviderScope.containerOf(ctx);
  container.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    await AppDateFormat.ensureInitialized();
  });

  for (final width in [360.0, 390.0, 412.0]) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets(
        'home shell no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/',
          );
        },
      );

      testWidgets(
        'transfers list no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/bonifici',
          );
        },
      );

      testWidgets(
        'transfer form no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/bonifici/nuovo',
          );
        },
      );

      testWidgets(
        'tasks list no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/dafare',
          );
        },
      );

      testWidgets(
        'task form no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/dafare/nuova',
          );
        },
      );

      testWidgets(
        'report no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/rendiconto',
          );
        },
      );

      testWidgets(
        'export no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/esporta',
          );
        },
      );

      testWidgets(
        'settings no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/altro',
          );
        },
      );

      testWidgets(
        'import excel no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/importa',
          );
        },
      );

      testWidgets(
        'appearance no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/altro/aspetto',
          );
        },
      );

      testWidgets(
        'trash no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/altro/cestino',
          );
        },
      );

      testWidgets(
        'properties catalog no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/altro/immobili',
          );
        },
      );

      testWidgets(
        'property form no horizontal overflow @ ${width.toInt()}dp scale $textScale',
        (tester) async {
          await _pumpShell(
            tester,
            width: width,
            textScale: textScale,
            location: '/altro/immobili/forlanini',
          );
        },
      );
    }
  }

  testWidgets('rendiconto list padding clears the system nav bar',
      (tester) async {
    await _pumpShell(
      tester,
      width: 390,
      textScale: 1.0,
      location: '/rendiconto',
    );
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding!.resolve(TextDirection.ltr).bottom, 72);
  });

  testWidgets('bonifici list padding clears the system nav bar', (tester) async {
    await _pumpShell(
      tester,
      width: 390,
      textScale: 1.0,
      location: '/bonifici',
    );
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding!.resolve(TextDirection.ltr).bottom, 72);
  });

  testWidgets('immobili list shows the label, detail shows civic number',
      (tester) async {
    await _pumpShell(
      tester,
      width: 390,
      textScale: 1.0,
      location: '/altro/immobili',
    );
    expect(find.text('Via Forlanini'), findsOneWidget);
    expect(find.text('Via Forlanini 9'), findsOneWidget);

    await _pumpShell(
      tester,
      width: 390,
      textScale: 1.0,
      location: '/altro/immobili/forlanini',
    );
    expect(find.text('Dettaglio immobile'), findsOneWidget);
    expect(find.text('Numero civico'), findsOneWidget);
    expect(find.text('Interno'), findsOneWidget);
  });
}
