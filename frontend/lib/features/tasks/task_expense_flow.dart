import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/task_models.dart';
import '../auth/auth_models.dart';
import '../expenses/expense_form_page.dart';

String? resolveLinkedExpenseId({
  String? formExpenseId,
  String? taskLinkedExpenseId,
}) {
  if (formExpenseId != null && formExpenseId.isNotEmpty) return formExpenseId;
  if (taskLinkedExpenseId != null && taskLinkedExpenseId.isNotEmpty) {
    return taskLinkedExpenseId;
  }
  return null;
}

ExpensePrefillPayer defaultPayerForCompletedTask({
  required HouseholdTask task,
  Household? household,
  String? actorUid,
}) {
  if (household != null) {
    if (task.assigneeUid == household.robUid) return ExpensePrefillPayer.rob;
    if (task.assigneeUid == household.lauUid) return ExpensePrefillPayer.lau;
    if (actorUid == household.robUid) return ExpensePrefillPayer.rob;
    if (actorUid == household.lauUid) return ExpensePrefillPayer.lau;
  }
  return ExpensePrefillPayer.none;
}

Future<void> pushExpenseForTask(
  BuildContext context, {
  required HouseholdTask task,
  required bool fromCompletion,
  Household? household,
  String? actorUid,
}) {
  final extra = ExpenseFormPrefill(
    description: task.title,
    propertyId: task.propertyId,
    taskId: task.id,
    fromTaskCompletion: fromCompletion,
    defaultPayer: fromCompletion
        ? defaultPayerForCompletedTask(
            task: task,
            household: household,
            actorUid: actorUid,
          )
        : null,
  );
  final linked = resolveLinkedExpenseId(taskLinkedExpenseId: task.linkedExpenseId);
  if (linked != null) {
    return context.push('/spese/$linked/modifica', extra: extra);
  }
  return context.push('/spese/nuova', extra: extra);
}
