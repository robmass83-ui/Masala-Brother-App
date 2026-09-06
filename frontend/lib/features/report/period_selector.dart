import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../data/report_period.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: c.line,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _Seg(
                  label: ReportPeriod.currentYear(now: now).segmentLabel(now: now),
                  selected: period.kind == ReportPeriodKind.currentYear,
                  onTap: () => onChanged(ReportPeriod.currentYear(now: now)),
                ),
              ),
              Expanded(
                child: _Seg(
                  label: 'Tutto',
                  selected: period.kind == ReportPeriodKind.all,
                  onTap: () => onChanged(ReportPeriod.all()),
                ),
              ),
              Expanded(
                child: _Seg(
                  label: 'Periodo…',
                  selected: period.kind == ReportPeriodKind.custom,
                  onTap: () => _pickCustom(context),
                ),
              ),
            ],
          ),
        ),
        if (period.kind == ReportPeriodKind.custom) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateChip(
                  label: period.from == null
                      ? 'Da'
                      : AppDateFormat.format(period.from!),
                  onTap: () => _pickBound(context, isFrom: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateChip(
                  label: period.to == null
                      ? 'A'
                      : AppDateFormat.format(period.to!),
                  onTap: () => _pickBound(context, isFrom: false),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final from = period.from ?? DateTime(now.year, 1, 1);
    final to = period.to ?? now;
    onChanged(ReportPeriod.custom(from, to));
    await _pickBound(context, isFrom: true);
  }

  Future<void> _pickBound(BuildContext context, {required bool isFrom}) async {
    final now = DateTime.now();
    final current = isFrom
        ? (period.from ?? DateTime(now.year, 1, 1))
        : (period.to ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 366)),
      locale: const Locale('it', 'IT'),
    );
    if (picked == null) return;
    final from = isFrom ? picked : (period.from ?? picked);
    final to = isFrom ? (period.to ?? picked) : picked;
    onChanged(ReportPeriod.custom(from, to));
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.card : const Color(0x00000000),
      elevation: selected ? 1 : 0,
      shadowColor: c.shadow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? c.ink : c.ink2,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: c.ink3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
