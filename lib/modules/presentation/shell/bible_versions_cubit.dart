import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/bible_download_service.dart';

// ── Available versions registry ───────────────────────────────────────────────

class BibleVersionMeta {
  const BibleVersionMeta({
    required this.code,
    required this.name,
    required this.bundled,
    this.url,
    this.apiCode,
    this.localImport = false,
  });
  final String code;
  final String name;
  final bool bundled;
  final String? url;
  // apiCode: código en bolls.life — descarga automática capítulo a capítulo
  final String? apiCode;
  // localImport: usuario provee su propio JSON (versiones no disponibles en bolls.life)
  final bool localImport;

  bool get canDownload => apiCode != null || url != null;
}

const kAvailableVersions = [
  BibleVersionMeta(code: 'RVR1960', name: 'Reina-Valera 1960', bundled: true),
  BibleVersionMeta(
    code: 'NVI',
    name: 'Nueva Versión Internacional',
    bundled: false,
    apiCode: 'NVI',
  ),
  BibleVersionMeta(
    code: 'LBLA',
    name: 'La Biblia de las Américas',
    bundled: false,
    apiCode: 'LBLA',
  ),
  BibleVersionMeta(code: 'PDT', name: 'Palabra de Dios para Todos', bundled: false, apiCode: 'PDT'),
  BibleVersionMeta(code: 'DHH', name: 'Dios Habla Hoy', bundled: false, localImport: true),
  BibleVersionMeta(code: 'RVR2015', name: 'Reina-Valera 2015', bundled: false, localImport: true),
];

// ── States ────────────────────────────────────────────────────────────────────

enum VersionStatus {
  checking,
  installed,
  notInstalled,
  downloading,
  importing,
  error,

  /// Installed, but missing books: a download that was cut off.
  incomplete,
}

class VersionState extends Equatable {
  const VersionState({
    required this.meta,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
  });

  final BibleVersionMeta meta;
  final VersionStatus status;
  final double progress;
  final String? errorMessage;

  VersionState copyWith({VersionStatus? status, double? progress, String? errorMessage}) =>
      VersionState(
        meta: meta,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [meta.code, status, progress, errorMessage];
}

class BibleVersionsState extends Equatable {
  const BibleVersionsState(this.versions);
  final List<VersionState> versions;

  BibleVersionsState copyWithVersion(VersionState updated) => BibleVersionsState([
    for (final v in versions) v.meta.code == updated.meta.code ? updated : v,
  ]);

  @override
  List<Object?> get props => [versions];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class BibleVersionsCubit extends Cubit<BibleVersionsState> {
  BibleVersionsCubit(this._service)
    : super(
        BibleVersionsState(
          kAvailableVersions
              .map((m) => VersionState(meta: m, status: VersionStatus.checking))
              .toList(),
        ),
      );

  final BibleDownloadService _service;

  Future<void> load() async {
    for (final meta in kAvailableVersions) {
      final installed = await _service.isDownloaded(meta.code);
      if (!installed) {
        _emit(meta.code, VersionStatus.notInstalled);
        continue;
      }
      // A Bible with holes in it is worse than one that is not there: the
      // operator only finds out when the passage does not come up.
      final complete = meta.bundled || await _service.isComplete(meta.code);
      _emit(meta.code, complete ? VersionStatus.installed : VersionStatus.incomplete);
    }
  }

  Future<void> download(String code) async {
    final meta = kAvailableVersions.firstWhere((m) => m.code == code);
    if (!meta.canDownload) return;

    _emit(code, VersionStatus.downloading, progress: 0);
    try {
      if (meta.apiCode != null) {
        await _service.downloadFromApi(
          apiCode: meta.apiCode!,
          code: meta.code,
          name: meta.name,
          onProgress: (p) => _emit(code, VersionStatus.downloading, progress: p),
        );
      } else {
        await _service.downloadAndImport(
          url: meta.url!,
          code: meta.code,
          name: meta.name,
          onProgress: (p) => _emit(code, VersionStatus.downloading, progress: p),
        );
      }
      _emit(code, VersionStatus.installed);
    } catch (e) {
      _emit(code, VersionStatus.error, error: e.toString().split('\n').first);
    }
  }

  Future<void> importFromFile(String code) async {
    final meta = kAvailableVersions.firstWhere((m) => m.code == code);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null) return;

    _emit(code, VersionStatus.importing);
    try {
      await _service.importFromFile(filePath: path, code: meta.code, name: meta.name);
      _emit(code, VersionStatus.installed);
    } catch (e) {
      _emit(
        code,
        VersionStatus.error,
        error: 'Archivo inválido: ${e.toString().split('\n').first}',
      );
    }
  }

  Future<void> delete(String code) async {
    await _service.deleteVersion(code);
    _emit(code, VersionStatus.notInstalled);
  }

  void _emit(String code, VersionStatus status, {double progress = 0.0, String? error}) {
    final current = state.versions.firstWhere((v) => v.meta.code == code);
    emit(
      state.copyWithVersion(
        current.copyWith(status: status, progress: progress, errorMessage: error),
      ),
    );
  }
}
