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

        return Container(
          height: AppSizes.liveBarHeight,
          color: AppColors.chrome,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Row(
            children: [
              // Only the inert half of the bar drags the window. Wrapping the
              // controls too puts an ancestor double-tap recogniser above every
              // button, and each one then sits dead for the length of the
              // double-tap window before it fires.
              Expanded(
                child: DragToMoveArea(
                  child: Row(
                    children: [
                      // Room for the macOS traffic-light buttons.
                      const SizedBox(width: 88),
                      const _AppMark(),
                      const SizedBox(width: AppSpace.lg),
                      Expanded(child: _NowShowing(model: model)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.lg),

              // ── Screen state ──────────────────────────────────────────────
              AppButtonGroup(
                children: [
                  AppIconButton(
                    icon: Icons.timer_outlined,
                    tooltip: model?.countdownActive == true
                        ? 'Detener cuenta regresiva'
                        : 'Cuenta regresiva',
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
                    icon: Icons.closed_caption_outlined,
                    tooltip: model?.overlayVisible == true
                        ? 'Ocultar overlay'
                        : 'Overlay de texto',
                    active: model?.overlayVisible ?? false,
                    activeColor: AppColors.success,
                    onTap: !enabled ? null : () => handleOverlay(context, model),
                  ),
                  AppIconButton(
                    icon: Icons.rectangle_outlined,
                    tooltip: 'Pantalla negra  ·  B',
                    active: model?.blankScreen ?? false,
                    activeColor: AppColors.textMuted,
                    onTap: enabled ? cubit.toggleBlank : null,
                  ),
                ],
              ),

              const AppVerticalDivider(),

              // ── Output windows ────────────────────────────────────────────
              AppButtonGroup(
                children: [
                  AppIconButton(
                    icon: Icons.tv_outlined,
                    tooltip: 'Abrir pantalla de proyección',
                    onTap: enabled ? cubit.openDisplayWindow : null,
                  ),
                  AppIconButton(
                    icon: Icons.monitor_outlined,
                    tooltip: 'Monitor de escenario',
                    onTap: enabled ? cubit.openStageMonitor : null,
                  ),
                ],
              ),

              const AppVerticalDivider(),

              const _DockToggle(),
              const SizedBox(width: AppSpace.md),
              _LiveButton(
                isLive: model?.isLive ?? false,
                onTap: enabled ? cubit.toggleLive : null,
              ),
            ],
          ),
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
        const SizedBox(width: AppSpace.sm),
        const Text(
          'Introduce',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Context readout ───────────────────────────────────────────────────────────

/// Names the collection and the slide currently on the projector.
///
/// Without this the operator has no way to tell what is being shown while
/// looking at a library, which is how people lost their place.
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

    final item = model!.currentItem;
    final slideCount = item?.slides.length ?? 0;
    final position = slideCount == 0 ? '' : '${model!.currentSlideIndex + 1}/$slideCount';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.folder_outlined, size: 13, color: AppColors.textMuted),
        const SizedBox(width: AppSpace.sm - 2),
        Flexible(
          child: Text(
            collection.name,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (item != null) ...[
          const _Dot(),
          Flexible(
            child: Text(
              item.displayTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (position.isNotEmpty) ...[
            const SizedBox(width: AppSpace.sm),
            Text(position, style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
          ],
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpace.sm),
    child: Text('•', style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
  );
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
          tooltip: shell.dockOpen ? 'Ocultar biblioteca' : 'Mostrar biblioteca',
          active: shell.dockOpen && inPresenter,
          onTap: context.read<ShellCubit>().toggleDock,
        );
      },
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
