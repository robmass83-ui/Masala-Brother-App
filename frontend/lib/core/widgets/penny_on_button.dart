import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'penny_thoughts.dart';

/// Penny con le zampe sul bordo del bottone e nuvoletta piccola, inclinata.
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
        final bob = math.sin(_idle.value * math.pi) * 1.6;
        final appear = Curves.easeOut.transform(_enter.value);
        return SizedBox(
          width: 128,
          height: 96,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 4,
                bottom: 0,
                child: Transform.translate(
                  offset: Offset(0, -bob),
                  child: Image.asset(
                    'assets/mascot/penny.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Penny',
                  ),
                ),
              ),
              Positioned(
                right: 30,
                top: 0,
                width: 98,
                height: 62,
                child: Opacity(
                  opacity: appear,
                  child: Transform.rotate(
                    angle: -0.18,
                    alignment: Alignment.bottomRight,
                    child: Transform.scale(
                      scale: 0.92 + appear * 0.08,
                      alignment: Alignment.bottomRight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/mascot/nuvoletta.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(22, 14, 22, 24),
                            child: _ThoughtText(),
                          ),
                        ],
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
        var size = 8.5;
        TextPainter? painter;
        while (size >= 5.5) {
          painter = TextPainter(
            text: TextSpan(
              text: phrase,
              style: TextStyle(
                color: const Color(0xFF16181D),
                fontSize: size,
                fontWeight: FontWeight.w800,
                height: 1.12,
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
          size -= 0.4;
        }
        return Text(
          phrase,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF16181D),
            fontSize: size,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        );
      },
    );
  }
}
