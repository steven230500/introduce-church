import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../core/module.dart';
import 'children/song_form/presenter/cubit/cubit.dart';
import 'children/song_form/presenter/page.dart';
import 'children/songs_list/presenter/cubit/cubit.dart';
import 'children/songs_list/presenter/page.dart';
import 'children/songs_list/repository/repository.dart';

class SongsModule extends Module {
  @override
  List<Module> get imports => [CoreModule()];

  @override
  void binds(Injector i) {
    i.add<SongsListRepository>(SongsListRepository.new);
    i.add<SongsListCubit>(SongsListCubit.new);
    i.add<SongFormCubit>(SongFormCubit.new);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => BlocProvider(
        create: (_) => Modular.get<SongsListCubit>()..load(),
        child: const SongsListPage(),
      ),
    );
    r.child(
      '/new',
      child: (_) => BlocProvider(
        create: (_) => Modular.get<SongFormCubit>()..init(null),
        child: const SongFormPage(),
      ),
    );
    r.child(
      '/edit',
      child: (_) => BlocProvider(
        create: (_) => Modular.get<SongFormCubit>()..init(Modular.args.data),
        child: const SongFormPage(),
      ),
    );
    r.child(
      '/import',
      child: (_) => BlocProvider(
        create: (_) =>
            Modular.get<SongFormCubit>()..initPrefilled(Modular.args.data as SongFormModel),
        child: const SongFormPage(),
      ),
    );
  }
}
