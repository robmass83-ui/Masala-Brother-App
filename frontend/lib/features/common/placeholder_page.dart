import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_chip.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    this.subtitle,
    this.showSampleHero = false,
  });

  final String title;
  final String? subtitle;
  final bool showSampleHero;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (showSampleHero) ...[
            _SampleHero(colors: c),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const PersonAvatar(person: PersonKey.rob, size: 28),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Roberto ha pagato',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.ink2,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const MoneyText(5320719, style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const PersonAvatar(person: PersonKey.lau, size: 28),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Laura ha pagato',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.ink2,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const MoneyText(4443419, style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle ??
                      'Schermata in costruzione — layout e token già attivi.',
                  style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const StatusChip(status: ExpenseStatusUi.daPagare),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Azione primaria', onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleHero extends StatelessWidget {
  const _SampleHero({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: colors.hero,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SITUAZIONE ATTUALE',
            style: TextStyle(
              color: colors.heroMuted,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.04,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '€ 4.386,50',
            style: TextStyle(
              color: colors.heroFg,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: TextStyle(
                color: colors.heroFg,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              children: [
                const TextSpan(text: 'che '),
                TextSpan(
                  text: 'Laura',
                  style: TextStyle(
                    color: colors.lauOnHero,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: ' deve a '),
                TextSpan(
                  text: 'Roberto',
                  style: TextStyle(
                    color: colors.robOnHero,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
