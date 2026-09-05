/// Runtime flags via `--dart-define`.
class AppConfig {
  const AppConfig._();

  static const String householdId = 'main';

  static const bool useFirebaseEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  /// In-memory Roberto session when Firebase is not configured.
  static const bool demoAuth = bool.fromEnvironment(
    'DEMO_AUTH',
    defaultValue: false,
  );

  static const List<String> defaultMemberEmails = [
    'roberto@example.com',
    'laura@example.com',
  ];
}
