import 'package:flutter/widgets.dart';

/// Brings row [at] of a list into view, even when it has not been drawn yet.
///
/// A list lays out only the rows around the viewport, so the row of John 3:16
/// does not exist while the chapter is showing verse 1, and the element the
/// operator jumped to with a number key may be below the bottom of the panel:
/// [Scrollable.ensureVisible] has nothing to scroll to. Jumping to about
/// where the row is builds it, and then it can be placed exactly. Rows are
/// not all the same height, so about may be a screen off; that is what
/// [tries] is for.
void revealRow({
  required GlobalKey key,
  required ScrollController controller,
  required int at,
  required int count,
  int tries = 4,
  double alignment = 0.25,
}) {
  final row = key.currentContext;
  if (row != null) {
    Scrollable.ensureVisible(row, alignment: alignment);
    return;
  }
  if (tries == 0 || at < 0 || count < 2 || !controller.hasClients) return;
  final extent = controller.position.maxScrollExtent;
  if (extent == 0) return;
  controller.jumpTo((extent * at / (count - 1)).clamp(0, extent));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!controller.hasClients) return;
    revealRow(
      key: key,
      controller: controller,
      at: at,
      count: count,
      tries: tries - 1,
      alignment: alignment,
    );
  });
}
