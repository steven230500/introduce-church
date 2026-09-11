import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/local_db/app_database.dart';
import 'core/local_db/bible_import_service.dart';
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

class _WindowCloseHandler extends WindowListener {
  @override
  void onWindowClose() async {
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
  windowManager.addListener(_WindowCloseHandler());
  await windowManager.setPreventClose(true);
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await BibleImportService(AppDatabase.instance).ensureBundledBiblesImported();

  final screen = await screenRetriever.getPrimaryDisplay();
  final sw = screen.size.width;
  final sh = screen.size.height;
  final w = sw * 0.8;
  final h = sh * 0.8;
  final x = (sw - w) / 2;
  final y = (sh - h) / 2;
  const windowOptions = WindowOptions(
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setBounds(Rect.fromLTWH(x, y, w, h));
    await windowManager.setMinimumSize(const Size(1024, 600));
    await windowManager.setTitle('');
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(ModularApp(module: AppModule(), child: const App()));
}

Future<void> _runDisplayWindow(String argStr) async {
  await windowManager.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final windowArgs = jsonDecode(argStr) as Map<String, dynamic>;
  final userId = windowArgs['user_id'] as String?;
  if (userId == null) return;

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
    runApp(StageApp(userId: userId));
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

  runApp(DisplayApp(userId: userId));
}
