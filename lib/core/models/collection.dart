import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'collection_item_type.dart';
import 'song.dart';

Map<String, dynamic>? _parseContentJson(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
  return null;
}

class CollectionItem extends Equatable {
  const CollectionItem({
    required this.id,
    required this.collectionId,
    required this.type,
    required this.order,
    this.song,
    this.templateId,
    this.contentJson,
    this.notes,
    this.autoAdvanceSecs,
  });

  final String id;
  final String collectionId;
  final CollectionItemType type;
  final int order;
  final Song? song;
  final String? templateId;
  final Map<String, dynamic>? contentJson;
  final String? notes;
  final int? autoAdvanceSecs;

  // Slides a proyectar según el tipo
  List<String> get slides => switch (type) {
    CollectionItemType.song => song?.slides ?? [],
    CollectionItemType.bibleVerse => _bibleSlides,
    CollectionItemType.sermon => _sermonSlides,
    CollectionItemType.freeSlide => [contentJson?['text'] as String? ?? ''],
    CollectionItemType.imageSlide => List<String>.from(contentJson?['paths'] as List? ?? []),
    CollectionItemType.videoSlide => [contentJson?['path'] as String? ?? ''],
    CollectionItemType.announcement => [contentJson?['message'] as String? ?? ''],
  };

  String get displayTitle => switch (type) {
    CollectionItemType.song => song?.title ?? '',
    CollectionItemType.bibleVerse => () {
      final book = contentJson?['book'] ?? '';
      final ch = contentJson?['chapter'] ?? '';
      final v = contentJson?['verse'] ?? '';
      final vEnd = contentJson?['verseEnd'];
      return vEnd != null && vEnd != v ? '$book $ch:$v-$vEnd' : '$book $ch:$v';
    }(),
    CollectionItemType.sermon => contentJson?['title'] as String? ?? 'Prédica',
    CollectionItemType.freeSlide =>
      contentJson?['title'] as String? ??
          (contentJson?['text'] as String? ?? 'Slide').split('\n').first,
    CollectionItemType.imageSlide => contentJson?['title'] as String? ?? 'Presentación',
    CollectionItemType.videoSlide => contentJson?['title'] as String? ?? 'Video',
    CollectionItemType.announcement => contentJson?['title'] as String? ?? 'Anuncio',
  };

  String get displaySubtitle => switch (type) {
    CollectionItemType.song => song?.author ?? '',
    CollectionItemType.bibleVerse => contentJson?['version'] as String? ?? '',
    CollectionItemType.sermon => '${(_sermonSlides.length)} puntos',
    CollectionItemType.freeSlide => '',
    // No slide count here: every row that shows a subtitle already shows one,
    // and this type is the only one that used to say it twice.
    CollectionItemType.imageSlide => '',
    CollectionItemType.videoSlide => contentJson?['duration'] as String? ?? '',
    CollectionItemType.announcement =>
      contentJson?['timerTarget'] != null ? 'Con cuenta regresiva' : '',
  };

  // Labels por slide para grid view (Verso, Coro, Puente, Slide N, etc.)
  List<String> get slideLabels => switch (type) {
    CollectionItemType.song => _songLabels,
    CollectionItemType.bibleVerse => _bibleSlideRefs,
    CollectionItemType.imageSlide => List.generate(slides.length, (i) => 'Slide ${i + 1}'),
    CollectionItemType.videoSlide => ['Video'],
    CollectionItemType.sermon => _sermonLabels,
    _ => List.filled(slides.length, ''),
  };

  List<String> get _songLabels {
    if (song == null) return [];
    final typeCount = <String, int>{};
    return song!.verses.map((v) {
      final base = v.type.label;
      typeCount[base] = (typeCount[base] ?? 0) + 1;
      final n = typeCount[base]!;
      return n == 1 ? base : '$base ($n)';
    }).toList();
  }

  // Returns one entry per slide with per-verse reference (Book Chap:Verse • VERSION)
  List<String> get slideReferences => switch (type) {
    CollectionItemType.bibleVerse => _bibleSlideRefs,
    _ => List.filled(slides.length, ''),
  };

