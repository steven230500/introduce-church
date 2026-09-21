import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bible_import/bible_files.dart';
import '../../../core/bible_import/imported_bible.dart';
import '../../../core/bible_import/version_naming.dart';
import '../../../core/local_db/bible_import_service.dart' show bundledBibleCode;
import '../../../core/local_db/bible_repository.dart';

part 'bible_versions_state.dart';

/// A version on this computer, as the dialog lists it.
class InstalledBible extends Equatable {
  const InstalledBible({
    required this.code,
    required this.name,
    required this.bundled,
    required this.complete,
  });

  final String code;
  final String name;

  /// The one that comes with the app. It cannot be removed.
  final bool bundled;

  /// Every book and chapter is there. A download an older build left half
  /// done, or a file with one Testament, is not.
  final bool complete;

  @override
  List<Object?> get props => [code, name, bundled, complete];
}

class BibleVersionsModel extends Equatable {
  const BibleVersionsModel({this.versions = const []});

  /// The church's own first, the included one last.
  final List<InstalledBible> versions;

  bool has(String code) => versions.any((v) => v.code == code);

  @override
  List<Object?> get props => [versions];
}

typedef BibleFileReader = Future<BibleFileResult> Function(String path);

/// The Bibles on this computer, and bringing one in from a file.
///
/// Introduce does not download Bibles: the church brings the file for the
/// version it has the right to use. See [ImportedBible].
class BibleVersionsCubit extends Cubit<BibleVersionsState> {
  BibleVersionsCubit(this._repo, {BibleFileReader? reader})
    : _reader = reader ?? readBibleFile,
      super(const BibleVersionsLoading());

  final BibleRepository _repo;
  final BibleFileReader _reader;

  /// Whether a version was added or removed while the dialog was open, so the
  /// Bible panel knows to read its list again.
  bool changed = false;

  Future<void> load() async {
    final model = await _model();
    if (!isClosed) emit(BibleVersionsIdle(model));
  }

  /// Reads the file at [path] and, when it is a Bible, offers it for review
  /// with a name and a code worked out from it.
  Future<void> open(String path) async {
    final model = state.model;
    emit(BibleVersionsReading(model));
    final result = await _reader(path);
    if (isClosed) return;

    final bible = result.bible;
    if (bible == null) {
      emit(BibleVersionsIdle(model, problem: _problemOf(result.failure?.problem)));
      return;
    }
    emit(
      BibleVersionsReview(
        model,
        bible: bible,
        name: bible.title,
        code: suggestVersionCode(bible.title, abbreviation: bible.abbreviation),
      ),
    );
  }

  /// Saves the Bible under review as [name] with the code [code], and makes
  /// it the one the operator gets: whoever imports a Bible means to use it.
  Future<void> install({required String name, required String code, String? language}) async {
    final review = state;
    if (review is! BibleVersionsReview) return;
    final cleanCode = cleanVersionCode(code);
    final cleanName = name.trim();
    if (!canInstall(name: cleanName, code: cleanCode)) return;

    emit(BibleVersionsSaving(review.model, name: cleanName));
    try {
      await _repo.install(
        review.bible,
        code: cleanCode,
        name: cleanName,
        language: language ?? review.bible.probableLanguage,
      );
      await _repo.rememberVersion(cleanCode);
      changed = true;
      final model = await _model();
      if (!isClosed) emit(BibleVersionsIdle(model, added: cleanCode));
    } catch (e) {
      if (isClosed) return;
      emit(
        BibleVersionsIdle(
          review.model,
          problem: BibleImportProblem.notSaved,
          detail: '$e'.split('\n').first,
        ),
      );
    }
  }

  /// Whether a Bible can be saved under [name] and [code]. The included
  /// version's code is taken: replacing it would leave a church without the
  /// one Bible the app guarantees.
  static bool canInstall({required String name, required String code}) =>
      name.trim().isNotEmpty &&
      cleanVersionCode(code).isNotEmpty &&
      cleanVersionCode(code) != bundledBibleCode;

  /// Whether version [code] can be called [newCode]: not the included one's
  /// code, and not another version's.
  bool canRename(String code, {required String name, required String newCode}) {
    final clean = cleanVersionCode(newCode);
    return name.trim().isNotEmpty &&
        clean.isNotEmpty &&
        clean != bundledBibleCode &&
        (clean == code || !state.model.has(clean));
  }

  /// A new name and code for a version already on this computer, so a Bible
  /// imported as "La Biblia de Las Americas" does not have to be imported
  /// again to be called "LBLA".
  Future<void> rename(String code, {required String name, required String newCode}) async {
    if (!canRename(code, name: name, newCode: newCode)) return;
    final version = state.model.versions.where((v) => v.code == code).firstOrNull;
    if (version == null || version.bundled) return;
    await _repo.rename(code, to: cleanVersionCode(newCode), name: name.trim());
    changed = true;
    final model = await _model();
    if (!isClosed) emit(BibleVersionsIdle(model));
  }

  /// Drops the Bible under review without saving it.
  void cancel() => emit(BibleVersionsIdle(state.model));

  Future<void> delete(String code) async {
    if (state.model.versions.any((v) => v.code == code && v.bundled)) return;
    await _repo.delete(code);
    changed = true;
    final model = await _model();
    if (!isClosed) emit(BibleVersionsIdle(model));
  }

  Future<BibleVersionsModel> _model() async {
    final versions = await _repo.getInstalledVersions();
    final installed = [
      for (final v in versions)
        InstalledBible(
          code: v.code,
          name: v.name,
          bundled: v.isBundled,
          complete: await _repo.isComplete(v),
        ),
    ];
    installed.sort((a, b) {
      if (a.bundled != b.bundled) return a.bundled ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return BibleVersionsModel(versions: installed);
  }

  static BibleImportProblem _problemOf(BibleFileProblem? problem) => switch (problem) {
    BibleFileProblem.unsupported || null => BibleImportProblem.unsupported,
    BibleFileProblem.unreadable => BibleImportProblem.unreadable,
    BibleFileProblem.empty => BibleImportProblem.empty,
  };
}
