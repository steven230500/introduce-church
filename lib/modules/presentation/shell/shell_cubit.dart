import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  String get label => switch (this) {
    LibraryTab.songs => 'Canciones',
    LibraryTab.bible => 'Biblia',
    LibraryTab.media => 'Media',
    LibraryTab.templates => 'Diseños',
  };
}

class ShellState extends Equatable {
  const ShellState({
    this.section = ShellSection.presenter,
    this.tab = LibraryTab.songs,
    this.dockOpen = true,
  });

  final ShellSection section;
  final LibraryTab tab;

  /// Whether the library dock is expanded. Collapsing it gives the preview the
  /// full width during a service.
  final bool dockOpen;

  ShellState copyWith({ShellSection? section, LibraryTab? tab, bool? dockOpen}) => ShellState(
    section: section ?? this.section,
    tab: tab ?? this.tab,
    dockOpen: dockOpen ?? this.dockOpen,
  );

  @override
  List<Object?> get props => [section, tab, dockOpen];
}

class ShellCubit extends Cubit<ShellState> {
  ShellCubit() : super(const ShellState());

  void goTo(ShellSection section) => emit(state.copyWith(section: section));

  void toggleDock() => emit(state.copyWith(dockOpen: !state.dockOpen));

  /// Selects a dock tab. Also returns to the presenter and opens the dock, so
  /// "add a song" from anywhere lands on the panel that can do it.
  void openLibrary(LibraryTab tab) =>
      emit(state.copyWith(tab: tab, dockOpen: true, section: ShellSection.presenter));
}
