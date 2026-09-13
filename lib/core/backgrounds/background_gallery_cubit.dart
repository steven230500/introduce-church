import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_client.dart';
import '../models/media_item.dart';
import '../repositories/media_repository.dart';
import 'background_cache.dart';
import 'background_choice.dart';
import 'background_probe.dart';
import 'background_standard.dart';

/// Where adding a background has got to.
sealed class AddingBackground extends Equatable {
  const AddingBackground();
  @override
  List<Object?> get props => [];
}

class NotAdding extends AddingBackground {
  const NotAdding();
}

/// Reading the file's size and length.
class CheckingBackground extends AddingBackground {
  const CheckingBackground();
}

class UploadingBackground extends AddingBackground {
  const UploadingBackground(this.progress);
  final double progress;
  @override
  List<Object?> get props => [progress];
}

/// The file breaks the standard; nothing was sent.
class RefusedBackground extends AddingBackground {
  const RefusedBackground(this.filename, this.problems);
  final String filename;
  final List<BackgroundProblem> problems;
  @override
  List<Object?> get props => [filename, problems];
}

/// It met the standard here but the upload failed, with the server's reason.
class FailedBackground extends AddingBackground {
  const FailedBackground(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class BackgroundGalleryState extends Equatable {
  const BackgroundGalleryState({
    this.loading = true,
    this.items = const [],
    this.loadFailed = false,
    this.selected,
    this.adding = const NotAdding(),
  });

  final bool loading;

  /// The church's own backgrounds, newest first.
  final List<MediaItem> items;

  /// The church's backgrounds could not be listed. The app's own scenes are
  /// still there to choose from.
  final bool loadFailed;

  final BackgroundChoice? selected;
  final AddingBackground adding;

  bool get busy => adding is CheckingBackground || adding is UploadingBackground;

  BackgroundGalleryState copyWith({
    bool? loading,
    List<MediaItem>? items,
    bool? loadFailed,
    BackgroundChoice? selected,
    AddingBackground? adding,
  }) => BackgroundGalleryState(
    loading: loading ?? this.loading,
    items: items ?? this.items,
    loadFailed: loadFailed ?? this.loadFailed,
    selected: selected ?? this.selected,
    adding: adding ?? this.adding,
  );

  @override
  List<Object?> get props => [loading, items, loadFailed, selected, adding];
}

class BackgroundGalleryCubit extends Cubit<BackgroundGalleryState> {
  BackgroundGalleryCubit(
    this._repo, {
    BackgroundProbe probe = const NativeBackgroundProbe(),
    BackgroundCache? cache,
    BackgroundChoice? initial,
  }) : _probe = probe,
       _cache = cache ?? BackgroundCache.instance,
       super(BackgroundGalleryState(selected: initial));

  final MediaRepository _repo;
  final BackgroundProbe _probe;
  final BackgroundCache _cache;

  Future<void> load() async {
    try {
      final items = await _repo.listBackgrounds();
      if (isClosed) return;
      emit(state.copyWith(loading: false, items: items, loadFailed: false));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, loadFailed: true));
    }
  }

  void select(BackgroundChoice choice) => emit(state.copyWith(selected: choice));

  /// Lets go of a refusal or a failure, once the operator has read it.
  void dismiss() => emit(state.copyWith(adding: const NotAdding()));

  /// Checks [path] against the standard and, if it meets it, adds it to the
  /// church's backgrounds and selects it.
  ///
  /// Nothing is sent for a file that breaks the standard: the operator is told
  /// everything wrong with it here, before any waiting on a transfer.
  Future<MediaItem?> add(String path) async {
    if (state.busy) return null;
    emit(state.copyWith(adding: const CheckingBackground()));

    final candidate = await _probe.read(path);
    final problems = checkBackground(candidate);
    // The plan's own ceiling can be lower than the standard's, and it is the
    // one the server will hold the upload to.
    try {
      final usage = await _repo.usage();
      if (usage.maxUploadBytes > 0 &&
          candidate.bytes > usage.maxUploadBytes &&
          !problems.any((p) => p is TooHeavy)) {
        problems.add(TooHeavy(candidate.bytes, usage.maxUploadBytes));
      }
    } catch (_) {
      // Unknown room is the server's to judge.
    }
    if (isClosed) return null;
    if (problems.isNotEmpty) {
      emit(state.copyWith(adding: RefusedBackground(File(path).uri.pathSegments.last, problems)));
      return null;
    }

    File? poster;
    if (candidate.kind == BackgroundKind.video) {
      poster = await _probe.poster(path);
      if (isClosed) return null;
    }

    emit(state.copyWith(adding: const UploadingBackground(0)));
    try {
      final item = await _repo.uploadBackground(
        candidate,
        poster: poster,
        onProgress: (progress) {
          if (!isClosed) emit(state.copyWith(adding: UploadingBackground(progress)));
        },
      );
      // The bytes are already on this machine; the projector should not have
      // to download them back.
      await _cache.adopt(item.url, File(path));
      if (poster != null && item.posterUrl != null) await _cache.adopt(item.posterUrl!, poster);
      if (isClosed) return item;
      emit(
        state.copyWith(
          items: [item, ...state.items],
          selected: BackgroundChoice.fromItem(item),
          adding: const NotAdding(),
        ),
      );
      return item;
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(adding: FailedBackground(e.message)));
      return null;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(adding: FailedBackground('$e')));
      return null;
    } finally {
      if (poster != null && await poster.exists()) await poster.delete();
    }
  }

  /// Removes a background from the church's library.
  Future<bool> remove(MediaItem item) async {
    try {
      await _repo.delete(item);
    } catch (_) {
      return false;
    }
    if (isClosed) return true;
    final removed = BackgroundChoice.fromItem(item);
    emit(
      BackgroundGalleryState(
        loading: state.loading,
        items: [
          for (final i in state.items)
            if (i.id != item.id) i,
        ],
        loadFailed: state.loadFailed,
        selected: state.selected == removed ? null : state.selected,
        adding: state.adding,
      ),
    );
    return true;
  }
}
