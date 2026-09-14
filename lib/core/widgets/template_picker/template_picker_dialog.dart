import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../models/labels.dart';
import '../../models/slide_layer.dart';
import '../../models/slide_template.dart';
import '../../repositories/organization_repository.dart';
import '../../repositories/template_repository.dart';
import '../app_dialog.dart';
import '../../../l10n/l10n.dart';
import '../../backgrounds/background_choice.dart';
import '../../motion/motion_scenes.dart';
import '../../motion/scene_names.dart';
import '../backgrounds/background_gallery_dialog.dart';
import '../slide_background.dart';
import 'canvas_snap.dart';
import 'color_field.dart';
import 'editor_controls.dart';
import '../slide_view.dart';
import '../ui/app_buttons.dart';
import '../ui/hover_builder.dart';
import 'template_editor_cubit.dart';
import 'template_picker_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';

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

        return AppDialog(
          title: L10n.of(context).designPickerTitle,
          icon: Icons.palette_outlined,
          width: 780,
          height: 560,
          contentPadding: EdgeInsets.zero,
          headerActions: [
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(L10n.of(context).designsNew),
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
          ],
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L10n.of(context).cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: loaded == null ? null : () => Navigator.pop(context, loaded.selectedId),
              child: Text(L10n.of(context).apply),
            ),
          ],
          child: loaded == null
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 16 / 10,
                    crossAxisSpacing: AppSpace.md,
                    mainAxisSpacing: AppSpace.md,
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
                      onDuplicate: () =>
                          cubit.duplicate(t, name: L10n.of(context).designCopySuffix(t.name)),
                    );
                  },
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
                        content: L10n.of(context).designSampleText,
                        reference: L10n.of(context).sampleVerseRef,
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
            template.nameIn(L10n.of(context)),
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
    // Closing is a decision now, because closing can throw away a design. The
    // barrier used to take one stray click as that decision.
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) =>
          TemplateEditorCubit(repo, Modular.get<OrganizationRepository>(), initial)..loadPalette(),
      child: TemplateEditorDialog(isNew: isNew),
    ),
  );
}

/// The editor itself, for [showTemplateEditor] and for tests, which provide
/// its cubit directly instead of through the app's injector.
class TemplateEditorDialog extends StatefulWidget {
  const TemplateEditorDialog({super.key, required this.isNew});
  final bool isNew;

  @override
  State<TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<TemplateEditorDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _sampleCtrl;
  late TextEditingController _sampleRefCtrl;

  /// The name the editor opened with, so a renamed design counts as changed
  /// even when nothing else was touched.
  late String _openedName;

