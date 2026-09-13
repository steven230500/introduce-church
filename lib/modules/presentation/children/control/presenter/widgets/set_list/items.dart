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
                color: AppColors.textMuted,
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
              const _AddItemMenu(),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            itemCount: items.length,
            // The default handle is a second trailing control on a panel that
            // is already too narrow for its titles. The order badge drags
            // instead, which costs no width because it is there regardless.
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              context.read<ControlCubit>().reorderItem(oldIndex, newIndex);
            },
            itemBuilder: (context, index) => _SetListTile(
              key: ValueKey(items[index].id),
              model: model,
              item: items[index],
              index: index,
              isActive: model.currentItemIndex == index,
              isOnAir: model.isLiveItem(index),
            ),
          ),
        ),
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
    required this.isActive,
    required this.isOnAir,
  });

  final ControlModel model;
  final CollectionItem item;
  final int index;

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
          margin: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.sm + 2,
            AppSpace.xs,
            AppSpace.sm + 2,
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
                index: index,
                child: Tooltip(
                  message: t.dragToReorder,
                  waitDuration: const Duration(milliseconds: 600),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: _OrderBadge(index: index, isActive: isActive),
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
                            item.displayTitle,
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
                        _subtitle(model, item),
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
  static String _subtitle(ControlModel model, CollectionItem item) {
    final count = item.slides.length;
    final parts = [
      ?_repeat(model, item),
      if (item.displaySubtitle.isNotEmpty) item.displaySubtitle,
      '$count slide${count == 1 ? '' : 's'}',
    ];
    return parts.join('  ·  ');
  }

  /// Which time round this is, when the plan repeats a title.
  ///
  /// A song that comes back as a reprise is normal, and three rows all reading
  /// "NADA ES IMPOSIBLE" tell the operator nothing about which one they are
  /// looking at. Numbering the repeats beats pretending they are distinct.
  static String? _repeat(ControlModel model, CollectionItem item) {
    final items = model.activeCollection?.items ?? const <CollectionItem>[];
    final total = items.where((i) => i.displayTitle == item.displayTitle).length;
    if (total < 2) return null;

    var seen = 0;
    for (final other in items) {
      if (other.displayTitle == item.displayTitle) seen++;
      if (other.id == item.id) break;
    }
    return '$seenª de $total';
  }

  static IconData _typeIcon(CollectionItemType type) => switch (type) {
    CollectionItemType.song => Icons.music_note,
    CollectionItemType.bibleVerse => Icons.menu_book,
    CollectionItemType.sermon => Icons.mic_outlined,
    CollectionItemType.freeSlide => Icons.text_fields,
    CollectionItemType.imageSlide => Icons.slideshow_outlined,
    CollectionItemType.videoSlide => Icons.videocam_outlined,
    CollectionItemType.announcement => Icons.campaign_outlined,
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
  const _OrderBadge({required this.index, required this.isActive});

  final int index;
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
        '${index + 1}',
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textMuted,
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
          label: model.findTemplate(item.templateId!)?.name ?? 'Diseño',
          color: AppColors.accent,
        ),
      if (item.autoAdvanceSecs != null)
        _Flag(
          icon: Icons.timer_outlined,
          label: '${item.autoAdvanceSecs}s',
          color: AppColors.success,
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

List<PopupMenuEntry<String>> _itemMenuEntries(L10n t, CollectionItem item) => [
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
    value: 'auto_advance',
    height: 38,
    child: AppMenuRow(
      icon: Icons.timer_outlined,
      label: t.autoAdvance,
      trailing: item.autoAdvanceSecs != null ? '${item.autoAdvanceSecs}s' : 'apagado',
    ),
  ),
  const PopupMenuDivider(),
  PopupMenuItem(
    value: 'remove',
    height: 38,
    child: AppMenuRow(icon: Icons.remove_circle_outline, label: t.removeFromSetList, danger: true),
  ),
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
    case 'rename':
      await _showRenameDialog(context, item, cubit);
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
    case 'auto_advance':
      await _showAutoAdvanceDialog(context, item, cubit);
    case 'remove':
      await _removeWithUndo(context, cubit, model, item);
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
      content: Text(t.itemRemoved(item.displayTitle)),
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
  // Selected, not just filled: every name worth changing is a long one that
  // an import chose, and the operator should not have to clear it by hand.
  final ctrl = TextEditingController(text: item.displayTitle)
    ..selection = TextSelection(baseOffset: 0, extentOffset: item.displayTitle.length);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AppDialog(
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
  );
  ctrl.dispose();
  // An empty name would leave the row with nothing to click on.
  if (name == null || name.isEmpty || name == item.displayTitle) return;
  await cubit.setItemTitle(item.id, name);
}

// ── Auto-advance dialog ───────────────────────────────────────────────────────

Future<void> _showAutoAdvanceDialog(
  BuildContext context,
  CollectionItem item,
  ControlCubit cubit,
) async {
  final t = L10n.of(context);
  final ctrl = TextEditingController(text: item.autoAdvanceSecs?.toString() ?? '');
  final result = await showDialog<int?>(
    context: context,
    builder: (ctx) => AppDialog(
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
          Text(item.displayTitle, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
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
                child: AppTextField(controller: ctrl, hintText: t.customSeconds),
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
  );
  ctrl.dispose();
  if (result == null) return;
  await cubit.setItemAutoAdvance(item.id, result == -1 ? null : result);
}

// ── Notes dialog ──────────────────────────────────────────────────────────────

Future<void> _showNotesDialog(BuildContext context, CollectionItem item, ControlCubit cubit) async {
  final t = L10n.of(context);
  final ctrl = TextEditingController(text: item.notes ?? '');
  final saved = await showDialog<String?>(
    context: context,
    builder: (ctx) => AppDialog(
      title: t.noteFor(item.displayTitle),
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
      child: AppTextField(controller: ctrl, hintText: t.internalNote, maxLines: 5, autofocus: true),
    ),
  );
  ctrl.dispose();
  if (saved == null) return;
  cubit.updateItemNotes(item.id, saved.isEmpty ? null : saved);
}
