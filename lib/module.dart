import 'package:flutter_modular/flutter_modular.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/module.dart';
import 'core/services/supabase_service.dart';
import 'modules/auth/module.dart';
import 'modules/org_setup/org_setup_module.dart';
import 'modules/presentation/module.dart';
import 'modules/songs/module.dart';

class AuthGuard extends RouteGuard {
  AuthGuard() : super(redirectTo: '/auth/login');

  @override
  Future<bool> canActivate(String path, ParallelRoute route) async {
    return Supabase.instance.client.auth.currentUser != null;
  }
}

class OrgGuard extends RouteGuard {
  OrgGuard() : super(redirectTo: '/org-setup/');

  @override
  Future<bool> canActivate(String path, ParallelRoute route) async {
    final svc = Modular.get<SupabaseService>();
    if (svc.orgId != null) return true;
    final loaded = await svc.loadOrgId();
    return loaded != null;
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
