import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'excel_classify.dart';
import 'excel_date_parser.dart';
import 'excel_models.dart';

class ExcelParser {
  const ExcelParser({
    this.dates = const ExcelDateParser(),
    this.classify = const ExcelClassify(),
  });

  final ExcelDateParser dates;
  final ExcelClassify classify;

  ExcelParseResult parseBytes(Uint8List bytes) {
    final book = Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) {
      throw ExcelParseException('Il file non contiene fogli');
    }
    final sheet = book.tables.values.first;
    return parseSheet(sheet);
  }

  ExcelParseResult parseSheet(Sheet sheet) {
    final header = _text(sheet, 3, 0).toUpperCase();
    if (header.isNotEmpty && !header.contains('DETTAGLIO')) {
      throw ExcelParseException(
        'Intestazione inattesa in riga 4: “${_text(sheet, 3, 0)}”. '
        'Serve il foglio con DETTAGLIO SPESA / DA PAGARE / ROBERTO / LAURA.',
      );
    }

    final raw = <_RawRow>[];
    for (var r = 4; r < sheet.maxRows; r++) {
      final description = _text(sheet, r, 0).trim();
      if (description.toUpperCase().contains('TOTALE PAGATO')) break;
      if (description.isEmpty) break;

      raw.add(
        _RawRow(
          excelRow: r + 1,
          description: description,
          dueCents: _cents(sheet, r, 1),
          robCents: _cents(sheet, r, 2),
          lauCents: _cents(sheet, r, 3),
        ),
      );
    }

    if (raw.isEmpty) {
      throw ExcelParseException('Nessuna riga di spesa trovata nel file');
    }

    final extracted = <ParsedExcelDate?>[];
    int? lastYear;
    for (final row in raw) {
      final parsedDate = dates.parse(row.description, fallbackYear: lastYear);
      extracted.add(parsedDate);
      if (parsedDate != null) lastYear = parsedDate.date.year;
    }

    final estimated = dates.estimateMissing(
      parsed: [for (final d in extracted) d?.date],
    );

    final expenses = <ParsedExcelExpense>[];
    final transfers = <ParsedExcelTransfer>[];
    final doubts = <ExcelDoubt>[];

    for (var i = 0; i < raw.length; i++) {
      final row = raw[i];
      final extractedDate = extracted[i];
      final date = extractedDate?.date ?? estimated[i];
      final dateEstimated = extractedDate == null;
      final yearCorrected = extractedDate?.yearCorrected ?? false;

      if (dateEstimated) {
        doubts.add(ExcelDoubt(row: row.excelRow, label: 'Data stimata'));
      }
      if (yearCorrected) {
        doubts.add(ExcelDoubt(row: row.excelRow, label: 'Anno corretto'));
      }

      if (_isTransfer(row)) {
        final rob = row.robCents;
        final lau = row.lauCents;
        final fromRob = rob > 0;
        final amount = _amountOf(row);
        final unequal = rob.abs() != lau.abs() || rob == lau;
        if (unequal) {
          doubts.add(
            ExcelDoubt(
              row: row.excelRow,
              label: 'Bonifico con importi non speculari',
            ),
          );
        }
        if (amount <= 0) continue;
        transfers.add(
          ParsedExcelTransfer(
            excelRow: row.excelRow,
            description: row.description,
            amountCents: amount,
            fromRob: fromRob,
            date: date,
            dateEstimated: dateEstimated,
            unequalLegs: unequal,
            yearCorrected: yearCorrected,
          ),
        );
        continue;
      }

      final overpaid = row.robCents + row.lauCents > row.dueCents &&
          row.dueCents > 0;
      if (overpaid) {
        doubts.add(
          ExcelDoubt(row: row.excelRow, label: 'Pagato in eccesso'),
        );
      }

      expenses.add(
        ParsedExcelExpense(
          excelRow: row.excelRow,
          description: row.description,
          amountDueCents: row.dueCents,
          paidRobCents: row.robCents < 0 ? 0 : row.robCents,
          paidLauCents: row.lauCents < 0 ? 0 : row.lauCents,
          date: date,
          dateEstimated: dateEstimated,
          categoryId: classify.categoryId(row.description),
          propertyId: classify.propertyId(row.description),
          yearCorrected: yearCorrected,
        ),
      );
    }

    return ExcelParseResult(
      expenses: expenses,
      transfers: transfers,
      doubts: doubts,
      excelPaidRobCents: _centsOrNull(sheet, 1, 2),
      excelPaidLauCents: _centsOrNull(sheet, 2, 2),
      excelTotalDueCents: _centsOrNull(sheet, 1, 0),
      excelCreditRobCents: _creditFromSheet(sheet),
    );
  }

  bool _isTransfer(_RawRow row) {
    final dueZero = row.dueCents == 0;
    final opposite = (row.robCents > 0 && row.lauCents < 0) ||
        (row.robCents < 0 && row.lauCents > 0);
    final named = row.description.toLowerCase().contains('bonifico');
    return dueZero && (opposite || named);
  }

  int _amountOf(_RawRow row) {
    if (row.robCents > 0) return row.robCents;
    if (row.lauCents > 0) return row.lauCents;
    return row.robCents.abs() > 0 ? row.robCents.abs() : row.lauCents.abs();
  }

  int? _creditFromSheet(Sheet sheet) {
    // D3 when Laura owes Roberto; D2 when the opposite.
    final d3 = _centsOrNull(sheet, 2, 3);
    if (d3 != null && d3 > 0) return d3;
    final d2 = _centsOrNull(sheet, 1, 3);
    if (d2 != null && d2 > 0) return -d2;
    return null;
  }

  String _text(Sheet sheet, int row, int col) {
    final v = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is FormulaCellValue) return v.formula.trim();
    if (v is IntCellValue) return '${v.value}';
    if (v is DoubleCellValue) return '${v.value}';
    return v.toString().trim();
  }

  int _cents(Sheet sheet, int row, int col) {
    return _centsOrNull(sheet, row, col) ?? 0;
  }

  int? _centsOrNull(Sheet sheet, int row, int col) {
    final v = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value;
    if (v == null) return null;
    if (v is IntCellValue) return v.value * 100;
    if (v is DoubleCellValue) return eurosToCents(v.value);
    if (v is FormulaCellValue) {
      final n = num.tryParse(v.formula.replaceAll(',', '.'));
      if (n != null) return eurosToCents(n);
      return null;
    }
    if (v is TextCellValue) {
      final t = v.value.toString().trim().replaceAll('.', '').replaceAll(',', '.');
      final n = num.tryParse(t);
      if (n != null) return eurosToCents(n);
    }
    return null;
  }
}

int eurosToCents(num euros) => (euros * 100).round();

class _RawRow {
  const _RawRow({
    required this.excelRow,
    required this.description,
    required this.dueCents,
    required this.robCents,
    required this.lauCents,
  });

  final int excelRow;
  final String description;
  final int dueCents;
  final int robCents;
  final int lauCents;
}
