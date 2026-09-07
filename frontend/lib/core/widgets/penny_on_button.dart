import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'penny_thoughts.dart';

/// Penny con le zampe sul bordo del bottone e nuvoletta grande, inclinata.
class PennyOnButton extends StatefulWidget {
  const PennyOnButton({super.key});

  @override
  State<PennyOnButton> createState() => _PennyOnButtonState();
}

class _PennyOnButtonState extends State<PennyOnButton>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_canLoop) {
        _idle.repeat(reverse: true);
        _enter.forward();
      } else {
        _enter.value = 1;
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
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _enter]),
      builder: (context, _) {
        final bob = math.sin(_idle.value * math.pi) * 1.8;
        final appear = Curves.easeOut.transform(_enter.value);
        return SizedBox(
          width: 228,
          height: 158,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 2,
                bottom: 0,
                child: Transform.translate(
                  offset: Offset(0, -bob),
                  child: Image.asset(
                    'assets/mascot/penny.png',
                    width: 82,
                    height: 82,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Penny',
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                width: 178,
                height: 126,
                child: Opacity(
                  opacity: appear,
                  child: Transform.rotate(
                    angle: -0.08,
                    alignment: Alignment.bottomRight,
                    child: Transform.scale(
                      scale: 0.94 + appear * 0.06,
                      alignment: Alignment.bottomRight,
                      child: const _ThoughtBubble(),
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
}

class _ThoughtBubble extends StatelessWidget {
  const _ThoughtBubble();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/mascot/nuvoletta.png',
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
        // Inset stays inside the white cloud, away from the scalloped edge.
        const Padding(
          padding: EdgeInsets.fromLTRB(40, 32, 46, 48),
          child: Center(child: _ThoughtText()),
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
    return LayoutBuilder(
      builder: (context, box) {
        final maxW = box.maxWidth;
        final maxH = box.maxHeight;
        if (maxW <= 0 || maxH <= 0) return const SizedBox.shrink();
        var size = 11.0;
        TextPainter? painter;
        while (size >= 6.0) {
          painter = TextPainter(
            text: TextSpan(
              text: phrase,
              style: TextStyle(
                color: const Color(0xFF16181D),
                fontSize: size,
                fontWeight: FontWeight.w800,
                height: 1.08,
              ),
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            ellipsis: '…',
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxW);
          final tooTall = painter.height > maxH + 0.5;
          final tooWide = painter.didExceedMaxLines;
          if (!tooTall && !tooWide) break;
          size -= 0.35;
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: SizedBox(
            width: maxW,
            child: Text(
              phrase,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF16181D),
                fontSize: size,
                fontWeight: FontWeight.w800,
                height: 1.08,
              ),
            ),
          ),
        );
      },
    );
  }
}
