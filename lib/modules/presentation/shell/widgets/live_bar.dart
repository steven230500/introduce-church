import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../shell_cubit.dart';

/// The always-visible control bar at the top of the window.
///
/// It lives in the shell, not in the presenter, because the operator must be
/// able to go black or cut the feed while browsing a library. Previously these
/// controls disappeared the moment you opened the Bible, which is the single
/// most dangerous thing the old layout did.
class LiveBar extends StatelessWidget {
  const LiveBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      builder: (context, state) {
        final model = state is ControlLoadedState ? state.model : null;
        final enabled = model != null;
        final cubit = context.read<ControlCubit>();

        return LayoutBuilder(
          builder: (context, constraints) {
            // Label budget, spent where confusion is worst.
            //
            // The two output buttons are always labelled: they open different
            // windows for different audiences, and no pair of icons makes that
            // difference readable. The screen-state trio earns labels once the
            // window is wide enough to hold them; its icons carry meaning on
            // their own. The library toggle never gets one, because a split
            // panel glyph already looks like the panel it opens.
            //
            // Both thresholds sit below the minimum window width, so in
            // practice every button is labelled. They only bite if a future
            // layout puts the bar somewhere narrower. The old state threshold
            // was 1180 against a window that opened at 1152, so the three
            // buttons an operator most needs to read were the three that never
            // said anything.
            final width = constraints.maxWidth;
            final labelOutputs = width >= 960;
            final labelState = width >= 1100;

            return Container(
              height: AppSizes.liveBarHeight,
              color: AppColors.chrome,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Row(
                children: [
                  // Only the inert half of the bar drags the window. Wrapping
                  // the controls too puts an ancestor double-tap recogniser
                  // above every button, and each one then sits dead for the
                  // length of the double-tap window before it fires.
                  Expanded(
                    child: DragToMoveArea(
                      child: Row(
                        children: [
                          // Room for the macOS traffic-light buttons.
                          const SizedBox(width: 88),
                          // Flexible, so the name gives way before the bar
                          // overflows. The controls on the right grow with the
                          // features; the word "Introduce" is the one thing
                          // here nobody needs to read twice.
                          const Flexible(child: _AppMark()),
                          const SizedBox(width: AppSpace.lg),
                          Expanded(flex: 4, child: _NowShowing(model: model)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),

                  if (model?.offline == true) ...[
                    const _OfflineChip(),
                    const SizedBox(width: AppSpace.md),
                  ],

                  // ── What the congregation sees ────────────────────────────
                  AppButtonGroup(
                    children: [
                      AppIconButton(
                        icon: Icons.timer_outlined,
                        label: labelState ? 'Cuenta' : null,
                        tooltip: model?.countdownActive == true
                            ? 'Detener la cuenta regresiva'
                            : 'Mostrar una cuenta regresiva en pantalla',
                        active: model?.countdownActive ?? false,
                        activeColor: AppColors.warning,
                        onTap: !enabled
                            ? null
                            : () {
                                if (model.countdownActive) {
                                  cubit.stopCountdown();
                                } else {
                                  showCountdownDialog(context, cubit);
                                }
                              },
                      ),
                      AppIconButton(
                        icon: Icons.subtitles_outlined,
                        label: labelState ? 'Aviso' : null,
                        tooltip: model?.overlayVisible == true
                            ? 'Quitar el aviso sobre el slide'
                            : 'Escribir un aviso sobre el slide',
                        active: model?.overlayVisible ?? false,
                        activeColor: AppColors.success,
                        onTap: !enabled ? null : () => handleOverlay(context, model),
                      ),
                      AppIconButton(
                        icon: Icons.visibility_off_outlined,
                        label: labelState ? 'Negro' : null,
                        tooltip: 'Poner la pantalla en negro  ·  B',
                        active: model?.blankScreen ?? false,
                        activeColor: AppColors.textMuted,
                        onTap: enabled ? cubit.toggleBlank : null,
                      ),
                    ],
                  ),

                  const AppVerticalDivider(),

                  // ── Extra windows ─────────────────────────────────────────
                  AppButtonGroup(
                    children: [
                      AppIconButton(
                        icon: Icons.present_to_all_outlined,
                        label: labelOutputs ? 'Proyector' : null,
                        tooltip: 'Abrir la ventana de proyección para el público',
                        onTap: enabled ? cubit.openDisplayWindow : null,
                      ),
                      AppIconButton(
                        icon: Icons.co_present_outlined,
                        label: labelOutputs ? 'Escenario' : null,
                        tooltip: 'Abrir el monitor con notas para el equipo',
                        onTap: enabled ? cubit.openStageMonitor : null,
                      ),
                    ],
                  ),

                  const AppVerticalDivider(),

                  // ── Whether the screen follows the operator ───────────────
                  AppIconButton(
                    icon: model?.followCursor == false
                        ? Icons.link_off_rounded
                        : Icons.link_rounded,
                    label: labelState
                        ? (model?.followCursor == false ? 'Retenido' : 'Sigue')
                        : null,
                    tooltip: model?.followCursor == false
                        ? 'La pantalla está retenida. Vuelve a seguir lo que eliges  ·  K'
                        : 'La pantalla sigue lo que eliges. Reténla para buscar sin cortar  ·  K',
                    active: model?.followCursor == false,
                    activeColor: AppColors.warning,
                    onTap: enabled ? cubit.toggleFollowCursor : null,
                  ),

                  const AppVerticalDivider(),

                  const _DockToggle(),
                  const SizedBox(width: AppSpace.md),
                  // Only there when it means something. A send button that is
                  // always present is one an operator learns to ignore.
                  if (model?.isHolding == true) ...[
                    _TakeButton(onTap: cubit.take),
                    const SizedBox(width: AppSpace.sm),
                  ],
                  _LiveButton(
                    isLive: model?.isLive ?? false,
                    onTap: enabled ? cubit.toggleLive : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── App mark ──────────────────────────────────────────────────────────────────

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.all(AppRadius.xs + 1),
          ),
          child: const Icon(Icons.church_rounded, size: 13, color: Colors.white),
        ),
        // The gap belongs to the name, so it goes when the name does. Left
        // outside, the glyph plus a fixed gap was still wider than the room
        // this is given at the tightest width.
        const Flexible(
          child: Padding(
            padding: EdgeInsets.only(left: AppSpace.sm),
            child: Text(
              'Introduce',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Context readout ───────────────────────────────────────────────────────────

/// Names the collection and the slide currently on the projector.
///
/// Without this the operator has no way to tell what is being shown while
/// looking at a library, which is how people lost their place. It reports the
/// live position, never the cursor: this line is the answer to "what are they
/// seeing right now".
class _NowShowing extends StatelessWidget {
  const _NowShowing({required this.model});

  final ControlModel? model;

  @override
  Widget build(BuildContext context) {
    final collection = model?.activeCollection;
    if (collection == null) {
      return const Text(
        'Sin colección activa',
        style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
      );
    }

    final item = model!.liveItem;
    final slideCount = item?.slides.length ?? 0;
    final position = slideCount == 0 ? '' : '${model!.liveSlideIndex + 1}/$slideCount';

    // One run of text rather than a row of pieces. As separate children the
    // icon, the separator and the position were not flexible, so the moment
    // the controls on the right grew the whole line overflowed instead of
    // shortening.
    return Text.rich(
      TextSpan(
        children: [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: AppSpace.sm - 2),
              child: Icon(Icons.folder_outlined, size: 13, color: AppColors.textMuted),
            ),
          ),
          TextSpan(text: collection.name),
          if (item != null) ...[
            const TextSpan(
              text: '  •  ',
              style: TextStyle(color: AppColors.textDisabled),
            ),
            TextSpan(
              text: item.displayTitle,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
            if (position.isNotEmpty)
              TextSpan(
                text: '   $position',
                style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
              ),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
    );
  }
}

// ── Dock toggle ───────────────────────────────────────────────────────────────

class _DockToggle extends StatelessWidget {
  const _DockToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShellCubit, ShellState>(
      buildWhen: (a, b) => a.dockOpen != b.dockOpen || a.section != b.section,
      builder: (context, shell) {
        final inPresenter = shell.section == ShellSection.presenter;
        return AppIconButton(
          icon: shell.dockOpen ? Icons.vertical_split_rounded : Icons.view_sidebar_rounded,
          tooltip: shell.dockOpen ? 'Ocultar la biblioteca  ·  F' : 'Mostrar la biblioteca  ·  F',
          active: shell.dockOpen && inPresenter,
          // Subtle: this moves a panel, it does not change what is projected.
          // A solid fill here competed with the live button for attention.
          subtle: true,
          onTap: context.read<ShellCubit>().toggleDock,
        );
      },
    );
  }
}

// ── Offline ───────────────────────────────────────────────────────────────────

/// Says the machine cannot reach the server.
///
/// Not an error: the plan, the designs and the Bible are all on this disk and
/// the service runs from them. What it warns about is the other half, because
/// an operator who removes an item and sees nothing happen has no other way to
/// find out why.
class _OfflineChip extends StatelessWidget {
  const _OfflineChip();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'El servicio corre igual: el plan está guardado en esta máquina.\n'
          'Lo que edites ahora no se guarda hasta que vuelva la conexión.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.16),
          borderRadius: AppRadius.all(AppRadius.sm),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 13, color: AppColors.warning),
            SizedBox(width: AppSpace.sm - 2),
            Text(
              'Sin conexión',
              style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Take button ───────────────────────────────────────────────────────────────

/// Sends what the operator is looking at to the projector.
class _TakeButton extends StatelessWidget {
  const _TakeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Enviar a la pantalla lo que estás viendo  ·  Enter',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.all(AppRadius.sm + 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.send_rounded, size: 13, color: Colors.white),
              SizedBox(width: AppSpace.sm - 2),
              Text(
                'Enviar',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Live button ───────────────────────────────────────────────────────────────

class _LiveButton extends StatelessWidget {
  const _LiveButton({required this.isLive, required this.onTap});

  final bool isLive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isLive ? 'Cortar la señal al proyector' : 'Enviar la señal al proyector',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isLive ? AppColors.live : AppColors.surfaceControl,
            borderRadius: AppRadius.all(AppRadius.sm + 1),
            border: Border.all(color: isLive ? AppColors.live : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.normal,
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isLive ? Colors.white : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                isLive ? 'EN VIVO' : 'En vivo',
                style: TextStyle(
                  color: isLive ? Colors.white : AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: isLive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: isLive ? 0.5 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Countdown ─────────────────────────────────────────────────────────────────

Future<void> showCountdownDialog(BuildContext context, ControlCubit cubit) async {
  int? picked;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _CountdownDialog(
      onConfirm: (seconds) {
        picked = seconds;
        Navigator.pop(ctx);
      },
    ),
  );
  if (picked != null) cubit.startCountdown(picked!);
}

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({required this.onConfirm});

  final void Function(int seconds) onConfirm;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  final _ctrl = TextEditingController();
  static const _presets = [5, 10, 15, 20, 30];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(int minutes) => widget.onConfirm(minutes * 60);

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Cuenta regresiva',
      icon: Icons.timer_outlined,
      width: 340,
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Presets', style: TextStyle(color: kTextMuted, fontSize: 11)),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            children: _presets
                .map(
                  (m) => ActionChip(
                    label: Text('$m min'),
                    backgroundColor: kDialogSurface,
                    labelStyle: const TextStyle(color: kTextPrimary, fontSize: 12),
                    onPressed: () => _submit(m),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpace.lg),
          const Text('Personalizado (minutos)', style: TextStyle(color: kTextMuted, fontSize: 11)),
          const SizedBox(height: AppSpace.sm - 2),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _ctrl,
                  hintText: '0',
                  onSubmitted: (v) {
                    final m = int.tryParse(v);
                    if (m != null && m > 0) _submit(m);
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              FilledButton(
                onPressed: () {
                  final m = int.tryParse(_ctrl.text);
                  if (m != null && m > 0) _submit(m);
                },
                child: const Text('Iniciar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Overlay ───────────────────────────────────────────────────────────────────

Future<void> handleOverlay(BuildContext context, ControlModel model) async {
  final cubit = context.read<ControlCubit>();

  if (model.overlayVisible) {
    cubit.toggleOverlay();
    return;
  }

  final ctrl = TextEditingController(text: model.overlayText ?? '');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: 'Texto del overlay',
      icon: Icons.subtitles_outlined,
      width: 380,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        const SizedBox(width: AppSpace.sm),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mostrar')),
      ],
      child: AppTextField(
        controller: ctrl,
        hintText: 'Texto a mostrar sobre el slide...',
        maxLines: 2,
        autofocus: true,
      ),
    ),
  );

  if (confirmed == true && context.mounted) {
    final text = ctrl.text.trim();
    if (text.isNotEmpty) {
      cubit.setOverlayText(text);
      if (!model.overlayVisible) cubit.toggleOverlay();
    }
  }
  ctrl.dispose();
}
