import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../l10n/l10n.dart';
import '../../backgrounds/background_choice.dart';
import '../../backgrounds/background_gallery_cubit.dart';
import '../../backgrounds/background_standard.dart';
import '../../models/media_item.dart';
import '../../models/slide_template.dart';
import '../../motion/motion_scenes.dart';
import '../../motion/scene_names.dart';
import '../../repositories/media_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../utils/bytes.dart';
import '../app_dialog.dart';
import '../slide_background.dart';

/// Picks what goes behind a design's text: one of the app's scenes, or one of
/// the church's own backgrounds, adding a new one on the way if need be.
Future<BackgroundChoice?> showBackgroundGallery(BuildContext context, {BackgroundChoice? current}) {
  return showDialog<BackgroundChoice>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) =>
          BackgroundGalleryCubit(Modular.get<MediaRepository>(), initial: current)..load(),
      child: const BackgroundGalleryDialog(),
    ),
  );
}

@visibleForTesting
class BackgroundGalleryDialog extends StatefulWidget {
  const BackgroundGalleryDialog({super.key, this.animate = true, this.pickFile});

  /// Off in tests, where nine scenes moving forever would never settle.
  final bool animate;

  /// Stands in for the system file picker in tests.
  final Future<String?> Function()? pickFile;

  @override
  State<BackgroundGalleryDialog> createState() => _BackgroundGalleryDialogState();
}

class _BackgroundGalleryDialogState extends State<BackgroundGalleryDialog> {
  bool _showRequirements = false;

