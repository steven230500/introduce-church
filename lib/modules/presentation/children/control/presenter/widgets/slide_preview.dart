part of '../page.dart';

/// The middle column: what the projector is showing, or a grid of everything
/// in the current item.
class _SlidePreview extends StatelessWidget {
  const _SlidePreview({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        children: [
          _PreviewHeader(model: model),
          Expanded(
            // Fades between the two ways of looking at an item. Swapping the
            // whole middle of the window in one frame read as a glitch.
            child: AnimatedSwitcher(
              duration: AppMotion.slow,
              child: model.gridView
                  ? _SlideGrid(key: const ValueKey('grid'), model: model)
                  : _Preview(key: const ValueKey('single'), model: model),
            ),
          ),
          if (!model.gridView) _Controls(model: model),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

/// Names the item on screen and switches how its slides are laid out.
///
/// The toggle used to be an unlabelled chip that silently rearranged the whole
/// window. Now both modes are named and both keep an output preview visible.
class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final item = model.currentItem;
    final cubit = context.read<ControlCubit>();

    return Container(
      height: AppSizes.panelHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item?.titleIn(t) ?? t.noItemSelected,
              style: item == null ? AppText.rowSubtitle : AppText.panelTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Grid mode only. The large slide badges its own frame, which is
          // where the eye already is; the grid has no frame to badge, and a
          // blue outline there used to mean live.
          if (model.isHolding && model.gridView) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm - 2, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentFill,
                borderRadius: AppRadius.all(AppRadius.xs),
                border: Border.all(color: AppColors.accentOutline),
              ),
              child: Text(
                t.notSent,
                style: TextStyle(
                  color: AppColors.accentLight,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
          ],
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.surfaceControl,
              borderRadius: AppRadius.all(AppRadius.sm + 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewModeButton(
                  icon: Icons.grid_view_rounded,
                  label: t.gridView,
                  active: model.gridView,
                  onTap: model.gridView ? null : cubit.toggleGridView,
                ),
                _ViewModeButton(
                  icon: Icons.crop_16_9_rounded,
                  label: t.bigSlideView,
                  active: !model.gridView,
                  onTap: model.gridView ? cubit.toggleGridView : null,
                ),
              ],
            ),
          ),
          if (model.gridView) ...[
            const SizedBox(width: AppSpace.sm),
            _GridSizeButtons(model: model),
          ],
        ],
      ),
    );
  }
}

/// Makes the slides in the grid bigger or smaller.
///
/// The operator at the desk runs a laptop with a small screen, and a song with
/// eight slides fits them all on it by making each one too small to read.
class _GridSizeButtons extends StatelessWidget {
  const _GridSizeButtons({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final cubit = context.read<ControlCubit>();
    final hasSlides = (model.currentItem?.slides.length ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.sm + 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GridSizeButton(
            icon: Icons.zoom_out_map_rounded,
            tooltip: t.gridBigger,
            onTap: !hasSlides || model.gridZoom >= ControlCubit.maxGridZoom
                ? null
                : () => cubit.zoomGrid(1),
          ),
          _GridSizeButton(
            icon: Icons.zoom_in_map_rounded,
            tooltip: t.gridSmaller,
            onTap: !hasSlides || model.gridZoom <= ControlCubit.minGridZoom
                ? null
                : () => cubit.zoomGrid(-1),
          ),
        ],
      ),
    );
  }
}

