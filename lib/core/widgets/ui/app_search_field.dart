import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// Search input used by every library. Debounces so typing doesn't fire a
/// query per keystroke against Supabase.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Buscar...',
    this.autofocus = false,
    this.dense = false,
    this.debounce = const Duration(milliseconds: 250),
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autofocus;

  /// Compact height, for use inside a narrow dock panel.
  final bool dense;
  final Duration debounce;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final _controller = TextEditingController();
  String _lastEmitted = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    Future.delayed(widget.debounce, () {
      if (!mounted) return;
      // Only fire for the newest keystroke, and only if the value actually moved.
      if (_controller.text != value || value == _lastEmitted) return;
      _lastEmitted = value;
      widget.onChanged(value);
    });
  }

  void _clear() {
    _controller.clear();
    _lastEmitted = '';
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.dense ? 8.0 : 11.0;
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      style: TextStyle(color: AppColors.textPrimary, fontSize: widget.dense ? 12 : 14),
      cursorColor: AppColors.accent,
      onChanged: (v) {
        _onChanged(v);
        setState(() {});
      },
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hintText,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: widget.dense ? 12 : 14),
        prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: widget.dense ? 16 : 18),
        prefixIconConstraints: BoxConstraints(
          minWidth: widget.dense ? 32 : 40,
          minHeight: widget.dense ? 16 : 18,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: widget.dense ? 14 : 16, color: AppColors.textMuted),
                onPressed: _clear,
                tooltip: 'Limpiar',
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: vertical),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.all(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.all(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: AppRadius.all(AppRadius.md)),
      ),
    );
  }
}
