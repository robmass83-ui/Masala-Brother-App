import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/data_providers.dart';
import '../../data/report_aggregator.dart';
import '../../data/report_period.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/export/excel_exporter.dart';
import '../connectivity/connectivity_provider.dart';
import 'drive_client.dart';

/// Name of the Excel kept up to date in each person's Google Drive.
const driveBackupFileName = 'Masala Brother - Spese.xlsx';

@immutable
class DriveBackupState {
  const DriveBackupState({
    this.enabled = false,
    this.fileId,
    this.lastBackupAt,
    this.pending = false,
    this.busy = false,
    this.error,
    this.needsPermission = false,
  });

  final bool enabled;
  final String? fileId;
  final DateTime? lastBackupAt;

  /// Something changed that isn't in Drive yet (e.g. saved offline).
  final bool pending;
  final bool busy;
  final String? error;
  final bool needsPermission;

  String? get fileUrl =>
      fileId == null ? null : 'https://drive.google.com/file/d/$fileId/view';

  DriveBackupState copyWith({
    bool? enabled,
    String? fileId,
    DateTime? lastBackupAt,
    bool? pending,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? needsPermission,
  }) {
    return DriveBackupState(
      enabled: enabled ?? this.enabled,
      fileId: fileId ?? this.fileId,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      pending: pending ?? this.pending,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      needsPermission: needsPermission ?? this.needsPermission,
    );
  }
}

/// Where the backup settings live on the phone, per Google account.
abstract class DriveBackupStore {
  Future<DriveBackupState> load(String uid);
  Future<void> save(String uid, DriveBackupState state);
}

class MemoryDriveBackupStore implements DriveBackupStore {
  final _data = <String, DriveBackupState>{};

  @override
  Future<DriveBackupState> load(String uid) async =>
      _data[uid] ?? const DriveBackupState();

  @override
  Future<void> save(String uid, DriveBackupState state) async =>
      _data[uid] = state;
}

class PrefsDriveBackupStore implements DriveBackupStore {
  final _fallback = MemoryDriveBackupStore();

  String _k(String uid, String key) => 'drive_backup_${uid}_$key';

  @override
  Future<DriveBackupState> load(String uid) async {
    try {
      final p = await SharedPreferences.getInstance();
      final at = p.getInt(_k(uid, 'last_at'));
      return DriveBackupState(
        enabled: p.getBool(_k(uid, 'enabled')) ?? false,
        fileId: p.getString(_k(uid, 'file_id')),
        lastBackupAt: at == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(at),
        pending: p.getBool(_k(uid, 'pending')) ?? false,
      );
    } catch (_) {
      return _fallback.load(uid);
    }
  }

  @override
  Future<void> save(String uid, DriveBackupState s) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_k(uid, 'enabled'), s.enabled);
      await p.setBool(_k(uid, 'pending'), s.pending);
      if (s.fileId != null) await p.setString(_k(uid, 'file_id'), s.fileId!);
      if (s.lastBackupAt != null) {
        await p.setInt(
          _k(uid, 'last_at'),
          s.lastBackupAt!.millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      await _fallback.save(uid, s);
    }
  }
}

final driveBackupStoreProvider = Provider<DriveBackupStore>(
  (ref) => PrefsDriveBackupStore(),
);

final driveClientProvider = Provider<DriveClient>((ref) {
  return GoogleDriveClient(
    authHeaders: () => ref.read(authRepositoryProvider).driveAuthHeaders(),
  );
});

/// How long to wait after a change before uploading, so a burst of edits
/// (amount, then payment, then split) becomes one upload.
final driveBackupDebounceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 4),
);

final driveBackupProvider =
    NotifierProvider<DriveBackupController, DriveBackupState>(
      DriveBackupController.new,
    );

/// Keeps an Excel copy of all expenses and transfers in the user's Google
/// Drive, rewritten after every money change made from this phone.
class DriveBackupController extends Notifier<DriveBackupState> {
  Timer? _debounce;
  bool _running = false;
  bool _runAgain = false;
  String? _uid;

