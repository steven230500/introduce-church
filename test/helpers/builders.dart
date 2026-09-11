/// Builders for the Supabase row shapes the app reads, so tests describe the
/// data they care about instead of repeating full JSON payloads.
library;

Map<String, dynamic> collectionRow({
  required String id,
  String name = 'Servicio',
  String? serviceDate,
  String? templateId,
  String? bgAudioPath,
  List<Map<String, dynamic>> items = const [],
}) => {
      'id': id,
      'name': name,
      'service_date': serviceDate,
      'notes': null,
      'template_id': templateId,
      'bg_audio_path': bgAudioPath,
      'collection_items': items,
    };

Map<String, dynamic> songItemRow({
  required String id,
  required String collectionId,
  required int order,
  String title = 'Canción',
  String? author,
  List<String> verses = const ['Verso uno'],
  List<String> verseTypes = const [],
  String? templateId,
  String? notes,
  int? autoAdvanceSecs,
}) => {
      'id': id,
      'collection_id': collectionId,
      'item_type': 'song',
      'item_order': order,
      'template_id': templateId,
      'content_json': null,
      'notes': notes,
      'auto_advance_secs': autoAdvanceSecs,
      'songs': {
        'id': 'song-$id',
        'title': title,
        'author': author,
        'language': 'es',
        'tags': <String>[],
        'verses': [
          for (var i = 0; i < verses.length; i++)
            {
              'id': 'verse-$id-$i',
              'song_id': 'song-$id',
              'type': i < verseTypes.length ? verseTypes[i] : 'verse',
              'verse_order': i,
              'content': verses[i],
            },
        ],
      },
    };

Map<String, dynamic> itemRow({
  required String id,
  required String collectionId,
  required String type,
  required int order,
  Map<String, dynamic>? contentJson,
  String? templateId,
  String? notes,
  int? autoAdvanceSecs,
}) => {
      'id': id,
      'collection_id': collectionId,
      'item_type': type,
      'item_order': order,
      'template_id': templateId,
      'content_json': contentJson,
      'notes': notes,
      'auto_advance_secs': autoAdvanceSecs,
    };
