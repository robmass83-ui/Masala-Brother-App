import 'package:flutter/material.dart';

import '../common/placeholder_page.dart';

class ExportPage extends StatelessWidget {
  const ExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Esporta',
      subtitle: 'Excel / PDF',
      showSampleHero: false,
    );
  }
}
