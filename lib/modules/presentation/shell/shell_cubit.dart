import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/l10n.dart';

import '../../../core/services/app_prefs_service.dart';
import '../../../core/theme/app_dimens.dart';

/// Top-level destinations.
///
/// Deliberately only two. The presenter is where a service is run, and
/// collections is where services are planned. Everything else is a library, and
/// libraries live in the dock beside the presenter so the operator never has to
/// leave the controls to find content.
enum ShellSection { presenter, collections }

/// Tabs inside the library dock.
enum LibraryTab { songs, bible, media, templates }

extension LibraryTabX on LibraryTab {
  /// Takes the strings rather than reading a context: an enum extension has
  /// no context, and the tab strip that draws these does.
  String label(L10n t) => switch (this) {
    LibraryTab.songs => t.tabSongs,
    LibraryTab.bible => t.tabBible,
    LibraryTab.media => t.tabMedia,
    LibraryTab.templates => t.tabDesigns,
  };
}

/// A column the operator can drag wider or narrower.
enum ShellPanel { setList, queue, dock }

extension ShellPanelX on ShellPanel {
  /// The width this panel starts at, and returns to on a double click.
  double get defaultWidth => switch (this) {
    ShellPanel.setList => AppSizes.setListWidth,
    ShellPanel.queue => AppSizes.queueWidth,
    ShellPanel.dock => AppSizes.dockWidth,
  };

  /// Limits, so no drag can leave a panel unusable or squeeze the preview out.
  (double min, double max) get limits => switch (this) {
    ShellPanel.setList => (220, 460),
    ShellPanel.queue => (200, 400),
    ShellPanel.dock => (240, 480),
  };
}

class ShellState extends Equatable {
  const ShellState({
    this.section = ShellSection.presenter,
    this.tab = LibraryTab.songs,
    this.dockOpen = true,
    this.widths = const {},
  });

  final ShellSection section;
  final LibraryTab tab;

  /// Whether the library dock is expanded. Collapsing it gives the preview the
  /// full width during a service.
  final bool dockOpen;

  /// Panel widths the operator has chosen. Anything absent is at its default.
  final Map<ShellPanel, double> widths;

  double widthOf(ShellPanel panel) => widths[panel] ?? panel.defaultWidth;

  ShellState copyWith({
    ShellSection? section,
    LibraryTab? tab,
    bool? dockOpen,
    Map<ShellPanel, double>? widths,
  }) => ShellState(
    section: section ?? this.section,
    tab: tab ?? this.tab,
    dockOpen: dockOpen ?? this.dockOpen,
    widths: widths ?? this.widths,
  );

  @override
  List<Object?> get props => [section, tab, dockOpen, widths];
}

class ShellCubit extends Cubit<ShellState> {
  ShellCubit({AppPrefsService? prefs}) : _prefs = prefs, super(const ShellState());

  final AppPrefsService? _prefs;
  Timer? _saveTimer;

  void goTo(ShellSection section) => emit(state.copyWith(section: section));

  void toggleDock() => emit(state.copyWith(dockOpen: !state.dockOpen));

  /// Selects a dock tab. Also returns to the presenter and opens the dock, so
  /// "add a song" from anywhere lands on the panel that can do it.
  void openLibrary(LibraryTab tab) =>
      emit(state.copyWith(tab: tab, dockOpen: true, section: ShellSection.presenter));

  /// Reads back the widths this operator last dragged to.
  Future<void> restoreLayout() async {
    final stored = await _prefs?.loadLayout();
    if (stored == null || stored.isEmpty || isClosed) return;

    final widths = <ShellPanel, double>{};
    for (final panel in ShellPanel.values) {
      final width = stored[panel.name];
      if (width == null) continue;
      final (min, max) = panel.limits;
      widths[panel] = width.clamp(min, max);
    }
    if (widths.isNotEmpty) emit(state.copyWith(widths: widths));
  }

  /// Moves one edge by [delta] pixels, within the panel's limits.
  void resizePanel(ShellPanel panel, double delta) {
    final (min, max) = panel.limits;
    final next = (state.widthOf(panel) + delta).clamp(min, max);
    if (next == state.widthOf(panel)) return;
    emit(state.copyWith(widths: {...state.widths, panel: next}));
    _scheduleSave();
  }

  /// Puts one panel back where it started.
  void resetPanel(ShellPanel panel) {
    if (!state.widths.containsKey(panel)) return;
    final widths = Map<ShellPanel, double>.from(state.widths)..remove(panel);
    emit(state.copyWith(widths: widths));
    _scheduleSave();
  }

  /// A drag fires on every frame, so the file is written once the operator
  /// lets go rather than sixty times a second.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    await _prefs?.saveLayout({
      for (final entry in state.widths.entries) entry.key.name: entry.value,
    });
  }

  @override
  Future<void> close() {
    _saveTimer?.cancel();
    return super.close();
  }
}
