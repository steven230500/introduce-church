enum CollectionItemType {
  song,
  bibleVerse,
  sermon,
  freeSlide,
  imageSlide,
  videoSlide,
  announcement,
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
  };

  String get label => switch (this) {
    CollectionItemType.song => 'Canción',
    CollectionItemType.bibleVerse => 'Versículo',
    CollectionItemType.sermon => 'Prédica',
    CollectionItemType.freeSlide => 'Slide libre',
    CollectionItemType.imageSlide => 'Presentación',
    CollectionItemType.videoSlide => 'Video',
    CollectionItemType.announcement => 'Anuncio',
  };

  static CollectionItemType fromString(String v) => switch (v) {
    'bible_verse' => CollectionItemType.bibleVerse,
    'sermon' => CollectionItemType.sermon,
    'free_slide' => CollectionItemType.freeSlide,
    'image_slide' => CollectionItemType.imageSlide,
    'video_slide' => CollectionItemType.videoSlide,
    'announcement' => CollectionItemType.announcement,
    _ => CollectionItemType.song,
  };
}
