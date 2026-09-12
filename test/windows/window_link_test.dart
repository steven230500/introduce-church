import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/models/slide_template.dart';
import 'package:introduce_church/core/windows/window_link.dart';

import '../helpers/builders.dart';

void main() {
  group('reading what the operator sent', () {
    test('carries the plan, so the far window has nothing to fetch', () {
      final payload = readPresentationPayload({
        'collection': collectionRow(
          id: 'c1',
          name: 'Culto domingo',
          items: [songItemRow(id: 'i1', collectionId: 'c1', order: 0, title: 'Sublime Gracia')],
        ),
        'templates': const <Map<String, dynamic>>[],
      });

      expect(payload.collection?.name, 'Culto domingo');
      expect(payload.collection?.items.single.displayTitle, 'Sublime Gracia');
    });

    test('carries the designs it will be drawn with', () {
      final payload = readPresentationPayload({
        'templates': [
          {'id': 'custom_1', 'name': 'De la iglesia', 'config': SlideTemplate.blueNight.toJson()},
        ],
      });

      expect(payload.templates.single.id, 'custom_1');
      expect(payload.templates.single.name, 'De la iglesia');
    });

    test('a message from the socket carries neither, and that is fine', () {
      // The server relays the position only. A window that gets one falls back
      // to what it already has.
      final payload = readPresentationPayload({
        'collection_id': 'c1',
        'current_item_index': 0,
        'current_slide_index': 0,
      });

      expect(payload.collection, isNull);
      expect(payload.templates, isEmpty);
    });

    test('one unreadable design does not cost the window the rest', () {
      final payload = readPresentationPayload({
        'templates': [
          {'id': 'broken'},
          {'id': 'ok', 'name': 'Buena', 'config': SlideTemplate.light.toJson()},
        ],
      });

      expect(payload.templates.map((t) => t.id), ['ok']);
    });

    test('junk where the plan should be leaves the window on what it had', () {
      final payload = readPresentationPayload({'collection': 'no es un plan', 'templates': 7});

      expect(payload.collection, isNull);
      expect(payload.templates, isEmpty);
    });
  });
}
