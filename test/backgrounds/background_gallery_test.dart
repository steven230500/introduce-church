import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/api/session.dart';
import 'package:introduce_church/core/backgrounds/background_cache.dart';
import 'package:introduce_church/core/backgrounds/background_choice.dart';
import 'package:introduce_church/core/backgrounds/background_gallery_cubit.dart';
import 'package:introduce_church/core/backgrounds/background_standard.dart';
import 'package:introduce_church/core/models/media_item.dart';
import 'package:introduce_church/core/motion/motion_scenes.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';
import 'package:introduce_church/core/widgets/backgrounds/background_gallery_dialog.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

void main() {
  const fullHd = BackgroundCandidate(
    path: '/in/cruz.png',
    bytes: 3 << 20,
    width: 1920,
    height: 1080,
  );
  const loop = BackgroundCandidate(
    path: '/in/olas.mp4',
    bytes: 40 << 20,
    width: 1920,
    height: 1080,
    duration: Duration(seconds: 30),
  );
  const phone = BackgroundCandidate(
    path: '/in/vertical.jpg',
    bytes: 2 << 20,
    width: 1080,
    height: 1920,
  );
  const blink = BackgroundCandidate(
    path: '/in/blink.mp4',
    bytes: 1 << 20,
    width: 1280,
    height: 720,
    duration: Duration(seconds: 1),
  );

  final probe = FakeBackgroundProbe({
    for (final c in [fullHd, loop, phone, blink]) c.path: c,
  }, still: File('/tmp/does-not-matter.jpg'));

  late FakeMediaRepository repo;

  setUp(() => repo = FakeMediaRepository());

  BackgroundGalleryCubit gallery({BackgroundChoice? initial}) => BackgroundGalleryCubit(
    repo,
    probe: probe,
    cache: BackgroundCache.disabled(),
    initial: initial,
  );

  group('adding a background', () {
    test('a file that breaks the standard is never sent', () async {
      // The operator hears everything wrong with it before any upload starts,
      // not after four minutes of one.
      final cubit = gallery();
      addTearDown(cubit.close);

      await cubit.add(phone.path);

      expect(repo.uploads, isEmpty);
      final refused = cubit.state.adding as RefusedBackground;
      expect(refused.filename, 'vertical.jpg');
      expect(refused.problems, contains(isA<WrongShape>()));
    });

    test('the plan\'s own limit counts, when it is lower than the standard\'s', () async {
      repo.maxUploadBytes = 25 << 20;
      final cubit = gallery();
      addTearDown(cubit.close);

      await cubit.add(loop.path);

      expect(repo.uploads, isEmpty);
      expect(
        (cubit.state.adding as RefusedBackground).problems,
        contains(const TooHeavy(40 << 20, 25 << 20)),
      );
    });

    test('a good still is uploaded, listed first and selected', () async {
      final cubit = gallery();
      addTearDown(cubit.close);
      await cubit.load();

      final item = await cubit.add(fullHd.path);

      expect(repo.uploads.single, fullHd);
      expect(cubit.state.items.first, item);
      expect(cubit.state.selected, PictureBackground(item!.url));
      expect(cubit.state.adding, isA<NotAdding>());
    });

    test('a loop goes up with a still frame of itself', () async {
      final cubit = gallery();
      addTearDown(cubit.close);

      final item = await cubit.add(loop.path);

      expect(repo.posters.single, isNotNull);
      expect(cubit.state.selected, LoopBackground(item!.url, poster: item.posterUrl));
    });

    test('when the server refuses, its reason is shown', () async {
      repo.refuse = const ApiException('El plan Gratis tiene 500 MB', statusCode: 507);
      final cubit = gallery();
      addTearDown(cubit.close);

      await cubit.add(fullHd.path);

      expect(cubit.state.adding, const FailedBackground('El plan Gratis tiene 500 MB'));
    });

    test('removing the selected background unselects it', () async {
      const item = MediaItem(
        id: 'b1',
        name: 'cruz',
        url: 'https://media.test/cruz.jpg',
        storagePath: 'images/cruz.jpg',
        mediaType: MediaType.image,
        isBackground: true,
      );
      repo.backgrounds = [item];
      final cubit = gallery(initial: const PictureBackground('https://media.test/cruz.jpg'));
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.remove(item);

      expect(repo.deleted, ['b1']);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.selected, isNull);
    });
  });

  group('the gallery', () {
    Future<BackgroundGalleryCubit> pump(
      WidgetTester tester, {
      String? pick,
      BackgroundChoice? initial,
      void Function(BackgroundChoice?)? onClosed,
    }) async {
      await tester.binding.setSurfaceSize(kMinWindowSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cubit = gallery(initial: initial);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        localizedApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showDialog<BackgroundChoice>(
                  context: context,
                  builder: (_) => BlocProvider.value(
                    value: cubit..load(),
                    child: BackgroundGalleryDialog(animate: false, pickFile: () async => pick),
                  ),
                );
                onClosed?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return cubit;
    }

    testWidgets('fits the smallest window the app allows', (tester) async {
      await pump(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Bruma'), findsOneWidget);
      expect(find.text('Usar este fondo'), findsOneWidget);
    });

    testWidgets('nothing can be used until something is chosen', (tester) async {
      await pump(tester);

      final use = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Usar este fondo'));
      expect(use.onPressed, isNull);
    });

    testWidgets('a double click on a scene is the choice', (tester) async {
      BackgroundChoice? chosen;
      await pump(tester, onClosed: (c) => chosen = c);

      await tester.tap(find.text('Seda'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Seda'));
      await tester.pumpAndSettle();

      expect(chosen, const SceneBackground(MotionScene.silk));
    });

    testWidgets('a refused file says what is wrong and what the rules are', (tester) async {
      await pump(tester, pick: blink.path);

      await tester.tap(find.text('Agregar fondo'));
      await tester.pumpAndSettle();

      expect(find.text('«blink.mp4» no cumple los requisitos'), findsOneWidget);
      expect(find.textContaining('al menos 4 segundos'), findsOneWidget);
      expect(find.text('Requisitos para un fondo'), findsOneWidget);
      expect(repo.uploads, isEmpty);
    });

    testWidgets('the requirements can be read before trying anything', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Requisitos'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1920 × 1080 recomendado'), findsOneWidget);
      expect(find.textContaining('MP4, MOV o M4V'), findsOneWidget);
    });

    testWidgets('an added background appears marked, ready to use', (tester) async {
      BackgroundChoice? chosen;
      await pump(tester, pick: fullHd.path, onClosed: (c) => chosen = c);

      await tester.tap(find.text('Agregar fondo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este fondo'));
      await tester.pumpAndSettle();

      expect(find.text('cruz'), findsNothing, reason: 'closed');
      expect(chosen, isA<PictureBackground>());
    });
  });
}
