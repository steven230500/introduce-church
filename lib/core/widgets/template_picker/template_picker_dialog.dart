import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../models/media_item.dart';
import '../../models/slide_layer.dart';
import '../../models/slide_template.dart';
import '../../repositories/organization_repository.dart';
import '../../repositories/template_repository.dart';
import '../media_library/media_library_dialog.dart';
import 'canvas_snap.dart';
import 'color_field.dart';
import '../slide_view.dart';
import 'template_editor_cubit.dart';
import 'template_picker_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';

/// Shows a grid of presets + custom templates. Returns selected template id.
Future<String?> showTemplatePicker(
  BuildContext context, {
  required TemplateRepository repo,
  required String? currentTemplateId,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => TemplatePickerCubit(repo, initialId: currentTemplateId)..load(),
      child: const _TemplatePickerDialog(),
    ),
  );
}

class _TemplatePickerDialog extends StatelessWidget {
  const _TemplatePickerDialog();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplatePickerCubit, TemplatePickerState>(
      builder: (context, state) {
        final cubit = context.read<TemplatePickerCubit>();
        final loaded = state is TemplatePickerLoadedState ? state : null;

        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 780,
            height: 540,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/casavida-isologo-white.png',
                        height: 18,
                        opacity: const AlwaysStoppedAnimation(0.55),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Seleccionar template',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Nuevo template'),
                        onPressed: () async {
                          final result = await showTemplateEditor(
                            context,
                            repo: cubit.repo,
                            initial: SlideTemplate.defaultTemplate,
                            isNew: true,
                          );
                          if (result != null) await cubit.saveNew(result);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Grid
                Expanded(
                  child: loaded == null
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 16 / 10,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: loaded.all.length,
                          itemBuilder: (_, i) {
                            final t = loaded.all[i];
                            final isCustom = !t.id.startsWith('preset_');
                            return _TemplateTile(
                              template: t,
                              isSelected: loaded.selectedId == t.id,
                              isCustom: isCustom,
                              onTap: () => cubit.select(t.id),
                              onEdit: isCustom
                                  ? () async {
                                      final result = await showTemplateEditor(
                                        context,
                                        repo: cubit.repo,
                                        initial: t,
                                        isNew: false,
                                      );
                                      if (result != null) {
                                        await cubit.updateCustom(result);
                                      }
                                    }
                                  : null,
                              onDelete: isCustom ? () => cubit.deleteCustom(t.id) : null,
                              onDuplicate: () => cubit.duplicate(t),
                            );
                          },
                        ),
                ),

                // Footer
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: loaded == null
                            ? null
                            : () => Navigator.pop(context, loaded.selectedId),
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.isSelected,
    required this.isCustom,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
  });

  final SlideTemplate template;
  final bool isSelected;
  final bool isCustom;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                // Preview thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppColors.accent : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SlideView(
                        content: 'Texto de ejemplo',
                        reference: 'Juan 3:16',
                        template: template,
                      ),
                    ),
                  ),
                ),

                // Actions overlay
                Positioned(
                  top: 4,
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onDuplicate != null) _SmallIconBtn(Icons.copy_outlined, onDuplicate!),
                      if (isCustom && onEdit != null) _SmallIconBtn(Icons.edit, onEdit!),
                      if (isCustom && onDelete != null)
                        _SmallIconBtn(Icons.delete_outline, onDelete!, danger: true),
                    ],
                  ),
                ),

                // Selected check
                if (isSelected)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            template.name,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  const _SmallIconBtn(this.icon, this.onTap, {this.danger = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 13, color: danger ? Colors.red.shade300 : Colors.white),
      ),
    );
  }
}

// ── Template Editor ───────────────────────────────────────────────────────────

