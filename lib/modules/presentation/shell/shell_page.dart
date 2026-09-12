import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/widgets/ui/app_buttons.dart';
import '../children/control/presenter/cubit/cubit.dart';
import '../children/control/presenter/page.dart';
import 'collections_library_page.dart';
import 'library/library_dock.dart';
import '../../../core/api/api_client.dart';
import '../../auth/utils/navigator.dart';
import 'org_admin_dialog.dart';
import 'shell_cubit.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/live_bar.dart';
import 'widgets/shortcuts_dialog.dart';

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
        BlocProvider(create: (_) => ShellCubit()),
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

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Transport keys are global, but they must never steal a keystroke from a
  /// text field. Typing the letter B in a song title used to be impossible
  /// because it blanked the projector.
  bool get _isTyping {
    final focused = FocusManager.instance.primaryFocus;
    final widget = focused?.context?.widget;
    return widget is EditableText;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _isTyping) return KeyEventResult.ignored;

    final control = context.read<ControlCubit>();
    final shell = context.read<ShellCubit>();
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.pageDown) {
      control.nextSlide();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      control.prevSlide();
    } else if (key == LogicalKeyboardKey.keyB) {
      control.toggleBlank();
    } else if (key == LogicalKeyboardKey.keyL) {
      control.toggleLive();
    } else if (key == LogicalKeyboardKey.keyG) {
      control.toggleGridView();
    } else if (key == LogicalKeyboardKey.keyF) {
      shell.toggleDock();
    } else if (key == LogicalKeyboardKey.slash && HardwareKeyboard.instance.isShiftPressed) {
      showShortcutsDialog(context);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

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
                builder: (context, shell) => Row(
                  children: [
                    _Sidebar(current: shell.section),
                    const VerticalDivider(width: 1, color: AppColors.divider),
                    Expanded(child: _body(context, shell.section)),
                    if (shell.section == ShellSection.presenter && shell.dockOpen) ...[
                      const VerticalDivider(width: 1, color: AppColors.divider),
                      const LibraryDock(),
                    ],
                  ],
                ),
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
    };
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current});

  final ShellSection current;

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
            label: 'Presentador',
            active: current == ShellSection.presenter,
            onTap: () => shell.goTo(ShellSection.presenter),
          ),
          _SideButton(
            icon: Icons.folder_open_rounded,
            label: 'Colecciones',
            active: current == ShellSection.collections,
            onTap: () => shell.goTo(ShellSection.collections),
          ),
          const Spacer(),
          _SideButton(
            icon: Icons.keyboard_outlined,
            label: 'Atajos de teclado',
            active: false,
            onTap: () => showShortcutsDialog(context),
          ),
          _SideButton(
            icon: Icons.people_rounded,
            label: 'Organización',
            active: false,
            onTap: () => showOrgAdminDialog(context),
          ),
          const _AccountButton(),
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
class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    final user = Modular.get<ApiClient>().currentUser;

    return PopupMenuButton<String>(
      tooltip: user?.email ?? 'Cuenta',
      color: AppColors.surfaceControl,
      position: PopupMenuPosition.over,
      itemBuilder: (_) => [
        if (user != null)
          PopupMenuItem<String>(
            enabled: false,
            height: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.displayName?.isNotEmpty == true)
                  Text(
                    user.displayName!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(user.email, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'password',
          height: 38,
          child: AppMenuRow(icon: Icons.key_outlined, label: 'Cambiar contraseña'),
        ),
        const PopupMenuItem(
          value: 'signout',
          height: 38,
          child: AppMenuRow(icon: Icons.logout_rounded, label: 'Cerrar sesión', danger: true),
        ),
      ],
      onSelected: (value) async {
        if (value == 'password') {
          await showChangePasswordDialog(context);
        } else if (value == 'signout') {
          await Modular.get<ApiClient>().signOut();
          AuthNavigator.goToLogin();
        }
      },
      child: const SizedBox(
        width: AppSizes.sidebarWidth,
        height: 54,
        child: Center(
          child: Icon(Icons.account_circle_outlined, size: 22, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

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
