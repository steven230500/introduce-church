part of '../../page.dart';

/// Adds an element to the set list.
///
/// The old menu was ten flat entries that mixed content types with file
/// formats, so "Canción" and "PPTX como imágenes" sat at the same level. This
/// one is grouped by where the content comes from: the library, a form you
/// fill in, or a file on disk.
class _AddItemMenu extends StatelessWidget {
  const _AddItemMenu({this.expanded = false});

  /// Renders as a full-width labelled button instead of an icon.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Agregar elemento',
      color: AppColors.surfaceControl,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        const _SectionItem('De la biblioteca'),
        const PopupMenuItem(
          value: 'song',
          height: 38,
          child: AppMenuRow(icon: Icons.music_note, label: 'Canción'),
        ),
        const PopupMenuItem(
          value: 'quick_verse',
          height: 38,
          child: AppMenuRow(icon: Icons.bolt_rounded, label: 'Versículo rápido', trailing: 'V'),
        ),
        const PopupMenuItem(
          value: 'bible',
          height: 38,
          child: AppMenuRow(icon: Icons.menu_book, label: 'Buscar en la Biblia'),
        ),
        const PopupMenuItem(
          value: 'media',
          height: 38,
          child: AppMenuRow(icon: Icons.perm_media_outlined, label: 'Imagen o video'),
        ),
        const PopupMenuDivider(),
        const _SectionItem('Crear'),
        const PopupMenuItem(
          value: 'free',
          height: 38,
          child: AppMenuRow(icon: Icons.text_fields, label: 'Slide de texto'),
        ),
        const PopupMenuItem(
          value: 'sermon',
          height: 38,
          child: AppMenuRow(icon: Icons.mic_outlined, label: 'Prédica'),
        ),
        const PopupMenuItem(
          value: 'announcement',
          height: 38,
          child: AppMenuRow(icon: Icons.campaign_outlined, label: 'Anuncio'),
        ),
        const PopupMenuDivider(),
        const _SectionItem('Importar archivo'),
        const PopupMenuItem(
          value: 'pptx',
          height: 38,
          child: AppMenuRow(
            icon: Icons.upload_file_outlined,
            label: 'PowerPoint',
            trailing: 'texto',
          ),
        ),
        const PopupMenuItem(
          value: 'pptx_images',
          height: 38,
          child: AppMenuRow(
            icon: Icons.slideshow_outlined,
            label: 'PowerPoint',
            trailing: 'imágenes',
          ),
        ),
        const PopupMenuItem(
          value: 'video',
          height: 38,
          child: AppMenuRow(icon: Icons.video_file_outlined, label: 'Video'),
        ),
        const PopupMenuItem(
          value: 'folder',
          height: 38,
          child: AppMenuRow(icon: Icons.folder_open_outlined, label: 'Carpeta completa'),
        ),
      ],
      onSelected: (value) => _handle(context, value),
      child: expanded
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm + 1,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentFillSoft,
                borderRadius: AppRadius.all(AppRadius.md),
                border: Border.all(color: AppColors.accentOutline),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: AppColors.accent),
                  SizedBox(width: AppSpace.sm - 2),
                  // Flexible so the label shortens in a narrow panel instead of
                  // running past the edge of the button.
                  Flexible(
                    child: Text(
                      'Agregar elemento',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const Padding(
              padding: EdgeInsets.all(AppSpace.xs + 2),
              child: Icon(Icons.add_circle_outline, color: AppColors.accent, size: 19),
            ),
    );
  }

  Future<void> _handle(BuildContext context, String value) async {
    final cubit = context.read<ControlCubit>();
    final shell = context.read<ShellCubit>();

    switch (value) {
      // Library types open the dock rather than a modal. The dock shows the
      // whole library, keeps the set list visible, and lets you add several
      // items in a row without reopening anything.
      case 'song':
        shell.openLibrary(LibraryTab.songs);
      case 'quick_verse':
        await showQuickVerseDialog(context);
      case 'bible':
        shell.openLibrary(LibraryTab.bible);
      case 'media':
        shell.openLibrary(LibraryTab.media);

      case 'free':
        final result = await showFreeSlideDialog(context);
        if (result != null) await cubit.addFreeSlide(result.text, title: result.title);
      case 'sermon':
        await _showSermonDialog(context, cubit);
      case 'announcement':
        await _showAnnouncementDialog(context, cubit);

      case 'pptx':
        await _importPptx(context, cubit);
      case 'pptx_images':
        await _importPptxAsImages(context, cubit);
      case 'video':
        await _importVideo(context, cubit);
      case 'folder':
        await _importFolder(context, cubit);
    }
  }
}

