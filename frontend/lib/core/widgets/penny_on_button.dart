import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'penny_thoughts.dart';

/// Penny on the transfer button. The nuvoletta pops out of her mouth.
class PennyOnButton extends StatefulWidget {
  const PennyOnButton({super.key});

  static const Size layoutSize = Size(128, 88);

  static const double _pennyRight = -4.9;
  static const double _pennyBottom = 6.8;
  static const double _pennySize = 85;
  static const double _bubbleRight = 55.8;
  static const double _bubbleTop = -4.1;
  static const double _bubbleW = 146.2;
  static const double _bubbleH = 68.4;
  static const double _fontSize = 8.5;
  static const double _textDx = -4.4;
  static const double _textDy = 5.8;

  @override
  State<PennyOnButton> createState() => _PennyOnButtonState();
}

class _PennyOnButtonState extends State<PennyOnButton>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _speak;

  bool get _inTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _speak = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_canLoop) {
        _idle.repeat(reverse: true);
        _speak.forward();
      } else {
        _speak.value = 1;
      }
    });
  }

  bool get _canLoop {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return !_inTest;
  }

  @override
  void dispose() {
    _idle.dispose();
    _speak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _speak]),
      builder: (context, _) {
        final bob = math.sin(_idle.value * math.pi) * 1.6;
        final t = _speak.value;
        final emerge = _emerge(t);
        final bubbleOpacity = _bubbleOpacity(t);
        final textOpacity = _textOpacity(t);
        final talk = t > 0.04 && t < 0.32
            ? 1.0 + 0.07 * math.sin((t - 0.04) / 0.28 * math.pi)
            : 1.0;
        final fromMouth = Offset.lerp(
          const Offset(36, 28),
          Offset.zero,
          emerge,
        )!;
        final scale = 0.08 + emerge * 0.92;

        return SizedBox(
          key: const Key('penny-on-button'),
          width: PennyOnButton.layoutSize.width,
          height: PennyOnButton.layoutSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: PennyOnButton._pennyRight,
                bottom: PennyOnButton._pennyBottom,
                child: Transform.translate(
                  offset: Offset(0, -bob),
                  child: Transform.scale(
                    scale: talk,
                    alignment: Alignment.bottomCenter,
                    child: Image.asset(
                      'assets/mascot/penny.png',
                      width: PennyOnButton._pennySize,
                      height: PennyOnButton._pennySize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'Penny',
                    ),
                  ),
                ),
              ),
              Positioned(
                right: PennyOnButton._bubbleRight,
                top: PennyOnButton._bubbleTop,
                width: PennyOnButton._bubbleW,
                height: PennyOnButton._bubbleH,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: bubbleOpacity,
                    child: Transform.translate(
                      offset: fromMouth,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.bottomRight,
                        child: _ThoughtBubble(textOpacity: textOpacity),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 0 at the mouth, 1 at the parked bubble.
  static double _emerge(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return Curves.easeOutBack.transform(t).clamp(0.0, 1.06);
  }

  static double _bubbleOpacity(double t) {
    if (t < 0.04) return 0;
    if (t < 0.18) return (t - 0.04) / 0.14;
    return 1;
  }

  static double _textOpacity(double t) {
    if (t < 0.28) return 0;
    if (t < 0.55) return (t - 0.28) / 0.27;
    return 1;
  }
}

class _ThoughtBubble extends StatelessWidget {
  const _ThoughtBubble({required this.textOpacity});

  final double textOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/mascot/nuvoletta.png',
          key: const Key('penny-nuvoletta'),
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 32, 22),
          child: Center(
            child: Opacity(
              opacity: textOpacity,
              child: Transform.translate(
                offset: const Offset(
                  PennyOnButton._textDx,
                  PennyOnButton._textDy,
                ),
                child: const _ThoughtText(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThoughtText extends StatelessWidget {
  const _ThoughtText();

  @override
  Widget build(BuildContext context) {
    final phrase = PennySession.phrase;
    return Text(
      phrase,
      key: const Key('penny-thought-text'),
      textAlign: TextAlign.center,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF16181D),
        fontSize: PennyOnButton._fontSize,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    );
  }
}
