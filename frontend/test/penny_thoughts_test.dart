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
}
