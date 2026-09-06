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

Future<PaymentDraft?> askPayment({
  required BuildContext context,
  required Household household,
  required int suggestedCents,
  String title = 'Chi ha pagato?',
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
    ),
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.household,
    required this.suggestedCents,
    required this.title,
  });

  final Household household;
  final int suggestedCents;
  final String title;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  bool _rob = false;
  bool _lau = false;
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.suggestedCents > 0
          ? MoneyFormat.fromCents(widget.suggestedCents).replaceFirst('€', '').trim()
          : '',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _cents {
    try {
      return MoneyFormat.parseToCents(_amount.text);
    } catch (_) {
      return 0;
    }
  }

  List<PaymentPart> get _parts => splitAmongSelected(
        totalCents: _cents,
        rob: _rob,
        lau: _lau,
        robUid: widget.household.robUid,
        lauUid: widget.household.lauUid,
      );

  bool get _both => _rob && _lau;

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
              'Potete selezionare entrambi se avete pagato metà ciascuno.',
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
              onTap: () => setState(() => _rob = !_rob),
            ),
            _PersonRow(
              person: PersonKey.lau,
              name: 'Laura',
              selected: _lau,
              onTap: () => setState(() => _lau = !_lau),
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
                onChanged: (_) => setState(() {}),
              ),
              if (_both && _cents > 0) ...[
                Text(
                  'Metà ciascuno',
                  style: TextStyle(
                    color: c.ink2,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const PersonAvatar(person: PersonKey.rob, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Roberto ${MoneyFormat.fromCents(parts[0].amountCents)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.rob,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const PersonAvatar(person: PersonKey.lau, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Laura ${MoneyFormat.fromCents(parts[1].amountCents)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: c.lau,
                          fontWeight: FontWeight.w800,
                        ),
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
