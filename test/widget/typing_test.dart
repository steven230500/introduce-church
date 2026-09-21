import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/widgets/ui/typing.dart';

void main() {
  testWidgets('a key typed into a text field is not a shortcut', (tester) async {
    final button = FocusNode();
    addTearDown(button.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TextField(autofocus: true),
              TextButton(focusNode: button, onPressed: () {}, child: const Text('Negro')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // What 1.0 to 1.5 asked - is the focused widget a text field? - said no
    // here, and B in the Bible search blacked out the screen.
    expect(isTyping(), isTrue);

    button.requestFocus();
    await tester.pump();
    expect(isTyping(), isFalse);
  });
}
