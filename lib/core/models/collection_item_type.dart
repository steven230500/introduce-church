enum CollectionItemType {
  song,
  bibleVerse,
  sermon,
  freeSlide,
  imageSlide,
  videoSlide,
  announcement,

  /// A moment in the service - "Alabanza", "Prédica" - dropped into the same
  /// ordered list as everything else. What follows belongs to it until the
  /// next one; it is not a folder that holds them.
  section,
}

extension CollectionItemTypeX on CollectionItemType {
  String get value => switch (this) {
    CollectionItemType.song => 'song',
    CollectionItemType.bibleVerse => 'bible_verse',
    CollectionItemType.sermon => 'sermon',
    CollectionItemType.freeSlide => 'free_slide',
    CollectionItemType.imageSlide => 'image_slide',
    CollectionItemType.videoSlide => 'video_slide',
    CollectionItemType.announcement => 'announcement',
    CollectionItemType.section => 'section',
  };

  String get label => switch (this) {
    CollectionItemType.song => 'Canción',
    CollectionItemType.bibleVerse => 'Versículo',
    CollectionItemType.sermon => 'Prédica',
    CollectionItemType.freeSlide => 'Slide libre',
    CollectionItemType.imageSlide => 'Presentación',
    CollectionItemType.videoSlide => 'Video',
    CollectionItemType.announcement => 'Anuncio',
    CollectionItemType.section => 'Momento',
  };

  static CollectionItemType fromString(String v) => switch (v) {
    'bible_verse' => CollectionItemType.bibleVerse,
    'sermon' => CollectionItemType.sermon,
    'free_slide' => CollectionItemType.freeSlide,
    'image_slide' => CollectionItemType.imageSlide,
    'video_slide' => CollectionItemType.videoSlide,
    'announcement' => CollectionItemType.announcement,
    'section' => CollectionItemType.section,
    _ => CollectionItemType.song,
  };
}
