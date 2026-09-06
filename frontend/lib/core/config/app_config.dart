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
    'robmass83@gmail.com',
    'laura.masala@tiscali.it',
  ];

  /// Keep in sync with `pubspec.yaml` `version:`.
  static const String appVersion = '1.0.1';
  static const int appBuild = 4;

  static const String githubOwner = 'robmass83-ui';
  static const String githubRepo = 'Masala-Brother-App';

  static const String githubReleasesUrl =
      'https://github.com/$githubOwner/$githubRepo/releases';

  static const String githubLatestReleaseApi =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  static const Duration trashRetention = Duration(days: 30);
}
