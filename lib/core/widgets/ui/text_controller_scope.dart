import 'package:flutter/widgets.dart';

/// Owns a text controller for exactly as long as what is built with it.
///
/// For dialogs written as a function. A controller made in the function and
/// disposed once `showDialog` returned was gone while the dialog was still
/// animating out, with its text field still attached - and pressing Enter to
/// save, which closes the dialog from inside the field, brought the whole app
/// down in a debug build.
class TextControllerScope extends StatefulWidget {
  const TextControllerScope({
    super.key,
    required this.builder,
    this.text = '',
    this.selectAll = false,
  });

  final String text;

  /// Starts with the text selected, so it can be typed over.
  final bool selectAll;

  final Widget Function(BuildContext context, TextEditingController controller) builder;

  @override
  State<TextControllerScope> createState() => _TextControllerScopeState();
}

class _TextControllerScopeState extends State<TextControllerScope> {
  late final TextEditingController _controller = TextEditingController(text: widget.text)
    ..selection = widget.selectAll
        ? TextSelection(baseOffset: 0, extentOffset: widget.text.length)
        : TextSelection.collapsed(offset: widget.text.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
