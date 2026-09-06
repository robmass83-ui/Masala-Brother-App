import '../../data/balance_calculator.dart';
import 'status_chip.dart';

ExpenseStatusUi statusToUi(ExpenseStatus status) => switch (status) {
      ExpenseStatus.daPagare => ExpenseStatusUi.daPagare,
      ExpenseStatus.parziale => ExpenseStatusUi.parziale,
      ExpenseStatus.pagato => ExpenseStatusUi.pagato,
    };
