part of '../page.dart';

/// Three columns: the plan, the output, and what comes next.
class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      builder: (context, state) => switch (state) {
        ControlLoadingState() => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        ControlErrorState(:final message) => ErrorStateView(
          message: message,
          onRetry: context.read<ControlCubit>().load,
        ),
        // With nothing open there is nothing for three columns to show, and
        // each used to announce its own emptiness in its own words. One screen
        // that says it once and offers the way out reads better than three
        // panels apologising in parallel.
        ControlLoadedState(:final model) when model.activeCollection == null => _NoCollection(
          model: model,
        ),
        ControlLoadedState(:final model) => BlocBuilder<ShellCubit, ShellState>(
          buildWhen: (a, b) => a.widths != b.widths,
          builder: (context, shell) {
            final layout = context.read<ShellCubit>();
            final columns = Row(
              children: [
                _SetListPanel(model: model, width: shell.widthOf(ShellPanel.setList)),
                PanelResizer(
                  tooltip: L10n.of(context).resizeHint,
                  onDrag: (dx) => layout.resizePanel(ShellPanel.setList, dx),
                  onReset: () => layout.resetPanel(ShellPanel.setList),
                ),
                Expanded(child: _SlidePreview(model: model)),
                PanelResizer(
                  tooltip: L10n.of(context).resizeHint,
                  // This edge is on the panel's left, so dragging left is what
                  // makes it wider.
                  onDrag: (dx) => layout.resizePanel(ShellPanel.queue, -dx),
                  onReset: () => layout.resetPanel(ShellPanel.queue),
                ),
                // The right column always mirrors the projector in some form:
                // the slide queue when the big preview is centre stage, the
                // output panel when the grid is.
                if (model.gridView)
                  _SidePreviewPanel(model: model, width: shell.widthOf(ShellPanel.queue))
                else
                  _SlideQueue(model: model, width: shell.widthOf(ShellPanel.queue)),
              ],
            );
            if (!model.rehearsing) return columns;
            return Column(
              children: [
                _RehearsalBar(model: model),
                Expanded(child: columns),
              ],
            );
          },
        ),
      },
    );
  }
}

// ── Nothing open ──────────────────────────────────────────────────────────────

/// The presenter with no collection loaded.
///
/// Doubles as the way in: the collections an operator already has are one
/// click away, rather than two panels and a menu away.
class _NoCollection extends StatelessWidget {
  const _NoCollection({required this.model});

  final ControlModel model;

  @override
  Widget build(BuildContext context) {
    final recent = model.collections.take(5).toList();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.slideshow_outlined, size: 44, color: AppColors.textDisabled),
              const SizedBox(height: AppSpace.lg),
              Text(
                L10n.of(context).nothingOnScreen,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                recent.isEmpty
                    ? L10n.of(context).collectionExplainer
                    : L10n.of(context).openCollectionToStart,
                textAlign: TextAlign.center,
                style: AppText.rowSubtitle,
              ),
              const SizedBox(height: AppSpace.xl),
              if (recent.isNotEmpty) ...[
                for (final collection in recent) _CollectionShortcut(collection: collection),
                const SizedBox(height: AppSpace.lg),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(L10n.of(context).newCollection),
                  ),
                  if (model.collections.length > recent.length) ...[
                    const SizedBox(width: AppSpace.sm),
                    FilledButton.tonal(
                      onPressed: () => context.read<ShellCubit>().goTo(ShellSection.collections),
                      child: Text(L10n.of(context).seeAll),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final cubit = context.read<ControlCubit>();
    final draft = await showCollectionDialog(context);
    if (draft != null) {
      await cubit.createCollection(draft.name, serviceDate: draft.date);
    }
  }
}

class _CollectionShortcut extends StatelessWidget {
  const _CollectionShortcut({required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final count = collection.items.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm - 2),
      child: GestureDetector(
        onTap: () => context.read<ControlCubit>().selectCollection(collection),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.all(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    collection.name,
                    style: AppText.rowTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(L10n.of(context).itemCount(count), style: AppText.rowSubtitle),
                const SizedBox(width: AppSpace.sm),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textDisabled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
