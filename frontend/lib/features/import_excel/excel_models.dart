import '../../data/balance_calculator.dart';

class ExcelParseException implements Exception {
  ExcelParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum ExcelRowKind { expense, transfer }

class ExcelDoubt {
  const ExcelDoubt({
    required this.row,
    required this.label,
  });

  final int row;
  final String label;
}

class ParsedExcelExpense {
  const ParsedExcelExpense({
    required this.excelRow,
    required this.description,
    required this.amountDueCents,
    required this.paidRobCents,
    required this.paidLauCents,
    required this.date,
    required this.dateEstimated,
    required this.categoryId,
    this.propertyId,
    this.yearCorrected = false,
  });

  final int excelRow;
  final String description;
  final int amountDueCents;
  final int paidRobCents;
  final int paidLauCents;
  final DateTime date;
  final bool dateEstimated;
  final String categoryId;
  final String? propertyId;
  final bool yearCorrected;

  String get importKey =>
      '$excelRow|${description.trim().toLowerCase()}|$amountDueCents|$paidRobCents|$paidLauCents';

  String get docId => 'imp_e_$excelRow';

  bool get overpaid => paidRobCents + paidLauCents > amountDueCents;
}

class ParsedExcelTransfer {
  const ParsedExcelTransfer({
    required this.excelRow,
    required this.description,
    required this.amountCents,
    required this.fromRob,
    required this.date,
    required this.dateEstimated,
    this.unequalLegs = false,
    this.yearCorrected = false,
  });

  final int excelRow;
  final String description;
  final int amountCents;
  final bool fromRob;
  final DateTime date;
  final bool dateEstimated;
  final bool unequalLegs;
  final bool yearCorrected;

  String get importKey =>
      '$excelRow|${description.trim().toLowerCase()}|$amountCents|${fromRob ? 'rob' : 'lau'}';

  String get docId => 'imp_t_$excelRow';
}

class ExcelParseResult {
  const ExcelParseResult({
    required this.expenses,
    required this.transfers,
    required this.doubts,
    required this.excelPaidRobCents,
    required this.excelPaidLauCents,
    required this.excelTotalDueCents,
    required this.excelCreditRobCents,
  });

  final List<ParsedExcelExpense> expenses;
  final List<ParsedExcelTransfer> transfers;
  final List<ExcelDoubt> doubts;

  /// Totals as written in the Excel summary (C2 / C3 / A2 / D3), if readable.
  final int? excelPaidRobCents;
  final int? excelPaidLauCents;
  final int? excelTotalDueCents;
  final int? excelCreditRobCents;

  BalanceSnapshot importedBalance({
    String robUid = 'rob',
    String lauUid = 'lau',
  }) {
    return const BalanceCalculator().calculate(
      expenses: [
        for (final e in expenses)
          ExpenseBalanceInput(
            amountDueCents: e.amountDueCents,
            paidRobCents: e.paidRobCents,
            paidLauCents: e.paidLauCents,
          ),
      ],
      transfers: [
        for (final t in transfers)
          TransferBalanceInput(
            fromUid: t.fromRob ? robUid : lauUid,
            toUid: t.fromRob ? lauUid : robUid,
            amountCents: t.amountCents,
          ),
      ],
      robUid: robUid,
      lauUid: lauUid,
    );
  }
}

class ExcelImportResult {
  const ExcelImportResult({
    required this.insertedExpenses,
    required this.insertedTransfers,
    required this.skipped,
    required this.wiped,
  });

  final int insertedExpenses;
  final int insertedTransfers;
  final int skipped;
  final int wiped;
}
