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

  /// Whether this version knows what [value] is.
  ///
  /// A newer version will add kinds of item. Read as a song, which is what
  /// [fromString] falls back to, one of those turns into an empty row this
  /// version cannot explain - which is what 1.0.x did with the moments of
  /// 1.1.0. What is not known is left out instead.
  static bool isKnown(String? value) => switch (value) {
    'song' ||
    'bible_verse' ||
    'sermon' ||
    'free_slide' ||
    'image_slide' ||
    'video_slide' ||
    'announcement' ||
    'section' => true,
    _ => false,
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
