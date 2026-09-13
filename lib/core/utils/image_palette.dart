import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// What a photo is made of: the colours worth offering, and the one colour
/// that stands for the whole thing.
typedef PhotoColors = ({List<int> palette, int average});

/// The colours actually present in an RGBA buffer.
///
/// A church drops in a photo of a sunrise and then hunts through twenty
/// built-in swatches for the orange that is already in the picture. These are
/// that orange: the colours the photo itself is made of, most common first.
///
/// Pixels are dropped into a coarse grid and the busiest cells win, each
/// reported as the mean of the pixels that landed in it, so the swatch is a
/// colour the photo really has and not the corner of a bucket.
PhotoColors photoColorsFrom(Uint8List rgba, {int most = 6}) {
  // Six steps per channel: fine enough that a sky and a sea do not share a
  // cell, coarse enough that a gradient does not become forty swatches.
  const steps = 6;
  final sumR = List<int>.filled(steps * steps * steps, 0);
  final sumG = List<int>.filled(steps * steps * steps, 0);
  final sumB = List<int>.filled(steps * steps * steps, 0);
  final count = List<int>.filled(steps * steps * steps, 0);

  var total = 0;
  var allR = 0, allG = 0, allB = 0;

  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue; // See-through pixels are not a colour.
    final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
    final cell =
        (r * steps ~/ 256) * steps * steps + (g * steps ~/ 256) * steps + (b * steps ~/ 256);
    sumR[cell] += r;
    sumG[cell] += g;
    sumB[cell] += b;
    count[cell]++;
    allR += r;
    allG += g;
    allB += b;
    total++;
  }

  if (total == 0) return (palette: const <int>[], average: 0xFF000000);

  final busiest = [
    for (var cell = 0; cell < count.length; cell++)
      if (count[cell] > 0) cell,
  ]..sort((a, b) => count[b].compareTo(count[a]));

  final palette = <int>[];
  for (final cell in busiest) {
    // A cell that holds a handful of pixels is a stray highlight, not a colour
    // the photo reads as.
    if (count[cell] * 100 < total) continue;
    final colour = _argb(
      sumR[cell] ~/ count[cell],
      sumG[cell] ~/ count[cell],
      sumB[cell] ~/ count[cell],
    );
    if (palette.any((kept) => _close(kept, colour))) continue;
    palette.add(colour);
    if (palette.length == most) break;
  }

  return (palette: palette, average: _argb(allR ~/ total, allG ~/ total, allB ~/ total));
}

/// What the text will really sit on once the darkening layer is over the photo.
///
/// The slide paints black at [overlayOpacity] on top of the picture, so a
/// readability verdict taken against the bare photo is wrong by exactly that
/// much: a pale photo under a heavy overlay takes white text perfectly well.
int backdropUnderOverlay(int photo, double overlayOpacity) {
  final keep = 1 - overlayOpacity.clamp(0.0, 1.0);
  return _argb(
    ((photo >> 16 & 0xFF) * keep).round(),
    ((photo >> 8 & 0xFF) * keep).round(),
    ((photo & 0xFF) * keep).round(),
  );
}

/// Reads a photo off disk or off the network and boils it down.
///
/// Decoded at [width] pixels across: nobody needs four megapixels to learn
/// that a picture is mostly blue, and a service starting in ten minutes should
/// not wait for it.
Future<PhotoColors?> readPhotoColors(String path, {int width = 64}) async {
  try {
    final bytes = await _bytesOf(path);
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
    final frame = await codec.getNextFrame();
    final raw = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    codec.dispose();
    if (raw == null) return null;
    return photoColorsFrom(raw.buffer.asUint8List());
  } catch (_) {
    // A missing file or a dead link costs the swatches, nothing else.
    return null;
  }
}

Future<Uint8List?> _bytesOf(String path) async {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final response = await (await client.getUrl(Uri.parse(path))).close();
      if (response.statusCode != 200) return null;
      final chunks = await response.toList();
      return Uint8List.fromList([for (final chunk in chunks) ...chunk]);
    } finally {
      client.close(force: true);
    }
  }
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

int _argb(int r, int g, int b) => 0xFF000000 | (r << 16) | (g << 8) | b;

/// Two swatches this near each other are the same swatch to the eye, and the
/// second one only makes the row longer.
bool _close(int a, int b) {
  final dr = (a >> 16 & 0xFF) - (b >> 16 & 0xFF);
  final dg = (a >> 8 & 0xFF) - (b >> 8 & 0xFF);
  final db = (a & 0xFF) - (b & 0xFF);
  return dr * dr + dg * dg + db * db < 60 * 60;
}
