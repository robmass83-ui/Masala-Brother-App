import 'package:flutter/material.dart';

import '../common/placeholder_page.dart';

class ExpenseFormPage extends StatelessWidget {
  const ExpenseFormPage({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: id == null ? 'Nuova spesa' : 'Modifica spesa',
      subtitle: 'Modulo nuova/modifica spesa',
    );
  }
}