class _GridSizeButton extends StatelessWidget {
  const _GridSizeButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.all(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 5),
          child: Icon(
            icon,
            size: 15,
            color: onTap == null ? AppColors.textMuted : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label  ·  G',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs + 1),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: AppRadius.all(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: active ? Colors.white : AppColors.textMuted),
              const SizedBox(width: AppSpace.xs + 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grid of slides ────────────────────────────────────────────────────────────

class _SlideGrid extends StatelessWidget {
  const _SlideGrid({super.key, required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final item = model.currentItem;
    if (item == null || item.slides.isEmpty) {
      return EmptyState(icon: Icons.slideshow_outlined, title: t.noSlides, message: t.selectAnItem);
    }

    final slides = item.slides;
    final labels = item.slideLabelsIn(t);
    final isImageSlide = item.type == CollectionItemType.imageSlide;
    final editable = item.slidesEditable;
    final cubit = context.read<ControlCubit>();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpace.sm;
        const pad = AppSpace.lg;
        final available = constraints.maxWidth - pad * 2;
        final fitted = _columnsFor(slides.length, available, constraints.maxHeight - pad * 2);
        // Each step of zoom is a column taken away, and never more columns
        // than there are slides: four columns for a two-slide song is two
        // empty holes.
        final columns = (fitted - model.gridZoom).clamp(1, slides.length);
        final gridWidth = _gridWidth(columns, available);
        final tile = (gridWidth - spacing * (columns - 1)) / columns;
        final inset = (available - gridWidth) / 2;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          // Centred, not top-aligned: a short song otherwise hangs from the
          // ceiling of a tall empty column.
          child: Center(
            child: GridView.builder(
              // Fitted to the window it cannot overflow, so it hugs its
              // content and sits centred. Once the operator makes the slides
              // bigger than the window, it has to scroll instead.
              shrinkWrap: model.gridZoom <= 0,
              physics: model.gridZoom <= 0
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(pad),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: tile / (tile * 9 / 16 + _captionHeight),
              ),
              itemCount: slides.length,
              itemBuilder: (context, index) {
                final isSelected = index == model.currentSlideIndex;
                // Red for what the congregation sees, blue for what the
                // operator has picked. The same tile until the screen is held.
                final isOnAir = model.isLiveAt(model.currentItemIndex, index);
                final label = index < labels.length ? labels[index] : '';

                return HoverBuilder(
                  cursor: SystemMouseCursors.click,
                  builder: (context, hovering) {
                    final outline = isOnAir
                        ? AppColors.live
                        : isSelected
                        ? AppColors.accent
                        : (hovering ? AppColors.textMuted : AppColors.divider);

                    return GestureDetector(
                      onTap: () => cubit.selectSlide(index),
                      // No double click to edit: the first click already puts
                      // the slide on the screen, and waiting to see whether a
                      // second one follows would slow every click in a service.
                      onSecondaryTapDown: editable
                          ? (details) => _showSlideMenu(context, details.globalPosition, index)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              decoration: BoxDecoration(
                                borderRadius: AppRadius.all(AppRadius.sm),
                                border: Border.all(
                                  color: outline,
                                  width: isSelected || isOnAir ? 2 : 1,
                                ),
                                boxShadow: isSelected || isOnAir
                                    ? [
                                        BoxShadow(
                                          color: outline.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: AppRadius.all(AppRadius.xs + 1),
                                child: SlideView(
                                  content: isImageSlide ? '' : slides[index],
                                  reference: '',
                                  template: model.activeTemplate,
                                  imagePath: isImageSlide ? slides[index] : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Under the slide, not on top of it. As a badge inside
                          // the frame it landed on the words whenever the lyric
                          // ran long, which is exactly when you need to read both.
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label.isEmpty ? t.slideNumber(index + 1) : label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.accentLight
                                        : (hovering
                                              ? AppColors.textSecondary
                                              : AppColors.textMuted),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (editable)
                                _EditSlideButton(
                                  highlighted: hovering || isSelected,
                                  onTap: () => showSlideEditor(context, slideIndex: index),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSlideMenu(BuildContext context, Offset at, int index) async {
    final t = L10n.of(context);
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      color: AppColors.surfaceRaised,
      items: [
        PopupMenuItem(
          value: 'edit',
          height: 38,
          child: AppMenuRow(icon: Icons.edit_outlined, label: t.slideEdit),
        ),
      ],
    );
    if (choice == 'edit' && context.mounted) await showSlideEditor(context, slideIndex: index);
  }

  /// Columns that make the slides as big as they can be while still all
  /// fitting on screen.
  ///
  /// The old rule was a fixed ~240px tile with a floor of two columns, so a
  /// one-slide item drew a single stamp in the corner of an otherwise empty
  /// column, and a four-slide song was four stamps in a strip across the top.
  static int _columnsFor(int count, double width, double height) {
    final most = count.clamp(1, _maxColumns);
    for (var columns = 1; columns < most; columns++) {
      final tile = (width - AppSpace.sm * (columns - 1)) / columns;
      if (tile > _maxTile) continue;
      final rows = (count / columns).ceil();
      final needed = rows * (tile * 9 / 16 + _captionHeight) + AppSpace.sm * (rows - 1);
      if (needed <= height) return columns;
    }
    return most;
  }

  /// How wide the grid is allowed to be, so a single slide does not stretch
  /// into a second copy of the large preview.
  static double _gridWidth(int columns, double available) {
    final tile = (available - AppSpace.sm * (columns - 1)) / columns;
    if (tile <= _maxTile) return available;
    return _maxTile * columns + AppSpace.sm * (columns - 1);
  }

  static const _maxColumns = 5;
  static const _maxTile = 520.0;

  /// Room under each tile for the slide's label.
  static const _captionHeight = 18.0;
}

/// The pencil under a slide. Always there, not only on hover: a control that
/// appears when the pointer finds it is one the operator never finds.
class _EditSlideButton extends StatelessWidget {
  const _EditSlideButton({required this.highlighted, required this.onTap});

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L10n.of(context).slideEdit,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // Its own tap, so editing a slide never puts it on the screen.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpace.xs),
            child: Icon(
              Icons.edit_outlined,
              size: 13,
              color: highlighted ? AppColors.textSecondary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Output panel shown beside the grid ────────────────────────────────────────

/// In grid mode this is the only window onto the projector, so it carries the
/// preview, the transport controls and the position readout. It used to hold a
/// thumbnail and nothing else, which left a dead 220px column.
class _SidePreviewPanel extends StatelessWidget {
  const _SidePreviewPanel({required this.model, required this.width});

  final ControlModel model;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    // The projector's item, not the operator's. This panel is the one place
    // that always answers "what are they seeing".
    final item = model.liveItem;

    return Container(
      width: width,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: t.output),
          Padding(
            padding: const EdgeInsets.all(AppSpace.sm + 2),
            child: _OutputThumbnail(model: model),
          ),
          if (item != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.titleIn(t), style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    t.slideOf(model.liveSlideIndex + 1, item.slides.length),
                    style: AppText.rowSubtitle,
                  ),
                  if (model.isLive) ...[
                    const SizedBox(height: 4),
                    ItemTimer(
                      startedAt: context.read<ControlCubit>().itemStartedAt,
                      plannedSecs: item.plannedSecs,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          _NavRow(model: model),
          const SizedBox(height: AppSpace.lg),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _UpNext(model: model),
                  if (model.liveItem?.notes?.isNotEmpty == true)
                    _NotePreview(note: model.liveItem!.notes!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 16:9 mirror of the projector output.
class _OutputThumbnail extends StatelessWidget {
  const _OutputThumbnail({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final item = model.liveItem;
    // A loose passage is words, whatever the item underneath it happens to be.
    final isImage = !model.looseActive && item?.type == CollectionItemType.imageSlide;
    final isVideo = !model.looseActive && item?.type == CollectionItemType.videoSlide;
    final isBlank = model.blankScreen;
    final hasContent = model.liveSlideContent != null;
    // This is a picture of the projector, so it shows the waiting scene when
    // the projector does - not the slide sitting underneath it.
    final waiting = model.waiting.active && model.isLive && !isBlank;

    final face = waiting
        ? WaitingScreen(
            key: ValueKey('waiting_${model.waiting.scene.name}'),
            config: model.waiting,
            countdownEnd: model.countdownActive ? model.countdownEnd : null,
          )
        : isVideo && hasContent && !isBlank
        ? _VideoPreview(
            key: ValueKey('side_${model.liveSlideContent}'),
            videoPath: model.liveSlideContent!,
          )
        : hasContent && !isBlank
        // A painted scene moves here as it does on the wall; a video loop
        // shows its still frame, since the projector is already playing it.
        ? SlideMotion(
            level: MotionLevel.scenes,
            child: SlideView(
              content: isImage ? '' : model.liveSlideContent!,
              reference: model.liveSlideReference,
              template: model.liveTemplate,
              imagePath: isImage ? model.liveSlideContent : null,
            ),
          )
        : const ColoredBox(color: Colors.black);

    return ClipRRect(
      borderRadius: AppRadius.all(AppRadius.sm),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: model.isLive ? AppColors.live : AppColors.border),
            borderRadius: AppRadius.all(AppRadius.sm),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.all(AppRadius.sm - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Dissolves with the projector, because this is a picture of
                // the projector.
                SlideTransitionView(
                  template: model.liveTemplate,
                  slideKey: '${model.liveItemIndex}:${model.liveSlideIndex}:$isBlank:$waiting',
                  child: face,
                ),
                if (isBlank)
                  Center(
                    child: Text(
                      t.blackMark,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (model.isLive) const _LiveBadge(compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ControlCubit>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _NavButton(
          icon: Icons.skip_previous_rounded,
          onTap: model.hasPrevSlide ? cubit.prevSlide : null,
        ),
        const SizedBox(width: AppSpace.sm),
        _NavButton(
          icon: Icons.skip_next_rounded,
          onTap: model.hasNextSlide ? cubit.nextSlide : null,
          primary: true,
        ),
      ],
    );
  }
}

/// Operator note for the current item, mirrored from the stage monitor.
class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.note.withValues(alpha: 0.12),
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(color: AppColors.note.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined, size: 12, color: AppColors.note),
          const SizedBox(width: AppSpace.sm - 2),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(color: AppColors.note, fontSize: 11, height: 1.35),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Large single-slide preview ────────────────────────────────────────────────

class _Preview extends StatelessWidget {
  const _Preview({super.key, required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final hasContent = model.currentSlideContent != null;
    // While the operator is looking away from the projector this frame shows
    // where they are looking, so the blank overlay and the live badge, which
    // both describe the projector, do not belong on it.
    final holding = model.isHolding;
    final isBlank = model.blankScreen && !holding;
    final onAir = model.isLive && !holding;
    final isVideo = model.currentItem?.type == CollectionItemType.videoSlide;
    final isImage = model.currentItem?.type == CollectionItemType.imageSlide;

    final face = isVideo && hasContent && !isBlank
        ? _VideoPreview(
            key: ValueKey('main_${model.currentSlideContent}'),
            videoPath: model.currentSlideContent!,
          )
        : hasContent && !isBlank
        ? SlideMotion(
            level: MotionLevel.scenes,
            child: SlideView(
              content: isImage ? '' : model.currentSlideContent!,
              reference: model.currentSlideReference,
              template: model.activeTemplate,
              imagePath: isImage ? model.currentSlideContent : null,
            ),
          )
        : const ColoredBox(color: Colors.black);

    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          margin: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: AppRadius.all(AppRadius.md),
            border: Border.all(
              color: onAir ? AppColors.live : (holding ? AppColors.accent : AppColors.divider),
              width: onAir || holding ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.all(AppRadius.md - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The same move the design makes on the projector. This used
                // to cut while the screen it mirrors dissolved.
                SlideTransitionView(
                  template: model.activeTemplate,
                  slideKey: '${model.currentItemIndex}:${model.currentSlideIndex}:$isBlank',
                  child: face,
                ),
                if (isBlank)
                  Center(
                    child: Text(
                      t.blackScreen,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!hasContent && !isBlank)
                  Center(
                    child: Text(
                      t.selectAnItem,
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
                    ),
                  ),
                if (onAir) const _LiveBadge(),
                if (holding) const _HoldingBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Says out loud that the frame under it is not what the congregation sees.
///
/// Without it the big preview looks exactly as it does when it is live, and an
/// operator who forgot the screen is held would keep clicking and wonder why
/// nothing changes out front.
class _HoldingBadge extends StatelessWidget {
  const _HoldingBadge();

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Positioned(
      top: AppSpace.md,
      right: AppSpace.md,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: AppRadius.all(AppRadius.xs),
        ),
        child: Text(
          t.notSent,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: compact ? 4 : AppSpace.md,
      right: compact ? 4 : AppSpace.md,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : AppSpace.sm,
          vertical: compact ? 2 : AppSpace.xs,
        ),
        decoration: BoxDecoration(color: AppColors.live, borderRadius: AppRadius.all(AppRadius.xs)),
        child: Text(
          L10n.of(context).liveBadge,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 7 : 10,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 0.8 : 1,
          ),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.videoPath, super.key});

  final String videoPath;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.setPlaylistMode(PlaylistMode.loop);
    _player.open(Media(widget.videoPath));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Video(controller: _controller, fill: Colors.black);
}

// ── Transport bar under the large preview ─────────────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final cubit = context.read<ControlCubit>();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.skip_previous_rounded,
            onTap: model.hasPrevSlide ? cubit.prevSlide : null,
          ),
          const SizedBox(width: AppSpace.sm),
          _NavButton(
            icon: Icons.skip_next_rounded,
            onTap: model.hasNextSlide ? cubit.nextSlide : null,
            primary: true,
          ),
          const SizedBox(width: AppSpace.xl),
          if (model.currentItem != null)
            Text(
              '${model.currentSlideIndex + 1} / ${model.currentItem!.slides.length}',
              style: AppText.rowSubtitle,
            ),
          // Under the frame it belongs to, as well as in the live bar: this is
          // where the operator is looking when they decide to send.
          if (model.isHolding) ...[
            const SizedBox(width: AppSpace.xl),
            FilledButton.icon(
              onPressed: cubit.take,
              icon: const Icon(Icons.send_rounded, size: 15),
              label: Text(t.barSend),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap, this.primary = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final enabled = onTap != null;
    return Tooltip(
      message: primary ? t.nextShortcut : t.previousShortcut,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: primary ? 52 : 44,
          height: primary ? 44 : 36,
          decoration: BoxDecoration(
            color: enabled
                ? (primary ? AppColors.accent : AppColors.surfaceControl)
                : AppColors.surface,
            borderRadius: AppRadius.all(AppRadius.lg),
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : AppColors.textDisabled,
            size: primary ? 28 : 22,
          ),
        ),
      ),
    );
  }
}