/// Non-selectable group label inside the add menu.
class _SectionItem extends PopupMenuEntry<String> {
  const _SectionItem(this.label);

  final String label;

  @override
  double get height => 26;

  @override
  bool represents(String? value) => false;

  @override
  State<_SectionItem> createState() => _SectionItemState();
}

class _SectionItemState extends State<_SectionItem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xs),
      child: Text(widget.label.toUpperCase(), style: AppText.sectionLabel),
    );
  }
}

// ── Sermon ────────────────────────────────────────────────────────────────────

Future<void> _showSermonDialog(BuildContext context, ControlCubit cubit) async {
  final result = await showDialog<({String title, List<String> points})>(
    context: context,
    builder: (_) => const _SermonDialog(),
  );
  if (result != null && context.mounted) {
    await cubit.addSermon(result.title, result.points);
  }
}

class _SermonDialog extends StatefulWidget {
  const _SermonDialog();

  @override
  State<_SermonDialog> createState() => _SermonDialogState();
}

class _SermonDialogState extends State<_SermonDialog> {
  final _titleCtrl = TextEditingController();
  final List<TextEditingController> _pointCtrls = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _pointCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPoint() => setState(() => _pointCtrls.add(TextEditingController()));

  void _removePoint(int index) {
    setState(() {
      _pointCtrls[index].dispose();
      _pointCtrls.removeAt(index);
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final points = _pointCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    Navigator.pop(context, (title: title, points: points));
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Nueva prédica',
      icon: Icons.mic_outlined,
      width: 480,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: _titleCtrl.text.trim().isEmpty ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _titleCtrl,
              hintText: 'Título de la prédica',
              label: 'Título',
              autofocus: true,
              onSubmitted: (_) => _addPoint(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                const Text('PUNTOS', style: AppText.sectionLabel),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                ),
              ],
            ),
            ..._pointCtrls.asMap().entries.map((entry) {
              final i = entry.key;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceControl,
                        borderRadius: AppRadius.all(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: AppTextField(
                        controller: entry.value,
                        hintText: 'Punto ${i + 1}',
                        onSubmitted: (_) => _addPoint(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      tooltip: 'Quitar punto',
                      onPressed: () => _removePoint(i),
                    ),
                  ],
                ),
              );
            }),
            if (_pointCtrls.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: TextButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Agregar primer punto'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Announcement ──────────────────────────────────────────────────────────────

Future<void> _showAnnouncementDialog(BuildContext context, ControlCubit cubit) async {
  DateTime? timerTarget;
  var useTimer = false;

  await showDialog<void>(
    context: context,
    builder: (_) => TextControllerScope(
      builder: (_, msgCtrl) => StatefulBuilder(
        builder: (ctx, setState) => AppDialog(
          title: 'Slide de anuncio',
          icon: Icons.campaign_outlined,
          width: 440,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            const SizedBox(width: AppSpace.sm),
            ValueListenableBuilder(
              valueListenable: msgCtrl,
              builder: (context, value, child) => FilledButton(
                onPressed: value.text.trim().isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        cubit.addAnnouncement(
                          msgCtrl.text.trim(),
                          timerTarget: useTimer ? timerTarget : null,
                        );
                      },
                child: const Text('Agregar'),
              ),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: msgCtrl,
                hintText: 'Bienvenidos a la iglesia...',
                label: 'Mensaje',
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Switch(value: useTimer, onChanged: (v) => setState(() => useTimer = v)),
                  const SizedBox(width: AppSpace.sm),
                  const Text(
                    'Mostrar cuenta regresiva',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
              if (useTimer) ...[
                const SizedBox(height: AppSpace.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(
                    timerTarget == null
                        ? 'Seleccionar hora de inicio'
                        : '${timerTarget!.hour.toString().padLeft(2, '0')}:'
                              '${timerTarget!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                    if (picked == null) return;
                    final now = DateTime.now();
                    var target = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
                    // A time already past today means the operator meant tomorrow.
                    if (target.isBefore(now)) {
                      target = target.add(const Duration(days: 1));
                    }
                    setState(() => timerTarget = target);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
