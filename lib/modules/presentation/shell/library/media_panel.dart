import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/models/media_item.dart';
import '../../../../core/repositories/media_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/ui/app_buttons.dart';
import '../../../../core/widgets/ui/empty_state.dart';
import '../../children/control/presenter/cubit/cubit.dart';
import 'library_dock.dart';
import '../../../../l10n/l10n.dart';

/// Image and video library, backed by the organization's storage bucket.
class MediaPanel extends StatefulWidget {
  const MediaPanel({super.key});

  @override
  State<MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends State<MediaPanel> {
  late final MediaRepository _repo;
  List<MediaItem> _items = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  MediaType? _filter;

  @override
  void initState() {
    super.initState();
    _repo = Modular.get<MediaRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.listMedia();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().split('\n').first;
          _loading = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'mkv', 'm4v'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      for (final file in result.files) {
        if (file.path == null) continue;
        await _repo.upload(File(file.path!));
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().split('\n').first);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(MediaItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: L10n.of(context).mediaDeleteTitle,
      message: L10n.of(context).confirmDeleteNamed(item.name),
      confirmLabel: L10n.of(context).delete,
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok) return;
    await _repo.delete(item);
    await _load();
  }

  void _insert(MediaItem item) {
    final control = context.read<ControlCubit>();
    final state = control.state;
    if (state is! ControlLoadedState || state.model.activeCollection == null) {
      return;
    }
    if (item.mediaType.isImage) {
      control.addImageSlide(item.url, title: item.name);
    } else {
      control.importVideo(item.url);
    }
    showAddedToast(context, item.name);
  }

  List<MediaItem> get _filtered =>
      _filter == null ? _items : _items.where((i) => i.mediaType == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return DockPanel(
      toolbar: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _Filter(
                      label: L10n.of(context).mediaFilterAll,
                      active: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    _Filter(
                      label: L10n.of(context).mediaFilterImages,
                      active: _filter == MediaType.image,
                      onTap: () => setState(() => _filter = MediaType.image),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    _Filter(
                      label: L10n.of(context).mediaFilterVideos,
                      active: _filter == MediaType.video,
                      onTap: () => setState(() => _filter = MediaType.video),
                    ),
                  ],
                ),
              ),
              if (_uploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                AppIconButton(
                  icon: Icons.upload_rounded,
                  tooltip: L10n.of(context).mediaUploadFiles,
                  size: 28,
                  iconSize: 16,
                  onTap: _upload,
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: AppRadius.all(AppRadius.sm),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 11)),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : _filtered.isEmpty
          ? EmptyState(
              compact: true,
              icon: Icons.perm_media_outlined,
              title: L10n.of(context).mediaEmptyTitle,
              message: L10n.of(context).mediaEmptyMessage,
              actionLabel: L10n.of(context).mediaUpload,
              onAction: _upload,
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpace.sm,
                mainAxisSpacing: AppSpace.sm,
                childAspectRatio: 1,
              ),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _MediaTile(
                item: _filtered[i],
                onInsert: () => _insert(_filtered[i]),
                onDelete: () => _delete(_filtered[i]),
              ),
            ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs + 1),
        decoration: BoxDecoration(
          color: active ? AppColors.accentFillSoft : AppColors.surfaceControl,
          borderRadius: AppRadius.all(AppRadius.xs + 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.accent : AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _MediaTile extends StatefulWidget {
  const _MediaTile({required this.item, required this.onInsert, required this.onDelete});

  final MediaItem item;
  final VoidCallback onInsert;
  final VoidCallback onDelete;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onDoubleTap: widget.onInsert,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          decoration: BoxDecoration(
            color: AppColors.surfaceControl,
            borderRadius: AppRadius.all(AppRadius.md),
            border: Border.all(color: _hovering ? AppColors.accent : AppColors.divider),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.all(AppRadius.md - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.mediaType.isImage)
                  Image.network(
                    item.url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const _Placeholder(),
                  )
                else
                  const _Placeholder(icon: Icons.play_circle_outline_rounded),

                // Name strip, always readable over the thumbnail.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm - 2,
                      vertical: AppSpace.xs + 1,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.scrim],
                      ),
                    ),
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                if (_hovering) ...[
                  Positioned(
                    top: AppSpace.xs,
                    left: AppSpace.xs,
                    child: AddToSetListButton(size: 24, onAdd: widget.onInsert),
                  ),
                  Positioned(
                    top: AppSpace.xs,
                    right: AppSpace.xs,
                    child: Tooltip(
                      message: L10n.of(context).mediaDeleteFromLibrary,
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.icon = Icons.image_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surfaceControl,
    child: Center(child: Icon(icon, size: 26, color: AppColors.textDisabled)),
  );
}
