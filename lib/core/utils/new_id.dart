import 'dart:math';

final _random = Random.secure();

/// A random (version 4) UUID, for a row the app creates itself.
///
/// The app names new services and items rather than waiting for the server to:
/// made with no network, everything done to them afterwards has to point at
/// an id that already exists, and the server keeps the one it is given.
String newId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
