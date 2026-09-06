import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool connectivityIsOnline(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}

/// Defaults to online. The plugin is ignored if it throws or times out (tests).
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  yield true;
  try {
    final plugin = Connectivity();
    final current = await plugin.checkConnectivity().timeout(
      const Duration(milliseconds: 400),
    );
    yield connectivityIsOnline(current);
    await for (final results in plugin.onConnectivityChanged) {
      yield connectivityIsOnline(results);
    }
  } catch (_) {
    yield true;
  }
});
