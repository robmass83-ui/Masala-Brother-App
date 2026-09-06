/// Maps an Excel description to category / property ids (seed catalog).
class ExcelClassify {
  const ExcelClassify();

  static final _bollette = RegExp(
    r'bolletta|luce|gas|tim|enel|gaxa|idrico',
    caseSensitive: false,
  );
  static final _condominio = RegExp(
    r'condominio|ascensore|e/c',
    caseSensitive: false,
  );
  static final _lavori = RegExp(
    r'fattura|infissi|acconto|saldo|rata',
    caseSensitive: false,
  );
  static final _tasse = RegExp(
    r'imu|tari|bollo|redditi',
    caseSensitive: false,
  );
  static final _notaio = RegExp(
    r'notai|successione|geometra|divisione',
    caseSensitive: false,
  );

  String categoryId(String description) {
    if (_bollette.hasMatch(description)) return 'bollette';
    if (_condominio.hasMatch(description)) return 'condominio';
    if (_lavori.hasMatch(description)) return 'lavori';
    if (_tasse.hasMatch(description)) return 'tasse';
    if (_notaio.hasMatch(description)) return 'notaio';
    return 'altro';
  }

  String? propertyId(String description) {
    final t = description.toLowerCase();
    if (t.contains('forlanini')) return 'forlanini';
    if (t.contains('addis')) return 'addis';
    if (t.contains('prunizzedda') || t.contains('prunuzzedda')) {
      return 'prunizzedda';
    }
    if (t.contains('sassari')) return 'sassari';
    return null;
  }
}
