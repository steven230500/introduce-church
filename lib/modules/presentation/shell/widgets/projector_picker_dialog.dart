import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';

/// Asks which screen the congregation is looking at.
///
/// The app used to take whichever display the system listed second. In a room
/// wired with a laptop, a projector and a foyer television that is a coin
/// flip, and getting it wrong means somebody crawling behind a rack during the
/// first song.
Future<Display?> showProjectorPicker(
  BuildContext context, {
  required List<Display> displays,
  Display? current,
}) {
  return showDialog<Display>(
    context: context,
    builder: (_) => AppDialog(
      title: '¿En qué pantalla se proyecta?',
      icon: Icons.present_to_all_outlined,
      width: 420,
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < displays.length; i++)
            _DisplayRow(
              display: displays[i],
              position: i + 1,
              selected: displays[i].id == current?.id,
            ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Se recuerda para la próxima. Clic derecho en Proyector para cambiarla.',
            style: AppText.rowSubtitle,
          ),
        ],
      ),
    ),
  );
}

class _DisplayRow extends StatelessWidget {
  const _DisplayRow({required this.display, required this.position, required this.selected});

  final Display display;
  final int position;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = display.visibleSize ?? display.size;
    final name = display.name?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm - 2),
      child: GestureDetector(
        onTap: () => Navigator.pop(context, display),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm + 2),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentFill : AppColors.surfaceControl,
              borderRadius: AppRadius.all(AppRadius.md),
              border: Border.all(color: selected ? AppColors.accent : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  position == 1 ? Icons.laptop_mac_rounded : Icons.tv_rounded,
                  size: 18,
                  color: selected ? AppColors.accentLight : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name == null || name.isEmpty ? 'Pantalla $position' : name,
                        style: AppText.rowTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${size.width.round()} × ${size.height.round()}'
                        '${position == 1 ? '  ·  la del operador' : ''}',
                        style: AppText.rowSubtitle,
                      ),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle, size: 16, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
