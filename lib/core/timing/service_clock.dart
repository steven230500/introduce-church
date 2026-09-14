import 'package:equatable/equatable.dart';

import '../models/collection.dart';

/// One item's share of a rehearsal.
class RehearsedItem extends Equatable {
  const RehearsedItem({required this.item, required this.spent});

  final CollectionItem item;
  final Duration spent;

  @override
  List<Object?> get props => [item, spent];
}

/// What a rehearsal measured, in the order of the plan.
class RehearsalResult extends Equatable {
  const RehearsalResult({required this.collection, required this.items, required this.total});

  final Collection collection;

  /// Every item of the plan, including the ones the rehearsal never reached,
  /// which have a zero.
  final List<RehearsedItem> items;

  /// From the start of the rehearsal to its end, stops included: the length
  /// the band actually needed.
  final Duration total;

  @override
  List<Object?> get props => [collection, items, total];
}

/// Keeps time for a service: how long the item on the screen has been there,
/// and, during a rehearsal, how long went on each item.
///
/// Told about each change of what is showing rather than reading a timer of
/// its own, so it is a plain function of the moments it is given and a test
/// can walk it through a whole service in a millisecond.
class ServiceClock {
  String? _onAirKey;
  DateTime? _itemStartedAt;

  DateTime? _rehearsalStartedAt;
  Collection? _rehearsedCollection;
  String? _rehearsalItem;
  DateTime? _segmentStartedAt;
  final _spent = <String, Duration>{};

  /// When the item on the screen went on it, or null when nothing is live.
  DateTime? get itemStartedAt => _itemStartedAt;

  DateTime? get rehearsalStartedAt => _rehearsalStartedAt;
  bool get rehearsing => _rehearsalStartedAt != null;

  /// Reports what is on the screen now.
  ///
  /// [onAir] is the collection and the item the congregation sees, or null
  /// when nothing is live. [rehearsed] is the item the rehearsal is on: the
  /// live one when the output is live, otherwise wherever the operator is,
  /// since a band often rehearses with the projector off.
  void observe({
    required Collection? collection,
    required CollectionItem? onAir,
    required CollectionItem? rehearsed,
    required DateTime now,
  }) {
    final key = collection == null || onAir == null ? null : '${collection.id}/${onAir.id}';
    // The same item stays the same clock however many of its slides go by,
    // and however it moves in the list: it is keyed by id, not position.
    if (key != _onAirKey) {
      _onAirKey = key;
      _itemStartedAt = key == null ? null : now;
    }

    if (!rehearsing) return;
    if (collection != null && collection.id == _rehearsedCollection?.id) {
      _rehearsedCollection = collection;
    }
    final id = collection?.id == _rehearsedCollection?.id ? rehearsed?.id : null;
    if (id == _rehearsalItem) return;
    _closeSegment(now);
    _rehearsalItem = id;
    _segmentStartedAt = id == null ? null : now;
  }

  void startRehearsal(Collection collection, DateTime now) {
    _spent.clear();
    _rehearsalStartedAt = now;
    _rehearsedCollection = collection;
    _rehearsalItem = null;
    _segmentStartedAt = null;
  }

  /// Time spent so far on [itemId] in this rehearsal, the stretch still
  /// running included.
  Duration spentOn(String itemId, DateTime now) {
    final closed = _spent[itemId] ?? Duration.zero;
    if (itemId != _rehearsalItem || _segmentStartedAt == null) return closed;
    return closed + now.difference(_segmentStartedAt!);
  }

  /// Ends the rehearsal and returns what it measured, or null when there was
  /// no rehearsal to end.
  RehearsalResult? endRehearsal(DateTime now) {
    final started = _rehearsalStartedAt;
    final collection = _rehearsedCollection;
    if (started == null || collection == null) return null;
    _closeSegment(now);
    final result = RehearsalResult(
      collection: collection,
      items: [
        for (final item in collection.items)
          RehearsedItem(item: item, spent: _spent[item.id] ?? Duration.zero),
      ],
      total: now.difference(started),
    );
    _rehearsalStartedAt = null;
    _rehearsedCollection = null;
    _rehearsalItem = null;
    _segmentStartedAt = null;
    _spent.clear();
    return result;
  }

  void _closeSegment(DateTime now) {
    final id = _rehearsalItem;
    final since = _segmentStartedAt;
    if (id == null || since == null) return;
    _spent[id] = (_spent[id] ?? Duration.zero) + now.difference(since);
    _segmentStartedAt = null;
  }
}

/// A duration as a clock reads it: 4:05, or 1:02:30 past an hour.
String clockText(Duration duration) {
  final negative = duration.isNegative;
  final d = duration.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  final text = d.inHours > 0
      ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
      : '${d.inMinutes}:${two(d.inSeconds % 60)}';
  return negative ? '-$text' : text;
}

/// The planned length of a whole plan, and how many of its items have none.
({Duration total, int unplanned}) plannedLength(Collection collection) {
  var seconds = 0;
  var unplanned = 0;
  for (final item in collection.items) {
    final planned = item.plannedSecs;
    if (planned == null) {
      unplanned++;
    } else {
      seconds += planned;
    }
  }
  return (total: Duration(seconds: seconds), unplanned: unplanned);
}

/// Reads what an operator types as a length: "4:30", "4" (minutes), "1:05:00",
/// or null when it is not one.
int? parseDuration(String input) {
  final text = input.trim().replaceAll('.', ':').replaceAll(',', ':');
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length > 3 || parts.any((p) => int.tryParse(p.trim()) == null)) return null;
  final numbers = [for (final p in parts) int.parse(p.trim())];
  if (numbers.any((n) => n < 0)) return null;
  final seconds = switch (numbers.length) {
    1 => numbers[0] * 60,
    2 => numbers[1] < 60 ? numbers[0] * 60 + numbers[1] : null,
    _ =>
      numbers[1] < 60 && numbers[2] < 60 ? numbers[0] * 3600 + numbers[1] * 60 + numbers[2] : null,
  };
  if (seconds == null || seconds <= 0 || seconds > 6 * 3600) return null;
  return seconds;
}

/// A rehearsed length made into a plan: to the nearest five seconds, because
/// "4:37" pretends to a precision no song has from one Sunday to the next.
int plannedFromRehearsal(Duration spent) {
  final rounded = ((spent.inMilliseconds / 5000).round() * 5);
  return rounded < 5 ? 5 : rounded;
}
