import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';

import '../models/collection.dart';
import '../models/slide_template.dart';
import '../utils/app_logger.dart';

/// The local link between the control window and the screens following it.
///
/// The server socket is how these windows stayed in step, which meant the
/// projector needed the internet to show a slide. Most of the rooms this runs
/// in have none. This path goes through the platform and never leaves the
/// machine, and it carries the plan and the designs along with the position,
/// so a window that receives it has nothing left to fetch.
///
/// The socket still runs when it can: it is what lets the server remember
/// where the service is, and what a window opened later catches up from.
abstract final class WindowLink {
  /// Named on the window channel, which every engine shares.
  static const method = 'presentation.state';

  /// Sends [payload] to every projector and stage window that is open.
  ///
  /// Windows are looked up each time rather than remembered: one can be closed
  /// from its own title bar, and a stale controller would throw on every slide
  /// change for the rest of the service.
  static Future<void> broadcast(Map<String, dynamic> payload) async {
    final List<WindowController> windows;
    try {
      windows = await WindowController.getAll();
    } catch (e) {
      appLogger.w('WindowLink.broadcast | cannot list windows: $e');
      return;
    }

    final message = jsonEncode(payload);
    for (final window in windows) {
      // The control window itself was launched with no arguments. Everything
      // else was told what kind of window to be.
      if (window.arguments.isEmpty) continue;
      try {
        await window.invokeMethod(method, message);
      } catch (_) {
        // Closed between listing and sending, or not listening yet. Neither is
        // worth a log line on every slide change.
      }
    }
  }

  /// Registers [onState] as this window's handler for operator updates.
  static Future<void> listen(void Function(Map<String, dynamic> state) onState) async {
    try {
      final controller = await WindowController.fromCurrentEngine();
      await controller.setWindowMethodHandler((call) async {
        if (call.method != method) return null;
        final raw = call.arguments;
        if (raw is! String) return null;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) onState(decoded);
        } catch (e) {
          appLogger.w('WindowLink | unreadable message: $e');
        }
        return null;
      });
    } on PlatformException catch (e) {
      appLogger.w('WindowLink.listen | $e');
    } catch (e) {
      appLogger.w('WindowLink.listen | $e');
    }
  }
}

/// What a control window sends along with the position: the plan itself and
/// every design it might need.
///
/// Reading it is what lets a projector window draw a slide without a network.
/// Both fields are absent when the message came from the server socket, which
/// only carries the position.
({Collection? collection, List<SlideTemplate> templates}) readPresentationPayload(
  Map<String, dynamic> state,
) {
  Collection? collection;
  final raw = state['collection'];
  if (raw is Map<String, dynamic>) {
    try {
      collection = Collection.fromJson(raw);
    } catch (e) {
      appLogger.w('WindowLink | unreadable collection: $e');
    }
  }

  final templates = <SlideTemplate>[];
  final rows = state['templates'];
  if (rows is List) {
    for (final row in rows) {
      if (row is! Map) continue;
      try {
        templates.add(
          SlideTemplate.fromJson(
            id: row['id'] as String,
            name: row['name'] as String,
            json: Map<String, dynamic>.from(row['config'] as Map),
          ),
        );
      } catch (e) {
        // One bad design must not cost the window the rest of them.
        appLogger.w('WindowLink | unreadable design: $e');
      }
    }
  }

  return (collection: collection, templates: templates);
}
