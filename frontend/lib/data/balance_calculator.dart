import 'person_uid.dart';

/// Pure balance logic matching the shared Excel formulas.
///
/// All amounts are integer cents.
class BalanceCalculator {
  const BalanceCalculator();

  BalanceSnapshot calculate({
    required List<ExpenseBalanceInput> expenses,
    required List<TransferBalanceInput> transfers,
    required String robUid,
    required String lauUid,
  }) {
    var paidRob = 0;
    var paidLau = 0;
    var totalDue = 0;
    var creditRob = 0;

    var usedCustomShare = false;
    for (final e in expenses) {
      if (e.deleted) continue;
      totalDue += e.amountDueCents;
      paidRob += e.paidRobCents;
      paidLau += e.paidLauCents;

      final paidTotal = e.paidRobCents + e.paidLauCents;
      if (paidTotal == 0) continue;
      if (e.shareRobPct != 50) usedCustomShare = true;
      final robShareOfPaid =
          _percentOf(paidTotal, e.shareRobPct.clamp(0, 100));
      creditRob += e.paidRobCents - robShareOfPaid;
    }

    for (final t in transfers) {
      if (t.deleted) continue;
      // paidRob = Σ from Rob − Σ to Rob
      // paidLau = Σ from Lau − Σ to Lau
      // creditRob += from Rob − to Rob
      // Match live Firebase uids and the import placeholders `rob` / `lau`.
      if (PersonUid.isRob(t.fromUid, robUid)) {
        paidRob += t.amountCents;
        creditRob += t.amountCents;
      } else if (PersonUid.isLau(t.fromUid, robUid: robUid, lauUid: lauUid)) {
        paidLau += t.amountCents;
      }
      if (PersonUid.isRob(t.toUid, robUid)) {
        paidRob -= t.amountCents;
        creditRob -= t.amountCents;
      } else if (PersonUid.isLau(t.toUid, robUid: robUid, lauUid: lauUid)) {
        paidLau -= t.amountCents;
      }
    }

    final totalPaid = paidRob + paidLau;
    // Metà da pagare: half of total paid. Odd cent stays with higher payer
    // conceptually; displayed half uses integer division (floor).
    final halfEach = totalPaid ~/ 2;

    // With every expense at 50% the saldo is half the paid difference, same
    // as the Excel "Da restituire" cell. Odd cent goes to whoever paid more.
    if (!usedCustomShare) {
      creditRob = _halfFavoringHigher(paidRob - paidLau);
    }

    return BalanceSnapshot(
      paidRobCents: paidRob,
      paidLauCents: paidLau,
      totalDueCents: totalDue,
      totalPaidCents: totalPaid,
      halfEachCents: halfEach,
      creditRobCents: creditRob,
    );
  }

  /// `(total * pct) / 100`. For odd remainders when pct=50, the extra cent
  /// stays with whoever paid more on that expense (truncation toward zero
  /// on share, so payer of the odd cent keeps credit).
  static int _percentOf(int total, int pct) => (total * pct) ~/ 100;

  /// Half of [diff] cents; if [diff] is odd the extra cent stays with the
  /// person who paid more (positive → Roberto, negative → Laura).
  static int _halfFavoringHigher(int diff) {
    if (diff >= 0) return (diff + 1) ~/ 2;
    return -((-diff + 1) ~/ 2);
  }
}

class ExpenseBalanceInput {
  const ExpenseBalanceInput({
    required this.amountDueCents,
    required this.paidRobCents,
    required this.paidLauCents,
    this.shareRobPct = 50,
    this.deleted = false,
  });

  final int amountDueCents;
  final int paidRobCents;
  final int paidLauCents;
  final int shareRobPct;
  final bool deleted;
}

class TransferBalanceInput {
  const TransferBalanceInput({
    required this.fromUid,
    required this.toUid,
    required this.amountCents,
    this.deleted = false,
  });

  final String fromUid;
  final String toUid;
  final int amountCents;
  final bool deleted;
}

class BalanceSnapshot {
  const BalanceSnapshot({
    required this.paidRobCents,
    required this.paidLauCents,
    required this.totalDueCents,
    required this.totalPaidCents,
    required this.halfEachCents,
    required this.creditRobCents,
  });

  final int paidRobCents;
  final int paidLauCents;
  final int totalDueCents;
  final int totalPaidCents;
  final int halfEachCents;

  /// Positive → Laura owes Roberto; negative → Roberto owes Laura; 0 → even.
  final int creditRobCents;

  int get absoluteCreditCents => creditRobCents.abs();

  bool get isEven => creditRobCents == 0;

  bool get lauraOwesRoberto => creditRobCents > 0;

  double get robPaidShare {
    if (totalPaidCents == 0) return 0.5;
    return paidRobCents / totalPaidCents;
  }
}

enum ExpenseStatus { daPagare, parziale, pagato }

ExpenseStatus expenseStatus({
  required int amountDueCents,
  required int paidTotalCents,
}) {
  if (paidTotalCents <= 0) return ExpenseStatus.daPagare;
  if (paidTotalCents < amountDueCents) return ExpenseStatus.parziale;
  return ExpenseStatus.pagato;
}
