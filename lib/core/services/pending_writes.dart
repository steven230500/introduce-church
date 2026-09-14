import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/collection.dart';

/// What kind of change is waiting to be sent.
///
/// Every one of these sets a field on something the server already knows
/// about. That is the whole reason they can wait: replaying them needs no id
/// the server has not handed out yet, and doing one twice lands on the same
/// result as doing it once. Adding and deleting are deliberately absent - a
/// second change that refers to a row created offline would have nothing to
/// point at, and guessing at that is how a church loses a service.
enum PendingKind {
  collectionDetails,
  collectionBgAudio,
  collectionTemplate,
  itemTitle,
  itemNotes,
  itemAutoAdvance,
  itemOrder,
  itemPlanned,
}

/// One change the operator made that the server has not been told about yet.
class PendingWrite extends Equatable {
  const PendingWrite({required this.kind, required this.target, required this.args});

  final PendingKind kind;

  /// The id of the thing being changed: an item for the item kinds, a
  /// collection for the rest.
  final String target;

  /// The new values, shaped for the repository call that will replay it.
  final Map<String, dynamic> args;

  /// Two changes with the same key are the same change made twice. The queue
  /// keeps the last, so renaming an item four times while the router is off
  /// sends one request when it comes back, not four.
  String get key => '${kind.name}:$target';

  Map<String, dynamic> toJson() => {'kind': kind.name, 'target': target, 'args': args};

  static PendingWrite? fromJson(Map<String, dynamic> json) {
    final kind = PendingKind.values.where((k) => k.name == json['kind']).firstOrNull;
    final target = json['target'];
    if (kind == null || target is! String) return null;
    return PendingWrite(
      kind: kind,
      target: target,
      args: Map<String, dynamic>.from(json['args'] as Map? ?? const {}),
    );
  }

  @override
  List<Object?> get props => [kind, target, args];
}

/// The changes made while the server could not be reached.
///
/// On disk, in a file of its own, because the network usually comes back after
/// the app has been closed and reopened - and because the preferences file
/// caches the whole document, so a second writer would clobber it.
class PendingWrites {
  PendingWrites({File? file}) : _override = file, _onDisk = true;

  /// A queue that forgets when the process does.
  ///
  /// For tests, which have no application support directory: asking for one
  /// inside a widget test waits on a platform channel that never answers.
  PendingWrites.inMemory() : _override = null, _onDisk = false;

  final File? _override;
  final bool _onDisk;
  List<PendingWrite>? _cache;

  Future<File> get _file async {
    if (_override != null) return _override;
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'pending_writes.json'));
  }

  Future<List<PendingWrite>> load() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    if (!_onDisk) return List.unmodifiable(_cache = []);
    try {
      final file = await _file;
      if (!await file.exists()) return List.unmodifiable(_cache = []);
      final rows = jsonDecode(await file.readAsString()) as List<dynamic>;
      _cache = [for (final row in rows) ?PendingWrite.fromJson(row as Map<String, dynamic>)];
    } catch (_) {
      // A file written by an older version, or half-written by a crash. Losing
      // the queue is bad; refusing to start because of it is worse.
      _cache = [];
    }
    return List.unmodifiable(_cache!);
  }

  /// Remembers one change, replacing any earlier one that sets the same field
  /// on the same thing.
  Future<void> add(PendingWrite write) async {
    final queue = [...await load()]
      ..removeWhere((existing) => existing.key == write.key)
      ..add(write);
    await save(queue);
  }

  Future<void> save(List<PendingWrite> queue) async {
    _cache = [...queue];
    if (!_onDisk) return;
    final file = await _file;
    if (queue.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([for (final w in queue) w.toJson()]));
  }

  Future<void> clear() => save(const []);
}

/// The collection as it will look once [write] reaches the server.
///
/// Applied locally the moment the change is queued. Without this the operator
/// renames an item, nothing on screen changes, and they rename it again -
/// which is exactly the silence this whole queue exists to end.
Collection applyPendingWrite(Collection collection, PendingWrite write) {
  switch (write.kind) {
    case PendingKind.collectionDetails:
      if (collection.id != write.target) return collection;
      final date = write.args['service_date'] as String?;
      return collection.copyWith(
        name: write.args['name'] as String?,
        serviceDate: date == null ? null : DateTime.tryParse(date),
      );

    case PendingKind.collectionBgAudio:
      if (collection.id != write.target) return collection;
      final path = write.args['path'] as String?;
      return collection.copyWith(bgAudioPath: path, clearBgAudio: path == null);

    case PendingKind.collectionTemplate:
      if (collection.id != write.target) return collection;
      final templateId = write.args['template_id'] as String?;
      return collection.copyWith(templateId: templateId, clearTemplateId: templateId == null);

    case PendingKind.itemOrder:
      if (collection.id != write.target) return collection;
      final order = List<String>.from(write.args['item_ids'] as List? ?? const []);
      final byId = {for (final item in collection.items) item.id: item};
      final moved = <CollectionItem>[
        for (final (position, id) in order.indexed)
          if (byId.remove(id) case final item?) item.copyWith(order: position),
      ];
      // Anything the caller did not name keeps its relative place at the end,
      // so a stale order list cannot make items disappear from the service.
      final leftovers = byId.values.toList()..sort((a, b) => a.order.compareTo(b.order));
      return collection.copyWith(
        items: [
          ...moved,
          for (final (offset, item) in leftovers.indexed)
            item.copyWith(order: moved.length + offset),
        ],
      );

    case PendingKind.itemTitle:
    case PendingKind.itemNotes:
    case PendingKind.itemAutoAdvance:
    case PendingKind.itemPlanned:
      return collection.copyWith(
        items: [
          for (final item in collection.items)
            if (item.id != write.target) item else _applyToItem(item, write),
        ],
      );
  }
}

CollectionItem _applyToItem(CollectionItem item, PendingWrite write) => switch (write.kind) {
  PendingKind.itemTitle => item.renamed(write.args['title'] as String? ?? ''),
  PendingKind.itemNotes => item.copyWith(
    notes: write.args['notes'] as String?,
    clearNotes: write.args['notes'] == null,
  ),
  PendingKind.itemAutoAdvance => item.copyWith(
    autoAdvanceSecs: write.args['auto_advance_secs'] as int?,
    clearAutoAdvance: write.args['auto_advance_secs'] == null,
  ),
  PendingKind.itemPlanned => item.copyWith(
    plannedSecs: write.args['planned_secs'] as int?,
    clearPlanned: write.args['planned_secs'] == null,
  ),
  _ => item,
};
