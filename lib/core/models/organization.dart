import 'package:equatable/equatable.dart';

enum OrgMemberStatus { pending, active, rejected }

enum OrgMemberRole { admin, member }

class Organization extends Equatable {
  const Organization({required this.id, required this.name, required this.createdAt});

  final String id;
  final String name;
  final DateTime createdAt;

  factory Organization.fromJson(Map<String, dynamic> j) => Organization(
    id: j['id'] as String,
    name: j['name'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  @override
  List<Object?> get props => [id, name];
}

class OrgMember extends Equatable {
  const OrgMember({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.email,
    this.displayName,
  });

  final String id;
  final String orgId;
  final String userId;
  final OrgMemberRole role;
  final OrgMemberStatus status;
  final DateTime joinedAt;
  final String? email;
  final String? displayName;

  String get label => displayName ?? email ?? userId.substring(0, 8);

  factory OrgMember.fromJson(Map<String, dynamic> j) {
    final profileEmail = (j['profiles'] as Map<String, dynamic>?)?['email'] as String?;
    return OrgMember(
      id: j['id'] as String,
      orgId: j['org_id'] as String,
      userId: j['user_id'] as String,
      role: j['role'] == 'admin' ? OrgMemberRole.admin : OrgMemberRole.member,
      status: switch (j['status'] as String) {
        'active' => OrgMemberStatus.active,
        'rejected' => OrgMemberStatus.rejected,
        _ => OrgMemberStatus.pending,
      },
      joinedAt: DateTime.parse(j['joined_at'] as String),
      email: j['email'] as String? ?? profileEmail,
      displayName: (j['profiles'] as Map<String, dynamic>?)?['display_name'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, orgId, userId, role, status];
}
