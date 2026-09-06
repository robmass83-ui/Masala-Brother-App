import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/balance_calculator.dart';
import '../../data/data_providers.dart';
import '../auth/auth_providers.dart';
import 'excel_importer.dart';
import 'excel_models.dart';
import 'excel_parser.dart';

class ImportExcelPage extends ConsumerStatefulWidget {
  const ImportExcelPage({super.key});

  @override
  ConsumerState<ImportExcelPage> createState() => _ImportExcelPageState();
}

class _ImportExcelPageState extends ConsumerState<ImportExcelPage> {
  ExcelParseResult? _parsed;
  String? _fileName;
  String? _error;
  bool _wipeManual = true;
  bool _busy = false;
  ExcelImportResult? _done;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _done = null;
      _parsed = null;
    });
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Non riesco a leggere il file. Riprova.');
      return;
    }
    _parse(file.name, bytes);
  }

  void _parse(String name, Uint8List bytes) {
    try {
      final parsed = const ExcelParser().parseBytes(bytes);
      setState(() {
        _fileName = name;
        _parsed = parsed;
        _error = null;
        _done = null;
      });
    } on ExcelParseException catch (e) {
      setState(() {
        _error = e.message;
        _parsed = null;
      });
    } catch (e) {
      setState(() {
        _error = 'File non valido: $e';
        _parsed = null;
      });
    }
  }

  Future<void> _commit() async {
    final parsed = _parsed;
    final session = ref.read(authSessionProvider).valueOrNull;
    final user = session?.user;
    final household = session?.household;
    if (parsed == null || user == null || household == null) return;

    setState(() => _busy = true);
    try {
      final result = await ExcelImporter(
        expenses: ref.read(expenseRepositoryProvider),
        transfers: ref.read(transferRepositoryProvider),
        tasks: ref.read(taskRepositoryProvider),
        activity: ref.read(activityRepositoryProvider),
      ).commit(
        parsed: parsed,
        actorUid: user.uid,
        robUid: household.robUid,
        lauUid: household.lauUid,
        wipeManualData: _wipeManual,
      );
      if (!mounted) return;
      setState(() {
        _done = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Import fallito: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parsed = _parsed;
    final current = ref.watch(balanceProvider);
    final imported = parsed?.importedBalance();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Importa Excel'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: parsed == null || _done != null
          ? null
          : Material(
              color: c.bg,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  12 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                child: PrimaryButton(
                  label: _busy ? 'Importazione…' : 'Conferma import',
                  onPressed: _busy ? null : _commit,
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Scegli il file Spese Laura Roberto. Vedrai un’anteprima: niente viene scritto finché non confermi.',
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            icon: Icons.folder_open_outlined,
            label: parsed == null ? 'Scegli file Excel' : 'Scegli un altro file',
            onPressed: _busy ? null : _pick,
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 8),
            Text(
              _fileName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.ink3, fontWeight: FontWeight.w600),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            EmptyState(message: _error!),
          ],
          if (_done != null) ...[
            const SizedBox(height: 14),
            _DoneCard(result: _done!, colors: c),
          ],
          if (parsed != null && _done == null) ...[
            const SizedBox(height: 16),
            _CountGrid(parsed: parsed),
            const SizedBox(height: 12),
            if (imported != null)
              _BalanceCompare(imported: imported, current: current),
            const SizedBox(height: 12),
            AppCard(
              onTap: _busy
                  ? null
                  : () => setState(() => _wipeManual = !_wipeManual),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elimina i dati di prova',
                          style: TextStyle(
                            color: c.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toglie spese, bonifici e cose da fare inseriti a mano, così restano solo i dati veri dell’Excel.',
                          style: TextStyle(
                            color: c.ink2,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch(
                    value: _wipeManual,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _wipeManual = v),
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return c.onAcc;
                      return c.card;
                    }),
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return c.acc;
                      return c.line;
                    }),
                  ),
                ],
              ),
            ),
            if (parsed.doubts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'RIGHE DUBBIE · ${parsed.doubts.length}',
                style: TextStyle(
                  color: c.ink2,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              for (final d in parsed.doubts.take(40)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Text(
                      'Riga ${d.row} · ${d.label}',
                      style: TextStyle(
                        color: c.warn,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              if (parsed.doubts.length > 40)
                Text(
                  'Altre ${parsed.doubts.length - 40} segnalazioni.',
                  style: TextStyle(color: c.ink3, fontWeight: FontWeight.w600),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CountGrid extends StatelessWidget {
  const _CountGrid({required this.parsed});

  final ExcelParseResult parsed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final snap = parsed.importedBalance();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Spese',
                value: '${parsed.expenses.length}',
                colors: c,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'Bonifici',
                value: '${parsed.transfers.length}',
                colors: c,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Roberto ha pagato',
                value: MoneyFormat.fromCents(snap.paidRobCents),
                colors: c,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'Laura ha pagato',
                value: MoneyFormat.fromCents(snap.paidLauCents),
                colors: c,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.ink2,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCompare extends StatelessWidget {
  const _BalanceCompare({
    required this.imported,
    required this.current,
  });

  final BalanceSnapshot imported;
  final BalanceSnapshot current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final excelCredit = imported.creditRobCents;
    final same = current.totalPaidCents == 0 ||
        current.creditRobCents == excelCredit;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo dopo l’import',
            style: TextStyle(
              color: c.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            imported.isEven
                ? 'Siete in pari'
                : imported.lauraOwesRoberto
                    ? '${MoneyFormat.fromCents(imported.absoluteCreditCents)} che Laura deve a Roberto'
                    : '${MoneyFormat.fromCents(imported.absoluteCreditCents)} che Roberto deve a Laura',
            style: TextStyle(
              color: c.acc,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            current.totalPaidCents == 0
                ? 'In app ora non c’è ancora un saldo da confrontare.'
                : same
                    ? 'Coincide con il saldo attuale in app.'
                    : 'Oggi in app il saldo è ${MoneyFormat.fromCents(current.absoluteCreditCents)}. Dopo l’import verrà sostituito (se elimini i dati di prova).',
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.result, required this.colors});

  final ExcelImportResult result;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import completato',
            style: TextStyle(
              color: colors.ok,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.insertedExpenses} spese e ${result.insertedTransfers} bonifici scritti.'
            '${result.skipped > 0 ? ' ${result.skipped} già presenti, non duplicati.' : ''}'
            '${result.wiped > 0 ? ' ${result.wiped} voci di prova rimosse.' : ''}',
            style: TextStyle(
              color: colors.ink2,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Vai al riepilogo',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}
