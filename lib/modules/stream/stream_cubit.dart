import 'package:flutter/foundation.dart';

import '../../core/stream/stream_style.dart';
import '../display/presenter/display_cubit.dart';

/// Follows the service like the projector does, and also keeps the look the
/// operator chose for the stream.
///
/// Built on the projector's cubit because deciding what is on the screen - a
/// slide, black, the waiting scene, nothing - is the same question for both
/// windows, and it has to be answered the same way, with no network.
class StreamCubit extends DisplayCubit {
  StreamCubit(super.api, super.socket, {StreamStyle initial = const StreamStyle()})
    : style = ValueNotifier(initial);

  /// Changes without a new slide: the operator adjusting the size while a
  /// verse is up should see it change on the verse.
  final ValueNotifier<StreamStyle> style;

  @override
  Future<void> applyLocalState(Map<String, dynamic> state) async {
    // Only from the control window: the server never carries it, so a message
    // from the socket must not reset it.
    if (state.containsKey('stream_style')) {
      style.value = StreamStyle.fromJson(state['stream_style']);
    }
    await super.applyLocalState(state);
  }

  @override
  Future<void> close() {
    style.dispose();
    return super.close();
  }
}
