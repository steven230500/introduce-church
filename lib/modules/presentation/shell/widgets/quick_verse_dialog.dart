import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/local_db/bible_reference.dart';
import '../../../../core/local_db/bible_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../children/control/presenter/cubit/cubit.dart';

/// Puts a passage on deck from a line of text.
///
/// The preacher says where to go and the operator has a few seconds. Browsing
/// there is a book list, a chapter grid and a verse list, all while the room
/// waits. This is one line and Enter.
Future<void> showQuickVerseDialog(BuildContext context, {BibleRepository? repository}) {
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ControlCubit>(),
      child: QuickVerseDialog(repository: repository),
    ),
  );
}

@visibleForTesting
class QuickVerseDialog extends StatefulWidget {
  const QuickVerseDialog({super.key, this.repository});

  /// Injected by tests. In the app it comes from the injector.
  final BibleRepository? repository;

  @override
  State<QuickVerseDialog> createState() => _QuickVerseDialogState();
}

class _QuickVerseDialogState extends State<QuickVerseDialog> {
  final _controller = TextEditingController();
  late final _repository = widget.repository ?? Modular.get<BibleRepository>();

  ReferenceResult _parsed = (reference: null, problem: ReferenceProblem.empty, typed: null);
  String? _failure;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reparse);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reparse() {
    setState(() {
      _parsed = parseBibleReference(_controller.text);
      _failure = null;
    });
  }

  Future<void> _submit() async {
    final reference = _parsed.reference;
    if (reference == null || _busy) return;

    final cubit = context.read<ControlCubit>();
    setState(() => _busy = true);

    try {
      final versions = await _repository.getVersions();
      if (versions.isEmpty) {
        setState(() {
          _busy = false;
          _failure = 'No hay ninguna versión de la Biblia instalada.';
        });
        return;
      }
      final version = versions.first;

      // A chapter on its own means all of it, and how long it is depends on
      // the chapter, so it has to be read before the range can be asked for.
      var start = reference.verseStart ?? 1;
      var end = reference.verseEnd ?? reference.verseStart ?? 0;
      if (reference.verseStart == null) {
        final verses = await _repository.getVerses(
          version.code,
          reference.bookIndex,
          reference.chapter,
        );
        if (verses.isEmpty) {
          setState(() {
            _busy = false;
            _failure = '${reference.bookName} no tiene capítulo ${reference.chapter}.';
          });
          return;
        }
        start = 1;
        end = verses.length;
      }

      final verseRef = await _repository.getVerseRange(
        versionCode: version.code,
        bookIndex: reference.bookIndex,
        chapter: reference.chapter,
        verseStart: start,
        verseEnd: end,
      );

      if (verseRef == null) {
        setState(() {
          _busy = false;
          _failure = 'No encontré $reference en ${version.name}.';
        });
        return;
      }

      await cubit.addBibleVerseAfterCurrent(verseRef);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _failure = 'No pude leer el pasaje: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reference = _parsed.reference;

    return AppDialog(
      title: 'Versículo rápido',
      icon: Icons.bolt_rounded,
      width: 420,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          onPressed: reference == null || _busy ? null : _submit,
          child: Text(_busy ? 'Buscando...' : 'Agregar'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enter is the whole point of typing a reference instead of browsing
          // to it, so it is bound here rather than left to the text field: the
          // field's own submit callback does not fire on this platform.
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter): _submit,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
            },
            child: AppTextField(
              controller: _controller,
              hintText: 'jn 3:16',
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _Feedback(result: _parsed, failure: _failure),
          const SizedBox(height: AppSpace.lg),
          const Text(
            'Se agrega justo después de lo que está en pantalla.',
            style: AppText.rowSubtitle,
          ),
          const SizedBox(height: AppSpace.xs),
          const Text(
            'Ejemplos:  jn 3:16   ·   1 co 13:4-7   ·   salmos 23',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Says what the line will turn into, before the operator commits to it.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.result, required this.failure});

  final ReferenceResult result;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final message = failure;
    if (message != null) return _Line(text: message, color: AppColors.danger);

    final reference = result.reference;
    if (reference != null) {
      return _Line(text: reference.toString(), color: AppColors.success, bold: true);
    }

    return switch (result.problem) {
      ReferenceProblem.empty ||
      null => const _Line(text: 'Escribe el libro y el capítulo.', color: AppColors.textMuted),
      ReferenceProblem.noChapter => const _Line(
        text: 'Falta el capítulo.',
        color: AppColors.textMuted,
      ),
      ReferenceProblem.noBook => _Line(
        text: 'No conozco el libro "${result.typed}".',
        color: AppColors.warning,
      ),
      ReferenceProblem.ambiguous => _Line(
        text: '"${result.typed}" puede ser varios libros. Escribe un poco más.',
        color: AppColors.warning,
      ),
    };
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.color, this.bold = false});

  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
