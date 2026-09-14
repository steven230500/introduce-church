import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Shows the first of [variants] that fits the width it is given.
///
/// For a toolbar whose buttons give up their labels as room runs out. Choosing
/// by measuring each variant, rather than by width thresholds written by hand,
/// is what keeps it right when a button is added, a label is translated into a
/// longer language, or a warning chip appears: thresholds had to be retuned
/// for every one of those, and the ones that were not ran the bar off the edge.
///
/// Order the variants from most to least spelled out. The last one is used
/// when none fits.
class FoldingRow extends MultiChildRenderObjectWidget {
  const FoldingRow({super.key, required List<Widget> variants}) : super(children: variants);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFoldingRow();

  @override
  MultiChildRenderObjectElement createElement() => _FoldingRowElement(this);
}

/// Every variant is built, so it can be measured, but only the one showing is
/// on stage: what finders in tests and the inspector see is what is painted,
/// the same way an [Offstage] hides its child from them.
class _FoldingRowElement extends MultiChildRenderObjectElement {
  _FoldingRowElement(super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final chosen = (renderObject as _RenderFoldingRow)._chosen;
    for (final child in children) {
      if (child.renderObject == chosen) visitor(child);
    }
  }
}

class _FoldingParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFoldingRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FoldingParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FoldingParentData> {
  RenderBox? _chosen;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FoldingParentData) child.parentData = _FoldingParentData();
  }

  @override
  void performLayout() {
    RenderBox? pick;
    var child = firstChild;
    while (child != null) {
      pick = child;
      if (child.getMaxIntrinsicWidth(constraints.maxHeight) <= constraints.maxWidth) break;
      child = childAfter(child);
    }
    _chosen = pick;
    if (pick == null) {
      size = constraints.smallest;
      return;
    }
    pick.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(pick.size);
  }

  @override
  double computeMinIntrinsicWidth(double height) => lastChild?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) => firstChild?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => firstChild?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => firstChild?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    final chosen = _chosen;
    if (chosen != null) context.paintChild(chosen, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final chosen = _chosen;
    if (chosen == null) return false;
    return chosen.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final chosen = _chosen;
    if (chosen != null) visitor(chosen);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {}
}
