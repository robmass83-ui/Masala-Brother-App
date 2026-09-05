import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_providers.dart';

class PrivateAppPage extends ConsumerWidget {
  const PrivateAppPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final session = ref.watch(authSessionProvider).valueOrNull;
    final email = session?.user?.email ?? '';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Questa app è privata',
                style: TextStyle(
                  color: c.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                email.isEmpty
                    ? 'Il tuo account Google non è autorizzato.'
                    : 'L’account $email non è nella lista dei partecipanti.',
                style: TextStyle(
                  color: c.ink2,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Text(
                  'Solo Roberto e Laura possono leggere e scrivere i dati. '
                  'Se pensi sia un errore, chiedi a Roberto di verificare '
                  'le email in households/main.',
                  style: TextStyle(
                    color: c.ink2,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Esci',
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
