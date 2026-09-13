import 'package:flutter/widgets.dart';

import 'app_prefs_service.dart';

/// The language the app is in.
///
/// A [ValueNotifier] rather than a cubit: exactly one widget listens to it, at
/// the root, and a language change has to rebuild everything below that point
/// anyway.
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController(this._prefs) : super(null) {
    // Nothing waits for this. The app opens following the computer and flips
    // to the saved choice a frame later, which nobody sees and which keeps
    // startup off the disk.
    load();
  }

  final AppPrefsService _prefs;

  /// Languages the app has strings for. Spanish first because it is the one
  /// the app was written in and the one most of its churches read.
  static const supported = [Locale('es'), Locale('en')];

  /// Reads the saved choice. Null means follow the computer, which is what a
  /// machine that has never been told anything should do.
  Future<void> load() async {
    final code = await _prefs.getLocale();
    value = code == null ? null : Locale(code);
  }

  Future<void> choose(Locale? locale) async {
    value = locale;
    await _prefs.setLocale(locale?.languageCode);
  }
}
