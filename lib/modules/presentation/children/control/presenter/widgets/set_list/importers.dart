part of '../../page.dart';

// Everything that pulls set list content out of a file on disk.

Future<void> _importPptx(BuildContext context, ControlCubit cubit) async {
  await Future.delayed(const Duration(milliseconds: 250));
  if (!context.mounted) return;

  final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
  final path = result?.files.firstOrNull?.path;
  if (path == null || !context.mounted) return;

  if (!path.toLowerCase().endsWith('.pptx')) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10n.of(context).importPickPptx),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }

  // Extract first so we know slide count before showing dialog
  final slides = await PptxImportService().extractSlides(path);
  if (!context.mounted) return;

  if (slides.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.of(context).importPptxNoText), duration: Duration(seconds: 3)),
    );
    return;
  }

  // Show pre-import dialog: slide count + template picker
  final templateId = await showDialog<_PptxImportChoice>(
    context: context,
    builder: (_) => _PptxImportDialog(slideCount: slides.length),
  );
  if (templateId == null || !context.mounted) return; // cancelled

  final count = await cubit.importPptx(path, templateId: templateId.templateId);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10n.of(context).importPptxDone(count)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

Future<void> _importPptxAsImages(BuildContext context, ControlCubit cubit) async {
  await Future.delayed(const Duration(milliseconds: 250));
  if (!context.mounted) return;

  final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
  final path = result?.files.firstOrNull?.path;
  if (path == null || !context.mounted) return;

  if (!path.toLowerCase().endsWith('.pptx')) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10n.of(context).importPickPptx),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final t = L10n.of(context);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AppDialog(
      title: t.importPptxConverting,
      icon: Icons.slideshow_outlined,
      showClose: false,
      width: 320,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
            ),
            SizedBox(width: 16),
            Text(t.importPptxConvertingBody, style: TextStyle(color: kTextSecondary, fontSize: 13)),
          ],
        ),
      ),
    ),
  );

  try {
    final count = await cubit.importPptxAsImages(path);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(count > 0 ? t.importPptxImagesDone(count) : t.importPptxImagesFailed),
        duration: const Duration(seconds: 4),
      ),
    );
  } catch (e) {
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(t.errorWith('$e')), duration: const Duration(seconds: 5)),
    );
  }
}

// Holds the result of the pre-import dialog
class _PptxImportChoice {
  const _PptxImportChoice({this.templateId});
  final String? templateId; // null = use collection template
}

class _PptxImportDialog extends StatefulWidget {
  const _PptxImportDialog({required this.slideCount});
  final int slideCount;

  @override
  State<_PptxImportDialog> createState() => _PptxImportDialogState();
}

class _PptxImportDialogState extends State<_PptxImportDialog> {
  String? _selectedTemplateId; // null = colección

  @override
  Widget build(BuildContext context) {
    final presets = SlideTemplate.presets;

    return AppDialog(
      title: L10n.of(context).importPptxTitle,
      icon: Icons.slideshow_outlined,
      width: 380,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).cancel)),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _PptxImportChoice(templateId: _selectedTemplateId)),
          child: Text(L10n.of(context).importPptxAction(widget.slideCount)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.of(context).importPptxFound(widget.slideCount),
            style: const TextStyle(color: kTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Text(
            L10n.of(context).importPptxDesign,
            style: TextStyle(color: kTextSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: kDialogSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kDialogBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedTemplateId,
                isExpanded: true,
                dropdownColor: kDialogSurface,
                style: const TextStyle(color: kTextPrimary, fontSize: 13),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(L10n.of(context).importPptxUseCollectionDesign),
                  ),
                  ...presets.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                ],
                onChanged: (v) => setState(() => _selectedTemplateId = v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _importVideo(BuildContext context, ControlCubit cubit) async {
  await Future.delayed(const Duration(milliseconds: 250));
  if (!context.mounted) return;

  final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false);
  final path = result?.files.firstOrNull?.path;
  if (path == null || !context.mounted) return;

  await cubit.importVideo(path);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.of(context).videoAdded), duration: const Duration(seconds: 2)),
    );
  }
}

const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.heic'};
const _videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.m4v', '.wmv', '.webm'};

Future<void> _importFolder(BuildContext context, ControlCubit cubit) async {
  await Future.delayed(const Duration(milliseconds: 250));
  if (!context.mounted) return;

  final dirPath = await FilePicker.platform.getDirectoryPath();
  if (dirPath == null || !context.mounted) return;

  final dir = Directory(dirPath);
  final allFiles = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  final images = allFiles
      .where((f) => _imageExts.contains(p.extension(f.path).toLowerCase()))
      .map((f) => f.path)
      .toList();
  final videos = allFiles
      .where((f) => _videoExts.contains(p.extension(f.path).toLowerCase()))
      .map((f) => f.path)
      .toList();

  if (images.isEmpty && videos.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).folderNothingFound),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _FolderImportDialog(
      folderName: p.basename(dirPath),
      imageCount: images.length,
      videoCount: videos.length,
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final folderTitle = p.basename(dirPath);
  final result = await cubit.importFolder(
    folderTitle: folderTitle,
    imagePaths: images,
    videoPaths: videos,
  );

  if (context.mounted) {
    final parts = <String>[];
    if (result.images > 0) parts.add(L10n.of(context).folderImages(images.length));
    if (result.videos > 0) parts.add(L10n.of(context).folderVideos(result.videos));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10n.of(context).folderImported(parts.join(' • '))),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _FolderImportDialog extends StatelessWidget {
  const _FolderImportDialog({
    required this.folderName,
    required this.imageCount,
    required this.videoCount,
  });

  final String folderName;
  final int imageCount;
  final int videoCount;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: L10n.of(context).folderImportTitle,
      icon: Icons.folder_open_outlined,
      width: 360,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(L10n.of(context).cancel),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(L10n.of(context).import),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open_outlined, size: 14, color: kTextSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  folderName,
                  style: const TextStyle(color: kTextSecondary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (imageCount > 0)
            _CountRow(
              icon: Icons.image_outlined,
              label: L10n.of(context).folderImages(imageCount),
              note: L10n.of(context).folderAsPresentation,
            ),
          if (imageCount > 0 && videoCount > 0) const SizedBox(height: 8),
          if (videoCount > 0)
            _CountRow(
              icon: Icons.video_file_outlined,
              label: L10n.of(context).folderVideos(videoCount),
              note: L10n.of(context).folderSeparateItems(videoCount),
            ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.icon, required this.label, required this.note});

  final IconData icon;
  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
            Text(note, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
