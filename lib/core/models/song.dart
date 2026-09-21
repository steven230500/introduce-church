import 'package:equatable/equatable.dart';

import '../utils/new_id.dart';

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

  /// The wire spelling, the one [fromString] reads back.
  String get value => switch (this) {
    VerseType.preCHORUS => 'pre-chorus',
    _ => name,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'song_id': songId,
    'type': type.value,
    'verse_order': order,
    'content': content,
    'chords': chords,
  };

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

  /// The row as `/songs` sends it, so a song can travel inside a service to a
  /// window or a queue and be read back by [Song.fromJson] unchanged.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'copyright': copyright,
    'ccli_number': ccliNumber,
    'language': language,
    'tags': tags,
    'verses': [for (final verse in verses) verse.toJson()],
  };

  List<String> get slides => verses.map((v) => v.content).toList();

  Song copyWith({List<Verse>? verses}) => Song(
    id: id,
    title: title,
    author: author,
    copyright: copyright,
    ccliNumber: ccliNumber,
    language: language,
    tags: tags,
    verses: verses ?? this.verses,
  );

  /// How many other times the words of slide [index] come up in the song:
  /// the chorus sung three times is three slides with the same words.
  int repeatsOf(int index) {
    if (index < 0 || index >= verses.length) return 0;
    final verse = verses[index];
    return verses.where((v) => v != verse && _sameWords(v, verse)).length;
  }

  /// The song with slide [index] replaced by [parts].
  ///
  /// One part corrects the slide, two or more split it into slides of the same
  /// kind, none takes it out. A correction or a split reaches every repeat of
  /// the same words - a typo in the chorus is in the chorus, however many
  /// times it is sung - but taking a slide out takes out only that time,
  /// because dropping one repeat is a change to the arrangement, not the words.
  Song withSlide(int index, List<String> parts) {
    if (index < 0 || index >= verses.length) return this;
    final edited = verses[index];
    final replaced = <Verse>[];
    for (final (position, verse) in verses.indexed) {
      final isTarget = position == index;
      final isRepeat = !isTarget && parts.isNotEmpty && _sameWords(verse, edited);
      if (!isTarget && !isRepeat) {
        replaced.add(verse);
        continue;
      }
      for (final (n, part) in parts.indexed) {
        replaced.add(
          Verse(
            id: n == 0 ? verse.id : newId(),
            songId: id,
            type: verse.type,
            order: 0,
            content: part,
            // The chords belong to the words they were written over; a new
            // slide split off the end starts without them.
            chords: n == 0 ? verse.chords : null,
          ),
        );
      }
    }
    return copyWith(
      verses: [
        for (final (order, verse) in replaced.indexed)
          Verse(
            id: verse.id,
            songId: verse.songId,
            type: verse.type,
            order: order,
            content: verse.content,
            chords: verse.chords,
          ),
      ],
    );
  }

  /// Where slide [position] lands once [withSlide] has replaced slide [index]
  /// with [parts]: after a split above it, the same words are one slide
  /// further down. A slide that was taken out lands on the one that followed.
  int positionAfter(int index, List<String> parts, int position) {
    if (index < 0 || index >= verses.length) return position;
    var moved = 0;
    for (var p = 0; p < position && p < verses.length; p++) {
      final touched = p == index || (parts.isNotEmpty && _sameWords(verses[p], verses[index]));
      moved += touched ? parts.length : 1;
    }
    return moved;
  }

  static bool _sameWords(Verse a, Verse b) => a.type == b.type && a.content == b.content;

  @override
  List<Object?> get props => [id, title, author, verses];
}
