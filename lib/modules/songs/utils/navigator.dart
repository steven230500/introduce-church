import '../../../core/utils/navigator.dart';

class SongsNavigator {
  SongsNavigator._();

  static Future<void> goToList() {
    return CustomNavigator.goTo('/songs/');
  }
}
