import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/widgets/ui/folding_row.dart';

void main() {
  Widget bar(double width, {VoidCallback? onWide, VoidCallback? onNarrow}) => MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: FoldingRow(
          variants: [
            GestureDetector(
              onTap: onWide,
              child: const SizedBox(width: 300, height: 40, child: Text('ancha')),
            ),
            GestureDetector(
              onTap: onNarrow,
              child: const SizedBox(width: 120, height: 40, child: Text('angosta')),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('shows the most spelled-out variant that fits', (tester) async {
    await tester.pumpWidget(bar(400));
    expect(find.text('ancha'), findsOneWidget);
    expect(find.text('angosta'), findsNothing, reason: 'built to be measured, not on stage');

    await tester.pumpWidget(bar(200));
    expect(find.text('ancha'), findsNothing);
    expect(find.text('angosta'), findsOneWidget);
  });

  testWidgets('falls back to the last variant when nothing fits', (tester) async {
    await tester.pumpWidget(bar(50));
    expect(find.text('angosta'), findsOneWidget);
  });

  testWidgets('only the variant showing can be clicked', (tester) async {
    var wide = 0;
    var narrow = 0;
    await tester.pumpWidget(bar(200, onWide: () => wide++, onNarrow: () => narrow++));

    await tester.tapAt(const Offset(20, 20));

    expect(narrow, 1);
    expect(wide, 0);
  });
}
