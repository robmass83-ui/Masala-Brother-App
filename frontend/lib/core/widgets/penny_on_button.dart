import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'penny_thoughts.dart';

/// Penny appoggiata al bottone, con nuvoletta tutta visibile e testo dentro.
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
      duration: const Duration(milliseconds: 700),
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
    const bubbleW = 158.0;
    const bubbleH = 104.0;
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _enter]),
      builder: (context, _) {
        final bob = math.sin(_idle.value * math.pi) * 2.0;
        final enter = Curves.easeOutBack.transform(_enter.value).clamp(0.0, 1.0);
        return SizedBox(
          width: 188,
          height: 150,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                child: Transform.translate(
                  offset: Offset(0, -bob),
                  child: Image.asset(
                    'assets/mascot/penny.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Penny',
                  ),
                ),
              ),
              Positioned(
                right: 44,
                top: 0,
                width: bubbleW,
                height: bubbleH,
                child: Opacity(
                  opacity: _enter.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.84 + enter * 0.16,
                    alignment: const Alignment(0.65, 1.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/mascot/nuvoletta.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          filterQuality: FilterQuality.high,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 20, 28, 38),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 96),
                                child: Text(
                                  PennySession.phrase,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  style: const TextStyle(
                                    color: Color(0xFF16181D),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
