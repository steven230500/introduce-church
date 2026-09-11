import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/models/song.dart';
import 'cubit/cubit.dart';
import 'widgets/paste_lyrics_dialog.dart';
import '../../../../../core/theme/app_colors.dart';

part 'widgets/body.dart';
part 'widgets/verse_editor.dart';

class SongFormPage extends StatelessWidget {
  const SongFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SongFormCubit, SongFormState>(
      listener: (context, state) {
        if (state is SongFormSavedState) Navigator.of(context).pop(true);
        if (state is SongFormErrorState) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: BlocBuilder<SongFormCubit, SongFormState>(
            builder: (_, state) {
              final isEditing = state is SongFormReadyState && state.model.isEditing;
              return Text(
                isEditing ? 'Editar canción' : 'Nueva canción',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(color: AppColors.surfaceControl, height: 1),
          ),
          actions: [
            BlocBuilder<SongFormCubit, SongFormState>(
              builder: (context, state) {
                final model = state is SongFormReadyState ? state.model : null;
                final canSave = model?.canSave == true;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: model?.isSaving == true
                      ? const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: canSave ? () => context.read<SongFormCubit>().save() : null,
                          child: Text(
                            'Guardar',
                            style: TextStyle(
                              color: canSave ? AppColors.accent : AppColors.textDisabled,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                );
              },
            ),
          ],
        ),
        body: const _Body(),
      ),
    );
  }
}
