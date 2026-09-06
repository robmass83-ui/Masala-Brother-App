import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/data/activity_repository.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/expense_repository.dart';
import 'package:brotherapp/data/task_models.dart';
import 'package:brotherapp/data/task_repository.dart';
import 'package:brotherapp/data/transfer_repository.dart';
import 'package:brotherapp/features/import_excel/excel_classify.dart';
import 'package:brotherapp/features/import_excel/excel_date_parser.dart';
import 'package:brotherapp/features/import_excel/excel_importer.dart';
import 'package:brotherapp/features/import_excel/excel_parser.dart';

Uint8List _fixtureBytes() {
  final excel = Excel.createExcel();
  final name = excel.getDefaultSheet() ?? excel.tables.keys.first;
  final sheet = excel[name];
  sheet.cell(CellIndex.indexByString('A4')).value =
      TextCellValue('DETTAGLIO SPESA');
  sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue('DA PAGARE');
  sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue('ROBERTO');
  sheet.cell(CellIndex.indexByString('D4')).value = TextCellValue('LAURA');

  void row(int r, String desc, num due, num? rob, num lau) {
    sheet.cell(CellIndex.indexByString('A$r')).value = TextCellValue(desc);
    sheet.cell(CellIndex.indexByString('B$r')).value =
        DoubleCellValue(due.toDouble());
    if (rob != null) {
      sheet.cell(CellIndex.indexByString('C$r')).value =
          DoubleCellValue(rob.toDouble());
    }
    sheet.cell(CellIndex.indexByString('D$r')).value =
        DoubleCellValue(lau.toDouble());
  }

  row(5, 'Bolletta luce casa genn 2024', 190.53, 0, 190.53);
  row(6, 'Condominio via Addis Dic 2023', 120, 0, 120);
  row(7, 'acconto infissi via forlanini', 3000, 3000, 0);
  row(8, 'Successione', 5134, 0, 5134);
  row(9, 'Bonifico Roberto per Laura', 0, 1470, -1470);
  row(10, 'bonifico fatto da Laura per rata notaio (roberto)', 0, -750, 750);
  row(11, '30/03/2026 Rata n.1 f.cassa -forlanini', 3600, 3600, 0);
  row(12, 'rata 2 ascensore via prunizzedda  17/07/206', 590, 0, 590);
  row(13, 'Tari Sassari (lugl 2025)', 324, 162, 162);
  row(14, 'Bolletta luce via Addis mag/giugno 24', 60, 0, 60);
  row(15, 'Agenzia Funebre foto mamma', 695.4, 695.4, 0);
  row(16, 'bolletta enel apr/magg via addis', 104, null, 104);
  sheet.cell(CellIndex.indexByString('A17')).value =
      TextCellValue('TOTALE PAGATO');

  final saved = excel.save();
  return Uint8List.fromList(saved!);
}

