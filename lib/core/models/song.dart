import 'package:equatable/equatable.dart';

enum VerseType { verse, chorus, bridge, preCHORUS, tag, intro, outro }

extension VerseTypeX on VerseType {
  String get label => switch (this) {
    VerseType.verse => 'Verso',
    VerseType.chorus => 'Coro',
    VerseType.bridge => 'Puente',
    VerseType.preCHORUS => 'Pre-coro',
    VerseType.tag => 'Tag',
    VerseType.intro => 'Intro',
    VerseType.outro => 'Outro',
  };

  static VerseType fromString(String value) => switch (value) {
    'chorus' => VerseType.chorus,
    'bridge' => VerseType.bridge,
    'pre-chorus' => VerseType.preCHORUS,
    'tag' => VerseType.tag,
    'intro' => VerseType.intro,
    'outro' => VerseType.outro,
    _ => VerseType.verse,
  };
}

class Verse extends Equatable {
  const Verse({
    required this.id,
    required this.songId,
    required this.type,
    required this.order,
    required this.content,
    this.chords,
  });

  final String id;
  final String songId;
  final VerseType type;
  final int order;
  final String content;
  final String? chords;

  Verse copyWith({String? content, String? chords, bool clearChords = false}) => Verse(
    id: id,
    songId: songId,
    type: type,
    order: order,
    content: content ?? this.content,
    chords: clearChords ? null : chords ?? this.chords,
  );

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
    id: json['id'] as String,
    songId: json['song_id'] as String,
    type: VerseTypeX.fromString(json['type'] as String),
    order: json['verse_order'] as int,
    content: json['content'] as String,
    chords: json['chords'] as String?,
  );

  @override
  List<Object?> get props => [id, songId, type, order, content, chords];
}

class Song extends Equatable {
  const Song({
    required this.id,
    required this.title,
    this.author,
    this.copyright,
    this.ccliNumber,
    this.language = 'es',
    this.tags = const [],
    this.verses = const [],
  });

  final String id;
  final String title;
  final String? author;
  final String? copyright;
  final String? ccliNumber;
  final String language;
  final List<String> tags;
  final List<Verse> verses;

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String?,
    copyright: json['copyright'] as String?,
    ccliNumber: json['ccli_number'] as String?,
    language: json['language'] as String? ?? 'es',
    tags: List<String>.from(json['tags'] ?? []),
    verses:
        (json['verses'] as List<dynamic>? ?? [])
            .map((v) => Verse.fromJson(v as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
  );

  List<String> get slides => verses.map((v) => v.content).toList();

  @override
  List<Object?> get props => [id, title, author, verses];
}
