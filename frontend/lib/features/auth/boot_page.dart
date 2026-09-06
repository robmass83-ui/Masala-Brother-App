import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'auth_models.dart';
import 'auth_providers.dart';

/// Shown while the last Google session is restored. Never shows Accedi.
class BootPage extends ConsumerStatefulWidget {
  const BootPage({super.key});

  @override
  ConsumerState<BootPage> createState() => _BootPageState();
}

class _BootPageState extends ConsumerState<BootPage> {
  bool _prompted = false;
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    setState(() => _showRetry = false);
    await ref.read(authRepositoryProvider).restoreSession(
          forcePrompt: _prompted,
        );
    _prompted = true;
    if (!mounted) return;
    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null || session.status == AuthStatus.signedOut) {
      setState(() => _showRetry = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Masala Brother',
                  style: TextStyle(
                    color: c.acc,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.04,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_showRetry)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: c.acc,
                    ),
                  )
                else ...[
                  Text(
                    'Non sono riuscito a entrare con Google. Riprova.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.ink2,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _restore,
                    child: const Text('Riprova'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
