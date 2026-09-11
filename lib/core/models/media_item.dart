import 'package:equatable/equatable.dart';

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
  );

  String get sizeLabel {
    if (sizeBytes == null) return '';
    final mb = sizeBytes! / (1024 * 1024);
    return mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(sizeBytes! / 1024).toStringAsFixed(0)} KB';
  }

  @override
  List<Object?> get props => [id, name, url, mediaType];
}
