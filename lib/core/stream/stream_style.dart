import 'dart:ui';

import 'package:equatable/equatable.dart';

/// The flat colour behind the words, which the streaming software removes.
///
/// Green is what OBS and every other keyer expect by default. Blue is for a
/// church whose worship team wears green. Magenta almost never appears in a
/// camera shot. Black is for a luma key, or for putting the window on a
/// second screen as it is.
enum StreamKey { green, blue, magenta, black }

extension StreamKeyColor on StreamKey {
  Color get color => switch (this) {
    StreamKey.green => const Color(0xFF00B140),
    StreamKey.blue => const Color(0xFF0047BB),
    StreamKey.magenta => const Color(0xFFFF00FF),
    StreamKey.black => const Color(0xFF000000),
  };
}

enum StreamPosition { bottom, top }

/// How the words look in the streaming window.
///
/// Kept per computer, not per church: it follows the capture setup of the
/// machine running the stream, not the design of the service.
class StreamStyle extends Equatable {
  const StreamStyle({
    this.key = StreamKey.green,
    this.position = StreamPosition.bottom,
    this.bar = true,
    this.scale = 1.0,
    this.showReference = true,
  });

  final StreamKey key;
  final StreamPosition position;

  /// A solid dark band behind the words. Solid on purpose: anything
  /// see-through mixes with the key colour, and the keyer then cuts holes in it.
  final bool bar;

  /// Text size relative to the default, from [minScale] to [maxScale].
  final double scale;

  final bool showReference;

  static const minScale = 0.6;
  static const maxScale = 1.6;

  StreamStyle copyWith({
    StreamKey? key,
    StreamPosition? position,
    bool? bar,
    double? scale,
    bool? showReference,
  }) => StreamStyle(
    key: key ?? this.key,
    position: position ?? this.position,
    bar: bar ?? this.bar,
    scale: scale ?? this.scale,
    showReference: showReference ?? this.showReference,
  );

  Map<String, dynamic> toJson() => {
    'key': key.name,
    'position': position.name,
    'bar': bar,
    'scale': scale,
    'reference': showReference,
  };

  /// Reads what was saved or sent. Anything missing or unknown takes its
  /// default, so a style from another version of the app still gives a
  /// working window rather than none.
  static StreamStyle fromJson(Object? raw) {
    if (raw is! Map) return const StreamStyle();
    return StreamStyle(
      key: StreamKey.values.where((k) => k.name == raw['key']).firstOrNull ?? StreamKey.green,
      position:
          StreamPosition.values.where((p) => p.name == raw['position']).firstOrNull ??
          StreamPosition.bottom,
      bar: raw['bar'] is bool ? raw['bar'] as bool : true,
      scale: ((raw['scale'] as num?)?.toDouble() ?? 1.0).clamp(minScale, maxScale),
      showReference: raw['reference'] is bool ? raw['reference'] as bool : true,
    );
  }

  @override
  List<Object?> get props => [key, position, bar, scale, showReference];
}
