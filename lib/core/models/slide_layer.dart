import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

String newLayerId() {
  final rng = math.Random();
  return List.generate(12, (_) => rng.nextInt(16).toRadixString(16)).join();
}

sealed class SlideLayer extends Equatable {
  const SlideLayer({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
  });

  final String id;
  final double x; // fraction 0.0–1.0 of slide width
  final double y; // fraction 0.0–1.0 of slide height
  final double width; // fraction 0.0–1.0
  final double height; // fraction 0.0–1.0
  final int zIndex;

  String get typeName;
  SlideLayer copyWithGeometry({double? x, double? y, double? width, double? height});
  SlideLayer copyWithZIndex(int z);
  Map<String, dynamic> toJson();

  static SlideLayer fromJson(Map<String, dynamic> j) => switch (j['type'] as String) {
    'text' => TextSlideLayer.fromJson(j),
    'reference' => ReferenceSlideLayer.fromJson(j),
    _ => throw ArgumentError('Unknown layer type: ${j['type']}'),
  };

  static List<SlideLayer> defaultLayers() => [
    TextSlideLayer(
      id: newLayerId(),
      x: 0.05,
      y: 0.08,
      width: 0.90,
      height: 0.72,
      zIndex: 0,
      fontSize: 52,
      fontWeight: 300,
      textColor: 0xFFFFFFFF,
      textAlign: TextAlign.center,
      textShadow: true,
    ),
    ReferenceSlideLayer(
      id: newLayerId(),
      x: 0.05,
      y: 0.87,
      width: 0.90,
      height: 0.09,
      zIndex: 1,
      fontSize: 15,
      textColor: 0xFFAAAAAA,
      textAlign: TextAlign.right,
    ),
  ];
}

// ── Text layer ────────────────────────────────────────────────────────────────

class TextSlideLayer extends SlideLayer {
  const TextSlideLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.zIndex,
    required this.fontSize,
    required this.fontWeight,
    required this.textColor,
    required this.textAlign,
    required this.textShadow,
    this.fontFamily,
    this.lineHeight = 1.5,
  });

  final double fontSize;
  final int fontWeight;
  final int textColor;
  final TextAlign textAlign;
  final bool textShadow;
  final String? fontFamily;
  final double lineHeight;

  @override
  String get typeName => 'Texto';

  static const _unset = Object();

  TextSlideLayer copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    double? fontSize,
    int? fontWeight,
    int? textColor,
    TextAlign? textAlign,
    bool? textShadow,
    Object? fontFamily = _unset,
    double? lineHeight,
  }) => TextSlideLayer(
    id: id ?? this.id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    zIndex: zIndex ?? this.zIndex,
    fontSize: fontSize ?? this.fontSize,
    fontWeight: fontWeight ?? this.fontWeight,
    textColor: textColor ?? this.textColor,
    textAlign: textAlign ?? this.textAlign,
    textShadow: textShadow ?? this.textShadow,
    fontFamily: fontFamily == _unset ? this.fontFamily : fontFamily as String?,
    lineHeight: lineHeight ?? this.lineHeight,
  );

  @override
  TextSlideLayer copyWithGeometry({double? x, double? y, double? width, double? height}) =>
      copyWith(x: x, y: y, width: width, height: height);

  @override
  TextSlideLayer copyWithZIndex(int z) => copyWith(zIndex: z);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'text',
    'id': id,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'zIndex': zIndex,
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'textColor': textColor,
    'textAlign': textAlign.name,
    'textShadow': textShadow,
    if (fontFamily != null) 'fontFamily': fontFamily,
    if (lineHeight != 1.5) 'lineHeight': lineHeight,
  };

  factory TextSlideLayer.fromJson(Map<String, dynamic> j) => TextSlideLayer(
    id: j['id'] as String,
    zIndex: (j['zIndex'] as num).toInt(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    width: (j['width'] as num).toDouble(),
    height: (j['height'] as num).toDouble(),
    fontSize: (j['fontSize'] as num).toDouble(),
    fontWeight: (j['fontWeight'] as num).toInt(),
    textColor: (j['textColor'] as num).toInt(),
    textAlign: TextAlign.values.firstWhere(
      (e) => e.name == j['textAlign'],
      orElse: () => TextAlign.center,
    ),
    textShadow: j['textShadow'] as bool? ?? true,
    fontFamily: j['fontFamily'] as String?,
    lineHeight: (j['lineHeight'] as num?)?.toDouble() ?? 1.5,
  );

  @override
  List<Object?> get props => [
    id,
    x,
    y,
    width,
    height,
    zIndex,
    fontSize,
    fontWeight,
    textColor,
    textAlign,
    textShadow,
    fontFamily,
    lineHeight,
  ];
}

// ── Reference layer ───────────────────────────────────────────────────────────

class ReferenceSlideLayer extends SlideLayer {
  const ReferenceSlideLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.zIndex,
    required this.fontSize,
    required this.textColor,
    required this.textAlign,
    this.fontFamily,
  });

  final double fontSize;
  final int textColor;
  final TextAlign textAlign;
  final String? fontFamily;

  @override
  String get typeName => 'Referencia';

  static const _unset = Object();

  ReferenceSlideLayer copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    int? zIndex,
    double? fontSize,
    int? textColor,
    TextAlign? textAlign,
    Object? fontFamily = _unset,
  }) => ReferenceSlideLayer(
    id: id ?? this.id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    zIndex: zIndex ?? this.zIndex,
    fontSize: fontSize ?? this.fontSize,
    textColor: textColor ?? this.textColor,
    textAlign: textAlign ?? this.textAlign,
    fontFamily: fontFamily == _unset ? this.fontFamily : fontFamily as String?,
  );

  @override
  ReferenceSlideLayer copyWithGeometry({double? x, double? y, double? width, double? height}) =>
      copyWith(x: x, y: y, width: width, height: height);

  @override
  ReferenceSlideLayer copyWithZIndex(int z) => copyWith(zIndex: z);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'reference',
    'id': id,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'zIndex': zIndex,
    'fontSize': fontSize,
    'textColor': textColor,
    'textAlign': textAlign.name,
    if (fontFamily != null) 'fontFamily': fontFamily,
  };

  factory ReferenceSlideLayer.fromJson(Map<String, dynamic> j) => ReferenceSlideLayer(
    id: j['id'] as String,
    zIndex: (j['zIndex'] as num).toInt(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    width: (j['width'] as num).toDouble(),
    height: (j['height'] as num).toDouble(),
    fontSize: (j['fontSize'] as num).toDouble(),
    textColor: (j['textColor'] as num).toInt(),
    textAlign: TextAlign.values.firstWhere(
      (e) => e.name == j['textAlign'],
      orElse: () => TextAlign.right,
    ),
    fontFamily: j['fontFamily'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    x,
    y,
    width,
    height,
    zIndex,
    fontSize,
    textColor,
    textAlign,
    fontFamily,
  ];
}
