import 'package:flutter/foundation.dart';

import '../core/utils/date_format.dart';

enum ReportPeriodKind { currentYear, all, custom }

/// Inclusive date window (local calendar days). [from]/[to] null means unbounded.
@immutable
class ReportPeriod {
  const ReportPeriod({
    required this.kind,
    this.from,
    this.to,
  });

  factory ReportPeriod.currentYear({DateTime? now}) {
    final n = now ?? DateTime.now();
    return ReportPeriod(
      kind: ReportPeriodKind.currentYear,
      from: DateTime(n.year, 1, 1),
      to: DateTime(n.year, 12, 31),
    );
  }

  factory ReportPeriod.all() =>
      const ReportPeriod(kind: ReportPeriodKind.all);

  factory ReportPeriod.custom(DateTime from, DateTime to) {
    final a = dateOnly(from);
    final b = dateOnly(to);
    return ReportPeriod(
      kind: ReportPeriodKind.custom,
      from: a.isBefore(b) ? a : b,
      to: a.isBefore(b) ? b : a,
    );
  }

  final ReportPeriodKind kind;
  final DateTime? from;
  final DateTime? to;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool contains(DateTime date) {
    final d = dateOnly(date);
    if (from != null && d.isBefore(from!)) return false;
    if (to != null && d.isAfter(to!)) return false;
    return true;
  }

  String segmentLabel({DateTime? now}) {
    switch (kind) {
      case ReportPeriodKind.currentYear:
        return 'Anno ${(now ?? DateTime.now()).year}';
      case ReportPeriodKind.all:
        return 'Tutto';
      case ReportPeriodKind.custom:
        return 'Periodo…';
    }
  }

  String rangeLabel({DateTime? now}) {
    switch (kind) {
      case ReportPeriodKind.currentYear:
        final y = (now ?? DateTime.now()).year;
        return '1 gen $y – 31 dic $y';
      case ReportPeriodKind.all:
        return 'Tutte le date';
      case ReportPeriodKind.custom:
        if (from == null || to == null) return 'Periodo personalizzato';
        return '${AppDateFormat.format(from!)} – ${AppDateFormat.format(to!)}';
    }
  }

  String fileSuffix({DateTime? now}) {
    switch (kind) {
      case ReportPeriodKind.currentYear:
        return '${(now ?? DateTime.now()).year}';
      case ReportPeriodKind.all:
        return 'tutto';
      case ReportPeriodKind.custom:
        if (from == null || to == null) return 'periodo';
        return '${_ymd(from!)}_${_ymd(to!)}';
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  ReportPeriod copyWith({
    ReportPeriodKind? kind,
    DateTime? from,
    DateTime? to,
    bool clearBounds = false,
  }) {
    return ReportPeriod(
      kind: kind ?? this.kind,
      from: clearBounds ? null : (from ?? this.from),
      to: clearBounds ? null : (to ?? this.to),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod &&
      other.kind == kind &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(kind, from, to);
}
