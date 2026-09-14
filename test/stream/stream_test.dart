import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/services/pending_writes.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';
import 'package:introduce_church/core/stream/stream_style.dart';
import 'package:introduce_church/core/stream/stream_view.dart';
import 'package:introduce_church/modules/display/presenter/display_cubit.dart';
import 'package:introduce_church/modules/presentation/children/control/presenter/cubit/cubit.dart';
import 'package:introduce_church/modules/presentation/shell/widgets/stream_dialog.dart';
import 'package:introduce_church/modules/stream/stream_app.dart';
import 'package:introduce_church/modules/stream/stream_cubit.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  group('the style', () {
    test('survives being saved and sent', () {
      const style = StreamStyle(
        key: StreamKey.blue,
        position: StreamPosition.top,
        bar: false,
        scale: 1.3,
        showReference: false,
      );
      expect(StreamStyle.fromJson(style.toJson()), style);
    });

    test('anything unknown or out of range takes a working default', () {
      final style = StreamStyle.fromJson({
        'key': 'plaid',
        'position': 'left',
        'scale': 9,
        'bar': 'yes',
      });
      expect(style.key, StreamKey.green);
      expect(style.position, StreamPosition.bottom);
      expect(style.scale, StreamStyle.maxScale);
      expect(style.bar, isTrue);
      expect(StreamStyle.fromJson(null), const StreamStyle());
    });
  });

  group('what goes out on the stream', () {
    test('the words of a slide, with its reference', () {
      expect(
        streamWords(
          const DisplaySlideState(
            content: 'Porque de tal manera amó Dios al mundo',
            reference: 'Juan 3:16',
            template: SlideTemplate.darkClassic,
          ),
        ),
        ('Porque de tal manera amó Dios al mundo', 'Juan 3:16'),
      );
    });

    test('nothing for what only the room should see: the camera is the picture', () {
      for (final state in [
        DisplayBlankState(),
        DisplayIdleState(),
        const DisplayImageState(imagePath: '/foto.jpg'),
        const DisplayVideoState(videoPath: '/video.mp4'),
      ]) {
        expect(streamWords(state), ('', ''), reason: '${state.runtimeType}');
      }
    });

    test('a notice over a photo or a video is words, and goes out', () {
      expect(
        streamWords(
          const DisplayImageState(
            imagePath: '/foto.jpg',
            overlayVisible: true,
            overlayText: 'Reunión de jóvenes el sábado',
          ),
        ),
        ('Reunión de jóvenes el sábado', ''),
      );
    });
  });

  group('the stream window', () {
    test('takes its look from the control window, and keeps it when the server speaks', () async {
      final cubit = StreamCubit(OfflineApiClient(), FakePresentationSocket());
      addTearDown(cubit.close);

      await cubit.applyLocalState({
        'is_live': false,
        'stream_style': const StreamStyle(key: StreamKey.magenta).toJson(),
      });
      expect(cubit.style.value.key, StreamKey.magenta);

      // A later message without it - the socket's - must not reset it.
      await cubit.applyLocalState({'is_live': false});
      expect(cubit.style.value.key, StreamKey.magenta);
    });

    testWidgets('with nothing to say it is the key colour and nothing else', (tester) async {
      await tester.pumpWidget(
        const SizedBox(width: 640, height: 360, child: StreamView(style: StreamStyle())),
      );
      expect(find.byType(Text), findsNothing);
      final box = tester.widget<ColoredBox>(find.byType(ColoredBox).first);
      expect(box.color, StreamKey.green.color);
    });

    testWidgets('a long verse fits the band at a small window', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 480,
            height: 270,
            child: StreamView(
              style: StreamStyle(bar: false, scale: StreamStyle.maxScale),
              text:
                  'Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito, '
                  'para que todo aquel que en él cree, no se pierda, mas tenga vida eterna.',
              reference: 'Juan 3:16',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // Its own text style: with no Material above it - as in the stream
      // window - Flutter's fallback underlines every word in yellow.
      for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
        expect(text.text.style?.decoration, TextDecoration.none);
      }
      // Without the bar, an outline: a stroked copy under the filled one.
      expect(find.textContaining('Porque de tal manera', findRichText: true), findsNWidgets(2));
    });
  });

  group('the settings', () {
    late FakePrefsService prefs;
    late ControlCubit control;

    setUp(() async {
      prefs = FakePrefsService();
      control = ControlCubit(
        FakeControlRepository(rows: [collectionRow(id: 'c1')]),
        FakeTemplateRepository(),
        prefs,
        FakePresentationSocket(),
        pending: PendingWrites.inMemory(),
      );
      await control.load();
    });

    tearDown(() => control.close());

    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(kMinWindowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BlocProvider.value(
          value: control,
          child: localizedApp(StreamDialog(initial: await control.streamStyle())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('fit the smallest window, and say how to set up OBS', (tester) async {
      await pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Captura de ventana'), findsOneWidget);
      expect(find.textContaining('Chroma Key'), findsOneWidget);
    });

    testWidgets('a change is kept on this computer at once', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Negro'));
      await tester.pumpAndSettle();

      expect(StreamStyle.fromJson(prefs.streamStyle).key, StreamKey.black);
      expect(await control.streamStyle(), const StreamStyle(key: StreamKey.black));
      // Black is removed by brightness, not by colour.
      expect(find.textContaining('Luma Key'), findsOneWidget);
    });
  });
}
