import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/backgrounds/background_cache.dart';
import 'package:introduce_church/core/backgrounds/background_choice.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/motion/motion_scenes.dart';
import 'package:introduce_church/core/widgets/slide_background.dart';
import 'package:introduce_church/core/widgets/slide_view.dart';
import 'package:introduce_church/modules/display/presenter/display_cubit.dart';
import 'package:introduce_church/modules/display/presenter/display_page.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../helpers/fakes.dart';

/// A projector whose state the test sets directly.
class _Projector extends DisplayCubit {
  _Projector() : super(fakeApiClient(), FakePresentationSocket());
  void show(DisplayState state) => emit(state);
}

void main() {
  setUpAll(() => BackgroundCache.instance = BackgroundCache.disabled());

  final silk = applyBackground(SlideTemplate.darkClassic, const SceneBackground(MotionScene.silk));
  final loop = applyBackground(
    SlideTemplate.darkClassic,
    const LoopBackground('https://media.test/olas.mp4', poster: 'https://media.test/olas.jpg'),
  );

  Widget at(MotionLevel level, SlideTemplate template) => MaterialApp(
    home: SlideMotion(
      level: level,
      child: SizedBox(width: 480, height: 270, child: SlideBackground(template: template)),
    ),
  );

  group('how much a background moves', () {
    testWidgets('a thumbnail of a moving design holds still', (tester) async {
      // Dozens of designs in a list, each asking for sixty frames a second,
      // is the operator's machine spending itself on nothing.
      await tester.pumpWidget(at(MotionLevel.still, silk));
      await tester.pump();

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a preview of the output moves', (tester) async {
      await tester.pumpWidget(at(MotionLevel.scenes, silk));
      await tester.pump();

      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a preview shows a loop\'s still frame instead of a second player', (tester) async {
      await tester.pumpWidget(at(MotionLevel.scenes, loop));
      await tester.pump();

      expect(find.byType(Video), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a scene from a newer app shows the design\'s colour', (tester) async {
      final unknown = silk.copyWith(bgMotion: 'holograma', bgColor: 0xFF224466);
      await tester.pumpWidget(at(MotionLevel.all, unknown));
      await tester.pump();

      final box = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(SlideBackground), matching: find.byType(ColoredBox)),
      );
      expect(box.color, const Color(0xFF224466));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('on the projector', () {
    Future<_Projector> pumpProjector(WidgetTester tester) async {
      final projector = _Projector();
      addTearDown(projector.close);
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<DisplayCubit>.value(value: projector, child: const DisplayPage()),
        ),
      );
      return projector;
    }

    testWidgets('the next line of a song does not restart the background', (tester) async {
      // Drawn with each slide, every new line would cross-fade the scene into
      // a second copy of itself.
      final projector = await pumpProjector(tester);
      projector.show(DisplaySlideState(content: 'Sublime gracia', reference: '', template: silk));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final before = tester.element(find.byType(SlideBackground));

      projector.show(
        DisplaySlideState(content: 'del Señor que a mí', reference: '', template: silk),
      );
      await tester.pump();
      // Mid cross-fade: two slides of words, still one background.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SlideView), findsNWidgets(2));
      expect(find.byType(SlideBackground), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(identical(tester.element(find.byType(SlideBackground)), before), isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a design without a moving background draws it with the slide', (tester) async {
      final projector = await pumpProjector(tester);
      projector.show(
        const DisplaySlideState(
          content: 'Sublime gracia',
          reference: '',
          template: SlideTemplate.darkClassic,
        ),
      );
      await tester.pumpAndSettle();

      final view = tester.widget<SlideView>(find.byType(SlideView));
      expect(view.showBackground, isTrue);
    });

    testWidgets('going to black takes the moving background away too', (tester) async {
      final projector = await pumpProjector(tester);
      projector.show(DisplaySlideState(content: 'a', reference: '', template: silk));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      projector.show(DisplayBlankState());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The frame in which the faded-out scene is finally removed.
      await tester.pump();

      expect(find.byType(SlideBackground), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
