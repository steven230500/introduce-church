import 'package:flutter/widgets.dart';
import 'slide_layer.dart';

/// What a design's text sits on.
///
/// [motion] is one of the scenes the app draws itself; [video] is a loop the
/// church uploaded. Both move, and both are drawn behind the text rather than
/// swapped with it, so a new slide does not restart them.
enum BackgroundType { solid, gradient, image, motion, video }

enum TextVerticalAlign { top, center, bottom }

enum ReferencePosition { bottomRight, bottomCenter, bottomLeft }

enum SlideTransitionType { cut, fade, slideLeft, slideRight, zoomIn }

class SlideTemplate {
  const SlideTemplate({
    required this.id,
    required this.name,
    required this.bgType,
    required this.bgColor,
    this.bgGradientEnd = 0xFF000000,
    this.bgGradientAngle = 135.0,
    this.bgImagePath,
    this.bgMotion,
    this.bgVideoPath,
    this.bgPosterPath,
    this.bgOverlayOpacity = 0.45,
    required this.fontSize,
    required this.fontWeight,
    required this.textColor,
    required this.textAlign,
    required this.textValign,
    required this.paddingH,
    required this.paddingV,
    required this.textShadow,
    required this.showReference,
    required this.referenceFontSize,
    required this.referenceColor,
    required this.referencePosition,
    this.fontFamily,
    this.lineHeight = 1.5,
    this.transitionType = SlideTransitionType.fade,
    this.transitionDurationMs = 300,
    this.layers = const [],
  });

  final String id;
  final String name;

  final BackgroundType bgType;
  final int bgColor;
  final int bgGradientEnd;
  final double bgGradientAngle;
  // BackgroundType.image
  final String? bgImagePath;

  /// BackgroundType.motion: the id of the scene.
  final String? bgMotion;

  /// BackgroundType.video: the loop, and a still frame of it for the places
  /// that show a design without playing it.
  final String? bgVideoPath;
  final String? bgPosterPath;

  /// How much the background is darkened under the text, for every kind of
  /// background that is a picture rather than a colour.
  final double bgOverlayOpacity;

  final double fontSize;
  final int fontWeight;
  final int textColor;
  final TextAlign textAlign;
  final TextVerticalAlign textValign;
  final double paddingH;
  final double paddingV;
  final bool textShadow;

  final bool showReference;
  final double referenceFontSize;
  final int referenceColor;
  final ReferencePosition referencePosition;
  final String? fontFamily;
  final double lineHeight;
  final SlideTransitionType transitionType;
  final int transitionDurationMs;
  final List<SlideLayer> layers;

  /// Whether the background moves, and so has to be kept playing behind the
  /// text instead of being redrawn with each slide.
  bool get hasMovingBackground => switch (bgType) {
    BackgroundType.motion => bgMotion != null,
    BackgroundType.video => bgVideoPath != null,
    _ => false,
  };

