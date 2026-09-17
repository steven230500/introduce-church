import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/models/slide_template.dart';
import '../../../../core/repositories/template_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/slide_view.dart';
import '../../../../core/widgets/template_picker/template_picker_dialog.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import '../templates_library_cubit.dart';
import '../../../../core/models/labels.dart';
import '../../../../l10n/l10n.dart';

/// Slide designs. Applying one here sets the look of the active collection,
/// which is the only thing an operator wants from this panel mid-service.
class TemplatesPanel extends StatelessWidget {
  const TemplatesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TemplatesLibraryCubit(Modular.get<TemplateRepository>())..load(),
      child: const _TemplatesPanelView(),
    );
  }
}

class _TemplatesPanelView extends StatelessWidget {
  const _TemplatesPanelView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplatesLibraryCubit, TemplatesLibraryState>(
      builder: (context, state) {
        final cubit = context.read<TemplatesLibraryCubit>();
        final custom = state is TemplatesLibraryLoadedState
            ? state.customTemplates
            : const <SlideTemplate>[];
        final all = [...SlideTemplate.presets, ...custom];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      L10n.of(context).designsSectionCollection,
                      style: AppText.sectionLabel,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.add_rounded,
                    tooltip: L10n.of(context).designsNew,
                    size: 28,
                    iconSize: 16,
                    onTap: () => _create(context, cubit),
                  ),
                ],
              ),
            ),
            if (state is TemplatesLibraryLoadingState)
              const Expanded(
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Expanded(
                child: BlocBuilder<ControlCubit, ControlState>(
                  builder: (context, controlState) {
                    final model = controlState is ControlLoadedState ? controlState.model : null;
                    final activeId = model?.activeCollection?.templateId;

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.md),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpace.sm,
                        mainAxisSpacing: AppSpace.md,
                        childAspectRatio: 16 / 12,
                      ),
                      itemCount: all.length,
                      itemBuilder: (_, i) {
                        final template = all[i];
                        final isCustom = !template.id.startsWith('preset_');
                        return _TemplateTile(
                          template: template,
                          selected: activeId == template.id,
                          isCustom: isCustom,
                          sampleContent: L10n.of(context).sampleVerse,
                          sampleRef: L10n.of(context).sampleVerseRef,
                          onApply: model?.activeCollection == null
                              ? null
                              : () => context.read<ControlCubit>().setCollectionTemplate(
                                  model!.activeCollection!.id,
                                  template.id,
                                ),
                          onEdit: () => isCustom
                              ? _edit(context, cubit, template)
                              : _copyAndEdit(context, cubit, template),
                          onDelete: isCustom ? () => _delete(context, cubit, template) : null,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _create(BuildContext context, TemplatesLibraryCubit cubit) async {
    final result = await showTemplateEditor(
      context,
      repo: cubit.repo,
      initial: SlideTemplate.defaultTemplate,
      isNew: true,
    );
    if (result != null) await cubit.save(result);
    if (context.mounted) await context.read<ControlCubit>().refreshTemplates();
  }

  /// Opens the editor on a copy of a design the app ships with.
  ///
  /// The presets belong to every church, so they cannot be edited in place.
  /// That was shown as no edit button at all, which read as "designs cannot be
  /// changed" - and that is where the operator gave up looking.
  Future<void> _copyAndEdit(
    BuildContext context,
    TemplatesLibraryCubit cubit,
    SlideTemplate preset,
  ) async {
    final l = L10n.of(context);
    final result = await showTemplateEditor(
      context,
      repo: cubit.repo,
      initial: preset.copyWith(id: '', name: l.designCopySuffix(preset.nameIn(l))),
      isNew: true,
    );
    if (result != null) await cubit.save(result);
    if (context.mounted) await context.read<ControlCubit>().refreshTemplates();
  }

  Future<void> _edit(
    BuildContext context,
    TemplatesLibraryCubit cubit,
    SlideTemplate template,
  ) async {
    final result = await showTemplateEditor(
      context,
      repo: cubit.repo,
      initial: template,
      isNew: false,
    );
    if (result != null) await cubit.save(result);
    if (context.mounted) await context.read<ControlCubit>().refreshTemplates();
  }

  Future<void> _delete(
    BuildContext context,
    TemplatesLibraryCubit cubit,
    SlideTemplate template,
  ) async {
    final ok = await showAppConfirmDialog(
      context,
      title: L10n.of(context).designsDeleteTitle,
      message: L10n.of(context).confirmDeleteDesign(template.name),
      confirmLabel: L10n.of(context).delete,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (ok) await cubit.delete(template.id);
    if (ok && context.mounted) await context.read<ControlCubit>().refreshTemplates();
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _TemplateTile extends StatefulWidget {
  const _TemplateTile({
    required this.template,
    required this.selected,
    required this.isCustom,
    required this.sampleContent,
    required this.sampleRef,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
  });

  final SlideTemplate template;
  final bool selected;
  final bool isCustom;
  final String sampleContent;
  final String sampleRef;
  final VoidCallback? onApply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_TemplateTile> createState() => _TemplateTileState();
}

class _TemplateTileState extends State<_TemplateTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Tooltip(
              message: widget.onApply == null
                  ? L10n.of(context).barNoCollection
                  : L10n.of(context).designsApplyToCollection,
              child: GestureDetector(
                onTap: widget.onApply,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.all(AppRadius.md),
                    border: Border.all(
                      color: widget.selected
                          ? AppColors.accent
                          : _hovering
                          ? AppColors.border
                          : AppColors.divider,
                      width: widget.selected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.all(AppRadius.md - 1),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SlideView(
                          content: widget.sampleContent,
                          reference: widget.sampleRef,
                          template: widget.template,
                        ),
                        if (widget.selected)
                          Positioned(
                            top: AppSpace.xs,
                            left: AppSpace.xs,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: AppRadius.all(AppRadius.xs),
                              ),
                              child: Text(
                                L10n.of(context).designsInUse,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        // Always shown, not only under the pointer: an
                        // operator who does not know the editor exists has no
                        // reason to hover a design to find out.
                        Positioned(
                          top: AppSpace.xs,
                          right: AppSpace.xs,
                          child: AnimatedOpacity(
                            duration: AppMotion.fast,
                            opacity: _hovering ? 1 : 0.7,
                            child: Row(
                              children: [
                                _MiniButton(
                                  icon: Icons.edit_outlined,
                                  tooltip: widget.isCustom
                                      ? L10n.of(context).edit
                                      : L10n.of(context).designDuplicateAndEdit,
                                  onTap: widget.onEdit,
                                ),
                                if (widget.isCustom) ...[
                                  const SizedBox(width: 3),
                                  _MiniButton(
                                    icon: Icons.delete_outline,
                                    tooltip: L10n.of(context).delete,
                                    danger: true,
                                    onTap: widget.onDelete,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            widget.template.nameIn(L10n.of(context)),
            style: AppText.rowSubtitle.copyWith(
              color: widget.selected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: danger ? AppColors.danger : AppColors.surfaceControl,
            borderRadius: AppRadius.all(AppRadius.xs),
          ),
          child: Icon(icon, size: 11, color: Colors.white),
        ),
      ),
    );
  }
}
