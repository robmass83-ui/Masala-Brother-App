import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brotherapp/core/connectivity/connectivity_provider.dart';
import 'package:brotherapp/core/theme/app_theme.dart';
import 'package:brotherapp/core/utils/date_format.dart';
import 'package:brotherapp/core/utils/money_format.dart';
import 'package:brotherapp/core/widgets/penny_thoughts.dart';
import 'package:brotherapp/data/balance_calculator.dart';
import 'package:brotherapp/data/data_providers.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/expense_repository.dart';
import 'package:brotherapp/data/task_repository.dart';
import 'package:brotherapp/data/transfer_repository.dart';
import 'package:brotherapp/features/auth/auth_providers.dart';
import 'package:brotherapp/features/auth/auth_repository.dart';
import 'package:brotherapp/features/import_excel/excel_importer.dart';
import 'package:brotherapp/features/import_excel/excel_models.dart';
import 'package:brotherapp/router/app_router.dart';

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final repo = AuthRepository(forceDemo: true);
  await repo.signInWithGoogle();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) {
          ref.onDispose(repo.dispose);
          return repo;
        }),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('it', 'IT')],
          routerConfig: ref.watch(appRouterProvider),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<Expense> _seedPaidByRoberto(
  ProviderContainer c, {
  DateTime? date,
}) async {
  final h = c.read(authSessionProvider).valueOrNull!.household!;
  final repo = c.read(expenseRepositoryProvider);
  return repo.save(
    draft: Expense(
      id: '',
      description: 'Luce',
      amountDueCents: 10000,
      date: date ?? DateTime(2026, 5, 1),
      categoryId: 'bollette',
      payments: [repo.newPayment(payerUid: h.robUid, amountCents: 10000)],
    ),
    actorUid: h.robUid,
    robUid: h.robUid,
    lauUid: h.lauUid,
  );
}

Expense _only(ProviderContainer c) => c.read(expensesProvider).valueOrNull!.single;

