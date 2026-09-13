import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../core/models/collection.dart';
import '../../../core/models/slide_template.dart';
import '../../../core/repositories/template_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/slide_background.dart';
import '../../../core/widgets/template_picker/template_picker_dialog.dart';
import '../../../core/widgets/ui/app_buttons.dart';
import '../../../core/widgets/ui/empty_state.dart';
import '../../../core/widgets/ui/page_header.dart';
import '../children/control/presenter/cubit/cubit.dart';
import 'widgets/collection_dialog.dart';

/// Every planned service, newest work first. Opening one switches the
/// presenter to it and returns there, because planning and running a service
/// are the same job a few minutes apart.
class CollectionsLibraryPage extends StatelessWidget {
  const CollectionsLibraryPage({required this.onOpenCollection, super.key});

  final VoidCallback onOpenCollection;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      builder: (context, state) {
        if (state is ControlLoadingState) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ControlErrorState) {
          return ErrorStateView(message: state.message, onRetry: context.read<ControlCubit>().load);
        }
        if (state is! ControlLoadedState) {
          return const ErrorStateView(message: 'No se pudieron cargar las colecciones.');
        }

        final cubit = context.read<ControlCubit>();
        final model = state.model;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Colecciones',
              subtitle: model.collections.isEmpty
                  ? null
                  : '${model.collections.length} servicio'
                        '${model.collections.length == 1 ? '' : 's'} planificado'
                        '${model.collections.length == 1 ? '' : 's'}',
              actions: [
                FilledButton.icon(
                  onPressed: () => _create(context, cubit, onOpenCollection),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nueva colección'),
                ),
              ],
            ),
            Expanded(
              child: model.collections.isEmpty
                  ? EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'Sin colecciones',
                      message:
                          'Una colección es el plan de un servicio: '
                          'canciones, versículos y media en orden.',
                      actionLabel: 'Crear la primera',
                      onAction: () => _create(context, cubit, onOpenCollection),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.pageGutter,
                        0,
                        AppSpace.pageGutter,
                        AppSpace.pageGutter,
                      ),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        childAspectRatio: 1.6,
                        crossAxisSpacing: AppSpace.lg,
                        mainAxisSpacing: AppSpace.lg,
                      ),
                      itemCount: model.collections.length,
                      itemBuilder: (_, i) {
                        final collection = model.collections[i];
                        return _CollectionCard(
                          collection: collection,
                          template:
                              model.findTemplate(collection.templateId ?? '') ??
                              SlideTemplate.defaultTemplate,
                          isActive: model.activeCollection?.id == collection.id,
                          onOpen: () {
                            cubit.selectCollection(collection);
                            onOpenCollection();
                          },
                          onRename: () => _rename(context, cubit, collection),
                          onDuplicate: () => _duplicate(context, cubit, collection),
                          onChangeTemplate: () => _changeTemplate(context, cubit, collection),
                          onDelete: () => _delete(context, cubit, collection),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _create(BuildContext context, ControlCubit cubit, VoidCallback onOpen) async {
    final draft = await showCollectionDialog(context);
    if (draft == null) return;
    await cubit.createCollection(draft.name, serviceDate: draft.date);
    onOpen();
  }

  Future<void> _rename(BuildContext context, ControlCubit cubit, Collection collection) async {
    final draft = await showCollectionDialog(context, existing: collection);
    if (draft == null) return;
    await cubit.updateCollection(collection.id, draft.name, serviceDate: draft.date);
  }

  Future<void> _duplicate(BuildContext context, ControlCubit cubit, Collection collection) async {
    final draft = await showCollectionDialog(context, duplicating: collection);
    if (draft == null) return;
    await cubit.duplicateCollection(collection, name: draft.name, serviceDate: draft.date);
  }

  Future<void> _changeTemplate(
    BuildContext context,
    ControlCubit cubit,
    Collection collection,
  ) async {
    final picked = await showTemplatePicker(
      context,
      repo: Modular.get<TemplateRepository>(),
      currentTemplateId: collection.templateId,
    );
    // The picker can also make, change and delete designs.
    await cubit.refreshTemplates();
    if (picked != null) cubit.setCollectionTemplate(collection.id, picked);
  }

  Future<void> _delete(BuildContext context, ControlCubit cubit, Collection collection) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar colección',
      message: '¿Eliminar "${collection.name}"? Se eliminan todos sus elementos.',
      confirmLabel: 'Eliminar',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (ok) await cubit.deleteCollection(collection.id);
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _CollectionCard extends StatefulWidget {
  const _CollectionCard({
    required this.collection,
    required this.template,
    required this.isActive,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onChangeTemplate,
    required this.onDelete,
  });

  final Collection collection;
  final SlideTemplate template;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onChangeTemplate;
  final VoidCallback onDelete;

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final template = widget.template;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.all(AppRadius.xl - 2),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.accent
                  : _hovering
                  ? AppColors.border
                  : AppColors.divider,
              width: widget.isActive ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl - 3)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SlideBackground(template: template),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.md),
                          child: Text(
                            collection.items.isNotEmpty
                                ? collection.items.first.displayTitle
                                : collection.name,
                            style: TextStyle(
                              color: Color(template.textColor).withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (widget.isActive)
                        Positioned(
                          top: AppSpace.sm,
                          left: AppSpace.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.sm - 2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: AppRadius.all(AppRadius.xs),
                            ),
                            child: const Text(
                              'ABIERTA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm + 2,
                  AppSpace.xs,
                  AppSpace.sm + 2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection.name,
                            style: AppText.rowTitle,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _meta(collection),
                            style: AppText.rowSubtitle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textDisabled),
                      padding: EdgeInsets.zero,
                      tooltip: 'Opciones',
                      color: AppColors.surfaceControl,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          height: 38,
                          child: AppMenuRow(icon: Icons.edit_outlined, label: 'Nombre y fecha'),
                        ),
                        PopupMenuItem(
                          value: 'duplicate',
                          height: 38,
                          child: AppMenuRow(
                            icon: Icons.copy_all_outlined,
                            label: 'Duplicar para otro domingo',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'template',
                          height: 38,
                          child: AppMenuRow(
                            icon: Icons.palette_outlined,
                            label: 'Diseño de los slides',
                          ),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          height: 38,
                          child: AppMenuRow(
                            icon: Icons.delete_outline,
                            label: 'Eliminar',
                            danger: true,
                          ),
                        ),
                      ],
                      onSelected: (value) => switch (value) {
                        'rename' => widget.onRename(),
                        'duplicate' => widget.onDuplicate(),
                        'template' => widget.onChangeTemplate(),
                        'delete' => widget.onDelete(),
                        _ => null,
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _meta(Collection collection) {
    final count = collection.items.length;
    final items = '$count elemento${count == 1 ? '' : 's'}';
    final date = collection.serviceDate;
    if (date == null) return items;
    return '$items  •  ${date.day}/${date.month}/${date.year}';
  }
}
