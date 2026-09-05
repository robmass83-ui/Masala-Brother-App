import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ExpenseStatusUi { daPagare, parziale, pagato }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ExpenseStatusUi status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, fg, bg) = switch (status) {
      ExpenseStatusUi.pagato => ('Pagato', c.ok, c.okSoft),
      ExpenseStatusUi.parziale => ('Parziale', c.warn, c.warnSoft),
      ExpenseStatusUi.daPagare => ('Da pagare', c.due, c.dueSoft),
    };

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
