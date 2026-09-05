import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/theme/app_colors.dart';
import 'package:brotherapp/core/utils/contrast.dart';

void main() {
  group('contrast tokens dark', () {
    const c = AppColors.dark;
    test('ink on bg/card ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.ink, c.bg), isTrue);
      expect(Contrast.passesNormalText(c.ink, c.card), isTrue);
    });
    test('ink2 on bg/card ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.ink2, c.bg), isTrue);
      expect(Contrast.passesNormalText(c.ink2, c.card), isTrue);
    });
    test('onAcc on acc ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.onAcc, c.acc), isTrue);
    });
    test('heroFg on hero ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.heroFg, c.hero), isTrue);
    });
    test('status chips ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.ok, c.okSoft), isTrue);
      expect(Contrast.passesNormalText(c.warn, c.warnSoft), isTrue);
      expect(Contrast.passesNormalText(c.due, c.dueSoft), isTrue);
    });
    test('person avatars ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.rob, c.robSoft), isTrue);
      expect(Contrast.passesNormalText(c.lau, c.lauSoft), isTrue);
    });
  });

  group('contrast tokens light', () {
    const c = AppColors.light;
    test('ink on bg/card ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.ink, c.bg), isTrue);
      expect(Contrast.passesNormalText(c.ink, c.card), isTrue);
    });
    test('onAcc on acc ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.onAcc, c.acc), isTrue);
    });
    test('heroFg on hero ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.heroFg, c.hero), isTrue);
    });
    test('status chips ≥ 4.5', () {
      expect(Contrast.passesNormalText(c.ok, c.okSoft), isTrue);
      expect(Contrast.passesNormalText(c.warn, c.warnSoft), isTrue);
      expect(Contrast.passesNormalText(c.due, c.dueSoft), isTrue);
    });
  });
}
