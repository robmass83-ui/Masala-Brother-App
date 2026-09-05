import 'package:flutter/material.dart';

import '../common/placeholder_page.dart';

class ImportExcelPage extends StatelessWidget {
  const ImportExcelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Importa Excel',
      subtitle: 'Import dal file OneDrive',
      showSampleHero: false,
    );
  }
}
