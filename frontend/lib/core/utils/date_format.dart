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

  static String formatDayMonth(DateTime date) {
    return DateFormat('d MMM', 'it_IT').format(date);
  }

  static String monthYearHeader(DateTime date) {
    return DateFormat('MMMM yyyy', 'it_IT').format(date).toUpperCase();
  }

  /// Full Italian weekday: `lunedì`.
  static String weekday(DateTime date) {
    return DateFormat('EEEE', 'it_IT').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm', 'it_IT').format(date);
  }

  /// Short relative time in Italian: adesso, 2 min fa, ieri, …
  static String relative(DateTime at, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final delta = n.difference(at);
    if (delta.isNegative || delta.inSeconds < 45) return 'adesso';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min fa';
    if (delta.inHours < 24) return '${delta.inHours} h fa';
    if (delta.inDays == 1) return 'ieri';
    if (delta.inDays < 7) return '${delta.inDays} giorni fa';
    return format(at);
  }
}
