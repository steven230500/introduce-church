import '../../../core/utils/navigator.dart';

class AuthNavigator {
  AuthNavigator._();

  static Future<void> goToLogin() {
    return CustomNavigator.goTo('/auth/login');
  }
}
