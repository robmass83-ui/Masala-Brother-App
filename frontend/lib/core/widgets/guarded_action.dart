import 'package:flutter/material.dart';

/// Runs a write the user triggered and tells them when it fails, instead of
/// letting the UI silently snap back. Returns true on success.
Future<bool> guardedAction(
  BuildContext context,
  Future<void> Function() action, {
  String failure = 'Operazione non riuscita. Riprova.',
}) async {
  // Grab the messenger before the await: the page may be gone afterwards.
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
    return true;
  } catch (e) {
    debugPrint('$failure $e');
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure)));
    return false;
  }
}