Future<SlideTemplate?> showTemplateEditor(
  BuildContext context, {
  required TemplateRepository repo,
  required SlideTemplate initial,
  required bool isNew,
}) {
  return showDialog<SlideTemplate>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) =>
          TemplateEditorCubit(repo, Modular.get<OrganizationRepository>(), initial)..loadPalette(),
      child: _TemplateEditorDialog(isNew: isNew),
    ),
  );
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog({required this.isNew});
  final bool isNew;

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _sampleCtrl;
  late TextEditingController _sampleRefCtrl;

  @override
  void initState() {
    super.initState();
    final t = context.read<TemplateEditorCubit>().state.template;
    // Saving a built-in design creates a copy rather than changing it, so the
    // name is offered already distinct. Four designs called "Oscuro clásico"
    // is what happens when it is not.
    final fromPreset = SlideTemplate.findPreset(t.id) != null;
    final suggested = fromPreset ? '${t.name} (mío)' : t.name;
    _nameCtrl = TextEditingController(text: suggested)
      ..selection = TextSelection(baseOffset: 0, extentOffset: suggested.length);
    _sampleCtrl = TextEditingController(
      text: '"Porque de tal manera amó Dios al mundo,\nque ha dado a su Hijo unigénito"',
    );
    _sampleRefCtrl = TextEditingController(text: 'Juan 3:16');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sampleCtrl.dispose();
    _sampleRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await context.read<TemplateEditorCubit>().save(_nameCtrl.text);
    if (mounted && saved != null) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TemplateEditorCubit, TemplateEditorState>(
      builder: (context, state) {
        final t = state.template;
        final cubit = context.read<TemplateEditorCubit>();
        void update(SlideTemplate updated) => cubit.update(updated);
        final isLayersMode = t.layers.isNotEmpty;

        // ── Shared sub-builders ─────────────────────────────────────────────

        // What text will sit on, when that can be known. A photo background
        // has no single colour, so no verdict is offered rather than a wrong
        // one.
        final int? backdrop = t.bgType == BackgroundType.image ? null : t.bgColor;

        Widget bgControls() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Fondo'),
            _BgTypeToggle(t, update),
            const SizedBox(height: 10),
            if (t.bgType == BackgroundType.image) ...[
              _ImageBgPicker(
                imagePath: t.bgImagePath,
                onPick: (path) => update(t.copyWith(bgImagePath: path)),
                onClear: () => update(t.copyWith(bgImagePath: null)),
              ),
              const SizedBox(height: 10),
              _SliderRow(
                label: 'Oscuridad',
                value: t.bgOverlayOpacity,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => update(t.copyWith(bgOverlayOpacity: v)),
              ),
            ] else ...[
              ColorField(
                label: t.bgType == BackgroundType.gradient ? 'Color inicio' : 'Color',
                value: t.bgColor,
                saved: state.palette,
                onSave: cubit.saveColor,
                onForget: cubit.forgetColor,
                onChanged: (v) => update(t.copyWith(bgColor: v)),
              ),
              if (t.bgType == BackgroundType.gradient) ...[
                const SizedBox(height: 8),
                ColorField(
                  label: 'Color fin',
                  value: t.bgGradientEnd,
                  saved: state.palette,
                  onSave: cubit.saveColor,
                  onForget: cubit.forgetColor,
                  onChanged: (v) => update(t.copyWith(bgGradientEnd: v)),
                ),
                const SizedBox(height: 8),
                _SliderRow(
                  label: 'Ángulo',
                  value: t.bgGradientAngle,
                  min: 0,
                  max: 360,
                  onChanged: (v) => update(t.copyWith(bgGradientAngle: v)),
                ),
              ],
            ],
          ],
        );

        Widget dialogHeader() => Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 8, 10),
          child: Row(
            children: [
              Image.asset(
                'assets/images/casavida-isologo-white.png',
                height: 18,
                opacity: const AlwaysStoppedAnimation(0.55),
              ),
              const SizedBox(width: 10),
              Text(
                widget.isNew ? 'Nuevo diseño' : 'Editar diseño',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // Up here, where it can be found. The two buttons this replaces
              // sat at the bottom of a scrolling panel, so the mode an editor
              // is in was both invisible and hard to change.
              _ModeToggle(
                inLayers: isLayersMode,
                onSimple: cubit.disableLayers,
                onLayers: cubit.enableLayers,
              ),
              const SizedBox(width: AppSpace.sm),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );

        Widget dialogFooter() => Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: state.saving ? null : _save,
                child: state.saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        );

        Widget sampleFields() => Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _DarkField(
                  controller: _sampleCtrl,
                  hint: 'Texto de muestra',
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _DarkField(
                  controller: _sampleRefCtrl,
                  hint: 'Referencia',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        );

        // ── 3-panel layout (layers mode) ────────────────────────────────────
        if (isLayersMode) {
          return Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 1200,
              height: 700,
              // The header runs the whole width here rather than living in the
              // narrow left column, which could not hold a title and a mode
              // switch at the same time.
              child: Column(
                children: [
                  dialogHeader(),
                  const Divider(height: 1),
                  Expanded(
                    child: Row(
                      children: [
                        // Left: name + bg + layer list
                        SizedBox(
                          width: 240,
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: _nameCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Nombre',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      bgControls(),
                                      const SizedBox(height: 16),
                                      _LayersListSection(
                                        template: t,
                                        selectedLayerId: state.selectedLayerId,
                                        cubit: cubit,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              dialogFooter(),
                            ],
                          ),
                        ),

                        const VerticalDivider(width: 1),

                        // Center: drag-and-drop canvas (expanded)
                        Expanded(
                          child: Container(
                            color: AppColors.background,
                            child: Column(
                              children: [
                                sampleFields(),
                                Expanded(
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Container(
                                        margin: const EdgeInsets.all(16),
                                        clipBehavior: Clip.hardEdge,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.surfaceControl),
                                        ),
                                        child: _LayerCanvas(
                                          template: t,
                                          sampleContent: _sampleCtrl.text,
                                          sampleReference: _sampleRefCtrl.text,
                                          selectedLayerId: state.selectedLayerId,
                                          cubit: cubit,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const VerticalDivider(width: 1),

                        // Right: layer inspector (280px)
                        SizedBox(
                          width: 280,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Propiedades',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    if (state.selectedLayer != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceControl,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          state.selectedLayer!.typeName,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: state.selectedLayer == null
                                    ? const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.touch_app_outlined,
                                              color: AppColors.border,
                                              size: 32,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Selecciona una capa',
                                              style: TextStyle(
                                                color: AppColors.textDisabled,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        padding: const EdgeInsets.all(14),
                                        child: _LayerInspector(
                                          layer: state.selectedLayer!,
                                          cubit: cubit,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // ── 2-panel layout (simple mode) ────────────────────────────────────
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 900,
            height: 600,
            child: Row(
              children: [
                // Left: controls (340px)
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      dialogHeader(),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 20),
                              bgControls(),
                              const SizedBox(height: 20),
                              _SectionLabel('Texto'),
                              _SliderRow(
                                label: 'Tamaño',
                                value: t.fontSize,
                                min: 24,
                                max: 120,
                                onChanged: (v) => update(t.copyWith(fontSize: v)),
                              ),
                              const SizedBox(height: 4),
                              _SliderRow(
                                label: 'Interlineado',
                                value: t.lineHeight,
                                min: 1.0,
                                max: 2.5,
                                decimals: 1,
                                onChanged: (v) => update(t.copyWith(lineHeight: v)),
                              ),
                              const SizedBox(height: 8),
                              _FontWeightPicker(t, update),
                              const SizedBox(height: 8),
                              _FontFamilyPicker(
                                value: t.fontFamily,
                                onChanged: (f) => update(t.copyWith(fontFamily: f)),
                              ),
                              const SizedBox(height: 8),
                              ColorField(
                                label: 'Color texto',
                                value: t.textColor,
                                saved: state.palette,
                                onSave: cubit.saveColor,
                                onForget: cubit.forgetColor,
                                against: backdrop,
                                onChanged: (v) => update(t.copyWith(textColor: v)),
                              ),
                              const SizedBox(height: 8),
                              _TextAlignPicker(t, update),
                              const SizedBox(height: 8),
                              _ValignPicker(t, update),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Sombra', style: TextStyle(fontSize: 12)),
                                  const Spacer(),
                                  Switch(
                                    value: t.textShadow,
                                    onChanged: (v) => update(t.copyWith(textShadow: v)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _SectionLabel('Márgenes'),
                              _SliderRow(
                                label: 'Horizontal',
                                value: t.paddingH,
                                min: 0,
                                max: 200,
                                onChanged: (v) => update(t.copyWith(paddingH: v)),
                              ),
                              _SliderRow(
                                label: 'Vertical',
                                value: t.paddingV,
                                min: 0,
                                max: 200,
                                onChanged: (v) => update(t.copyWith(paddingV: v)),
                              ),
                              const SizedBox(height: 20),
                              _SectionLabel('Referencia'),
                              Row(
                                children: [
                                  const Text('Mostrar', style: TextStyle(fontSize: 12)),
                                  const Spacer(),
                                  Switch(
                                    value: t.showReference,
                                    onChanged: (v) => update(t.copyWith(showReference: v)),
                                  ),
                                ],
                              ),
                              if (t.showReference) ...[
                                const SizedBox(height: 8),
                                _SliderRow(
                                  label: 'Tamaño ref.',
                                  value: t.referenceFontSize,
                                  min: 8,
                                  max: 36,
                                  onChanged: (v) => update(t.copyWith(referenceFontSize: v)),
                                ),
                                const SizedBox(height: 8),
                                ColorField(
                                  label: 'Color ref.',
                                  value: t.referenceColor,
                                  saved: state.palette,
                                  onSave: cubit.saveColor,
                                  onForget: cubit.forgetColor,
                                  against: backdrop,
                                  onChanged: (v) => update(t.copyWith(referenceColor: v)),
                                ),
                                const SizedBox(height: 8),
                                _RefPositionPicker(t, update),
                              ],
                              const SizedBox(height: 20),
                              _SectionLabel('Transición'),
                              _TransitionPicker(
                                value: t.transitionType,
                                onChanged: (v) => update(t.copyWith(transitionType: v)),
                              ),
                              if (t.transitionType != SlideTransitionType.cut) ...[
                                const SizedBox(height: 4),
                                _SliderRow(
                                  label: 'Duración (ms)',
                                  value: t.transitionDurationMs.toDouble(),
                                  min: 100,
                                  max: 1000,
                                  onChanged: (v) =>
                                      update(t.copyWith(transitionDurationMs: v.round())),
                                ),
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      dialogFooter(),
                    ],
                  ),
                ),

                const VerticalDivider(width: 1),

                // Right: live preview
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _DarkField(
                                  controller: _sampleCtrl,
                                  hint: 'Texto de muestra',
                                  maxLines: 2,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: _DarkField(
                                  controller: _sampleRefCtrl,
                                  hint: 'Referencia',
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                margin: const EdgeInsets.all(20),
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.surfaceControl),
                                ),
                                child: SlideView(
                                  content: _sampleCtrl.text,
                                  reference: _sampleRefCtrl.text,
                                  template: t,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Switches between arranging a design with sliders and arranging it by hand.
///
/// Deliberately says what each mode is rather than what pressing it does, so
/// the editor always shows which of the two you are in.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.inLayers, required this.onSimple, required this.onLayers});

  final bool inLayers;
  final VoidCallback onSimple;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.sm + 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            icon: Icons.tune,
            label: 'Simple',
            active: !inLayers,
            onTap: inLayers ? onSimple : null,
          ),
          _ModeButton(
            icon: Icons.layers_outlined,
            label: 'Capas',
            active: inLayers,
            onTap: inLayers ? null : onLayers,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
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
    return GestureDetector(
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
    );
  }
}

// ── Editor sub-widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _BgTypeToggle extends StatelessWidget {
  const _BgTypeToggle(this.t, this.onUpdate);
  final SlideTemplate t;
  final void Function(SlideTemplate) onUpdate;
  @override
  Widget build(BuildContext context) => SegmentedButton<BackgroundType>(
    segments: const [
      // Scaled down rather than wrapped: in the canvas layout these three
      // share a 240px column and were breaking into "Sóli do" and "Imag en".
      ButtonSegment(
        value: BackgroundType.solid,
        icon: Icon(Icons.rectangle_outlined, size: 13),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text('Sólido')),
      ),
      ButtonSegment(
        value: BackgroundType.gradient,
        icon: Icon(Icons.gradient_outlined, size: 13),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text('Grad.')),
      ),
      ButtonSegment(
        value: BackgroundType.image,
        icon: Icon(Icons.image_outlined, size: 13),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text('Imagen')),
      ),
    ],
    selected: {t.bgType},
    onSelectionChanged: (s) => onUpdate(t.copyWith(bgType: s.first)),
    style: ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 10)),
      iconSize: const WidgetStatePropertyAll(13),
    ),
  );
}

class _ImageBgPicker extends StatelessWidget {
  const _ImageBgPicker({required this.imagePath, required this.onPick, required this.onClear});
  final String? imagePath;
  final void Function(String path) onPick;
  final VoidCallback onClear;

  bool get _isUrl =>
      imagePath != null && (imagePath!.startsWith('http://') || imagePath!.startsWith('https://'));

  String get _label {
    if (imagePath == null) return 'Sin imagen';
    if (_isUrl) return Uri.parse(imagePath!).pathSegments.last;
    return File(imagePath!).uri.pathSegments.last;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _label,
                style: TextStyle(
                  fontSize: 11,
                  color: imagePath != null ? AppColors.textSecondary : AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            if (imagePath != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
              ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
                  allowMultiple: false,
                );
                final path = result?.files.firstOrNull?.path;
                if (path != null) onPick(path);
              },
              child: const Text('Archivo'),
            ),
            const SizedBox(width: 4),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () async {
                if (!context.mounted) return;
                final item = await showMediaLibraryDialog(context);
                if (item != null && item.mediaType == MediaType.image) {
                  onPick(item.url);
                }
              },
              child: const Text('Biblioteca'),
            ),
          ],
        ),
        if (imagePath != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 60,
              child: _isUrl
                  ? Image.network(
                      imagePath!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const _BrokenImage(),
                    )
                  : Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const _BrokenImage(),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.surfaceControl,
    child: Center(
      child: Icon(Icons.broken_image_outlined, color: AppColors.textDisabled, size: 20),
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.decimals = 0,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final void Function(double) onChanged;
  final int decimals;

  String get _display => decimals > 0 ? value.toStringAsFixed(decimals) : value.round().toString();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * (decimals > 0 ? 10 : 0.5)).round().clamp(1, 200),
            onChanged: onChanged,
          ),
        ),
        _SliderValue(
          text: _display,
          onSubmitted: (raw) {
            final parsed = double.tryParse(raw.replaceAll(',', '.'));
            if (parsed != null) onChanged(parsed.clamp(min, max));
          },
        ),
      ],
    );
  }
}

/// The number beside a slider, which can also be typed into.
///
/// A slider cannot be asked for 48 on purpose. The value was a label, so the
/// only way to reach an exact size was to nudge the handle and hope.
class _SliderValue extends StatefulWidget {
  const _SliderValue({required this.text, required this.onSubmitted});

  final String text;
  final ValueChanged<String> onSubmitted;

  @override
  State<_SliderValue> createState() => _SliderValueState();
}

class _SliderValueState extends State<_SliderValue> {
  late final TextEditingController _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_SliderValue old) {
    super.didUpdateWidget(old);
    // The slider moved. Do not overwrite what is being typed.
    if (widget.text != old.text && !_focus.hasFocus) _controller.text = widget.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onSubmitted(_controller.text);
    _controller.text = widget.text;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 6),
        ),
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) {
          if (!_focus.hasFocus) return;
          _focus.unfocus();
          _commit();
        },
      ),
    );
  }
}

