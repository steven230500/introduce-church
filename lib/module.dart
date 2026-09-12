import 'package:flutter_modular/flutter_modular.dart';
import 'core/api/api_client.dart';
import 'core/module.dart';
import 'modules/auth/module.dart';
import 'modules/org_setup/org_setup_module.dart';
import 'modules/presentation/module.dart';
import 'modules/songs/module.dart';

class AuthGuard extends RouteGuard {
  AuthGuard() : super(redirectTo: '/auth/login');

  @override
  Future<bool> canActivate(String path, ParallelRoute route) async {
    return Modular.get<ApiClient>().isAuthenticated;
  }
}

class OrgGuard extends RouteGuard {
  OrgGuard() : super(redirectTo: '/org-setup/');

  @override
  Future<bool> canActivate(String path, ParallelRoute route) async {
    final api = Modular.get<ApiClient>();
    if (api.orgId != null) return true;
    // The session may predate the membership, so ask the server once before
    // sending the operator back to setup.
    final refreshed = await api.refreshSession();
    return refreshed?.hasOrg ?? false;
  }
}

class AppModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];

  @override
  void routes(RouteManager r) {
    r.module('/auth', module: AuthModule());
    r.module('/org-setup', module: OrgSetupModule(), guards: [AuthGuard()]);
    r.module('/presentation', module: PresentationModule(), guards: [AuthGuard(), OrgGuard()]);
    r.module('/songs', module: SongsModule(), guards: [AuthGuard(), OrgGuard()]);
    r.redirect('/', to: '/auth/splash');
  }
}
