part of '../../page.dart';

/// The ordered list of elements in the open collection.
class _SetListItems extends StatelessWidget {
  const _SetListItems({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final collection = model.activeCollection;

    if (collection == null) {
      return EmptyState(
        compact: true,
        icon: Icons.folder_open_outlined,
        title: t.noCollectionOpen,
        message: model.collections.isEmpty ? t.createToStart : t.openFromCollections,
        actionLabel: model.collections.isEmpty ? t.createCollection : null,
        onAction: model.collections.isEmpty
            ? () async {
                final cubit = context.read<ControlCubit>();
                final draft = await showCollectionDialog(context);
                if (draft != null) {
                  await cubit.createCollection(draft.name, serviceDate: draft.date);
                }
              }
            : null,
      );
    }

    final items = collection.items;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_add_rounded, size: 32, color: AppColors.textDisabled),
            const SizedBox(height: AppSpace.md),
            Text(
              t.emptyCollection,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(t.addSongsVersesMedia, textAlign: TextAlign.center, style: AppText.rowSubtitle),
            const SizedBox(height: AppSpace.lg),
            const _AddItemMenu(expanded: true),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.xs, 0),
          child: Row(
            children: [
              Expanded(child: Text(t.sectionItems, style: AppText.sectionLabel)),
              // Beside the list it adds up, rather than in the subtitle above,
              // where it was cut off after the date.
              if (_plannedTotal(t, collection) case final total?)
                Tooltip(
                  message: t.plannedDuration,
                  child: Text(
                    total,
                    style: AppText.rowSubtitle.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              const _AddItemMenu(),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              // A folded moment takes its items out of the list, except the
              // one on the screen and the one the operator has selected:
              // losing sight of what the congregation is reading is worse
              // than a long list.
              final rows = [
                for (var i = 0; i < items.length; i++)
                  if (items[i].isSection ||
                      !model.isFolded(i) ||
                      model.isLiveItem(i) ||
                      model.currentItemIndex == i)
                    i,
              ];

              return ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                itemCount: rows.length,
                // The default handle is a second trailing control on a panel
                // that is already too narrow for its titles. The order badge
                // drags instead, which costs no width because it is there
                // regardless.
                buildDefaultDragHandles: false,
                onReorder: (oldPosition, newPosition) {
                  if (newPosition > oldPosition) newPosition--;
                  final from = rows[oldPosition];
                  final to = newPosition < rows.length ? rows[newPosition] : items.length - 1;
                  context.read<ControlCubit>().reorderItem(from, to);
                },
                itemBuilder: (context, position) {
                  final index = rows[position];
                  final item = items[index];
                  if (item.isSection) {
                    return _MomentRow(
                      key: ValueKey(item.id),
                      model: model,
                      item: item,
                      index: index,
                      position: position,
                    );
                  }
                  return _SetListTile(
                    key: ValueKey(item.id),
                    model: model,
                    item: item,
                    index: index,
                    position: position,
                    isActive: model.currentItemIndex == index,
                    isOnAir: model.isLiveItem(index),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The colour that runs down a moment, and down the items under it.
Color? _momentColor(ControlModel model, int index) {
  final moment = model.momentOf(index);
  if (moment == null) return null;
  return AppColors.moments[model.momentOrder(moment.id) % AppColors.moments.length];
}

/// The colour of the moment an item belongs to, drawn down its left edge.
///
/// Null before the first mark of a service, and for a service with none: the
/// list then looks exactly as it did before moments existed.
BoxDecoration? _spine(Color? colour) {
  if (colour == null) return null;
  return BoxDecoration(
    border: Border(left: BorderSide(color: colour, width: 3)),
  );
}

/// A moment of the service: the mark that opens "Alabanza" or "Prédica".
///
/// It reads as a band the running order passes through rather than a folder
/// that swallows it: the items keep their place in the one list, and folding
/// one is a way of looking, not a way of filing.
class _MomentRow extends StatelessWidget {
  const _MomentRow({
    super.key,
    required this.model,
    required this.item,
    required this.index,
    required this.position,
  });

  final ControlModel model;
  final CollectionItem item;
  final int index;
  final int position;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final cubit = context.read<ControlCubit>();
    final colour = AppColors.moments[model.momentOrder(item.id) % AppColors.moments.length];
    final folded = model.isMomentFolded(item.id);
    final length = model.momentLength(index);

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovering) => GestureDetector(
        onTap: () => cubit.toggleMoment(item.id),
        onSecondaryTapDown: (details) =>
            _showItemMenu(context, model, item, details.globalPosition),
        // The whole strip drags, not the 3px spine: an operator moving a
        // moment mid-service should not have to hit a hairline.
        child: ReorderableDragStartListener(
          index: position,
          child: Tooltip(
            message: t.momentDrag,
            waitDuration: const Duration(milliseconds: 900),
            child: Container(
              // The gap above is what makes this read as the start of something
              // rather than one more row.
              margin: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.md, AppSpace.sm, 0),
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      color: colour,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm + 2),
                  Flexible(
                    child: Text(
                      item.titleIn(t),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  // Folded, the dots say how much is under there without opening
                  // it; open, the numbers do.
                  if (folded)
                    _FoldedDots(count: length.items, colour: colour)
                  else
                    Text(_summary(t, length), style: AppText.rowSubtitle),
                  const Spacer(),
                  AnimatedRotation(
                    turns: folded ? -0.25 : 0,
                    duration: AppMotion.fast,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: hovering ? AppColors.textSecondary : AppColors.textMuted,
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

  /// "3 elementos · 18 min", dropping the half it cannot say.
  static String _summary(L10n t, ({int items, Duration planned, int unplanned}) length) {
    final parts = [
      t.momentItems(length.items),
      if (length.planned > Duration.zero) clockText(length.planned),
    ];
    return parts.join('  ·  ');
  }
}

/// One dot per item folded away, so the size of what is hidden is visible.
class _FoldedDots extends StatelessWidget {
  const _FoldedDots({required this.count, required this.colour});

  final int count;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    // Past a dozen the dots stop being countable and start being a texture.
    final shown = count.clamp(0, 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        if (count > shown)
          Text('+${count - shown}', style: AppText.rowSubtitle.copyWith(fontSize: 10)),
      ],
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _SetListTile extends StatelessWidget {
  const _SetListTile({
    super.key,
    required this.model,
    required this.item,
    required this.index,
    required this.position,
    required this.isActive,
    required this.isOnAir,
  });

  final ControlModel model;
  final CollectionItem item;

  /// Where the item sits in the service.
  final int index;

  /// Where its row sits in the list as drawn, which is not the same once a
  /// moment is folded and the drag has to know the difference.
  final int position;

  /// The row the operator has selected.
  final bool isActive;

  /// The row the congregation is looking at, which is the same one until the
  /// operator holds the screen to go browsing.
  final bool isOnAir;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovering) => GestureDetector(
        onTap: () => context.read<ControlCubit>().selectItem(index),
        // Right click opens the same menu as the kebab. The kebab is 13px and
        // most operators never found it.
        onSecondaryTapDown: (details) =>
            _showItemMenu(context, model, item, details.globalPosition),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          // The spine has to meet the one above it: with a gap between rows it
          // reads as dashes rather than one band running down the moment. The
          // breathing room is padding inside the row instead.
          margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          foregroundDecoration: _spine(_momentColor(model, index)),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.sm + 3,
            AppSpace.xs,
            AppSpace.sm + 3,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accentFill
                : (hovering ? AppColors.surfaceRaised : Colors.transparent),
            borderRadius: AppRadius.all(AppRadius.md),
            border: Border.all(color: isActive ? AppColors.accentOutline : Colors.transparent),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: position,
                child: Tooltip(
                  message: t.dragToReorder,
                  waitDuration: const Duration(milliseconds: 600),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: _OrderBadge(number: model.playableNumber(index), isActive: isActive),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _typeIcon(item.type),
                          size: 11,
                          color: isActive ? AppColors.accentLight : AppColors.textDisabled,
                        ),
                        const SizedBox(width: AppSpace.xs + 1),
                        Expanded(
                          child: Text(
                            item.titleIn(L10n.of(context)),
                            style: TextStyle(
                              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Only when the two have come apart. While they agree the
                        // blue row already says everything.
                        if (isOnAir && !isActive) const _OnAirDot(),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        _subtitle(L10n.of(context), model, item),
                        style: AppText.rowSubtitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _TileFlags(model: model, item: item),
                  ],
                ),
              ),
              _ItemMenuButton(model: model, item: item),
            ],
          ),
        ),
      ),
    );
  }

  /// One line under the title, holding what the item is and how long it runs.
  ///
  /// The slide count used to be a bare number wedged between the title and the
  /// kebab, where it read as part of the title and ate the width that made
  /// titles fit in the first place.
  static String _subtitle(L10n t, ControlModel model, CollectionItem item) {
    final count = item.slides.length;
    final parts = [
      ?_repeat(t, model, item),
      if (item.subtitleIn(t).isNotEmpty) item.subtitleIn(t),
      t.slideCount(count),
    ];
    return parts.join('  ·  ');
  }

  /// Which time round this is, when the plan repeats a title.
  ///
  /// A song that comes back as a reprise is normal, and three rows all reading
  /// "NADA ES IMPOSIBLE" tell the operator nothing about which one they are
  /// looking at. Numbering the repeats beats pretending they are distinct.
  static String? _repeat(L10n t, ControlModel model, CollectionItem item) {
    final items = model.activeCollection?.items ?? const <CollectionItem>[];
    final total = items.where((i) => i.displayTitle == item.displayTitle).length;
    if (total < 2) return null;

    var seen = 0;
    for (final other in items) {
      if (other.displayTitle == item.displayTitle) seen++;
      if (other.id == item.id) break;
    }
    return t.repeatOf(seen, total);
  }

  static IconData _typeIcon(CollectionItemType type) => switch (type) {
    CollectionItemType.song => Icons.music_note,
    CollectionItemType.bibleVerse => Icons.menu_book,
    CollectionItemType.sermon => Icons.mic_outlined,
    CollectionItemType.freeSlide => Icons.text_fields,
    CollectionItemType.imageSlide => Icons.slideshow_outlined,
    CollectionItemType.videoSlide => Icons.videocam_outlined,
    CollectionItemType.announcement => Icons.campaign_outlined,
    CollectionItemType.section => Icons.label_outline,
  };
}

/// Marks the row that is on the projector while the operator is elsewhere.
class _OnAirDot extends StatelessWidget {
  const _OnAirDot();

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Tooltip(
      message: t.onScreenNow,
      child: Container(
        margin: const EdgeInsets.only(left: AppSpace.xs),
        width: 7,
        height: 7,
        decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.number, required this.isActive});

  /// What the operator counts, which skips the moments: the third song is 3
  /// however many marks divide the service above it.
  final int number;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent : AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.xs),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badges for the per-item settings: design, note, auto-advance.
class _TileFlags extends StatelessWidget {
  const _TileFlags({required this.model, required this.item});

  final ControlModel model;
  final CollectionItem item;

  @override
  Widget build(BuildContext context) {
    final flags = <Widget>[
      if (item.templateId != null)
        _Flag(
          icon: Icons.palette_outlined,
          label:
              model.findTemplate(item.templateId!)?.nameIn(L10n.of(context)) ??
              L10n.of(context).design,
          color: AppColors.accent,
        ),
      if (item.autoAdvanceSecs != null)
        _Flag(
          icon: Icons.timer_outlined,
          label: '${item.autoAdvanceSecs}s',
          color: AppColors.success,
        ),
      if (item.plannedSecs != null)
        _Flag(
          icon: Icons.schedule,
          label: clockText(Duration(seconds: item.plannedSecs!)),
          color: AppColors.textTertiary,
        ),
      if (item.notes?.isNotEmpty == true)
        _Flag(icon: Icons.sticky_note_2_outlined, label: item.notes!, color: AppColors.note),
    ];

    if (flags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 3),
      child: Wrap(spacing: AppSpace.sm, runSpacing: 2, children: flags),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 2),
        // Flexible, not a fixed max width: the panel is narrow and a long note
        // has to give way rather than overflow the row.
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Item menu ─────────────────────────────────────────────────────────────────

class _ItemMenuButton extends StatelessWidget {
  const _ItemMenuButton({required this.model, required this.item});

  final ControlModel model;
  final CollectionItem item;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 15, color: AppColors.textDisabled),
      padding: EdgeInsets.zero,
      iconSize: 15,
      tooltip: t.itemOptions,
      color: AppColors.surfaceControl,
      itemBuilder: (_) => _itemMenuEntries(L10n.of(context), item),
      onSelected: (value) => _runItemAction(context, model, item, value),
    );
  }
}

/// Whether the item's name is its own, rather than derived from what it holds.
///
/// A song is named by the song and a reading by its reference, so renaming
/// those would either lie or have to be undone somewhere else. Everything an
/// operator imports arrives named after a file.
bool _canRename(CollectionItemType type) => switch (type) {
  CollectionItemType.song || CollectionItemType.bibleVerse => false,
  _ => true,
};

/// Whether the words on this item's slides were typed into the app, and so can
/// be typed again.
///
/// A song and a passage are read from the library and the Bible; everything
/// else is a file. These two the operator wrote, usually sitting beside the
/// preacher, and getting a point wrong the first time is the normal case.
bool _canEditContent(CollectionItemType type) =>
    type == CollectionItemType.sermon || type == CollectionItemType.freeSlide;

String _editLabel(L10n t, CollectionItemType type) =>
    type == CollectionItemType.sermon ? t.sermonEdit : t.freeSlideEdit;

List<PopupMenuEntry<String>> _itemMenuEntries(L10n t, CollectionItem item) => [
  // A moment holds nothing of its own: no design, no notes, no duration. What
  // it has is a name and a place in the order.
  if (item.isSection) ...[
    PopupMenuItem(
      value: 'rename',
      height: 38,
      child: AppMenuRow(icon: Icons.drive_file_rename_outline, label: t.rename),
    ),
    PopupMenuItem(
      value: 'template',
      height: 38,
      child: AppMenuRow(
        icon: Icons.palette_outlined,
        label: item.templateId == null ? t.momentDesign : t.changeDesign,
      ),
    ),
    if (item.templateId != null)
      PopupMenuItem(
        value: 'clear_template',
        height: 38,
        child: AppMenuRow(icon: Icons.format_color_reset_outlined, label: t.useCollectionDesign),
      ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: 'remove',
      height: 38,
      child: AppMenuRow(
        icon: Icons.remove_circle_outline,
        label: t.removeFromSetList,
        danger: true,
      ),
    ),
  ] else ...[
    if (_canEditContent(item.type)) ...[
      PopupMenuItem(
        value: 'edit',
        height: 38,
        child: AppMenuRow(icon: Icons.edit_outlined, label: _editLabel(t, item.type)),
      ),
      const PopupMenuDivider(),
    ],
    if (item.type == CollectionItemType.song && item.song != null) ...[
      PopupMenuItem(
        value: 'song_details',
        height: 38,
        child: AppMenuRow(icon: Icons.drive_file_rename_outline, label: t.songDetails),
      ),
      const PopupMenuDivider(),
    ],
    if (_canRename(item.type)) ...[
      PopupMenuItem(
        value: 'rename',
        height: 38,
        child: AppMenuRow(icon: Icons.drive_file_rename_outline, label: t.rename),
      ),
      const PopupMenuDivider(),
    ],
    PopupMenuItem(
      value: 'template',
      height: 38,
      child: AppMenuRow(
        icon: Icons.palette_outlined,
        label: item.templateId == null ? t.ownDesign : t.changeDesign,
      ),
    ),
    if (item.templateId != null)
      PopupMenuItem(
        value: 'clear_template',
        height: 38,
        child: AppMenuRow(icon: Icons.format_color_reset_outlined, label: t.useCollectionDesign),
      ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: 'notes',
      height: 38,
      child: AppMenuRow(
        icon: Icons.sticky_note_2_outlined,
        label: item.notes?.isNotEmpty == true ? t.editNote : t.addNote,
      ),
    ),
    PopupMenuItem(
      value: 'planned',
      height: 38,
      child: AppMenuRow(
        icon: Icons.schedule,
        label: t.plannedMenu,
        trailing: item.plannedSecs != null
            ? clockText(Duration(seconds: item.plannedSecs!))
            : t.plannedNone,
      ),
    ),
    PopupMenuItem(
      value: 'auto_advance',
      height: 38,
      child: AppMenuRow(
        icon: Icons.timer_outlined,
        label: t.autoAdvance,
        trailing: item.autoAdvanceSecs != null ? '${item.autoAdvanceSecs}s' : t.autoAdvanceOff,
      ),
    ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: 'moment_here',
      height: 38,
      child: AppMenuRow(icon: Icons.label_outline, label: t.momentHere),
    ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: 'remove',
      height: 38,
      child: AppMenuRow(
        icon: Icons.remove_circle_outline,
        label: t.removeFromSetList,
        danger: true,
      ),
    ),
  ],
];

/// Opens the item menu at a point, for the right-click path.
Future<void> _showItemMenu(
  BuildContext context,
  ControlModel model,
  CollectionItem item,
  Offset position,
) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final value = await showMenu<String>(
    context: context,
    color: AppColors.surfaceControl,
    position: RelativeRect.fromRect(position & const Size(40, 40), Offset.zero & overlay.size),
    items: _itemMenuEntries(L10n.of(context), item),
  );
  if (value != null && context.mounted) {
    await _runItemAction(context, model, item, value);
  }
}

Future<void> _runItemAction(
  BuildContext context,
  ControlModel model,
  CollectionItem item,
  String value,
) async {
  final cubit = context.read<ControlCubit>();
  final collectionId = model.activeCollection?.id;
  if (collectionId == null) return;

  switch (value) {
    case 'moment_here':
      final name = await askMomentName(context);
      final at = model.activeCollection?.items.indexWhere((i) => i.id == item.id) ?? -1;
      if (name != null && at >= 0) await cubit.addSection(name, before: at);
    case 'edit':
      await _editItemContent(context, item, cubit);
    case 'rename':
      await _showRenameDialog(context, item, cubit);
    case 'song_details':
      await _showSongDetailsDialog(context, item, cubit);
    case 'template':
      final picked = await showTemplatePicker(
        context,
        repo: Modular.get<TemplateRepository>(),
        currentTemplateId: item.templateId,
      );
      // The picker can also make, change and delete designs.
      await cubit.refreshTemplates();
      if (picked != null) cubit.setItemTemplate(collectionId, item.id, picked);
    case 'clear_template':
      cubit.setItemTemplate(collectionId, item.id, null);
    case 'notes':
      await _showNotesDialog(context, item, cubit);
    case 'planned':
      await _showPlannedDialog(context, item, cubit);
    case 'auto_advance':
      await _showAutoAdvanceDialog(context, item, cubit);
    case 'remove':
      await _removeWithUndo(context, cubit, model, item);
  }
}

/// Reopens the dialog the item was written in, filled with what it holds.
Future<void> _editItemContent(BuildContext context, CollectionItem item, ControlCubit cubit) async {
  final content = item.contentJson;
  switch (item.type) {
    case CollectionItemType.sermon:
      final draft = await showSermonDialog(
        context,
        initial: (
          title: content?['title'] as String? ?? '',
          points: List<String>.from(content?['points'] as List? ?? const []),
        ),
      );
      if (draft != null) {
        await cubit.updateSermon(item.id, title: draft.title, points: draft.points);
      }
    case CollectionItemType.freeSlide:
      final result = await showFreeSlideDialog(
        context,
        initial: FreeSlideResult(
          text: content?['text'] as String? ?? '',
          title: content?['title'] as String?,
        ),
      );
      if (result != null) {
        await cubit.updateFreeSlide(item.id, text: result.text, title: result.title);
      }
    default:
      break;
  }
}

// ── Remove ────────────────────────────────────────────────────────────────────

/// Takes the item out and offers the way back.
///
/// Removing was immediate and final, on a panel where the menu that does it is
/// two pixels from the one that changes a design.
Future<void> _removeWithUndo(
  BuildContext context,
  ControlCubit cubit,
  ControlModel model,
  CollectionItem item,
) async {
  final t = L10n.of(context);
  final items = model.activeCollection?.items ?? const <CollectionItem>[];
  final index = items.indexWhere((i) => i.id == item.id);
  final messenger = ScaffoldMessenger.of(context);

  await cubit.removeItem(item.id);

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(t.itemRemoved(item.titleIn(t))),
      duration: const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      width: 420,
      action: SnackBarAction(label: t.undo, onPressed: () => cubit.restoreItem(item, index)),
    ),
  );
}

// ── Rename dialog ─────────────────────────────────────────────────────────────

Future<void> _showRenameDialog(
  BuildContext context,
  CollectionItem item,
  ControlCubit cubit,
) async {
  final t = L10n.of(context);
  final name = await showDialog<String>(
    context: context,
    // Selected, not just filled: every name worth changing is a long one that
    // an import chose, and the operator should not have to clear it by hand.
    builder: (_) => TextControllerScope(
      text: item.displayTitle,
      selectAll: true,
      builder: (ctx, ctrl) => AppDialog(
        title: t.rename,
        icon: Icons.drive_file_rename_outline,
        width: 380,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          const SizedBox(width: AppSpace.sm),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(t.save)),
        ],
        child: AppTextField(
          controller: ctrl,
          hintText: t.itemName,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
      ),
    ),
  );
  // An empty name would leave the row with nothing to click on.
  if (name == null || name.isEmpty || name == item.displayTitle) return;
  await cubit.setItemTitle(item.id, name);
}

/// A song's title and author, changed from the service: the operator sees the
/// typo in the set list and should not have to go looking for the song.
Future<void> _showSongDetailsDialog(
  BuildContext context,
  CollectionItem item,
  ControlCubit cubit,
) async {
  final song = item.song;
  if (song == null) return;
  final result = await showDialog<({String title, String author})>(
    context: context,
    builder: (_) => _SongDetailsDialog(song: song),
  );
  if (result != null) {
    await cubit.updateSongDetails(item.id, title: result.title, author: result.author);
  }
}

class _SongDetailsDialog extends StatefulWidget {
  const _SongDetailsDialog({required this.song});

