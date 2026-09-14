import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../core/module.dart';
import '../../core/services/locale_controller.dart';
import 'children/language/language_page.dart';
import 'children/login/presenter/cubit/cubit.dart';
import 'children/login/presenter/page.dart';
import 'children/login/repository/repository.dart';
import 'children/splash/presenter/cubit/cubit.dart';
import 'children/splash/presenter/page.dart';

class AuthModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];

  @override
  void binds(Injector i) {
    i.add<LoginRepository>(LoginRepository.new);
    i.add<LoginCubit>(LoginCubit.new);
    i.add<SplashCubit>(SplashCubit.new);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/splash',
      child: (_) => BlocProvider(
        create: (_) => Modular.get<SplashCubit>()..check(),
        child: const SplashPage(),
      ),
    );
    r.child(
      '/language',
      child: (_) => LanguagePage(
        controller: Modular.get<LocaleController>(),
        onChosen: () => Modular.to.navigate('/auth/login'),
      ),
    );
    r.child(
      '/login',
      child: (_) =>
          BlocProvider(create: (_) => Modular.get<LoginCubit>(), child: const LoginPage()),
    );
  }
}
