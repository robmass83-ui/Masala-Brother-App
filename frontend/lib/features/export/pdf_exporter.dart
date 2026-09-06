import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../data/balance_calculator.dart';
import '../../data/expense_models.dart';
import '../../data/person_uid.dart';
import '../../data/report_aggregator.dart';
import '../../data/task_models.dart';
import '../../data/transfer_models.dart';

class PdfExporter {
  const PdfExporter();

  Future<Uint8List> build({
    required ReportSnapshot snapshot,
    required String robUid,
    required String lauUid,
    required bool includeTransfers,
    required bool includeTasks,
    required String periodLabel,
    Map<String, String> categoryNames = const {},
    Map<String, String> propertyNames = const {},
  }) {
    final balance = periodBalance(
      snapshot: snapshot,
      robUid: robUid,
      lauUid: lauUid,
      includeTransfers: includeTransfers,
    );
    final doc = pw.Document();
    final base = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    pw.Widget heading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 8),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        );

    String propName(String? id) {
      if (id == null || id.isEmpty) return '-';
      return propertyNames[id] ?? id;
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: base,
          margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 32),
        ),
        header: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Rendiconto spese Laura e Roberto',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                periodLabel,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (ctx) {
          final children = <pw.Widget>[
            _balanceBox(balance),
            heading('Spese'),
            _expensesTable(snapshot.expenses),
            heading('Per immobile'),
            _namedBars(snapshot.byProperty, snapshot.maxPropertyCents),
            heading('Per categoria'),
            _namedBars(snapshot.byCategory, snapshot.maxCategoryCents),
          ];

          if (includeTransfers) {
            children.add(heading('Bonifici di conguaglio'));
            children.add(
              snapshot.transfers.isEmpty
                  ? pw.Text(
                      'Nessun bonifico nel periodo.',
                      style: const pw.TextStyle(fontSize: 10),
                    )
                  : _transfersTable(
                      snapshot.transfers,
                      robUid: robUid,
                      lauUid: lauUid,
                    ),
            );
          }

          if (includeTasks) {
            final open = snapshot.tasks.where((t) => !t.done).toList();
            children.add(heading('Cose da fare aperte'));
            children.add(
              open.isEmpty
                  ? pw.Text(
                      'Nessuna cosa da fare aperta.',
                      style: const pw.TextStyle(fontSize: 10),
                    )
                  : _tasksTable(
                      open,
                      robUid: robUid,
                      lauUid: lauUid,
                      propertyName: propName,
                    ),
            );
          }

          for (final group in snapshot.byProperty) {
            final items = snapshot.expenses.where((e) {
              final pid = (e.propertyId == null || e.propertyId!.isEmpty)
                  ? ReportAggregator.nonePropertyId
                  : e.propertyId!;
              return pid == group.id;
            }).toList();
            if (items.isEmpty) continue;
            children.add(heading('Immobile · ${group.name}'));
            children.add(
              _expensesTable(items),
            );
          }

          for (final group in snapshot.byCategory) {
            final items = snapshot.expenses
                .where((e) =>
                    (e.categoryId.isEmpty ? 'altro' : e.categoryId) == group.id)
                .toList();
            if (items.isEmpty) continue;
            children.add(heading('Categoria · ${group.name}'));
            children.add(
              _expensesTable(items),
            );
          }

          return children;
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _balanceBox(BalanceSnapshot snap) {
    final phrase = snap.isEven
        ? 'Siete in pari'
        : snap.lauraOwesRoberto
            ? 'che Laura deve a Roberto'
            : 'che Roberto deve a Laura';
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Saldo del periodo',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            MoneyFormat.fromCentsPdf(snap.absoluteCreditCents),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(phrase, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Roberto ${MoneyFormat.fromCentsPdf(snap.paidRobCents)}   ·   '
            'Laura ${MoneyFormat.fromCentsPdf(snap.paidLauCents)}   ·   '
            'Spese ${MoneyFormat.fromCentsPdf(snap.totalDueCents)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _expensesTable(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return pw.Text(
        'Nessuna spesa nel periodo.',
        style: const pw.TextStyle(fontSize: 10),
      );
    }
    var due = 0;
    var rob = 0;
    var lau = 0;
    for (final e in expenses) {
      due += e.amountDueCents;
      rob += e.paidRobCents;
      lau += e.paidLauCents;
    }
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.6),
        1: const pw.FlexColumnWidth(1.1),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(1.1),
        4: const pw.FlexColumnWidth(1.1),
        5: const pw.FlexColumnWidth(1.0),
      },
      cellAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: const [
        'Descrizione',
        'Data',
        'Dovuto',
        'Roberto',
        'Laura',
        'Stato',
      ],
      data: [
        for (final e in expenses)
          [
            e.description,
            AppDateFormat.format(e.date),
            MoneyFormat.fromCentsPdf(e.amountDueCents),
            MoneyFormat.fromCentsPdf(e.paidRobCents),
            MoneyFormat.fromCentsPdf(e.paidLauCents),
            expenseStatusLabel(e.status),
          ],
        [
          'Totale',
          '',
          MoneyFormat.fromCentsPdf(due),
          MoneyFormat.fromCentsPdf(rob),
          MoneyFormat.fromCentsPdf(lau),
          '',
        ],
      ],
    );
  }

  pw.Widget _namedBars(List<NamedAmount> items, int maxCents) {
    if (items.isEmpty) {
      return pw.Text('Nessun dato.', style: const pw.TextStyle(fontSize: 10));
    }
    return pw.Column(
      children: [
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        item.name,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Text(
                      MoneyFormat.fromCentsPdf(item.amountCents),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.LinearProgressIndicator(
                  value: maxCents == 0 ? 0 : item.amountCents / maxCents,
                  minHeight: 5,
                  backgroundColor: PdfColors.grey300,
                  valueColor: PdfColors.teal,
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _transfersTable(
    List<Transfer> transfers, {
    required String robUid,
    required String lauUid,
  }) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headers: const ['Data', 'Da', 'A', 'Importo', 'Nota'],
      data: [
        for (final t in transfers)
          [
            AppDateFormat.format(t.date),
            PersonUid.isLau(t.fromUid, robUid: robUid, lauUid: lauUid)
                ? 'Laura'
                : 'Roberto',
            PersonUid.isLau(t.toUid, robUid: robUid, lauUid: lauUid)
                ? 'Laura'
                : 'Roberto',
            MoneyFormat.fromCentsPdf(t.amountCents),
            t.note ?? '',
          ],
      ],
    );
  }

  pw.Widget _tasksTable(
    List<HouseholdTask> tasks, {
    required String robUid,
    required String lauUid,
    required String Function(String?) propertyName,
  }) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headers: const ['Cosa', 'Scadenza', 'Chi', 'Immobile'],
      data: [
        for (final t in tasks)
          [
            t.title,
            t.dueDate == null ? '-' : AppDateFormat.format(t.dueDate!),
            t.assigneeUid == null || t.assigneeUid!.isEmpty
                ? 'Chiunque'
                : (PersonUid.isLau(t.assigneeUid!, robUid: robUid, lauUid: lauUid)
                    ? 'Laura'
                    : 'Roberto'),
            propertyName(t.propertyId),
          ],
      ],
    );
  }
}
