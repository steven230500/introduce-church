import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/l10n.dart';
import '../services/app_prefs_service.dart';
import '../services/locale_controller.dart';

/// The language a secondary window speaks.
///
/// The projector, stage and stream windows run in engines of their own and
/// cannot listen to the control window's [LocaleController], so each reads the
/// saved choice once as it opens. A language changed mid-service reaches them
/// the next time they are opened. Null follows the computer, as the control
/// window does.
Future<Locale?> savedWindowLocale() async {
  try {
    final code = await AppPrefsService().getLocale();
    return code == null ? null : Locale(code);
  } catch (_) {
    return null;
  }
}

/// What a secondary window's MaterialApp needs to find its strings.
const windowLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  L10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
