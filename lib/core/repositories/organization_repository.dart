import '../api/api_client.dart';
import '../models/organization.dart';
import '../models/saved_notice.dart';
import '../utils/color_contrast.dart';

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

  /// The colours this church has saved, as 0xAARRGGBB values.
  ///
  /// A church that cannot be asked, or has saved none, simply gets the
  /// built-in swatches, so this never fails an editor.
  Future<List<int>> getPalette() async {
    try {
      final body = await _api.get<Map<String, dynamic>>('/org/palette');
      return _readColors(body?['colors']);
    } on ApiException {
      return const [];
    }
  }

  Future<List<int>> setPalette(List<int> colors) async {
    final body = await _api.put<Map<String, dynamic>>(
      '/org/palette',
      data: {
        'colors': [for (final c in colors) hexOf(c)],
      },
    );
    final saved = _readColors(body?['colors']);
    return saved.isEmpty && colors.isNotEmpty ? colors : saved;
  }

  /// Reads a list of hex strings, skipping anything that is not one.
  static List<int> _readColors(Object? colors) {
    if (colors is! List) return const [];
    final out = <int>[];
    for (final raw in colors) {
      if (raw is! String) continue;
      final value = parseHexColor(raw);
      if (value != null) out.add(value);
    }
    return out;
  }

  /// The notices this church keeps ready.
  ///
  /// A church that cannot be reached simply gets none, and the operator can
  /// still type one, so this never blocks a service.
  Future<List<SavedNotice>> getNotices() async {
    try {
      final body = await _api.get<Map<String, dynamic>>('/org/notices');
      return _readNotices(body?['notices']);
    } on ApiException {
      return const [];
    }
  }

  Future<List<SavedNotice>> setNotices(List<SavedNotice> notices) async {
    final body = await _api.put<Map<String, dynamic>>(
      '/org/notices',
      data: {
        'notices': [for (final n in notices) n.toJson()],
      },
    );
    final saved = _readNotices(body?['notices']);
    return saved.isEmpty && notices.isNotEmpty ? notices : saved;
  }

  static List<SavedNotice> _readNotices(Object? raw) {
    if (raw is! List) return const [];
    final out = <SavedNotice>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final notice = SavedNotice.fromJson(Map<String, dynamic>.from(row));
      if (notice.text.isNotEmpty) out.add(notice);
    }
    return out;
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

  /// Makes a member an administrator, or takes the role away. The server
  /// refuses to take it from the church's last administrator.
  Future<void> setAdmin(String memberId, {required bool admin}) async {
    await _api.put<void>('/org/members/$memberId/role', data: {'role': admin ? 'admin' : 'member'});
  }

  /// Takes someone out of the church and ends their sessions.
  Future<void> removeMember(String memberId) async {
    await _api.delete<void>('/org/members/$memberId');
  }

  /// A one-time code the member uses, with their email, to set a new password.
  Future<String> createResetCode(String memberId) async {
    final body = await _api.post<Map<String, dynamic>>('/org/members/$memberId/reset-code');
    return body!['code'] as String;
  }

  Future<List<OrgMember>> _members(String path) async {
    final rows = await _api.get<List<dynamic>>(path);
    return (rows ?? []).map((r) => OrgMember.fromJson(r as Map<String, dynamic>)).toList();
  }
}
