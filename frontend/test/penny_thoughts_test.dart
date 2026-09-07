import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/widgets/penny_thoughts.dart';

void main() {
  test('Penny thoughts are real sentences, not numbered bullets', () {
    expect(pennyThoughts.length, greaterThan(40));
    expect(pennyThoughts, contains('Suggerisco di rapire Toby.'));
    expect(pennyThoughts, contains('Piano geniale. Dettagli top secret.'));
    for (final line in pennyThoughts) {
      expect(line.trim(), isNotEmpty);
      expect(RegExp(r'^\d+').hasMatch(line), isFalse);
    }
  });

  test('Penny keeps the same phrase for the whole app session', () {
    PennySession.resetForTest();
    final first = PennySession.phrase;
    expect(first, isNotEmpty);
    expect(PennySession.phrase, first);
    expect(PennySession.phrase, first);
  });

  test('mascot stays the same until the app is closed', () {
    PennySession.resetForTest();
    final first = PennySession.showPenny;
    expect(PennySession.showPenny, first);
    expect(PennySession.showPenny, first);
  });

  test('resetForTest can pin Burns or Penny', () {
    PennySession.resetForTest(showPenny: false);
    expect(PennySession.showPenny, isFalse);
    PennySession.resetForTest(showPenny: true);
    expect(PennySession.showPenny, isTrue);
  });

  test('resetForTest can pin a thought phrase', () {
    PennySession.resetForTest(phrase: 'Ho inseguito la coda. Persa.');
    expect(PennySession.phrase, 'Ho inseguito la coda. Persa.');
    expect(PennySession.phrase, 'Ho inseguito la coda. Persa.');
  });
}
