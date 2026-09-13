import 'package:flutter/material.dart';

/// Rebuilds its child when the pointer arrives or leaves.
///
/// The workspace gave no sign it had noticed the mouse until a click landed,
/// which is what made a set list feel like a printed page rather than
/// something you operate. Exists as a builder so the rows that need it do not
/// each have to become stateful for one boolean.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder, this.cursor = MouseCursor.defer});

  final Widget Function(BuildContext context, bool hovering) builder;
  final MouseCursor cursor;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: widget.builder(context, _hovering),
    );
  }
}
