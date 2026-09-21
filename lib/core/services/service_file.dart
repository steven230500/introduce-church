/// A whole service in one file.
///
/// Three things needed this and none of them are exotic: a backup that does
/// not depend on the server being there, moving a service between a rehearsal
/// laptop and the booth machine, and a second campus running the same plan on
/// Sunday. Every one of them was previously "build it again by hand".
///
/// The file carries the lyrics and the designs, not just references to them,
/// because the church opening it is often not the church that made it. What it
/// does not carry is the media: a countdown video would turn a 40 KB plan into
/// a 200 MB attachment, so photos and video come across as the paths they had
/// and the import says which ones it could not find.
library;

import 'dart:convert';
import '../../l10n/l10n.dart';
import '../models/collection.dart';
import '../models/collection_item_type.dart';
import '../models/slide_template.dart';
import '../models/song.dart';

/// What a file turned back into. Ids inside are the exporting church's and
/// mean nothing here until they are remapped.
typedef ServiceFile = ({
  String name,
  DateTime? serviceDate,
  String? designId,
  List<SlideTemplate> designs,
  List<Song> songs,
  List<ServiceFileItem> items,
});

/// One entry of the plan, still pointing at the ids the file was written with.
typedef ServiceFileItem = ({
  CollectionItemType type,
  String? songId,
  String? designId,
  Map<String, dynamic>? content,
  String? notes,
  int? autoAdvanceSecs,
  int? plannedSecs,
});

/// Marks the file as ours, so opening the wrong JSON says so instead of
/// failing somewhere deep with a type error.
const kServiceFileFormat = 'introduce.service';

/// Raised when the format changes in a way an older app cannot read.
const kServiceFileVersion = 1;

/// The extension the file picker filters on.
const kServiceFileExtension = 'introduce';

/// Everything needed to rebuild [collection] somewhere else.
String encodeService(
  Collection collection, {
  required List<SlideTemplate> designs,
  DateTime? exportedAt,
}) {
  // Only the designs this service actually uses. Exporting a church's whole
  // design library inside one Sunday is not what anyone asked for.
  final used = <String>{
    ?collection.templateId,
    for (final item in collection.items) ?item.templateId,
  };

  final songs = <String, Song>{for (final item in collection.items) ?item.song?.id: ?item.song};

  return const JsonEncoder.withIndent('  ').convert({
    'format': kServiceFileFormat,
    'version': kServiceFileVersion,
    'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
    'name': collection.name,
    'serviceDate': collection.serviceDate?.toIso8601String(),
    'designId': collection.templateId,
    'designs': [
      for (final design in designs)
        if (used.contains(design.id))
          {'id': design.id, 'name': design.name, 'config': design.toJson()},
    ],
    'songs': [
      for (final song in songs.values)
        {
          'id': song.id,
          'title': song.title,
          'author': song.author,
          'copyright': song.copyright,
          'ccliNumber': song.ccliNumber,
          'verses': [
            for (final verse in song.verses)
              {'type': verse.type.value, 'content': verse.content, 'chords': verse.chords},
          ],
        },
    ],
    'items': [
      for (final item in collection.items)
        {
          'type': item.type.value,
          'songId': item.song?.id,
          'designId': item.templateId,
          'content': item.contentJson,
          'notes': item.notes,
          'autoAdvanceSecs': item.autoAdvanceSecs,
          'plannedSecs': item.plannedSecs,
        },
    ],
  });
}

/// Why a file could not be opened as a service.
enum ServiceFileProblem { unreadable, notIntroduce, tooNew, noName }

/// Thrown when a file cannot be read, carrying what is wrong with it.
///
/// [message] is the Spanish sentence for logs; the screen words [problem] in
/// the operator's language through [describeIn].
class ServiceFileError implements Exception {
  const ServiceFileError(this.problem);
  final ServiceFileProblem problem;

  String get message => switch (problem) {
    ServiceFileProblem.unreadable => 'El archivo no se puede leer.',
    ServiceFileProblem.notIntroduce => 'Ese archivo no es un servicio de Introduce.',
    ServiceFileProblem.tooNew =>
      'El archivo viene de una versión más nueva de Introduce. Actualiza la app para abrirlo.',
    ServiceFileProblem.noName => 'El archivo no dice de qué servicio es.',
  };

