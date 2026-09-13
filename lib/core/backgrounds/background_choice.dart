import 'package:equatable/equatable.dart';

import '../models/media_item.dart';
import '../models/slide_template.dart';
import '../motion/motion_scenes.dart';

/// A background picked in the gallery, before it is put on a design.
sealed class BackgroundChoice extends Equatable {
  const BackgroundChoice();

  /// Which choice a design has, so the gallery opens with it marked.
  ///
  /// A design on a plain colour may still remember the picture it had before;
  /// that one is marked, so going back to it is one click.
  static BackgroundChoice? of(SlideTemplate t) => switch (t.bgType) {
    BackgroundType.motion when MotionSceneX.knows(t.bgMotion) => SceneBackground(
      MotionSceneX.fromId(t.bgMotion),
    ),
    BackgroundType.image when t.bgImagePath != null => PictureBackground(t.bgImagePath!),
    BackgroundType.video when t.bgVideoPath != null => LoopBackground(
      t.bgVideoPath!,
      poster: t.bgPosterPath,
    ),
    _ when t.bgVideoPath != null => LoopBackground(t.bgVideoPath!, poster: t.bgPosterPath),
    _ when t.bgImagePath != null => PictureBackground(t.bgImagePath!),
    _ when MotionSceneX.knows(t.bgMotion) => SceneBackground(MotionSceneX.fromId(t.bgMotion)),
    _ => null,
  };

  /// The choice a church background in the library stands for.
  static BackgroundChoice fromItem(MediaItem item) => item.mediaType.isVideo
      ? LoopBackground(item.url, poster: item.posterUrl)
      : PictureBackground(item.url);
}

/// One of the scenes the app draws itself.
class SceneBackground extends BackgroundChoice {
  const SceneBackground(this.scene);
  final MotionScene scene;
  @override
  List<Object?> get props => [scene];
}

/// A still, from the church's backgrounds or from an older design.
class PictureBackground extends BackgroundChoice {
  const PictureBackground(this.source);
  final String source;
  @override
  List<Object?> get props => [source];
}

/// A church's video loop.
class LoopBackground extends BackgroundChoice {
  const LoopBackground(this.source, {this.poster});
  final String source;
  final String? poster;
  @override
  List<Object?> get props => [source, poster];
}

/// How dark a scene is made under text when a design first gets one.
///
/// Lighter than for a photo: the scenes are dark already, and were drawn to
/// have text over them.
const sceneOverlay = 0.2;

/// How dark a church's own picture or loop is made under text at first. Theirs
/// could be anything, including white, so it starts darker.
const pictureOverlay = 0.4;

/// [template] with [choice] behind its text.
///
/// The fields of the other kinds of background are left as they were, so an
/// operator who tries a scene and goes back to their photo finds the photo
/// still there, and one who goes back to a plain colour finds their colour. The darkness is only reset when the kind of picture changes:
/// a value tuned for this photo is kept for the next photo, but it means
/// nothing for a scene.
SlideTemplate applyBackground(SlideTemplate template, BackgroundChoice choice) {
  final wasScene = template.bgType == BackgroundType.motion;
  final wasPicture =
      template.bgType == BackgroundType.image || template.bgType == BackgroundType.video;
  return switch (choice) {
    SceneBackground(:final scene) => template.copyWith(
      bgType: BackgroundType.motion,
      bgMotion: scene.id,
      bgOverlayOpacity: wasScene ? null : sceneOverlay,
    ),
    PictureBackground(:final source) => template.copyWith(
      bgType: BackgroundType.image,
      bgImagePath: source,
      bgOverlayOpacity: wasPicture ? null : pictureOverlay,
    ),
    LoopBackground(:final source, :final poster) => template.copyWith(
      bgType: BackgroundType.video,
      bgVideoPath: source,
      bgPosterPath: poster,
      bgOverlayOpacity: wasPicture ? null : pictureOverlay,
    ),
  };
}