class _FontWeightPicker extends StatelessWidget {
  const _FontWeightPicker(this.t, this.onUpdate);
  final SlideTemplate t;
  final void Function(SlideTemplate) onUpdate;

  static const _weights = [(300, 'Fino'), (400, 'Normal'), (600, 'Semi'), (700, 'Bold')];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Peso', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<int>(
            value: t.fontWeight,
            isExpanded: true,
            isDense: true,
            items: _weights.map((w) => DropdownMenuItem(value: w.$1, child: Text(w.$2))).toList(),
            onChanged: (v) {
              if (v != null) onUpdate(t.copyWith(fontWeight: v));
            },
          ),
        ),
      ],
    );
  }
}

class _TextAlignPicker extends StatelessWidget {
  const _TextAlignPicker(this.t, this.onUpdate);
  final SlideTemplate t;
  final void Function(SlideTemplate) onUpdate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Alineación', style: TextStyle(fontSize: 12)),
        const Spacer(),
        _AlignBtn(Icons.format_align_left, TextAlign.left, t, onUpdate),
        _AlignBtn(Icons.format_align_center, TextAlign.center, t, onUpdate),
        _AlignBtn(Icons.format_align_right, TextAlign.right, t, onUpdate),
      ],
    );
  }
}

class _AlignBtn extends StatelessWidget {
  const _AlignBtn(this.icon, this.align, this.t, this.onUpdate);
  final IconData icon;
  final TextAlign align;
  final SlideTemplate t;
  final void Function(SlideTemplate) onUpdate;

