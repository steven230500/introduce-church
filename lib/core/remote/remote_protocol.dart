import '../../modules/presentation/children/control/presenter/cubit/cubit.dart';

/// What a phone is shown: the service, where the operator is, and what is on
/// the screen. Plain JSON, because the other end is a web page.
Map<String, dynamic> remoteSnapshot(ControlModel model, {String? language}) {
  final collection = model.activeCollection;
  final items = collection?.items ?? const [];
  final live = model.liveItem;
  final liveSlides = model.liveSlides;
  String? nextText;
  if (live != null) {
    if (model.liveSlideIndex + 1 < liveSlides.length) {
      nextText = liveSlides[model.liveSlideIndex + 1];
    } else if (model.liveItemIndex + 1 < items.length) {
      final following = items[model.liveItemIndex + 1].slides;
      nextText = following.isEmpty ? null : following.first;
    }
  }
  return {
    'lang': ?language,
    'collection': collection?.name,
    'items': [
      for (final item in items) {'title': item.displayTitle, 'slides': item.slides.length},
    ],
    'item': model.currentItemIndex,
    'slide': model.currentSlideIndex,
    'live_item': model.liveItemIndex,
    'live_slide': model.liveSlideIndex,
    'is_live': model.isLive,
    'blank': model.blankScreen,
    'holding': model.isHolding,
    'waiting': model.waiting.active,
    // Words only: a photo's path means nothing on a phone.
    'text': _words(model.liveSlideContent, live),
    'title': live?.displayTitle,
    'next': nextText,
  };
}

String? _words(String? content, Object? item) {
  if (content == null) return null;
  final looksLikeFile = content.startsWith('/') || content.startsWith('http');
  return looksLikeFile ? null : content;
}

/// Something a phone asked for.
sealed class RemoteCommand {
  const RemoteCommand();

  /// Reads a message from a phone, or null when it is not one this version
  /// understands. Unknown messages are ignored, never guessed at.
  static RemoteCommand? parse(Object? raw) {
    if (raw is! Map) return null;
    return switch (raw['type']) {
      'next' => const RemoteNext(),
      'prev' => const RemotePrev(),
      'live' => const RemoteToggleLive(),
      'blank' => const RemoteToggleBlank(),
      'take' => const RemoteTake(),
      'goto' when raw['item'] is int => RemoteGoTo(
        raw['item'] as int,
        raw['slide'] is int ? raw['slide'] as int : 0,
      ),
      _ => null,
    };
  }
}

class RemoteNext extends RemoteCommand {
  const RemoteNext();
}

class RemotePrev extends RemoteCommand {
  const RemotePrev();
}

class RemoteToggleLive extends RemoteCommand {
  const RemoteToggleLive();
}

class RemoteToggleBlank extends RemoteCommand {
  const RemoteToggleBlank();
}

class RemoteTake extends RemoteCommand {
  const RemoteTake();
}

class RemoteGoTo extends RemoteCommand {
  const RemoteGoTo(this.item, this.slide);
  final int item;
  final int slide;
}

/// Does what [command] asks, the same way the keyboard would.
void applyRemoteCommand(ControlCubit control, RemoteCommand command) {
  switch (command) {
    case RemoteNext():
      control.nextSlide();
    case RemotePrev():
      control.prevSlide();
    case RemoteToggleLive():
      control.toggleLive();
    case RemoteToggleBlank():
      control.toggleBlank();
    case RemoteTake():
      control.take();
    case RemoteGoTo(:final item, :final slide):
      control.selectItem(item);
      if (slide > 0) control.selectSlide(slide);
  }
}
