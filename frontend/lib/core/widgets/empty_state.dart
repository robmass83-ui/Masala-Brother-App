import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_card.dart';
import 'primary_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = actionLabel;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (label != null && onAction != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(label: label, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
