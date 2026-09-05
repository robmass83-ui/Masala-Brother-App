import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum PersonKey { rob, lau }

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    this.person,
    this.size = 36,
    this.empty = false,
  });

  final PersonKey? person;
  final double size;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = size / 3;

    if (empty || person == null) {
      return CustomPaint(
        size: Size.square(size),
        painter: _DashedAvatarPainter(color: c.ink3, radius: radius),
      );
    }

    final isRob = person == PersonKey.rob;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isRob ? c.robSoft : c.lauSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        isRob ? 'R' : 'L',
        style: TextStyle(
          color: isRob ? c.rob : c.lau,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

class _DashedAvatarPainter extends CustomPainter {
  _DashedAvatarPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 4;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedAvatarPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
