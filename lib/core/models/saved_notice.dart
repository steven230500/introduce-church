import 'package:equatable/equatable.dart';

/// One of the messages a church shows over and over.
///
/// The children going out, the offering, where the bathrooms are. These were
/// typed from scratch every week with the room waiting.
class SavedNotice extends Equatable {
  const SavedNotice({required this.text, this.autoHideSecs = 0});

  final String text;

  /// Seconds after which it takes itself back down. Zero means it stays until
  /// the operator dismisses it, which is what an offering notice wants and
  /// "the children go out now" does not.
  final int autoHideSecs;

  bool get hides => autoHideSecs > 0;

  factory SavedNotice.fromJson(Map<String, dynamic> json) => SavedNotice(
    text: json['text'] as String? ?? '',
    autoHideSecs: (json['auto_hide_secs'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {'text': text, 'auto_hide_secs': autoHideSecs};

  @override
  List<Object?> get props => [text, autoHideSecs];
}
