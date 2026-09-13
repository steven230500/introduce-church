import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/backgrounds/background_choice.dart';
import 'package:introduce_church/core/models/media_item.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/motion/motion_scenes.dart';

void main() {
  const base = SlideTemplate.darkClassic;

  group('putting a background on a design', () {
    test('a scene makes the design move', () {
      final t = applyBackground(base, const SceneBackground(MotionScene.silk));

      expect(t.bgType, BackgroundType.motion);
      expect(t.bgMotion, 'silk');
      expect(t.hasMovingBackground, isTrue);
      expect(t.bgOverlayOpacity, sceneOverlay, reason: 'the photo darkness means nothing here');
    });

    test('a loop keeps its still frame for the places that do not play it', () {
      final t = applyBackground(
        base,
        const LoopBackground('https://x/olas.mp4', poster: 'https://x/olas.jpg'),
      );

      expect(t.bgType, BackgroundType.video);
      expect(t.bgVideoPath, 'https://x/olas.mp4');
      expect(t.bgPosterPath, 'https://x/olas.jpg');
      expect(t.hasMovingBackground, isTrue);
    });

    test('trying a scene and going back leaves the photo and the colour where they were', () {
      final photo = applyBackground(
        base.copyWith(bgColor: 0xFF123456),
        const PictureBackground('https://x/cruz.jpg'),
      ).copyWith(bgOverlayOpacity: 0.6);

      final scene = applyBackground(photo, const SceneBackground(MotionScene.mist));
      final back = applyBackground(scene, const PictureBackground('https://x/cruz.jpg'));

      expect(scene.bgColor, 0xFF123456);
      expect(back.bgImagePath, 'https://x/cruz.jpg');
      expect(scene.copyWith(bgType: BackgroundType.solid).bgColor, 0xFF123456);
    });

    test('a darkness tuned for one photo carries to the next photo', () {
      final first = applyBackground(
        base,
        const PictureBackground('a.jpg'),
      ).copyWith(bgOverlayOpacity: 0.7);
      final second = applyBackground(first, const PictureBackground('b.jpg'));

      expect(second.bgOverlayOpacity, 0.7);
    });
  });

  group('which background the gallery opens on', () {
    test('the one the design has', () {
      final t = applyBackground(base, const SceneBackground(MotionScene.rays));
      expect(BackgroundChoice.of(t), const SceneBackground(MotionScene.rays));
    });

    test('a design back on a colour still points at the picture it had', () {
      final t = applyBackground(
        base,
        const PictureBackground('https://x/cruz.jpg'),
      ).copyWith(bgType: BackgroundType.solid);
      expect(BackgroundChoice.of(t), const PictureBackground('https://x/cruz.jpg'));
    });

    test('a church background stands for a picture or a loop by its kind', () {
      const loop = MediaItem(
        id: '1',
        name: 'olas',
        url: 'https://x/olas.mp4',
        storagePath: 'videos/olas.mp4',
        mediaType: MediaType.video,
        posterUrl: 'https://x/olas.jpg',
      );
      expect(
        BackgroundChoice.fromItem(loop),
        const LoopBackground('https://x/olas.mp4', poster: 'https://x/olas.jpg'),
      );
    });
  });

  group('a moving design travels', () {
    test('the scene and the loop survive being stored', () {
      final scene = applyBackground(base, const SceneBackground(MotionScene.mist));
      final loop = applyBackground(base, const LoopBackground('v.mp4', poster: 'p.jpg'));

      for (final t in [scene, loop]) {
        final back = SlideTemplate.fromJson(id: 'x', name: 'x', json: t.toJson());
        expect(back.bgType, t.bgType);
        expect(back.bgMotion, t.bgMotion);
        expect(back.bgVideoPath, t.bgVideoPath);
        expect(back.bgPosterPath, t.bgPosterPath);
        expect(back.backgroundSignature, t.backgroundSignature);
      }
    });

    test('a kind of background from a newer app reads as its plain colour', () {
      final t = SlideTemplate.fromJson(
        id: 'x',
        name: 'x',
        json: {'bgType': 'hologram', 'bgColor': 0xFF223344},
      );
      expect(t.bgType, BackgroundType.solid);
      expect(t.bgColor, 0xFF223344);
    });

    test('the projector keeps the background running while only the words change', () {
      final t = applyBackground(base, const SceneBackground(MotionScene.silk));
      expect(
        t.copyWith(fontSize: 80, textColor: 0xFFFFD700).backgroundSignature,
        t.backgroundSignature,
      );
      expect(t.copyWith(bgOverlayOpacity: 0.5).backgroundSignature, isNot(t.backgroundSignature));
    });

    test('the built-in moving designs draw scenes this version knows', () {
      final moving = SlideTemplate.presets.where((p) => p.bgType == BackgroundType.motion);
      expect(moving, isNotEmpty);
      for (final preset in moving) {
        expect(MotionSceneX.knows(preset.bgMotion), isTrue, reason: preset.id);
        expect(SlideTemplate.findPreset(preset.id), same(preset));
      }
    });
  });
}
