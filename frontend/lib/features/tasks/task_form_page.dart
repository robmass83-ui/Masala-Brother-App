import 'package:flutter/material.dart';

import '../common/placeholder_page.dart';

class TaskFormPage extends StatelessWidget {
  const TaskFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Nuova cosa da fare',
      subtitle: 'Crea un task',
      showSampleHero: false,
    );
  }
}
