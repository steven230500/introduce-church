import 'package:flutter/material.dart';

import '../../../../../../core/api/error_text.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_dimens.dart';
import '../../../../../../core/theme/app_text.dart';
import '../../../../../../core/widgets/app_dialog.dart';
import '../../../../../../l10n/l10n.dart';

typedef ResetPassword =
    Future<void> Function({
      required String email,
      required String code,
      required String newPassword,
    });

/// Asks for the code an administrator created, and sets a new password.
///
/// Pops with the email when the password was changed, so the sign-in form can
/// say so. Nothing is mailed anywhere: the code came from someone at church.
class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key, required this.reset, this.email = ''});

  final ResetPassword reset;
  final String email;

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  static const _minLength = 8;

  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  Object? _error;

  List<TextEditingController> get _controllers => [_email, _code, _next, _confirm];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _hint {
    final t = L10n.of(context);
    if (_next.text.isNotEmpty && _next.text.length < _minLength) {
      return t.passwordNewTooShort(_minLength);
    }
    if (_confirm.text.isNotEmpty && _next.text != _confirm.text) return t.loginHintMismatch;
    return null;
  }

  bool get _canSave =>
      !_saving &&
      _email.text.contains('@') &&
      _code.text.trim().length >= 8 &&
      _next.text.length >= _minLength &&
      _next.text == _confirm.text;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.reset(email: _email.text, code: _code.text, newPassword: _next.text);
      if (!mounted) return;
      Navigator.of(context).pop(_email.text.trim());
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
    final t = L10n.of(context);
    return AppDialog(
      title: t.resetTitle,
      icon: Icons.key_outlined,
      width: 420,
      showClose: !_saving,
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(t.cancel)),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.passwordChangeAction),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.resetIntro, style: AppText.body),
          const SizedBox(height: AppSpace.lg),
          AppTextField(controller: _email, hintText: t.loginEmail, label: t.loginEmail),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _code,
            hintText: t.resetCodeHint,
            label: t.resetCode,
            autofocus: widget.email.isNotEmpty,
          ),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _next,
            hintText: t.passwordNewHint(_minLength),
            label: t.passwordNew,
            obscureText: true,
          ),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _confirm,
            hintText: t.passwordRepeatHint,
            label: t.passwordConfirm,
            obscureText: true,
            onSubmitted: (_) => _canSave ? _save() : null,
          ),
          if (_hint != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(_hint!, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              errorText(t, _error),
              style: const TextStyle(color: AppColors.danger, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
