import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'balance_calculator.dart';
import 'person_uid.dart';

enum PaymentMethod { bonifico, contanti, carta, altro }

@immutable
class ExpensePayment {
  const ExpensePayment({
    required this.id,
    required this.payerUid,
    required this.amountCents,
    required this.date,
    this.method = PaymentMethod.altro,
    this.note,
  });

  final String id;
  final String payerUid;
  final int amountCents;
  final DateTime date;
  final PaymentMethod method;
  final String? note;

  Map<String, dynamic> toMap() => {
        'id': id,
        'payerUid': payerUid,
        'amountCents': amountCents,
        'date': Timestamp.fromDate(date),
        'method': method.name,
        'note': note,
      };

  factory ExpensePayment.fromMap(Map<String, dynamic> map) {
    return ExpensePayment(
      id: map['id'] as String? ?? '',
      payerUid: map['payerUid'] as String? ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      date: _readDate(map['date']) ?? DateTime.now(),
      method: PaymentMethod.values.firstWhere(
        (m) => m.name == map['method'],
        orElse: () => PaymentMethod.altro,
      ),
      note: map['note'] as String?,
    );
  }
}

@immutable
class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.amountDueCents,
    required this.date,
    required this.categoryId,
    this.propertyId,
    this.shareRobPct = 50,
    this.payments = const [],
    this.paidRobCents = 0,
    this.paidLauCents = 0,
    this.paidTotalCents = 0,
    this.status = ExpenseStatus.daPagare,
    this.notes,
    this.source = 'app',
    this.importRow,
    this.dateEstimated = false,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String description;
  final int amountDueCents;
  final DateTime date;
  final String categoryId;
  final String? propertyId;
  final int shareRobPct;
  final List<ExpensePayment> payments;
  final int paidRobCents;
  final int paidLauCents;
  final int paidTotalCents;
  final ExpenseStatus status;
  final String? notes;
  final String source;
  final int? importRow;
  final bool dateEstimated;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  int get missingCents => (amountDueCents - paidTotalCents).clamp(0, 1 << 31);
  int get overpaidCents =>
      paidTotalCents > amountDueCents ? paidTotalCents - amountDueCents : 0;

  Expense copyWith({
    String? description,
    int? amountDueCents,
    DateTime? date,
    String? categoryId,
    String? propertyId,
    int? shareRobPct,
    List<ExpensePayment>? payments,
    String? notes,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool clearPropertyId = false,
  }) {
    return Expense(
      id: id,
      description: description ?? this.description,
      amountDueCents: amountDueCents ?? this.amountDueCents,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      propertyId: clearPropertyId ? null : (propertyId ?? this.propertyId),
      shareRobPct: shareRobPct ?? this.shareRobPct,
      payments: payments ?? this.payments,
      paidRobCents: paidRobCents,
      paidLauCents: paidLauCents,
      paidTotalCents: paidTotalCents,
      status: status,
      notes: notes ?? this.notes,
      source: source,
      importRow: importRow,
      dateEstimated: dateEstimated,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Expense withTotals({required String robUid, required String lauUid}) {
    var rob = 0;
    var lau = 0;
    for (final p in payments) {
      if (PersonUid.isRob(p.payerUid, robUid)) rob += p.amountCents;
      if (PersonUid.isLau(p.payerUid, robUid: robUid, lauUid: lauUid)) {
        lau += p.amountCents;
      }
    }
    final total = rob + lau;
    return Expense(
      id: id,
      description: description,
      amountDueCents: amountDueCents,
      date: date,
      categoryId: categoryId,
      propertyId: propertyId,
      shareRobPct: shareRobPct,
      payments: payments,
      paidRobCents: rob,
      paidLauCents: lau,
      paidTotalCents: total,
      status: expenseStatus(
        amountDueCents: amountDueCents,
        paidTotalCents: total,
      ),
      notes: notes,
      source: source,
      importRow: importRow,
      dateEstimated: dateEstimated,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  Map<String, dynamic> toMap({required bool isCreate}) {
    return {
      'description': description,
      'amountDueCents': amountDueCents,
      'date': Timestamp.fromDate(date),
      'categoryId': categoryId,
      'propertyId': propertyId,
      'shareRobPct': shareRobPct,
      'payments': payments.map((p) => p.toMap()).toList(),
      'paidRobCents': paidRobCents,
      'paidLauCents': paidLauCents,
      'paidTotalCents': paidTotalCents,
      'status': _statusKey(status),
      'notes': notes,
      'source': source,
      'importRow': importRow,
      'dateEstimated': dateEstimated,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      if (isCreate) 'createdBy': createdBy,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Expense.fromDoc(String id, Map<String, dynamic> map) {
    final rawPayments = map['payments'] as List<dynamic>? ?? const [];
    return Expense(
      id: id,
      description: map['description'] as String? ?? '',
      amountDueCents: (map['amountDueCents'] as num?)?.toInt() ?? 0,
      date: _readDate(map['date']) ?? DateTime.now(),
      categoryId: map['categoryId'] as String? ?? 'altro',
      propertyId: map['propertyId'] as String?,
      shareRobPct: (map['shareRobPct'] as num?)?.toInt() ?? 50,
      payments: rawPayments
          .whereType<Map>()
          .map((e) => ExpensePayment.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      paidRobCents: (map['paidRobCents'] as num?)?.toInt() ?? 0,
      paidLauCents: (map['paidLauCents'] as num?)?.toInt() ?? 0,
      paidTotalCents: (map['paidTotalCents'] as num?)?.toInt() ?? 0,
      status: _statusFromKey(map['status'] as String?),
      notes: map['notes'] as String?,
      source: map['source'] as String? ?? 'app',
      importRow: (map['importRow'] as num?)?.toInt(),
      dateEstimated: map['dateEstimated'] as bool? ?? false,
      createdBy: map['createdBy'] as String?,
      createdAt: _readDate(map['createdAt']),
      updatedBy: map['updatedBy'] as String?,
      updatedAt: _readDate(map['updatedAt']),
      deletedAt: _readDate(map['deletedAt']),
    );
  }

  ExpenseBalanceInput toBalanceInput() => ExpenseBalanceInput(
        amountDueCents: amountDueCents,
        paidRobCents: paidRobCents,
        paidLauCents: paidLauCents,
        shareRobPct: shareRobPct,
        deleted: isDeleted,
      );
}

@immutable
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.order,
    this.isDefault = false,
    this.deletedAt,
  });

  final String id;
  final String name;
  final int order;
  final bool isDefault;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  CatalogCategory copyWith({
    String? name,
    int? order,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return CatalogCategory(
      id: id,
      name: name ?? this.name,
      order: order ?? this.order,
      isDefault: isDefault,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

@immutable
class CatalogProperty {
  const CatalogProperty({
    required this.id,
    required this.name,
    required this.shortName,
    required this.order,
    this.street = '',
    this.houseNumber = '',
    this.interno = '',
    this.scala = '',
    this.floor = '',
    this.postalCode = '',
    this.city = '',
    this.notes = '',
    this.deletedAt,
  });

  final String id;
  /// Label shown in lists and reports (e.g. "Via Forlanini").
  final String name;
  /// Compact chip label (e.g. "Forlanini").
  final String shortName;
  final int order;
  final String street;
  final String houseNumber;
  final String interno;
  final String scala;
  final String floor;
  final String postalCode;
  final String city;
  final String notes;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  String get streetWithNumber {
    final via = street.trim();
    final n = houseNumber.trim();
    if (via.isEmpty) return n;
    if (n.isEmpty) return via;
    return '$via $n';
  }

  String get cityLine {
    final cap = postalCode.trim();
    final citta = city.trim();
    if (cap.isEmpty) return citta;
    if (citta.isEmpty) return cap;
    return '$cap $citta';
  }

  /// One-line address for list subtitles and the apartment register.
  String get addressLine {
    final parts = <String>[
      if (streetWithNumber.isNotEmpty) streetWithNumber,
      if (interno.trim().isNotEmpty) 'interno ${interno.trim()}',
      if (scala.trim().isNotEmpty) 'scala ${scala.trim()}',
      if (floor.trim().isNotEmpty) 'piano ${floor.trim()}',
      if (cityLine.isNotEmpty) cityLine,
    ];
    return parts.join(' · ');
  }

  bool get hasAddressDetails => addressLine.isNotEmpty || notes.trim().isNotEmpty;

  /// Subtitle under the list label: address if present, otherwise short name.
  String? get listSubtitle {
    final line = addressLine;
    if (line.isNotEmpty && line != name) return line;
    if (shortName.isNotEmpty && shortName != name) return shortName;
    return null;
  }

  factory CatalogProperty.fromMap(String id, Map<String, dynamic> data) {
    return CatalogProperty(
      id: id,
      name: data['name'] as String? ?? id,
      shortName: data['shortName'] as String? ?? data['name'] as String? ?? id,
      order: (data['order'] as num?)?.toInt() ?? 0,
      street: data['street'] as String? ?? '',
      houseNumber: data['houseNumber'] as String? ?? '',
      interno: data['interno'] as String? ?? '',
      scala: data['scala'] as String? ?? '',
      floor: data['floor'] as String? ?? '',
      postalCode: data['postalCode'] as String? ?? '',
      city: data['city'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'shortName': shortName,
        'order': order,
        'street': street,
        'houseNumber': houseNumber,
        'interno': interno,
        'scala': scala,
        'floor': floor,
        'postalCode': postalCode,
        'city': city,
        'notes': notes,
      };

  CatalogProperty copyWith({
    String? name,
    String? shortName,
    int? order,
    String? street,
    String? houseNumber,
    String? interno,
    String? scala,
    String? floor,
    String? postalCode,
    String? city,
    String? notes,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return CatalogProperty(
      id: id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      order: order ?? this.order,
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      interno: interno ?? this.interno,
      scala: scala ?? this.scala,
      floor: floor ?? this.floor,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      notes: notes ?? this.notes,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

String paymentMethodLabel(PaymentMethod method) => switch (method) {
      PaymentMethod.bonifico => 'Bonifico',
      PaymentMethod.contanti => 'Contanti',
      PaymentMethod.carta => 'Carta',
      PaymentMethod.altro => 'Altro',
    };

String _statusKey(ExpenseStatus status) => switch (status) {
      ExpenseStatus.daPagare => 'da_pagare',
      ExpenseStatus.parziale => 'parziale',
      ExpenseStatus.pagato => 'pagato',
    };

ExpenseStatus _statusFromKey(String? key) => switch (key) {
      'parziale' => ExpenseStatus.parziale,
      'pagato' => ExpenseStatus.pagato,
      _ => ExpenseStatus.daPagare,
    };

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
