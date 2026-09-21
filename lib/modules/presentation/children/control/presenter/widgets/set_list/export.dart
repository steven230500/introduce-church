part of '../../page.dart';

// ── Export set list ───────────────────────────────────────────────────────────

Future<void> _exportSetList(BuildContext context, Collection collection) async {
  final t = L10n.of(context);
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

  var number = 0;
  for (var i = 0; i < collection.items.length; i++) {
    final item = collection.items[i];

    // A moment heads the list it opens rather than taking a number of its own,
    // the way it reads on the screen.
    if (item.isSection) {
      buf.writeln();
      buf.writeln('── ${item.titleIn(t).toUpperCase()} ──');
      buf.writeln();
      continue;
    }

    number++;
    buf.writeln('$number. ${item.titleIn(t).toUpperCase()}  [${item.type.labelIn(t)}]');

    switch (item.type) {
      case CollectionItemType.section:
        break;
      case CollectionItemType.song:
        if (item.song?.author != null) buf.writeln('   ${item.song!.author}');
        buf.writeln('   $dash');
        for (final verse in item.song?.verses ?? []) {
          buf.writeln('   ${verse.type.labelIn(t)}:');
          for (final line in verse.content.split('\n')) {
            buf.writeln('   $line');
          }
          if (verse.chords?.isNotEmpty == true) {
            buf.writeln('   [${t.printChords(verse.chords!)}]');
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
          buf.writeln('   [${t.announcementWithCountdown}]');
        }
        buf.writeln();
      case CollectionItemType.imageSlide:
      case CollectionItemType.videoSlide:
        buf.writeln();
    }
  }

  buf.writeln(sep);
  buf.writeln(t.printTotal(collection.playableCount));
  buf.writeln(sep);

  try {
    final docs = p.join(homeDirectory(), 'Documents');
    final safeName = collection.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final path = p.join(docs, 'introduce_${date}_$safeName.txt');
    await Directory(docs).create(recursive: true);
    await File(path).writeAsString(buf.toString());
    await openWithSystem(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.printExported('introduce_${date}_$safeName.txt')),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.printExportFailed('$e')),
          backgroundColor: const Color(0xFFFF453A),
        ),
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
      SnackBar(
        content: Text(t.openFailed(e is ServiceFileError ? e.describeIn(t) : errorText(t, e))),
        backgroundColor: AppColors.danger,
      ),
    );
  }
}
