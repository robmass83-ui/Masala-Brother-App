import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brotherapp/core/backup/drive_backup.dart';
import 'package:brotherapp/core/backup/drive_client.dart';
import 'package:brotherapp/core/connectivity/connectivity_provider.dart';
import 'package:brotherapp/data/data_providers.dart';
import 'package:brotherapp/data/expense_models.dart';
import 'package:brotherapp/data/transfer_models.dart';
import 'package:brotherapp/features/auth/auth_providers.dart';
import 'package:brotherapp/features/auth/auth_repository.dart';

class _FakeDrive implements DriveClient {
  final uploads = <({String? fileId, String name, int size})>[];
  Object? failWith;

  @override
  Future<String> upsert({
    required String? fileId,
    required String name,
    required Uint8List bytes,
  }) async {
    if (failWith != null) throw failWith!;
    uploads.add((fileId: fileId, name: name, size: bytes.length));
    return fileId ?? 'file-1';
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  late ProviderContainer c;
  late _FakeDrive drive;

  setUp(() async {
    drive = _FakeDrive();
    final auth = AuthRepository(forceDemo: true);
    await auth.signInWithGoogle();
    c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        driveClientProvider.overrideWithValue(drive),
        driveBackupStoreProvider.overrideWithValue(MemoryDriveBackupStore()),
        driveBackupDebounceProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(c.dispose);
    c.listen(driveBackupProvider, (_, __) {});
    await c.read(authSessionProvider.future);
    await c.read(expensesProvider.future);
    await c.read(transfersProvider.future);
    await _settle();
  });

  Future<void> addExpense() async {
    final h = c.read(authSessionProvider).valueOrNull!.household!;
    final repo = c.read(expenseRepositoryProvider);
    await repo.save(
      draft: Expense(
        id: '',
        description: 'Luce',
        amountDueCents: 5000,
        date: DateTime(2026, 11, 1),
        categoryId: 'bollette',
        payments: [repo.newPayment(payerUid: h.robUid, amountCents: 5000)],
      ),
      actorUid: h.robUid,
      robUid: h.robUid,
      lauUid: h.lauUid,
    );
  }

  test('off by default: saving money does not upload', () async {
    await addExpense();
    await _settle();
    expect(drive.uploads, isEmpty);
  });

  test('turning it on uploads the Excel right away', () async {
    expect(await c.read(driveBackupProvider.notifier).enable(), isTrue);
    expect(drive.uploads, hasLength(1));
    expect(drive.uploads.single.name, driveBackupFileName);
    expect(drive.uploads.single.size, greaterThan(0));
    final s = c.read(driveBackupProvider);
    expect(s.enabled, isTrue);
    expect(s.pending, isFalse);
    expect(s.lastBackupAt, isNotNull);
  });

  test('every money change rewrites the same Drive file', () async {
    await c.read(driveBackupProvider.notifier).enable();
    await addExpense();
    await _settle();
    final h = c.read(authSessionProvider).valueOrNull!.household!;
    await c.read(transferRepositoryProvider).save(
          draft: Transfer(
            id: '',
            fromUid: h.lauUid,
            toUid: h.robUid,
            amountCents: 2500,
            date: DateTime(2026, 11, 2),
          ),
          actorUid: h.lauUid,
        );
    await _settle();
    expect(drive.uploads.length, greaterThanOrEqualTo(3));
    // After the first upload the file id is reused: one file, updated.
    expect(drive.uploads.skip(1).every((u) => u.fileId == 'file-1'), isTrue);
  });

  test('a failed upload stays pending and is retried', () async {
    await c.read(driveBackupProvider.notifier).enable();
    drive.failWith = Exception('offline');
    await addExpense();
    await _settle();
    var s = c.read(driveBackupProvider);
    expect(s.pending, isTrue);
    expect(s.error, isNotNull);

    drive.failWith = null;
    await c.read(driveBackupProvider.notifier).runNow();
    s = c.read(driveBackupProvider);
    expect(s.pending, isFalse);
    expect(s.error, isNull);
  });

  test('turning it off stops uploads', () async {
    final ctrl = c.read(driveBackupProvider.notifier);
    await ctrl.enable();
    await ctrl.disable();
    final before = drive.uploads.length;
    await addExpense();
    await _settle();
    expect(drive.uploads.length, before);
  });

  group('GoogleDriveClient', () {
    Future<Map<String, String>> headers() async => {'Authorization': 'Bearer t'};
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('creates the file the first time', () async {
      final calls = <String>[];
      final client = GoogleDriveClient(
        authHeaders: headers,
        client: MockClient((req) async {
          calls.add('${req.method} ${req.url.path}');
          return http.Response(jsonEncode({'id': 'new'}), 200);
        }),
      );
      final id = await client.upsert(fileId: null, name: 'x.xlsx', bytes: bytes);
      expect(id, 'new');
      expect(calls, ['POST /upload/drive/v3/files']);
    });

    test('updates in place, and recreates a deleted or trashed file', () async {
      for (final gone in [
        http.Response('not found', 404),
        http.Response(jsonEncode({'id': 'old', 'trashed': true}), 200),
      ]) {
        final calls = <String>[];
        final client = GoogleDriveClient(
          authHeaders: headers,
          client: MockClient((req) async {
            calls.add(req.method);
            if (req.method == 'PATCH') return gone;
            return http.Response(jsonEncode({'id': 'new'}), 200);
          }),
        );
        final id = await client.upsert(fileId: 'old', name: 'x.xlsx', bytes: bytes);
        expect(id, 'new');
        expect(calls, ['PATCH', 'POST']);
      }

      final client = GoogleDriveClient(
        authHeaders: headers,
        client: MockClient(
          (req) async => http.Response(jsonEncode({'id': 'old', 'trashed': false}), 200),
        ),
      );
      expect(await client.upsert(fileId: 'old', name: 'x.xlsx', bytes: bytes), 'old');
    });

    test('explains a disabled Drive API in Italian', () async {
      final client = GoogleDriveClient(
        authHeaders: headers,
        client: MockClient(
          (req) async => http.Response('{"error":{"status":"SERVICE_DISABLED"}}', 403),
        ),
      );
      expect(
        () => client.upsert(fileId: null, name: 'x.xlsx', bytes: bytes),
        throwsA(
          isA<DriveBackupException>()
              .having((e) => e.message, 'message', contains('Drive API')),
        ),
      );
    });
  });
}