void main() {
  const parser = ExcelParser();
  const dates = ExcelDateParser();
  const classify = ExcelClassify();

  test('parses Italian date formats from the original sheet', () {
    expect(dates.parse('Bolletta tim casa 26 dic 2023')?.date, DateTime(2023, 12, 26));
    expect(dates.parse('Bolletta luce casa genn 2024')?.date, DateTime(2024, 1, 1));
    expect(dates.parse('30/03/2026 Rata n.1')?.date, DateTime(2026, 3, 30));
    expect(
      dates.parse('rata 2 ascensore 17/07/206')?.date,
      DateTime(2026, 7, 17),
    );
    expect(dates.parse('Tari Sassari (lugl 2025)')?.date, DateTime(2025, 7, 1));
    expect(
      dates.parse('Bolletta luce via Addis mag/giugno 24')?.date,
      DateTime(2024, 6, 1),
    );
    expect(dates.parse('Agenzia Funebre foto mamma'), isNull);
  });

  test('classifies category and property from keywords', () {
    expect(classify.categoryId('Bolletta tim casa'), 'bollette');
    expect(classify.categoryId('Condominio via Addis'), 'condominio');
    expect(classify.categoryId('acconto infissi'), 'lavori');
    expect(classify.categoryId('Imu mamma'), 'tasse');
    expect(classify.categoryId('geometra Sotgiu per successione'), 'notaio');
    expect(classify.categoryId('Agenzia Funebre'), 'altro');
    expect(classify.propertyId('via forlanini 9'), 'forlanini');
    expect(classify.propertyId('via prunuzzedda'), 'prunizzedda');
    expect(classify.propertyId('Tari Sassari'), 'sassari');
    expect(classify.propertyId('Successione'), isNull);
  });

  test('fixture covers normal row, Laura-only, empty C, transfers, dates', () {
    final parsed = parser.parseBytes(_fixtureBytes());
    expect(parsed.expenses.length, 10);
    expect(parsed.transfers.length, 2);

    final lauraOnly = parsed.expenses.firstWhere(
      (e) => e.description.contains('genn 2024'),
    );
    expect(lauraOnly.paidRobCents, 0);
    expect(lauraOnly.paidLauCents, 19053);
    expect(lauraOnly.date, DateTime(2024, 1, 1));
    expect(lauraOnly.categoryId, 'bollette');

    final emptyC = parsed.expenses.firstWhere(
      (e) => e.description.contains('apr/magg'),
    );
    expect(emptyC.paidRobCents, 0);
    expect(emptyC.paidLauCents, 10400);

    final robTransfer = parsed.transfers.firstWhere((t) => t.fromRob);
    expect(robTransfer.amountCents, 147000);
    final lauTransfer = parsed.transfers.firstWhere((t) => !t.fromRob);
    expect(lauTransfer.amountCents, 75000);

    final yearFix = parsed.expenses.firstWhere(
      (e) => e.description.contains('17/07/206'),
    );
    expect(yearFix.date, DateTime(2026, 7, 17));
    expect(yearFix.yearCorrected, isTrue);
    expect(yearFix.categoryId, 'condominio');
    expect(yearFix.propertyId, 'prunizzedda');

    final estimated = parsed.expenses.firstWhere(
      (e) => e.description.startsWith('Agenzia'),
    );
    expect(estimated.dateEstimated, isTrue);

    final snap = parsed.importedBalance();
    expect(snap.paidRobCents, 817740);
    expect(snap.paidLauCents, 564053);
  });

  test('import is idempotent and can retire manual test data', () async {
    final expenseRepo = ExpenseRepository();
    final transferRepo = TransferRepository();
    final taskRepo = TaskRepository();
    final activity = ActivityRepository();
    final importer = ExcelImporter(
      expenses: expenseRepo,
      transfers: transferRepo,
      tasks: taskRepo,
      activity: activity,
    );

    await expenseRepo.save(
        draft: Expense(
          id: '',
          description: 'Spesa di prova',
          amountDueCents: 1000,
          date: DateTime(2026, 1, 1),
          categoryId: 'altro',
        ),
      actorUid: 'rob',
      robUid: 'rob',
      lauUid: 'lau',
    );
    await taskRepo.save(
      draft: const HouseholdTask(id: '', title: 'Task di prova'),
      actorUid: 'rob',
    );

    final parsed = parser.parseBytes(_fixtureBytes());
    final first = await importer.commit(
      parsed: parsed,
      actorUid: 'rob',
      robUid: 'rob',
      lauUid: 'lau',
      wipeManualData: true,
    );
    expect(first.wiped, greaterThanOrEqualTo(2));
    expect(first.insertedExpenses, parsed.expenses.length);
    expect(first.insertedTransfers, parsed.transfers.length);

    final live = await expenseRepo.fetchAll();
    expect(live.where((e) => !e.isDeleted).length, parsed.expenses.length);
    expect(
      live.where((e) => !e.isDeleted && e.description == 'Spesa di prova'),
      isEmpty,
    );
    expect(
      live.where((e) => !e.isDeleted).every((e) => e.source == 'excel_import'),
      isTrue,
    );

    final second = await importer.commit(
      parsed: parsed,
      actorUid: 'rob',
      robUid: 'rob',
      lauUid: 'lau',
      wipeManualData: true,
    );
    expect(second.insertedExpenses, 0);
    expect(second.insertedTransfers, 0);
    expect(second.skipped, parsed.expenses.length + parsed.transfers.length);
    final after = await expenseRepo.fetchAll();
    expect(after.where((e) => !e.isDeleted).length, parsed.expenses.length);
  });

  test('real Excel file matches sheet totals to the cent', () {
    final file = File('test/fixtures/Spese_Laura_Roberto_corretto.xlsx');
    expect(file.existsSync(), isTrue, reason: 'metti il file in test/fixtures');
    final parsed = parser.parseBytes(file.readAsBytesSync());

    expect(parsed.expenses.length, 65);
    expect(parsed.transfers.length, 3);
    expect(
      parsed.transfers.map((t) => t.amountCents).toSet(),
      {147000, 240000, 75000},
    );
    expect(parsed.transfers.where((t) => t.fromRob).length, 2);
    expect(parsed.transfers.where((t) => !t.fromRob).length, 1);

    final yearFix = parsed.expenses.firstWhere(
      (e) => e.description.contains('17/07/206'),
    );
    expect(yearFix.date, DateTime(2026, 7, 17));

    final over = parsed.expenses.where((e) => e.overpaid);
    expect(over, isNotEmpty);

    final snap = parsed.importedBalance();
    expect(snap.paidRobCents, 4770119);
    expect(snap.paidLauCents, 2258788);
    expect(snap.totalDueCents, 7028556);
    expect(snap.lauraOwesRoberto, isTrue);
    expect(snap.absoluteCreditCents, 1255666);
  });
}
