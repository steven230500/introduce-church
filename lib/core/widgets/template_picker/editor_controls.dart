import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../ui/hover_builder.dart';

// The controls the design editor is built from.
//
// The editor had grown out of stock Material pieces - underlined dropdowns, an
// outlined name field, loose icon buttons, a teal segmented button - and read
// like a different program from the rest of the app. These carry the app's own
// surfaces, radii and type, and every row of the editor is one of them, so the
// panels line up label under label and control under control.

/// Width of the label column, so every control starts on the same line.
const kEditorLabelWidth = 96.0;

/// Height of a single-line control.
const kEditorControlHeight = 32.0;

/// A group of controls under an uppercase heading.
class EditorSection extends StatelessWidget {
  const EditorSection({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(child: Text(title.toUpperCase(), style: AppText.sectionLabel)),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpace.sm + 2),
            child,
          ],
        ],
      ),
    );
  }
}

/// A label on the left and its control on the right.
class EditorField extends StatelessWidget {
  const EditorField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kEditorControlHeight),
      child: Row(
        children: [
          SizedBox(
            width: kEditorLabelWidth,
            child: Text(
              label,
              style: AppText.body.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A dropdown drawn as a filled control rather than an underlined one.
class EditorDropdown<T> extends StatelessWidget {
  const EditorDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.selectedItemBuilder,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;
  final DropdownButtonBuilder? selectedItemBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kEditorControlHeight,
      padding: const EdgeInsets.only(left: AppSpace.md, right: AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          selectedItemBuilder: selectedItemBuilder,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.textTertiary),
          dropdownColor: AppColors.surfaceRaised,
          borderRadius: AppRadius.all(AppRadius.md),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          onChanged: (next) {
            if (next != null || null is T) onChanged(next as T);
          },
        ),
      ),
    );
  }
}

/// One option of an [EditorSegmented].
class EditorSegment<T> {
  const EditorSegment({required this.value, this.icon, this.label, this.tooltip});

  final T value;
  final IconData? icon;
  final String? label;
  final String? tooltip;
}

/// Mutually exclusive options side by side, the chosen one filled in accent.
class EditorSegmented<T> extends StatelessWidget {
  const EditorSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = true,
  });

  final List<EditorSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Share the width equally instead of sizing each option to its content.
  final bool expand;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Icons go first when there is not room for both: "Degradado" beside an
      // icon did not fit a third of the layers column and read "Degra...".
      final roomy =
          !expand || !constraints.hasBoundedWidth || constraints.maxWidth / segments.length >= 90;
      return _build(context, showIcons: roomy);
    },
  );

  Widget _build(BuildContext context, {required bool showIcons}) {
    Widget segment(EditorSegment<T> option) {
      final active = option.value == selected;
      final icon = showIcons || option.label == null ? option.icon : null;
      final colour = active ? Colors.white : AppColors.textTertiary;
      Widget body = HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovering) => GestureDetector(
          onTap: () => onChanged(option.value),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: kEditorControlHeight - 4,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent
                  : (hovering ? AppColors.surfaceRaised : Colors.transparent),
              borderRadius: AppRadius.all(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) Icon(icon, size: 14, color: colour),
                if (icon != null && option.label != null) const SizedBox(width: AppSpace.xs + 1),
                if (option.label != null)
                  Flexible(
                    child: Text(
                      option.label!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colour,
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (option.tooltip != null) body = Tooltip(message: option.tooltip, child: body);
      return expand ? Expanded(child: body) : body;
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final option in segments) segment(option)],
      ),
    );
  }
}

/// A label with a switch at the end of the row.
class EditorSwitch extends StatelessWidget {
  const EditorSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return EditorField(
      label: label,
      child: Align(
        alignment: Alignment.centerRight,
        child: Transform.scale(
          scale: 0.8,
          alignment: Alignment.centerRight,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}

/// A slider with its number beside it; the number can be typed into.
class EditorSlider extends StatelessWidget {
  const EditorSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int decimals;

  String get _display => decimals > 0 ? value.toStringAsFixed(decimals) : value.round().toString();

  @override
  Widget build(BuildContext context) {
    return EditorField(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.border,
                thumbColor: Colors.white,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                tickMarkShape: SliderTickMarkShape.noTickMark,
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: ((max - min) * (decimals > 0 ? 10 : 0.5)).round().clamp(1, 200),
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          _NumberBox(
            text: _display,
            onSubmitted: (raw) {
              final parsed = double.tryParse(raw.replaceAll(',', '.'));
              if (parsed != null) onChanged(parsed.clamp(min, max));
            },
          ),
        ],
      ),
    );
  }
}

/// The number beside a slider, which can also be typed into.
///
/// A slider cannot be asked for 48 on purpose. The value was a label, so the
/// only way to reach an exact size was to nudge the handle and hope.
class _NumberBox extends StatefulWidget {
  const _NumberBox({required this.text, required this.onSubmitted});

  final String text;
  final ValueChanged<String> onSubmitted;

  @override
  State<_NumberBox> createState() => _NumberBoxState();
}

class _NumberBoxState extends State<_NumberBox> {
  late final TextEditingController _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_NumberBox old) {
    super.didUpdateWidget(old);
    // The slider moved. Do not overwrite what is being typed.
    if (widget.text != old.text && !_focus.hasFocus) _controller.text = widget.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onSubmitted(_controller.text);
    _controller.text = widget.text;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: kEditorControlHeight - 4,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceControl,
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.all(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.all(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) {
          if (!_focus.hasFocus) return;
          _focus.unfocus();
          _commit();
        },
      ),
    );
  }
}

/// A filled text field in the editor's own style.
class EditorTextInput extends StatelessWidget {
  const EditorTextInput({
    super.key,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.fontSize = 12,
  });

  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      cursorColor: AppColors.accent,
      style: TextStyle(color: AppColors.textPrimary, fontSize: fontSize),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: fontSize),
        filled: true,
        fillColor: AppColors.surfaceControl,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.all(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.all(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}
