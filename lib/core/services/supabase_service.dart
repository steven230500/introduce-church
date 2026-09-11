import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_prefs_service.dart';

class SupabaseService {
  SupabaseService(this._prefs);
  final AppPrefsService _prefs;

  SupabaseClient get client => Supabase.instance.client;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  User? get currentUser => client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String? _orgId;
  String? get orgId => _orgId;

  Future<String?> loadOrgId() async {
    final uid = currentUser?.id;
    if (uid == null) {
      _orgId = null;
      return null;
    }
    final rows = await client
        .from('organization_members')
        .select('org_id')
        .eq('user_id', uid)
        .eq('status', 'active')
        .limit(1)
        .timeout(const Duration(seconds: 5));
    _orgId = rows.isNotEmpty ? rows.first['org_id'] as String? : null;
    if (_orgId != null) await _prefs.setOrgId(_orgId);
    return _orgId;
  }

  Future<String?> loadOrgIdWithFallback() async {
    try {
      return await loadOrgId();
    } catch (_) {
      _orgId = await _prefs.getOrgId();
      return _orgId;
    }
  }

  void clearOrg() {
    _orgId = null;
    _prefs.setOrgId(null);
  }
}
