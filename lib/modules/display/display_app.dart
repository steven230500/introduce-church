import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/bootstrap.dart';
import 'presenter/display_cubit.dart';
import 'presenter/display_page.dart';

/// The projector window.
///
/// It runs in its own engine, so it builds its own clients rather than
/// receiving them from the control window.
class DisplayApp extends StatelessWidget {
  const DisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
