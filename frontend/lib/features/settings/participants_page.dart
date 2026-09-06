import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/person_avatar.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';

class ParticipantsPage extends ConsumerWidget {
  const ParticipantsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final household = ref.watch(authSessionProvider).valueOrNull?.household;
    final members = household?.members.values.toList() ?? const <HouseholdMember>[];
    final emails = household?.memberEmails ?? const <String>[];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Partecipanti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Solo queste persone possono usare l’app. Le email si cambiano da Firebase.',
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (members.isEmpty)
            AppCard(
              child: Text(
                'I profili si compilano al primo accesso di Roberto e Laura.',
                style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
              ),
            )
          else
            for (final m in members) ...[
              AppCard(
                child: Row(
                  children: [
                    PersonAvatar(
                      person: m.colorKey == ColorKey.lau
                          ? PersonKey.lau
                          : PersonKey.rob,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.colorKey == ColorKey.rob ? 'Roberto' : 'Laura',
                            style: TextStyle(
                              color: m.colorKey == ColorKey.rob ? c.rob : c.lau,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          Text(
            'Email autorizzate',
            style: TextStyle(
              color: c.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < emails.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Text(
                    emails[i],
                    style: TextStyle(
                      color: c.ink2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
