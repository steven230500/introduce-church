import '../../l10n/l10n.dart';
import 'motion_scenes.dart';

extension MotionSceneName on MotionScene {
  /// What the operator calls the scene, in their language.
  String label(L10n t) => switch (this) {
    MotionScene.aurora => t.sceneAurora,
    MotionScene.light => t.sceneLight,
    MotionScene.waves => t.sceneWaves,
    MotionScene.sunrise => t.sceneSunrise,
    MotionScene.stars => t.sceneStars,
    MotionScene.calm => t.sceneCalm,
    MotionScene.mist => t.sceneMist,
    MotionScene.rays => t.sceneRays,
    MotionScene.silk => t.sceneSilk,
  };
}
