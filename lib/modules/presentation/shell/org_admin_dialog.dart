import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../core/api/error_text.dart';
import '../../../core/models/organization.dart';
import '../../../core/repositories/organization_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';

void showOrgAdminDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => OrgAdminDialog(repo: Modular.get<OrganizationRepository>()),
  );
}

class OrgAdminDialog extends StatefulWidget {
  const OrgAdminDialog({super.key, required this.repo});
  final OrganizationRepository repo;

  @override
  State<OrgAdminDialog> createState() => _OrgAdminDialogState();
}

class _OrgAdminDialogState extends State<OrgAdminDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  Organization? _org;
  OrgMember? _me;
  List<OrgMember> _pending = [];
  List<OrgMember> _members = [];
  bool _loading = true;
  Object? _error;
  static const _noOrganization = Object();

  bool get _isAdmin => _me?.role == OrgMemberRole.admin;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final membership = await widget.repo.getMyMembership();
      if (membership == null) {
        setState(() {
          _loading = false;
          _error = _noOrganization;
        });
        return;
      }
      _org = membership.org;
      _me = membership.me;

      final results = await Future.wait([
        if (_isAdmin) widget.repo.getPendingRequests() else Future.value(<OrgMember>[]),
        widget.repo.getMembers(),
      ]);
      setState(() {
        _pending = results[0];
        _members = results[1];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _approve(String memberId) async {
    await widget.repo.approveRequest(memberId);
    _load();
  }

  Future<void> _reject(String memberId) async {
    await widget.repo.rejectRequest(memberId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 500,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Text(
                    _error == _noOrganization
                        ? L10n.of(context).orgNone
                        : errorText(L10n.of(context), _error),
                    style: const TextStyle(color: Color(0xFFFF3B30)),
                  ),
                ),
              )
            else ...[
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(
                    text: _isAdmin
                        ? (_pending.isNotEmpty
                              ? L10n.of(context).orgRequestsCount(_pending.length)
                              : L10n.of(context).orgRequests)
                        : L10n.of(context).orgRequests,
                  ),
                  Tab(text: L10n.of(context).orgMembers),
                ],
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.accent,
                dividerColor: AppColors.surfaceControl,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PendingTab(
                      requests: _pending,
                      isAdmin: _isAdmin,
                      onApprove: _approve,
                      onReject: _reject,
                    ),
                    _MembersTab(members: _members, meId: _me?.userId ?? ''),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Image.asset(
            'assets/images/casavida-isologo-white.png',
            height: 20,
            opacity: const AlwaysStoppedAnimation(0.55),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _org?.name ?? L10n.of(context).orgTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_me != null)
                  Text(
                    _me!.role == OrgMemberRole.admin
                        ? L10n.of(context).orgRoleAdmin
                        : L10n.of(context).orgRoleMember,
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ── Pending tab ───────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  const _PendingTab({
    required this.requests,
    required this.isAdmin,
    required this.onApprove,
    required this.onReject,
  });
  final List<OrgMember> requests;
  final bool isAdmin;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return Center(
        child: Text(
          L10n.of(context).orgOnlyAdminsSeeRequests,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
    if (requests.isEmpty) {
      return Center(
        child: Text(
          L10n.of(context).orgNoPendingRequests,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = requests[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceControl,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.border,
                child: Text(
                  (r.displayName ?? r.email ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.displayName != null)
                      Text(
                        r.displayName!,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    if (r.email != null)
                      Text(
                        r.email!,
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => onApprove(r.id),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(L10n.of(context).orgApprove),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => onReject(r.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: const BorderSide(color: Color(0xFFFF3B30)),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(L10n.of(context).orgReject),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Members tab ───────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.members, required this.meId});
  final List<OrgMember> members;
  final String meId;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          L10n.of(context).orgNoMembers,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final m = members[i];
        final isMe = m.userId == meId;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceControl,
            borderRadius: BorderRadius.circular(10),
            border: isMe ? Border.all(color: AppColors.accent.withValues(alpha: 0.4)) : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.border,
                child: Text(
                  (m.displayName ?? m.email ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (m.displayName != null)
                          Text(
                            m.displayName!,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        if (isMe)
                          Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text(
                              L10n.of(context).orgYou,
                              style: TextStyle(fontSize: 11, color: AppColors.accent),
                            ),
                          ),
                      ],
                    ),
                    if (m.email != null)
                      Text(
                        m.email!,
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                  ],
                ),
              ),
              _RoleBadge(role: m.role),
            ],
          ),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final OrgMemberRole role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == OrgMemberRole.admin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.accent.withValues(alpha: 0.15) : AppColors.border,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAdmin ? L10n.of(context).orgRoleAdminShort : L10n.of(context).orgRoleMember,
        style: TextStyle(
          fontSize: 11,
          color: isAdmin ? AppColors.accent : AppColors.textTertiary,
          fontWeight: isAdmin ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
