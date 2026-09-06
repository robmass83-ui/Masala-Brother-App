import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'penny_thoughts.dart';

/// Penny appoggiata al bottone, con nuvoletta che nasce dalla testa.
class PennyOnButton extends StatefulWidget {
  const PennyOnButton({super.key});

  @override
  State<PennyOnButton> createState() => _PennyOnButtonState();
}

class _PennyOnButtonState extends State<PennyOnButton>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _bubble;
  final _rng = math.Random();
  late String _phrase;
  String? _lastPhrase;
  bool _readyForNext = true;

  @override
  void initState() {
    super.initState();
    _phrase = _nextPhrase();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _bubble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    );
    _bubble.addListener(_maybePickPhrase);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_canLoop) {
        _idle.repeat(reverse: true);
        _bubble.repeat();
      } else {
        _bubble.value = 0.5;
      }
    });
  }

  bool get _canLoop {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    return !WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  void _maybePickPhrase() {
    if (_bubble.value < 0.04) {
      _readyForNext = true;
      return;
    }
    if (_readyForNext && _bubble.value >= 0.04) {
      _readyForNext = false;
      final next = _nextPhrase();
      if (next != _phrase) setState(() => _phrase = next);
    }
  }

  String _nextPhrase() {
    String pick;
    do {
      pick = pennyThoughts[_rng.nextInt(pennyThoughts.length)];
    } while (pick == _lastPhrase && pennyThoughts.length > 1);
    _lastPhrase = pick;
    return pick;
  }

  @override
  void dispose() {
    _bubble.removeListener(_maybePickPhrase);
    _idle.dispose();
    _bubble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _bubble]),
      builder: (context, _) {
        final t = _bubble.value;
        final pop = _pop(t);
        final opacity = _opacity(t);
        final textIn = _textIn(t);
        final bob = math.sin(_idle.value * math.pi) * 2.2;
        final float = math.sin(t * math.pi * 2) * 2.0 * textIn;

        return SizedBox(
          width: 168,
          height: 118,
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
                    width: 78,
                    height: 78,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Penny',
                  ),
                ),
              ),
              Positioned(
                right: 52,
                bottom: 46,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, -float),
                    child: Transform.scale(
                      scale: pop,
                      alignment: const Alignment(0.72, 1.05),
                      child: SizedBox(
                        width: 118,
                        height: 78,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/mascot/nuvoletta.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                              child: Opacity(
                                opacity: textIn,
                                child: Text(
                                  _phrase,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF16181D),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  static double _pop(double t) {
    if (t < 0.08) return 0;
    if (t < 0.28) {
      final p = (t - 0.08) / 0.20;
      return Curves.elasticOut.transform(p).clamp(0.0, 1.08);
    }
    if (t < 0.82) return 1;
    return Curves.easeIn.transform((1 - t) / 0.18).clamp(0.0, 1.0);
  }

  static double _opacity(double t) {
    if (t < 0.06) return 0;
    if (t < 0.16) return (t - 0.06) / 0.10;
    if (t < 0.82) return 1;
    return ((1 - t) / 0.18).clamp(0.0, 1.0);
  }

  static double _textIn(double t) {
    if (t < 0.22) return 0;
    if (t < 0.34) return (t - 0.22) / 0.12;
    if (t < 0.80) return 1;
    return ((0.92 - t) / 0.12).clamp(0.0, 1.0);
  }
}
