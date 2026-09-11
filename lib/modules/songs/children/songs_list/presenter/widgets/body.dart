part of '../page.dart';

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar canciones...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: context.read<SongsListCubit>().onSearchChanged,
          ),
        ),
        Expanded(
          child: BlocBuilder<SongsListCubit, SongsListState>(
            builder: (context, state) => switch (state) {
              SongsListLoadingState() => const Center(child: CircularProgressIndicator()),
              SongsListErrorState(:final message) => Center(child: Text(message)),
              SongsListLoadedState(:final model) => _SongsList(model: model),
            },
          ),
        ),
      ],
    );
  }
}

class _SongsList extends StatelessWidget {
  const _SongsList({required this.model});
  final SongsListModel model;

  @override
  Widget build(BuildContext context) {
    if (model.songs.isEmpty) {
      return const Center(child: Text('No hay canciones'));
    }
    return ListView.separated(
      itemCount: model.songs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final song = model.songs[i];
        return ListTile(
          title: Text(song.title),
          subtitle: song.author != null ? Text(song.author!) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${song.verses.length} versos',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Editar',
                onPressed: () async {
                  final saved = await Modular.to.pushNamed('/songs/edit', arguments: song);
                  if (saved == true && context.mounted) {
                    context.read<SongsListCubit>().load();
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                tooltip: 'Eliminar',
                onPressed: () async {
                  final confirm = await showAppConfirmDialog(
                    context,
                    title: 'Eliminar canción',
                    message: '¿Eliminar "${song.title}"? Esta acción no se puede deshacer.',
                    confirmLabel: 'Eliminar',
                    destructive: true,
                    icon: Icons.delete_outline,
                  );
                  if (confirm == true && context.mounted) {
                    context.read<SongsListCubit>().deleteSong(song.id);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