  Future<void> _add(BackgroundGalleryCubit cubit) async {
    final path = widget.pickFile != null
        ? await widget.pickFile!()
        : (await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: BackgroundStandard.allExtensions,
          ))?.files.firstOrNull?.path;
    if (path == null) return;
    await cubit.add(path);
  }

  Future<void> _remove(BackgroundGalleryCubit cubit, MediaItem item) async {
    final t = L10n.of(context);
    final ok = await showAppConfirmDialog(
      context,
      title: t.bgDeleteTitle,
      message: t.bgDeleteMessage,
      confirmLabel: t.bgDelete,
      cancelLabel: t.cancel,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (ok) await cubit.remove(item);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final cubit = context.read<BackgroundGalleryCubit>();
    final level = widget.animate ? MotionLevel.scenes : MotionLevel.still;

    return BlocBuilder<BackgroundGalleryCubit, BackgroundGalleryState>(
      builder: (context, state) {
        final selected = state.selected;
        return AppDialog(
          title: t.bgGalleryTitle,
          icon: Icons.wallpaper_outlined,
          width: 860,
          height: 640,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
            const SizedBox(width: AppSpace.sm),
            FilledButton(
              onPressed: selected == null ? null : () => Navigator.pop(context, selected),
              child: Text(t.bgUse),
            ),
          ],
          child: SlideMotion(
            level: level,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.bgGalleryIntro,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
                const SizedBox(height: AppSpace.lg),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(t.bgSectionScenes.toUpperCase(), style: AppText.sectionLabel),
                        const SizedBox(height: AppSpace.sm),
                        _Grid(
                          children: [
                            for (final scene in MotionScene.values)
                              _Tile(
                                label: scene.label(t),
                                selected: selected == SceneBackground(scene),
                                onTap: () => cubit.select(SceneBackground(scene)),
                                onUse: () => Navigator.pop(context, SceneBackground(scene)),
                                child: SlideBackground(template: _preview(SceneBackground(scene))),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.xl),
                        Row(
                          children: [
                            Text(t.bgSectionChurch.toUpperCase(), style: AppText.sectionLabel),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _showRequirements = !_showRequirements),
                              icon: Icon(
                                _showRequirements ? Icons.expand_less : Icons.info_outline,
                                size: 16,
                              ),
                              label: Text(t.bgRequirements),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            FilledButton.tonalIcon(
                              onPressed: state.busy ? null : () => _add(cubit),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(t.bgAdd),
                            ),
                          ],
                        ),
                        if (_showRequirements) ...[
                          const SizedBox(height: AppSpace.sm),
                          const BackgroundRequirements(),
                        ],
                        const SizedBox(height: AppSpace.sm),
                        _AddingStatus(
                          adding: state.adding,
                          onDismiss: cubit.dismiss,
                          onChooseOther: () {
                            cubit.dismiss();
                            _add(cubit);
                          },
                        ),
                        if (state.loading)
                          const Padding(
                            padding: EdgeInsets.all(AppSpace.xl),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else if (state.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                            child: Text(
                              state.loadFailed ? t.bgLoadFailed : t.bgEmpty,
                              style: AppText.rowSubtitle.copyWith(fontSize: 12),
                            ),
                          )
                        else
                          _Grid(
                            children: [
                              for (final item in state.items)
                                _Tile(
                                  label: item.name,
                                  badge: _badge(item),
                                  selected: selected == BackgroundChoice.fromItem(item),
                                  onTap: () => cubit.select(BackgroundChoice.fromItem(item)),
                                  onUse: () =>
                                      Navigator.pop(context, BackgroundChoice.fromItem(item)),
                                  onDelete: () => _remove(cubit, item),
                                  child: SlideBackground(
                                    template: _preview(BackgroundChoice.fromItem(item)),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A design with nothing but [choice] on it, undarkened, for a tile.
  static SlideTemplate _preview(BackgroundChoice choice) {
    final applied = applyBackground(SlideTemplate.darkClassic, choice);
    return applied.copyWith(bgOverlayOpacity: 0);
  }

  static String _badge(MediaItem item) {
    final size = item.width != null && item.height != null ? '${item.width}×${item.height}' : '';
    final ms = item.durationMs;
    if (ms == null) return size;
    final seconds = (ms / 1000).round();
    final length = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return size.isEmpty ? '▶ $length' : '▶ $length · $size';
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 5,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: AppSpace.sm,
    mainAxisSpacing: AppSpace.sm,
    childAspectRatio: 16 / 9,
    children: children,
  );
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onUse,
    required this.child,
    this.badge = '',
    this.onDelete,
  });

  final String label;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  /// A double click is a choice made: select it and close.
  final VoidCallback onUse;
  final VoidCallback? onDelete;
  final Widget child;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onUse,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              borderRadius: AppRadius.all(AppRadius.sm + 2),
              border: Border.all(
                color: widget.selected
                    ? AppColors.accent
                    : _hovering
                    ? AppColors.textMuted
                    : AppColors.border,
                width: widget.selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.all(AppRadius.sm),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.child,
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      color: const Color(0x99000000),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.label,
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.badge.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              widget.badge,
                              style: const TextStyle(fontSize: 9, color: Color(0xCCFFFFFF)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.onDelete != null && _hovering)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Tooltip(
                        message: L10n.of(context).bgDelete,
                        child: InkWell(
                          onTap: widget.onDelete,
                          borderRadius: AppRadius.all(AppRadius.xs),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: AppRadius.all(AppRadius.xs),
                            ),
                            child: const Icon(Icons.delete_outline, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the church sees while a background is being added, or why it was not.
class _AddingStatus extends StatelessWidget {
  const _AddingStatus({required this.adding, required this.onDismiss, required this.onChooseOther});

  final AddingBackground adding;
  final VoidCallback onDismiss;
  final VoidCallback onChooseOther;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return switch (adding) {
      NotAdding() => const SizedBox.shrink(),
      CheckingBackground() => _progress(t.bgChecking, null),
      UploadingBackground(:final progress) => _progress(
        t.bgUploading((progress * 100).round()),
        progress,
      ),
      RefusedBackground(:final filename, :final problems) => _Notice(
        colour: AppColors.danger,
        icon: Icons.block,
        title: t.bgRefusedTitle(filename),
        lines: [for (final problem in problems) describeBackgroundProblem(t, problem)],
        actions: [
          TextButton(onPressed: onDismiss, child: Text(t.bgDismiss)),
          FilledButton.tonal(onPressed: onChooseOther, child: Text(t.bgChooseOther)),
        ],
        footer: const BackgroundRequirements(),
      ),
      FailedBackground(:final message) => _Notice(
        colour: AppColors.warning,
        icon: Icons.cloud_off_outlined,
        title: t.bgFailed(message),
        lines: const [],
        actions: [TextButton(onPressed: onDismiss, child: Text(t.bgDismiss))],
      ),
    };
  }

  Widget _progress(String label, double? value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.rowSubtitle.copyWith(fontSize: 12)),
        const SizedBox(height: AppSpace.xs),
        LinearProgressIndicator(value: value, minHeight: 3),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.colour,
    required this.icon,
    required this.title,
    required this.lines,
    required this.actions,
    this.footer,
  });

  final Color colour;
  final IconData icon;
  final String title;
  final List<String> lines;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colour),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: AppSpace.xs),
              child: Text('•  $line', style: AppText.body),
            ),
          if (footer != null) ...[const SizedBox(height: AppSpace.md), footer!],
          const SizedBox(height: AppSpace.sm),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
        ],
      ),
    );
  }
}

/// The background standard, as the operator reads it.
class BackgroundRequirements extends StatelessWidget {
  const BackgroundRequirements({super.key});

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final lines = [
      (Icons.crop_landscape, t.bgReqShape),
      (
        Icons.aspect_ratio,
        t.bgReqSize(
          BackgroundStandard.recommendedWidth,
          BackgroundStandard.recommendedHeight,
          BackgroundStandard.minWidth,
          BackgroundStandard.minHeight,
        ),
      ),
      (Icons.image_outlined, t.bgReqImage(humanBytes(BackgroundStandard.maxImageBytes))),
      (
        Icons.movie_outlined,
        t.bgReqVideo(
          humanBytes(BackgroundStandard.maxVideoBytes),
          BackgroundStandard.minLoop.inSeconds,
          BackgroundStandard.maxLoop.inMinutes,
        ),
      ),
      (Icons.lightbulb_outline, t.bgReqTip),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.bgRequirementsTitle,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpace.sm),
          for (final (icon, text) in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One broken rule, as a sentence that says what to do about it.
String describeBackgroundProblem(L10n t, BackgroundProblem problem) => switch (problem) {
  UnsupportedFormat() => t.bgProblemFormat,
  UnreadableFile() => t.bgProblemUnreadable,
  TooSmall(:final width, :final height) => t.bgProblemSmall(
    width,
    height,
    BackgroundStandard.minWidth,
    BackgroundStandard.minHeight,
  ),
  TooLarge(:final width, :final height) => t.bgProblemLarge(
    width,
    height,
    BackgroundStandard.maxVideoWidth,
    BackgroundStandard.maxVideoHeight,
  ),
  WrongShape(:final width, :final height) => t.bgProblemShape(width, height),
  TooHeavy(:final bytes, :final limit) => t.bgProblemHeavy(humanBytes(bytes), humanBytes(limit)),
  UnknownLength() => t.bgProblemNoLength,
  TooShort(:final duration) => t.bgProblemShort(
    duration.inSeconds,
    BackgroundStandard.minLoop.inSeconds,
  ),
  TooLong(:final duration) => t.bgProblemLong(
    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
    BackgroundStandard.maxLoop.inMinutes,
  ),
};
