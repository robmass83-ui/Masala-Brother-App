import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

class AppUpdate {
  const AppUpdate({
    required this.tag,
    required this.version,
    required this.apkUrl,
    required this.apkName,
    this.notes,
    this.sizeBytes,
  });

  final String tag;
  final String version;
  final String apkUrl;
  final String apkName;
  final String? notes;
  final int? sizeBytes;
}

class AppUpdater {
  AppUpdater({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'MasalaBrotherApp';

  Future<AppUpdate?> fetchLatest() async {
    final res = await _client.get(
      Uri.parse(AppConfig.githubLatestReleaseApi),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': _userAgent,
      },
    );
    if (res.statusCode == 404) {
      throw const AppUpdateException(
        'Nessuna release trovata. Serve un tag GitHub (es. v1.0.1) con l’APK, '
        'e il repository deve essere pubblico.',
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const AppUpdateException(
        'Le release GitHub non sono scaricabili da qui (repo privato). '
        'Rendi il repository pubblico, oppure manda l’APK su WhatsApp.',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AppUpdateException('Controllo aggiornamenti non riuscito (${res.statusCode}).');
    }
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw const AppUpdateException('Risposta GitHub non valida');
    }
    return fromGithubRelease(body);
  }

  static AppUpdate? fromGithubRelease(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').trim();
    final version = stripVersionPrefix(tag);
    if (version.isEmpty) return null;
    final assets = json['assets'];
    if (assets is! List) return null;
    final apk = pickApkAsset(
      assets.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    if (apk == null) return null;
    final url = apk['browser_download_url'] as String? ?? '';
    final name = apk['name'] as String? ?? 'update.apk';
    if (url.isEmpty) return null;
    final notes = json['body'] as String?;
    final size = (apk['size'] as num?)?.toInt();
    return AppUpdate(
      tag: tag,
      version: version,
      apkUrl: url,
      apkName: name,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      sizeBytes: size,
    );
  }

  static Map<String, dynamic>? pickApkAsset(Iterable<Map<String, dynamic>> assets) {
    final apks = assets.where((a) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      return name.endsWith('.apk');
    }).toList();
    if (apks.isEmpty) return null;
    Map<String, dynamic>? named(String part) {
      for (final a in apks) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.contains(part)) return a;
      }
      return null;
    }

    return named('arm64') ?? named('app-release.apk') ?? apks.first;
  }

  static String stripVersionPrefix(String tag) {
    var v = tag.trim();
    if (v.toLowerCase().startsWith('v')) v = v.substring(1);
    return v;
  }

  /// Returns true if [remote] is a newer semver than [local] (`1.0.1` > `1.0.0`).
  static bool isNewer(String remote, String local) {
    return _compare(remote, local) > 0;
  }

  static int _compare(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final da = i < pa.length ? pa[i] : 0;
      final db = i < pb.length ? pb[i] : 0;
      if (da != db) return da.compareTo(db);
    }
    return 0;
  }

  static List<int> _parts(String version) {
    final core = stripVersionPrefix(version).split(RegExp(r'[-+]')).first;
    return [
      for (final bit in core.split('.')) int.tryParse(bit) ?? 0,
    ];
  }

  Future<File> download(
    AppUpdate update, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${update.apkName}');
    final req = http.Request('GET', Uri.parse(update.apkUrl));
    req.headers['User-Agent'] = _userAgent;
    final res = await _client.send(req);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AppUpdateException('Download non riuscito (${res.statusCode}).');
    }
    final total = res.contentLength ?? update.sizeBytes;
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  Future<void> install(File apk) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw const AppUpdateException('L’installazione diretta è disponibile solo su Android.');
    }
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw AppUpdateException(
        result.message.isNotEmpty
            ? result.message
            : 'Impossibile aprire il programma di installazione.',
      );
    }
  }
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}
