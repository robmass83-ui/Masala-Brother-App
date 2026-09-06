import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/updates/app_updater.dart';

void main() {
  test('isNewer compares semver and ignores v prefix', () {
    expect(AppUpdater.isNewer('1.0.1', '1.0.0'), isTrue);
    expect(AppUpdater.isNewer('v1.0.1', '1.0.0'), isTrue);
    expect(AppUpdater.isNewer('1.0.0', '1.0.0'), isFalse);
    expect(AppUpdater.isNewer('1.0.0', '1.0.1'), isFalse);
    expect(AppUpdater.isNewer('2.0.0', '1.9.9'), isTrue);
  });

  test('picks arm64 apk when several assets exist', () {
    final apk = AppUpdater.pickApkAsset([
      {'name': 'notes.txt', 'browser_download_url': 'https://x/notes'},
      {
        'name': 'app-armeabi-v7a-release.apk',
        'browser_download_url': 'https://x/v7',
      },
      {
        'name': 'app-arm64-v8a-release.apk',
        'browser_download_url': 'https://x/arm64',
        'size': 20,
      },
    ]);
    expect(apk?['name'], 'app-arm64-v8a-release.apk');
  });

  test('parses a GitHub release payload', () {
    final update = AppUpdater.fromGithubRelease({
      'tag_name': 'v1.0.1',
      'body': 'Fix login',
      'assets': [
        {
          'name': 'app-release.apk',
          'browser_download_url': 'https://example.com/app.apk',
          'size': 1000,
        },
      ],
    });
    expect(update?.version, '1.0.1');
    expect(update?.apkUrl, 'https://example.com/app.apk');
    expect(update?.notes, 'Fix login');
  });
}
