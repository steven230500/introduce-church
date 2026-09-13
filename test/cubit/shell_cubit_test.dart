import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/modules/presentation/shell/shell_cubit.dart';

import '../helpers/fakes.dart';

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

  group('panel widths', () {
    test('start at the widths the layout was designed around', () {
      for (final panel in ShellPanel.values) {
        expect(cubit.state.widthOf(panel), panel.defaultWidth);
      }
    });

    test('a drag moves the edge', () {
      cubit.resizePanel(ShellPanel.setList, 60);

      expect(cubit.state.widthOf(ShellPanel.setList), ShellPanel.setList.defaultWidth + 60);
    });

    test('no drag can leave a panel unusable', () {
      // A panel squeezed to nothing, or grown until the preview is a sliver,
      // is a layout an operator cannot get back from mid-service.
      cubit.resizePanel(ShellPanel.dock, -5000);
      expect(cubit.state.widthOf(ShellPanel.dock), ShellPanel.dock.limits.$1);

      cubit.resizePanel(ShellPanel.dock, 5000);
      expect(cubit.state.widthOf(ShellPanel.dock), ShellPanel.dock.limits.$2);
    });

    test('a double click puts one panel back without touching the others', () {
      cubit.resizePanel(ShellPanel.setList, 50);
      cubit.resizePanel(ShellPanel.queue, 30);

      cubit.resetPanel(ShellPanel.setList);

      expect(cubit.state.widthOf(ShellPanel.setList), ShellPanel.setList.defaultWidth);
      expect(cubit.state.widthOf(ShellPanel.queue), ShellPanel.queue.defaultWidth + 30);
    });

    test('the widths come back on the next launch', () async {
      final prefs = FakePrefsService();
      final first = ShellCubit(prefs: prefs);
      first.resizePanel(ShellPanel.setList, 40);
      // The write is debounced, because a drag fires on every frame.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await first.close();

      final next = ShellCubit(prefs: prefs);
      await next.restoreLayout();

      expect(next.state.widthOf(ShellPanel.setList), ShellPanel.setList.defaultWidth + 40);
      await next.close();
    });

    test('a stored width from an older layout is brought inside the limits', () async {
      final prefs = FakePrefsService();
      await prefs.saveLayout({'setList': 4000, 'queue': 10});
      final restored = ShellCubit(prefs: prefs);

      await restored.restoreLayout();

      expect(restored.state.widthOf(ShellPanel.setList), ShellPanel.setList.limits.$2);
      expect(restored.state.widthOf(ShellPanel.queue), ShellPanel.queue.limits.$1);
      await restored.close();
    });
  });

  test('every library tab has a Spanish label', () {
    expect(LibraryTab.values.map((t) => t.label), ['Canciones', 'Biblia', 'Media', 'Diseños']);
  });
}
