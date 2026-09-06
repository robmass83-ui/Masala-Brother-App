import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import '../../data/expense_models.dart';
import '../../data/person_uid.dart';
import '../../data/report_aggregator.dart';
import '../../data/task_models.dart';
import '../../data/transfer_models.dart';

class ExcelExporter {
  const ExcelExporter();

  static final NumFormat euroFormat = NumFormat.custom(
    formatCode: r'#,##0.00 "€"',
  );

  static final NumFormat dateFormat = NumFormat.custom(
    formatCode: 'd mmm yyyy',
  );

  Uint8List build({
    required ReportSnapshot snapshot,
    required String robUid,
    required String lauUid,
    required bool includeTransfers,
    required bool includeTasks,
    Map<String, String> categoryNames = const {},
    Map<String, String> propertyNames = const {},
  }) {
    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet() ?? excel.tables.keys.first;
    if (defaultName != 'Spese') {
      excel.rename(defaultName, 'Spese');
    }
    excel.setDefaultSheet('Spese');

    final rows = <_SpeseRow>[
      for (final e in snapshot.expenses)
        _SpeseRow.expense(
          e,
          robUid: robUid,
          category: categoryNames[e.categoryId] ?? e.categoryId,
          property: e.propertyId == null
              ? ''
              : (propertyNames[e.propertyId!] ?? e.propertyId!),
        ),
      if (includeTransfers)
        for (final t in snapshot.transfers)
          _SpeseRow.transfer(t, robUid: robUid, lauUid: lauUid),
    ]..sort((a, b) => a.date.compareTo(b.date));

    _writeSpeseSheet(excel['Spese'], rows);
    _writePagamentiSheet(
      excel['Pagamenti'],
      snapshot.expenses,
      robUid: robUid,
      lauUid: lauUid,
    );
    if (includeTasks) {
      _writeTasksSheet(
        excel['Da fare'],
        snapshot.tasks,
        robUid: robUid,
        lauUid: lauUid,
        propertyNames: propertyNames,
      );
    }

    final saved = excel.save();
    if (saved == null) {
      throw StateError('Impossibile generare il file Excel');
    }
    return Uint8List.fromList(_freezeTopRows(saved, rows: 4));
  }

  void _writeSpeseSheet(Sheet sheet, List<_SpeseRow> rows) {
    const headerRow = 3; // Excel row 4
    final dataStart = 5;
    final lastData = rows.isEmpty ? 5 : 4 + rows.length;

    final bold = CellStyle(bold: true);
    final boldEuro = CellStyle(bold: true, numberFormat: euroFormat);
    final euro = CellStyle(numberFormat: euroFormat);
    final dateStyle = CellStyle(numberFormat: dateFormat);
    final headerStyle = CellStyle(bold: true);

    void text(int c, int r, String v, {CellStyle? style}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        TextCellValue(v),
        cellStyle: style,
      );
    }

