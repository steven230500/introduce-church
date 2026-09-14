import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPrefsService {
  Map<String, dynamic>? _cache;

  Future<File> get _file async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'prefs.json'));
  }

  Future<Map<String, dynamic>> _read() async {
    if (_cache != null) return _cache!;
    try {
      final f = await _file;
      if (!await f.exists()) return _cache = {};
      _cache = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return _cache!;
    } catch (_) {
      return _cache = {};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    _cache = data;
    final f = await _file;
    await f.writeAsString(jsonEncode(data));
  }

  Future<String?> getOrgId() async {
    final d = await _read();
    return d['org_id'] as String?;
  }

  Future<void> setOrgId(String? id) async {
    final d = Map<String, dynamic>.from(await _read());
    if (id == null) {
      d.remove('org_id');
    } else {
      d['org_id'] = id;
    }
    await _write(d);
  }

  Future<void> saveCollections(List<Map<String, dynamic>> raw) async {
    final d = Map<String, dynamic>.from(await _read());
    d['collections'] = raw;
    d['collections_at'] = DateTime.now().toIso8601String();
    await _write(d);
  }

  Future<List<Map<String, dynamic>>?> loadCollections() async {
    final d = await _read();
    final list = d['collections'] as List?;
    return list?.cast<Map<String, dynamic>>();
  }

  /// The designs, kept for the services with no internet.
  ///
  /// Without these a church that made its own design falls back to the built-in
  /// one the moment the router is off, which changes what the congregation
  /// sees for reasons nobody in the room can explain.
  Future<void> saveTemplates(List<Map<String, dynamic>> raw) async {
    final d = Map<String, dynamic>.from(await _read());
    d['templates'] = raw;
    await _write(d);
  }

  Future<List<Map<String, dynamic>>?> loadTemplates() async {
    final d = await _read();
    final list = d['templates'] as List?;
    return list?.cast<Map<String, dynamic>>();
  }

  /// How wide the operator dragged each panel.
  ///
  /// Churches differ: one has long song titles and wants the set list wide,
  /// another wants the biggest preview it can get. Hard-coding one answer was
  /// always going to be wrong for somebody.
  Future<void> saveLayout(Map<String, double> widths) async {
    final d = Map<String, dynamic>.from(await _read());
    d['layout'] = widths;
    await _write(d);
  }

  Future<Map<String, double>?> loadLayout() async {
    final d = await _read();
    final raw = d['layout'];
    if (raw is! Map) return null;
    return {
      for (final entry in raw.entries)
        if (entry.value is num) entry.key as String: (entry.value as num).toDouble(),
    };
  }

  /// Which display the projector window opens on.
  ///
  /// A church wires the same room the same way every week, and the app used to
  /// take the second display it was handed and hope.
  /// Whether phones may control this computer, the PIN, and the phones that
  /// have paired, so a phone paired last Sunday reconnects this one.
  Future<Map<String, dynamic>?> loadRemote() async {
    final d = await _read();
    final raw = d['remote'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> saveRemote(Map<String, dynamic> remote) async {
    final d = Map<String, dynamic>.from(await _read());
    d['remote'] = remote;
    await _write(d);
  }

  /// How the words look in the streaming window, on this computer.
  Future<Map<String, dynamic>?> loadStreamStyle() async {
    final d = await _read();
    final raw = d['stream_style'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> saveStreamStyle(Map<String, dynamic> style) async {
    final d = Map<String, dynamic>.from(await _read());
    d['stream_style'] = style;
    await _write(d);
  }

  /// The waiting screen chosen last, so the picker opens on it.
  Future<Map<String, dynamic>?> loadWaiting() async {
    final d = await _read();
    final raw = d['waiting'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  Future<void> saveWaiting(Map<String, dynamic> config) async {
    final d = Map<String, dynamic>.from(await _read());
    d['waiting'] = config;
    await _write(d);
  }

  /// The language the operator chose, or null to follow the computer.
  ///
  /// A church in a bilingual city runs the machine in one language and the
  /// service in another, so this is a setting and not a reading of the OS.
  Future<String?> getLocale() async {
    final d = await _read();
    return d['locale'] as String?;
  }

  Future<void> setLocale(String? code) async {
    final d = Map<String, dynamic>.from(await _read());
    if (code == null) {
      d.remove('locale');
    } else {
      d['locale'] = code;
    }
    // Choosing to follow the computer is an answer too, and must not bring
    // the first-run question back.
    d['language_asked'] = true;
    await _write(d);
  }

  /// Whether this computer has been asked which language to use.
  Future<bool> languageAsked() async {
    final d = await _read();
    return d['language_asked'] == true || d.containsKey('locale');
  }

  Future<void> setLanguageAsked() async {
    final d = Map<String, dynamic>.from(await _read());
    d['language_asked'] = true;
    await _write(d);
  }

  /// Whether this computer was already in use before the language question
  /// existed: a session or a plan saved on it. Those churches have been
  /// reading the app in a language for months and are not asked again.
  Future<bool> hasBeenUsed() async {
    final d = await _read();
    return d.containsKey('session') || d.containsKey('collections') || d.containsKey('templates');
  }

  Future<String?> getProjectorDisplay() async {
    final d = await _read();
    return d['projector_display'] as String?;
  }

  Future<void> setProjectorDisplay(String? id) async {
    final d = Map<String, dynamic>.from(await _read());
    if (id == null) {
      d.remove('projector_display');
    } else {
      d['projector_display'] = id;
    }
    await _write(d);
  }

  // ── Session ────────────────────────────────────────────────────────────────
  //
  // Tokens live in the same file as the rest of the preferences. On a desktop
  // machine that is no weaker than the keychain for this purpose: anyone who
  // can read this file already runs as the operator.

  Future<Map<String, dynamic>?> loadSession() async {
    final d = await _read();
    return d['session'] as Map<String, dynamic>?;
  }

  Future<void> saveSession(Map<String, dynamic> session) async {
    final d = Map<String, dynamic>.from(await _read());
    d['session'] = session;
    await _write(d);
  }

  Future<void> clearSession() async {
    final d = Map<String, dynamic>.from(await _read());
    d.remove('session');
    await _write(d);
  }

  Future<void> clear() async {
    await _write({});
  }
}
