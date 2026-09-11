enum AppEnv { dev, prod }

extension AppEnvX on AppEnv {
  static AppEnv get current {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    return flavor == 'prod' ? AppEnv.prod : AppEnv.dev;
  }

  static bool get isProd => current == AppEnv.prod;
  static bool get isDev => current == AppEnv.dev;
}
