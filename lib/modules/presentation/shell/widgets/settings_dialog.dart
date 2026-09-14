import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import 'package:screen_retriever/screen_retriever.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_version.dart';
import '../../../../core/services/update_checker.dart';
import '../../../../core/services/locale_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/ui/flag.dart';
import '../../../../core/widgets/ui/hover_builder.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/utils/navigator.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import 'change_password_dialog.dart';
import 'projector_picker_dialog.dart';
import 'update_dialog.dart';

/// Everything set on this computer rather than for the church: who is signed
/// in, the language, and the screen the projector opens on.
Future<void> showSettingsDialog(BuildContext context, ControlCubit control) {
  final api = Modular.get<ApiClient>();
  return showDialog<void>(
    context: context,
    builder: (dialog) => SettingsDialog(
      user: api.currentUser,
      locale: Modular.get<LocaleController>(),
      displays: control.projectorDisplays,
      rememberedDisplay: control.rememberedProjector,
      rememberDisplay: control.rememberProjector,
      updates: Modular.get<UpdateChecker>(),
      onChangePassword: () => showChangePasswordDialog(context),
      onSignOut: () async {
        Navigator.of(dialog).pop();
        await api.signOut();
        AuthNavigator.goToLogin();
      },
    ),
  );
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.user,
    required this.locale,
    required this.displays,
    required this.rememberedDisplay,
    required this.rememberDisplay,
    required this.onChangePassword,
    required this.onSignOut,
    this.updates,
    this.version = appVersion,
    this.onOpenUpdate,
  });

  final AuthUser? user;
  final LocaleController locale;
  final Future<List<Display>> Function() displays;
  final Future<Display?> Function() rememberedDisplay;
  final Future<void> Function(Display) rememberDisplay;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;

  /// Where the version section asks about updates. Without one it shows the
  /// version alone.
  final UpdateChecker? updates;
  final String version;

  /// Shows a found update. Defaults to the update dialog.
  final void Function(AvailableUpdate update)? onOpenUpdate;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  List<Display> _displays = const [];
  Display? _projector;

  /// The result of the last check asked for here: null before any, then
  /// whether GitHub answered.
  bool? _reached;
  bool _checking = false;

  Future<void> _checkUpdates() async {
    final updates = widget.updates;
    if (updates == null) return;
    setState(() => _checking = true);
    final reached = await updates.check();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _reached = reached;
    });
  }

  void _openUpdate(AvailableUpdate update) {
    final open = widget.onOpenUpdate;
    if (open != null) {
      open(update);
    } else {
      showUpdateDialog(context, update);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDisplays();
  }

  Future<void> _loadDisplays() async {
    final displays = await widget.displays();
    final remembered = await widget.rememberedDisplay();
    if (!mounted) return;
    setState(() {
      _displays = displays;
      _projector = remembered;
    });
  }

  Future<void> _chooseProjector() async {
    final chosen = await showProjectorPicker(context, displays: _displays, current: _projector);
    if (chosen == null) return;
    await widget.rememberDisplay(chosen);
    if (mounted) setState(() => _projector = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final user = widget.user;

    return AppDialog(
      title: t.settingsTitle,
      icon: Icons.settings_outlined,
      width: 480,
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close))],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(label: t.settingsAccount),
          if (user != null) ...[
            if (user.displayName?.isNotEmpty == true)
              Text(user.displayName!, style: AppText.rowTitle),
            Text(user.email, style: AppText.body),
            const SizedBox(height: AppSpace.md),
          ],
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onChangePassword,
                icon: const Icon(Icons.key_outlined, size: 15),
                label: Text(t.menuChangePassword),
              ),
              OutlinedButton.icon(
                onPressed: widget.onSignOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.border),
                ),
                icon: const Icon(Icons.logout_rounded, size: 15),
                label: Text(t.menuSignOut),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          _Section(label: t.settingsLanguage),
          ValueListenableBuilder<Locale?>(
            valueListenable: widget.locale,
            builder: (context, chosen, _) => Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                _Choice(
                  label: t.languageFollowSystem,
                  selected: chosen == null,
                  onTap: () => widget.locale.choose(null),
                ),
                for (final option in LocaleController.supported)
                  _Choice(
                    // Each language by its own name, so somebody looking for
                    // theirs finds it whatever the app is in now.
                    label: lookupL10n(option).languageName,
                    flag: Flag.forLanguage(option.languageCode),
                    selected: chosen?.languageCode == option.languageCode,
                    onTap: () => widget.locale.choose(option),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          _Section(label: t.settingsProjector),
          Row(
            children: [
              Expanded(
                child: Text(
                  _displays.length < 2
                      ? t.settingsProjectorOneScreen
                      : _projector == null
                      ? t.settingsProjectorUnset
                      : _describe(t, _projector!),
                  style: AppText.body,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              if (_displays.length > 1)
                OutlinedButton(onPressed: _chooseProjector, child: Text(t.settingsProjectorChoose)),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          _Section(label: t.settingsVersion),
          _versionRow(t),
        ],
      ),
    );
  }

  Widget _versionRow(L10n t) {
    final updates = widget.updates;
    final version = Text(t.settingsVersionNumber(widget.version), style: AppText.body);
    if (updates == null) return version;

    return ValueListenableBuilder<AvailableUpdate?>(
      valueListenable: updates.available,
      builder: (context, update, _) {
        final note = update != null
            ? null
            : _reached == true
            ? t.settingsUpToDate
            : _reached == false
            ? t.settingsUpdateFailed
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: version),
                const SizedBox(width: AppSpace.md),
                if (update != null)
                  FilledButton.icon(
                    onPressed: () => _openUpdate(update),
                    icon: const Icon(Icons.system_update_alt_rounded, size: 15),
                    label: Text(t.settingsUpdateTo(update.version)),
                  )
                else
                  OutlinedButton(
                    onPressed: _checking ? null : _checkUpdates,
                    child: Text(t.settingsCheckUpdates),
                  ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(note, style: AppText.body),
            ],
          ],
        );
      },
    );
  }

  String _describe(L10n t, Display display) {
    final position = _displays.indexWhere((d) => d.id == display.id) + 1;
    final name = display.name;
    final label = name == null || name.isEmpty ? t.projectorScreenNumber(position) : name;
    return '$label  ·  ${display.size.width.round()} × ${display.size.height.round()}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.sm),
    child: Text(label.toUpperCase(), style: AppText.sectionLabel),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap, this.flag});

  final String label;
  final String? flag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovering) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentFill
                : (hovering ? AppColors.surfaceRaised : AppColors.surfaceControl),
            borderRadius: AppRadius.all(AppRadius.md),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (flag != null) ...[
                Flag(country: flag!, width: 20, radius: 3),
                const SizedBox(width: AppSpace.sm),
              ] else if (selected) ...[
                const Icon(Icons.check_rounded, size: 14, color: AppColors.accentLight),
                const SizedBox(width: AppSpace.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
