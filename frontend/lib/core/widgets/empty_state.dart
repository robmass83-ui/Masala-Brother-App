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
    this.compact = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = actionLabel;
    return AppCard(
      padding: compact
          ? const EdgeInsets.fromLTRB(14, 8, 14, 8)
          : const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              height: compact ? 1.25 : 1.4,
            ),
          ),
          if (label != null && onAction != null) ...[
            SizedBox(height: compact ? 6 : 16),
            if (compact)
              SizedBox(
                height: 38,
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.acc,
                    foregroundColor: c.onAcc,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(label),
                ),
              )
            else
              PrimaryButton(label: label, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
