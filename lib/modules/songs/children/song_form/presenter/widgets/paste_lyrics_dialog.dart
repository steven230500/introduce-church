import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/services/lyric_import_service.dart';
import '../../../../../../core/widgets/app_dialog.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../../core/theme/app_colors.dart';

// ── Cubit ─────────────────────────────────────────────────────────────────────

class PasteLyricsState extends Equatable {
  const PasteLyricsState({this.segments = const [], this.hasText = false});
  final List<String> segments;
  final bool hasText;
  @override
  List<Object?> get props => [segments, hasText];
}

class PasteLyricsCubit extends Cubit<PasteLyricsState> {
  PasteLyricsCubit() : super(const PasteLyricsState());

  void textChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    if (!hasText) {
      emit(const PasteLyricsState());
      return;
    }
    if (state.segments.isNotEmpty) {
      analyze(text);
    } else {
      emit(PasteLyricsState(hasText: true, segments: state.segments));
    }
  }

  void analyze(String text) {
    final segs = LyricImportService.segmentLines(text.split('\n')).map((v) => v.content).toList();
    emit(PasteLyricsState(hasText: text.trim().isNotEmpty, segments: segs));
  }

  void splitEveryNLines(String text, int n) {
    if (n < 1) return;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final segs = <String>[];
    for (var i = 0; i < lines.length; i += n) {
      final chunk = lines.sublist(i, (i + n).clamp(0, lines.length));
      segs.add(chunk.join('\n'));
    }
    emit(PasteLyricsState(hasText: text.trim().isNotEmpty, segments: segs));
  }
}

// ── Dialog entry point ────────────────────────────────────────────────────────

Future<List<String>?> showPasteLyricsDialog(BuildContext context) {
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        BlocProvider(create: (_) => PasteLyricsCubit(), child: const _PasteLyricsDialog()),
  );
}

// ── Dialog (StatelessWidget) ──────────────────────────────────────────────────

class _PasteLyricsDialog extends StatelessWidget {
  const _PasteLyricsDialog();

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: L10n.of(context).songPasteLyrics,
      icon: Icons.lyrics_outlined,
      width: 720,
      height: 580,
      contentPadding: EdgeInsets.zero,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(L10n.of(context).cancel),
        ),
        const SizedBox(width: 8),
        BlocBuilder<PasteLyricsCubit, PasteLyricsState>(
          buildWhen: (a, b) => a.segments.length != b.segments.length,
          builder: (context, state) => FilledButton(
            onPressed: state.segments.isEmpty
                ? null
                : () => Navigator.of(context).pop(state.segments),
            child: Text(L10n.of(context).pasteLoadVerses(state.segments.length)),
          ),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: _PasteInputArea()),
          const VerticalDivider(width: 1),
          const Expanded(child: _SegmentsPreview()),
        ],
      ),
    );
  }
}

// ── Left panel: paste input (StatefulWidget for TextEditingController) ────────

class _PasteInputArea extends StatefulWidget {
  const _PasteInputArea();

  @override
  State<_PasteInputArea> createState() => _PasteInputAreaState();
}

class _PasteInputAreaState extends State<_PasteInputArea> {
  final _ctrl = TextEditingController();
  int _linesPerVerse = 4;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PasteLyricsCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.of(context).pasteHere,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: L10n.of(context).pasteHint,
                hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: cubit.textChanged,
            ),
          ),
          const SizedBox(height: 10),

          // Sugerir divisiones (blank-line detection)
          SizedBox(
            width: double.infinity,
            child: BlocBuilder<PasteLyricsCubit, PasteLyricsState>(
              buildWhen: (a, b) => a.hasText != b.hasText,
              builder: (context, state) => FilledButton.icon(
                onPressed: state.hasText ? () => cubit.analyze(_ctrl.text) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceControl,
                  foregroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.surfaceControl,
                ),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: Text(L10n.of(context).pasteSuggest),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Split every N lines
          BlocBuilder<PasteLyricsCubit, PasteLyricsState>(
            buildWhen: (a, b) => a.hasText != b.hasText,
            builder: (context, state) => Row(
              children: [
                Text(
                  L10n.of(context).pasteOrEvery,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const SizedBox(width: 8),
                _LinesStepper(
                  value: _linesPerVerse,
                  enabled: state.hasText,
                  onChanged: (v) => setState(() => _linesPerVerse = v),
                ),
                const SizedBox(width: 8),
                Text(
                  L10n.of(context).pasteLines,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: state.hasText
                      ? () => cubit.splitEveryNLines(_ctrl.text, _linesPerVerse)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surfaceControl,
                    foregroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.surfaceControl,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(L10n.of(context).pasteSplit),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _LinesStepper extends StatelessWidget {
  const _LinesStepper({required this.value, required this.enabled, required this.onChanged});
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove,
            enabled: enabled && value > 1,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: enabled ? Colors.white : AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            enabled: enabled && value < 16,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 14, color: enabled ? AppColors.accent : AppColors.border),
      ),
    );
  }
}

// ── Right panel: segments preview (StatelessWidget) ───────────────────────────

class _SegmentsPreview extends StatelessWidget {
  const _SegmentsPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<PasteLyricsCubit, PasteLyricsState>(
            buildWhen: (a, b) => a.segments.length != b.segments.length,
            builder: (_, state) {
              final count = state.segments.length;
              final isOnlyOne = count == 1 && state.segments.first.split('\n').length > 6;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count == 0
                        ? L10n.of(context).pastePreview
                        : L10n.of(context).pasteDetected(count),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  if (isOnlyOne) ...[
                    const SizedBox(height: 4),
                    Text(
                      L10n.of(context).pasteNoBlankLines,
                      style: TextStyle(color: AppColors.warning, fontSize: 11),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<PasteLyricsCubit, PasteLyricsState>(
              builder: (_, state) => state.segments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 32,
                            color: AppColors.textDisabled,
                          ),
                          SizedBox(height: 10),
                          Text(
                            L10n.of(context).pasteEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: state.segments.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _SegmentCard(index: i + 1, text: state.segments[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Segment card ──────────────────────────────────────────────────────────────

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceControl,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
