import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/balance_calculator.dart';
import '../../data/data_providers.dart';
import '../../data/transfer_models.dart';
import '../auth/auth_providers.dart';

class TransferFormPage extends ConsumerStatefulWidget {
  const TransferFormPage({super.key});

  @override
  ConsumerState<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends ConsumerState<TransferFormPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _fromLaura = true;
  bool _defaultsApplied = false;
  bool _dirty = false;
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _amountCents {
    try {
      return MoneyFormat.parseToCents(_amountCtrl.text);
    } catch (_) {
      return 0;
    }
  }

  void _applyDefaultsIfReady() {
    if (_defaultsApplied || _dirty) return;
    final expenses = ref.read(expensesProvider);
    final transfers = ref.read(transfersProvider);
    if (!expenses.hasValue || !transfers.hasValue) return;
    final snap = ref.read(balanceProvider);
    _defaultsApplied = true;
    _fromLaura = snap.isEven || snap.lauraOwesRoberto;
    if (!snap.isEven) {
      _amountCtrl.text = MoneyFormat.fromCents(snap.absoluteCreditCents)
          .replaceFirst('€', '')
          .trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final snap = ref.watch(balanceProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final transfersAsync = ref.watch(transfersProvider);
    if (!_defaultsApplied &&
        !_dirty &&
        expensesAsync.hasValue &&
        transfersAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _defaultsApplied || _dirty) return;
        setState(_applyDefaultsIfReady);
      });
    }

    return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          title: const Text('Registra bonifico'),
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
              label: _busy ? 'Salvataggio…' : 'Registra bonifico',
              onPressed: _busy ? null : _save,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SettleHintCard(snap: snap),
            const SizedBox(height: 18),
            _FieldLabel('Chi manda i soldi'),
            const SizedBox(height: 8),
            _DirectionPicker(
              fromLaura: _fromLaura,
              onChanged: (fromLaura) => setState(() {
                _fromLaura = fromLaura;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 18),
            _FieldLabel('Importo'),
            const SizedBox(height: 6),
            _AmountField(
              controller: _amountCtrl,
              settleCents: snap.absoluteCreditCents,
              onChanged: () => setState(() => _dirty = true),
            ),
            const SizedBox(height: 18),
            _FieldLabel('Data'),
            const SizedBox(height: 6),
            _TappableField(
              icon: Icons.calendar_today_outlined,
              label: AppDateFormat.format(_date),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  locale: const Locale('it', 'IT'),
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    _date = picked;
                    _dirty = true;
                  });
                }
              },
            ),
            const SizedBox(height: 18),
            _FieldLabel('Nota'),
            const SizedBox(height: 6),
            _NoteField(
              controller: _noteCtrl,
              onChanged: () => setState(() => _dirty = true),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.swap_horiz, color: c.ink3, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Il bonifico viene registrato come voce di conguaglio: '
                    'non è una spesa, serve solo a riportare il saldo a zero.',
                    style: TextStyle(
                      color: c.ink2,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Future<void> _save() async {
    final session = ref.read(authSessionProvider).valueOrNull;
    final user = session?.user;
    final household = session?.household;
    if (user == null || household == null) return;

    final fromUid = _fromLaura ? household.lauUid : household.robUid;
    final toUid = _fromLaura ? household.robUid : household.lauUid;
    final error = TransferValidation.validate(
      amountCents: _amountCents,
      date: _date,
      fromUid: fromUid,
      toUid: toUid,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _busy = true);
    await ref.read(transferRepositoryProvider).save(
          draft: Transfer(
            id: '',
            fromUid: fromUid,
            toUid: toUid,
            amountCents: _amountCents,
            date: _date,
            note: _noteCtrl.text,
          ),
          actorUid: user.uid,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _dirty = false;
    });
    context.go('/');
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: c.ink2,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.02,
      ),
    );
  }
}

class _SettleHintCard extends StatelessWidget {
  const _SettleHintCard({required this.snap});

  final BalanceSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fromLaura = snap.isEven || snap.lauraOwesRoberto;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.accSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.accLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Per pareggiare i conti oggi',
            style: TextStyle(
              color: c.ink2,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (snap.isEven)
            Text(
              'Siete in pari. Puoi comunque registrare un bonifico.',
              style: TextStyle(
                color: c.ink,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            )
          else ...[
            Row(
              children: [
                PersonAvatar(
                  person: fromLaura ? PersonKey.lau : PersonKey.rob,
                  size: 44,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        MoneyFormat.fromCents(snap.absoluteCreditCents),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          Divider(color: c.line, height: 2, thickness: 2),
                          Icon(Icons.chevron_right, color: c.ink3, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
                PersonAvatar(
                  person: fromLaura ? PersonKey.rob : PersonKey.lau,
                  size: 44,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  fromLaura ? 'Laura' : 'Roberto',
                  style: TextStyle(
                    color: fromLaura ? c.lau : c.rob,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  fromLaura ? 'Roberto' : 'Laura',
                  style: TextStyle(
                    color: fromLaura ? c.rob : c.lau,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({
    required this.fromLaura,
    required this.onChanged,
  });

  final bool fromLaura;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.line,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DirectionSeg(
              selected: fromLaura,
              person: PersonKey.lau,
              label: 'Laura → Roberto',
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _DirectionSeg(
              selected: !fromLaura,
              person: PersonKey.rob,
              label: 'Roberto → Laura',
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionSeg extends StatelessWidget {
  const _DirectionSeg({
    required this.selected,
    required this.person,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final PersonKey person;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.card : c.line,
      elevation: selected ? 1 : 0,
      shadowColor: c.shadow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PersonAvatar(person: person, size: 26),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? c.ink : c.ink2,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.settleCents,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int settleCents;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(
                color: c.ink,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                prefixText: '€ ',
                prefixStyle: TextStyle(
                  color: c.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
                hintText: '0,00',
                hintStyle: TextStyle(color: c.ink3, fontWeight: FontWeight.w800),
                border: InputBorder.none,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (settleCents > 0)
            TextButton(
              onPressed: () {
                controller.text = MoneyFormat.fromCents(settleCents)
                    .replaceFirst('€', '')
                    .trim();
                onChanged();
              },
              style: TextButton.styleFrom(
                backgroundColor: c.accSoft,
                foregroundColor: c.acc,
                minimumSize: const Size(48, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Tutto',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _TappableField extends StatelessWidget {
  const _TappableField({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: c.ink3, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, color: c.ink3, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 120,
              style: TextStyle(
                color: c.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Opzionale',
                hintStyle: TextStyle(color: c.ink3, fontWeight: FontWeight.w600),
                border: InputBorder.none,
                counterText: '',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
