import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/song.dart';
import '../../../core/song_import/imported_song.dart';
import '../../../core/song_import/song_files.dart';
import '../children/songs_list/repository/repository.dart';

/// Where a song found in the files stands against the library.
enum ImportStatus {
  /// Not in the library: imported unless the operator says otherwise.
  fresh,

  /// A song with the same CCLI number or the same title is already there.
  inLibrary,

  /// The same song appeared earlier in this same import.
  repeated,
}

class ImportCandidate extends Equatable {
  const ImportCandidate(this.song, this.status, {required this.selected});

  final ImportedSong song;
  final ImportStatus status;
  final bool selected;

  ImportCandidate withSelected(bool value) => ImportCandidate(song, status, selected: value);

  @override
  List<Object?> get props => [song, status, selected];
}

sealed class SongImportState extends Equatable {
  const SongImportState();
  @override
  List<Object?> get props => [];
}

/// Nothing chosen yet.
class SongImportIdle extends SongImportState {
  const SongImportIdle();
}

class SongImportReading extends SongImportState {
  const SongImportReading(this.done, this.total);
  final int done;
  final int total;
  @override
  List<Object?> get props => [done, total];
}

class SongImportReview extends SongImportState {
  const SongImportReview({required this.candidates, required this.failures, this.previewing = 0});

  final List<ImportCandidate> candidates;
  final List<SongFileFailure> failures;

  /// The song whose words are shown beside the list.
  final int previewing;

  int get selectedCount => candidates.where((c) => c.selected).length;
  int count(ImportStatus status) => candidates.where((c) => c.status == status).length;

  SongImportReview copyWith({List<ImportCandidate>? candidates, int? previewing}) =>
      SongImportReview(
        candidates: candidates ?? this.candidates,
        failures: failures,
        previewing: previewing ?? this.previewing,
      );

  @override
  List<Object?> get props => [candidates, failures, previewing];
}

class SongImportSaving extends SongImportState {
  const SongImportSaving(this.done, this.total);
  final int done;
  final int total;
  @override
  List<Object?> get props => [done, total];
}

class SongImportDone extends SongImportState {
  const SongImportDone({required this.imported, required this.failures, this.error});

  final int imported;
  final List<SongFileFailure> failures;

  /// Set when sending stopped part of the way: [imported] made it, the rest
  /// did not, and importing the same files again finds the first ones already
  /// in the library.
  final String? error;

  @override
  List<Object?> get props => [imported, failures, error];
}

typedef SongFilesReader =
    Future<List<SongFileResult>> Function(
      List<String> paths, {
      void Function(int done)? onProgress,
    });

class SongImportCubit extends Cubit<SongImportState> {
  SongImportCubit(
    this._repo, {
    SongFilesReader? reader,
    Future<List<String>> Function(String directory)? lister,
  }) : _reader = reader ?? readSongFiles,
       _lister = lister ?? listSongFiles,
       super(const SongImportIdle());

  final SongsListRepository _repo;
  final SongFilesReader _reader;
  final Future<List<String>> Function(String directory) _lister;

  Future<void> openFolder(String directory) async {
    emit(const SongImportReading(0, 0));
    final paths = await _lister(directory);
    if (isClosed) return;
    await openFiles(paths);
  }

  /// Reads [paths] and sets each song found against the library.
  Future<void> openFiles(List<String> paths) async {
    emit(SongImportReading(0, paths.length));
    final results = await _reader(
      paths,
      onProgress: (done) {
        if (!isClosed) emit(SongImportReading(done, paths.length));
      },
    );
    if (isClosed) return;

    List<Song> library;
    try {
      library = await _repo.getSongs();
    } catch (_) {
      // Unknown, then: nothing is marked as already there, and the operator
      // can still untick what they recognise.
      library = const [];
    }
    if (isClosed) return;

    final titles = {for (final song in library) songKey(song.title)};
    final numbers = {for (final song in library) ?nonEmpty(song.ccliNumber)};
    final seen = <String>{};
    final candidates = <ImportCandidate>[];
    final failures = <SongFileFailure>[];

    // Alphabetical, and among copies of the same song the fullest first, so
    // the one ticked is the one with the most slides and the licence details
    // rather than whichever file happened to sort first.
    int fullness(ImportedSong song) =>
        song.verses.length * 4 + (song.ccliNumber != null ? 2 : 0) + (song.author != null ? 1 : 0);
    final songs = [for (final r in results) ?r.song]
      ..sort((a, b) {
        final byTitle = songKey(a.title).compareTo(songKey(b.title));
        return byTitle != 0 ? byTitle : fullness(b).compareTo(fullness(a));
      });
    for (final r in results) {
      if (r.failure != null) failures.add(r.failure!);
    }
    for (final song in songs) {
      final key = songKey(song.title);
      final number = nonEmpty(song.ccliNumber);
      final status = titles.contains(key) || (number != null && numbers.contains(number))
          ? ImportStatus.inLibrary
          : seen.contains(key) || (number != null && seen.contains('#$number'))
          ? ImportStatus.repeated
          : ImportStatus.fresh;
      seen.add(key);
      if (number != null) seen.add('#$number');
      candidates.add(ImportCandidate(song, status, selected: status == ImportStatus.fresh));
    }
    emit(SongImportReview(candidates: candidates, failures: failures));
  }

  void toggle(int index) {
    final review = state;
    if (review is! SongImportReview) return;
    final next = [...review.candidates];
    next[index] = next[index].withSelected(!next[index].selected);
    emit(review.copyWith(candidates: next));
  }

  /// Ticks or unticks every song with [status].
  void selectWhere(ImportStatus status, bool selected) {
    final review = state;
    if (review is! SongImportReview) return;
    emit(
      review.copyWith(
        candidates: [
          for (final c in review.candidates) c.status == status ? c.withSelected(selected) : c,
        ],
      ),
    );
  }

  void preview(int index) {
    final review = state;
    if (review is SongImportReview) emit(review.copyWith(previewing: index));
  }

  Future<void> import() async {
    final review = state;
    if (review is! SongImportReview) return;
    final chosen = [
      for (final c in review.candidates)
        if (c.selected) c.song,
    ];
    if (chosen.isEmpty) return;

    var done = 0;
    emit(SongImportSaving(0, chosen.length));
    try {
      await _repo.importSongs(
        chosen,
        onProgress: (n) {
          done = n;
          if (!isClosed) emit(SongImportSaving(n, chosen.length));
        },
      );
      if (!isClosed) emit(SongImportDone(imported: chosen.length, failures: review.failures));
    } catch (e) {
      if (isClosed) return;
      emit(
        SongImportDone(
          imported: done,
          failures: review.failures,
          error: e is ApiException ? e.message : '$e',
        ),
      );
    }
  }

  void startOver() => emit(const SongImportIdle());
}

/// A title reduced to what tells two songs apart: no case, no accents, no
/// punctuation, single spaces. "¡Cuán Grande Es Él!" and "Cuan grande es el"
/// are the same song.
String songKey(String title) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final out = StringBuffer();
  for (final ch in title.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    out.write(i == -1 ? ch : to[i]);
  }
  return out
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
