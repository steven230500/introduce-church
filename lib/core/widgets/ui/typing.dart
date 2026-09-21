import 'package:flutter/widgets.dart';

/// Whether the keyboard is in a text field right now, so a key belongs to
/// the words being typed and not to a shortcut.
///
/// The node a text field focuses sits on a `Focus` inside its `EditableText`,
/// not on the `EditableText` itself: asking whether the focused widget *is*
/// one always said no, and typing "Biblia" in the Bible panel's search put
/// the screen to black on the B.
bool isTyping([FocusNode? node]) {
  final context = (node ?? FocusManager.instance.primaryFocus)?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}
