import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/bootstrap.dart';
import '../../core/services/locale_controller.dart';
import '../../core/windows/window_locale.dart';
import 'presenter/display_cubit.dart';
import 'presenter/display_page.dart';

/// The projector window.
///
/// It runs in its own engine, so it builds its own clients rather than
/// receiving them from the control window.
class DisplayApp extends StatelessWidget {
  const DisplayApp({super.key, this.locale});

  /// The saved language, read before the window opened. Null follows the computer.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: windowLocalizationsDelegates,
      home: FutureBuilder<WindowClients>(
        future: bootstrapWindowClients(),
        builder: (context, snapshot) {
          final clients = snapshot.data;
          if (clients == null) {
            // Black, not a spinner: this window is pointed at a congregation.
            return const ColoredBox(color: Colors.black, child: SizedBox.expand());
          }
          return BlocProvider(
            create: (_) => DisplayCubit(clients.api, clients.socket)..init(),
            child: const DisplayPage(),
          );
        },
      ),
    );
  }
}