    void formula(int c, int r, String f, {CellStyle? style}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        FormulaCellValue(f),
        cellStyle: style,
      );
    }

    void money(int c, int r, int cents, {CellStyle? style}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        DoubleCellValue(cents / 100.0),
        cellStyle: style ?? euro,
      );
    }

    text(0, 0, 'Spese totali', style: bold);
    formula(1, 0, 'SUM(B$dataStart:B$lastData)', style: boldEuro);
    text(2, 0, 'TOT pagato Roberto', style: bold);
    formula(3, 0, 'SUM(C$dataStart:C$lastData)', style: boldEuro);

    text(0, 1, 'TOT pagato Laura', style: bold);
    formula(1, 1, 'SUM(D$dataStart:D$lastData)', style: boldEuro);
    text(2, 1, 'Metà da pagare', style: bold);
    formula(3, 1, '(D1+B2)/2', style: boldEuro);

    text(0, 2, 'Da restituire', style: bold);
    formula(1, 2, 'ABS(D1-B2)/2', style: boldEuro);
    formula(
      2,
      2,
      'IF(D1>B2,"Laura deve a Roberto",IF(B2>D1,"Roberto deve a Laura","Siete in pari"))',
      style: bold,
    );

    const headers = [
      'DETTAGLIO SPESA',
      'DA PAGARE',
      'ROBERTO',
      'LAURA',
      'STATO',
      'CORRISPOSTO',
      'DATA',
      'CATEGORIA',
      'IMMOBILE',
      'ID',
    ];
    for (var i = 0; i < headers.length; i++) {
      text(i, headerRow, headers[i], style: headerStyle);
    }

    for (var i = 0; i < rows.length; i++) {
      final r = headerRow + 1 + i;
      final excelRow = r + 1;
      final row = rows[i];
      text(0, r, row.description);
      money(1, r, row.dueCents);
      money(2, r, row.robCents);
      money(3, r, row.lauCents);
      formula(
        4,
        r,
        'IF(B$excelRow=0,"",IF(F$excelRow=0,"DA PAGARE",IF(F$excelRow<B$excelRow,"PARZIALE","PAGATO")))',
      );
      formula(5, r, 'C$excelRow+D$excelRow', style: euro);
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r),
        DateCellValue(year: row.date.year, month: row.date.month, day: row.date.day),
        cellStyle: dateStyle,
      );
      text(7, r, row.category);
      text(8, r, row.property);
      text(9, r, row.id);
    }

    const widths = [42.0, 14.0, 14.0, 14.0, 14.0, 14.0, 14.0, 22.0, 18.0, 16.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  void _writePagamentiSheet(
    Sheet sheet,
    List<Expense> expenses, {
    required String robUid,
    required String lauUid,
  }) {
    final header = CellStyle(bold: true);
    final euro = CellStyle(numberFormat: euroFormat);
    final dateStyle = CellStyle(numberFormat: dateFormat);

    const titles = [
      'DATA',
      'DETTAGLIO SPESA',
      'CHI',
      'IMPORTO',
      'METODO',
      'NOTA',
      'ID SPESA',
      'ID PAGAMENTO',
    ];
    for (var i = 0; i < titles.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        TextCellValue(titles[i]),
        cellStyle: header,
      );
    }

    final payments = <({
      DateTime date,
      String description,
      String who,
      int cents,
      String method,
      String note,
      String expenseId,
      String paymentId,
    })>[];
    for (final e in expenses) {
      for (final p in e.payments) {
        payments.add((
          date: p.date,
          description: e.description,
          who: PersonUid.isLau(p.payerUid, robUid: robUid, lauUid: lauUid)
              ? 'Laura'
              : (PersonUid.isRob(p.payerUid, robUid) ? 'Roberto' : p.payerUid),
          cents: p.amountCents,
          method: paymentMethodLabel(p.method),
          note: p.note ?? '',
          expenseId: e.id,
          paymentId: p.id,
        ));
      }
    }
    payments.sort((a, b) => a.date.compareTo(b.date));

    for (var i = 0; i < payments.length; i++) {
      final p = payments[i];
      final r = i + 1;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        DateCellValue(year: p.date.year, month: p.date.month, day: p.date.day),
        cellStyle: dateStyle,
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r),
        TextCellValue(p.description),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r),
        TextCellValue(p.who),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r),
        DoubleCellValue(p.cents / 100.0),
        cellStyle: euro,
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r),
        TextCellValue(p.method),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r),
        TextCellValue(p.note),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r),
        TextCellValue(p.expenseId),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: r),
        TextCellValue(p.paymentId),
      );
    }

    const widths = [14.0, 42.0, 14.0, 14.0, 14.0, 24.0, 16.0, 16.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  void _writeTasksSheet(
    Sheet sheet,
    List<HouseholdTask> tasks, {
    required String robUid,
    required String lauUid,
    required Map<String, String> propertyNames,
  }) {
    final header = CellStyle(bold: true);
    final dateStyle = CellStyle(numberFormat: dateFormat);
    const titles = [
      'COSA',
      'SCADENZA',
      'ASSEGNATARIO',
      'IMMOBILE',
      'FATTA',
      'NOTE',
      'ID',
    ];
    for (var i = 0; i < titles.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        TextCellValue(titles[i]),
        cellStyle: header,
      );
    }
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final r = i + 1;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        TextCellValue(t.title),
      );
      if (t.dueDate != null) {
        final d = t.dueDate!;
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r),
          DateCellValue(year: d.year, month: d.month, day: d.day),
          cellStyle: dateStyle,
        );
      }
      final who = t.assigneeUid == null || t.assigneeUid!.isEmpty
          ? 'Chiunque'
          : (PersonUid.isLau(t.assigneeUid!, robUid: robUid, lauUid: lauUid)
              ? 'Laura'
              : (PersonUid.isRob(t.assigneeUid!, robUid)
                  ? 'Roberto'
                  : t.assigneeUid!));
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r),
        TextCellValue(who),
      );
      final prop = t.propertyId == null
          ? ''
          : (propertyNames[t.propertyId!] ?? t.propertyId!);
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r),
        TextCellValue(prop),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r),
        TextCellValue(t.done ? 'Sì' : 'No'),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r),
        TextCellValue(t.notes ?? ''),
      );
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: r),
        TextCellValue(t.id),
      );
    }
    const widths = [40.0, 14.0, 16.0, 18.0, 10.0, 28.0, 16.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }
}

