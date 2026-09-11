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

  Future<void> clear() async {
    await _write({});
  }
}
