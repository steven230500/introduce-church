import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../core/models/labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../children/control/presenter/cubit/cubit.dart';
import '../children/control/presenter/page.dart';
import 'collections_library_page.dart';
import 'history_page.dart';
import 'library/library_dock.dart';
import '../../../core/history/projection_recorder.dart';
import '../../../core/remote/remote_control.dart';
import '../../../core/services/app_prefs_service.dart';
import '../../../core/services/update_checker.dart';
import '../../../core/services/usage_reporter.dart';
import '../../../l10n/l10n.dart';
import '../../../core/widgets/ui/panel_resizer.dart';
import '../../../core/widgets/ui/typing.dart';
import 'org_admin_dialog.dart';
import 'shell_cubit.dart';
import 'widgets/command_palette.dart';
import 'widgets/live_bar.dart';
import 'widgets/remote_dialog.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/quick_verse_dialog.dart';
import 'widgets/slide_editor_dialog.dart';
import 'widgets/shortcuts_dialog.dart';
import 'widgets/update_dialog.dart';

/// Application frame.
///
/// The live bar sits above everything and the library docks beside the
/// presenter, so the operator can browse content without ever losing sight of
/// what is on the projector or the controls that change it.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ShellCubit(prefs: Modular.get<AppPrefsService>())..restoreLayout(),
        ),
        BlocProvider(create: (_) => Modular.get<ControlCubit>()..load()),
      ],
      child: const _ShellScaffold(),
    );
  }
}

class _ShellScaffold extends StatefulWidget {
  const _ShellScaffold();

