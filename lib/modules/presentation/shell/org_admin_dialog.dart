import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../core/api/error_text.dart';
import '../../../core/models/organization.dart';
import '../../../core/repositories/organization_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_dialog.dart';
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

  /// What went wrong with the last change asked for here, such as removing
  /// the church's only administrator. Shown above the tabs until the next one.
  Object? _actionError;
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

  Future<void> _act(Future<void> Function() change) async {
    setState(() => _actionError = null);
    try {
      await change();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _actionError = e);
    }
  }

  Future<void> _setAdmin(OrgMember member, bool admin) =>
      _act(() => widget.repo.setAdmin(member.id, admin: admin));

  Future<void> _remove(OrgMember member) async {
    final t = L10n.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: t.orgRemoveMemberTitle,
      message: t.orgRemoveMemberBody(member.label),
      confirmLabel: t.orgRemoveMemberConfirm,
      destructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (confirmed) await _act(() => widget.repo.removeMember(member.id));
  }

  Future<void> _resetCode(OrgMember member) async {
    setState(() => _actionError = null);
    try {
      final code = await widget.repo.createResetCode(member.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ResetCodeDialog(name: member.label, code: code),
      );
    } catch (e) {
      if (mounted) setState(() => _actionError = e);
    }
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
              if (_actionError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    errorText(L10n.of(context), _actionError),
                    style: const TextStyle(color: AppColors.danger, fontSize: 12, height: 1.4),
                  ),
                ),
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
                    _MembersTab(
                      members: _members,
                      meId: _me?.userId ?? '',
                      isAdmin: _isAdmin,
                      onSetAdmin: _setAdmin,
                      onResetCode: _resetCode,
                      onRemove: _remove,
                    ),
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
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      );
    }
    if (requests.isEmpty) {
      return Center(
        child: Text(
          L10n.of(context).orgNoPendingRequests,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
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
  const _MembersTab({
    required this.members,
    required this.meId,
    required this.isAdmin,
    required this.onSetAdmin,
    required this.onResetCode,
    required this.onRemove,
  });
  final List<OrgMember> members;
  final String meId;
  final bool isAdmin;
  final Future<void> Function(OrgMember, bool admin) onSetAdmin;
  final Future<void> Function(OrgMember) onResetCode;
  final Future<void> Function(OrgMember) onRemove;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          L10n.of(context).orgNoMembers,
          style: const TextStyle(color: AppColors.textTertiary),
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
              if (isAdmin)
                _MemberMenu(
                  member: m,
                  isMe: isMe,
                  onSetAdmin: onSetAdmin,
                  onResetCode: onResetCode,
                  onRemove: onRemove,
                ),
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

enum _MemberAction { makeAdmin, removeAdmin, resetCode, remove }

/// What an administrator can do to one member. Their own row offers only
/// stepping down, and the server refuses even that for the last administrator.
class _MemberMenu extends StatelessWidget {
  const _MemberMenu({
    required this.member,
    required this.isMe,
    required this.onSetAdmin,
    required this.onResetCode,
    required this.onRemove,
  });

  final OrgMember member;
  final bool isMe;
  final Future<void> Function(OrgMember, bool admin) onSetAdmin;
  final Future<void> Function(OrgMember) onResetCode;
  final Future<void> Function(OrgMember) onRemove;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final isAdmin = member.role == OrgMemberRole.admin;
    return PopupMenuButton<_MemberAction>(
      tooltip: t.orgMemberActions,
      icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
      color: AppColors.surfaceRaised,
      onSelected: (action) => switch (action) {
        _MemberAction.makeAdmin => onSetAdmin(member, true),
        _MemberAction.removeAdmin => onSetAdmin(member, false),
        _MemberAction.resetCode => onResetCode(member),
        _MemberAction.remove => onRemove(member),
      },
      itemBuilder: (_) => [
        if (!isAdmin) PopupMenuItem(value: _MemberAction.makeAdmin, child: Text(t.orgMakeAdmin)),
        if (isAdmin) PopupMenuItem(value: _MemberAction.removeAdmin, child: Text(t.orgRemoveAdmin)),
        if (!isMe) PopupMenuItem(value: _MemberAction.resetCode, child: Text(t.orgResetCode)),
        if (!isMe)
          PopupMenuItem(
            value: _MemberAction.remove,
            child: Text(t.orgRemoveMember, style: const TextStyle(color: AppColors.danger)),
          ),
      ],
    );
  }
}

/// Shows a password code once, big enough to read out, with a way to copy it
/// into a message.
class ResetCodeDialog extends StatefulWidget {
  const ResetCodeDialog({super.key, required this.name, required this.code});

  final String name;
  final String code;

  @override
  State<ResetCodeDialog> createState() => _ResetCodeDialogState();
}

class _ResetCodeDialogState extends State<ResetCodeDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AppDialog(
      title: t.resetCodeTitle(widget.name),
      icon: Icons.key_outlined,
      width: 420,
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.code));
            if (mounted) setState(() => _copied = true);
          },
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 16),
          label: Text(_copied ? t.resetCodeCopied : t.resetCodeCopy),
        ),
        const SizedBox(width: AppSpace.sm),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(t.close)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceControl,
              borderRadius: AppRadius.all(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              widget.code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(t.resetCodeBody(widget.name), style: AppText.body),
          const SizedBox(height: AppSpace.sm),
          Text(t.resetCodeExpires, style: AppText.rowSubtitle),
        ],
      ),
    );
  }
}
