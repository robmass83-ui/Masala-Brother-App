import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shown while Firebase restores a persisted Google session.
/// Must not look like the login page — no “Accedi”, no Google button.
class BootPage extends StatelessWidget {
  const BootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
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
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: c.acc,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
