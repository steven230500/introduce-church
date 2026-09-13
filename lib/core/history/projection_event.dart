import 'dart:math';

import 'package:equatable/equatable.dart';

import '../models/collection.dart';
import '../models/collection_item_type.dart';

/// One stretch of time one item was on the screen.
///
/// Per item rather than per slide: a licence report counts a song once each
/// time it is used, and a service history reads as a running order, not as two
/// hundred page turns.
class ProjectionEvent extends Equatable {
  const ProjectionEvent({
    required this.id,
    required this.itemType,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    this.collectionId,
    this.collectionName = '',
    this.songId,
    this.songAuthor,
    this.songCopyright,
    this.ccliNumber,
  });

  /// Made here, not by the server, so the event can be recorded with no
  /// network and sent twice without being counted twice.
  final String id;

  final String? collectionId;
  final String collectionName;
  final String itemType;
  final String title;

  final String? songId;
  final String? songAuthor;
  final String? songCopyright;
  final String? ccliNumber;

  final DateTime startedAt;
  final DateTime endedAt;

  bool get isSong => itemType == 'song';

  Duration get duration => endedAt.difference(startedAt);

  /// Ids that are not UUIDs are sent as null. The server stores the batch or
  /// refuses all of it, and one odd id - a row made offline, an import that has
  /// not synced - must not keep a whole service out of the record.
  Map<String, dynamic> toJson() => {
    'id': id,
    'collection_id': _uuidOrNull(collectionId),
    'collection_name': collectionName,
    'item_type': itemType,
    'title': title,
    'song_id': _uuidOrNull(songId),
    'song_author': songAuthor,
    'song_copyright': songCopyright,
    'ccli_number': ccliNumber,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
  };

  factory ProjectionEvent.fromJson(Map<String, dynamic> json) => ProjectionEvent(
    id: json['id'] as String,
    collectionId: json['collection_id'] as String?,
    collectionName: json['collection_name'] as String? ?? '',
    itemType: json['item_type'] as String? ?? 'song',
    title: json['title'] as String? ?? '',
    songId: json['song_id'] as String?,
    songAuthor: json['song_author'] as String?,
    songCopyright: json['song_copyright'] as String?,
    ccliNumber: json['ccli_number'] as String?,
    startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
    endedAt: DateTime.parse(json['ended_at'] as String).toLocal(),
  );

  @override
  List<Object?> get props => [id, startedAt, endedAt];
}

final _uuidShape = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String? _uuidOrNull(String? value) => value != null && _uuidShape.hasMatch(value) ? value : null;

/// What is on the screen at one moment, or nothing.
typedef OnAir = ({Collection collection, CollectionItem item});

/// Turns a sequence of "what is on air now" into closed stretches of time.
///
/// Fed every time the presenter's state changes. It opens a stretch when
/// something goes on air, and closes it when that thing is replaced, blacked
/// out or taken off air.
class SegmentTracker {
  SegmentTracker({this.minimum = const Duration(seconds: 5), String Function()? newId})
    : _newId = newId ?? _uuid;

  /// Shorter than this does not count.
  ///
  /// An operator stepping through the running order with the output live puts
  /// every song on screen for half a second on the way past. Counting those
  /// would put songs nobody sang into a licence report somebody has to sign.
  final Duration minimum;

  final String Function() _newId;

  OnAir? _current;
  DateTime? _since;

  /// Reports what is on the screen as of [now]. Returns the stretch this
  /// closed, if it closed one that counts.
  ProjectionEvent? observe(OnAir? onAir, DateTime now) {
    if (_sameThing(_current, onAir)) return null;

    final closed = _close(now);
    _current = onAir;
    _since = onAir == null ? null : now;
    return closed;
  }

  /// Closes whatever is open, for when the presenter goes away with something
  /// still on the screen.
  ProjectionEvent? finish(DateTime now) {
    final closed = _close(now);
    _current = null;
    _since = null;
    return closed;
  }

  ProjectionEvent? _close(DateTime now) {
    final current = _current;
    final since = _since;
    if (current == null || since == null) return null;
    if (now.difference(since) < minimum) return null;

    final item = current.item;
    final song = item.song;
    return ProjectionEvent(
      id: _newId(),
      collectionId: current.collection.id,
      collectionName: current.collection.name,
      itemType: item.type.value,
      title: item.displayTitle,
      songId: song?.id,
      songAuthor: song?.author,
      songCopyright: song?.copyright,
      ccliNumber: song?.ccliNumber,
      startedAt: since,
      endedAt: now,
    );
  }

  /// The same item of the same service is the same thing, even when the slide
  /// within it changed: moving from the verse to the chorus is not a new use of
  /// the song.
  static bool _sameThing(OnAir? a, OnAir? b) {
    if (a == null || b == null) return a == b;
    return a.collection.id == b.collection.id && a.item.id == b.item.id;
  }
}

/// A random v4 UUID, without a dependency for one function.
String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int from, int to) =>
      bytes.sublist(from, to).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Exposed so tests can check the shape without reaching into privates.
String newProjectionId() => _uuid();
