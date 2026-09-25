import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/widgets/ui/reveal_row.dart';

void main() {
  testWidgets('a row far below the viewport is brought into view', (tester) async {
    final key = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    // Rows of different heights, so jumping to about where row 150 is lands
    // near it rather than on it.
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 200; i++)
                SizedBox(
                  key: i == 150 ? key : null,
                  height: i.isEven ? 20 : 44,
                  child: Text('fila $i'),
                ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('fila 150'), findsNothing, reason: 'not drawn yet');
    expect(key.currentContext, isNull);

    revealRow(key: key, controller: controller, at: 150, count: 200);
    await tester.pumpAndSettle();

    expect(find.text('fila 150'), findsOneWidget);
    final box = tester.getRect(find.text('fila 150'));
    expect(box.top, greaterThanOrEqualTo(0));
    expect(box.bottom, lessThanOrEqualTo(300));
  });

  testWidgets('a row already on screen is left where it is', (tester) async {
    final key = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 20; i++)
                SizedBox(key: i == 2 ? key : null, height: 30, child: Text('fila $i')),
            ],
          ),
        ),
      ),
    );

    revealRow(key: key, controller: controller, at: 2, count: 20);
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    expect(find.text('fila 2'), findsOneWidget);
  });
}