class _SpeseRow {
  const _SpeseRow({
    required this.id,
    required this.description,
    required this.dueCents,
    required this.robCents,
    required this.lauCents,
    required this.date,
    required this.category,
    required this.property,
  });

  factory _SpeseRow.expense(
    Expense e, {
    required String robUid,
    required String category,
    required String property,
  }) {
    return _SpeseRow(
      id: e.id,
      description: e.description,
      dueCents: e.amountDueCents,
      robCents: e.paidRobCents,
      lauCents: e.paidLauCents,
      date: e.date,
      category: category,
      property: property,
    );
  }

  factory _SpeseRow.transfer(
    Transfer t, {
    required String robUid,
    required String lauUid,
  }) {
    final fromRob = PersonUid.isRob(t.fromUid, robUid);
    return _SpeseRow(
      id: t.id,
      description: fromRob
          ? 'Bonifico Roberto per Laura'
          : 'Bonifico Laura per Roberto',
      dueCents: 0,
      robCents: fromRob ? t.amountCents : -t.amountCents,
      lauCents: fromRob ? -t.amountCents : t.amountCents,
      date: t.date,
      category: '',
      property: '',
    );
  }

  final String id;
  final String description;
  final int dueCents;
  final int robCents;
  final int lauCents;
  final DateTime date;
  final String category;
  final String property;
}

List<int> _freezeTopRows(List<int> xlsxBytes, {required int rows}) {
  final archive = ZipDecoder().decodeBytes(xlsxBytes);
  final out = Archive();
  var applied = false;
  for (final file in archive.files) {
    if (!applied &&
        file.name.contains('worksheets/sheet1.xml') &&
        file.isFile) {
      var xml = utf8.decode(file.content as List<int>);
      final pane =
          '<pane ySplit="$rows" topLeftCell="A${rows + 1}" activePane="bottomLeft" state="frozen"/>'
          '<selection pane="bottomLeft"/>';
      if (xml.contains('state="frozen"')) {
        out.addFile(file);
        applied = true;
        continue;
      }
      xml = xml.replaceFirstMapped(
        RegExp(r'<sheetView([^>]*)/>'),
        (m) => '<sheetView${m[1]}>$pane</sheetView>',
      );
      if (!xml.contains('state="frozen"')) {
        xml = xml.replaceFirstMapped(
          RegExp(r'<sheetView([^>]*)></sheetView>'),
          (m) => '<sheetView${m[1]}>$pane</sheetView>',
        );
      }
      final encoded = utf8.encode(xml);
      out.addFile(ArchiveFile(file.name, encoded.length, encoded));
      applied = true;
    } else {
      out.addFile(file);
    }
  }
  final encoded = ZipEncoder().encode(out);
  return encoded ?? xlsxBytes;
}
