part of 'bible_versions_cubit.dart';

/// Why the last import did not end with a new version.
enum BibleImportProblem { unsupported, unreadable, empty, notSaved }

sealed class BibleVersionsState extends Equatable {
  const BibleVersionsState(this.model);

  final BibleVersionsModel model;

  @override
  List<Object?> get props => [model];
}

final class BibleVersionsLoading extends BibleVersionsState {
  const BibleVersionsLoading() : super(const BibleVersionsModel());
}

/// The list, with nothing being imported.
final class BibleVersionsIdle extends BibleVersionsState {
  const BibleVersionsIdle(super.model, {this.problem, this.detail, this.added});

  /// Set when the last file could not be read or saved.
  final BibleImportProblem? problem;
  final String? detail;

  /// The code of the version just imported, to mark it in the list.
  final String? added;

  @override
  List<Object?> get props => [model, problem, detail, added];
}

final class BibleVersionsReading extends BibleVersionsState {
  const BibleVersionsReading(super.model);
}

/// A Bible read from a file, waiting for the operator to confirm its name and
/// code before it is saved.
final class BibleVersionsReview extends BibleVersionsState {
  const BibleVersionsReview(
    super.model, {
    required this.bible,
    required this.name,
    required this.code,
  });

  final ImportedBible bible;

  /// What the file suggests; the operator can change both.
  final String name;
  final String code;

  @override
  List<Object?> get props => [model, bible, name, code];
}

final class BibleVersionsSaving extends BibleVersionsState {
  const BibleVersionsSaving(super.model, {required this.name});

  final String name;

  @override
  List<Object?> get props => [model, name];
}
