part of '../page.dart';

/// A preview of the slide that Next will put on the projector.
///
/// The right-hand column held a thumbnail, two buttons and then several hundred
/// pixels of nothing. What belongs in that space is the one thing the operator
/// could not see anywhere else: what happens when they press the key again,
/// especially at the seam between two items, which is where a service trips.
class _UpNext extends StatelessWidget {
  const _UpNext({required this.model, this.onlyAcrossItems = false});

  final ControlModel model;

  /// Stay hidden while the next slide is still inside the current item.
  ///
  /// The slide queue already lists those a few centimetres above, so the card
  /// would just repeat a tile that is already on screen.
  final bool onlyAcrossItems;

  @override
  Widget build(BuildContext context) {
    final next = model.upNext;
    if (next == null) return const _EndOfSet();

    final crossesItem = next.item.id != model.currentItem?.id;
    if (onlyAcrossItems && !crossesItem) return const SizedBox.shrink();

    final item = next.item;
    final labels = item.slideLabelsIn(L10n.of(context));
    final label = next.slide < labels.length ? labels[next.slide] : '';

    return Container(
      margin: const EdgeInsets.all(AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: crossesItem ? AppColors.accentOutline : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.skip_next_rounded, size: 12, color: AppColors.textMuted),
              SizedBox(width: AppSpace.xs),
              Text(L10n.of(context).upNext, style: AppText.sectionLabel),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          _UpNextFrame(model: model, item: item, slide: next.slide),
          const SizedBox(height: AppSpace.sm - 2),
          if (crossesItem)
            Text(
              item.titleIn(L10n.of(context)),
              style: const TextStyle(
                color: AppColors.accentLight,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (label.isNotEmpty)
            Text(label, style: AppText.rowSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// The 16:9 thumbnail inside the card, drawn with the design the next item
/// will actually use, which is not always the one on screen now.
class _UpNextFrame extends StatelessWidget {
  const _UpNextFrame({required this.model, required this.item, required this.slide});

  final ControlModel model;
  final CollectionItem item;
  final int slide;

  @override
  Widget build(BuildContext context) {
    final slides = item.slides;
    final content = slide < slides.length ? slides[slide] : null;
    final isImage = item.type == CollectionItemType.imageSlide;
    final isVideo = item.type == CollectionItemType.videoSlide;
    final refs = item.slideReferences;
    final reference = slide < refs.length ? refs[slide] : '';

    return ClipRRect(
      borderRadius: AppRadius.all(AppRadius.sm),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          // A video would need a second decoder running just to show a frame
          // nobody is watching yet, so it gets named instead of played.
          child: isVideo || content == null
              ? Center(
                  child: Icon(
                    isVideo ? Icons.videocam_outlined : Icons.hide_image_outlined,
                    size: 18,
                    color: AppColors.textDisabled,
                  ),
                )
              : SlideView(
                  content: isImage ? '' : content,
                  reference: reference,
                  template: model.templateFor(item),
                  imagePath: isImage ? content : null,
                ),
        ),
      ),
    );
  }
}

/// Shown once there is nothing after the current slide.
///
/// An empty space says the same thing, but only to someone who already knows
/// the set list is over.
class _EndOfSet extends StatelessWidget {
  const _EndOfSet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, size: 12, color: AppColors.textDisabled),
          SizedBox(width: AppSpace.sm - 2),
          Text(L10n.of(context).endOfSetList, style: AppText.rowSubtitle),
        ],
      ),
    );
  }
}
