part of '../../page.dart';

/// The set list: the ordered plan for a service.
class _SetListPanel extends StatelessWidget {
  const _SetListPanel({required this.model, required this.width});

  final ControlModel model;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SetListHeader(model: model),
          const Divider(color: AppColors.divider, height: 1),
          Expanded(child: _SetListItems(model: model)),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

/// Names the collection being edited and holds its actions.
///
/// The old header said "Set List" and hid the collection behind a 120px
/// dropdown, so there was no way to tell at a glance which service you were
/// building.
class _SetListHeader extends StatelessWidget {
  const _SetListHeader({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final collection = model.activeCollection;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.xs, AppSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  collection?.name ?? t.setList,
                  style: AppText.panelTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  _subtitle(L10n.of(context), collection),
                  style: AppText.rowSubtitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (model.collections.isNotEmpty) _CollectionSwitcher(model: model),
          _CollectionMenu(model: model),
        ],
      ),
    );
  }

  static String _subtitle(L10n t, Collection? collection) {
    if (collection == null) return t.noCollectionOpen;
    final items = t.itemCount(collection.items.length);
    final date = collection.serviceDate;
    if (date == null) return items;
    return '$items  •  ${date.day}/${date.month}/${date.year}';
  }
}

/// Switches the open collection without leaving the presenter.
class _CollectionSwitcher extends StatelessWidget {
  const _CollectionSwitcher({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.unfold_more_rounded, color: AppColors.textMuted, size: 17),
      tooltip: t.changeCollection,
      color: AppColors.surfaceControl,
      itemBuilder: (_) => [
        for (final collection in model.collections)
          PopupMenuItem(
            value: collection.id,
            height: 38,
            child: AppMenuRow(
              icon: collection.id == model.activeCollection?.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              label: collection.name,
              trailing: '${collection.items.length}',
            ),
          ),
      ],
      onSelected: (id) {
        final collection = model.collections.firstWhere((c) => c.id == id);
        context.read<ControlCubit>().selectCollection(collection);
      },
    );
  }
}

/// Actions that apply to the whole collection.
class _CollectionMenu extends StatelessWidget {
  const _CollectionMenu({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final collection = model.activeCollection;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 17),
      tooltip: t.collectionOptions,
      color: AppColors.surfaceControl,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'new',
          height: 38,
          child: AppMenuRow(icon: Icons.add, label: t.newCollection),
        ),
        PopupMenuItem(
          value: 'open_file',
          height: 38,
          child: AppMenuRow(icon: Icons.folder_open_outlined, label: t.openFromFile),
        ),
        if (collection != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'edit',
            height: 38,
            child: AppMenuRow(icon: Icons.edit_outlined, label: t.nameAndDate),
          ),
          PopupMenuItem(
            value: 'duplicate',
            height: 38,
            child: AppMenuRow(icon: Icons.copy_all_outlined, label: t.duplicateForAnotherSunday),
          ),
          PopupMenuItem(
            value: 'template',
            height: 38,
            child: AppMenuRow(icon: Icons.palette_outlined, label: t.slideDesign),
          ),
          PopupMenuItem(
            value: 'audio',
            height: 38,
            child: AppMenuRow(
              icon: Icons.music_note_outlined,
              label: collection.bgAudioPath == null ? t.backgroundAudio : t.changeBackgroundAudio,
            ),
          ),
          if (collection.bgAudioPath != null)
            PopupMenuItem(
              value: 'clear_audio',
              height: 38,
              child: AppMenuRow(icon: Icons.music_off_outlined, label: t.removeBackgroundAudio),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'save_file',
            height: 38,
            child: AppMenuRow(icon: Icons.save_alt_outlined, label: t.saveAsFile),
          ),
          PopupMenuItem(
            value: 'export',
            height: 38,
            child: AppMenuRow(icon: Icons.ios_share_outlined, label: t.printableList),
          ),
          PopupMenuItem(
            value: 'delete',
            height: 38,
            child: AppMenuRow(icon: Icons.delete_outline, label: t.deleteCollection, danger: true),
          ),
        ],
      ],
      onSelected: (value) => _handle(context, value, collection),
    );
  }

  Future<void> _handle(BuildContext context, String value, Collection? collection) async {
    final t = L10n.of(context);
    final cubit = context.read<ControlCubit>();

    if (value == 'new') {
      final draft = await showCollectionDialog(context);
      if (draft != null) {
        await cubit.createCollection(draft.name, serviceDate: draft.date);
      }
      return;
    }

    if (collection == null) return;

    switch (value) {
      case 'edit':
        final draft = await showCollectionDialog(context, existing: collection);
        if (draft != null) {
          await cubit.updateCollection(collection.id, draft.name, serviceDate: draft.date);
        }

      case 'duplicate':
        final copy = await showCollectionDialog(context, duplicating: collection);
        if (copy != null) {
          await cubit.duplicateCollection(collection, name: copy.name, serviceDate: copy.date);
        }

      case 'template':
        final templateId = await showTemplatePicker(
          context,
          repo: Modular.get<TemplateRepository>(),
          currentTemplateId: collection.templateId,
        );
        if (templateId != null) {
          cubit.setCollectionTemplate(collection.id, templateId);
        }

      case 'audio':
        // The picker steals focus from the popup; let the menu close first.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
        );
        final path = result?.files.firstOrNull?.path;
        if (path != null) cubit.setCollectionBgAudio(collection.id, path);

      case 'clear_audio':
        cubit.setCollectionBgAudio(collection.id, null);

      case 'open_file':
        if (context.mounted) await _openServiceFile(context);

      case 'save_file':
        if (context.mounted) await _saveServiceFile(context, collection);

      case 'export':
        if (context.mounted) await _exportSetList(context, collection);

      case 'delete':
        if (!context.mounted) return;
        final confirmed = await showAppConfirmDialog(
          context,
          title: t.deleteCollection,
          message: '${t.deleteCollectionQuestion(collection.name)} ${t.deleteCollectionBody}',
          confirmLabel: t.delete,
          destructive: true,
          icon: Icons.delete_outline,
        );
        if (confirmed) cubit.deleteCollection(collection.id);
    }
  }
}
