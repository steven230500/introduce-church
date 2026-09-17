import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/collection.dart';

/// What kind of change is waiting to be sent.
///
/// Every one of these can be replayed without asking the server anything
/// first, and doing one twice lands on the same result as doing it once.
///
/// Creating fits because the app names what it creates: a service or an item
/// made offline carries an id chosen here, the server keeps that id, and a
/// repeat of the same creation is skipped. Everything queued after it - the
/// items of a new service, a rename, a new order - points at that id and finds
/// it. Deleting fits because a delete that finds nothing left to delete is the
/// result it wanted.
enum PendingKind {
  collectionCreate,
  collectionDelete,
  collectionDetails,
  collectionBgAudio,
  collectionTemplate,
  itemsAdd,
  itemRemove,
  itemTemplate,
  itemTitle,
  itemContent,
  itemNotes,
  itemAutoAdvance,
  itemOrder,
  itemPlanned,
}

/// One change the operator made that the server has not been told about yet.
class PendingWrite extends Equatable {
  const PendingWrite({required this.kind, required this.target, required this.args, this.org});

  final PendingKind kind;

  /// The church the change was made for.
  ///
  /// A queue outlives a session: someone signs out with changes still
  /// waiting and another church signs in on the same laptop. Replayed under
  /// that second session, a service made offline would be created in the
  /// wrong church's library. Null only in queues written before this existed.
  final String? org;

  PendingWrite forOrg(String? org) =>
      PendingWrite(kind: kind, target: target, args: args, org: org);

  /// The id of the thing being changed: an item for the item kinds, a
  /// collection for the rest - including [PendingKind.itemsAdd], which adds
  /// to a collection.
  final String target;

  /// The new values, shaped for the repository call that will replay it.
  ///
  /// For [PendingKind.itemsAdd], the items as whole rows under `items`, songs
  /// and verses included: until the server has them, this is the only copy
  /// the set list and the projector can draw them from.
  final Map<String, dynamic> args;

  /// Two changes with the same key are the same change made twice. The queue
  /// keeps the last, so renaming an item four times while the router is off
  /// sends one request when it comes back, not four.
  ///
  /// Adds are keyed by what they add, not where: two songs added to the same
  /// service are two changes, and the second must not replace the first.
  String get key => switch (kind) {
    PendingKind.itemsAdd => '${kind.name}:${addedItems.firstOrNull?.id ?? target}',
    _ => '${kind.name}:$target',
  };

  /// The items a [PendingKind.itemsAdd] puts in its collection, in order.
  List<CollectionItem> get addedItems => [
    for (final row in args['items'] as List? ?? const [])
      CollectionItem.fromJson({...Map<String, dynamic>.from(row as Map), 'collection_id': target}),
  ];

  Map<String, dynamic> toJson() => {'kind': kind.name, 'target': target, 'args': args, 'org': ?org};

  static PendingWrite? fromJson(Map<String, dynamic> json) {
    final kind = PendingKind.values.where((k) => k.name == json['kind']).firstOrNull;
    final target = json['target'];
    if (kind == null || target is! String) return null;
    return PendingWrite(
      kind: kind,
      target: target,
      args: Map<String, dynamic>.from(json['args'] as Map? ?? const {}),
      org: json['org'] as String?,
    );
  }

  @override
  List<Object?> get props => [kind, target, args, org];
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

/// Every collection as it will look once [write] reaches the server.
///
/// Applied locally the moment the change is queued, and again over the cached
/// plan when the app is opened with no network. Without this the operator
/// renames an item, nothing on screen changes, and they rename it again -
/// which is exactly the silence this whole queue exists to end.
///
/// Applying the same change twice changes nothing the second time, so it is
/// safe over a cache that may already hold it.
List<Collection> applyPendingWriteToAll(List<Collection> collections, PendingWrite write) {
  switch (write.kind) {
    case PendingKind.collectionCreate:
      if (collections.any((c) => c.id == write.target)) return collections;
      final date = write.args['service_date'] as String?;
      final created = Collection(
        id: write.target,
        name: write.args['name'] as String? ?? '',
        serviceDate: date == null ? null : DateTime.tryParse(date),
      );
      // Where the server will put it: latest date first, undated last, and
      // the newest first among equals.
      final at = collections.indexWhere((c) => _sortsAfter(c, created));
      return [...collections]..insert(at == -1 ? collections.length : at, created);

    case PendingKind.collectionDelete:
      return [
        for (final c in collections)
          if (c.id != write.target) c,
      ];

    default:
      return [for (final c in collections) applyPendingWrite(c, write)];
  }
}

bool _sortsAfter(Collection existing, Collection created) {
  final a = existing.serviceDate, b = created.serviceDate;
  if (b == null) return a == null;
  return a == null || !a.isAfter(b);
}

/// One collection as it will look once [write] reaches the server.
///
/// Creating and deleting whole collections change the list, not a collection
/// in it: those go through [applyPendingWriteToAll].
Collection applyPendingWrite(Collection collection, PendingWrite write) {
  switch (write.kind) {
    case PendingKind.collectionCreate:
    case PendingKind.collectionDelete:
      return collection;

    case PendingKind.itemsAdd:
      if (collection.id != write.target) return collection;
      final known = {for (final item in collection.items) item.id};
      final added = [
        for (final item in write.addedItems)
          if (!known.contains(item.id)) item,
      ];
      if (added.isEmpty) return collection;
      return collection.copyWith(
        items: [
          ...collection.items,
          for (final (offset, item) in added.indexed)
            item.copyWith(order: collection.items.length + offset),
        ],
      );

    case PendingKind.itemRemove:
      if (!collection.items.any((item) => item.id == write.target)) return collection;
      return collection.copyWith(
        items: [
          for (final (position, item)
              in collection.items.where((item) => item.id != write.target).indexed)
            item.copyWith(order: position),
        ],
      );

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

    case PendingKind.itemTemplate:
    case PendingKind.itemTitle:
    case PendingKind.itemContent:
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
  PendingKind.itemTemplate => item.withTemplateId(write.args['template_id'] as String?),
  PendingKind.itemTitle => item.renamed(write.args['title'] as String? ?? ''),
  PendingKind.itemContent => item.copyWith(
    contentJson: {
      ...?item.contentJson,
      ...Map<String, dynamic>.from(write.args['content'] as Map? ?? const {}),
    },
  ),
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
