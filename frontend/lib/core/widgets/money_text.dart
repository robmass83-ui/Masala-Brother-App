import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/money_format.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    super.key,
    this.style,
    this.color,
  });

  final int cents;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = style ??
        TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: color ?? c.ink,
          letterSpacing: -0.01,
        );
    return Text(
      MoneyFormat.fromCents(cents),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base.copyWith(color: color ?? base.color ?? c.ink),
    );
  }
}
