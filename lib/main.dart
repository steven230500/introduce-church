import 'dart:async';
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/local_db/app_database.dart';
import 'core/local_db/bible_import_service.dart';
import 'core/services/window_bounds_store.dart';
import 'module.dart';
import 'modules/display/display_app.dart';
import 'modules/stage/stage_app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();
  final argStr = windowController.arguments;

  if (argStr.isNotEmpty) {
    await _runDisplayWindow(argStr);
  } else {
    await _runMainApp();
  }
}

class _MainWindowListener extends WindowListener {
  _MainWindowListener(this._bounds);

  final WindowBoundsStore _bounds;
  Timer? _saveTimer;

  /// macOS reports a resize or a move continuously while the mouse is down, so
  /// write once the operator has stopped rather than on every frame.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    // A minimised or full-screen window would be remembered as the size to
    // reopen at, which is not what the operator chose.
    if (await windowManager.isMinimized()) return;
    if (await windowManager.isFullScreen()) return;
    await _bounds.save(await windowManager.getBounds());
  }

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowClose() async {
    _saveTimer?.cancel();
    await _save();
    // Close drift DB before window destroys — unregisters sqlite3_update_hook
    // preventing null-pointer crash when Dart VM tears down mid-cleanup.
    await AppDatabase.instance.close();
    await windowManager.destroy();
  }
}

Future<void> _runMainApp() async {
  // Suppress Flutter's HardwareKeyboard duplicate-key assertion caused by
  // desktop_multi_window forwarding platform key events that arrive out-of-sync.
  // This is a known Flutter macOS bug and does not affect runtime behaviour.
  FlutterError.onError = (details) {
    if (details.exception is AssertionError &&
        details.exception.toString().contains('_pressedKeys.containsKey')) {
      return; // swallow silently
    }
    FlutterError.presentError(details);
  };

  await windowManager.ensureInitialized();
  final boundsStore = WindowBoundsStore();
  windowManager.addListener(_MainWindowListener(boundsStore));
  await windowManager.setPreventClose(true);
  await dotenv.load(fileName: '.env');
  await BibleImportService(AppDatabase.instance).ensureBundledBiblesImported();

  final bounds = resolveWindowBounds(
    saved: await boundsStore.load(),
    primary: _workArea(await screenRetriever.getPrimaryDisplay()),
    displays: (await screenRetriever.getAllDisplays()).map(_workArea).toList(),
  );
  const windowOptions = WindowOptions(
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setBounds(bounds);
    await windowManager.setMinimumSize(kMinWindowSize);
    await windowManager.setTitle('');
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(ModularApp(module: AppModule(), child: const App()));
}

/// The part of a display a window may occupy, menu bar and dock excluded.
Rect _workArea(Display display) {
  final origin = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;
  return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
}

Future<void> _runDisplayWindow(String argStr) async {
  await windowManager.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final windowArgs = jsonDecode(argStr) as Map<String, dynamic>;
  final windowType = windowArgs['type'] as String? ?? 'display';
  final screenData = windowArgs['screen'] as Map<String, dynamic>?;

  if (windowType == 'stage') {
    const windowOptions = WindowOptions(
      size: Size(1000, 600),
      center: true,
      backgroundColor: Colors.black,
      title: 'Monitor de Escenario',
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    runApp(const StageApp());
    return;
  }

  // Display window
  if (screenData != null && screenData.isNotEmpty) {
    final x = (screenData['x'] as num).toDouble();
    final y = (screenData['y'] as num).toDouble();
    final w = (screenData['w'] as num).toDouble();
    final h = (screenData['h'] as num).toDouble();
    windowManager.waitUntilReadyToShow(null, () async {
      await windowManager.setBounds(Rect.fromLTWH(x, y, w, h));
      await windowManager.setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();
    });
  } else {
    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.black,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const DisplayApp());
}
