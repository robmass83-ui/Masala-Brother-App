import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/utils/date_format.dart';
import 'package:brotherapp/data/balance_calculator.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/report_aggregator.dart';
import 'package:brotherapp/data/report_period.dart';
import 'package:brotherapp/data/task_models.dart';
import 'package:brotherapp/data/transfer_models.dart';
import 'package:brotherapp/features/export/excel_exporter.dart';
import 'package:brotherapp/features/export/pdf_exporter.dart';

Expense _expense({
  required String id,
  required String description,
  required DateTime date,
  required int due,
  int rob = 0,
  int lau = 0,
  String categoryId = 'bollette',
  String? propertyId = 'forlanini',
}) {
  final total = rob + lau;
  return Expense(
    id: id,
    description: description,
    amountDueCents: due,
    date: date,
    categoryId: categoryId,
    propertyId: propertyId,
    paidRobCents: rob,
    paidLauCents: lau,
    paidTotalCents: total,
    status: expenseStatus(amountDueCents: due, paidTotalCents: total),
    payments: [
      if (rob > 0)
        ExpensePayment(
          id: 'p-$id-rob',
          payerUid: 'rob',
          amountCents: rob,
          date: date,
          method: PaymentMethod.bonifico,
        ),
      if (lau > 0)
        ExpensePayment(
          id: 'p-$id-lau',
          payerUid: 'lau',
          amountCents: lau,
          date: date,
          method: PaymentMethod.contanti,
        ),
    ],
  );
}

void main() {
  setUpAll(() async {
    await AppDateFormat.ensureInitialized();
  });

  late ReportSnapshot snapshot;

  setUp(() {
    snapshot = const ReportAggregator().build(
      expenses: [
        _expense(
          id: 'e1',
          description: 'Bolletta luce',
          date: DateTime(2026, 3, 10),
          due: 10000,
          rob: 10000,
        ),
        _expense(
          id: 'e2',
          description: 'Condominio',
          date: DateTime(2026, 4, 1),
          due: 4000,
          lau: 2000,
          categoryId: 'condominio',
          propertyId: 'addis',
        ),
      ],
      transfers: [
        Transfer(
          id: 't1',
          fromUid: 'rob',
          toUid: 'lau',
          amountCents: 150000,
          date: DateTime(2026, 5, 1),
          note: 'Conguaglio',
        ),
      ],
      tasks: [
        HouseholdTask(
          id: 'k1',
          title: 'Rinnovare assicurazione',
          dueDate: DateTime(2026, 10, 1),
          assigneeUid: 'lau',
        ),
      ],
      period: ReportPeriod.all(),
      categoryNames: const {
        'bollette': 'Bollette',
        'condominio': 'Condominio',
      },
      propertyNames: const {
        'forlanini': 'Forlanini 9',
        'addis': 'Via Addis',
      },
    );
  });

  test('excel has Spese formulas, transfer signs and Pagamenti sheet', () {
    final bytes = const ExcelExporter().build(
      snapshot: snapshot,
      robUid: 'rob',
      lauUid: 'lau',
      includeTransfers: true,
      includeTasks: true,
      categoryNames: const {
        'bollette': 'Bollette',
        'condominio': 'Condominio',
      },
      propertyNames: const {
        'forlanini': 'Forlanini 9',
        'addis': 'Via Addis',
      },
    );
    expect(bytes.length, greaterThan(100));

    final archive = ZipDecoder().decodeBytes(bytes);
    final sheetFile = archive.files.firstWhere(
      (f) => f.name.contains('worksheets/sheet1.xml'),
    );
    final sheetXml = utf8.decode(sheetFile.content as List<int>);
    expect(sheetXml.contains('frozen'), isTrue);

    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys, containsAll(['Spese', 'Pagamenti', 'Da fare']));

    final spese = book['Spese'];
    CellValue? at(String a1) =>
        spese.cell(CellIndex.indexByString(a1)).value;
    num money(String a1) {
      final v = at(a1);
      if (v is IntCellValue) return v.value;
      if (v is DoubleCellValue) return v.value;
      fail('expected number at $a1, got $v');
    }

    expect(at('A1'), TextCellValue('Spese totali'));
    expect(at('B1'), isA<FormulaCellValue>());
    expect((at('B1') as FormulaCellValue).formula, contains('SUM(B5'));
    expect((at('D1') as FormulaCellValue).formula, contains('SUM(C5'));
    expect((at('B2') as FormulaCellValue).formula, contains('SUM(D5'));
    expect((at('D2') as FormulaCellValue).formula, '(D1+B2)/2');
    expect((at('B3') as FormulaCellValue).formula, 'ABS(D1-B2)/2');

    expect(at('A4'), TextCellValue('DETTAGLIO SPESA'));
    expect(at('B4'), TextCellValue('DA PAGARE'));
    expect(at('J4'), TextCellValue('ID'));

    expect(at('A5'), TextCellValue('Bolletta luce'));
    expect(money('B5'), 100);
    expect(money('C5'), 100);
    expect((at('E5') as FormulaCellValue).formula, contains('DA PAGARE'));
    expect((at('F5') as FormulaCellValue).formula, 'C5+D5');

    expect(at('A7'), TextCellValue('Bonifico Roberto per Laura'));
    expect(money('B7'), 0);
    expect(money('C7'), 1500);
    expect(money('D7'), -1500);

    final pagamenti = book['Pagamenti'];
    expect(
      pagamenti.cell(CellIndex.indexByString('A1')).value,
      TextCellValue('DATA'),
    );
    expect(
      pagamenti.cell(CellIndex.indexByString('B2')).value,
      TextCellValue('Bolletta luce'),
    );
    expect(
      pagamenti.cell(CellIndex.indexByString('C2')).value,
      TextCellValue('Roberto'),
    );

    final tasks = book['Da fare'];
    expect(
      tasks.cell(CellIndex.indexByString('A2')).value,
      TextCellValue('Rinnovare assicurazione'),
    );
    expect(
      tasks.cell(CellIndex.indexByString('C2')).value,
      TextCellValue('Laura'),
    );
  });

  test('excel omits transfers and tasks when flags are off', () {
    final bytes = const ExcelExporter().build(
      snapshot: snapshot,
      robUid: 'rob',
      lauUid: 'lau',
      includeTransfers: false,
      includeTasks: false,
    );
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys.contains('Da fare'), isFalse);
    final spese = book['Spese'];
    expect(
      spese.cell(CellIndex.indexByString('A7')).value,
      isNot(TextCellValue('Bonifico Roberto per Laura')),
    );
  });

  test('pdf starts with %PDF and includes period header text', () async {
    final bytes = await const PdfExporter().build(
      snapshot: snapshot,
      robUid: 'rob',
      lauUid: 'lau',
      includeTransfers: true,
      includeTasks: true,
      periodLabel: 'Tutte le date',
      categoryNames: const {'bollette': 'Bollette', 'condominio': 'Condominio'},
      propertyNames: const {'forlanini': 'Forlanini 9', 'addis': 'Via Addis'},
    );
    expect(bytes.length, greaterThan(200));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
  });
}
