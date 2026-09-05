import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Italian short date: `17 lug 2026`.
class AppDateFormat {
  AppDateFormat._();

  static bool _ready = false;

  static Future<void> ensureInitialized() async {
    if (_ready) return;
    await initializeDateFormatting('it_IT');
    _ready = true;
  }

  static String format(DateTime date) {
    return DateFormat('d MMM yyyy', 'it_IT').format(date);
  }

  static String monthYearHeader(DateTime date) {
    return DateFormat('MMMM yyyy', 'it_IT').format(date).toUpperCase();
  }
}
