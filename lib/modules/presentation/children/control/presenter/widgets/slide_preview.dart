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
            child: model.gridView ? _SlideGrid(model: model) : _Preview(model: model),
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
              item?.displayTitle ?? 'Sin elemento seleccionado',
              style: item == null ? AppText.rowSubtitle : AppText.panelTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                  label: 'Cuadrícula',
                  active: model.gridView,
                  onTap: model.gridView ? null : cubit.toggleGridView,
                ),
                _ViewModeButton(
                  icon: Icons.crop_16_9_rounded,
                  label: 'Slide grande',
                  active: !model.gridView,
                  onTap: model.gridView ? cubit.toggleGridView : null,
                ),
              ],
            ),
          ),
        ],
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
                  color: active ? Colors.white : AppColors.textMuted,
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
  const _SlideGrid({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final item = model.currentItem;
    if (item == null || item.slides.isEmpty) {
      return const EmptyState(
        icon: Icons.slideshow_outlined,
        title: 'Sin slides',
        message: 'Selecciona un elemento del set list.',
      );
    }

    final slides = item.slides;
    final labels = item.slideLabels;
    final isImageSlide = item.type == CollectionItemType.imageSlide;
    final cubit = context.read<ControlCubit>();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpace.sm;
        const pad = AppSpace.lg;
        final available = constraints.maxWidth - pad * 2;
        final columns = _columnsFor(slides.length, available, constraints.maxHeight - pad * 2);
        final gridWidth = _gridWidth(columns, available);
        final tile = (gridWidth - spacing * (columns - 1)) / columns;
        final inset = (available - gridWidth) / 2;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          // Centred, not top-aligned: a short song otherwise hangs from the
          // ceiling of a tall empty column.
          child: Center(
            child: GridView.builder(
              shrinkWrap: true,
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
                final label = index < labels.length ? labels[index] : '';

                return GestureDetector(
                  onTap: () => cubit.selectSlide(index),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.all(AppRadius.sm),
                            border: Border.all(
                              color: isSelected ? AppColors.accent : AppColors.divider,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.3),
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
                      Text(
                        label.isEmpty ? 'Slide ${index + 1}' : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? AppColors.accentLight : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
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

// ── Output panel shown beside the grid ────────────────────────────────────────

/// In grid mode this is the only window onto the projector, so it carries the
/// preview, the transport controls and the position readout. It used to hold a
/// thumbnail and nothing else, which left a dead 220px column.
class _SidePreviewPanel extends StatelessWidget {
  const _SidePreviewPanel({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final item = model.currentItem;

    return Container(
      width: AppSizes.queueWidth,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(title: 'Salida'),
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
                  Text(item.displayTitle, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${model.currentSlideIndex + 1} de ${item.slides.length}',
                    style: AppText.rowSubtitle,
                  ),
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
                  if (model.currentItem?.notes?.isNotEmpty == true)
                    _NotePreview(note: model.currentItem!.notes!),
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
    final item = model.currentItem;
    final isImage = item?.type == CollectionItemType.imageSlide;
    final isVideo = item?.type == CollectionItemType.videoSlide;
    final isBlank = model.blankScreen;
    final hasContent = model.currentSlideContent != null;

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
                if (isVideo && hasContent && !isBlank)
                  _VideoPreview(
                    key: ValueKey('side_${model.currentSlideContent}'),
                    videoPath: model.currentSlideContent!,
                  )
                else if (hasContent && !isBlank)
                  SlideView(
                    content: isImage ? '' : model.currentSlideContent!,
                    reference: model.currentSlideReference,
                    template: model.activeTemplate,
                    imagePath: isImage ? model.currentSlideContent : null,
                  )
                else
                  const ColoredBox(color: Colors.black),
                if (isBlank)
                  const Center(
                    child: Text(
                      'NEGRO',
                      style: TextStyle(
                        color: AppColors.textDisabled,
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
  const _Preview({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final hasContent = model.currentSlideContent != null;
    final isBlank = model.blankScreen;
    final isVideo = model.currentItem?.type == CollectionItemType.videoSlide;
    final isImage = model.currentItem?.type == CollectionItemType.imageSlide;

    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          margin: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: AppRadius.all(AppRadius.md),
            border: Border.all(
              color: model.isLive ? AppColors.live : AppColors.divider,
              width: model.isLive ? 2 : 1,
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
                if (isVideo && hasContent && !isBlank)
                  _VideoPreview(
                    key: ValueKey('main_${model.currentSlideContent}'),
                    videoPath: model.currentSlideContent!,
                  )
                else if (hasContent && !isBlank)
                  SlideView(
                    content: isImage ? '' : model.currentSlideContent!,
                    reference: model.currentSlideReference,
                    template: model.activeTemplate,
                    imagePath: isImage ? model.currentSlideContent : null,
                  )
                else
                  const ColoredBox(color: Colors.black),
                if (isBlank)
                  const Center(
                    child: Text(
                      'PANTALLA NEGRA',
                      style: TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (!hasContent && !isBlank)
                  const Center(
                    child: Text(
                      'Selecciona un elemento del set list',
                      style: TextStyle(color: AppColors.textDisabled, fontSize: 15),
                    ),
                  ),
                if (model.isLive) const _LiveBadge(),
              ],
            ),
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
          '● EN VIVO',
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
    final enabled = onTap != null;
    return Tooltip(
      message: primary ? 'Siguiente  ·  →' : 'Anterior  ·  ←',
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
