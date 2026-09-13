import 'package:equatable/equatable.dart';

import '../utils/bytes.dart';

/// How much room the church has, and how much of it is gone.
///
/// Shown before an upload rather than after: finding out that a video does not
/// fit is fine, finding out four minutes into uploading it is not.
class StorageUsage extends Equatable {
  const StorageUsage({
    required this.plan,
    required this.label,
    required this.usedBytes,
    required this.totalBytes,
    required this.maxUploadBytes,
  });

  /// The plan's identifier: `free`, `iglesia`, `red`.
  final String plan;

  /// Its name in Spanish, as the API writes it.
  final String label;

  final int usedBytes;
  final int totalBytes;

  /// The largest single file this plan accepts.
  final int maxUploadBytes;

  factory StorageUsage.fromJson(Map<String, dynamic> j) => StorageUsage(
    plan: j['plan'] as String? ?? 'free',
    label: j['label'] as String? ?? 'Gratis',
    usedBytes: (j['used_bytes'] as num? ?? 0).toInt(),
    totalBytes: (j['total_bytes'] as num? ?? 0).toInt(),
    maxUploadBytes: (j['max_upload_bytes'] as num? ?? 0).toInt(),
  );

  double get fraction => totalBytes <= 0 ? 0 : (usedBytes / totalBytes).clamp(0.0, 1.0);

  /// Worth saying something about before the church runs into it mid-service.
  bool get nearlyFull => fraction >= 0.85;

  bool get full => usedBytes >= totalBytes;

  int get freeBytes => totalBytes - usedBytes < 0 ? 0 : totalBytes - usedBytes;

  String get summary => '${humanBytes(usedBytes)} de ${humanBytes(totalBytes)}';

  @override
  List<Object?> get props => [plan, usedBytes, totalBytes, maxUploadBytes];
}