  bool _controllersReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllersReady) return;
    _controllersReady = true;
    final l = L10n.of(context);
    final t = context.read<TemplateEditorCubit>().state.template;
    // Saving a built-in design creates a copy rather than changing it, so the
    // name is offered already distinct. Four designs called "Oscuro clásico"
    // is what happens when it is not.
    final fromPreset = SlideTemplate.findPreset(t.id) != null;
    final suggested = fromPreset ? l.designMineSuffix(t.nameIn(l)) : t.name;
    _openedName = suggested;
    _nameCtrl = TextEditingController(text: suggested)
      ..selection = TextSelection(baseOffset: 0, extentOffset: suggested.length);
    _sampleCtrl = TextEditingController(text: l.sampleVerseLong);
    _sampleRefCtrl = TextEditingController(text: l.sampleVerseRef);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sampleCtrl.dispose();
    _sampleRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final saved = await context.read<TemplateEditorCubit>().save(
      name.isEmpty ? L10n.of(context).designUntitled : name,
    );
    if (mounted && saved != null) Navigator.pop(context, saved);
  }

  /// Whether the operator is in a text field, where the system's own undo is
  /// the one they mean.
  bool get _typing {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null && focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;

    if (event.logicalKey == LogicalKeyboardKey.escape && !_typing) {
      _close();
      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.keyZ) return KeyEventResult.ignored;
    if (!keys.isMetaPressed && !keys.isControlPressed) return KeyEventResult.ignored;
    // Inside a field, ⌘Z belongs to the field.
    if (_typing) return KeyEventResult.ignored;

    final cubit = context.read<TemplateEditorCubit>();
    keys.isShiftPressed ? cubit.redo() : cubit.undo();
    return KeyEventResult.handled;
  }

  /// Leaves the editor, asking first when leaving would lose something.
  Future<void> _close() async {
    final changed =
        context.read<TemplateEditorCubit>().state.dirty || _nameCtrl.text.trim() != _openedName;
    if (!changed) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AppDialog(
        title: L10n.of(context).designDiscardTitle,
        icon: Icons.warning_amber_rounded,
        width: 380,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(L10n.of(context).designKeepEditing),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(L10n.of(context).designDiscard),
          ),
        ],
        child: Text(L10n.of(context).designDiscardBody, style: AppText.rowSubtitle),
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Sits above the panels rather than on any one of them, so ⌘Z works
    // wherever the operator happens to have clicked last.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: _editor(context),
    );
  }

  Widget _editor(BuildContext context) {
    return BlocBuilder<TemplateEditorCubit, TemplateEditorState>(
      builder: (context, state) {
        final t = state.template;
        final cubit = context.read<TemplateEditorCubit>();
        void update(SlideTemplate updated) => cubit.update(updated);
        final isLayersMode = t.layers.isNotEmpty;

        // ── Shared sub-builders ─────────────────────────────────────────────

        // What text will sit on. For a photo this is its average seen through
        // the darkening layer, which is what makes a verdict possible at all
        // on an image background.
        final backdrop = state.backdrop;

        Future<void> chooseBackground() async {
          final choice = await showBackgroundGallery(
            context,
            current: BackgroundChoice.of(cubit.state.template),
          );
          if (choice != null) update(applyBackground(cubit.state.template, choice));
        }

        final l = L10n.of(context);

        Widget nameField() => EditorSection(
          title: l.designName,
          children: [EditorTextInput(controller: _nameCtrl, fontSize: 13)],
        );

        Widget backgroundSection() => EditorSection(
          title: l.designBackground,
          children: [
            _BgTypeToggle(t, update, onPicture: chooseBackground),
            if (_isPicture(t.bgType)) ...[
              _BackgroundCard(template: t, onChange: chooseBackground),
              // In percent. As a fraction from 0 to 1 the slider had one
              // step - fully clear or fully black - and its number read 0 for
              // everything short of black.
              EditorSlider(
                label: l.bgDarkness,
                value: t.bgOverlayOpacity * 100,
                min: 0,
                max: 100,
                onChanged: (v) => update(t.copyWith(bgOverlayOpacity: v / 100)),
              ),
            ] else ...[
              ColorField(
                label: t.bgType == BackgroundType.gradient ? l.designColorStart : l.designColor,
                value: t.bgColor,
                saved: state.palette,
                onSave: cubit.saveColor,
                onForget: cubit.forgetColor,
                onChanged: (v) => update(t.copyWith(bgColor: v)),
              ),
              if (t.bgType == BackgroundType.gradient) ...[
                ColorField(
                  label: l.designColorEnd,
                  value: t.bgGradientEnd,
                  saved: state.palette,
                  onSave: cubit.saveColor,
                  onForget: cubit.forgetColor,
                  onChanged: (v) => update(t.copyWith(bgGradientEnd: v)),
                ),
                EditorSlider(
                  label: l.designAngle,
                  value: t.bgGradientAngle,
                  min: 0,
                  max: 360,
                  onChanged: (v) => update(t.copyWith(bgGradientAngle: v)),
                ),
              ],
            ],
          ],
        );

        Widget sampleFields() => Container(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: EditorTextInput(
                      controller: _sampleCtrl,
                      hint: l.designSampleHint,
                      maxLines: 2,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    flex: 2,
                    child: EditorTextInput(
                      controller: _sampleRefCtrl,
                      hint: l.designReference,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              // The sample was one two-line verse, so a design was judged on
              // the one length it never has to survive. These are the lengths
              // a real service throws at it.
              _SampleLengths(
                onPick: (content, reference) => setState(() {
                  _sampleCtrl.text = content;
                  _sampleRefCtrl.text = reference;
                }),
              ),
            ],
          ),
        );

        Widget stage(Widget slide) => Expanded(
          child: ColoredBox(
            color: AppColors.canvas,
            child: Column(
              children: [
                // The same row in both modes. It was a second copy once, so
                // the lengths only reached one of them.
                sampleFields(),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        margin: const EdgeInsets.all(AppSpace.xl),
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.all(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: slide,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        Widget column({required double width, required List<Widget> children}) => SizedBox(
          width: width,
          child: ColoredBox(
            color: AppColors.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        );

        // The editor is a dialog like the others: the same header, with the
        // history and the mode switch in it, and the same footer. It used to
        // be a stock Material dialog with its own header and a footer tucked
        // into the left column.
        Widget shell({required double width, required double height, required Widget body}) =>
            AppDialog(
              title: widget.isNew ? l.designsNew : l.designEdit,
              icon: Icons.palette_outlined,
              width: width,
              height: height,
              contentPadding: EdgeInsets.zero,
              onClose: _close,
              headerActions: [
                _HistoryButtons(
                  canUndo: state.canUndo,
                  canRedo: state.canRedo,
                  onUndo: cubit.undo,
                  onRedo: cubit.redo,
                ),
                const SizedBox(width: AppSpace.sm),
                _ModeToggle(
                  inLayers: isLayersMode,
                  onSimple: cubit.disableLayers,
                  onLayers: cubit.enableLayers,
                ),
              ],
              actions: [
                TextButton(onPressed: _close, child: Text(l.cancel)),
                const SizedBox(width: AppSpace.sm),
                FilledButton(
                  onPressed: state.saving ? null : _save,
                  child: state.saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.save),
                ),
              ],
              child: body,
            );

        // ── Layers mode: layers, canvas, inspector ──────────────────────────
        if (isLayersMode) {
          final selected = state.selectedLayer;
          return shell(
            width: 1240,
            height: 740,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                column(
                  width: 280,
                  children: [
                    nameField(),
                    backgroundSection(),
                    _LayersListSection(
                      template: t,
                      selectedLayerId: state.selectedLayerId,
                      cubit: cubit,
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, color: AppColors.divider),
                stage(
                  _LayerCanvas(
                    template: t,
                    sampleContent: _sampleCtrl.text,
                    sampleReference: _sampleRefCtrl.text,
                    selectedLayerId: state.selectedLayerId,
                    cubit: cubit,
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.divider),
                column(
                  width: 300,
                  children: [
                    if (selected == null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xxl),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.touch_app_outlined,
                              color: AppColors.textTertiary,
                              size: 28,
                            ),
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              l.designSelectLayer,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      _LayerInspector(layer: selected, cubit: cubit),
                  ],
                ),
              ],
            ),
          );
        }

        // ── Simple mode: controls and a live preview ─────────────────────────
        return shell(
          width: 960,
          height: 660,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              column(
                width: 360,
                children: [
                  nameField(),
                  backgroundSection(),
                  EditorSection(
                    title: l.designText,
                    children: [
                      EditorSlider(
                        label: l.designSize,
                        value: t.fontSize,
                        min: 24,
                        max: 120,
                        onChanged: (v) => update(t.copyWith(fontSize: v)),
                      ),
                      EditorSlider(
                        label: l.designLineHeight,
                        value: t.lineHeight,
                        min: 1.0,
                        max: 2.5,
                        decimals: 1,
                        onChanged: (v) => update(t.copyWith(lineHeight: v)),
                      ),
                      _WeightPicker(
                        value: t.fontWeight,
                        onChanged: (v) => update(t.copyWith(fontWeight: v)),
                      ),
                      _FontFamilyPicker(
                        value: t.fontFamily,
                        onChanged: (f) => update(t.copyWith(fontFamily: f)),
                      ),
                      _AlignPicker(
                        value: t.textAlign,
                        onChanged: (v) => update(t.copyWith(textAlign: v)),
                      ),
                      _ValignPicker(
                        value: t.textValign,
                        onChanged: (v) => update(t.copyWith(textValign: v)),
                      ),
                      EditorSwitch(
                        label: l.designShadow,
                        value: t.textShadow,
                        onChanged: (v) => update(t.copyWith(textShadow: v)),
                      ),
                      ColorField(
                        label: l.designTextColor,
                        value: t.textColor,
                        saved: state.palette,
                        fromPhoto: state.photoPalette,
                        onSave: cubit.saveColor,
                        onForget: cubit.forgetColor,
                        against: backdrop,
                        onChanged: (v) => update(t.copyWith(textColor: v)),
                      ),
                    ],
                  ),
                  EditorSection(
                    title: l.designMargins,
                    children: [
                      EditorSlider(
                        label: l.designHorizontal,
                        value: t.paddingH,
                        min: 0,
                        max: 200,
                        onChanged: (v) => update(t.copyWith(paddingH: v)),
                      ),
                      EditorSlider(
                        label: l.designVertical,
                        value: t.paddingV,
                        min: 0,
                        max: 200,
                        onChanged: (v) => update(t.copyWith(paddingV: v)),
                      ),
                    ],
                  ),
                  EditorSection(
                    title: l.designReference,
                    children: [
                      EditorSwitch(
                        label: l.designShow,
                        value: t.showReference,
                        onChanged: (v) => update(t.copyWith(showReference: v)),
                      ),
                      if (t.showReference) ...[
                        EditorSlider(
                          label: l.designRefSize,
                          value: t.referenceFontSize,
                          min: 8,
                          max: 36,
                          onChanged: (v) => update(t.copyWith(referenceFontSize: v)),
                        ),
                        _RefPositionPicker(
                          value: t.referencePosition,
                          onChanged: (v) => update(t.copyWith(referencePosition: v)),
                        ),
                        ColorField(
                          label: l.designRefColor,
                          value: t.referenceColor,
                          saved: state.palette,
                          fromPhoto: state.photoPalette,
                          onSave: cubit.saveColor,
                          onForget: cubit.forgetColor,
                          against: backdrop,
                          onChanged: (v) => update(t.copyWith(referenceColor: v)),
                        ),
                      ],
                    ],
                  ),
                  EditorSection(
                    title: l.designTransition,
                    children: [
                      _TransitionPicker(
                        value: t.transitionType,
                        onChanged: (v) => update(t.copyWith(transitionType: v)),
                      ),
                      if (t.transitionType != SlideTransitionType.cut)
                        EditorSlider(
                          label: l.designDurationMs,
                          value: t.transitionDurationMs.toDouble(),
                          min: 100,
                          max: 1000,
                          onChanged: (v) => update(t.copyWith(transitionDurationMs: v.round())),
                        ),
                    ],
                  ),
                ],
              ),
              const VerticalDivider(width: 1, color: AppColors.divider),
              // The design as the room will see it, moving background and all.
              stage(
                SlideMotion(
                  level: MotionLevel.all,
                  child: SlideView(
                    content: _sampleCtrl.text,
                    reference: _sampleRefCtrl.text,
                    template: t,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Back a step, forward a step.
///
/// Designing is trying things, and an operator who nudges a slider and does not
/// like where it landed should not have to remember the number it was on.
class _HistoryButtons extends StatelessWidget {
  const _HistoryButtons({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.undo_rounded, size: 17),
        visualDensity: VisualDensity.compact,
        tooltip: L10n.of(context).designUndo,
        onPressed: canUndo ? onUndo : null,
      ),
      IconButton(
        icon: const Icon(Icons.redo_rounded, size: 17),
        visualDensity: VisualDensity.compact,
        tooltip: L10n.of(context).designRedo,
        onPressed: canRedo ? onRedo : null,
      ),
    ],
  );
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
    final l = L10n.of(context);
    return SizedBox(
      width: 190,
      child: EditorSegmented<bool>(
        selected: inLayers,
        onChanged: (layers) {
          if (layers == inLayers) return;
          layers ? onLayers() : onSimple();
        },
        segments: [
          EditorSegment(value: false, icon: Icons.tune, label: l.designModeSimple),
          EditorSegment(value: true, icon: Icons.layers_outlined, label: l.designModeLayers),
        ],
      ),
    );
  }
}

/// The lengths a design has to survive, one press each.
///
/// A chorus line, an ordinary verse and the longest thing a service is likely
/// to put on the wall. The last one is where designs break, and it was the one
/// nobody ever previewed.
class _SampleLengths extends StatelessWidget {
  const _SampleLengths({required this.onPick});

  final void Function(String content, String reference) onPick;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final samples = <String, (String, String)>{
      l.designSampleShort: (l.designSampleShortText, l.verseTypeChorus),
      l.designSampleNormal: (l.sampleVerseLong, l.sampleVerseRef),
      l.designSampleLong: (l.designSampleLongText, l.designSampleLongRef),
    };
    return Row(
      children: [
        Text(l.designTryWith, style: AppText.rowSubtitle),
        const SizedBox(width: AppSpace.sm),
        for (final entry in samples.entries)
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs + 1),
            child: HoverBuilder(
              cursor: SystemMouseCursors.click,
              builder: (context, hovering) => GestureDetector(
                onTap: () => onPick(entry.value.$1, entry.value.$2),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm + 2, vertical: 4),
                  decoration: BoxDecoration(
                    color: hovering ? AppColors.surfaceRaised : AppColors.surfaceControl,
                    borderRadius: AppRadius.all(AppRadius.xl),
                    border: Border.all(
                      color: hovering ? AppColors.accentOutline : AppColors.border,
                    ),
                  ),
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Editor sub-widgets ────────────────────────────────────────────────────────

String _weightLabel(L10n l, int weight) => switch (weight) {
  300 => l.designWeightLight,
  400 => l.designWeightRegular,
  600 => l.designWeightSemibold,
  _ => l.designWeightBold,
};

bool _isPicture(BackgroundType type) =>
    type == BackgroundType.image || type == BackgroundType.motion || type == BackgroundType.video;

/// Colour, gradient, or a picture behind the text - the app's scenes and the
/// church's own images and loops are all "a background", chosen in the
/// gallery rather than told apart here.
class _BgTypeToggle extends StatelessWidget {
  const _BgTypeToggle(this.t, this.onUpdate, {required this.onPicture});
  final SlideTemplate t;
  final void Function(SlideTemplate) onUpdate;
  final Future<void> Function() onPicture;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final current = _isPicture(t.bgType) ? _BgKind.picture : _BgKind.values[t.bgType.index];
    return EditorSegmented<_BgKind>(
      selected: current,
      segments: [
        EditorSegment(value: _BgKind.solid, icon: Icons.rectangle_outlined, label: l.bgTypeColor),
        EditorSegment(
          value: _BgKind.gradient,
          icon: Icons.gradient_outlined,
          label: l.bgTypeGradient,
        ),
        EditorSegment(
          value: _BgKind.picture,
          icon: Icons.wallpaper_outlined,
          label: l.bgTypePicture,
        ),
      ],
      onChanged: (kind) {
        switch (kind) {
          case _BgKind.solid:
            onUpdate(t.copyWith(bgType: BackgroundType.solid));
          case _BgKind.gradient:
            onUpdate(t.copyWith(bgType: BackgroundType.gradient));
          case _BgKind.picture:
            // Always through the gallery, with the picture this design had
            // before already marked. A design can remember more than one
            // earlier picture, and silently bringing back the wrong one costs
            // more than the one click this saves.
            onPicture();
        }
      },
    );
  }
}

enum _BgKind { solid, gradient, picture }

/// The picture a design has, small, with what kind it is and a way to change it.
class _BackgroundCard extends StatelessWidget {
  const _BackgroundCard({required this.template, required this.onChange});

  final SlideTemplate template;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final kind = switch (template.bgType) {
      BackgroundType.motion => l.bgKindScene(MotionSceneX.fromId(template.bgMotion).label(l)),
      BackgroundType.video => l.bgKindVideo,
      _ => l.bgKindImage,
    };
    return InkWell(
      onTap: onChange,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 96,
              height: 54,
              child: SlideMotion(
                level: MotionLevel.scenes,
                child: SlideBackground(template: template.copyWith(bgOverlayOpacity: 0)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              kind,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 11),
            ),
            onPressed: onChange,
            child: Text(l.bgChange),
          ),
        ],
      ),
    );
  }
}

class _WeightPicker extends StatelessWidget {
  const _WeightPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _weights = [300, 400, 600, 700];

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return EditorField(
      label: l.designWeight,
      child: EditorDropdown<int>(
        value: _weights.contains(value) ? value : 400,
        items: [
          for (final w in _weights)
            DropdownMenuItem(
              value: w,
              child: Text(
                _weightLabel(l, w),
                style: TextStyle(fontWeight: FontWeight.values[(w ~/ 100) - 1]),
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _AlignPicker extends StatelessWidget {
  const _AlignPicker({required this.value, required this.onChanged});

  final TextAlign value;
  final ValueChanged<TextAlign> onChanged;

  @override
  Widget build(BuildContext context) {
    return EditorField(
      label: L10n.of(context).designAlignment,
      child: EditorSegmented<TextAlign>(
        selected: value,
        onChanged: onChanged,
        segments: const [
          EditorSegment(value: TextAlign.left, icon: Icons.format_align_left),
          EditorSegment(value: TextAlign.center, icon: Icons.format_align_center),
          EditorSegment(value: TextAlign.right, icon: Icons.format_align_right),
        ],
      ),
    );
  }
}

class _ValignPicker extends StatelessWidget {
  const _ValignPicker({required this.value, required this.onChanged});

  final TextVerticalAlign value;
  final ValueChanged<TextVerticalAlign> onChanged;

  @override
  Widget build(BuildContext context) {
    return EditorField(
      label: L10n.of(context).designPosition,
      child: EditorSegmented<TextVerticalAlign>(
        selected: value,
        onChanged: onChanged,
        segments: const [
          EditorSegment(value: TextVerticalAlign.top, icon: Icons.vertical_align_top),
          EditorSegment(value: TextVerticalAlign.center, icon: Icons.vertical_align_center),
          EditorSegment(value: TextVerticalAlign.bottom, icon: Icons.vertical_align_bottom),
        ],
      ),
    );
  }
}

class _RefPositionPicker extends StatelessWidget {
  const _RefPositionPicker({required this.value, required this.onChanged});

  final ReferencePosition value;
  final ValueChanged<ReferencePosition> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return EditorField(
      label: l.designRefPosition,
      // Icons with the words as tooltips: "Inf. izq." was the dropdown's way
      // of fitting three places into a narrow column.
      child: EditorSegmented<ReferencePosition>(
        selected: value,
        onChanged: onChanged,
        segments: [
          EditorSegment(
            value: ReferencePosition.bottomLeft,
            icon: Icons.align_horizontal_left,
            tooltip: l.designRefBottomLeft,
          ),
          EditorSegment(
            value: ReferencePosition.bottomCenter,
            icon: Icons.align_horizontal_center,
            tooltip: l.designRefBottomCenter,
          ),
          EditorSegment(
            value: ReferencePosition.bottomRight,
            icon: Icons.align_horizontal_right,
            tooltip: l.designRefBottomRight,
          ),
        ],
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
    final l = L10n.of(context);
    final sorted = [...template.layers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return EditorSection(
      title: l.designLayers,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconButton(
            icon: Icons.text_fields,
            tooltip: l.designAddText,
            size: 26,
            iconSize: 15,
            onTap: cubit.addTextLayer,
          ),
          AppIconButton(
            icon: Icons.format_quote,
            tooltip: l.designAddReference,
            size: 26,
            iconSize: 15,
            onTap: cubit.addReferenceLayer,
          ),
        ],
      ),
      children: [
        if (sorted.isEmpty)
          Text(
            l.designNoLayers,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          )
        else
          for (final layer in sorted)
            _LayerListTile(layer: layer, isSelected: layer.id == selectedLayerId, cubit: cubit),
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
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovering) => GestureDetector(
        onTap: () => cubit.selectLayer(layer.id),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: kEditorControlHeight + 4,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentFillSoft
                : (hovering ? AppColors.surfaceRaised : AppColors.surfaceControl),
            borderRadius: AppRadius.all(AppRadius.md),
            border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 14,
                color: isSelected ? AppColors.accentLight : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  layer.labelIn(L10n.of(context)),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              AppIconButton(
                icon: Icons.close,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                size: 22,
                iconSize: 13,
                onTap: () => cubit.removeLayer(layer.id),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final layer = this.layer;
    final colour = ColorField(
      label: l.designColor,
      value: switch (layer) {
        TextSlideLayer text => text.textColor,
        ReferenceSlideLayer ref => ref.textColor,
      },
      saved: cubit.state.palette,
      fromPhoto: cubit.state.photoPalette,
      against: cubit.state.backdrop,
      onSave: cubit.saveColor,
      onForget: cubit.forgetColor,
      onChanged: (v) => cubit.updateLayer(switch (layer) {
        TextSlideLayer text => text.copyWith(textColor: v),
        ReferenceSlideLayer ref => ref.copyWith(textColor: v),
      }),
    );

    return EditorSection(
      title: '${l.designProperties} · ${layer.labelIn(l)}',
      children: switch (layer) {
        TextSlideLayer text => [
          EditorSlider(
            label: l.designSize,
            value: text.fontSize,
            min: 20,
            max: 120,
            onChanged: (v) => cubit.updateLayer(text.copyWith(fontSize: v)),
          ),
          EditorSlider(
            label: l.designLineHeight,
            value: text.lineHeight,
            min: 1.0,
            max: 2.5,
            decimals: 1,
            onChanged: (v) => cubit.updateLayer(text.copyWith(lineHeight: v)),
          ),
          _WeightPicker(
            value: text.fontWeight,
            onChanged: (v) => cubit.updateLayer(text.copyWith(fontWeight: v)),
          ),
          _FontFamilyPicker(
            value: text.fontFamily,
            onChanged: (f) => cubit.updateLayer(text.copyWith(fontFamily: f)),
          ),
          _AlignPicker(
            value: text.textAlign,
            onChanged: (v) => cubit.updateLayer(text.copyWith(textAlign: v)),
          ),
          EditorSwitch(
            label: l.designShadow,
            value: text.textShadow,
            onChanged: (v) => cubit.updateLayer(text.copyWith(textShadow: v)),
          ),
          colour,
        ],
        ReferenceSlideLayer ref => [
          EditorSlider(
            label: l.designSize,
            value: ref.fontSize,
            min: 8,
            max: 48,
            onChanged: (v) => cubit.updateLayer(ref.copyWith(fontSize: v)),
          ),
          _FontFamilyPicker(
            value: ref.fontFamily,
            onChanged: (f) => cubit.updateLayer(ref.copyWith(fontFamily: f)),
          ),
          _AlignPicker(
            value: ref.textAlign,
            onChanged: (v) => cubit.updateLayer(ref.copyWith(textAlign: v)),
          ),
          colour,
        ],
      },
    );
  }
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
    final l = L10n.of(context);
    final current = _fonts.contains(value) ? value : null;
    return EditorField(
      label: l.designFont,
      child: EditorDropdown<String?>(
        value: current,
        // The name was already drawn in its own font, but a family name at
        // twelve points says almost nothing about how a verse will look in
        // it. Each row carries a phrase at a size worth judging.
        items: [
          for (final f in _fonts)
            DropdownMenuItem<String?>(
              value: f,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.designSampleShortText,
                      style: TextStyle(fontFamily: f, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Text(f ?? l.designFontSystem, style: AppText.rowSubtitle),
                ],
              ),
            ),
        ],
        selectedItemBuilder: (_) => [
          for (final f in _fonts)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                f ?? l.designFontSystem,
                style: TextStyle(fontFamily: f, fontSize: 12, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
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
                child: SlideMotion(
                  level: MotionLevel.all,
                  child: SlideView(
                    content: '',
                    reference: '',
                    template: widget.template.copyWith(layers: []),
                  ),
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
                L10n.of(context).designSafeArea,
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
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: _layerContent(context, scale),
            ),
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

  Widget _layerContent(BuildContext context, double scale) => switch (layer) {
    TextSlideLayer l => Container(
      color: const Color(0x12FFFFFF),
      alignment: _alignFor(l.textAlign),
      child: Text(
        sampleContent.isEmpty ? L10n.of(context).designTextPlaceholder : sampleContent,
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
        sampleReference.isEmpty ? L10n.of(context).designReferencePlaceholder : sampleReference,
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

  static String _label(L10n l, SlideTransitionType type) => switch (type) {
    SlideTransitionType.cut => l.designTransitionCut,
    SlideTransitionType.fade => l.designTransitionFade,
    SlideTransitionType.slideLeft => l.designTransitionSlideLeft,
    SlideTransitionType.slideRight => l.designTransitionSlideRight,
    SlideTransitionType.zoomIn => l.designTransitionZoom,
  };

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return EditorField(
      label: l.designTransitionType,
      child: EditorDropdown<SlideTransitionType>(
        value: value,
        items: [
          for (final option in SlideTransitionType.values)
            DropdownMenuItem(value: option, child: Text(_label(l, option))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
