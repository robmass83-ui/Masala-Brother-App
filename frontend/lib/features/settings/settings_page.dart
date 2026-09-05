import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';
import '../common/placeholder_page.dart';

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

    final member = session?.household?.members[user.uid];
    final person = member?.colorKey == ColorKey.lau
        ? PersonKey.lau
        : PersonKey.rob;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Altro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                PersonAvatar(person: person, size: 48),
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
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Text(
              'Partecipanti autorizzati:\n'
              '${session?.household?.memberEmails.join('\n') ?? '—'}',
              style: TextStyle(
                color: c.ink2,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Text(
              'Categorie e immobili vengono creati al primo accesso '
              '(seed automatico).',
              style: TextStyle(
                color: c.ink2,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
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
}