  /// Two designs with the same value here look the same behind the text. The
  /// projector keeps a moving background running across slides for as long as
  /// this does not change.
  String get backgroundSignature => switch (bgType) {
    BackgroundType.solid => 'solid:$bgColor',
    BackgroundType.gradient => 'gradient:$bgColor:$bgGradientEnd:$bgGradientAngle',
    BackgroundType.image => 'image:$bgImagePath:$bgOverlayOpacity',
    BackgroundType.motion => 'motion:$bgMotion:$bgOverlayOpacity',
    BackgroundType.video => 'video:$bgVideoPath:$bgOverlayOpacity',
  };

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'bgType': bgType.name,
    'bgColor': bgColor,
    'bgGradientEnd': bgGradientEnd,
    'bgGradientAngle': bgGradientAngle,
    if (bgImagePath != null) 'bgImagePath': bgImagePath,
    if (bgMotion != null) 'bgMotion': bgMotion,
    if (bgVideoPath != null) 'bgVideoPath': bgVideoPath,
    if (bgPosterPath != null) 'bgPosterPath': bgPosterPath,
    'bgOverlayOpacity': bgOverlayOpacity,
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'textColor': textColor,
    'textAlign': textAlign.name,
    'textValign': textValign.name,
    'paddingH': paddingH,
    'paddingV': paddingV,
    'textShadow': textShadow,
    'showReference': showReference,
    'referenceFontSize': referenceFontSize,
    'referenceColor': referenceColor,
    'referencePosition': referencePosition.name,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (lineHeight != 1.5) 'lineHeight': lineHeight,
    if (transitionType != SlideTransitionType.fade) 'transitionType': transitionType.name,
    if (transitionDurationMs != 300) 'transitionDurationMs': transitionDurationMs,
    if (layers.isNotEmpty) 'layers': layers.map((l) => l.toJson()).toList(),
  };

  factory SlideTemplate.fromJson({
    required String id,
    required String name,
    required Map<String, dynamic> json,
  }) {
    return SlideTemplate(
      id: id,
      name: name,
      bgType: BackgroundType.values.firstWhere(
        (e) => e.name == json['bgType'],
        orElse: () => BackgroundType.solid,
      ),
      bgColor: (json['bgColor'] as num?)?.toInt() ?? _fallback.bgColor,
      bgGradientEnd: (json['bgGradientEnd'] as num? ?? 0xFF000000).toInt(),
      bgGradientAngle: (json['bgGradientAngle'] as num? ?? 135).toDouble(),
      bgImagePath: json['bgImagePath'] as String?,
      bgMotion: json['bgMotion'] as String?,
      bgVideoPath: json['bgVideoPath'] as String?,
      bgPosterPath: json['bgPosterPath'] as String?,
      bgOverlayOpacity: (json['bgOverlayOpacity'] as num? ?? 0.45).toDouble(),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? _fallback.fontSize,
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? _fallback.fontWeight,
      textColor: (json['textColor'] as num?)?.toInt() ?? _fallback.textColor,
      textAlign: TextAlign.values.firstWhere(
        (e) => e.name == json['textAlign'],
        orElse: () => TextAlign.center,
      ),
      textValign: TextVerticalAlign.values.firstWhere(
        (e) => e.name == json['textValign'],
        orElse: () => TextVerticalAlign.center,
      ),
      paddingH: (json['paddingH'] as num?)?.toDouble() ?? _fallback.paddingH,
      paddingV: (json['paddingV'] as num?)?.toDouble() ?? _fallback.paddingV,
      textShadow: json['textShadow'] as bool? ?? true,
      showReference: json['showReference'] as bool? ?? true,
      referenceFontSize:
          (json['referenceFontSize'] as num?)?.toDouble() ?? _fallback.referenceFontSize,
      referenceColor: (json['referenceColor'] as num?)?.toInt() ?? _fallback.referenceColor,
      referencePosition: ReferencePosition.values.firstWhere(
        (e) => e.name == json['referencePosition'],
        orElse: () => ReferencePosition.bottomRight,
      ),
      fontFamily: json['fontFamily'] as String?,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
      transitionType: SlideTransitionType.values.firstWhere(
        (e) => e.name == json['transitionType'],
        orElse: () => SlideTransitionType.fade,
      ),
      transitionDurationMs: (json['transitionDurationMs'] as num?)?.toInt() ?? 300,
      layers: _parseLayers(json['layers']),
    );
  }

  static const _unset = Object();

  SlideTemplate copyWith({
    String? id,
    String? name,
    BackgroundType? bgType,
    int? bgColor,
    int? bgGradientEnd,
    double? bgGradientAngle,
    Object? bgImagePath = _unset,
    Object? bgMotion = _unset,
    Object? bgVideoPath = _unset,
    Object? bgPosterPath = _unset,
    double? bgOverlayOpacity,
    double? fontSize,
    int? fontWeight,
    int? textColor,
    TextAlign? textAlign,
    TextVerticalAlign? textValign,
    double? paddingH,
    double? paddingV,
    bool? textShadow,
    bool? showReference,
    double? referenceFontSize,
    int? referenceColor,
    ReferencePosition? referencePosition,
    Object? fontFamily = _unset,
    double? lineHeight,
    SlideTransitionType? transitionType,
    int? transitionDurationMs,
    List<SlideLayer>? layers,
  }) {
    return SlideTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      bgType: bgType ?? this.bgType,
      bgColor: bgColor ?? this.bgColor,
      bgGradientEnd: bgGradientEnd ?? this.bgGradientEnd,
      bgGradientAngle: bgGradientAngle ?? this.bgGradientAngle,
      bgImagePath: bgImagePath == _unset ? this.bgImagePath : bgImagePath as String?,
      bgMotion: bgMotion == _unset ? this.bgMotion : bgMotion as String?,
      bgVideoPath: bgVideoPath == _unset ? this.bgVideoPath : bgVideoPath as String?,
      bgPosterPath: bgPosterPath == _unset ? this.bgPosterPath : bgPosterPath as String?,
      bgOverlayOpacity: bgOverlayOpacity ?? this.bgOverlayOpacity,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textColor: textColor ?? this.textColor,
      textAlign: textAlign ?? this.textAlign,
      textValign: textValign ?? this.textValign,
      paddingH: paddingH ?? this.paddingH,
      paddingV: paddingV ?? this.paddingV,
      textShadow: textShadow ?? this.textShadow,
      showReference: showReference ?? this.showReference,
      referenceFontSize: referenceFontSize ?? this.referenceFontSize,
      referenceColor: referenceColor ?? this.referenceColor,
      referencePosition: referencePosition ?? this.referencePosition,
      fontFamily: fontFamily == _unset ? this.fontFamily : fontFamily as String?,
      lineHeight: lineHeight ?? this.lineHeight,
      transitionType: transitionType ?? this.transitionType,
      transitionDurationMs: transitionDurationMs ?? this.transitionDurationMs,
      layers: layers ?? this.layers,
    );
  }

  // ── Presets ───────────────────────────────────────────────────────────────

  static const List<SlideTemplate> presets = [
    darkClassic,
    blueNight,
    lowerThird,
    light,
    mist,
    rays,
    silk,
  ];

  static SlideTemplate get defaultTemplate => darkClassic;

  /// Values used for any field a stored design is missing.
  ///
  /// A design row written by an older build, or by hand, must not be able to
  /// take down the presenter: the set list loads designs on every refresh, and
  /// one malformed row used to throw and blank the whole screen.
  static const SlideTemplate _fallback = darkClassic;

  static List<SlideLayer> _parseLayers(dynamic raw) {
    if (raw is! List) return const [];
    final layers = <SlideLayer>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        layers.add(SlideLayer.fromJson(entry));
      } catch (_) {
        // Skip the bad layer and keep the rest of the design.
      }
    }
    return layers;
  }

  static SlideTemplate? findPreset(String id) {
    try {
      return presets.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  static const SlideTemplate darkClassic = SlideTemplate(
    id: 'preset_dark_classic',
    name: 'Oscuro clásico',
    bgType: BackgroundType.solid,
    bgColor: 0xFF000000,
    fontSize: 52,
    fontWeight: 300,
    textColor: 0xFFFFFFFF,
    textAlign: TextAlign.center,
    textValign: TextVerticalAlign.center,
    paddingH: 100,
    paddingV: 80,
    textShadow: true,
    showReference: true,
    referenceFontSize: 15,
    referenceColor: 0xFFAAAAAA,
    referencePosition: ReferencePosition.bottomRight,
  );

  static const SlideTemplate blueNight = SlideTemplate(
    id: 'preset_blue_night',
    name: 'Azul noche',
    bgType: BackgroundType.gradient,
    bgColor: 0xFF0D0D2B,
    bgGradientEnd: 0xFF0F3460,
    bgGradientAngle: 135,
    fontSize: 52,
    fontWeight: 300,
    textColor: 0xFFFFFFFF,
    textAlign: TextAlign.center,
    textValign: TextVerticalAlign.center,
    paddingH: 100,
    paddingV: 80,
    textShadow: true,
    showReference: true,
    referenceFontSize: 15,
    referenceColor: 0xFF8899BB,
    referencePosition: ReferencePosition.bottomRight,
  );

  static const SlideTemplate lowerThird = SlideTemplate(
    id: 'preset_lower_third',
    name: 'Letras abajo',
    bgType: BackgroundType.solid,
    bgColor: 0xFF000000,
    fontSize: 46,
    fontWeight: 400,
    textColor: 0xFFFFFFFF,
    textAlign: TextAlign.center,
    textValign: TextVerticalAlign.bottom,
    paddingH: 80,
    paddingV: 60,
    textShadow: true,
    showReference: true,
    referenceFontSize: 14,
    referenceColor: 0xFF888888,
    referencePosition: ReferencePosition.bottomCenter,
  );

  static const SlideTemplate light = SlideTemplate(
    id: 'preset_light',
    name: 'Claro',
    bgType: BackgroundType.solid,
    bgColor: 0xFFF5F5F5,
    fontSize: 48,
    fontWeight: 400,
    textColor: 0xFF1A1A1A,
    textAlign: TextAlign.center,
    textValign: TextVerticalAlign.center,
    paddingH: 100,
    paddingV: 80,
    textShadow: false,
    showReference: true,
    referenceFontSize: 15,
    referenceColor: 0xFF666666,
    referencePosition: ReferencePosition.bottomRight,
  );

  // Moving backgrounds. The plain colour is the scene's own, which is what a
  // copy of the app from before scenes existed shows instead.

  static const SlideTemplate mist = SlideTemplate(
    id: 'preset_motion_mist',
    name: 'Bruma',
    bgType: BackgroundType.motion,
    bgMotion: 'mist',
    bgColor: 0xFF1D2733,
    bgOverlayOpacity: 0.1,
    fontSize: 54,
    fontWeight: 300,
    textColor: 0xFFFFFFFF,
    textAlign: TextAlign.center,
    textValign: TextVerticalAlign.center,
    paddingH: 110,
    paddingV: 80,
    textShadow: true,
    showReference: true,
    referenceFontSize: 15,
    referenceColor: 0xFFB8C6D6,
    referencePosition: ReferencePosition.bottomRight,
  );

  static const SlideTemplate rays = SlideTemplate(
    id: 'preset_motion_rays',
    name: 'Luz de lo alto',
    bgType: BackgroundType.motion,
    bgMotion: 'rays',
    bgColor: 0xFF1A1D2B,
    bgOverlayOpacity: 0.15,
    fontSize: 54,
    fontWeight: 300,
    textColor: 0xFFFFFFFF,
    textAlign: TextAlign.center,
    textValign: TextVerticalAlign.center,
    paddingH: 110,
    paddingV: 80,
    textShadow: true,
    showReference: true,
    referenceFontSize: 15,
    referenceColor: 0xFFD9D3C4,
    referencePosition: ReferencePosition.bottomCenter,
  );

  static const SlideTemplate silk = SlideTemplate(
    id: 'preset_motion_silk',
    name: 'Seda',
    bgType: BackgroundType.motion,
    bgMotion: 'silk',
    bgColor: 0xFF1A1233,
    bgOverlayOpacity: 0.2,
    fontSize: 50,
    fontWeight: 400,
    textColor: 0xFFFFFFFF,
    textAlign: TextAlign.center,
    textValign: TextVerticalAlign.top,
    paddingH: 110,
    paddingV: 90,
    textShadow: true,
    showReference: true,
    referenceFontSize: 15,
    referenceColor: 0xFFC9B8F0,
    referencePosition: ReferencePosition.bottomRight,
  );
}
