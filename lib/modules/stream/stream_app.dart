import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/bootstrap.dart';
import '../../core/stream/stream_style.dart';
import '../../core/stream/stream_view.dart';
import '../display/presenter/display_cubit.dart';
import 'stream_cubit.dart';

/// The window a streaming program captures: the words of the service over a
/// key colour, for laying over a camera.
class StreamApp extends StatelessWidget {
  const StreamApp({super.key, required this.initial});

  final StreamStyle initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<WindowClients>(
        future: bootstrapWindowClients(),
        builder: (context, snapshot) {
          final clients = snapshot.data;
          // The key colour while starting, not a spinner: this window is
          // being captured, and a frame of anything else goes out on the stream.
          if (clients == null) return StreamView(style: initial);
          return BlocProvider(
            create: (_) => StreamCubit(clients.api, clients.socket, initial: initial)..init(),
            child: const StreamPage(),
          );
        },
      ),
    );
  }
}

@visibleForTesting
class StreamPage extends StatelessWidget {
  const StreamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StreamCubit>();
    return ValueListenableBuilder<StreamStyle>(
      valueListenable: cubit.style,
      builder: (context, style, _) => BlocBuilder<StreamCubit, DisplayState>(
        builder: (context, state) {
          final (text, reference) = streamWords(state);
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: StreamView(
              key: ValueKey('$text|$reference|${style.hashCode}'),
              style: style,
              text: text,
              reference: reference,
            ),
          );
        },
      ),
    );
  }
}

/// What the stream shows for what the projector is showing.
///
/// Words only. A photo, a video, the waiting scene or a black screen are for
/// the room; on the stream the camera is already the picture, so those leave
/// the key colour alone. A notice put over the slides is words, and shows when
/// there are no lyrics under it.
(String, String) streamWords(DisplayState state) => switch (state) {
  DisplaySlideState(:final content, :final reference) => (content, reference),
  DisplayAnnouncementState(:final message) => (message, ''),
  DisplayImageState(overlayVisible: true, :final overlayText?) ||
  DisplayVideoState(overlayVisible: true, :final overlayText?) ||
  DisplayCountdownState(overlayVisible: true, :final overlayText?) => (overlayText, ''),
  _ => ('', ''),
};
