import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/widgets/penny_on_button.dart';
import 'package:brotherapp/core/widgets/penny_thoughts.dart';

Future<void> _pumpBubble(WidgetTester tester, String phrase) async {
  PennySession.resetForTest(showPenny: true, phrase: phrase);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: KeyedSubtree(
            key: ValueKey(phrase),
            child: const PennyOnButton(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('thought text stays inside the bubble for every phrase',
      (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final phrase in pennyThoughts) {
      await _pumpBubble(tester, phrase);

      final textFinder = find.byKey(const Key('penny-thought-text'));
      final bubbleFinder = find.byKey(const Key('penny-nuvoletta'));
      expect(textFinder, findsOneWidget, reason: phrase);
      expect(bubbleFinder, findsOneWidget, reason: phrase);
      expect(find.text(phrase), findsOneWidget, reason: phrase);
      expect(
        tester.widget<Text>(textFinder).style!.fontSize,
        8.5,
        reason: phrase,
      );

      final textRect = tester.getRect(textFinder);
      final bubbleRect = tester.getRect(bubbleFinder);
      expect(textRect.width, greaterThan(0), reason: phrase);
      expect(textRect.height, greaterThan(0), reason: phrase);
      expect(textRect.left, greaterThanOrEqualTo(bubbleRect.left), reason: phrase);
      expect(textRect.top, greaterThanOrEqualTo(bubbleRect.top), reason: phrase);
      expect(textRect.right, lessThanOrEqualTo(bubbleRect.right), reason: phrase);
      expect(textRect.bottom, lessThanOrEqualTo(bubbleRect.bottom), reason: phrase);
    }
  });

  testWidgets('the whole bubble stays on Penny\'s overlay', (tester) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpBubble(tester, 'Ho inseguito la coda. Persa.');
    final bubble = tester.getRect(find.byKey(const Key('penny-nuvoletta')));
    expect(bubble.width, greaterThan(40));
    expect(bubble.height, greaterThan(30));
  });
}
