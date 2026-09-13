import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// What a file has to be before a church can keep it as a background.
///
/// Every rule is here because breaking it shows on the wall. Too small and the
/// lyrics sit on a blur; the wrong shape and the picture is cropped or
/// letterboxed; too heavy and the computer running the service stutters, or
/// the upload never finishes on the church wifi; too short a loop and its
/// restart is seen every few seconds.
///
/// The server holds uploads to the same rules and is the check that cannot be
/// skipped. This one runs first so the operator hears about a problem before
/// waiting on a transfer. Keep the numbers in step with
/// internal/media/standard.go in introduce-api.
abstract final class BackgroundStandard {
  /// 720p is the least that still looks sharp behind text on a 1080p
  /// projector.
  static const minWidth = 1280;
  static const minHeight = 720;

  /// What to export at, when the operator is making one.
  static const recommendedWidth = 1920;
  static const recommendedHeight = 1080;

  /// 4K. Past it a video is decoded at a size no church projector shows. Only
  /// video is held to it: a still is scaled down on upload.
  static const maxVideoWidth = 3840;
  static const maxVideoHeight = 2160;

  /// From 16:10, the WXGA projectors still in half the churches, to a little
  /// past 16:9, which absorbs 1366 × 768 and encoder rounding.
  static const minAspect = 1.6;
  static const maxAspect = 1.8;

  static const maxImageBytes = 20 * 1024 * 1024;
  static const maxVideoBytes = 250 * 1024 * 1024;

  static const minLoop = Duration(seconds: 4);
  static const maxLoop = Duration(minutes: 3);

  static const imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const videoExtensions = ['mp4', 'mov', 'm4v'];

  static List<String> get allExtensions => [...imageExtensions, ...videoExtensions];

  /// Whether a path is a still or a loop, by its extension, or null when it is
  /// neither.
  static BackgroundKind? kindOf(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (imageExtensions.contains(ext)) return BackgroundKind.image;
    if (videoExtensions.contains(ext)) return BackgroundKind.video;
    return null;
  }
}

enum BackgroundKind { image, video }

/// What is known about a file offered as a background.
class BackgroundCandidate extends Equatable {
  const BackgroundCandidate({
    required this.path,
    required this.bytes,
    this.width,
    this.height,
    this.duration,
  });

  final String path;
  final int bytes;

  /// Null when the file could not be read.
  final int? width;
  final int? height;

  /// Null for a still, and for a video whose length could not be read.
  final Duration? duration;

  BackgroundKind? get kind => BackgroundStandard.kindOf(path);

  @override
  List<Object?> get props => [path, bytes, width, height, duration];
}

/// One rule a candidate breaks, with the numbers the message needs.
sealed class BackgroundProblem extends Equatable {
  const BackgroundProblem();
}

class UnsupportedFormat extends BackgroundProblem {
  const UnsupportedFormat(this.filename);
  final String filename;
  @override
  List<Object?> get props => [filename];
}

class UnreadableFile extends BackgroundProblem {
  const UnreadableFile();
  @override
  List<Object?> get props => [];
}

class TooSmall extends BackgroundProblem {
  const TooSmall(this.width, this.height);
  final int width;
  final int height;
  @override
  List<Object?> get props => [width, height];
}

class TooLarge extends BackgroundProblem {
  const TooLarge(this.width, this.height);
  final int width;
  final int height;
  @override
  List<Object?> get props => [width, height];
}

class WrongShape extends BackgroundProblem {
  const WrongShape(this.width, this.height);
  final int width;
  final int height;
  double get aspect => width / height;
  @override
  List<Object?> get props => [width, height];
}

class TooHeavy extends BackgroundProblem {
  const TooHeavy(this.bytes, this.limit);
  final int bytes;
  final int limit;
  @override
  List<Object?> get props => [bytes, limit];
}

class UnknownLength extends BackgroundProblem {
  const UnknownLength();
  @override
  List<Object?> get props => [];
}

class TooShort extends BackgroundProblem {
  const TooShort(this.duration);
  final Duration duration;
  @override
  List<Object?> get props => [duration];
}

class TooLong extends BackgroundProblem {
  const TooLong(this.duration);
  final Duration duration;
  @override
  List<Object?> get props => [duration];
}

/// Every rule [candidate] breaks, or nothing when it meets the standard.
///
/// All of them at once: fixing one problem only to be told about the next is a
/// second trip to the video editor.
List<BackgroundProblem> checkBackground(BackgroundCandidate candidate) {
  final kind = candidate.kind;
  if (kind == null) return [UnsupportedFormat(p.basename(candidate.path))];

  final width = candidate.width;
  final height = candidate.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return const [UnreadableFile()];
  }

  final problems = <BackgroundProblem>[];
  if (width < BackgroundStandard.minWidth || height < BackgroundStandard.minHeight) {
    problems.add(TooSmall(width, height));
  }
  if (kind == BackgroundKind.video &&
      (width > BackgroundStandard.maxVideoWidth || height > BackgroundStandard.maxVideoHeight)) {
    problems.add(TooLarge(width, height));
  }
  final aspect = width / height;
  if (aspect < BackgroundStandard.minAspect || aspect > BackgroundStandard.maxAspect) {
    problems.add(WrongShape(width, height));
  }

  final limit = kind == BackgroundKind.video
      ? BackgroundStandard.maxVideoBytes
      : BackgroundStandard.maxImageBytes;
  if (candidate.bytes > limit) problems.add(TooHeavy(candidate.bytes, limit));

  if (kind == BackgroundKind.video) {
    final duration = candidate.duration;
    if (duration == null || duration <= Duration.zero) {
      problems.add(const UnknownLength());
    } else if (duration < BackgroundStandard.minLoop) {
      problems.add(TooShort(duration));
    } else if (duration > BackgroundStandard.maxLoop) {
      problems.add(TooLong(duration));
    }
  }
  return problems;
}
