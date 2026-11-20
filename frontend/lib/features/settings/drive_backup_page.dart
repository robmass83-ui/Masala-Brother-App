import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/backup/drive_backup.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';

/// Altro → Backup su Google Drive.
class DriveBackupPage extends ConsumerWidget {
  const DriveBackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(driveBackupProvider);
    final ctrl = ref.read(driveBackupProvider.notifier);

    final status = !s.enabled
        ? 'Spento'
        : s.busy
        ? 'Salvataggio su Drive…'
        : s.error != null
        ? s.error!
        : s.pending
        ? 'In attesa: salvo appena c’è connessione'
        : s.lastBackupAt == null
        ? 'Acceso'
        : 'Aggiornato ${AppDateFormat.relative(s.lastBackupAt!)}';
    final statusColor = !s.enabled
        ? c.ink2
        : s.error != null
        ? c.due
        : (s.pending || s.busy)
        ? c.warn
        : c.ok;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Backup su Google Drive')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Ogni volta che da questo telefono aggiungi o modifichi una spesa, '
            'un pagamento o un bonifico, l’app aggiorna il file '
            '“$driveBackupFileName” nel tuo Google Drive. '
            'Drive conserva anche le versioni precedenti.',
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup automatico',
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: s.enabled,
                  onChanged: s.busy
                      ? null
                      : (on) => on ? ctrl.enable() : ctrl.disable(),
                ),
              ],
            ),
          ),
          if (s.enabled) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: s.needsPermission
                  ? 'Concedi di nuovo l’accesso'
                  : 'Salva ora',
              icon: Icons.cloud_upload_outlined,
              onPressed: s.busy
                  ? null
                  : () => s.needsPermission ? ctrl.enable() : ctrl.runNow(),
            ),
            if (s.fileUrl != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(s.fileUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: Icon(Icons.open_in_new, color: c.acc),
                label: Text(
                  'Apri il file in Drive',
                  style: TextStyle(color: c.acc, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          Text(
            'Il file contiene tutte le spese e i bonifici. Ognuno di voi lo '
            'trova nel proprio Drive: si aggiorna con le modifiche fatte dal '
            'suo telefono, e con quelle dell’altro al prossimo cambiamento.',
            style: TextStyle(
              color: c.ink3,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
