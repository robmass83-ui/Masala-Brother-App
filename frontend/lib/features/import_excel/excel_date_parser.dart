/// Extracts dates from Italian expense descriptions (the old Excel has no date column).
class ExcelDateParser {
  const ExcelDateParser();

  static const _months = <String, int>{
    'gennaio': 1,
    'genn': 1,
    'gen': 1,
    'febbraio': 2,
    'febbr': 2,
    'febb': 2,
    'feb': 2,
    'marzo': 3,
    'marz': 3,
    'mar': 3,
    'aprile': 4,
    'apr': 4,
    'maggio': 5,
    'magg': 5,
    'mag': 5,
    'giugno': 6,
    'giugn': 6,
    'giu': 6,
    'luglio': 7,
    'lugl': 7,
    'lug': 7,
    'agosto': 8,
    'ago': 8,
    'settembre': 9,
    'sett': 9,
    'set': 9,
    'ottobre': 10,
    'ott': 10,
    'novembre': 11,
    'nov': 11,
    'dicembre': 12,
    'dic': 12,
  };

  static final _monthAlt = (_months.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length)))
      .join('|');

  static final _numericDate = RegExp(
    r'(\d{1,2})[./](\d{1,2})[./](\d{2,4})',
  );
  static final _dayMonthYear = RegExp(
    r'(\d{1,2})\s*(' + _monthAlt + r')\s*(\d{2,4})',
    caseSensitive: false,
  );
  static final _dayMonth = RegExp(
    r'(\d{1,2})\s*(' + _monthAlt + r')\b',
    caseSensitive: false,
  );
  static final _monthSlashYear = RegExp(
    r'(' + _monthAlt + r')\s*/\s*(' + _monthAlt + r')\s*(\d{2,4})',
    caseSensitive: false,
  );
  static final _monthYear = RegExp(
    r'(' + _monthAlt + r')\s*(\d{2,4})',
    caseSensitive: false,
  );

  ParsedExcelDate? parse(String description, {int? fallbackYear}) {
    final text = description.toLowerCase();

    final numeric = _numericDate.firstMatch(text);
    if (numeric != null) {
      return _fromParts(
        day: int.parse(numeric.group(1)!),
        month: int.parse(numeric.group(2)!),
        yearRaw: int.parse(numeric.group(3)!),
        yearCorrected: numeric.group(3)!.length == 3,
      );
    }

    final dmy = _dayMonthYear.firstMatch(text);
    if (dmy != null) {
      return _fromParts(
        day: int.parse(dmy.group(1)!),
        month: _months[dmy.group(2)!.toLowerCase()]!,
        yearRaw: int.parse(dmy.group(3)!),
        yearCorrected: dmy.group(3)!.length == 3,
      );
    }

    final slash = _monthSlashYear.firstMatch(text);
    if (slash != null) {
      return _fromParts(
        day: 1,
        month: _months[slash.group(2)!.toLowerCase()]!,
        yearRaw: int.parse(slash.group(3)!),
        yearCorrected: slash.group(3)!.length == 3,
      );
    }

    final my = _monthYear.firstMatch(text);
    if (my != null) {
      return _fromParts(
        day: 1,
        month: _months[my.group(1)!.toLowerCase()]!,
        yearRaw: int.parse(my.group(2)!),
        yearCorrected: my.group(2)!.length == 3,
      );
    }

    final dm = _dayMonth.firstMatch(text);
    if (dm != null && fallbackYear != null) {
      return _fromParts(
        day: int.parse(dm.group(1)!),
        month: _months[dm.group(2)!.toLowerCase()]!,
        yearRaw: fallbackYear,
      );
    }

    return null;
  }

  /// Fill gaps using row order (the sheet is chronological 2023–2026).
  List<DateTime> estimateMissing({
    required List<DateTime?> parsed,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    final start = rangeStart ?? DateTime(2023, 1, 15);
    final end = rangeEnd ?? DateTime(2026, 7, 17);
    final n = parsed.length;
    if (n == 0) return const [];

    final known = <int, DateTime>{};
    for (var i = 0; i < n; i++) {
      final d = parsed[i];
      if (d != null) known[i] = d;
    }

    DateTime at(int i) {
      if (known.containsKey(i)) return known[i]!;
      var prev = -1;
      var next = -1;
      for (var p = i - 1; p >= 0; p--) {
        if (known.containsKey(p)) {
          prev = p;
          break;
        }
      }
      for (var nx = i + 1; nx < n; nx++) {
        if (known.containsKey(nx)) {
          next = nx;
          break;
        }
      }
      if (prev >= 0 && next >= 0) {
        return _lerp(known[prev]!, known[next]!, i - prev, next - prev);
      }
      if (prev >= 0) {
        return known[prev]!.add(Duration(days: (i - prev) * 12));
      }
      if (next >= 0) {
        return known[next]!.subtract(Duration(days: (next - i) * 12));
      }
      if (n == 1) return start;
      return _lerp(start, end, i, n - 1);
    }

    return [for (var i = 0; i < n; i++) at(i)];
  }

  ParsedExcelDate? _fromParts({
    required int day,
    required int month,
    required int yearRaw,
    bool yearCorrected = false,
  }) {
    final year = normalizeYear(yearRaw);
    if (month < 1 || month > 12) return null;
    final dim = DateTime(year, month + 1, 0).day;
    final d = day.clamp(1, dim);
    return ParsedExcelDate(
      date: DateTime(year, month, d),
      yearCorrected: yearCorrected,
    );
  }

  /// 24 → 2024; 206 → 2026 (3-digit typo in the original sheet).
  static int normalizeYear(int year) {
    if (year >= 1000) return year;
    if (year >= 100) {
      final lastTwo = year % 100;
      if (lastTwo >= 20) return 2000 + lastTwo;
      return 2020 + (year % 10);
    }
    if (year >= 50) return 1900 + year;
    return 2000 + year;
  }

  static DateTime _lerp(DateTime a, DateTime b, int step, int span) {
    if (span <= 0) return a;
    final delta = b.difference(a).inDays;
    final days = (delta * step / span).round();
    return a.add(Duration(days: days));
  }
}

class ParsedExcelDate {
  const ParsedExcelDate({
    required this.date,
    this.yearCorrected = false,
  });

  final DateTime date;
  final bool yearCorrected;
}