  final Song song;

  @override
  State<_SongDetailsDialog> createState() => _SongDetailsDialogState();
}

class _SongDetailsDialogState extends State<_SongDetailsDialog> {
  late final _title = TextEditingController(text: widget.song.title);
  late final _author = TextEditingController(text: widget.song.author ?? '');

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, (title: _title.text, author: _author.text));

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AppDialog(
      title: t.songDetails,
      icon: Icons.drive_file_rename_outline,
      width: 420,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        const SizedBox(width: AppSpace.sm),
        FilledButton(onPressed: _save, child: Text(t.save)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _title,
            label: t.songTitle,
            hintText: t.songTitle,
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _author,
            label: t.songAuthor,
            hintText: t.songAuthor,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(t.songDetailsNote, style: AppText.rowSubtitle),
        ],
      ),
    );
  }
}

// ── Auto-advance dialog ───────────────────────────────────────────────────────

Future<void> _showAutoAdvanceDialog(
  BuildContext context,
  CollectionItem item,
  ControlCubit cubit,
) async {
  final t = L10n.of(context);
  final result = await showDialog<int?>(
    context: context,
    builder: (_) => TextControllerScope(
      text: item.autoAdvanceSecs?.toString() ?? '',
      builder: (ctx, ctrl) => AppDialog(
        title: t.autoAdvance,
        icon: Icons.timer_outlined,
        width: 360,
        actions: [
          if (item.autoAdvanceSecs != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, -1),
              style: TextButton.styleFrom(foregroundColor: kDestructive),
              child: Text(t.remove),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.titleIn(t), style: const TextStyle(color: kTextSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Text(t.advanceAfter, style: TextStyle(color: kTextSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 10, 15, 20, 30, 60]
                  .map(
                    (s) => ActionChip(
                      label: Text('${s}s'),
                      backgroundColor: kDialogSurface,
                      labelStyle: const TextStyle(color: kTextPrimary, fontSize: 12),
                      onPressed: () => Navigator.pop(ctx, s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: ctrl,
                    hintText: t.customSeconds,
                    onSubmitted: (text) {
                      final v = int.tryParse(text);
                      if (v != null && v > 0) Navigator.pop(ctx, v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final v = int.tryParse(ctrl.text);
                    if (v != null && v > 0) Navigator.pop(ctx, v);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (result == null) return;
  await cubit.setItemAutoAdvance(item.id, result == -1 ? null : result);
}

// ── Notes dialog ──────────────────────────────────────────────────────────────

Future<void> _showNotesDialog(BuildContext context, CollectionItem item, ControlCubit cubit) async {
  final t = L10n.of(context);
  final saved = await showDialog<String?>(
    context: context,
    builder: (_) => TextControllerScope(
      text: item.notes ?? '',
      builder: (ctx, ctrl) => AppDialog(
        title: t.noteFor(item.titleIn(t)),
        icon: Icons.sticky_note_2_outlined,
        width: 380,
        actions: [
          if (item.notes?.isNotEmpty == true)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              style: TextButton.styleFrom(foregroundColor: kDestructive),
              child: Text(t.clear),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          const SizedBox(width: 8),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(t.save)),
        ],
        child: AppTextField(
          controller: ctrl,
          hintText: t.internalNote,
          maxLines: 5,
          autofocus: true,
        ),
      ),
    ),
  );
  if (saved == null) return;
  cubit.updateItemNotes(item.id, saved.isEmpty ? null : saved);
}

/// Sets how long an item is meant to take, by typing it.
Future<void> _showPlannedDialog(
  BuildContext context,
  CollectionItem item,
  ControlCubit cubit,
) async {
  // -1 clears the plan; null is cancel.
  final result = await showDialog<int>(
    context: context,
    builder: (_) => _PlannedDialog(item: item),
  );
  if (result == null) return;
  await cubit.setItemPlanned(item.id, result == -1 ? null : result);
}

/// A widget of its own so the text field's controller lives exactly as long as
/// the field does. Disposed by the caller as soon as the dialog returned, it
/// was gone while the dialog was still animating out, and Enter to save took
/// the app down with it.
class _PlannedDialog extends StatefulWidget {
  const _PlannedDialog({required this.item});

  final CollectionItem item;

  @override
  State<_PlannedDialog> createState() => _PlannedDialogState();
}

class _PlannedDialogState extends State<_PlannedDialog> {
  late final _ctrl = TextEditingController(
    text: widget.item.plannedSecs == null
        ? ''
        : clockText(Duration(seconds: widget.item.plannedSecs!)),
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final secs = parseDuration(_ctrl.text);
    if (secs == null) {
      setState(() => _error = L10n.of(context).plannedInvalid);
      return;
    }
    Navigator.pop(context, secs);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AppDialog(
      title: t.plannedDuration,
      icon: Icons.schedule,
      width: 380,
      actions: [
        if (widget.item.plannedSecs != null)
          TextButton(
            onPressed: () => Navigator.pop(context, -1),
            style: TextButton.styleFrom(foregroundColor: kDestructive),
            child: Text(t.remove),
          ),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        const SizedBox(width: AppSpace.sm),
        FilledButton(onPressed: _submit, child: Text(t.save)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.item.titleIn(t), style: const TextStyle(color: kTextSecondary, fontSize: 12)),
          const SizedBox(height: AppSpace.sm),
          Text(t.plannedIntro, style: AppText.body),
          const SizedBox(height: AppSpace.md),
          AppTextField(
            controller: _ctrl,
            hintText: t.plannedHint,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// The planned length of the whole plan, or null when no item has one.
String? _plannedTotal(L10n t, Collection collection) {
  final length = plannedLength(collection);
  if (length.total == Duration.zero) return null;
  final time = clockText(length.total);
  return length.unplanned == 0
      ? t.plannedTotal(time)
      : t.plannedTotalPartial(time, length.unplanned);
}
