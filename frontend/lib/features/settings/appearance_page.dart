import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/settings_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selected = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Aspetto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Scegli se seguire il telefono oppure fissare il tema chiaro o scuro.',
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (final mode in ThemeMode.values) ...[
            AppCard(
              onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          themeModeLabel(mode),
                          style: TextStyle(
                            color: c.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hint(mode),
                          style: TextStyle(
                            color: c.ink2,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected == mode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected == mode ? c.acc : c.ink3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String _hint(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Come nelle impostazioni di Android',
        ThemeMode.light => 'Sfondo chiaro, testo scuro',
        ThemeMode.dark => 'Sfondo scuro, come nel riferimento visivo',
      };
}
