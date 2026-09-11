import '../../../core/utils/navigator.dart';

class PresentationNavigator {
  PresentationNavigator._();

  static Future<void> goToControl() {
    return CustomNavigator.goTo('/presentation/');
  }
}
