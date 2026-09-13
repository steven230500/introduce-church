import 'package:equatable/equatable.dart';

import '../utils/bytes.dart';

enum MediaType { image, video }

extension MediaTypeX on MediaType {
  String get value => name;
  bool get isImage => this == MediaType.image;
  bool get isVideo => this == MediaType.video;
  static MediaType fromString(String s) => s == 'video' ? MediaType.video : MediaType.image;
}

class MediaItem extends Equatable {
  const MediaItem({
    required this.id,
    required this.name,
    required this.url,
    required this.storagePath,
    required this.mediaType,
    this.orgId,
    this.userId,
    this.sizeBytes,
    this.createdAt,
    this.isBackground = false,
    this.width,
    this.height,
    this.durationMs,
    this.posterUrl,
  });

  final String id;
  final String name;
  final String url;
  final String storagePath;
  final MediaType mediaType;
  final String? orgId;
  final String? userId;
  final int? sizeBytes;
  final DateTime? createdAt;

  /// A file added to sit behind the text of a design, rather than to be put on
  /// the screen by itself.
  final bool isBackground;

  /// Recorded for backgrounds, which were checked against them.
  final int? width;
  final int? height;

  /// Null for a still.
  final int? durationMs;

  /// A still frame of a video background.
  final String? posterUrl;

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
    id: j['id'] as String,
    name: j['name'] as String,
    url: j['url'] as String,
    storagePath: j['storage_path'] as String,
    mediaType: MediaTypeX.fromString(j['media_type'] as String),
    orgId: j['org_id'] as String?,
    userId: j['user_id'] as String?,
    sizeBytes: j['size_bytes'] as int?,
    createdAt: j['created_at'] != null ? DateTime.parse(j['created_at'] as String) : null,
    isBackground: j['role'] == 'background',
    width: (j['width'] as num?)?.toInt(),
    height: (j['height'] as num?)?.toInt(),
    durationMs: (j['duration_ms'] as num?)?.toInt(),
    posterUrl: j['poster_url'] as String?,
  );

  String get sizeLabel => sizeBytes == null ? '' : humanBytes(sizeBytes!);

  @override
  List<Object?> get props => [id, name, url, mediaType, isBackground, posterUrl];
}
