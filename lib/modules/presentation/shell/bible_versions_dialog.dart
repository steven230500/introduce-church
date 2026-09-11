import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import '../../../core/services/bible_download_service.dart';
import '../../../core/widgets/app_dialog.dart';
import 'bible_versions_cubit.dart';
import '../../../core/theme/app_colors.dart';

Future<void> showBibleVersionsDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => BibleVersionsCubit(Modular.get<BibleDownloadService>())..load(),
      child: const _BibleVersionsDialog(),
    ),
  );
}

class _BibleVersionsDialog extends StatelessWidget {
  const _BibleVersionsDialog();

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Versiones de la Biblia',
      icon: Icons.book_outlined,
      width: 480,
      contentPadding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<BibleVersionsCubit, BibleVersionsState>(
            builder: (context, state) => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: state.versions.length,
              separatorBuilder: (c, i) => const Divider(color: kDialogBorder, height: 16),
              itemBuilder: (_, i) => _VersionRow(state: state.versions[i]),
            ),
          ),
          const _ImportNote(),
        ],
      ),
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────────

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.state});
  final VersionState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BibleVersionsCubit>();
    final installed = state.status == VersionStatus.installed;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceControl,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            installed ? Icons.menu_book_rounded : Icons.menu_book_outlined,
            size: 18,
            color: installed ? AppColors.success : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.meta.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    state.meta.bundled ? '${state.meta.code} • Incluida' : state.meta.code,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  if (state.meta.localImport && !installed) ...[
                    const SizedBox(width: 6),
                    const _LocalImportBadge(),
                  ],
                  if (state.meta.apiCode != null && !installed) ...[
                    const SizedBox(width: 6),
                    const _ApiBadge(),
                  ],
                ],
              ),
            ],
          ),
        ),
        _VersionAction(state: state, cubit: cubit),
      ],
    );
  }
}

class _LocalImportBadge extends StatelessWidget {
  const _LocalImportBadge();

  @override
  Widget build(BuildContext context) => _Badge('archivo local', AppColors.textDisabled);
}

class _ApiBadge extends StatelessWidget {
  const _ApiBadge();

  @override
  Widget build(BuildContext context) => _Badge('bolls.life', const Color(0xFF1D3D6B));
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.borderColor);
  final String label;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 9)),
    );
  }
}

// ── Action ────────────────────────────────────────────────────────────────────

class _VersionAction extends StatelessWidget {
  const _VersionAction({required this.state, required this.cubit});
  final VersionState state;
  final BibleVersionsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      VersionStatus.checking => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),

      VersionStatus.installed =>
        state.meta.bundled
            ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
            : IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                tooltip: 'Eliminar',
                onPressed: () => cubit.delete(state.meta.code),
              ),

      VersionStatus.notInstalled =>
        state.meta.localImport
            ? FilledButton.icon(
                onPressed: () => cubit.importFromFile(state.meta.code),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceControl,
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text('Importar', style: TextStyle(fontSize: 13)),
              )
            : state.meta.canDownload
            ? FilledButton.icon(
                onPressed: () => cubit.download(state.meta.code),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Descargar', style: TextStyle(fontSize: 13)),
              )
            : const SizedBox.shrink(),

      VersionStatus.downloading => _ProgressBar(progress: state.progress),

      VersionStatus.importing => const SizedBox(
        width: 100,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
            SizedBox(width: 8),
            Text('Importando...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),

      VersionStatus.error => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.red.shade400),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => state.meta.localImport
                ? cubit.importFromFile(state.meta.code)
                : cubit.download(state.meta.code),
            child: const Text(
              'Reintentar',
              style: TextStyle(color: AppColors.accent, fontSize: 13),
            ),
          ),
        ],
      ),
    };
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(color: AppColors.accent, fontSize: 12),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              color: AppColors.accent,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Footer note ───────────────────────────────────────────────────────────────

class _ImportNote extends StatelessWidget {
  const _ImportNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Las versiones marcadas como "archivo local" requieren que importes tu propio archivo JSON en formato thiagobodruk/bible.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
