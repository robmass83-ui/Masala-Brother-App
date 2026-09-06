import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/task_notifications.dart';
import 'core/prefs/app_prefs.dart';
import 'core/prefs/settings_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/date_format.dart';
import 'core/widgets/keyboard_dismiss.dart';
import 'features/auth/auth_providers.dart';
import 'features/auth/auth_repository.dart';
import 'firebase_bootstrap.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDateFormat.ensureInitialized();
  await TaskNotifications.ensureInitialized();
  final boot = await bootstrapFirebase();
  final demo = boot == FirebaseBootstrapResult.demo;
  final prefs = await AppPrefs.load();

  runApp(
    ProviderScope(
      overrides: [
        appPrefsProvider.overrideWithValue(prefs),
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
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Masala Brother App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return KeyboardDismiss(child: child ?? const SizedBox.shrink());
      },
      routerConfig: router,
    );
  }
}