  @override
  Widget build(BuildContext context) {
    final active = t.textAlign == align;
    return IconButton(
      icon: Icon(icon, size: 18, color: active ? AppColors.accent : AppColors.textMuted),
      onPressed: () => onUpdate(t.copyWith(textAlign: align)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ValignPicker extends StatelessWidget {
  const _ValignPicker(this.t, this.onUpdate);
  final SlideTemplate t;
  final void Function(SlideTemplate) onUpdate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Posición', style: TextStyle(fontSize: 12)),
        const Spacer(),
        _ValignBtn(Icons.vertical_align_top, TextVerticalAlign.top, t, onUpdate),
        _ValignBtn(Icons.vertical_align_center, TextVerticalAlign.center, t, onUpdate),
        _ValignBtn(Icons.vertical_align_bottom, TextVerticalAlign.bottom, t, onUpdate),
      ],
    );
  }
}

class _ValignBtn extends StatelessWidget {
  const _ValignBtn(this.icon, this.valign, this.t, this.onUpdate);
  final IconData icon;
  final TextVerticalAlign valign;
  final SlideTemplate t;
  final void Function(SlideTemplate) onUpdate;

  @override
  Widget build(BuildContext context) {
    final active = t.textValign == valign;
    return IconButton(
      icon: Icon(icon, size: 18, color: active ? AppColors.accent : AppColors.textMuted),
      onPressed: () => onUpdate(t.copyWith(textValign: valign)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RefPositionPicker extends StatelessWidget {
  const _RefPositionPicker(this.t, this.onUpdate);
  final SlideTemplate t;
  final void Function(SlideTemplate) onUpdate;

  static const _opts = [
    (ReferencePosition.bottomLeft, 'Inf. izq.'),
    (ReferencePosition.bottomCenter, 'Inf. centro'),
    (ReferencePosition.bottomRight, 'Inf. der.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Posición ref.', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<ReferencePosition>(
            value: t.referencePosition,
            isExpanded: true,
            isDense: true,
            items: _opts.map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2))).toList(),
            onChanged: (v) {
              if (v != null) onUpdate(t.copyWith(referencePosition: v));
            },
          ),
        ),
      ],
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.surfaceControl,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

// ── Layers list panel (left panel in layers mode) ─────────────────────────────

class _LayersListSection extends StatelessWidget {
  const _LayersListSection({
    required this.template,
    required this.selectedLayerId,
    required this.cubit,
  });

  final SlideTemplate template;
  final String? selectedLayerId;
  final TemplateEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final sorted = [...template.layers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Capas',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Tooltip(
              message: 'Agregar texto',
              child: IconButton(
                icon: const Icon(Icons.text_fields, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: cubit.addTextLayer,
              ),
            ),
            Tooltip(
              message: 'Agregar referencia',
              child: IconButton(
                icon: const Icon(Icons.format_quote, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: cubit.addReferenceLayer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin capas — agrega una.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          )
        else
          ...sorted.map(
            (layer) =>
                _LayerListTile(layer: layer, isSelected: layer.id == selectedLayerId, cubit: cubit),
          ),
      ],
    );
  }
}

class _LayerListTile extends StatelessWidget {
  const _LayerListTile({required this.layer, required this.isSelected, required this.cubit});

  final SlideLayer layer;
  final bool isSelected;
  final TemplateEditorCubit cubit;

  IconData get _icon => switch (layer) {
    TextSlideLayer _ => Icons.text_fields,
    ReferenceSlideLayer _ => Icons.format_quote,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => cubit.selectLayer(layer.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceControl,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 14, color: isSelected ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                layer.typeName,
                style: TextStyle(fontSize: 12, color: isSelected ? AppColors.accent : Colors.white),
              ),
            ),
            GestureDetector(
              onTap: () => cubit.removeLayer(layer.id),
              child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Layer inspector ───────────────────────────────────────────────────────────

class _LayerInspector extends StatelessWidget {
  const _LayerInspector({required this.layer, required this.cubit});

  final SlideLayer layer;
  final TemplateEditorCubit cubit;

  static const _palette = [
    0xFFFFFFFF,
    0xFFEEEEEE,
    0xFFBBBBBB,
    0xFF888888,
    0xFF444444,
    0xFF222222,
    0xFF000000,
    0xFF0A84FF,
    0xFF34C759,
    0xFFFF9500,
    0xFFFF3B30,
    0xFFFF2D55,
    0xFFBF5AF2,
    0xFF5AC8FA,
    0xFFFFCC00,
    0xFF8E8E93,
  ];

  @override
  Widget build(BuildContext context) {
    return switch (layer) {
      TextSlideLayer l => _textInspector(l),
      ReferenceSlideLayer l => _refInspector(l),
    };
  }

  Widget _textInspector(TextSlideLayer l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LayerSlider(
          label: 'Tamaño',
          value: l.fontSize,
          min: 20,
          max: 120,
          onChanged: (v) => cubit.updateLayer(l.copyWith(fontSize: v)),
        ),
        const SizedBox(height: 4),
        _LayerSlider(
          label: 'Interlineado',
          value: l.lineHeight,
          min: 1.0,
          max: 2.5,
          decimals: 1,
          onChanged: (v) => cubit.updateLayer(l.copyWith(lineHeight: v)),
        ),
        const SizedBox(height: 8),
        _LayerWeightRow(
          value: l.fontWeight,
          onChanged: (v) => cubit.updateLayer(l.copyWith(fontWeight: v)),
        ),
        const SizedBox(height: 8),
        _FontFamilyPicker(
          value: l.fontFamily,
          onChanged: (f) => cubit.updateLayer(l.copyWith(fontFamily: f)),
        ),
        const SizedBox(height: 8),
        _LayerAlignRow(
          value: l.textAlign,
          onChanged: (v) => cubit.updateLayer(l.copyWith(textAlign: v)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Sombra', style: TextStyle(fontSize: 12)),
            const Spacer(),
            Switch(
              value: l.textShadow,
              onChanged: (v) => cubit.updateLayer(l.copyWith(textShadow: v)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Color', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        _LayerColorPicker(
          value: l.textColor,
          palette: _palette,
          onChanged: (v) => cubit.updateLayer(l.copyWith(textColor: v)),
        ),
      ],
    );
  }

  Widget _refInspector(ReferenceSlideLayer l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LayerSlider(
          label: 'Tamaño',
          value: l.fontSize,
          min: 8,
          max: 48,
          onChanged: (v) => cubit.updateLayer(l.copyWith(fontSize: v)),
        ),
        const SizedBox(height: 8),
        _FontFamilyPicker(
          value: l.fontFamily,
          onChanged: (f) => cubit.updateLayer(l.copyWith(fontFamily: f)),
        ),
        const SizedBox(height: 8),
        _LayerAlignRow(
          value: l.textAlign,
          onChanged: (v) => cubit.updateLayer(l.copyWith(textAlign: v)),
        ),
        const SizedBox(height: 8),
        const Text('Color', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        _LayerColorPicker(
          value: l.textColor,
          palette: _palette,
          onChanged: (v) => cubit.updateLayer(l.copyWith(textColor: v)),
        ),
      ],
    );
  }
}

class _LayerSlider extends StatelessWidget {
  const _LayerSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.decimals = 0,
  });
  final String label;
  final double value;
  final double min, max;
  final void Function(double) onChanged;
  final int decimals;

  String get _display => decimals > 0 ? value.toStringAsFixed(decimals) : value.round().toString();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) * (decimals > 0 ? 10 : 0.5)).round().clamp(1, 200),
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 32,
        child: Text(_display, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ),
    ],
  );
}

