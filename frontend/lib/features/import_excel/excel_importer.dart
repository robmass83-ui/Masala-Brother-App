import '../../data/activity_models.dart';
import '../../data/activity_repository.dart';
import '../../data/expense_models.dart';
import '../../data/expense_repository.dart';
import '../../data/task_repository.dart';
import '../../data/transfer_models.dart';
import '../../data/transfer_repository.dart';
import 'excel_models.dart';

class ExcelImporter {
  const ExcelImporter({
    required this.expenses,
    required this.transfers,
    required this.tasks,
    this.activity,
  });

  final ExpenseRepository expenses;
  final TransferRepository transfers;
  final TaskRepository tasks;
  final ActivityRepository? activity;

  Future<ExcelImportResult> commit({
    required ExcelParseResult parsed,
    required String actorUid,
    required String robUid,
    required String lauUid,
    required bool wipeManualData,
  }) async {
    var wiped = 0;
    if (wipeManualData) {
      final existingExpenses = await expenses.fetchAll();
      final existingTransfers = await transfers.fetchAll();
      final existingTasks = await tasks.fetchAll();
      final existingLists = await tasks.fetchAllLists();
      wiped += await expenses.retireMany(
        existingExpenses
            .where((e) => !e.isDeleted && e.source != 'excel_import')
            .map((e) => e.id),
        actorUid,
      );
      wiped += await transfers.retireMany(
        existingTransfers
            .where((t) => !t.isDeleted && t.source != 'excel_import')
            .map((t) => t.id),
        actorUid,
      );
      wiped += await tasks.retireMany(
        existingTasks.where((t) => !t.isDeleted).map((t) => t.id),
        actorUid,
      );
      wiped += await tasks.retireLists(
        existingLists.where((l) => !l.isDeleted).map((l) => l.id),
        actorUid,
      );
    }

    final knownExpenses = await expenses.fetchAll();
    final knownTransfers = await transfers.fetchAll();
    final expenseKeys = {
      for (final e in knownExpenses)
        if (e.source == 'excel_import' && e.importRow != null)
          _key(e.importRow!, e.description, e.amountDueCents, e.paidRobCents,
              e.paidLauCents),
    };
    final expenseIds = knownExpenses.map((e) => e.id).toSet();
    final transferKeys = {
      for (final t in knownTransfers)
        if (t.source == 'excel_import' && t.importRow != null)
          '${t.importRow}|${t.note ?? ''}|${t.amountCents}',
    };
    final transferIds = knownTransfers.map((t) => t.id).toSet();

    final toInsertExpenses = <Expense>[];
    final toInsertTransfers = <Transfer>[];
    var skipped = 0;

    for (final row in parsed.expenses) {
      if (expenseIds.contains(row.docId) || expenseKeys.contains(row.importKey)) {
        skipped++;
        continue;
      }
      final payments = <ExpensePayment>[
        if (row.paidRobCents > 0)
          ExpensePayment(
            id: 'imp_${row.excelRow}_rob',
            payerUid: robUid,
            amountCents: row.paidRobCents,
            date: row.date,
            method: PaymentMethod.altro,
          ),
        if (row.paidLauCents > 0)
          ExpensePayment(
            id: 'imp_${row.excelRow}_lau',
            payerUid: lauUid,
            amountCents: row.paidLauCents,
            date: row.date,
            method: PaymentMethod.altro,
          ),
      ];
      toInsertExpenses.add(
        Expense(
          id: row.docId,
          description: row.description,
          amountDueCents: row.amountDueCents,
          date: row.date,
          categoryId: row.categoryId,
          propertyId: row.propertyId,
          payments: payments,
          source: 'excel_import',
          importRow: row.excelRow,
          dateEstimated: row.dateEstimated,
          createdBy: actorUid,
          updatedBy: actorUid,
        ).withTotals(robUid: robUid, lauUid: lauUid),
      );
    }

    for (final row in parsed.transfers) {
      if (row.amountCents <= 0) {
        skipped++;
        continue;
      }
      final key = '${row.excelRow}|${row.description}|${row.amountCents}';
      if (transferIds.contains(row.docId) || transferKeys.contains(key)) {
        skipped++;
        continue;
      }
      toInsertTransfers.add(
        Transfer(
          id: row.docId,
          fromUid: row.fromRob ? robUid : lauUid,
          toUid: row.fromRob ? lauUid : robUid,
          amountCents: row.amountCents,
          date: row.date,
          note: row.description,
          source: 'excel_import',
          importRow: row.excelRow,
          createdBy: actorUid,
          updatedBy: actorUid,
        ),
      );
    }

    await expenses.saveImported(toInsertExpenses);
    await transfers.saveImported(toInsertTransfers);

    await activity?.log(
      type: ActivityType.excelImported,
      refId: 'excel',
      byUid: actorUid,
      summary:
          'Ha importato ${toInsertExpenses.length} spese e ${toInsertTransfers.length} bonifici dal vecchio Excel',
    );

    return ExcelImportResult(
      insertedExpenses: toInsertExpenses.length,
      insertedTransfers: toInsertTransfers.length,
      skipped: skipped,
      wiped: wiped,
    );
  }

  String _key(int row, String description, int due, int rob, int lau) =>
      '$row|${description.trim().toLowerCase()}|$due|$rob|$lau';
}