  @override
  State<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<_ShellScaffold> {
  final _focusNode = FocusNode(debugLabel: 'shell');

  /// Writes down what goes on the screen, for the history and the licence
  /// report. Lives exactly as long as the presenter does.
  late final ProjectionRecorder _recorder = ProjectionRecorder(
    context.read<ControlCubit>(),
    Modular.get<HistoryRepository>(),
    Modular.get<ProjectionOutbox>(),
  )..start();

  /// Phones on this network, when the operator has allowed them. Lives as
  /// long as the presenter, like the recorder.
  late final RemoteControl _remote = RemoteControl(
    context.read<ControlCubit>(),
    Modular.get<AppPrefsService>(),
  );

  /// Whether a newer version is out. Asked while the presenter is open, which
  /// is whenever the app is in use.
  final UpdateChecker _updates = Modular.get<UpdateChecker>();

  /// The anonymous "a copy is in use" count. Started here, where there is a
  /// session, so the count knows which church the copy belongs to.
  final UsageReporter _usage = Modular.get<UsageReporter>();

  /// Quitting the app with a song still on the screen must still record that
  /// song, and dispose() is not guaranteed to run on the way out.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onExitRequested: () async {
      await _recorder.stop();
      await _remote.dispose();
      return AppExitResponse.exit;
    },
  );

  @override
  void initState() {
    super.initState();
    // Touching both starts them.
    _recorder;
    _lifecycle;
    unawaited(_remote.restore());
    _control.keepRetrying();
    _updates.start();
    _usage.start();
    FocusManager.instance.addListener(_keepKeyboard);
  }

  /// Held rather than looked up again in dispose, where the tree it would be
  /// looked up in is already coming down.
  late final ControlCubit _control = context.read<ControlCubit>();

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepKeyboard);
    _control.stopRetrying();
    _updates.stop();
    _usage.stop();
    unawaited(_recorder.stop());
    unawaited(_remote.dispose());
    _lifecycle.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Transport keys are global, but they must never steal a keystroke from a
  /// text field. Typing the letter B in a song title used to be impossible
  /// because it blanked the projector.
  bool get _isTyping => isTyping();

  /// Hands the keyboard back to the service.
  ///
  /// The guard above keeps typing from running the service. It is not enough
  /// on its own: the focus stays in the search box until something takes it,
  /// and when the box goes away - another library tab, a chapter opened from
  /// a search - the focus is left on no one at all, which puts this handler
  /// off the path the keys travel. Either way the operator searched a song
  /// and the arrows stopped passing slides.
  /// Takes the keyboard back whenever nobody is holding it: a search box that
  /// closed with the panel it was in, a menu that went away. The keys of a
  /// service have to work without the operator knowing what a focus is.
  void _keepKeyboard() {
    if (!mounted) return;
    final focus = FocusManager.instance.primaryFocus;
    // Somebody is typing or has the keyboard for a reason.
    if (focus != null && focus is! FocusScopeNode) return;
    // A dialog is open: the keyboard is its own.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (_focusNode.hasFocus) return;
    scheduleMicrotask(() {
      if (mounted && !_focusNode.hasFocus) _focusNode.requestFocus();
    });
  }

  void _takeKeyboard() {
    if (_isTyping) FocusManager.instance.primaryFocus?.unfocus();
    if (!_focusNode.hasPrimaryFocus) _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Before the typing guard on purpose: the search is the one thing an
    // operator reaches for while the cursor is already sitting in a field.
    if (key == LogicalKeyboardKey.keyK &&
        (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed)) {
      showCommandPalette(context);
      return KeyEventResult.handled;
    }

    if (_isTyping) {
      // Escape is how you leave a box you are typing in. On the service it
      // uncovers the screen; here it gives the keys back.
      if (key == LogicalKeyboardKey.escape) {
        _takeKeyboard();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final control = context.read<ControlCubit>();
    final shell = context.read<ShellCubit>();

    // Before the arrows that pass slides: the same keys with Option held move
    // the words on the screen instead of moving through the service.
    if (HardwareKeyboard.instance.isAltPressed &&
        (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown)) {
      final design = control.state is ControlLoadedState
          ? (control.state as ControlLoadedState).model.liveTemplate
          : null;
      if (design == null) return KeyEventResult.ignored;
      control.nudgeLiveText(
        key == LogicalKeyboardKey.arrowUp ? -_textNudge : _textNudge,
        copyName: L10n.of(context).designAdjustedSuffix(design.nameIn(L10n.of(context))),
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.pageDown) {
      control.nextSlide();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      control.prevSlide();
    } else if (key == LogicalKeyboardKey.home) {
      control.selectSlide(0);
    } else if (key == LogicalKeyboardKey.end) {
      control.lastSlide();
    } else if (key == LogicalKeyboardKey.escape) {
      // Only ever uncovers the screen. Escape is what someone presses when
      // they do not know what else to press, so it must not be able to cut
      // the projector.
      control.clearBlank();
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      // Does nothing while the screen follows the cursor, so it is safe to
      // press out of habit.
      control.take();
    } else if (key == LogicalKeyboardKey.keyV) {
      showQuickVerseDialog(context);
    } else if (key == LogicalKeyboardKey.keyE) {
      showSlideEditor(context);
    } else if (key == LogicalKeyboardKey.keyM) {
      control.jumpMoment(forward: !HardwareKeyboard.instance.isShiftPressed);
    } else if (key == LogicalKeyboardKey.keyK) {
      control.toggleFollowCursor();
    } else if (key == LogicalKeyboardKey.keyB) {
      control.toggleBlank();
    } else if (key == LogicalKeyboardKey.keyW) {
      // The last waiting screen, back up or down, without opening the picker.
      control.toggleWaiting();
    } else if (key == LogicalKeyboardKey.keyL) {
      control.toggleLive();
    } else if (key == LogicalKeyboardKey.keyG) {
      control.toggleGridView();
    } else if (key == LogicalKeyboardKey.keyF) {
      shell.toggleDock();
    } else if (key == LogicalKeyboardKey.slash && HardwareKeyboard.instance.isShiftPressed) {
      showShortcutsDialog(context);
    } else if (_itemNumber(key) case final number?) {
      // Jumping to the fourth item took a scroll and a click, mid-service,
      // while the congregation watched the wrong slide. The fourth item is
      // the fourth thing that goes on the screen, whatever marks divide them.
      control.selectPlayable(number);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// How far one press moves the text, as a share of the slide's height. Two
  /// per cent is about a line, which is what "a little higher" means.
  static const _textNudge = 0.02;

  /// The set list position a number key names, or null for any other key.
  static int? _itemNumber(LogicalKeyboardKey key) {
    final index = _digits.indexOf(key);
    return index == -1 ? null : index + 1;
  }

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const LiveBar(),
            Expanded(
              child: BlocBuilder<ShellCubit, ShellState>(
                builder: (context, shell) {
                  final inPresenter = shell.section == ShellSection.presenter;
                  final showDock = inPresenter && shell.dockOpen;
                  final dockWidth = shell.widthOf(ShellPanel.dock);
                  final layout = context.read<ShellCubit>();

                  return Row(
                    children: [
                      _Sidebar(current: shell.section, remote: _remote, updates: _updates),
                      const VerticalDivider(width: 1, color: AppColors.divider),
                      Expanded(
                        // A pointer route, not a tap: the press is seen even
                        // when the row or the slide under it handles the tap.
                        child: Listener(
                          onPointerDown: (_) => _takeKeyboard(),
                          child: _body(context, shell.section),
                        ),
                      ),
                      if (showDock)
                        PanelResizer(
                          tooltip: L10n.of(context).resizeHint,
                          // The dock's edge is on its left, so dragging left
                          // is what makes it wider.
                          onDrag: (dx) => layout.resizePanel(ShellPanel.dock, -dx),
                          onReset: () => layout.resetPanel(ShellPanel.dock),
                        ),
                      // Slides out rather than vanishing. Half the window used
                      // to change shape between one frame and the next, which
                      // reads as a glitch rather than as a panel closing.
                      AnimatedContainer(
                        duration: AppMotion.slow,
                        curve: Curves.easeOutCubic,
                        width: showDock ? dockWidth : 0,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: dockWidth,
                            maxWidth: dockWidth,
                            child: LibraryDock(width: dockWidth),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ShellSection section) {
    return switch (section) {
      ShellSection.presenter => const ControlPage(),
      ShellSection.collections => CollectionsLibraryPage(
        onOpenCollection: () => context.read<ShellCubit>().goTo(ShellSection.presenter),
      ),
      ShellSection.history => const HistoryPage(),
    };
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current, required this.remote, required this.updates});

  final ShellSection current;
  final RemoteControl remote;
  final UpdateChecker updates;

  @override
  Widget build(BuildContext context) {
    final shell = context.read<ShellCubit>();
    return Container(
      width: AppSizes.sidebarWidth,
      color: AppColors.chrome,
      child: Column(
        children: [
          const SizedBox(height: AppSpace.lg),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.lg),
            child: Image.asset('assets/images/casavida-isologo-white.png', width: 32, height: 32),
          ),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: AppSpace.sm),
          _SideButton(
            icon: Icons.slideshow_rounded,
            label: L10n.of(context).sidePresenter,
            active: current == ShellSection.presenter,
            onTap: () => shell.goTo(ShellSection.presenter),
          ),
          _SideButton(
            icon: Icons.folder_open_rounded,
            label: L10n.of(context).sideCollections,
            active: current == ShellSection.collections,
            onTap: () => shell.goTo(ShellSection.collections),
          ),
          _SideButton(
            icon: Icons.history_rounded,
            label: L10n.of(context).sideHistory,
            active: current == ShellSection.history,
            onTap: () => shell.goTo(ShellSection.history),
          ),
          const Spacer(),
          // Only there while a newer version is out, and only ever opened by
          // hand, so it can wait for the end of the service.
          ValueListenableBuilder<AvailableUpdate?>(
            valueListenable: updates.available,
            builder: (context, update, _) => update == null
                ? const SizedBox.shrink()
                : _SideButton(
                    icon: Icons.system_update_alt_rounded,
                    label: L10n.of(context).updateAvailable,
                    active: true,
                    onTap: () => showUpdateDialog(context, update),
                  ),
          ),
          // Lit while phones are allowed in, so a remote left on is never
          // forgotten.
          ValueListenableBuilder<RemoteStatus>(
            valueListenable: remote.status,
            builder: (context, status, _) => _SideButton(
              icon: Icons.phonelink_ring_outlined,
              label: L10n.of(context).sideRemote,
              active: status.enabled,
              onTap: () => showRemoteDialog(context, remote),
            ),
          ),
          _SideButton(
            icon: Icons.keyboard_outlined,
            label: L10n.of(context).shortcutsTitle,
            active: false,
            onTap: () => showShortcutsDialog(context),
          ),
          _SideButton(
            icon: Icons.people_rounded,
            label: L10n.of(context).sideOrganization,
            active: false,
            onTap: () => showOrgAdminDialog(context),
          ),
          // Account, language and the projector screen live together here:
          // they belong to this computer, not to the service on it.
          _SideButton(
            icon: Icons.settings_outlined,
            label: L10n.of(context).settingsTitle,
            active: false,
            onTap: () => showSettingsDialog(context, context.read<ControlCubit>()),
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    );
  }
}

/// The account menu: who is signed in, change password, sign out.
///
/// These used to have nowhere to live, so an operator could not change their
/// password or hand the machine to someone else without editing a file.
class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppSizes.sidebarWidth,
          height: 54,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? AppColors.accentFill : Colors.transparent,
                borderRadius: AppRadius.all(AppRadius.lg),
              ),
              child: Icon(icon, size: 22, color: active ? AppColors.accent : AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
