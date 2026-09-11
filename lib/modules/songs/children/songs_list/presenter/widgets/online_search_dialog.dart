import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../../../../core/services/lyric_import_service.dart';
import '../../../../../../core/services/lyric_search_service.dart';
import '../../../../../../core/widgets/app_dialog.dart';
import '../../../../children/song_form/presenter/cubit/cubit.dart';

class OnlineSongSearchDialog extends StatefulWidget {
  const OnlineSongSearchDialog({super.key});

  @override
  State<OnlineSongSearchDialog> createState() => _OnlineSongSearchDialogState();
}

class _OnlineSongSearchDialogState extends State<OnlineSongSearchDialog> {
  final _controller = TextEditingController();
  final _service = LyricSearchService();

  bool _searching = false;
  List<LyricSearchResult> _results = [];
  bool _fetchingLyrics = false;
  LyricSearchResult? _selected;
  String? _lyrics;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _results = [];
      _selected = null;
      _lyrics = null;
      _error = null;
    });
    try {
      final results = await _service.search(query);
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) _error = 'Sin resultados para "$query"';
      });
    } catch (e) {
      setState(() {
        _searching = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _selectResult(LyricSearchResult result) async {
    setState(() {
      _fetchingLyrics = true;
      _selected = result;
      _lyrics = null;
      _error = null;
    });
    try {
      final lyrics = await _service.fetchLyrics(result.artist, result.title);
      setState(() {
        _fetchingLyrics = false;
        if (lyrics == null || lyrics.trim().isEmpty) {
          _error = 'No se encontró letra para "${result.title}"';
          _selected = null;
        } else {
          _lyrics = lyrics;
        }
      });
    } catch (e) {
      setState(() {
        _fetchingLyrics = false;
        _error = _friendlyError(e);
        _selected = null;
      });
    }
  }

  void _import() {
    if (_lyrics == null || _selected == null) return;
    final verses = LyricImportService.segmentLines(
      _lyrics!.split('\n'),
    ).map((v) => SongFormVerse(type: v.type, content: v.content)).toList();
    final model = SongFormModel(title: _selected!.title, author: _selected!.artist, verses: verses);
    Navigator.of(context).pop();
    Modular.to.pushNamed('/songs/import', arguments: model);
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Tiempo de espera agotado. Verifica tu conexión.';
      }
      final status = e.response?.statusCode;
      if (status == 404) return 'No encontrado.';
      if (status != null) return 'Error del servidor ($status).';
    }
    return 'Error de conexión. Verifica tu internet.';
  }

  void _back() => setState(() {
    _selected = null;
    _lyrics = null;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: _lyrics != null
          ? '${_selected!.title} — ${_selected!.artist}'
          : 'Buscar letra en línea',
      icon: Icons.travel_explore,
      width: 560,
      height: 540,
      contentPadding: EdgeInsets.zero,
      showClose: _lyrics == null,
      actions: _lyrics != null
          ? [
              TextButton(onPressed: _back, child: const Text('Volver')),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Importar canción'),
                onPressed: _import,
              ),
            ]
          : null,
      child: _lyrics != null
          ? _LyricsPreview(lyrics: _lyrics!)
          : _SearchPanel(
              controller: _controller,
              searching: _searching,
              fetchingLyrics: _fetchingLyrics,
              results: _results,
              error: _error,
              onSearch: _search,
              onSelect: _selectResult,
            ),
    );
  }
}

// ── Search panel ──────────────────────────────────────────────────────────────

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.searching,
    required this.fetchingLyrics,
    required this.results,
    required this.error,
    required this.onSearch,
    required this.onSelect,
  });

  final TextEditingController controller;
  final bool searching;
  final bool fetchingLyrics;
  final List<LyricSearchResult> results;
  final String? error;
  final VoidCallback onSearch;
  final void Function(LyricSearchResult) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller,
                  hintText: 'Título o artista...',
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (!searching && !fetchingLyrics) ? onSearch : null,
                child: const Text('Buscar'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _ResultsArea(
            searching: searching,
            fetchingLyrics: fetchingLyrics,
            results: results,
            error: error,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

class _ResultsArea extends StatelessWidget {
  const _ResultsArea({
    required this.searching,
    required this.fetchingLyrics,
    required this.results,
    required this.error,
    required this.onSelect,
  });

  final bool searching;
  final bool fetchingLyrics;
  final List<LyricSearchResult> results;
  final String? error;
  final void Function(LyricSearchResult) onSelect;

  @override
  Widget build(BuildContext context) {
    if (searching || fetchingLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2, color: kAccent),
            const SizedBox(height: 12),
            Text(
              fetchingLyrics ? 'Cargando letra...' : 'Buscando...',
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error!,
            style: const TextStyle(color: kTextSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Escribe un título o artista y presiona Buscar.',
          style: TextStyle(color: kTextMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = results[i];
        return ListTile(
          dense: true,
          title: Text(r.title, style: const TextStyle(color: kTextPrimary, fontSize: 13)),
          subtitle: Text(r.artist, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, size: 18, color: kTextMuted),
          onTap: () => onSelect(r),
        );
      },
    );
  }
}

// ── Lyrics preview ────────────────────────────────────────────────────────────

class _LyricsPreview extends StatelessWidget {
  const _LyricsPreview({required this.lyrics});
  final String lyrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Text(lyrics, style: const TextStyle(color: kTextPrimary, fontSize: 13, height: 1.6)),
    );
  }
}
