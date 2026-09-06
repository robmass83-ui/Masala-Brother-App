import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/updates/app_updater.dart';

Future<void> checkAppUpdates(BuildContext context) async {
  if (kIsWeb) {
    await launchUrl(
      Uri.parse(AppConfig.githubReleasesUrl),
      mode: LaunchMode.externalApplication,
    );
    return;
  }

  final updater = AppUpdater();
  _showBusy(context, 'Controllo aggiornamenti…');
  AppUpdate? latest;
  try {
    latest = await updater.fetchLatest();
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _snack(context, e.toString());
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (latest == null || !AppUpdater.isNewer(latest.version, AppConfig.appVersion)) {
    _snack(context, 'Hai già l’ultima versione (${AppConfig.appVersion}).');
    return;
  }

  final available = latest;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      return AlertDialog(
        backgroundColor: c.card,
        title: Text(
          'Versione ${available.version} disponibile',
          style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Ora hai la ${AppConfig.appVersion}. Vuoi scaricare e installare l’aggiornamento? '
          'Android ti chiederà conferma.',
          style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Non ora', style: TextStyle(color: c.ink2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Scarica e installa', style: TextStyle(color: c.acc)),
          ),
        ],
      );
    },
  );
  if (go != true || !context.mounted) return;

  await _downloadAndInstall(context, updater, available);
}

Future<void> _downloadAndInstall(
  BuildContext context,
  AppUpdater updater,
  AppUpdate latest,
) async {
  final progress = ValueNotifier<double?>(null);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final c = ctx.colors;
      return AlertDialog(
        backgroundColor: c.card,
        title: Text(
          'Download ${latest.version}',
          style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
        ),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: value,
                  color: c.acc,
                  backgroundColor: c.accSoft,
                ),
                const SizedBox(height: 12),
                Text(
                  value == null
                      ? 'Preparazione…'
                      : '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  try {
    final file = await updater.download(
      latest,
      onProgress: (received, total) {
        if (total == null || total <= 0) {
          progress.value = null;
        } else {
          progress.value = (received / total).clamp(0, 1);
        }
      },
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await updater.install(file);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _snack(context, e.toString());
  } finally {
    progress.dispose();
  }
}

void _showBusy(BuildContext context, String message) {
  final c = context.colors;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.card,
      content: Row(
        children: [
          CircularProgressIndicator(color: c.acc),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
