import 'package:flutter_modular/flutter_modular.dart';
import '../../core/module.dart';
import '../songs/children/song_form/presenter/cubit/cubit.dart';
import '../songs/children/songs_list/presenter/cubit/cubit.dart';
import '../songs/children/songs_list/repository/repository.dart';
import 'children/control/presenter/cubit/cubit.dart';
import 'children/control/repository/repository.dart';
import 'shell/shell_cubit.dart';
import 'shell/shell_page.dart';

class PresentationModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];

  @override
  void binds(Injector i) {
    i.add<ControlRepository>(ControlRepository.new);
    i.addSingleton<ControlCubit>(ControlCubit.new);
    i.add<ShellCubit>(ShellCubit.new);
    // Songs binds needed here because SongsShellSection lives under /presentation
    i.add<SongsListRepository>(SongsListRepository.new);
    i.add<SongsListCubit>(SongsListCubit.new);
    i.add<SongFormCubit>(SongFormCubit.new);
  }

  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const ShellPage());
  }
}