Future<void> _open(WidgetTester tester, ProviderContainer c, String location) async {
  c.read(appRouterProvider).go(location);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await AppDateFormat.ensureInitialized();
  });

  setUp(() {
    PennySession.resetForTest(showPenny: false);
  });

  group('MoneyFormat.parseToCents', () {
    test('reads a dot as decimal point when followed by 1-2 digits', () {
      expect(MoneyFormat.parseToCents('12.50'), 1250);
      expect(MoneyFormat.parseToCents('12.5'), 1250);
      expect(MoneyFormat.parseToCents('0.99'), 99);
    });

    test('keeps the Italian format', () {
      expect(MoneyFormat.parseToCents('12,50'), 1250);
      expect(MoneyFormat.parseToCents('1.234,56'), 123456);
      expect(MoneyFormat.parseToCents('€ 1.234,56'), 123456);
      expect(MoneyFormat.parseToCents('12,'), 1200);
      expect(MoneyFormat.parseToCents('12'), 1200);
    });

    test('a dot followed by three digits is a thousands separator', () {
      expect(MoneyFormat.parseToCents('1.234'), 123400);
      expect(MoneyFormat.parseToCents('1.234.567'), 123456700);
      expect(MoneyFormat.parseToCents('1,234.56'), 123456);
    });

    test('round-trips its own output', () {
      for (final cents in [1, 99, 1250, 123456, 360000]) {
        final text = MoneyFormat.fromCents(cents).replaceFirst('€', '').trim();
        expect(MoneyFormat.parseToCents(text), cents, reason: text);
      }
    });
  });

  testWidgets('editing an expense saves a new payer', (tester) async {
    final c = await _pumpApp(tester);
    final e = await _seedPaidByRoberto(c);
    await _open(tester, c, '/spese/${e.id}/modifica');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laura').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva spesa'));
    await tester.pumpAndSettle();

    final after = _only(c);
    expect(after.paidRobCents, 0);
    expect(after.paidLauCents, 10000);
  });

  testWidgets('editing only the description keeps existing payments',
      (tester) async {
    final c = await _pumpApp(tester);
    final e = await _seedPaidByRoberto(c);
    final paymentId = e.payments.single.id;
    await _open(tester, c, '/spese/${e.id}/modifica');
    await tester.enterText(find.widgetWithText(TextField, 'Descrizione'), 'Luce casa');
    await tester.tap(find.text('Salva spesa'));
    await tester.pumpAndSettle();

    final after = _only(c);
    expect(after.description, 'Luce casa');
    expect(after.payments.single.id, paymentId);
  });

  testWidgets('new expense: paid amount follows the total until edited',
      (tester) async {
    final c = await _pumpApp(tester);
    await _open(tester, c, '/spese/nuova');
    final amount = find.widgetWithText(TextField, 'Importo');
    await tester.enterText(amount, '1');
    await tester.enterText(find.widgetWithText(TextField, 'Descrizione'), 'Gas');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roberto').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.enterText(amount, '80');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva spesa'));
    await tester.pumpAndSettle();

    final saved = _only(c);
    expect(saved.amountDueCents, 8000);
    expect(saved.paidRobCents, 8000);
    expect(saved.status, ExpenseStatus.pagato);
  });

  testWidgets('removing a payment asks first and can be undone', (tester) async {
    final c = await _pumpApp(tester);
    final e = await _seedPaidByRoberto(c);
    await _open(tester, c, '/spese/${e.id}');

    await tester.drag(find.text('Roberto ha pagato'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare questo pagamento?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(_only(c).payments, hasLength(1));

    await tester.drag(find.text('Roberto ha pagato'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Elimina'));
    await tester.pumpAndSettle();
    expect(_only(c).payments, isEmpty);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(_only(c).payments, hasLength(1));
    expect(_only(c).paidRobCents, 10000);
  });

  testWidgets('deleting from the detail menu asks first and can be undone',
      (tester) async {
    final c = await _pumpApp(tester);
    final e = await _seedPaidByRoberto(c);
    await _open(tester, c, '/spese/${e.id}');

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina').last);
    await tester.pumpAndSettle();
    expect(find.text('Eliminare la spesa?'), findsOneWidget);
    await tester.tap(find.text('Elimina').last);
    await tester.pumpAndSettle();
    expect(c.read(expensesProvider).valueOrNull, isEmpty);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(c.read(expensesProvider).valueOrNull, hasLength(1));
  });

  testWidgets('date picker opens for an expense older than 2020', (tester) async {
    final c = await _pumpApp(tester);
    final e = await _seedPaidByRoberto(c, date: DateTime(2018, 3, 1));
    await _open(tester, c, '/spese/${e.id}/modifica');
    await tester.tap(find.textContaining('Data ·'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  test('Excel import wipe sends manual data to the trash', () async {
    final expenses = ExpenseRepository();
    final transfers = TransferRepository();
    final tasks = TaskRepository();
    await expenses.save(
      draft: Expense(
        id: '',
        description: 'spesa vera',
        amountDueCents: 500,
        date: DateTime(2026, 1, 1),
        categoryId: 'altro',
      ),
      actorUid: 'rob',
      robUid: 'rob',
      lauUid: 'lau',
    );
    final result = await ExcelImporter(
      expenses: expenses,
      transfers: transfers,
      tasks: tasks,
    ).commit(
      parsed: const ExcelParseResult(
        expenses: [],
        transfers: [],
        doubts: [],
        excelPaidRobCents: 0,
        excelPaidLauCents: 0,
        excelTotalDueCents: 0,
        excelCreditRobCents: 0,
      ),
      actorUid: 'rob',
      robUid: 'rob',
      lauUid: 'lau',
      wipeManualData: true,
    );
    expect(result.wiped, 1);
    expect(await expenses.watchExpenses().first, isEmpty);
    final trash = await expenses.watchDeleted().first;
    expect(trash.map((e) => e.description), ['spesa vera']);
  });
}
