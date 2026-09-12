import '../api/api_client.dart';
import '../models/organization.dart';

class OrganizationRepository {
  const OrganizationRepository(this._api);
  final ApiClient _api;

  /// The caller's organization and their standing in it, or null when they
  /// belong to none yet.
  Future<({Organization org, OrgMember me})?> getMyMembership() async {
    try {
      final body = await _api.get<Map<String, dynamic>>('/org/me');
      if (body == null) return null;
      return (
        org: Organization.fromJson(body['organization'] as Map<String, dynamic>),
        me: OrgMember.fromJson(body['member'] as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      // 404 is the normal answer for a brand new account, not a failure.
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Organization>> searchOrganizations(String query) async {
    if (query.trim().isEmpty) return [];
    final rows = await _api.get<List<dynamic>>('/org/search', query: {'q': query.trim()});
    return (rows ?? []).map((r) => Organization.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Creates an organization and refreshes the session.
  ///
  /// The current access token was minted before the membership existed, so
  /// without the refresh every org-scoped request would still be rejected.
  Future<Organization> createOrganization(String name) async {
    final body = await _api.post<Map<String, dynamic>>('/org', data: {'name': name.trim()});
    await _api.refreshSession();
    return Organization.fromJson(body!);
  }

  Future<void> requestJoin(String orgId) async {
    await _api.post<void>('/org/join', data: {'org_id': orgId});
  }

  Future<List<OrgMember>> getPendingRequests() => _members('/org/pending');

  Future<List<OrgMember>> getMembers() => _members('/org/members');

  Future<void> approveRequest(String memberId) async {
    await _api.post<void>('/org/members/$memberId/approve');
  }

  Future<void> rejectRequest(String memberId) async {
    await _api.post<void>('/org/members/$memberId/reject');
  }

  Future<List<OrgMember>> _members(String path) async {
    final rows = await _api.get<List<dynamic>>(path);
    return (rows ?? []).map((r) => OrgMember.fromJson(r as Map<String, dynamic>)).toList();
  }
}
