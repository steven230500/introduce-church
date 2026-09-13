import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../modules/presentation/children/control/presenter/cubit/cubit.dart';
import '../api/api_client.dart';
import 'projection_event.dart';

/// The church's record of what it projected, on the server.
class HistoryRepository {
  const HistoryRepository(this._api);
  final ApiClient _api;

  /// The server stores a batch or refuses all of it, and ignores events it
  /// already has, so sending the same batch twice is harmless.
  Future<void> send(List<ProjectionEvent> events) async {
    if (events.isEmpty) return;
    await _api.post<Map<String, dynamic>>(
      '/history',
      data: {
        'events': [for (final event in events) event.toJson()],
      },
    );
  }

  Future<List<ProjectionEvent>> between(DateTime from, DateTime to) async {
    final rows = await _api.get<List<dynamic>>(
      '/history',
      query: {'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String()},
    );
    return [
      for (final row in rows ?? const []) ProjectionEvent.fromJson(row as Map<String, dynamic>),
    ];
  }
}

/// Events recorded but not yet delivered.
///
/// On disk, because the network is usually down in exactly the room where the
/// service is happening, and the laptop is shut before it comes back.
class ProjectionOutbox {
  ProjectionOutbox({File? file}) : _override = file, _onDisk = true;

  /// Forgets on exit. For tests, where there is no application directory.
  ProjectionOutbox.inMemory() : _override = null, _onDisk = false;

  final File? _override;
  final bool _onDisk;
  List<ProjectionEvent>? _cache;

  Future<File> get _file async {
    if (_override != null) return _override;
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'projection_outbox.json'));
  }

  Future<List<ProjectionEvent>> load() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    if (!_onDisk) return List.unmodifiable(_cache = []);
    try {
      final file = await _file;
      if (!await file.exists()) return List.unmodifiable(_cache = []);
      final rows = jsonDecode(await file.readAsString()) as List<dynamic>;
      _cache = [for (final row in rows) ProjectionEvent.fromJson(row as Map<String, dynamic>)];
    } catch (_) {
      // A half-written file costs what was in it, not the ability to record.
      _cache = [];
    }
    return List.unmodifiable(_cache!);
  }

  Future<void> add(ProjectionEvent event) async => _save([...await load(), event]);

  /// Drops events that have been delivered.
  Future<void> remove(Iterable<String> ids) async {
    final gone = ids.toSet();
    await _save([
      for (final event in await load())
        if (!gone.contains(event.id)) event,
    ]);
  }

  Future<void> _save(List<ProjectionEvent> events) async {
    _cache = events;
    if (!_onDisk) return;
    final file = await _file;
    if (events.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([for (final e in events) e.toJson()]));
  }
}

/// Watches the presenter and writes down what goes on the screen.
///
/// Nothing in the presenter knows this exists. It listens to the state the
/// presenter already publishes, which keeps the recording out of the code
/// that runs a service - a bug here must not be able to stop a slide.
class ProjectionRecorder {
  ProjectionRecorder(
    this._control,
    this._history,
    this._outbox, {
    SegmentTracker? tracker,
    DateTime Function()? clock,
  }) : _tracker = tracker ?? SegmentTracker(),
       _clock = clock ?? DateTime.now;

  final ControlCubit _control;
  final HistoryRepository _history;
  final ProjectionOutbox _outbox;
  final SegmentTracker _tracker;
  final DateTime Function() _clock;

  StreamSubscription<ControlState>? _subscription;
  bool _flushing = false;

  /// The server accepts up to this many at once.
  static const _batch = 500;

  void start() {
    _observe(_control.state);
    _subscription = _control.stream.listen(_observe);
    // Whatever the last session could not deliver.
    unawaited(flush());
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    final closed = _tracker.finish(_clock());
    if (closed != null) await _outbox.add(closed);
    await flush();
  }

  void _observe(ControlState state) {
    final closed = _tracker.observe(onAirIn(state), _clock());
    if (closed == null) return;
    unawaited(_outbox.add(closed).then((_) => flush()));
  }

  /// Sends what is waiting, oldest first, in batches.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (true) {
        final waiting = await _outbox.load();
        if (waiting.isEmpty) return;
        final batch = waiting.take(_batch).toList();
        try {
          await _history.send(batch);
        } on ApiException catch (error) {
          // Only a refusal of the content itself drops the batch: keeping one
          // the server will never accept would block every event behind it.
          // An expired session, a server having a bad minute or no network at
          // all are temporary, and the record is worth waiting for.
          if (!_rejectsContent(error.statusCode)) return;
        } catch (_) {
          return; // Transport failure of some other shape: try next time.
        }
        await _outbox.remove(batch.map((e) => e.id));
      }
    } finally {
      _flushing = false;
    }
  }
}

bool _rejectsContent(int? status) => status == 400 || status == 413 || status == 422;

/// What the congregation is looking at, according to the presenter's state.
///
/// Only when the output is live and not blacked out: an operator browsing with
/// the projector off, or with the screen black during a prayer, is not showing
/// anything to anyone.
OnAir? onAirIn(ControlState state) {
  if (state is! ControlLoadedState) return null;
  final model = state.model;
  if (!model.isLive || model.blankScreen) return null;
  // A waiting scene is not an item of the service, and a loop left up for
  // twenty minutes before the service is not twenty minutes of a song.
  if (model.waiting.active) return null;
  final collection = model.activeCollection;
  if (collection == null) return null;
  final index = model.liveItemIndex;
  if (index < 0 || index >= collection.items.length) return null;
  return (collection: collection, item: collection.items[index]);
}
