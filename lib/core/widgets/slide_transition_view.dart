import 'package:flutter/material.dart';

import '../models/slide_template.dart';

/// Moves between slides the way the design says to.
///
/// The projector has always dissolved and the operator's copy of it cut, which
/// made the preview a slightly dishonest mirror and made the workspace feel
/// stiff next to the screen it controls. Both use this now, so whatever a
/// church picks for the congregation is what the operator sees too.
class SlideTransitionView extends StatelessWidget {
  const SlideTransitionView({
    super.key,
    required this.template,
    required this.slideKey,
    required this.child,
  });

  final SlideTemplate template;

  /// Changes when the slide changes, and only then. Keying on the content
  /// itself would replay the transition on a repeated line.
  final Object slideKey;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final type = template.transitionType;
    return AnimatedSwitcher(
      duration: type == SlideTransitionType.cut
          ? Duration.zero
          : Duration(milliseconds: template.transitionDurationMs),
      transitionBuilder: (child, animation) => buildSlideTransition(child, animation, type),
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(slideKey), child: child),
    );
  }
}

/// The transition itself, shared by the projector and the preview.
Widget buildSlideTransition(Widget child, Animation<double> animation, SlideTransitionType type) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
  return switch (type) {
    SlideTransitionType.cut => child,
    SlideTransitionType.fade => FadeTransition(opacity: curved, child: child),
    SlideTransitionType.slideLeft => SlideTransition(
      position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
      child: FadeTransition(opacity: animation, child: child),
    ),
    SlideTransitionType.slideRight => SlideTransition(
      position: Tween(begin: const Offset(-0.06, 0), end: Offset.zero).animate(curved),
      child: FadeTransition(opacity: animation, child: child),
    ),
    SlideTransitionType.zoomIn => ScaleTransition(
      scale: Tween(begin: 0.96, end: 1.0).animate(curved),
      child: FadeTransition(opacity: animation, child: child),
    ),
  };
}
