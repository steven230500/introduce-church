import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/collection.dart';
import 'package:introduce_church/core/timing/item_timer.dart';
import 'package:introduce_church/core/timing/service_clock.dart';

import '../helpers/builders.dart';

void main() {
  final plan = Collection.fromJson(
    collectionRow(
      id: 'c1',
      items: [
        songItemRow(
          id: 'a',
          collectionId: 'c1',
          order: 0,
          title: 'Sublime gracia',
          plannedSecs: 240,
        ),
        songItemRow(id: 'b', collectionId: 'c1', order: 1, title: 'Cuán grande'),
        songItemRow(id: 'c', collectionId: 'c1', order: 2, title: 'Final', plannedSecs: 60),
      ],
    ),
  );
  final other = Collection.fromJson(
    collectionRow(
      id: 'c2',
      items: [songItemRow(id: 'x', collectionId: 'c2', order: 0)],
    ),
  );
  CollectionItem item(String id) => plan.items.firstWhere((i) => i.id == id);
  final t0 = DateTime(2026, 9, 13, 10);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  group('the item on the screen', () {
    test('its clock starts when it goes on, not at each slide', () {
      final clock = ServiceClock();
      clock.observe(collection: plan, onAir: item('a'), rehearsed: item('a'), now: at(0));
      // The next slide of the same song is the same item.
      clock.observe(collection: plan, onAir: item('a'), rehearsed: item('a'), now: at(90));
      expect(clock.itemStartedAt, at(0));

      clock.observe(collection: plan, onAir: item('b'), rehearsed: item('b'), now: at(200));
      expect(clock.itemStartedAt, at(200));
    });

    test('nothing live, no clock; back live, a fresh one', () {
      final clock = ServiceClock();
      clock.observe(collection: plan, onAir: item('a'), rehearsed: item('a'), now: at(0));
      clock.observe(collection: plan, onAir: null, rehearsed: item('a'), now: at(10));
      expect(clock.itemStartedAt, isNull);

      clock.observe(collection: plan, onAir: item('a'), rehearsed: item('a'), now: at(30));
      expect(clock.itemStartedAt, at(30));
    });
  });

  group('a rehearsal', () {
    test('adds up the time on each item, coming back to one included', () {
      final clock = ServiceClock()..startRehearsal(plan, at(0));
      clock.observe(collection: plan, onAir: null, rehearsed: item('a'), now: at(0));
      clock.observe(collection: plan, onAir: null, rehearsed: item('b'), now: at(250));
      // Back to the first song to go over the ending again.
      clock.observe(collection: plan, onAir: null, rehearsed: item('a'), now: at(400));
      expect(
        clock.spentOn('a', at(430)),
        const Duration(seconds: 280),
        reason: 'open stretch counts',
      );

      final result = clock.endRehearsal(at(460))!;

      expect(result.total, const Duration(seconds: 460));
      expect(
        {for (final e in result.items) e.item.id: e.spent.inSeconds},
        {'a': 310, 'b': 150, 'c': 0},
      );
      expect(clock.rehearsing, isFalse);
    });

    test('time spent looking at another service is not this one\'s', () {
      final clock = ServiceClock()..startRehearsal(plan, at(0));
      clock.observe(collection: plan, onAir: null, rehearsed: item('a'), now: at(0));
      clock.observe(collection: other, onAir: null, rehearsed: other.items.first, now: at(60));
      clock.observe(collection: plan, onAir: null, rehearsed: item('a'), now: at(600));

      final result = clock.endRehearsal(at(660))!;
      expect(result.items.first.spent, const Duration(seconds: 120));
    });

    test('there is nothing to end when none was started', () {
      expect(ServiceClock().endRehearsal(at(0)), isNull);
    });
  });

  group('reading and writing lengths', () {
    test('what an operator types', () {
      expect(parseDuration('4:30'), 270);
      expect(parseDuration(' 4 '), 240, reason: 'a bare number is minutes');
      expect(parseDuration('35'), 2100);
      expect(parseDuration('1:05:00'), 3900);
      expect(parseDuration('4.30'), 270);
      for (final bad in ['', 'cuatro', '4:75', '0', '-3', '7:00:00', '1:2:3:4']) {
        expect(parseDuration(bad), isNull, reason: bad);
      }
    });

    test('as a clock reads them', () {
      expect(clockText(const Duration(seconds: 65)), '1:05');
      expect(clockText(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(clockText(Duration.zero), '0:00');
    });

    test('a rehearsed time is rounded to the nearest five seconds', () {
      expect(plannedFromRehearsal(const Duration(seconds: 277)), 275);
      expect(plannedFromRehearsal(const Duration(seconds: 278)), 280);
      expect(plannedFromRehearsal(const Duration(seconds: 1)), 5);
    });

    test('a whole plan adds up, and says how much of it has no time', () {
      final length = plannedLength(plan);
      expect(length.total, const Duration(seconds: 300));
      expect(length.unplanned, 1);
    });
  });

  group('the item timer', () {
    test('counts against the plan, warns near the end, and says how far over', () {
      expect(timerReading(const Duration(seconds: 100), 240), (
        text: '1:40 / 4:00',
        pace: TimerPace.onTime,
      ));
      expect(timerReading(const Duration(seconds: 200), 240).pace, TimerPace.closing);
      expect(timerReading(const Duration(seconds: 282), 240), (
        text: '4:42 / 4:00  +0:42',
        pace: TimerPace.over,
      ));
      expect(timerReading(const Duration(seconds: 75), null), (
        text: '1:15',
        pace: TimerPace.onTime,
      ));
    });
  });
}
