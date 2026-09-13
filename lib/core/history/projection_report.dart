import 'projection_event.dart';

/// One service as it actually happened: what went up, in order.
typedef ServiceHistory = ({
  String collectionName,
  DateTime day,
  DateTime startedAt,
  DateTime endedAt,
  List<ProjectionEvent> events,
});

/// One song's line in a licence report.
typedef SongUse = ({
  String title,
  String? author,
  String? copyright,
  String? ccliNumber,

  /// How many services it was used in. Not how many times it was put on the
  /// screen: a chorus sung again after the sermon is still one use of the song
  /// in that service.
  int uses,
  List<DateTime> days,
});

/// Groups a stretch of the record into the services it came from.
///
/// A service is one running order on one calendar day. The same running order
/// used on two Sundays is two services, and two running orders on one Sunday
/// morning are two services, because that is how anyone would describe them.
/// Newest first: the question is almost always "last Sunday".
List<ServiceHistory> servicesFrom(Iterable<ProjectionEvent> events) {
  final groups = <String, List<ProjectionEvent>>{};
  for (final event in events) {
    final day = _dayOf(event.startedAt);
    final key = '${day.toIso8601String()}|${event.collectionId ?? event.collectionName}';
    groups.putIfAbsent(key, () => []).add(event);
  }

  final services = [
    for (final group in groups.values)
      () {
        final ordered = [...group]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
        return (
          collectionName: ordered.first.collectionName,
          day: _dayOf(ordered.first.startedAt),
          startedAt: ordered.first.startedAt,
          endedAt: ordered.map((e) => e.endedAt).reduce((a, b) => a.isAfter(b) ? a : b),
          events: ordered,
        );
      }(),
  ];
  services.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return services;
}

/// Every song used in a stretch of time, for the licence report.
///
/// Songs are told apart by their licence number when they have one, and by
/// title and author when they do not, so the same song imported twice into
/// the library still reports as one song. Most used first, then by title.
List<SongUse> songReport(Iterable<ProjectionEvent> events) {
  final bySong = <String, List<ProjectionEvent>>{};
  for (final event in events.where((e) => e.isSong)) {
    bySong.putIfAbsent(_songKey(event), () => []).add(event);
  }

  final rows = [
    for (final group in bySong.values)
      () {
        final services = <String>{};
        final days = <DateTime>{};
        for (final event in group) {
          final day = _dayOf(event.startedAt);
          services.add('${day.toIso8601String()}|${event.collectionId ?? event.collectionName}');
          days.add(day);
        }
        // The most recent copy of the details wins: a licence number added
        // to the song later should appear in the report.
        final latest = group.reduce((a, b) => a.startedAt.isAfter(b.startedAt) ? a : b);
        return (
          title: latest.title,
          author: latest.songAuthor,
          copyright: latest.songCopyright,
          ccliNumber: latest.ccliNumber,
          uses: services.length,
          days: days.toList()..sort(),
        );
      }(),
  ];

  rows.sort((a, b) {
    final byUses = b.uses.compareTo(a.uses);
    return byUses != 0 ? byUses : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return rows;
}

/// The licence report as a spreadsheet anyone can open.
///
/// Comma separated with every field quoted, and a byte order mark first, so a
/// title with an accent opens as "Canción" in Excel and not as mojibake.
String songReportCsv(List<SongUse> rows, {required List<String> headers}) {
  String field(Object? value) => '"${'${value ?? ''}'.replaceAll('"', '""')}"';
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final lines = [
    headers.map(field).join(','),
    for (final row in rows)
      [
        row.title,
        row.author,
        row.copyright,
        row.ccliNumber,
        row.uses,
        row.days.map(date).join(' '),
      ].map(field).join(','),
  ];
  return '\uFEFF${lines.join('\r\n')}\r\n';
}

DateTime _dayOf(DateTime moment) {
  final local = moment.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _songKey(ProjectionEvent event) {
  final ccli = event.ccliNumber?.trim();
  if (ccli != null && ccli.isNotEmpty) return 'ccli:$ccli';
  return 'name:${event.title.trim().toLowerCase()}|${(event.songAuthor ?? '').trim().toLowerCase()}';
}
