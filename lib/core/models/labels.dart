import '../../l10n/l10n.dart';
import 'collection.dart';
import 'collection_item_type.dart';
import 'slide_layer.dart';
import 'slide_template.dart';
import 'song.dart';

// The names the operator reads for things the models only know by value.
//
// The models keep their Spanish getters for what is not shown - the printed
// sheet's older callers, the projection record - while everything drawn on
// the operator's screen asks here, in the language the operator picked.

extension CollectionItemTypeLabel on CollectionItemType {
  String labelIn(L10n t) => switch (this) {
    CollectionItemType.song => t.itemTypeSong,
    CollectionItemType.bibleVerse => t.itemTypeVerse,
    CollectionItemType.sermon => t.itemTypeSermon,
    CollectionItemType.freeSlide => t.itemTypeFreeSlide,
    CollectionItemType.imageSlide => t.itemTypePresentation,
    CollectionItemType.videoSlide => t.itemTypeVideo,
    CollectionItemType.announcement => t.itemTypeAnnouncement,
    CollectionItemType.section => t.itemTypeSection,
  };
}

extension VerseTypeLabel on VerseType {
  String labelIn(L10n t) => switch (this) {
    VerseType.verse => t.verseTypeVerse,
    VerseType.chorus => t.verseTypeChorus,
    VerseType.bridge => t.verseTypeBridge,
    VerseType.preCHORUS => t.verseTypePreChorus,
    VerseType.tag => t.verseTypeTag,
    VerseType.intro => t.verseTypeIntro,
    VerseType.outro => t.verseTypeOutro,
  };
}

extension CollectionItemLabels on CollectionItem {
  /// The item's name. Only the fallbacks differ from [displayTitle]: a title
  /// the church typed stays as typed.
  String titleIn(L10n t) {
    final title = contentJson?['title'] as String?;
    return switch (type) {
      CollectionItemType.sermon => title ?? t.itemTypeSermon,
      CollectionItemType.freeSlide =>
        title ?? (contentJson?['text'] as String? ?? t.itemTypeFreeSlide).split('\n').first,
      CollectionItemType.imageSlide => title ?? t.itemTypePresentation,
      CollectionItemType.videoSlide => title ?? t.itemTypeVideo,
      CollectionItemType.announcement => title ?? t.itemTypeAnnouncement,
      _ => displayTitle,
    };
  }

  String subtitleIn(L10n t) => switch (type) {
    CollectionItemType.sermon => t.sermonPointCount(
      List<String>.from(contentJson?['points'] ?? const []).length,
    ),
    CollectionItemType.announcement =>
      contentJson?['timerTarget'] != null ? t.announcementWithCountdown : '',
    _ => displaySubtitle,
  };

  /// One caption per slide: Verse, Chorus (2), Point 3.
  List<String> slideLabelsIn(L10n t) {
    switch (type) {
      case CollectionItemType.song:
        final seen = <VerseType, int>{};
        return [
          for (final verse in song?.verses ?? const <Verse>[])
            () {
              final n = seen[verse.type] = (seen[verse.type] ?? 0) + 1;
              final base = verse.type.labelIn(t);
              return n == 1 ? base : '$base ($n)';
            }(),
        ];
      case CollectionItemType.imageSlide:
        return [for (var i = 0; i < slides.length; i++) t.slideNumber(i + 1)];
      case CollectionItemType.videoSlide:
        return [t.itemTypeVideo];
      case CollectionItemType.sermon:
        final points = List<String>.from(contentJson?['points'] ?? const []).length;
        return [t.sermonTitleSlide, for (var i = 0; i < points; i++) t.sermonPoint(i + 1)];
      default:
        return slideLabels;
    }
  }
}

extension SlideLayerLabel on SlideLayer {
  String labelIn(L10n t) => switch (this) {
    TextSlideLayer _ => t.designText,
    ReferenceSlideLayer _ => t.designReference,
  };
}

extension SlideTemplateLabel on SlideTemplate {
  /// A built-in design's name in the operator's language. The church's own
  /// designs keep the name the church gave them.
  String nameIn(L10n t) => switch (id) {
    'preset_dark_classic' => t.presetDarkClassic,
    'preset_blue_night' => t.presetBlueNight,
    'preset_lower_third' => t.presetLowerThird,
    'preset_light' => t.presetLight,
    'preset_motion_mist' => t.sceneMist,
    'preset_motion_rays' => t.sceneRays,
    'preset_motion_silk' => t.sceneSilk,
    _ => name,
  };
}
