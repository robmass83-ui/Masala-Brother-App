import 'package:flutter/material.dart';

import '../common/placeholder_page.dart';

class ExpenseDetailPage extends StatelessWidget {
  const ExpenseDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Dettaglio spesa',
      subtitle: 'ID: $id — dettaglio e pagamenti',
    );
  }
}
