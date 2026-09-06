import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/data_providers.dart';
import '../../data/expense_models.dart';
import '../../data/report_aggregator.dart';
import '../auth/auth_providers.dart';
import '../report/period_selector.dart';
import 'excel_exporter.dart';
import 'export_share.dart';
import 'pdf_exporter.dart';

enum ExportFormat { excel, pdf }

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  ExportFormat _format = ExportFormat.excel;
  bool _includeTransfers = true;
  bool _includeTasks = false;
  bool _unpaidOnly = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final period = ref.watch(reportPeriodProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Esporta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: Material(
        color: c.bg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: PrimaryButton(
            icon: _format == ExportFormat.excel
                ? Icons.table_chart_outlined
                : Icons.picture_as_pdf_outlined,
            label: _busy
                ? 'Generazione…'
                : (_format == ExportFormat.excel
                    ? 'Genera Excel'
                    : 'Genera PDF'),
            onPressed: _busy ? null : _generate,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'FORMATO',
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          _FormatTile(
            selected: _format == ExportFormat.excel,
            icon: Icons.table_chart_outlined,
            title: 'Excel (.xlsx)',
            subtitle: 'Stesse colonne del file attuale, con formule',
            onTap: () => setState(() => _format = ExportFormat.excel),
          ),
          const SizedBox(height: 10),
          _FormatTile(
            selected: _format == ExportFormat.pdf,
            icon: Icons.description_outlined,
            title: 'PDF',
            subtitle: 'Rendiconto leggibile, da stampare o inviare',
            onTap: () => setState(() => _format = ExportFormat.pdf),
          ),
          const SizedBox(height: 18),
          Text(
            'PERIODO',
            style: TextStyle(
              color: c.ink2,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          PeriodSelector(
            period: period,
            onChanged: (p) =>
                ref.read(reportPeriodProvider.notifier).state = p,
          ),
          const SizedBox(height: 8),
          Text(
            period.rangeLabel(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.ink3,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ToggleRow(
                  label: 'Includi bonifici di conguaglio',
                  value: _includeTransfers,
                  onChanged: (v) => setState(() => _includeTransfers = v),
                ),
                Divider(color: c.line, height: 1),
                _ToggleRow(
                  label: 'Includi cose da fare',
                  value: _includeTasks,
                  onChanged: (v) => setState(() => _includeTasks = v),
                ),
                Divider(color: c.line, height: 1),
                _ToggleRow(
                  label: 'Solo spese da pagare / parziali',
                  value: _unpaidOnly,
                  onChanged: (v) => setState(() => _unpaidOnly = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_done_outlined, color: c.ink3, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'I dati vengono letti da Firebase al momento dell’esportazione. '
                  'Il file si può salvare sul telefono o condividere su WhatsApp e OneDrive.',
                  style: TextStyle(
                    color: c.ink2,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final household = session?.household;
    if (household == null) return;

    setState(() => _busy = true);
    try {
      final period = ref.read(reportPeriodProvider);
      final expenses =
          ref.read(expensesProvider).valueOrNull ?? const [];
      final transfers =
          ref.read(transfersProvider).valueOrNull ?? const [];
      final tasks = ref.read(visibleTasksProvider);
      final cats = {
        for (final x in ref.read(categoriesProvider).valueOrNull ??
            const <CatalogCategory>[])
          x.id: x.name,
      };
      final props = {
        for (final x in ref.read(propertiesProvider).valueOrNull ??
            const <CatalogProperty>[])
          x.id: x.name,
      };
      final snapshot = const ReportAggregator().build(
        expenses: expenses,
        transfers: transfers,
        tasks: tasks,
        period: period,
        categoryNames: cats,
        propertyNames: props,
        unpaidOrPartialOnly: _unpaidOnly,
      );

      final suffix = period.fileSuffix();
      if (_format == ExportFormat.excel) {
        final bytes = const ExcelExporter().build(
          snapshot: snapshot,
          robUid: household.robUid,
          lauUid: household.lauUid,
          includeTransfers: _includeTransfers,
          includeTasks: _includeTasks,
          categoryNames: cats,
          propertyNames: props,
        );
        await shareGeneratedFile(
          bytes: bytes,
          filename: 'Rendiconto_Laura_Roberto_$suffix.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final bytes = await const PdfExporter().build(
          snapshot: snapshot,
          robUid: household.robUid,
          lauUid: household.lauUid,
          includeTransfers: _includeTransfers,
          includeTasks: _includeTasks,
          periodLabel: period.rangeLabel(),
          categoryNames: cats,
          propertyNames: props,
        );
        await shareGeneratedFile(
          bytes: bytes,
          filename: 'Rendiconto_Laura_Roberto_$suffix.pdf',
          mimeType: 'application/pdf',
        );
      }
    } catch (e) {
      if (!mounted) return;
      final c = context.colors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Non sono riuscito a creare il file. Riprova.',
            style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? c.acc : c.line, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? c.accSoft : c.line,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: selected ? c.acc : c.ink2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink2,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? c.acc : c.ink3,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: c.acc,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              thumbColor: WidgetStateProperty.all(c.ink),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return c.acc;
                return c.line;
              }),
              trackOutlineColor: WidgetStateProperty.all(c.line),
            ),
          ],
        ),
      ),
    );
  }
}
