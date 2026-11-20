import 'dart:async';

import 'package:flutter/foundation.dart';

/// How long a write may wait for the server before the UI moves on.
const localFirstGrace = Duration(seconds: 2);

/// Awaits a Firestore write the "local first" way.
///
/// With offline persistence on, `set()` / `commit()` complete only when the
/// server acknowledges the write, which never happens without a connection,
/// even though the change is already stored locally and visible in every
/// stream. Waiting on that left buttons stuck on "Salvataggio…".
///
/// This waits at most [grace]: an error arriving within it (for example a
/// rules rejection while online) is rethrown so the UI can show it; after
/// that the write stays queued and syncs when the connection returns.
Future<void> localFirst(
  Future<void> write, {
  Duration grace = localFirstGrace,
}) {
  final result = Completer<void>();
  Timer? timer;
  write.then(
    (_) {
      timer?.cancel();
      if (!result.isCompleted) result.complete();
    },
    onError: (Object e, StackTrace st) {
      timer?.cancel();
      if (!result.isCompleted) {
        result.completeError(e, st);
      } else {
        debugPrint('Sincronizzazione non riuscita: $e');
      }
    },
  );
  timer = Timer(grace, () {
    if (!result.isCompleted) result.complete();
  });
  return result.future;
}

/// Fires a secondary write (e.g. the activity log) without blocking the UI.
void fireAndForget(Future<void> write) {
  unawaited(
    write.catchError((Object e) {
      debugPrint('Scrittura secondaria non riuscita: $e');
    }),
  );
}