  String describeIn(L10n t) => switch (problem) {
    ServiceFileProblem.unreadable => t.serviceFileUnreadable,
    ServiceFileProblem.notIntroduce => t.serviceFileNotIntroduce,
    ServiceFileProblem.tooNew => t.serviceFileTooNew,
    ServiceFileProblem.noName => t.serviceFileNoName,
  };

  @override
  String toString() => message;
}

/// Reads a file back. Throws [ServiceFileError] with something an operator can
/// act on rather than a decoding error nobody can.
ServiceFile decodeService(String source) {
  final Object? raw;
  try {
    raw = jsonDecode(source);
  } catch (_) {
    throw const ServiceFileError(ServiceFileProblem.unreadable);
  }
  if (raw is! Map<String, dynamic>) {
    throw const ServiceFileError(ServiceFileProblem.unreadable);
  }
  if (raw['format'] != kServiceFileFormat) {
    throw const ServiceFileError(ServiceFileProblem.notIntroduce);
  }
  final version = (raw['version'] as num?)?.toInt() ?? 0;
  if (version > kServiceFileVersion) {
    throw const ServiceFileError(ServiceFileProblem.tooNew);
  }

  final name = (raw['name'] as String?)?.trim();
  if (name == null || name.isEmpty) {
    throw const ServiceFileError(ServiceFileProblem.noName);
  }

  final date = raw['serviceDate'] as String?;

  return (
    name: name,
    serviceDate: date == null ? null : DateTime.tryParse(date),
    designId: raw['designId'] as String?,
    designs: [
      for (final row in raw['designs'] as List<dynamic>? ?? const [])
        if (row is Map<String, dynamic>)
          SlideTemplate.fromJson(
            id: row['id'] as String? ?? '',
            name: row['name'] as String? ?? 'Diseño',
            json: Map<String, dynamic>.from(row['config'] as Map? ?? const {}),
          ),
    ],
    songs: [
      for (final row in raw['songs'] as List<dynamic>? ?? const [])
        if (row is Map<String, dynamic>) _song(row),
    ],
    items: [
      for (final row in raw['items'] as List<dynamic>? ?? const [])
        // Items a newer version wrote that this one does not know stay out,
        // rather than arriving as empty songs.
        if (row is Map<String, dynamic> &&
            (row['type'] == null || CollectionItemTypeX.isKnown(row['type'] as String?)))
          (
            type: CollectionItemTypeX.fromString(row['type'] as String? ?? 'song'),
            songId: row['songId'] as String?,
            designId: row['designId'] as String?,
            content: row['content'] == null
                ? null
                : Map<String, dynamic>.from(row['content'] as Map),
            notes: row['notes'] as String?,
            autoAdvanceSecs: (row['autoAdvanceSecs'] as num?)?.toInt(),
            plannedSecs: (row['plannedSecs'] as num?)?.toInt(),
          ),
    ],
  );
}

Song _song(Map<String, dynamic> row) {
  final id = row['id'] as String? ?? '';
  final verses = row['verses'] as List<dynamic>? ?? const [];
  return Song(
    id: id,
    title: row['title'] as String? ?? 'Canción',
    author: row['author'] as String?,
    copyright: row['copyright'] as String?,
    ccliNumber: row['ccliNumber'] as String?,
    verses: [
      for (final (index, verse) in verses.indexed)
        if (verse is Map<String, dynamic>)
          Verse(
            id: '$id-$index',
            songId: id,
            type: VerseTypeX.fromString(verse['type'] as String? ?? 'verse'),
            order: index,
            content: verse['content'] as String? ?? '',
            chords: verse['chords'] as String?,
          ),
    ],
  );
}

/// A name for the file on disk: the service, the date, no characters a file
/// system will argue about.
String serviceFileName(String serviceName, {DateTime? on}) {
  final when = on ?? DateTime.now();
  final stamp =
      '${when.year}'
      '${when.month.toString().padLeft(2, '0')}'
      '${when.day.toString().padLeft(2, '0')}';
  final safe = serviceName
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return 'introduce_${stamp}_${safe.isEmpty ? 'servicio' : safe}.$kServiceFileExtension';
}
