part of '../page.dart';

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SongFormCubit, SongFormState>(
      builder: (context, state) => switch (state) {
        SongFormLoadingState() => const Center(child: CircularProgressIndicator()),
        SongFormErrorState(:final message) => Center(
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
        SongFormSavedState() => const SizedBox.shrink(),
        SongFormReadyState(:final model) => _Form(model: model),
      },
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.model});
  final SongFormModel model;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.model.title);
    _authorCtrl = TextEditingController(text: widget.model.author);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _paste(BuildContext context) async {
    final segments = await showPasteLyricsDialog(context);
    if (segments == null || segments.isEmpty) return;
    if (!context.mounted) return;
    final cubit = context.read<SongFormCubit>();
    for (int i = 0; i < segments.length; i++) {
      cubit.addVerse();
    }
    final state = cubit.state;
    if (state is! SongFormReadyState) return;
    final baseIndex = state.model.verses.length - segments.length;
    for (int i = 0; i < segments.length; i++) {
      cubit.updateVerseContent(baseIndex + i, segments[i]);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${segments.length} versos cargados'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf', 'xml', 'cho', 'chordpro', 'chopro'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    if (!context.mounted) return;
    final cubit = context.read<SongFormCubit>();
    final count = await cubit.importLyrics(path);
    if (!context.mounted) return;
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count versos importados'), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SongFormCubit>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        // ── Metadata fields ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _DarkField(
                controller: _titleCtrl,
                label: 'Título',
                required: true,
                onChanged: cubit.updateTitle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DarkField(
                controller: _authorCtrl,
                label: 'Autor',
                onChanged: cubit.updateAuthor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),
        const Divider(color: AppColors.surfaceControl, height: 1),
        const SizedBox(height: 20),

        // ── Verses header ─────────────────────────────────────────────────
        Row(
          children: [
            const Text(
              'Versos',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            // Paste lyrics
            OutlinedButton.icon(
              onPressed: () => _paste(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textTertiary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.content_paste_rounded, size: 16),
              label: const Text('Pegar letra', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            // Import from file
            BlocBuilder<SongFormCubit, SongFormState>(
              buildWhen: (a, b) =>
                  a is SongFormReadyState &&
                  b is SongFormReadyState &&
                  a.model.isImporting != b.model.isImporting,
              builder: (context, state) {
                final importing = state is SongFormReadyState && state.model.isImporting;
                return OutlinedButton.icon(
                  onPressed: importing ? null : () => _import(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textTertiary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: importing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textTertiary,
                          ),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(
                    importing ? 'Importando...' : 'Importar archivo',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: cubit.addVerse,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.surfaceControl),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar verso', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Verses list ───────────────────────────────────────────────────
        BlocBuilder<SongFormCubit, SongFormState>(
          buildWhen: (a, b) =>
              a is SongFormReadyState &&
              b is SongFormReadyState &&
              a.model.verses != b.model.verses,
          builder: (context, state) {
            if (state is! SongFormReadyState) return const SizedBox.shrink();
            final verses = state.model.verses;
            if (verses.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceControl),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.queue_music_rounded, size: 36, color: AppColors.textDisabled),
                      SizedBox(height: 10),
                      Text(
                        'Sin versos. Agrega manualmente o importa un archivo.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              proxyDecorator: (child, i, a) => Material(color: Colors.transparent, child: child),
              itemCount: verses.length,
              onReorder: cubit.moveVerse,
              itemBuilder: (_, i) => _VerseEditor(key: ValueKey(i), index: i, verse: verses[i]),
            );
          },
        ),
      ],
    );
  }
}

// ── Dark text field ────────────────────────────────────────────────────────────

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.label,
    this.required = false,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceControl),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceControl),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }
}