class _LayerWeightRow extends StatelessWidget {
  const _LayerWeightRow({required this.value, required this.onChanged});
  final int value;
  final void Function(int) onChanged;

  static const _weights = [(300, 'Fino'), (400, 'Normal'), (600, 'Semi'), (700, 'Bold')];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('Peso', style: TextStyle(fontSize: 12)),
      const SizedBox(width: 8),
      Expanded(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: _weights.map((w) => DropdownMenuItem(value: w.$1, child: Text(w.$2))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    ],
  );
}

class _FontFamilyPicker extends StatelessWidget {
  const _FontFamilyPicker({required this.value, required this.onChanged});

  final String? value;
  final void Function(String?) onChanged;

  static const _fonts = <String?>[
    null,
    'Helvetica Neue',
    'Avenir',
    'Avenir Next',
    'Gill Sans',
    'Futura',
    'Optima',
    'Georgia',
    'Times New Roman',
    'Palatino',
    'Baskerville',
    'Arial',
    'Trebuchet MS',
    'Impact',
  ];

  @override
  Widget build(BuildContext context) {
    final current = _fonts.contains(value) ? value : null;
    return Row(
      children: [
        const Text('Fuente', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String?>(
            value: current,
            isExpanded: true,
            isDense: true,
            items: _fonts
                .map(
                  (f) => DropdownMenuItem<String?>(
                    value: f,
                    child: Text(
                      f ?? 'Sistema',
                      style: TextStyle(fontFamily: f, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _LayerAlignRow extends StatelessWidget {
  const _LayerAlignRow({required this.value, required this.onChanged});
  final TextAlign value;
  final void Function(TextAlign) onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('Alineación', style: TextStyle(fontSize: 12)),
      const Spacer(),
      for (final (icon, align) in [
        (Icons.format_align_left, TextAlign.left),
        (Icons.format_align_center, TextAlign.center),
        (Icons.format_align_right, TextAlign.right),
      ])
        IconButton(
          icon: Icon(
            icon,
            size: 16,
            color: value == align ? AppColors.accent : AppColors.textMuted,
          ),
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(align),
        ),
    ],
  );
}

class _LayerColorPicker extends StatelessWidget {
  const _LayerColorPicker({required this.value, required this.palette, required this.onChanged});
  final int value;
  final List<int> palette;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: palette.map((c) {
      final sel = c == value;
      return GestureDetector(
        onTap: () => onChanged(c),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Color(c),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: sel ? AppColors.accent : Colors.white24, width: sel ? 2 : 1),
          ),
          child: sel
              ? Icon(Icons.check, size: 13, color: c == 0xFFFFFFFF ? Colors.black : Colors.white)
              : null,
        ),
      );
    }).toList(),
  );
}

// ── Layer canvas (drag-and-drop center panel) ─────────────────────────────────

/// Where the layers of a design are arranged by hand.
///
/// It draws the safe area, and while a layer is being moved it pulls the layer
/// onto the lines it is nearly on and shows which ones those are. Before this
/// everything was placed by eye, which is how text ends up a few pixels off
/// centre on a wall three metres wide.
class _LayerCanvas extends StatefulWidget {
  const _LayerCanvas({
    required this.template,
    required this.sampleContent,
    required this.sampleReference,
    required this.selectedLayerId,
    required this.cubit,
  });

  final SlideTemplate template;
  final String sampleContent;
  final String sampleReference;
  final String? selectedLayerId;
  final TemplateEditorCubit cubit;

  @override
  State<_LayerCanvas> createState() => _LayerCanvasState();
}

class _LayerCanvasState extends State<_LayerCanvas> {
  List<double> _vertical = const [];
  List<double> _horizontal = const [];
  Size _canvas = Size.zero;

  static Rect _rectOf(SlideLayer l) => Rect.fromLTWH(l.x, l.y, l.width, l.height);

  /// Within six pixels on screen, whatever the canvas happens to measure.
  Offset get _tolerance => Offset(
    6 / (_canvas.width == 0 ? 1 : _canvas.width),
    6 / (_canvas.height == 0 ? 1 : _canvas.height),
  );

  void _apply(
    SlideLayer layer,
    Rect proposed, {
    required bool moving,
    bool left = false,
    bool top = false,
    bool right = false,
    bool bottom = false,
  }) {
    final lines = SnapLines.around([
      for (final other in widget.template.layers)
        if (other.id != layer.id) _rectOf(other),
    ]);

    final snapped = moving
        ? snapMove(proposed, lines, _tolerance)
        : snapResize(
            proposed,
            lines,
            _tolerance,
            left: left,
            top: top,
            right: right,
            bottom: bottom,
          );

    if (snapped.vertical != _vertical || snapped.horizontal != _horizontal) {
      setState(() {
        _vertical = snapped.vertical;
        _horizontal = snapped.horizontal;
      });
    }

    final r = snapped.rect;
    widget.cubit.updateLayer(
      layer.copyWithGeometry(x: r.left, y: r.top, width: r.width, height: r.height),
    );
  }

  void _release() {
    if (_vertical.isEmpty && _horizontal.isEmpty) return;
    setState(() {
      _vertical = const [];
      _horizontal = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.template.layers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return LayoutBuilder(
      builder: (_, constraints) {
        _canvas = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTap: () => widget.cubit.selectLayer(null),
          child: Stack(
            children: [
              Positioned.fill(
                child: SlideView(
                  content: '',
                  reference: '',
                  template: widget.template.copyWith(layers: []),
                ),
              ),
              const Positioned.fill(child: IgnorePointer(child: _SafeAreaFrame())),
              ...sorted.map(
                (layer) => _CanvasLayer(
                  layer: layer,
                  isSelected: layer.id == widget.selectedLayerId,
                  canvasSize: _canvas,
                  sampleContent: widget.sampleContent,
                  sampleReference: widget.sampleReference,
                  cubit: widget.cubit,
                  onGeometry: _apply,
                  onRelease: _release,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: _SnapGuides(vertical: _vertical, horizontal: _horizontal),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The area a projector can be trusted to show.
class _SafeAreaFrame extends StatelessWidget {
  const _SafeAreaFrame();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: constraints.maxWidth * kSlideSafeInset,
          vertical: constraints.maxHeight * kSlideSafeInset,
        ),
        // A label rather than a tooltip: this sits under an IgnorePointer so
        // the canvas stays draggable, and nothing under one can be hovered.
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
              ),
            ),
            Positioned(
              left: 3,
              top: 2,
              child: Text(
                'ÁREA SEGURA',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lines a layer has just landed on.
class _SnapGuides extends StatelessWidget {
  const _SnapGuides({required this.vertical, required this.horizontal});

  final List<double> vertical;
  final List<double> horizontal;

  @override
  Widget build(BuildContext context) {
    if (vertical.isEmpty && horizontal.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (_, constraints) => Stack(
        children: [
          for (final x in vertical)
            Positioned(
              left: x * constraints.maxWidth - 0.5,
              top: 0,
              bottom: 0,
              width: 1,
              child: const ColoredBox(color: AppColors.accent),
            ),
          for (final y in horizontal)
            Positioned(
              top: y * constraints.maxHeight - 0.5,
              left: 0,
              right: 0,
              height: 1,
              child: const ColoredBox(color: AppColors.accent),
            ),
        ],
      ),
    );
  }
}

/// How the canvas is told a layer wants to move or change size.
typedef _GeometryChange =
    void Function(
      SlideLayer layer,
      Rect proposed, {
      required bool moving,
      bool left,
      bool top,
      bool right,
      bool bottom,
    });

class _CanvasLayer extends StatelessWidget {
  const _CanvasLayer({
    required this.layer,
    required this.isSelected,
    required this.canvasSize,
    required this.sampleContent,
    required this.sampleReference,
    required this.cubit,
    required this.onGeometry,
    required this.onRelease,
  });

  final SlideLayer layer;
  final bool isSelected;
  final Size canvasSize;
  final String sampleContent;
  final String sampleReference;
  final TemplateEditorCubit cubit;
  final _GeometryChange onGeometry;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final left = layer.x * canvasSize.width;
    final top = layer.y * canvasSize.height;
    final w = layer.width * canvasSize.width;
    final h = layer.height * canvasSize.height;
    final scale = canvasSize.width / 1920;

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => cubit.selectLayer(layer.id),
            onPanUpdate: (d) {
              final dx = d.delta.dx / canvasSize.width;
              final dy = d.delta.dy / canvasSize.height;
              onGeometry(
                layer,
                Rect.fromLTWH(
                  (layer.x + dx).clamp(0.0, 1.0 - layer.width),
                  (layer.y + dy).clamp(0.0, 1.0 - layer.height),
                  layer.width,
                  layer.height,
                ),
                moving: true,
              );
            },
            onPanEnd: (_) => onRelease(),
            onPanCancel: onRelease,
            child: MouseRegion(cursor: SystemMouseCursors.move, child: _layerContent(scale)),
          ),
          if (isSelected)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.accent, width: 1.5)),
              ),
            ),
          if (isSelected) ...[
            _ResizeHandle(_HandlePos.tl, layer, canvasSize, onGeometry, onRelease),
            _ResizeHandle(_HandlePos.tr, layer, canvasSize, onGeometry, onRelease),
            _ResizeHandle(_HandlePos.bl, layer, canvasSize, onGeometry, onRelease),
            _ResizeHandle(_HandlePos.br, layer, canvasSize, onGeometry, onRelease),
          ],
        ],
      ),
    );
  }

  Widget _layerContent(double scale) => switch (layer) {
    TextSlideLayer l => Container(
      color: const Color(0x12FFFFFF),
      alignment: _alignFor(l.textAlign),
      child: Text(
        sampleContent.isEmpty ? 'Texto...' : sampleContent,
        textAlign: l.textAlign,
        style: TextStyle(
          fontFamily: l.fontFamily,
          color: Color(l.textColor),
          fontSize: (l.fontSize * scale).clamp(6.0, 80.0),
          fontWeight: FontWeight.values.firstWhere(
            (fw) => fw.value == l.fontWeight,
            orElse: () => FontWeight.w300,
          ),
          shadows: l.textShadow
              ? const [Shadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(1, 1))]
              : null,
        ),
      ),
    ),
    ReferenceSlideLayer l => Container(
      color: const Color(0x08FFFFFF),
      alignment: _alignFor(l.textAlign),
      child: Text(
        sampleReference.isEmpty ? 'Referencia...' : sampleReference,
        textAlign: l.textAlign,
        style: TextStyle(
          fontFamily: l.fontFamily,
          color: Color(l.textColor),
          fontSize: (l.fontSize * scale).clamp(4.0, 40.0),
        ),
      ),
    ),
  };

  Alignment _alignFor(TextAlign a) => switch (a) {
    TextAlign.left || TextAlign.start => Alignment.centerLeft,
    TextAlign.right || TextAlign.end => Alignment.centerRight,
    _ => Alignment.center,
  };
}

// ── Resize handles ────────────────────────────────────────────────────────────

enum _HandlePos { tl, tr, bl, br }

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle(this.pos, this.layer, this.canvasSize, this.onGeometry, this.onRelease);

  final _HandlePos pos;
  final SlideLayer layer;
  final Size canvasSize;
  final _GeometryChange onGeometry;
  final VoidCallback onRelease;

  static const _sz = 10.0;

  double get _left {
    final lw = layer.width * canvasSize.width;
    return switch (pos) {
      _HandlePos.tl || _HandlePos.bl => -_sz / 2,
      _HandlePos.tr || _HandlePos.br => lw - _sz / 2,
    };
  }

  double get _top {
    final lh = layer.height * canvasSize.height;
    return switch (pos) {
      _HandlePos.tl || _HandlePos.tr => -_sz / 2,
      _HandlePos.bl || _HandlePos.br => lh - _sz / 2,
    };
  }

  MouseCursor get _cursor => switch (pos) {
    _HandlePos.tl || _HandlePos.br => SystemMouseCursors.resizeUpLeftDownRight,
    _HandlePos.tr || _HandlePos.bl => SystemMouseCursors.resizeUpRightDownLeft,
  };

  void _onPan(DragUpdateDetails d) {
    final dx = d.delta.dx / canvasSize.width;
    final dy = d.delta.dy / canvasSize.height;
    const minW = 0.05, minH = 0.03;
    final x = layer.x, y = layer.y, w = layer.width, h = layer.height;

    double nx = x, ny = y, nw = w, nh = h;
    switch (pos) {
      case _HandlePos.tl:
        nx = (x + dx).clamp(0.0, x + w - minW);
        ny = (y + dy).clamp(0.0, y + h - minH);
        nw = x + w - nx;
        nh = y + h - ny;
      case _HandlePos.tr:
        ny = (y + dy).clamp(0.0, y + h - minH);
        nh = y + h - ny;
        nw = (w + dx).clamp(minW, 1.0 - x);
      case _HandlePos.bl:
        nx = (x + dx).clamp(0.0, x + w - minW);
        nw = x + w - nx;
        nh = (h + dy).clamp(minH, 1.0 - y);
      case _HandlePos.br:
        nw = (w + dx).clamp(minW, 1.0 - x);
        nh = (h + dy).clamp(minH, 1.0 - y);
    }

    // Only the corner under the hand looks for a line. Snapping the far edge
    // too would change the box at both ends while one of them is being held.
    onGeometry(
      layer,
      Rect.fromLTWH(nx, ny, nw, nh),
      moving: false,
      left: pos == _HandlePos.tl || pos == _HandlePos.bl,
      top: pos == _HandlePos.tl || pos == _HandlePos.tr,
      right: pos == _HandlePos.tr || pos == _HandlePos.br,
      bottom: pos == _HandlePos.bl || pos == _HandlePos.br,
    );
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: _left,
    top: _top,
    width: _sz,
    height: _sz,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: _onPan,
      onPanEnd: (_) => onRelease(),
      onPanCancel: onRelease,
      child: MouseRegion(
        cursor: _cursor,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ),
    ),
  );
}

// ── Transition picker ─────────────────────────────────────────────────────────

class _TransitionPicker extends StatelessWidget {
  const _TransitionPicker({required this.value, required this.onChanged});

  final SlideTransitionType value;
  final void Function(SlideTransitionType) onChanged;

  static const _options = <(SlideTransitionType, String)>[
    (SlideTransitionType.cut, 'Corte directo'),
    (SlideTransitionType.fade, 'Fade'),
    (SlideTransitionType.slideLeft, 'Deslizar →'),
    (SlideTransitionType.slideRight, 'Deslizar ←'),
    (SlideTransitionType.zoomIn, 'Zoom in'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Tipo', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<SlideTransitionType>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: _options
                .map(
                  (o) => DropdownMenuItem(
                    value: o.$1,
                    child: Text(o.$2, style: const TextStyle(fontSize: 12)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
