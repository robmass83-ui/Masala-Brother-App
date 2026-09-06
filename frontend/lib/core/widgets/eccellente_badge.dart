import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Character on the home hero. «ECCELLENTE» comes out of the mouth.
class EccellenteBadge extends StatefulWidget {
  const EccellenteBadge({super.key, this.size = 72});

  final double size;

  @override
  State<EccellenteBadge> createState() => _EccellenteBadgeState();
}

class _EccellenteBadgeState extends State<EccellenteBadge>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _speak;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _speak = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_canLoop) {
        _idle.repeat(reverse: true);
        _speak.repeat();
      } else {
        _speak.value = 0.55;
      }
    });
  }

  bool get _canLoop {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return !WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  @override
  void dispose() {
    _idle.dispose();
    _speak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = widget.size;
    return SizedBox(
      width: size + 12,
      height: size + 18,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _speak]),
        builder: (context, _) {
          final idle = _idle.value;
          final speak = _speak.value;
          final emerge = _emerge(speak);
          final opacity = _wordOpacity(speak);
          final bob = math.sin(idle * math.pi) * 2.5;
          final rot = (idle - 0.5) * 0.05;
          final talk = speak > 0.06 && speak < 0.22 ? 1.04 : 1.0;

          final mouth = Offset(size * 0.28, size * 0.68);
          final rest = Offset(size * 0.5 + 6, size + 6);
          final pos = Offset.lerp(mouth, rest, emerge)!;
          final scale = 0.12 + emerge * 0.88;
          final spread = 0.2 + emerge * 0.5;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 6,
                top: 0,
                child: Transform.translate(
                  offset: Offset(0, -bob),
                  child: Transform.rotate(
                    angle: rot,
                    child: Transform.scale(
                      scale: talk,
                      child: Image.asset(
                        'assets/mascot/eccellente.png',
                        width: size,
                        height: size,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        semanticLabel: 'Eccellente',
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: pos.dx - 48,
                top: pos.dy - 7,
                width: 96,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: Text(
                        'ECCELLENTE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.heroFg,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: spread,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: c.acc.withValues(alpha: 0.22 + emerge * 0.18),
                              blurRadius: 7,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 0 at the mouth, 1 parked under the head.
  static double _emerge(double t) {
    if (t < 0.08) return 0;
    if (t < 0.42) {
      final p = (t - 0.08) / 0.34;
      return Curves.easeOutBack.transform(p).clamp(0.0, 1.0);
    }
    return 1;
  }

  static double _wordOpacity(double t) {
    if (t < 0.06) return 0;
    if (t < 0.16) return (t - 0.06) / 0.10;
    if (t < 0.78) return 1;
    return (1 - t) / 0.22;
  }
}
