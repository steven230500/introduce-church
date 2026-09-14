import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/api/api_client.dart';
import '../../../../core/api/error_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../auth/utils/navigator.dart';
import '../../../../l10n/l10n.dart';

/// Changes the operator's password.
///
/// On success the session is gone, so this returns to the login screen rather
/// than leaving the app holding a token the server has already revoked.
Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  static const _minLength = 8;

  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _next, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _hint {
    if (_next.text.isNotEmpty && _next.text.length < _minLength) {
      return L10n.of(context).passwordNewTooShort(_minLength);
    }
    if (_confirm.text.isNotEmpty && _next.text != _confirm.text) {
      return L10n.of(context).loginHintMismatch;
    }
    if (_next.text.isNotEmpty && _next.text == _current.text) {
      return L10n.of(context).passwordNewSameAsCurrent;
    }
    return null;
  }

  bool get _canSave =>
      !_saving &&
      _current.text.isNotEmpty &&
      _next.text.length >= _minLength &&
      _next.text == _confirm.text &&
      _next.text != _current.text;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await Modular.get<ApiClient>().changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AuthNavigator.goToLogin();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: L10n.of(context).menuChangePassword,
      icon: Icons.key_outlined,
      width: 420,
      showClose: !_saving,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(L10n.of(context).cancel),
        ),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(L10n.of(context).passwordChangeAction),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _current,
            hintText: L10n.of(context).passwordCurrentHint,
            label: L10n.of(context).passwordCurrent,
            obscureText: true,
            autofocus: true,
          ),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _next,
            hintText: L10n.of(context).passwordNewHint(_minLength),
            label: L10n.of(context).passwordNew,
            obscureText: true,
          ),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _confirm,
            hintText: L10n.of(context).passwordRepeatHint,
            label: L10n.of(context).passwordConfirm,
            obscureText: true,
            onSubmitted: (_) => _canSave ? _save() : null,
          ),
          if (_hint != null) ...[
            const SizedBox(height: AppSpace.md),
            _Notice(text: _hint!, color: AppColors.warning, icon: Icons.info_outline),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            _Notice(
              // Here a refused password is the current one, not an email and password.
              text: _error is ApiException && (_error as ApiException).code == 'invalid_credentials'
                  ? L10n.of(context).passwordCurrentWrong
                  : errorText(L10n.of(context), _error),
              color: AppColors.danger,
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: AppSpace.md),
          Text(L10n.of(context).passwordSignsOutEverywhere, style: AppText.rowSubtitle),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpace.sm - 2),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}
