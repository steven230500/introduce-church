import '../models/organization.dart';
import '../services/supabase_service.dart';

class OrganizationRepository {
  const OrganizationRepository(this._supabase);
  final SupabaseService _supabase;

  // ── My membership ─────────────────────────────────────────────────────────

  /// Returns active membership or null if user has none.
  Future<({Organization org, OrgMember me})?> getMyMembership() async {
    final uid = _supabase.currentUser?.id;
    if (uid == null) return null;

    final rows = await _supabase.client
        .from('organization_members')
        .select('*, organizations(id, name, created_at)')
        .eq('user_id', uid)
        .neq('status', 'rejected')
        .order('joined_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) return null;
    final row = rows.first;
    final orgData = row['organizations'] as Map<String, dynamic>?;
    if (orgData == null) return null;

    return (org: Organization.fromJson(orgData), me: OrgMember.fromJson(row));
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<Organization>> searchOrganizations(String query) async {
    if (query.trim().isEmpty) return [];
    final rows = await _supabase.client
        .from('organizations')
        .select('id, name, created_at')
        .ilike('name', '%${query.trim()}%')
        .limit(10);
    return rows.map((r) => Organization.fromJson(r)).toList();
  }

  // ── Create (via RPC to bypass RLS) ───────────────────────────────────────

  Future<Organization> createOrganization(String name) async {
    final result = await _supabase.client.rpc(
      'create_organization',
      params: {'org_name': name.trim()},
    );
    final data = (result is List) ? result.first : result;
    return Organization.fromJson(data as Map<String, dynamic>);
  }

  // ── Join request ──────────────────────────────────────────────────────────

  Future<void> requestJoin(String orgId) async {
    final user = _supabase.currentUser!;
    await _supabase.client.from('organization_members').insert({
      'org_id': orgId,
      'user_id': user.id,
      'role': 'member',
      'status': 'pending',
      'email': user.email,
    });
  }

  // ── Admin: list pending requests ──────────────────────────────────────────

  Future<List<OrgMember>> getPendingRequests() async {
    final orgId = _supabase.orgId;
    if (orgId == null) return [];
    final rows = await _supabase.client
        .from('organization_members')
        .select('*')
        .eq('org_id', orgId)
        .eq('status', 'pending')
        .order('joined_at');
    return rows.map((r) => OrgMember.fromJson(r)).toList();
  }

  // ── Admin: list active members ────────────────────────────────────────────

  Future<List<OrgMember>> getMembers() async {
    final orgId = _supabase.orgId;
    if (orgId == null) return [];
    final rows = await _supabase.client
        .from('organization_members')
        .select('*')
        .eq('org_id', orgId)
        .eq('status', 'active')
        .order('joined_at');
    return rows.map((r) => OrgMember.fromJson(r)).toList();
  }

  // ── Admin: approve / reject ───────────────────────────────────────────────

  Future<void> approveRequest(String memberId) async {
    await _supabase.client.rpc('approve_member', params: {'member_id': memberId});
  }

  Future<void> rejectRequest(String memberId) async {
    await _supabase.client.rpc('reject_member', params: {'member_id': memberId});
  }
}
