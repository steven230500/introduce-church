import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../utils/color_contrast.dart';
import '../ui/hover_builder.dart';

/// Picking a colour, including one that is not on the list.
///
/// The editor used to offer twenty swatches written into the source and
/// nothing else, so a church with its own colours could not use them. This
/// keeps the swatches for speed and adds the field that makes the rest of the
/// spectrum reachable.
class ColorField extends StatefulWidget {
  const ColorField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.palette = defaultPalette,
    this.saved = const [],
    this.against,
    this.onSave,
    this.onForget,
    this.swatchSize = 22,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  /// The colours offered first.
  final List<int> palette;

  /// The church's own colours, offered on their own row.
  final List<int> saved;

  /// What this colour will be seen against, when that is known. Drives the
  /// readability note; a photo background has no single answer, so callers
  /// pass null and no note is shown.
  final int? against;

  /// Keeps the current colour for the whole church. Absent when there is
  /// nowhere to keep it.
  final ValueChanged<int>? onSave;

  /// Drops one of the church's colours.
  final ValueChanged<int>? onForget;

  final double swatchSize;

  static const defaultPalette = [
    0xFF000000,
    0xFF1A1A2E,
    0xFF0D0D2B,
    0xFF0F3460,
    0xFF1B1B1B,
    0xFF2C2C2E,
    0xFF3A3A3C,
    0xFF48484A,
    0xFFFFFFFF,
    0xFFF5F5F5,
    0xFFE0E0E0,
    0xFFBBBBBB,
    0xFFFF3B30,
    0xFFFF9500,
    0xFFFFCC00,
    0xFF34C759,
    0xFF0A84FF,
    0xFF5856D6,
    0xFFBF5AF2,
    0xFFFF2D55,
  ];

  @override
  State<ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<ColorField> {
  late final TextEditingController _hex = TextEditingController(text: hexOf(widget.value));
  final _focus = FocusNode();

  @override
  void didUpdateWidget(ColorField old) {
    super.didUpdateWidget(old);
    // A swatch was pressed, or the design changed underneath. Do not fight the
    // operator for the field while they are typing in it.
    if (widget.value != old.value && !_focus.hasFocus) {
      _hex.text = hexOf(widget.value);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parsed = parseHexColor(raw);
    if (parsed == null) {
      // Put back what is actually in use rather than leaving nonsense on
      // screen next to a colour it does not describe.
      _hex.text = hexOf(widget.value);
      return;
    }
    _hex.text = hexOf(parsed);
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: AppSpace.sm - 2),
        if (widget.saved.isNotEmpty) ...[
          const Text(
            'DE LA IGLESIA',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          _Swatches(
            colors: widget.saved,
            value: widget.value,
            size: widget.swatchSize,
            onPick: widget.onChanged,
            onForget: widget.onForget,
          ),
          const SizedBox(height: AppSpace.sm - 2),
        ],
        _Swatches(
          colors: widget.palette,
          value: widget.value,
          size: widget.swatchSize,
          onPick: widget.onChanged,
        ),
        const SizedBox(height: AppSpace.sm),
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Color(widget.value),
                borderRadius: AppRadius.all(AppRadius.xs),
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            SizedBox(
              width: 96,
              child: TextField(
                controller: _hex,
                focusNode: _focus,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(9),
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F#]')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                  hintText: '#RRGGBB',
                ),
                onSubmitted: _commit,
                onTapOutside: (_) {
                  _focus.unfocus();
                  _commit(_hex.text);
                },
              ),
            ),
            if (widget.onSave != null && !widget.saved.contains(widget.value)) ...[
              const SizedBox(width: AppSpace.sm - 2),
              Tooltip(
                message: 'Guardar en los colores de la iglesia',
                child: GestureDetector(
                  onTap: () => widget.onSave!(widget.value),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceControl,
                        borderRadius: AppRadius.all(AppRadius.xs),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ],
            if (widget.against != null) ...[
              const SizedBox(width: AppSpace.sm),
              Flexible(
                child: _ContrastNote(colour: widget.value, against: widget.against!),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.colors,
    required this.value,
    required this.size,
    required this.onPick,
    this.onForget,
  });

  final List<int> colors;
  final int value;
  final double size;
  final ValueChanged<int> onPick;

  /// When given, a saved colour can be dropped from the row it lives in.
  final ValueChanged<int>? onForget;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final colour in colors)
          if (onForget != null)
            _SavedSwatch(
              colour: colour,
              selected: colour == value,
              size: size,
              onPick: () => onPick(colour),
              onForget: () => onForget!(colour),
            )
          else
            GestureDetector(
              onTap: () => onPick(colour),
              child: Tooltip(
                message: hexOf(colour),
                waitDuration: const Duration(milliseconds: 600),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Color(colour),
                    borderRadius: AppRadius.all(AppRadius.xs),
                    border: Border.all(
                      color: colour == value ? AppColors.accent : Colors.white24,
                      width: colour == value ? 2 : 1,
                    ),
                  ),
                  child: colour == value
                      ? Icon(
                          Icons.check,
                          size: size * 0.55,
                          color: colour == 0xFFFFFFFF ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
      ],
    );
  }
}

/// A saved colour, with the way to stop saving it.
class _SavedSwatch extends StatelessWidget {
  const _SavedSwatch({
    required this.colour,
    required this.selected,
    required this.size,
    required this.onPick,
    required this.onForget,
  });

  final int colour;
  final bool selected;
  final double size;
  final VoidCallback onPick;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovering) => GestureDetector(
        onTap: onPick,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Color(colour),
                borderRadius: AppRadius.all(AppRadius.xs),
                border: Border.all(
                  color: selected ? AppColors.accent : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: size * 0.55,
                      color: colour == 0xFFFFFFFF ? Colors.black : Colors.white,
                    )
                  : null,
            ),
            // Only on hover, and overlapping the swatch rather than hanging off
            // it: Flutter does not hit-test the part of a child that falls
            // outside its parent, so an overhang is a button that cannot be
            // pressed where it looks like it can.
            if (hovering)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onForget,
                  child: Tooltip(
                    message: 'Quitar de los colores de la iglesia',
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 9, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Says whether this pairing will be readable from the back of the room.
class _ContrastNote extends StatelessWidget {
  const _ContrastNote({required this.colour, required this.against});

  final int colour;
  final int against;

  @override
  Widget build(BuildContext context) {
    final ratio = contrastRatio(colour, against);
    final verdict = verdictFor(ratio);
    final tone = switch (verdict) {
      ContrastVerdict.good => AppColors.success,
      ContrastVerdict.tight => AppColors.warning,
      ContrastVerdict.poor => AppColors.danger,
    };

    return Tooltip(
      message: 'Contraste ${ratio.toStringAsFixed(1)} a 1 contra el fondo',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verdict == ContrastVerdict.good
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            size: 13,
            color: tone,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              verdict.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tone, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
