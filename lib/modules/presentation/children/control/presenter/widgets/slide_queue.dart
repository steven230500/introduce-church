part of '../page.dart';

/// The slides of the current item, in order, with the live one highlighted.
class _SlideQueue extends StatelessWidget {
  const _SlideQueue({required this.model, required this.width});

  final ControlModel model;
  final double width;

  @override
  Widget build(BuildContext context) {
    final item = model.currentItem;

    return Container(
      width: width,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(
            title: item?.displayTitle ?? 'Slides',
            leading: item == null ? null : _TypeChip(item.type),
          ),
          Expanded(
            child: item == null
                ? const EmptyState(
                    compact: true,
                    icon: Icons.list_alt_rounded,
                    title: 'Sin elemento activo',
                    message: 'Elige uno del set list.',
                  )
                : _SlideList(model: model, item: item),
          ),
          // Only at the seam. Inside an item the list above already shows what
          // comes next, and repeating it here would be noise — including the
          // rule above it, which would otherwise underline nothing.
          if (_showsSeam(model, item)) ...[
            const Divider(height: 1, color: AppColors.divider),
            _UpNext(model: model, onlyAcrossItems: true),
          ],
        ],
      ),
    );
  }
}

/// Whether the card under the list has anything to say: the next press either
/// leaves this item, or ends the service.
bool _showsSeam(ControlModel model, CollectionItem? item) {
  if (item == null) return false;
  final next = model.upNext;
  return next == null || next.item.id != item.id;
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.type);

  final CollectionItemType type;

  IconData get _icon => switch (type) {
    CollectionItemType.song => Icons.music_note,
    CollectionItemType.bibleVerse => Icons.menu_book,
    CollectionItemType.sermon => Icons.mic_outlined,
    CollectionItemType.freeSlide => Icons.text_fields,
    CollectionItemType.imageSlide => Icons.slideshow_outlined,
    CollectionItemType.videoSlide => Icons.videocam_outlined,
    CollectionItemType.announcement => Icons.campaign_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: type.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceControl,
          borderRadius: AppRadius.all(AppRadius.xs),
        ),
        child: Icon(_icon, size: 12, color: AppColors.textTertiary),
      ),
    );
  }
}

// ── List ──────────────────────────────────────────────────────────────────────

class _SlideList extends StatefulWidget {
  const _SlideList({required this.model, required this.item});

  final ControlModel model;
  final CollectionItem item;

  @override
  State<_SlideList> createState() => _SlideListState();
}

class _SlideListState extends State<_SlideList> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(_SlideList old) {
    super.didUpdateWidget(old);
    if (old.model.currentSlideIndex != widget.model.currentSlideIndex ||
        old.model.currentItemIndex != widget.model.currentItemIndex) {
      _scrollToActive();
    }
  }

  /// Keeps the live slide on screen as the operator advances, so they never
  /// have to scroll during a song.
  void _scrollToActive() {
    if (!_controller.hasClients) return;
    const tileHeight = 84.0;
    final offset = widget.model.currentSlideIndex * tileHeight;
    _controller.animateTo(
      offset.clamp(0.0, _controller.position.maxScrollExtent),
      duration: AppMotion.slow,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final slides = item.slides;

    if (slides.isEmpty) {
      return const EmptyState(compact: true, icon: Icons.hide_image_outlined, title: 'Sin slides');
    }

    final refs = item.slideReferences;
    final labels = item.slideLabels;

    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      itemCount: slides.length,
      itemBuilder: (context, index) {
        final isActive = widget.model.currentSlideIndex == index;
        // Red for the slide on the projector, blue for the one being browsed.
        // They are the same tile until the operator holds the screen.
        final isOnAir = widget.model.isLiveAt(widget.model.currentItemIndex, index);

        return HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder: (context, hovering) => GestureDetector(
            onTap: () => context.read<ControlCubit>().selectSlide(index),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
              padding: const EdgeInsets.all(AppSpace.sm + 2),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accentFillSoft
                    : (hovering ? AppColors.surfaceRaised : AppColors.surfaceControl),
                borderRadius: AppRadius.all(AppRadius.md),
                border: Border.all(
                  color: isOnAir
                      ? AppColors.live
                      : (isActive ? AppColors.accent : Colors.transparent),
                ),
              ),
              child: _SlideTile(
                item: item,
                index: index,
                slide: slides[index],
                label: index < labels.length ? labels[index] : '',
                ref: index < refs.length ? refs[index] : '',
                isActive: isActive,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _SlideTile extends StatelessWidget {
  const _SlideTile({
    required this.item,
    required this.index,
    required this.slide,
    required this.label,
    required this.ref,
    required this.isActive,
  });

  final CollectionItem item;
  final int index;
  final String slide;
  final String label;
  final String ref;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : AppColors.border,
            borderRadius: AppRadius.all(AppRadius.xs),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label.isNotEmpty) ...[
                _Badge(text: label, isActive: isActive, outlined: false),
                const SizedBox(height: AppSpace.xs),
              ],
              _content(),
              if (ref.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xs),
                _Badge(text: ref, isActive: isActive, outlined: true),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _content() {
    switch (item.type) {
      case CollectionItemType.videoSlide:
        return _IconLine(icon: Icons.videocam_outlined, text: item.displayTitle);
      case CollectionItemType.imageSlide:
        return _IconLine(icon: Icons.image_outlined, text: 'Slide ${index + 1}');
      default:
        return Text(
          slide,
          style: TextStyle(
            color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
            fontSize: 11,
            height: 1.3,
          ),
          maxLines: ref.isNotEmpty ? 2 : 3,
          overflow: TextOverflow.ellipsis,
        );
    }
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.isActive, required this.outlined});

  final String text;
  final bool isActive;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.accent.withValues(alpha: outlined ? 0.2 : 0.25)
            : (outlined ? AppColors.surface : AppColors.border),
        borderRadius: AppRadius.all(AppRadius.xs),
        border: outlined
            ? Border.all(color: isActive ? AppColors.accentOutline : AppColors.border)
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? AppColors.accentLight : AppColors.textTertiary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
