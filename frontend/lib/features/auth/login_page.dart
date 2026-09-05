import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      setState(() => _error = 'Accesso non riuscito. Riprova.');
      debugPrint('Sign-in error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Masala Brother',
                style: TextStyle(
                  color: c.acc,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.04,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Accedi',
                style: TextStyle(
                  color: c.ink,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'App privata per Roberto e Laura.\nEntra con il tuo account Google.',
                style: TextStyle(
                  color: c.ink2,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solo due account autorizzati possono usare l’app. '
                      'Se entri con un’altra email vedrai la schermata di accesso negato.',
                      style: TextStyle(
                        color: c.ink2,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: c.due,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PrimaryButton(
                      label: _busy ? 'Accesso…' : 'Entra con Google',
                      onPressed: _busy ? null : _signIn,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'I dati restano sul progetto Firebase di Roberto.\n'
                'Niente Play Store: si installa l’APK a mano.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.ink3,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
