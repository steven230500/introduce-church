part of '../page.dart';

class _VerseEditor extends StatefulWidget {
  const _VerseEditor({super.key, required this.index, required this.verse});

  final int index;
  final SongFormVerse verse;

  @override
  State<_VerseEditor> createState() => _VerseEditorState();
}

class _VerseEditorState extends State<_VerseEditor> {
  late final TextEditingController _ctrl;
  late final TextEditingController _chordsCtrl;
  bool _showChords = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.verse.content);
    _chordsCtrl = TextEditingController(text: widget.verse.chords ?? '');
    _showChords = widget.verse.chords?.isNotEmpty == true;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _chordsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SongFormCubit>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.surfaceControl)),
            ),
            child: Row(
              children: [
                // Verse number badge
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceControl,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Type dropdown
                Theme(
                  data: Theme.of(context).copyWith(canvasColor: AppColors.surfaceControl),
                  child: DropdownButton<VerseType>(
                    value: widget.verse.type,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    dropdownColor: AppColors.surfaceControl,
                    items: VerseType.values
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.labelIn(L10n.of(context)))),
                        )
                        .toList(),
                    onChanged: (t) {
                      if (t != null) cubit.updateVerseType(widget.index, t);
                    },
                  ),
                ),

                const Spacer(),

                IconButton(
                  icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                  tooltip: L10n.of(context).songDeleteVerse,
                  onPressed: () => cubit.removeVerse(widget.index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.drag_handle_rounded, size: 18, color: AppColors.textDisabled),
                const SizedBox(width: 4),
              ],
            ),
          ),

          // ── Lyrics text field ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              minLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
              decoration: InputDecoration(
                hintText: L10n.of(context).songVerseHint,
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (v) => cubit.updateVerseContent(widget.index, v),
            ),
          ),

          // ── Chords toggle + field ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showChords = !_showChords),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showChords ? Icons.music_note : Icons.music_note_outlined,
                        size: 12,
                        color: _showChords ? AppColors.accent : AppColors.textDisabled,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        L10n.of(context).songChords,
                        style: TextStyle(
                          fontSize: 11,
                          color: _showChords ? AppColors.accent : AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showChords) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _chordsCtrl,
                    maxLines: null,
                    minLines: 2,
                    style: const TextStyle(
                      color: Color(0xFF5AC8FA),
                      fontSize: 12,
                      fontFamily: 'Courier',
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Am  F  C  G...',
                      hintStyle: const TextStyle(color: AppColors.border, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.accent.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.accent, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.accent, width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                    onChanged: (v) => cubit.updateVerseChords(widget.index, v),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
