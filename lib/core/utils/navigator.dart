import 'package:flutter_modular/flutter_modular.dart';

class CustomNavigator {
  CustomNavigator._();

  static Future<T?> goTo<T>(String path, {dynamic arguments}) {
    return Modular.to.pushNamed<T>(path, arguments: arguments);
  }

  static Future<T?> goToAndReplace<T>(String path, {dynamic arguments}) {
    return Modular.to.pushReplacementNamed<T, dynamic>(path, arguments: arguments);
  }

  static void goBack<T>([T? result]) {
    Modular.to.pop(result);
  }
}