  @override
  DriveBackupState build() {
    _uid = ref.watch(authSessionProvider).valueOrNull?.user?.uid;
    // Keep the data the Excel is built from loaded, without rebuilding.
    ref.listen(expensesProvider, (_, __) {});
    ref.listen(transfersProvider, (_, __) {});
    ref.listen(categoryNamesProvider, (_, __) {});
    ref.listen(propertyNamesProvider, (_, __) {});
    // Back online with something not yet uploaded: upload it now.
    ref.listen(isOnlineProvider, (prev, next) {
      if (next.valueOrNull == true && state.enabled && state.pending) {
        unawaited(runNow());
      }
    });
    ref.onDispose(() => _debounce?.cancel());

    final uid = _uid;
    if (uid != null) unawaited(_load(uid));
    return const DriveBackupState();
  }

  Future<void> _load(String uid) async {
    final saved = await ref.read(driveBackupStoreProvider).load(uid);
    if (_uid != uid) return;
    state = saved;
    // A change saved while offline or before the app was closed.
    if (saved.enabled && saved.pending) unawaited(runNow());
  }

  Future<void> _persist() async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(driveBackupStoreProvider).save(uid, state);
  }

  /// Called by the repositories after a spesa, payment or bonifico changes.
  void notifyMoneyChanged() {
    if (!state.enabled || _uid == null) return;
    if (!state.pending) {
      state = state.copyWith(pending: true);
      unawaited(_persist());
    }
    _debounce?.cancel();
    _debounce = Timer(ref.read(driveBackupDebounceProvider), () {
      unawaited(runNow());
    });
  }

  /// Turns the backup on: asks Google for Drive access, then uploads.
  Future<bool> enable() async {
    if (_uid == null) return false;
    state = state.copyWith(busy: true, clearError: true);
    final granted = await ref.read(authRepositoryProvider).requestDriveAccess();
    if (!granted) {
      state = state.copyWith(
        busy: false,
        error: 'Serve il permesso per Google Drive: senza, il backup resta spento.',
      );
      return false;
    }
    state = state.copyWith(
      enabled: true,
      pending: true,
      busy: false,
      needsPermission: false,
    );
    await _persist();
    await runNow();
    return true;
  }

  Future<void> disable() async {
    _debounce?.cancel();
    state = state.copyWith(enabled: false, pending: false, clearError: true);
    await _persist();
  }

  /// Uploads now. Concurrent calls collapse into one extra run.
  Future<void> runNow() async {
    if (!state.enabled || _uid == null) return;
    _debounce?.cancel();
    if (_running) {
      _runAgain = true;
      return;
    }
    _running = true;
    state = state.copyWith(busy: true, pending: true);
    try {
      final bytes = await _buildExcel();
      final id = await ref
          .read(driveClientProvider)
          .upsert(
            fileId: state.fileId,
            name: driveBackupFileName,
            bytes: bytes,
          );
      state = state.copyWith(
        fileId: id,
        lastBackupAt: DateTime.now(),
        pending: false,
        clearError: true,
        needsPermission: false,
      );
    } on DriveBackupException catch (e) {
      state = state.copyWith(
        error: e.message,
        needsPermission: e.needsPermission,
      );
    } catch (e) {
      debugPrint('Drive backup: $e');
      state = state.copyWith(
        error: 'Backup non riuscito (connessione?). Riprovo appena possibile.',
      );
    } finally {
      _running = false;
      state = state.copyWith(busy: false);
      await _persist();
      if (_runAgain) {
        _runAgain = false;
        unawaited(runNow());
      }
    }
  }

  Future<Uint8List> _buildExcel() async {
    final household = ref.read(authSessionProvider).valueOrNull?.household;
    if (household == null) {
      throw const DriveBackupException('Sessione non pronta.');
    }
    final expenses = await ref.read(expensesProvider.future);
    final transfers = await ref.read(transfersProvider.future);
    final cats = ref.read(categoryNamesProvider);
    final props = ref.read(propertyNamesProvider);
    final snapshot = const ReportAggregator().build(
      expenses: expenses,
      transfers: transfers,
      tasks: const [],
      period: ReportPeriod.all(),
      categoryNames: cats,
      propertyNames: props,
    );
    return const ExcelExporter().build(
      snapshot: snapshot,
      robUid: household.robUid,
      lauUid: household.lauUid,
      includeTransfers: true,
      includeTasks: false,
      categoryNames: cats,
      propertyNames: props,
    );
  }
}