  List<String> get _bibleSlideRefs {
    final book = contentJson?['book'] ?? '';
    final chapter = contentJson?['chapter'] ?? '';
    final verseStart = (contentJson?['verse'] as num?)?.toInt() ?? 1;
    final version = contentJson?['version'] as String? ?? '';
    final suffix = version.isNotEmpty ? ' • $version' : '';
    final texts = contentJson?['texts'];
    if (texts is List && texts.isNotEmpty) {
      return List.generate(texts.length, (i) => '$book $chapter:${verseStart + i}$suffix');
    }
    return ['$book $chapter:$verseStart$suffix'];
  }

  List<String> get _bibleSlides {
    final texts = contentJson?['texts'];
    if (texts is List && texts.isNotEmpty) {
      return texts.map((t) => '"$t"').toList();
    }
    final text = contentJson?['text'] as String? ?? '';
    return ['"$text"'];
  }

  List<String> get _sermonSlides {
    final title = contentJson?['title'] as String? ?? '';
    final points = List<String>.from(contentJson?['points'] ?? []);
    return [title, ...points];
  }

  List<String> get _sermonLabels {
    final points = List<String>.from(contentJson?['points'] ?? []);
    return ['Título', ...List.generate(points.length, (i) => 'Punto ${i + 1}')];
  }

  CollectionItem withTemplateId(String? id) => CollectionItem(
    id: this.id,
    collectionId: collectionId,
    type: type,
    order: order,
    song: song,
    templateId: id,
    contentJson: contentJson,
    notes: notes,
    autoAdvanceSecs: autoAdvanceSecs,
  );

  CollectionItem copyWith({
    String? templateId,
    String? notes,
    int? autoAdvanceSecs,
    bool clearAutoAdvance = false,
  }) => CollectionItem(
    id: id,
    collectionId: collectionId,
    type: type,
    order: order,
    song: song,
    templateId: templateId ?? this.templateId,
    contentJson: contentJson,
    notes: notes ?? this.notes,
    autoAdvanceSecs: clearAutoAdvance ? null : autoAdvanceSecs ?? this.autoAdvanceSecs,
  );

  factory CollectionItem.fromJson(Map<String, dynamic> json) => CollectionItem(
    id: json['id'] as String,
    collectionId: json['collection_id'] as String,
    type: CollectionItemTypeX.fromString(json['item_type'] as String? ?? 'song'),
    order: json['item_order'] as int,
    song: json['songs'] != null ? Song.fromJson(json['songs'] as Map<String, dynamic>) : null,
    templateId: json['template_id'] as String?,
    contentJson: _parseContentJson(json['content_json']),
    notes: json['notes'] as String?,
    autoAdvanceSecs: json['auto_advance_secs'] as int?,
  );

  @override
  List<Object?> get props => [
    id,
    type,
    order,
    song,
    contentJson,
    templateId,
    notes,
    autoAdvanceSecs,
  ];
}

class Collection extends Equatable {
  const Collection({
    required this.id,
    required this.name,
    this.serviceDate,
    this.notes,
    this.templateId,
    this.bgAudioPath,
    this.items = const [],
  });

  final String id;
  final String name;
  final DateTime? serviceDate;
  final String? notes;
  final String? templateId;
  final String? bgAudioPath;
  final List<CollectionItem> items;

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
    id: json['id'] as String,
    name: json['name'] as String,
    serviceDate: json['service_date'] != null
        ? DateTime.parse(json['service_date'] as String)
        : null,
    notes: json['notes'] as String?,
    templateId: json['template_id'] as String?,
    bgAudioPath: json['bg_audio_path'] as String?,
    items:
        (json['collection_items'] as List<dynamic>? ?? [])
            .map((i) => CollectionItem.fromJson(i as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
  );

  Collection copyWith({
    String? id,
    String? name,
    DateTime? serviceDate,
    String? notes,
    String? templateId,
    bool clearTemplateId = false,
    String? bgAudioPath,
    bool clearBgAudio = false,
    List<CollectionItem>? items,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      serviceDate: serviceDate ?? this.serviceDate,
      notes: notes ?? this.notes,
      templateId: clearTemplateId ? null : templateId ?? this.templateId,
      bgAudioPath: clearBgAudio ? null : bgAudioPath ?? this.bgAudioPath,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [id, name, templateId, items];
}
