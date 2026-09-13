import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// The line between two panels, and the grip that moves it.
///
/// The columns used to be fixed, which is one hard-coded answer to a question
/// every church answers differently: a set list full of long song titles wants
/// width, a small screen wants everything the preview can get.
///
/// It stays a hairline until the pointer is over it, so the workspace does not
/// grow three more visible controls for something used once and then left
/// alone.
class PanelResizer extends StatefulWidget {
  const PanelResizer({super.key, required this.onDrag, required this.onReset, this.tooltip});

  /// Pixels the edge moved, already signed for the panel being resized: a
  /// positive value always means "wider".
  final ValueChanged<double> onDrag;

  /// Double click puts the panel back to the width it shipped with.
  final VoidCallback onReset;

  final String? tooltip;

  @override
  State<PanelResizer> createState() => _PanelResizerState();
}

class _PanelResizerState extends State<PanelResizer> {
  bool _hovering = false;
  bool _dragging = false;

  bool get _lit => _hovering || _dragging;

  @override
  Widget build(BuildContext context) {
    final resizer = MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        onDoubleTap: widget.onReset,
        child: SizedBox(
          width: 7,
          height: double.infinity,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: _lit ? 3 : 1,
              color: _lit ? AppColors.accent : AppColors.divider,
            ),
          ),
        ),
      ),
    );

    final message = widget.tooltip;
    if (message == null) return resizer;
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 700),
      child: resizer,
    );
  }
}
