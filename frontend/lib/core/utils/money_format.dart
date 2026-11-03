import 'package:intl/intl.dart';

/// Italian money formatting: `€ 1.234,56`. Amounts stored as cents.
class MoneyFormat {
  MoneyFormat._();

  static final NumberFormat _fmt = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );

  static String fromCents(int cents) => _fmt.format(cents / 100);

  /// ASCII-safe for PDF built-in fonts (no euro sign).
  static String fromCentsPdf(int cents) {
    final n = NumberFormat('#,##0.00', 'it_IT').format(cents / 100);
    return '$n EUR';
  }

  /// Accepts Italian (`1.234,56`) and dot-decimal (`12.50`) input: the last
  /// separator is the decimal point when followed by 1–2 digits, otherwise
  /// separators are thousands (`1.234` = 1234).
  static int parseToCents(String raw) {
    final cleaned = raw.replaceAll('€', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return 0;
    final lastSep = cleaned.lastIndexOf(RegExp(r'[.,]'));
    var intPart = cleaned;
    var decPart = '';
    if (lastSep >= 0) {
      final tail = cleaned.substring(lastSep + 1);
      final isComma = cleaned[lastSep] == ',';
      if (isComma || (tail.isNotEmpty && tail.length <= 2)) {
        intPart = cleaned.substring(0, lastSep);
        decPart = tail;
      }
    }
    intPart = intPart.replaceAll('.', '').replaceAll(',', '');
    final value = double.parse('${intPart.isEmpty ? '0' : intPart}.${decPart.isEmpty ? '0' : decPart}');
    return (value * 100).round();
  }
}
