import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/auth_models.dart';

class PaymentPart {
  const PaymentPart({required this.payerUid, required this.amountCents});

  final String payerUid;
  final int amountCents;
}

class PaymentDraft {
  const PaymentDraft(this.parts);

  final List<PaymentPart> parts;
}

/// Splits [totalCents] across the selected people.
/// With both selected, Roberto gets the floor half and Laura the remainder
/// so the two parts always sum to the total.
List<PaymentPart> splitAmongSelected({
  required int totalCents,
  required bool rob,
  required bool lau,
  required String robUid,
  required String lauUid,
}) {
  if (totalCents <= 0) return const [];
  if (rob && lau) {
    final half = totalCents ~/ 2;
    return [
      PaymentPart(payerUid: robUid, amountCents: half),
      PaymentPart(payerUid: lauUid, amountCents: totalCents - half),
    ];
  }
  if (rob) return [PaymentPart(payerUid: robUid, amountCents: totalCents)];
  if (lau) return [PaymentPart(payerUid: lauUid, amountCents: totalCents)];
  return const [];
}

/// With [initialRobCents] / [initialLauCents] the sheet opens on an existing
/// payment so it can be corrected.
Future<PaymentDraft?> askPayment({
  required BuildContext context,
  required Household household,
  required int suggestedCents,
  String title = 'Chi ha pagato?',
  int initialRobCents = 0,
  int initialLauCents = 0,
}) {
  final c = context.colors;
  return showModalBottomSheet<PaymentDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _PaymentSheet(
      household: household,
      suggestedCents: suggestedCents,
      title: title,
      initialRobCents: initialRobCents,
      initialLauCents: initialLauCents,
    ),
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.household,
    required this.suggestedCents,
    required this.title,
    required this.initialRobCents,
    required this.initialLauCents,
  });

  final Household household;
  final int suggestedCents;
  final String title;
  final int initialRobCents;
  final int initialLauCents;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  bool _rob = false;
  bool _lau = false;
  late final TextEditingController _amount;
  final _robPart = TextEditingController();
  final _lauPart = TextEditingController();

  static String _plain(int cents) =>
      cents > 0 ? MoneyFormat.fromCents(cents).replaceFirst('€', '').trim() : '';

  static int _parse(String raw) {
    try {
      return MoneyFormat.parseToCents(raw);
    } catch (_) {
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    final r = widget.initialRobCents;
    final l = widget.initialLauCents;
    _rob = r > 0;
    _lau = l > 0;
    _amount = TextEditingController(
      text: _plain(r + l > 0 ? r + l : widget.suggestedCents),
    );
    if (_both) {
      _robPart.text = _plain(r);
      _lauPart.text = _plain(l);
    } else {
      _splitHalves();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _robPart.dispose();
    _lauPart.dispose();
    super.dispose();
  }

  int get _cents => _parse(_amount.text);

  bool get _both => _rob && _lau;

  /// Resets the two parts to half each of the total.
  void _splitHalves() {
    final half = _cents ~/ 2;
    _robPart.text = _plain(half);
    _lauPart.text = _plain(_cents - half);
  }

  /// One part was typed by hand: the other becomes whatever is left.
  void _complement(TextEditingController typed, TextEditingController other) {
    final left = _cents - _parse(typed.text);
    other.text = _plain(left > 0 ? left : 0);
  }

  List<PaymentPart> get _parts {
    if (_both) {
      return [
        PaymentPart(
          payerUid: widget.household.robUid,
          amountCents: _parse(_robPart.text),
        ),
        PaymentPart(
          payerUid: widget.household.lauUid,
          amountCents: _parse(_lauPart.text),
        ),
      ].where((p) => p.amountCents > 0).toList();
    }
    return splitAmongSelected(
      totalCents: _cents,
      rob: _rob,
      lau: _lau,
      robUid: widget.household.robUid,
      lauUid: widget.household.lauUid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final parts = _parts;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: c.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Potete selezionare entrambi e dividere l’importo come volete.',
              style: TextStyle(
                color: c.ink2,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _PersonRow(
              person: PersonKey.rob,
              name: 'Roberto',
              selected: _rob,
              onTap: () => setState(() {
                _rob = !_rob;
                if (_both) _splitHalves();
              }),
            ),
            _PersonRow(
              person: PersonKey.lau,
              name: 'Laura',
              selected: _lau,
              onTap: () => setState(() {
                _lau = !_lau;
                if (_both) _splitHalves();
              }),
            ),
            if (_rob || _lau) ...[
              const SizedBox(height: 8),
              Text(
                _both ? 'Importo totale' : 'Importo pagato',
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
              ),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: TextStyle(
                  color: c.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  prefixText: '€ ',
                  prefixStyle: TextStyle(color: c.ink, fontWeight: FontWeight.w800),
                  hintText: '0,00',
                  hintStyle: TextStyle(color: c.ink3),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {
                  if (_both) _splitHalves();
                }),
              ),
              if (_both && _cents > 0) ...[
                Text(
                  'Quanto ciascuno · cambiane una, l’altra si adegua',
                  style: TextStyle(
                    color: c.ink2,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: PaymentPartField(
                        person: PersonKey.rob,
                        label: 'Roberto',
                        color: c.rob,
                        controller: _robPart,
                        onChanged: (_) =>
                            setState(() => _complement(_robPart, _lauPart)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PaymentPartField(
                        person: PersonKey.lau,
                        label: 'Laura',
                        color: c.lau,
                        controller: _lauPart,
                        onChanged: (_) =>
                            setState(() => _complement(_lauPart, _robPart)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Conferma',
                onPressed: parts.isEmpty
                    ? null
                    : () => Navigator.pop(context, PaymentDraft(parts)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Amount field for one person's share, with their avatar.
class PaymentPartField extends StatelessWidget {
  const PaymentPartField({
    super.key,
    required this.person,
    required this.label,
    required this.color,
    required this.controller,
    required this.onChanged,
  });

  final PersonKey person;
  final String label;
  final Color color;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        PersonAvatar(person: person, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: c.ink2),
              prefixText: '€ ',
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final PersonKey person;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: PersonAvatar(person: person),
      title: Text(
        name,
        style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
      ),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? c.acc : c.ink3,
      ),
      onTap: onTap,
    );
  }
}
