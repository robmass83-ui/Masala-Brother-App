import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/person_avatar.dart';
import '../../data/activity_models.dart';
import '../../data/data_providers.dart';
import '../auth/auth_models.dart';
import '../auth/auth_providers.dart';

class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final items = ref.watch(activityProvider).valueOrNull ?? const <ActivityEntry>[];
    final household = ref.watch(authSessionProvider).valueOrNull?.household;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Attività')),
      body: items.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: const [
                EmptyState(
                  message:
                      'Qui comparirà chi ha aggiunto o modificato spese, bonifici e cose da fare. Utile se usate l’app in momenti diversi.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = items[i];
                final member = household?.memberByUid(e.byUid);
                final person = member?.colorKey == ColorKey.lau
                    ? PersonKey.lau
                    : PersonKey.rob;
                final who = member?.name.split(' ').first ?? 'Qualcuno';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PersonAvatar(person: person, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _line(who, e.summary),
                              style: TextStyle(
                                color: c.ink,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppDateFormat.relative(e.at),
                              style: TextStyle(
                                color: c.ink3,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  static String _line(String who, String summary) {
    final s = summary.trim();
    if (s.isEmpty) return who;
    final rest = '${s[0].toLowerCase()}${s.substring(1)}';
    return '$who $rest';
  }
}
