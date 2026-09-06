import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ExpenseStatusUi { daPagare, parziale, pagato }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final ExpenseStatusUi status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, fg, bg) = switch (status) {
      ExpenseStatusUi.pagato => ('Pagato', c.ok, c.okSoft),
      ExpenseStatusUi.parziale => ('Parziale', c.warn, c.warnSoft),
      ExpenseStatusUi.daPagare => ('Da pagare', c.due, c.dueSoft),
    };

    return Container(
      height: compact ? null : 26,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 0,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: compact ? 10 : 13,
          fontWeight: FontWeight.w700,
          height: compact ? 1.1 : 1,
        ),
      ),
    );
  }
}
