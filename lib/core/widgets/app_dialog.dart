import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';

// ── Dialog color aliases ──────────────────────────────────────────────────────
//
// These name the role a color plays inside a dialog. The values live in
// AppColors so a palette change lands everywhere at once.

const kDialogBg = AppColors.surface;
const kDialogSurface = AppColors.surfaceControl;
const kDialogBorder = AppColors.border;
const kDialogHeaderBg = AppColors.surfaceRaised;
const kTextPrimary = AppColors.textPrimary;
const kTextSecondary = AppColors.textTertiary;
const kTextMuted = AppColors.textDisabled;
const kAccent = AppColors.accent;
const kDestructive = AppColors.danger;

// ── AppDialog ─────────────────────────────────────────────────────────────────

/// Unified dialog shell. Use instead of AlertDialog / Dialog + custom container.
///
/// Header always shows the Casa Vida isologo + [title]. Optional [icon] appears
/// between the logo and title for context. Close button dismisses by default.
///
/// Pass [actions] to show a footer row. Pass [width]/[height] to size the dialog.
/// If [height] is omitted the dialog shrinks to fit content.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.width = 440,
    this.height,
    this.actions,
    this.icon,
    this.iconColor = kAccent,
    this.contentPadding = const EdgeInsets.all(20),
    this.showClose = true,
  });

  final String title;
  final Widget child;
  final double width;
  final double? height;
  final List<Widget>? actions;
  final IconData? icon;
  final Color iconColor;
  final EdgeInsets contentPadding;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AppDialogHeader(title: title, icon: icon, iconColor: iconColor, showClose: showClose),
        if (height != null)
          Expanded(
            child: Padding(padding: contentPadding, child: child),
          )
        else
          Padding(padding: contentPadding, child: child),
        if (actions != null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
          ),
        ],
      ],
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: kDialogBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kDialogBorder),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 48, offset: Offset(0, 16)),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(14), child: body),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _AppDialogHeader extends StatelessWidget {
  const _AppDialogHeader({
    required this.title,
    this.icon,
    this.iconColor = kAccent,
    this.showClose = true,
  });

  final String title;
  final IconData? icon;
  final Color iconColor;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: kDialogHeaderBg,
        border: Border(bottom: BorderSide(color: kDialogBorder)),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/casavida-isologo-white.png',
            height: 20,
            opacity: const AlwaysStoppedAnimation(0.55),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (showClose)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16, color: kTextSecondary),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: kDialogSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── AppTextField ──────────────────────────────────────────────────────────────

/// Unified dark text field. Matches the dialog design system.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.label,
    this.fillColor = kDialogSurface,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? label;
  final Color fillColor;

  /// Hides what is typed. For passwords.
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscureText,
      // A password field cannot be multiline, and Flutter asserts on the
      // combination rather than ignoring it.
      maxLines: obscureText ? 1 : maxLines,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(color: kTextPrimary, fontSize: 14),
      cursorColor: kAccent,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: label,
        labelStyle: const TextStyle(color: kTextSecondary),
        hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kDialogBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kAccent, width: 1.5),
        ),
      ),
    );
  }
}

// ── showAppConfirmDialog ──────────────────────────────────────────────────────

/// Standard confirm/destructive dialog. Returns true if user confirms.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final t = L10n.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title,
      width: 360,
      icon: icon,
      iconColor: destructive ? kDestructive : kAccent,
      contentPadding: message != null
          ? const EdgeInsets.fromLTRB(20, 16, 20, 4)
          : const EdgeInsets.fromLTRB(20, 0, 20, 0),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel ?? t.cancel),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: destructive ? FilledButton.styleFrom(backgroundColor: kDestructive) : null,
          child: Text(confirmLabel ?? t.confirm),
        ),
      ],
      child: message != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message,
                style: const TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
              ),
            )
          : const SizedBox.shrink(),
    ),
  );
  return result ?? false;
}
