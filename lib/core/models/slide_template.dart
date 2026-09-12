import 'package:flutter/widgets.dart';
import 'slide_layer.dart';

enum BackgroundType { solid, gradient, image }

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

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'bgType': bgType.name,
    'bgColor': bgColor,
    'bgGradientEnd': bgGradientEnd,
    'bgGradientAngle': bgGradientAngle,
    if (bgImagePath != null) 'bgImagePath': bgImagePath,
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

  static const List<SlideTemplate> presets = [darkClassic, blueNight, lowerThird, light];

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
}
