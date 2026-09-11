import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../core/models/organization.dart';
import '../../../core/repositories/organization_repository.dart';
import '../../../core/theme/app_colors.dart';

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
  String? _error;

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
          _error = 'Sin organización';
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
        _error = e.toString();
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
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30))),
                ),
              )
            else ...[
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(
                    text: _isAdmin
                        ? 'Solicitudes${_pending.isNotEmpty ? " (${_pending.length})" : ""}'
                        : 'Solicitudes',
                  ),
                  const Tab(text: 'Miembros'),
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
                  _org?.name ?? 'Organización',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_me != null)
                  Text(
                    _me!.role == OrgMemberRole.admin ? 'Administrador' : 'Miembro',
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
      return const Center(
        child: Text(
          'Solo los administradores pueden ver solicitudes.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'Sin solicitudes pendientes.',
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
                child: const Text('Aprobar'),
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
                child: const Text('Rechazar'),
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
      return const Center(
        child: Text('Sin miembros.', style: TextStyle(color: AppColors.textMuted)),
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
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text(
                              '(tú)',
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
        isAdmin ? 'Admin' : 'Miembro',
        style: TextStyle(
          fontSize: 11,
          color: isAdmin ? AppColors.accent : AppColors.textTertiary,
          fontWeight: isAdmin ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
