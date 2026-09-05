import 'package:flutter/material.dart';

import '../common/placeholder_page.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Da fare',
      subtitle: 'Cose da fare',
      showSampleHero: false,
    );
  }
}
