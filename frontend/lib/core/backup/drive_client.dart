import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Errors the backup screen can explain in plain Italian.
class DriveBackupException implements Exception {
  const DriveBackupException(this.message, {this.needsPermission = false});
  final String message;

  /// Google refused the token: Drive access must be granted again.
  final bool needsPermission;

  @override
  String toString() => message;
}

/// Uploads one file to the user's Google Drive, replacing it in place.
abstract class DriveClient {
  /// Overwrites [fileId] with [bytes], or creates [name] when there is no
  /// file yet (or it was deleted / put in the Drive trash). Returns the id.
  Future<String> upsert({
    required String? fileId,
    required String name,
    required Uint8List bytes,
  });
}

/// Drive REST v3 over plain HTTP, using the signed-in Google account's
/// headers. The `drive.file` scope only reaches files this app created.
class GoogleDriveClient implements DriveClient {
  GoogleDriveClient({required this.authHeaders, http.Client? client})
    : _client = client ?? http.Client();

  /// Fresh `Authorization` headers for the current Google account.
  final Future<Map<String, String>> Function() authHeaders;
  final http.Client _client;

  static const _timeout = Duration(seconds: 60);
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';

  @override
  Future<String> upsert({
    required String? fileId,
    required String name,
    required Uint8List bytes,
  }) async {
    final headers = await authHeaders();
    if (fileId != null && fileId.isNotEmpty) {
      final updated = await _update(fileId, bytes, headers);
      if (updated != null) return updated;
    }
    return _create(name, bytes, headers);
  }

  /// Returns null when the old file is gone or trashed (make a new one).
  Future<String?> _update(
    String fileId,
    Uint8List bytes,
    Map<String, String> headers,
  ) async {
    final res = await _client
        .patch(
          Uri.parse('$_upload/$fileId?uploadType=media&fields=id,trashed'),
          headers: {...headers, 'Content-Type': xlsxMimeType},
          body: bytes,
        )
        .timeout(_timeout);
    if (res.statusCode == 404) return null;
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['trashed'] == true) return null;
    return body['id'] as String? ?? fileId;
  }

  Future<String> _create(
    String name,
    Uint8List bytes,
    Map<String, String> headers,
  ) async {
    const boundary = 'masala_brother_backup';
    final meta = jsonEncode({'name': name, 'mimeType': xlsxMimeType});
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$meta\r\n'
          '--$boundary\r\n'
          'Content-Type: $xlsxMimeType\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final res = await _client
        .post(
          Uri.parse('$_upload?uploadType=multipart&fields=id'),
          headers: {
            ...headers,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body.takeBytes(),
        )
        .timeout(_timeout);
    _check(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
  }

  void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    if (res.statusCode == 401) {
      throw const DriveBackupException(
        'Google non ha accettato l’accesso a Drive: riattiva il backup.',
        needsPermission: true,
      );
    }
    if (res.statusCode == 403) {
      final apiOff =
          res.body.contains('accessNotConfigured') ||
          res.body.contains('SERVICE_DISABLED');
      throw DriveBackupException(
        apiOff
            ? 'Google Drive API non attiva nel progetto: va abilitata nella '
                  'Google Cloud Console.'
            : 'Google Drive ha rifiutato il salvataggio (permesso mancante).',
        needsPermission: !apiOff,
      );
    }
    throw DriveBackupException(
      'Google Drive non risponde (errore ${res.statusCode}). Riprovo più tardi.',
    );
  }
}
