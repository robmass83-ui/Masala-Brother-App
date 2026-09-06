import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'balance_calculator.dart';

@immutable
class Transfer {
  const Transfer({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.amountCents,
    required this.date,
    this.note,
    this.source = 'app',
    this.importRow,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final int amountCents;
  final DateTime date;
  final String? note;
  final String source;
  final int? importRow;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Transfer copyWith({
    String? fromUid,
    String? toUid,
    int? amountCents,
    DateTime? date,
    String? note,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool clearNote = false,
  }) {
    return Transfer(
      id: id,
      fromUid: fromUid ?? this.fromUid,
      toUid: toUid ?? this.toUid,
      amountCents: amountCents ?? this.amountCents,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
      source: source,
      importRow: importRow,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toMap({required bool isCreate}) {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'amountCents': amountCents,
      'date': Timestamp.fromDate(date),
      'note': note,
      'source': source,
      'importRow': importRow,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      if (isCreate) 'createdBy': createdBy,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Transfer.fromDoc(String id, Map<String, dynamic> map) {
    return Transfer(
      id: id,
      fromUid: map['fromUid'] as String? ?? '',
      toUid: map['toUid'] as String? ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      date: _readDate(map['date']) ?? DateTime.now(),
      note: map['note'] as String?,
      source: map['source'] as String? ?? 'app',
      importRow: (map['importRow'] as num?)?.toInt(),
      createdBy: map['createdBy'] as String?,
      createdAt: _readDate(map['createdAt']),
      updatedBy: map['updatedBy'] as String?,
      updatedAt: _readDate(map['updatedAt']),
      deletedAt: _readDate(map['deletedAt']),
    );
  }

  TransferBalanceInput toBalanceInput() => TransferBalanceInput(
        fromUid: fromUid,
        toUid: toUid,
        amountCents: amountCents,
        deleted: isDeleted,
      );
}

/// Client-side checks for a settlement transfer.
class TransferValidation {
  const TransferValidation._();

  static String? validate({
    required int amountCents,
    required DateTime date,
    required String fromUid,
    required String toUid,
  }) {
    if (amountCents <= 0) {
      return 'Inserisci un importo maggiore di zero';
    }
    if (fromUid.isEmpty || toUid.isEmpty || fromUid == toUid) {
      return 'Scegli chi manda e chi riceve';
    }
    final limit = DateTime.now().add(const Duration(days: 366));
    if (date.isAfter(limit)) {
      return 'La data non può superare un anno nel futuro';
    }
    return null;
  }
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
