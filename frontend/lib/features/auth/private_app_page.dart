import 'package:flutter/material.dart';

import '../common/placeholder_page.dart';

class PrivateAppPage extends StatelessWidget {
  const PrivateAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'App privata',
      subtitle: 'Solo Roberto e Laura possono accedere.',
      showSampleHero: false,
    );
  }
}
