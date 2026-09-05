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

  static int parseToCents(String raw) {
    final cleaned = raw
        .replaceAll('€', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    if (cleaned.isEmpty) return 0;
    final value = double.parse(cleaned);
    return (value * 100).round();
  }
}
