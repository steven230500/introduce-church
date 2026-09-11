import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import 'cubit/cubit.dart';
import 'widgets/online_search_dialog.dart';
import '../../../../../core/widgets/app_dialog.dart';

part 'widgets/body.dart';

class SongsListPage extends StatelessWidget {
  const SongsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.travel_explore),
            tooltip: 'Buscar letra en línea',
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (_) => const OnlineSongSearchDialog(),
              );
              if (context.mounted) context.read<SongsListCubit>().load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva canción',
            onPressed: () async {
              final created = await Modular.to.pushNamed('/songs/new');
              if (created == true && context.mounted) {
                context.read<SongsListCubit>().load();
              }
            },
          ),
        ],
      ),
      body: const _Body(),
    );
  }
}
