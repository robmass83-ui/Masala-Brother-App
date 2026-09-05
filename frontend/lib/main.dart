import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/date_format.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_repository.dart';
import 'firebase_bootstrap.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDateFormat.ensureInitialized();
  final boot = await bootstrapFirebase();
  final demo = boot == FirebaseBootstrapResult.demo;

  runApp(
    ProviderScope(
      overrides: [
        if (demo)
          authRepositoryProvider.overrideWith((ref) {
            final repo = AuthRepository(forceDemo: true);
            ref.onDispose(repo.dispose);
            return repo;
          }),
      ],
      child: const MasalaBrotherApp(),
    ),
  );
}

class MasalaBrotherApp extends ConsumerWidget {
  const MasalaBrotherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Masala Brother App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
