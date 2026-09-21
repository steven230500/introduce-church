/// The short code a version goes by on screen: "Juan 3:16 • LBLA".
///
/// Files rarely carry the code a Spanish-speaking church knows the version
/// by, and when they do it is often a catalogue id nobody would put under a
/// verse. So the common versions are recognised by name, and anything else
/// gets its initials, for the operator to correct before saving.
library;

/// Longest names first: "nueva biblia de las americas" must not be taken for
/// "biblia de las americas".
const _knownVersions = [
  ('nueva biblia de las americas', 'NBLA'),
  ('biblia de las americas', 'LBLA'),
  ('nueva version internacional', 'NVI'),
  ('nueva traduccion viviente', 'NTV'),
  ('dios habla hoy', 'DHH'),
  ('lenguaje actual', 'TLA'),
  ('palabra de dios para todos', 'PDT'),
  ('biblia textual', 'BTX'),
  ('reina valera contemporanea', 'RVC'),
  ('reina valera actualizada', 'RVA'),
  ('new king james', 'NKJV'),
  ('king james', 'KJV'),
  ('new international version', 'NIV'),
  ('english standard version', 'ESV'),
  ('new living translation', 'NLT'),
  ('world english bible', 'WEB'),
];

const _smallWords = {
  'de', 'del', 'la', 'las', 'el', 'los', 'y', 'e', 'en', 'a', 'para', 'santa', //
  'the', 'of', 'and', 'holy',
};

/// The code to offer for a Bible titled [title], whose file calls itself
/// [abbreviation].
String suggestVersionCode(String title, {String? abbreviation}) {
  final plain = _plain(title);

  for (final (name, code) in _knownVersions) {
    if (plain.contains(name)) return code;
  }

  // The Reina-Valera revisions go by their year: RV1909, RVR1960, RVR1995.
  final reinaValera = RegExp(r'reina valera (\d{4})').firstMatch(plain);
  if (reinaValera != null) {
    final year = int.parse(reinaValera.group(1)!);
    return year < 1960 ? 'RV$year' : 'RVR$year';
  }

  // A file named "NVI.xml" or "rvr1960.xml" already says it.
  if (_looksLikeCode(title)) return cleanVersionCode(title);
  if (abbreviation != null && _looksLikeCode(abbreviation)) return cleanVersionCode(abbreviation);

  final words = plain.split(' ').where((w) => w.isNotEmpty && !_smallWords.contains(w));
  final letters = words.where((w) => !RegExp(r'^\d+$').hasMatch(w)).map((w) => w[0]).join();
  final year = words.where((w) => RegExp(r'^\d{4}$').hasMatch(w)).firstOrNull ?? '';
  final initials = cleanVersionCode(
    '${letters.length > 6 ? letters.substring(0, 6) : letters}$year',
  );
  if (initials.length >= 2) return initials;
  final fallback = cleanVersionCode(title);
  return fallback.length > 6 ? fallback.substring(0, 6) : fallback;
}

/// Upper case letters and digits, as it will be printed under a verse.
String cleanVersionCode(String value) {
  final cleaned = _stripAccents(value.toUpperCase()).replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return cleaned.length > 10 ? cleaned.substring(0, 10) : cleaned;
}

bool _looksLikeCode(String value) {
  final trimmed = value.trim();
  return trimmed.length >= 2 &&
      trimmed.length <= 10 &&
      RegExp(r'^[A-Za-z]+[0-9]*$').hasMatch(trimmed);
}

String _plain(String value) =>
    _stripAccents(value.toLowerCase()).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String _stripAccents(String value) {
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
    'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
  };
  return value.split('').map((c) => accents[c] ?? c).join();
}
