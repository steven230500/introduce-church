import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../models/media_item.dart';
import '../../repositories/media_repository.dart';
import '../app_dialog.dart';
import '../../../core/theme/app_colors.dart';

Future<MediaItem?> showMediaLibraryDialog(BuildContext context) {
  return showDialog<MediaItem>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => const _MediaLibraryDialog(),
  );
}

class _MediaLibraryDialog extends StatefulWidget {
  const _MediaLibraryDialog();

  @override
  State<_MediaLibraryDialog> createState() => _MediaLibraryDialogState();
}

class _MediaLibraryDialogState extends State<_MediaLibraryDialog> {
  late final MediaRepository _repo;
  List<MediaItem> _items = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String _filter = 'all'; // 'all' | 'image' | 'video'

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
          _error = e.toString();
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
      for (final pf in result.files) {
        if (pf.path == null) continue;
        await _repo.upload(File(pf.path!));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al subir: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(MediaItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar media',
      message: '¿Eliminar "${item.name}"?',
      confirmLabel: 'Eliminar',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok) return;
    try {
      await _repo.delete(item);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    }
  }

  List<MediaItem> get _filtered =>
      _filter == 'all' ? _items : _items.where((i) => i.mediaType.value == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 780,
        height: 560,
        child: Column(
          children: [
            _Header(
              uploading: _uploading,
              filter: _filter,
              onFilterChange: (f) => setState(() => _filter = f),
              onUpload: _upload,
              onClose: () => Navigator.pop(context),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
                ),
              ),
            Expanded(
              child: _Body(
                loading: _loading,
                items: _filtered,
                onSelect: (item) => Navigator.pop(context, item),
                onDelete: _delete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.uploading,
    required this.filter,
    required this.onFilterChange,
    required this.onUpload,
    required this.onClose,
  });

  final bool uploading;
  final String filter;
  final ValueChanged<String> onFilterChange;
  final VoidCallback onUpload;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          Image.asset(
            'assets/images/casavida-isologo-white.png',
            height: 18,
            opacity: const AlwaysStoppedAnimation(0.55),
          ),
          const SizedBox(width: 10),
          const Text(
            'Biblioteca de Media',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          _FilterChip(label: 'Todo', value: 'all', current: filter, onTap: onFilterChange),
          const SizedBox(width: 6),
          _FilterChip(label: 'Imágenes', value: 'image', current: filter, onTap: onFilterChange),
          const SizedBox(width: 6),
          _FilterChip(label: 'Videos', value: 'video', current: filter, onTap: onFilterChange),
          const Spacer(),
          if (uploading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            )
          else
            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_outlined, size: 14),
              label: const Text('Subir', style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surfaceControl,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : AppColors.textTertiary, fontSize: 12),
        ),
      ),
    );
  }
}

// ── Body / grid ───────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.loading,
    required this.items,
    required this.onSelect,
    required this.onDelete,
  });

  final bool loading;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onSelect;
  final ValueChanged<MediaItem> onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.perm_media_outlined, size: 48, color: AppColors.border),
            SizedBox(height: 12),
            Text(
              'Sin media — sube imágenes o videos',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _MediaTile(
          item: items[i],
          onSelect: () => onSelect(items[i]),
          onDelete: () => onDelete(items[i]),
        ),
      ),
    );
  }
}

class _MediaTile extends StatefulWidget {
  const _MediaTile({required this.item, required this.onSelect, required this.onDelete});

  final MediaItem item;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceControl,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hovered ? AppColors.accent : Colors.transparent, width: 2),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: item.mediaType.isImage
                    ? Image.network(
                        item.url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, _, _) => const _VideoIcon(),
                      )
                    : const _VideoIcon(),
              ),
              // Bottom label
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                  ),
                  child: Text(
                    item.name,
                    style: const TextStyle(color: Colors.white, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Delete button on hover
              if (_hovered)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              // Insert badge on hover
              if (_hovered)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Insertar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoIcon extends StatelessWidget {
  const _VideoIcon();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.border,
      child: Center(child: Icon(Icons.play_circle_outline, size: 36, color: AppColors.textMuted)),
    );
  }
}
