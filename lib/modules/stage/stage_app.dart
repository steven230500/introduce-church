import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/bootstrap.dart';
import '../../core/services/locale_controller.dart';
import '../../core/windows/window_locale.dart';
import 'presenter/stage_cubit.dart';
import 'presenter/stage_page.dart';

/// The stage monitor: what the worship team reads, with the operator's notes.
class StageApp extends StatelessWidget {
  const StageApp({super.key, this.locale});

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
            return const ColoredBox(color: Colors.black, child: SizedBox.expand());
          }
          return BlocProvider(
            create: (_) => StageCubit(clients.api, clients.socket)..init(),
            child: const StagePage(),
          );
        },
      ),
    );
  }
}
