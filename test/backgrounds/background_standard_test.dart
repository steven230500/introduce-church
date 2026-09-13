import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/backgrounds/background_standard.dart';

// The same cases as TestBackgroundStandard in introduce-api. If one side
// changes a number and the other does not, the app waves through a file the
// server refuses, or refuses one the server would keep.
void main() {
  BackgroundCandidate good(String path) => BackgroundCandidate(
    path: path,
    bytes: 4 << 20,
    width: 1920,
    height: 1080,
    duration: BackgroundStandard.kindOf(path) == BackgroundKind.video
        ? const Duration(seconds: 30)
        : null,
  );

  BackgroundCandidate change(
    BackgroundCandidate c, {
    String? path,
    int? bytes,
    int? width,
    int? height,
    Duration? duration,
    bool noDuration = false,
    bool noSize = false,
  }) => BackgroundCandidate(
    path: path ?? c.path,
    bytes: bytes ?? c.bytes,
    width: noSize ? null : width ?? c.width,
    height: noSize ? null : height ?? c.height,
    duration: noDuration ? null : duration ?? c.duration,
  );

  test('a Full HD file of every accepted kind meets the standard', () {
    for (final name in [
      'cruz.jpg',
      'CRUZ.JPEG',
      'luz.png',
      'cielo.webp',
      'a.mp4',
      'a.MOV',
      'a.m4v',
    ]) {
      expect(checkBackground(good('/tmp/$name')), isEmpty, reason: name);
    }
  });

  test('the shapes churches actually have are accepted', () {
    for (final (w, h) in [(1280, 800), (1366, 768), (1280, 720), (3840, 2160)]) {
      expect(
        checkBackground(change(good('a.mp4'), width: w, height: h)),
        isEmpty,
        reason: '$w×$h',
      );
    }
  });

  test('each broken rule is named', () {
    final loop = good('a.mp4');
    expect(checkBackground(change(loop, path: 'letra.pdf')).single, isA<UnsupportedFormat>());
    expect(checkBackground(change(loop, width: 1024, height: 576)), contains(isA<TooSmall>()));
    for (final (w, h) in [(1080, 1920), (2000, 2000), (1600, 1200), (2560, 1080)]) {
      expect(
        checkBackground(change(loop, width: w, height: h)),
        contains(isA<WrongShape>()),
        reason: '$w×$h',
      );
    }
    expect(
      checkBackground(change(good('foto.jpg'), bytes: 30 << 20)).single,
      const TooHeavy(30 << 20, BackgroundStandard.maxImageBytes),
    );
    expect(checkBackground(change(loop, bytes: 300 << 20)).single, isA<TooHeavy>());
    expect(checkBackground(change(loop, width: 7680, height: 4320)).single, isA<TooLarge>());
    expect(
      checkBackground(change(loop, duration: const Duration(seconds: 2))).single,
      isA<TooShort>(),
    );
    expect(
      checkBackground(change(loop, duration: const Duration(minutes: 20))).single,
      isA<TooLong>(),
    );
    expect(checkBackground(change(loop, noDuration: true)).single, isA<UnknownLength>());
    expect(checkBackground(change(loop, noSize: true)).single, isA<UnreadableFile>());
  });

  test('a large photo is fine, because it is scaled down on upload', () {
    expect(checkBackground(change(good('foto.jpg'), width: 6000, height: 3375)), isEmpty);
  });

  test('everything wrong is said at once', () {
    const bad = BackgroundCandidate(
      path: 'x.mp4',
      bytes: 900 << 20,
      width: 640,
      height: 640,
      duration: Duration(seconds: 1),
    );
    expect(checkBackground(bad), hasLength(4));
  });
}
