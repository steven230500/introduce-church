import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import 'package:path/path.dart' as p;

import '../../../core/history/projection_event.dart';
import '../../../core/history/projection_recorder.dart';
import '../../../core/history/projection_report.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../l10n/l10n.dart';

/// What the church put on its screen, read two ways.
///
/// As services, for "what did we sing last Sunday". As a song report, for the
/// licence paperwork that asks which songs were projected and how often.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.repository, this.now});

  /// Injected by tests.
  final HistoryRepository? repository;
  final DateTime Function()? now;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

enum HistoryRange { week, month, quarter, year }

extension on HistoryRange {
  Duration get span => switch (this) {
    HistoryRange.week => const Duration(days: 7),
    HistoryRange.month => const Duration(days: 31),
    HistoryRange.quarter => const Duration(days: 92),
    HistoryRange.year => const Duration(days: 365),
  };

  String label(L10n t) => switch (this) {
    HistoryRange.week => t.historyRangeWeek,
    HistoryRange.month => t.historyRangeMonth,
    HistoryRange.quarter => t.historyRangeQuarter,
    HistoryRange.year => t.historyRangeYear,
  };
}

class _HistoryPageState extends State<HistoryPage> {
  late final _repository = widget.repository ?? Modular.get<HistoryRepository>();
  DateTime _now() => (widget.now ?? DateTime.now)();

  // A quarter by default: it covers "last Sunday" and it is the period most
  // licence reports ask for, so neither view opens on the wrong window.
  var _range = HistoryRange.quarter;
  var _showLicences = false;

  List<ProjectionEvent>? _events;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _events = null;
      _failure = null;
    });
    final to = _now();
    try {
      final events = await _repository.between(to.subtract(_range.span), to);
      if (mounted) setState(() => _events = events);
    } catch (e) {
      if (mounted) setState(() => _failure = '$e');
    }
  }

  Future<void> _exportCsv(List<SongUse> rows) async {
    final t = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final to = _now();
    final from = to.subtract(_range.span);
    String stamp(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

    final path = await FilePicker.platform.saveFile(
      dialogTitle: t.historyExportCsv,
      fileName: 'licencias_${stamp(from)}_${stamp(to)}.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (path == null) return;

    await File(path).writeAsString(
      songReportCsv(
        rows,
        headers: [t.csvTitle, t.csvAuthor, t.csvCopyright, t.csvLicence, t.csvUses, t.csvDates],
      ),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.historyExported(p.basename(path))),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final events = _events;

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            t: t,
            range: _range,
            showLicences: _showLicences,
            onRange: (range) {
              setState(() => _range = range);
              _load();
            },
            onView: (licences) => setState(() => _showLicences = licences),
            onExport: events == null || !_showLicences
                ? null
                : () => _exportCsv(songReport(events)),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch ((events, _failure)) {
              (_, final String failure) => _Message(
                icon: Icons.cloud_off_rounded,
                title: t.historyLoadFailed(failure),
              ),
              (null, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              (final List<ProjectionEvent> list, _) when list.isEmpty => _Message(
                icon: Icons.history_rounded,
                title: t.historyEmpty,
                body: t.historyEmptyBody,
              ),
              (final List<ProjectionEvent> list, _) =>
                _showLicences
                    ? _LicenceReport(rows: songReport(list), t: t)
                    : _ServiceList(services: servicesFrom(list), t: t),
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.t,
    required this.range,
    required this.showLicences,
    required this.onRange,
    required this.onView,
    required this.onExport,
  });

  final L10n t;
  final HistoryRange range;
  final bool showLicences;
  final ValueChanged<HistoryRange> onRange;
  final ValueChanged<bool> onView;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.md),
      child: Wrap(
        spacing: AppSpace.md,
        runSpacing: AppSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(t.historyTitle, style: AppText.pageTitle),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(t.historyServices)),
              ButtonSegment(value: true, label: Text(t.historyLicences)),
            ],
            selected: {showLicences},
            onSelectionChanged: (choice) => onView(choice.first),
          ),
          DropdownButton<HistoryRange>(
            value: range,
            underline: const SizedBox.shrink(),
            dropdownColor: AppColors.surfaceControl,
            items: [
              for (final option in HistoryRange.values)
                DropdownMenuItem(value: option, child: Text(option.label(t))),
            ],
            onChanged: (value) {
              if (value != null) onRange(value);
            },
          ),
          if (showLicences)
            FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.table_view_outlined, size: 16),
              label: Text(t.historyExportCsv),
            ),
        ],
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.services, required this.t});

  final List<ServiceHistory> services;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.xl),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.lg),
      itemBuilder: (context, index) {
        final service = services[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.all(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  AppSpace.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.collectionName.isEmpty ? '—' : service.collectionName,
                        style: AppText.rowTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_date(service.day, locale)}  ·  '
                      '${_time(service.startedAt)}–${_time(service.endedAt)}  ·  '
                      '${t.historyItems(service.events.length)}',
                      style: AppText.rowSubtitle,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final event in service.events) _EventRow(event: event),
            ],
          ),
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final ProjectionEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _time(event.startedAt),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Icon(_iconFor(event.itemType), size: 15, color: AppColors.textTertiary),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(event.title, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
          ),
          if (event.songAuthor?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.md),
              child: Text(event.songAuthor!, style: AppText.rowSubtitle),
            ),
          SizedBox(
            width: 56,
            child: Text(
              _duration(event.duration),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenceReport extends StatelessWidget {
  const _LicenceReport({required this.rows, required this.t});

  final List<SongUse> rows;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _Message(icon: Icons.music_off_outlined, title: t.historyNoSongs);
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        Text(
          '${t.historySongsUsed(rows.length)}  ·  ${t.historyLicenceNote}',
          style: AppText.rowSubtitle,
        ),
        const SizedBox(height: AppSpace.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.all(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (final (index, row) in rows.indexed) ...[
                if (index > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg,
                    vertical: AppSpace.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.title, style: AppText.rowTitle),
                            Text(
                              [
                                if (row.author?.isNotEmpty == true) row.author!,
                                row.ccliNumber?.isNotEmpty == true
                                    ? 'CCLI ${row.ccliNumber}'
                                    : t.historyNoLicence,
                              ].join('  ·  '),
                              style: AppText.rowSubtitle,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        t.historyUses(row.uses),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.textDisabled),
          const SizedBox(height: AppSpace.md),
          Text(title, textAlign: TextAlign.center, style: AppText.rowTitle),
          if (body != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(body!, textAlign: TextAlign.center, style: AppText.rowSubtitle),
          ],
        ],
      ),
    ),
  );
}

IconData _iconFor(String type) => switch (type) {
  'song' => Icons.music_note_outlined,
  'bible_verse' => Icons.menu_book_outlined,
  'sermon' => Icons.mic_none_outlined,
  'image_slide' => Icons.image_outlined,
  'video_slide' => Icons.movie_outlined,
  'announcement' => Icons.campaign_outlined,
  _ => Icons.text_snippet_outlined,
};

String _time(DateTime moment) {
  final local = moment.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _duration(Duration span) {
  final minutes = span.inMinutes;
  final seconds = span.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// A day the way people say it, in the app's language.
String _date(DateTime day, String locale) {
  const es = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final months = locale.startsWith('en') ? en : es;
  return locale.startsWith('en')
      ? '${months[day.month - 1]} ${day.day}, ${day.year}'
      : '${day.day} ${months[day.month - 1]} ${day.year}';
}
