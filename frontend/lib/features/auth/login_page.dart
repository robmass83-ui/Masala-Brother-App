import 'package:flutter/material.dart';

import '../common/placeholder_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Accedi',
      subtitle: 'Entra con Google (Fase 2)',
      showSampleHero: false,
    );
  }
}
