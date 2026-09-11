import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';

void main() {
  late ShellCubit cubit;

  setUp(() => cubit = ShellCubit());
  tearDown(() => cubit.close());

  test('opens on the presenter with the library visible', () {
    expect(cubit.state.section, ShellSection.presenter);
    expect(cubit.state.dockOpen, isTrue);
    expect(cubit.state.tab, LibraryTab.songs);
  });

  test('moving to collections leaves the library tab alone', () {
    cubit.openLibrary(LibraryTab.bible);

    cubit.goTo(ShellSection.collections);

    expect(cubit.state.section, ShellSection.collections);
    expect(cubit.state.tab, LibraryTab.bible);
  });

  test('opening a library returns to the presenter and reveals the dock', () {
    cubit.goTo(ShellSection.collections);
    cubit.toggleDock();

    cubit.openLibrary(LibraryTab.media);

    expect(cubit.state.section, ShellSection.presenter);
    expect(cubit.state.dockOpen, isTrue);
    expect(cubit.state.tab, LibraryTab.media);
  });

  test('the dock toggle goes both ways', () {
    cubit.toggleDock();
    expect(cubit.state.dockOpen, isFalse);

    cubit.toggleDock();
    expect(cubit.state.dockOpen, isTrue);
  });

  test('every library tab has a Spanish label', () {
    expect(
      LibraryTab.values.map((t) => t.label),
      ['Canciones', 'Biblia', 'Media', 'Diseños'],
    );
  });
}
