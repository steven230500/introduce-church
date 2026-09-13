import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/models/saved_notice.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/notices_dialog.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeControlRepository repo;
  late FakeOrganizationRepository org;
  late ControlCubit control;

  setUp(() {
    repo = FakeControlRepository(
      rows: [
        collectionRow(
          id: 'c1',
          items: [songItemRow(id: 'i1', collectionId: 'c1', order: 0)],
        ),
      ],
    );
    org = FakeOrganizationRepository(
      notices: const [SavedNotice(text: 'Los niños pasan al salón', autoHideSecs: 10)],
    );
    control = ControlCubit(
      repo,
      FakeTemplateRepository(),
      FakePrefsService(),
      FakePresentationSocket(),
      pending: PendingWrites.inMemory(),
    );
  });

  tearDown(() => control.close());

  ControlModel model() => (control.state as ControlLoadedState).model;

  Future<void> pumpDialog(WidgetTester tester) async {
    await control.load();
    control.selectCollection(model().collections.first);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: control,
          child: Scaffold(body: NoticesDialog(repository: org)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a saved notice is one press away', (tester) async {
    // Typing "los niños pasan al salón" from scratch every week, mid-service,
    // with the room waiting, is the thing this replaces.
    await pumpDialog(tester);

    await tester.tap(find.text('Los niños pasan al salón'));
    await tester.pumpAndSettle();

    expect(model().overlayVisible, isTrue);
    expect(model().overlayText, 'Los niños pasan al salón');

    // This notice carries a clock; a timer still pending when the test ends is
    // a failure in its own right.
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('a notice with a clock takes itself down', (tester) async {
    await pumpDialog(tester);
    await tester.tap(find.text('Los niños pasan al salón'));
    await tester.pumpAndSettle();
    expect(model().overlayVisible, isTrue);

    await tester.pump(const Duration(seconds: 11));

    // An operator who has to remember to take it down again will not.
    expect(model().overlayVisible, isFalse);
  });

  testWidgets('a typed notice can be kept for next week', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField).first, 'Ofrenda');
    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pumpAndSettle();

    expect(org.notices.map((n) => n.text), contains('Ofrenda'));
  });

  testWidgets('a line for the platform never reaches the projector', (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField).last, 'Quedan 5 minutos');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(model().stageMessage, 'Quedan 5 minutos');
    expect(model().overlayVisible, isFalse, reason: 'the congregation sees nothing');
    expect(model().overlayText, isNot('Quedan 5 minutos'));
  });

  testWidgets('a church with none is shown what one looks like', (tester) async {
    // The hint carries the examples, so an empty dialog is not a paragraph
    // explaining itself.
    org.notices = const [];
    await pumpDialog(tester);

    expect(find.textContaining('Ofrenda'), findsOneWidget);
  });

  testWidgets('the thing you press and the thing you type are not the same shape', (tester) async {
    // They were two identical boxes, which during a service is one mistake
    // away from projecting a half-typed sentence.
    await pumpDialog(tester);

    // A saved notice is a bounded card you press, never a field you type in.
    expect(
      find.descendant(of: find.byType(TextField), matching: find.text('Los niños pasan al salón')),
      findsNothing,
    );

    final card = tester.getSize(
      find
          .ancestor(
            of: find.text('Los niños pasan al salón'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(card.width, lessThanOrEqualTo(220));
  });
}
