import 'package:flutter/material.dart';

/// Design tokens from docs/design-reference.html (direzione B · Notte).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.card,
    required this.line,
    required this.shadow,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.acc,
    required this.onAcc,
    required this.accSoft,
    required this.accLine,
    required this.accShadow,
    required this.rob,
    required this.robSoft,
    required this.lau,
    required this.lauSoft,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.due,
    required this.dueSoft,
    required this.hero,
    required this.heroFg,
    required this.heroMuted,
    required this.heroSoft,
    required this.robOnHero,
    required this.lauOnHero,
  });

  final Color bg;
  final Color card;
  final Color line;
  final Color shadow;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color acc;
  final Color onAcc;
  final Color accSoft;
  final Color accLine;
  final Color accShadow;
  final Color rob;
  final Color robSoft;
  final Color lau;
  final Color lauSoft;
  final Color ok;
  final Color okSoft;
  final Color warn;
  final Color warnSoft;
  final Color due;
  final Color dueSoft;
  final Color hero;
  final Color heroFg;
  final Color heroMuted;
  final Color heroSoft;
  final Color robOnHero;
  final Color lauOnHero;

  static const dark = AppColors(
    bg: Color(0xFF131518),
    card: Color(0xFF1D2026),
    line: Color(0xFF2A2E36),
    shadow: Color(0x73000000),
    ink: Color(0xFFF3F2EE),
    ink2: Color(0xFFA9ADB6),
    ink3: Color(0xFF6E737D),
    acc: Color(0xFF4ED6B8),
    onAcc: Color(0xFF0F1A17),
    accSoft: Color(0xFF1B3A34),
    accLine: Color(0xFF2A5A50),
    accShadow: Color(0x4D4ED6B8),
    rob: Color(0xFF8AB0FF),
    robSoft: Color(0xFF1F2B47),
    lau: Color(0xFFFF9E7C),
    lauSoft: Color(0xFF3A2620),
    ok: Color(0xFF5FD38F),
    okSoft: Color(0xFF173327),
    warn: Color(0xFFF2B85B),
    warnSoft: Color(0xFF3A2E14),
    due: Color(0xFFFF7A70),
    dueSoft: Color(0xFF3E1F1E),
    hero: Color(0xFF1D2026),
    heroFg: Color(0xFFF3F2EE),
    heroMuted: Color(0xFFA9ADB6),
    heroSoft: Color(0x1AFFFFFF),
    robOnHero: Color(0xFF8AB0FF),
    lauOnHero: Color(0xFFFF9E7C),
  );

  static const light = AppColors(
    bg: Color(0xFFF7F7F5),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE3E3DF),
    shadow: Color(0x1F000000),
    ink: Color(0xFF16181D),
    ink2: Color(0xFF5B5F68),
    ink3: Color(0xFF8A8F99),
    // Light accent/status hues kept from design-reference; slightly deepened
    // so on-color text meets WCAG AA 4.5:1 on soft/solid fills.
    acc: Color(0xFF097A66),
    onAcc: Color(0xFFFFFFFF),
    accSoft: Color(0xFFDDF3ED),
    accLine: Color(0xFFB6E3D8),
    accShadow: Color(0x4D097A66),
    rob: Color(0xFF2F5BD1),
    robSoft: Color(0xFFE3E9FA),
    lau: Color(0xFFA03D22),
    lauSoft: Color(0xFFFBE6DE),
    ok: Color(0xFF1F7A3E),
    okSoft: Color(0xFFDFF2E4),
    warn: Color(0xFF8F5415),
    warnSoft: Color(0xFFFBEBD3),
    due: Color(0xFFB8322B),
    dueSoft: Color(0xFFFBE1DF),
    hero: Color(0xFF16181D),
    heroFg: Color(0xFFF7F7F5),
    heroMuted: Color(0xFFB9B5AC),
    heroSoft: Color(0x24FFFFFF),
    robOnHero: Color(0xFF9FB8FF),
    lauOnHero: Color(0xFFFFB59E),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? card,
    Color? line,
    Color? shadow,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? acc,
    Color? onAcc,
    Color? accSoft,
    Color? accLine,
    Color? accShadow,
    Color? rob,
    Color? robSoft,
    Color? lau,
    Color? lauSoft,
    Color? ok,
    Color? okSoft,
    Color? warn,
    Color? warnSoft,
    Color? due,
    Color? dueSoft,
    Color? hero,
    Color? heroFg,
    Color? heroMuted,
    Color? heroSoft,
    Color? robOnHero,
    Color? lauOnHero,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      line: line ?? this.line,
      shadow: shadow ?? this.shadow,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      acc: acc ?? this.acc,
      onAcc: onAcc ?? this.onAcc,
      accSoft: accSoft ?? this.accSoft,
      accLine: accLine ?? this.accLine,
      accShadow: accShadow ?? this.accShadow,
      rob: rob ?? this.rob,
      robSoft: robSoft ?? this.robSoft,
      lau: lau ?? this.lau,
      lauSoft: lauSoft ?? this.lauSoft,
      ok: ok ?? this.ok,
      okSoft: okSoft ?? this.okSoft,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      due: due ?? this.due,
      dueSoft: dueSoft ?? this.dueSoft,
      hero: hero ?? this.hero,
      heroFg: heroFg ?? this.heroFg,
      heroMuted: heroMuted ?? this.heroMuted,
      heroSoft: heroSoft ?? this.heroSoft,
      robOnHero: robOnHero ?? this.robOnHero,
      lauOnHero: lauOnHero ?? this.lauOnHero,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: l(bg, other.bg),
      card: l(card, other.card),
      line: l(line, other.line),
      shadow: l(shadow, other.shadow),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      ink3: l(ink3, other.ink3),
      acc: l(acc, other.acc),
      onAcc: l(onAcc, other.onAcc),
      accSoft: l(accSoft, other.accSoft),
      accLine: l(accLine, other.accLine),
      accShadow: l(accShadow, other.accShadow),
      rob: l(rob, other.rob),
      robSoft: l(robSoft, other.robSoft),
      lau: l(lau, other.lau),
      lauSoft: l(lauSoft, other.lauSoft),
      ok: l(ok, other.ok),
      okSoft: l(okSoft, other.okSoft),
      warn: l(warn, other.warn),
      warnSoft: l(warnSoft, other.warnSoft),
      due: l(due, other.due),
      dueSoft: l(dueSoft, other.dueSoft),
      hero: l(hero, other.hero),
      heroFg: l(heroFg, other.heroFg),
      heroMuted: l(heroMuted, other.heroMuted),
      heroSoft: l(heroSoft, other.heroSoft),
      robOnHero: l(robOnHero, other.robOnHero),
      lauOnHero: l(lauOnHero, other.lauOnHero),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
