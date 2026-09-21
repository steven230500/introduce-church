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
    this.plannedSecs,
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

  /// How long this part of the service is meant to take, usually as timed in
  /// a rehearsal. What the stage display counts the item against.
  final int? plannedSecs;

  // Slides a proyectar según el tipo
  List<String> get slides => switch (type) {
    CollectionItemType.song => song?.slides ?? [],
    CollectionItemType.bibleVerse => _bibleSlides,
    CollectionItemType.sermon => _sermonSlides,
    CollectionItemType.freeSlide => [contentJson?['text'] as String? ?? ''],
    CollectionItemType.imageSlide => List<String>.from(contentJson?['paths'] as List? ?? []),
    CollectionItemType.videoSlide => [contentJson?['path'] as String? ?? ''],
    CollectionItemType.announcement => [contentJson?['message'] as String? ?? ''],
    // A moment is a mark in the running order, not something that goes on the
    // screen, so it has nothing to project.
    CollectionItemType.section => const [],
  };

  /// Whether this is a mark in the running order rather than something the
  /// congregation can see.
  bool get isSection => type == CollectionItemType.section;

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
    CollectionItemType.section => contentJson?['title'] as String? ?? 'Momento',
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
    CollectionItemType.section => '',
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

  /// Whether the church asked for the whole passage on one slide rather than
  /// a slide per verse. A pastor reading three verses straight through does
  /// not want the screen changing under him mid-sentence.
  bool get versesTogether => contentJson?['together'] == true;

  List<String> get _bibleSlideRefs {
    final book = contentJson?['book'] ?? '';
    final chapter = contentJson?['chapter'] ?? '';
    final verseStart = (contentJson?['verse'] as num?)?.toInt() ?? 1;
    final version = contentJson?['version'] as String? ?? '';
    final suffix = version.isNotEmpty ? ' • $version' : '';
    final texts = contentJson?['texts'];
    if (texts is List && texts.isNotEmpty) {
      if (versesTogether && texts.length > 1) {
        return ['$book $chapter:$verseStart-${verseStart + texts.length - 1}$suffix'];
      }
      // A verse missing from the version it came from has no slide, and the
      // ones after it keep their numbers.
      return [
        for (var i = 0; i < texts.length; i++)
          if ('${texts[i]}'.trim().isNotEmpty) '$book $chapter:${verseStart + i}$suffix',
      ];
    }
    return ['$book $chapter:$verseStart$suffix'];
  }

  List<String> get _bibleSlides {
    final texts = contentJson?['texts'];
    if (texts is List && texts.isNotEmpty) {
      final present = [
        for (final text in texts)
          if ('$text'.trim().isNotEmpty) '$text',
      ];
      if (present.isEmpty) return ['""'];
      if (versesTogether && texts.length > 1) return ['"${present.join(' ')}"'];
      return present.map((t) => '"$t"').toList();
    }
    final text = contentJson?['text'] as String? ?? '';
    return ['"$text"'];
  }

  List<String> get _sermonSlides {
    final title = contentJson?['title'] as String? ?? '';
    final points = List<String>.from(contentJson?['points'] ?? []);
    return [title, ...points];
  }

  /// Whether the words of its slides can be corrected from the grid. A
  /// passage is the Bible's text, and pictures and videos have no words.
  bool get slidesEditable => switch (type) {
    CollectionItemType.song => song != null,
    CollectionItemType.sermon ||
    CollectionItemType.freeSlide ||
    CollectionItemType.announcement => true,
    _ => false,
  };

  /// Whether slide [index] can become two. A slide libre and an announcement
  /// are one slide by nature.
  bool canSplitSlide(int index) => switch (type) {
    CollectionItemType.song || CollectionItemType.sermon => slidesEditable,
    _ => false,
  };

  /// Whether slide [index] can be taken out: never the last one of a song,
  /// and never the sermon's title, which is what the item is called.
  bool canRemoveSlide(int index) => switch (type) {
    CollectionItemType.song => (song?.verses.length ?? 0) > 1,
    CollectionItemType.sermon => index > 0,
    // A page of the announcements that already went by, taken out of the
    // presentation without importing it again.
    CollectionItemType.imageSlide => slides.length > 1,
    _ => false,
  };

  /// Whether a new slide can go after slide [index]: in a song, or among the
  /// sermon's points.
  bool canInsertSlide(int index) => switch (type) {
    CollectionItemType.song => song != null,
    CollectionItemType.sermon => true,
    _ => false,
  };

  /// Whether slide [index] can move [offset] places. The sermon's title stays
  /// first; the pages of a presentation move among themselves.
  bool canMoveSlide(int index, int offset) {
    final target = index + offset;
    return switch (type) {
      CollectionItemType.song => song != null && target >= 0 && target < song!.verses.length,
      CollectionItemType.sermon => index >= 1 && target >= 1 && target < slides.length,
      CollectionItemType.imageSlide => target >= 0 && target < slides.length,
      _ => false,
    };
  }

  /// The content with [text] as a new point after slide [index] of a sermon.
  Map<String, dynamic>? contentWithInsert(int index, String text) {
    if (type != CollectionItemType.sermon) return null;
    final points = List<String>.from(contentJson?['points'] ?? const []);
    points.insert(index.clamp(0, points.length), text);
    return {'title': contentJson?['title'] ?? '', 'points': points};
  }

  /// The content with slide [index] moved [offset] places: a sermon point or
  /// a page of a presentation.
  Map<String, dynamic>? contentWithMove(int index, int offset) {
    if (!canMoveSlide(index, offset)) return null;
    switch (type) {
      case CollectionItemType.sermon:
        final points = List<String>.from(contentJson?['points'] ?? const []);
        points.insert(index - 1 + offset, points.removeAt(index - 1));
        return {'title': contentJson?['title'] ?? '', 'points': points};
      case CollectionItemType.imageSlide:
        final paths = List<String>.from(contentJson?['paths'] ?? const []);
        paths.insert(index + offset, paths.removeAt(index));
        return {'paths': paths};
      default:
        return null;
    }
  }

  /// Where slide [position] lands once a new slide goes in after [index].
  static int positionAfterInsert(int index, int position) =>
      position > index ? position + 1 : position;

  /// Where slide [position] lands once slide [from] moves to [to].
  static int positionAfterMove(int from, int to, int position) {
    if (position == from) return to;
    if (from < to && position > from && position <= to) return position - 1;
    if (to < from && position >= to && position < from) return position + 1;
    return position;
  }

  /// Where slide [position] lands once slide [index] is replaced by [parts],
  /// so the operator's place and the screen stay on the same words.
  int slidePositionAfterEdit(int index, List<String> parts, int position) {
    if (type == CollectionItemType.song && song != null) {
      return song!.positionAfter(index, parts, position);
    }
    if (position <= index) return position;
    return position + parts.length - 1;
  }

  /// The content that results from replacing slide [index] with [parts], for
  /// the kinds whose words live in the item itself. Songs keep theirs in the
  /// library: see [Song.withSlide].
  Map<String, dynamic>? contentWithSlide(int index, List<String> parts) {
    switch (type) {
      case CollectionItemType.sermon:
        final title = contentJson?['title'] as String? ?? '';
        final points = List<String>.from(contentJson?['points'] ?? const []);
        if (index == 0) {
          // The title split in two keeps its first half as the title; the rest
          // become the first points.
          if (parts.isEmpty) return null;
          return {
            'title': parts.first,
            'points': [...parts.skip(1), ...points],
          };
        }
        final at = index - 1;
        if (at >= points.length) return null;
        points.replaceRange(at, at + 1, parts);
        return {'title': title, 'points': points};
      case CollectionItemType.freeSlide:
        if (parts.length != 1) return null;
        return {'text': parts.single, 'title': ?contentJson?['title']};
      case CollectionItemType.announcement:
        if (parts.length != 1) return null;
        return {'message': parts.single};
      case CollectionItemType.imageSlide:
        // A page has no words to correct; it can only be taken out.
        final paths = List<String>.from(contentJson?['paths'] ?? const []);
        if (parts.isNotEmpty || index >= paths.length || paths.length < 2) return null;
        return {'paths': paths..removeAt(index)};
      default:
        return null;
    }
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
    plannedSecs: plannedSecs,
  );

  /// The same content as a new item [id] in another collection, for copying a
  /// running order into a new service.
  CollectionItem copiedInto(String collectionId, String id) => CollectionItem(
    id: id,
    collectionId: collectionId,
    type: type,
    order: order,
    song: song,
    templateId: templateId,
    contentJson: contentJson,
    notes: notes,
    autoAdvanceSecs: autoAdvanceSecs,
    plannedSecs: plannedSecs,
  );

  CollectionItem copyWith({
    int? order,
    Song? song,
    String? templateId,
    Map<String, dynamic>? contentJson,
    String? notes,
    bool clearNotes = false,
    int? autoAdvanceSecs,
    bool clearAutoAdvance = false,
    int? plannedSecs,
    bool clearPlanned = false,
  }) => CollectionItem(
    id: id,
    collectionId: collectionId,
    type: type,
    order: order ?? this.order,
    song: song ?? this.song,
    templateId: templateId ?? this.templateId,
    contentJson: contentJson ?? this.contentJson,
    notes: clearNotes ? null : notes ?? this.notes,
    autoAdvanceSecs: clearAutoAdvance ? null : autoAdvanceSecs ?? this.autoAdvanceSecs,
    plannedSecs: clearPlanned ? null : plannedSecs ?? this.plannedSecs,
  );

  /// The same item under a new name.
  ///
  /// The title lives inside `content_json` next to the slide paths and the
  /// sermon points, so renaming has to leave the rest of that map alone.
  CollectionItem renamed(String title) => copyWith(contentJson: {...?contentJson, 'title': title});

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
    plannedSecs: (json['planned_secs'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection_id': collectionId,
    'item_type': type.value,
    'item_order': order,
    'template_id': templateId,
    'content_json': contentJson,
    'notes': notes,
    'auto_advance_secs': autoAdvanceSecs,
    'planned_secs': plannedSecs,
    'songs': song?.toJson(),
  };

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
    plannedSecs,
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

  /// The moment [item] belongs to: the nearest mark above it, or null before
  /// the first one. A moment belongs to itself.
  CollectionItem? momentOf(CollectionItem item) {
    final at = items.indexWhere((i) => i.id == item.id);
    for (var i = at; i >= 0; i--) {
      if (items[i].isSection) return items[i];
    }
    return null;
  }

  /// The designs that could draw [item], most particular first: its own, its
  /// moment's, the service's. Alabanza on a moving background and the sermon
  /// on a plain one, without giving every song the design one by one.
  List<String> designsFor(CollectionItem item) => [
    ?item.templateId,
    ?momentOf(item)?.templateId,
    ?templateId,
  ];

  /// How many things the service puts on the screen. The moments that divide
  /// it are marks in the list, and counting them made a service of seven items
  /// with three moments read as ten.
  int get playableCount => items.where((item) => !item.isSection).length;

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
            .cast<Map<String, dynamic>>()
            // A row with no type is the oldest shape, a song; a type this
            // version does not know is something newer, and left out.
            .where(
              (i) =>
                  i['item_type'] == null || CollectionItemTypeX.isKnown(i['item_type'] as String?),
            )
            .map(CollectionItem.fromJson)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
  );

  /// The row as `/collections` sends it.
  ///
  /// What the projector and stage windows are handed, built from the plan on
  /// the operator's screen rather than kept from the last download: a change
  /// made with no network is on that screen, and the projector has to agree
  /// with it about which song is item four.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'service_date': serviceDate == null
        ? null
        : '${serviceDate!.year.toString().padLeft(4, '0')}-'
              '${serviceDate!.month.toString().padLeft(2, '0')}-'
              '${serviceDate!.day.toString().padLeft(2, '0')}',
    'notes': notes,
    'template_id': templateId,
    'bg_audio_path': bgAudioPath,
    'collection_items': [for (final item in items) item.toJson()],
  };

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
  List<Object?> get props => [id, name, serviceDate, notes, templateId, bgAudioPath, items];
}
