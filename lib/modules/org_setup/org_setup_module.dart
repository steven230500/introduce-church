import 'package:flutter_modular/flutter_modular.dart';
import '../../core/module.dart';
import 'org_setup_cubit.dart';
import 'org_setup_page.dart';

class OrgSetupModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];

  @override
  void binds(Injector i) {
    i.add<OrgSetupCubit>(OrgSetupCubit.new);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const OrgSetupPage());
  }
}
