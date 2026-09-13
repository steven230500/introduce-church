part of '../../page.dart';

// ── Export set list ───────────────────────────────────────────────────────────

Future<void> _exportSetList(BuildContext context, Collection collection) async {
  final buf = StringBuffer();
  final sep = '═' * 50;
  final dash = '─' * 50;

  buf.writeln(sep);
  buf.writeln('INTRODUCE — SET LIST');
  buf.writeln(collection.name);
  if (collection.serviceDate != null) {
    final d = collection.serviceDate!;
    buf.writeln('${d.day}/${d.month}/${d.year}');
  }
  buf.writeln(sep);
  buf.writeln();

  for (var i = 0; i < collection.items.length; i++) {
    final item = collection.items[i];
    buf.writeln('${i + 1}. ${item.displayTitle.toUpperCase()}  [${item.type.label}]');

    switch (item.type) {
      case CollectionItemType.song:
        if (item.song?.author != null) buf.writeln('   ${item.song!.author}');
        buf.writeln('   $dash');
        for (final verse in item.song?.verses ?? []) {
          buf.writeln('   ${verse.type.label}:');
          for (final line in verse.content.split('\n')) {
            buf.writeln('   $line');
          }
          if (verse.chords?.isNotEmpty == true) {
            buf.writeln('   [Acordes: ${verse.chords}]');
          }
          buf.writeln();
        }
      case CollectionItemType.bibleVerse:
        for (final slide in item.slides) {
          buf.writeln('   $slide');
        }
        buf.writeln();
      case CollectionItemType.sermon:
        final points = List<String>.from(item.contentJson?['points'] as List? ?? []);
        for (var p = 0; p < points.length; p++) {
          buf.writeln('   ${p + 1}. ${points[p]}');
        }
        buf.writeln();
      case CollectionItemType.freeSlide:
        final text = item.contentJson?['text'] as String? ?? '';
        for (final line in text.split('\n')) {
          buf.writeln('   $line');
        }
        buf.writeln();
      case CollectionItemType.announcement:
        final msg = item.contentJson?['message'] as String? ?? '';
        if (msg.isNotEmpty) buf.writeln('   $msg');
        if (item.contentJson?['timerTarget'] != null) {
          buf.writeln('   [Con cuenta regresiva]');
        }
        buf.writeln();
      case CollectionItemType.imageSlide:
      case CollectionItemType.videoSlide:
        buf.writeln();
    }
  }

  buf.writeln(sep);
  buf.writeln('Total: ${collection.items.length} elementos');
  buf.writeln(sep);

  try {
    final home = Platform.environment['HOME'] ?? '';
    final docs = '$home/Documents';
    final safeName = collection.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final path = '$docs/introduce_${date}_$safeName.txt';
    await File(path).writeAsString(buf.toString());
    await Process.run('open', [path]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exportado: introduce_${date}_$safeName.txt'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e'), backgroundColor: const Color(0xFFFF453A)),
      );
    }
  }
}

// ── A service as a file ───────────────────────────────────────────────────────
//
// Different from the printable sheet above, which is for a music stand. This
// one is for another machine: a backup, a move from the rehearsal laptop to the
// booth, a second campus running the same plan.

Future<void> _saveServiceFile(BuildContext context, Collection collection) async {
  final t = L10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final cubit = context.read<ControlCubit>();
  final suggested = serviceFileName(collection.name, on: collection.serviceDate);

  final path = await FilePicker.platform.saveFile(
    dialogTitle: t.saveAsFile,
    fileName: suggested,
    type: FileType.custom,
    allowedExtensions: const [kServiceFileExtension],
  );
  if (path == null) return;

  try {
    await File(path).writeAsString(cubit.exportService(collection));
    messenger.showSnackBar(
      SnackBar(content: Text(t.serviceSaved(p.basename(path))), backgroundColor: AppColors.success),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(t.saveFailed('$e')), backgroundColor: AppColors.danger),
    );
  }
}

Future<void> _openServiceFile(BuildContext context) async {
  final t = L10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final cubit = context.read<ControlCubit>();

  final picked = await FilePicker.platform.pickFiles(
    dialogTitle: t.openFromFile,
    type: FileType.custom,
    allowedExtensions: const [kServiceFileExtension, 'json'],
  );
  final path = picked?.files.singleOrNull?.path;
  if (path == null) return;

  try {
    final result = await cubit.importService(await File(path).readAsString());
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          t.serviceOpened(result.name, result.items) +
              t.importedSongs(result.newSongs) +
              t.importedMissingMedia(result.missingMedia),
        ),
        backgroundColor: result.missingMedia == 0 ? AppColors.success : AppColors.warning,
        duration: const Duration(seconds: 6),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(t.openFailed('$e')), backgroundColor: AppColors.danger),
    );
  }
}
