import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/connectivity/connectivity_provider.dart';
import '../../core/prefs/settings_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';
import '../common/placeholder_page.dart';
import 'settings_tiles.dart';
import 'update_flow.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final session = ref.watch(authSessionProvider).valueOrNull;
    final user = session?.user;

    if (user == null) {
      return const PlaceholderPage(
        title: 'Altro',
        subtitle: 'Impostazioni e dati',
      );
    }

    final household = session?.household;
    final member = household?.members[user.uid];
    final person = member?.colorKey == ColorKey.lau
        ? PersonKey.lau
        : PersonKey.rob;
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final lastAt = _lastUpdateAt(ref);
    final theme = ref.watch(themeModeProvider);
    final hour = ref.watch(reminderHourProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <CatalogCategory>[];
    final props =
        ref.watch(propertiesProvider).valueOrNull ?? const <CatalogProperty>[];
    final members = household?.members.values.toList() ?? const <HouseholdMember>[];
    final memberNames = members.isEmpty
        ? 'Roberto, Laura'
        : members.map((m) => m.name.split(' ').first).join(', ');
    final propPreview = props.take(3).map((p) => p.name).join(', ');
    final catPreview = cats.take(3).map((c) => c.name.split(' ').first).join(', ');
    final trashCount = ref.watch(trashItemsProvider).length;

    final otherName = person == PersonKey.rob ? 'Laura' : 'Roberto';
    final syncLabel = online
        ? (lastAt == null
            ? 'Sincronizzato con $otherName'
            : 'Sincronizzato con $otherName · ${AppDateFormat.relative(lastAt)}')
        : 'Offline · le modifiche si sincronizzano dopo';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Altro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                Semantics(
                  image: true,
                  child: PersonAvatar(person: person, size: 52),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink2,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                            size: 16,
                            color: online ? c.ok : c.warn,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              syncLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: online ? c.ok : c.warn,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SettingsSectionLabel('Conti condivisi'),
          SettingsGroup(
            children: [
              SettingsTile(
                leading: const SettingsIcon(Icons.people_outline),
                title: 'Partecipanti',
                subtitle: memberNames,
                onTap: () => context.push('/altro/partecipanti'),
              ),
              SettingsTile(
                leading: const SettingsIcon(Icons.home_outlined),
                title: 'Immobili',
                subtitle: propPreview.isEmpty ? 'Nessuno' : propPreview,
                onTap: () => context.push('/altro/immobili'),
              ),
              SettingsTile(
                leading: const SettingsIcon(Icons.label_outline),
                title: 'Categorie',
                subtitle: catPreview.isEmpty ? 'Nessuna' : '$catPreview…',
                onTap: () => context.push('/altro/categorie'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SettingsSectionLabel('Dati'),
          SettingsGroup(
            children: [
              SettingsTile(
                leading: const SettingsIcon(Icons.table_chart_outlined),
                title: 'Esporta Excel / PDF',
                onTap: () => context.push('/esporta'),
              ),
              SettingsTile(
                leading: const SettingsIcon(Icons.swap_vert),
                title: 'Importa dal vecchio Excel',
                subtitle: 'Dal file OneDrive',
                onTap: () => context.push('/importa'),
              ),
              SettingsTile(
                leading: const SettingsIcon(Icons.history),
                title: 'Attività recente',
                subtitle: 'Chi ha fatto cosa',
                onTap: () => context.push('/altro/attivita'),
              ),
              SettingsTile(
                leading: const SettingsIcon(Icons.delete_outline),
                title: 'Cestino',
                subtitle: trashCount == 0
                    ? 'Ultimi 30 giorni'
                    : '$trashCount ${trashCount == 1 ? 'voce' : 'voci'}',
                onTap: () => context.push('/altro/cestino'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SettingsSectionLabel('App'),
          SettingsGroup(
            children: [
              SettingsTile(
                leading: const SettingsIcon(Icons.notifications_outlined),
                title: 'Promemoria scadenze',
                subtitle: 'Alle ${_two(hour)}:00',
                onTap: () => context.push('/altro/promemoria'),
              ),
              SettingsTile(
                leading: const SettingsIcon(Icons.palette_outlined),
                title: 'Aspetto',
                subtitle: themeModeLabel(theme),
                onTap: () => context.push('/altro/aspetto'),
              ),
              const SettingsTile(
                leading: SettingsIcon(Icons.format_size),
                title: 'Dimensione testo',
                subtitle: 'Segue il telefono, fino a 1,3×',
                showChevron: false,
              ),
              SettingsTile(
                leading: const SettingsIcon(Icons.info_outline),
                title: 'Versione',
                subtitle: '${AppConfig.appVersion} (${AppConfig.appBuild})',
                showChevron: false,
              ),
              SettingsTile(
                leading: const SettingsIcon(Icons.system_update_alt),
                title: 'Controlla aggiornamenti',
                subtitle: 'Scarica e installa se c’è una versione nuova',
                onTap: () => checkAppUpdates(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Esci',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }

  DateTime? _lastUpdateAt(WidgetRef ref) {
    DateTime? latest;
    void consider(DateTime? at) {
      if (at == null) return;
      if (latest == null || at.isAfter(latest!)) latest = at;
    }

    for (final e in ref.watch(expensesProvider).valueOrNull ?? const []) {
      consider(e.updatedAt ?? e.createdAt);
    }
    for (final t in ref.watch(transfersProvider).valueOrNull ?? const []) {
      consider(t.updatedAt ?? t.createdAt);
    }
    for (final t in ref.watch(visibleTasksProvider)) {
      consider(t.updatedAt ?? t.createdAt);
    }
    return latest;
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
