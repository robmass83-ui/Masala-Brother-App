import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Asks "Scartare le modifiche?" before leaving a form with unsaved input,
/// for both the system back gesture and the app bar arrow (use
/// [DiscardGuard.back] for the latter). Saving pops with `context.pop()`,
/// which does not go through this guard.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({super.key, required this.isDirty, required this.child});

  final bool Function() isDirty;
  final Widget child;

  /// For an app bar back arrow: goes through the guard like system back.
  static void back(BuildContext context) => Navigator.maybePop(context);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isDirty()) {
          final discard = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Scartare le modifiche?'),
              content: const Text('Quello che hai scritto non è stato salvato.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Continua a modificare'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Scarta'),
                ),
              ],
            ),
          );
          if (discard != true) return;
        }
        if (!context.mounted) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          GoRouter.of(context).go('/');
        }
      },
      child: child,
    );
  }
}
