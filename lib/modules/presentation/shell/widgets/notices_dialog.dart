import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;

import '../../../../core/models/saved_notice.dart';
import '../../../../core/repositories/organization_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../children/control/presenter/cubit/cubit.dart';

/// Everything an operator says in the middle of a service.
///
/// Two audiences, one place: a notice over the slide, which everyone reads,
/// and a line for the platform, which nobody in the pews sees. They were
/// separate ideas before, and only the first one existed.
Future<void> showNoticesDialog(BuildContext context, {OrganizationRepository? repository}) {
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<ControlCubit>(),
      child: NoticesDialog(repository: repository),
    ),
  );
}

@visibleForTesting
class NoticesDialog extends StatefulWidget {
  const NoticesDialog({super.key, this.repository});

  /// Injected by tests. In the app it comes from the injector.
  final OrganizationRepository? repository;

  @override
  State<NoticesDialog> createState() => _NoticesDialogState();
}

class _NoticesDialogState extends State<NoticesDialog> {
  late final _repository = widget.repository ?? Modular.get<OrganizationRepository>();
  final _screen = TextEditingController();
  final _stage = TextEditingController();

  List<SavedNotice> _saved = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final model = context.read<ControlCubit>().state;
    if (model is ControlLoadedState) {
      _screen.text = model.model.overlayText ?? '';
      _stage.text = model.model.stageMessage ?? '';
    }
    _load();
  }

  Future<void> _load() async {
    final notices = await _repository.getNotices();
    if (!mounted) return;
    setState(() {
      _saved = notices;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _screen.dispose();
    _stage.dispose();
    super.dispose();
  }

  Future<void> _remember() async {
    final text = _screen.text.trim();
    if (text.isEmpty || _saved.any((n) => n.text == text)) return;
    final next = [..._saved, SavedNotice(text: text)];
    setState(() => _saved = next);
    final stored = await _repository.setNotices(next);
    if (mounted) setState(() => _saved = stored);
  }

  Future<void> _forget(SavedNotice notice) async {
    final next = [..._saved]..remove(notice);
    setState(() => _saved = next);
    final stored = await _repository.setNotices(next);
    if (mounted) setState(() => _saved = stored);
  }

  Future<void> _setHide(SavedNotice notice, int seconds) async {
    final next = [
      for (final n in _saved)
        if (n == notice) SavedNotice(text: n.text, autoHideSecs: seconds) else n,
    ];
    setState(() => _saved = next);
    final stored = await _repository.setNotices(next);
    if (mounted) setState(() => _saved = stored);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ControlCubit>();
    final model = context.select<ControlCubit, ControlModel?>(
      (c) => c.state is ControlLoadedState ? (c.state as ControlLoadedState).model : null,
    );
    final showing = model?.overlayVisible ?? false;

    return AppDialog(
      title: 'Avisos',
      icon: Icons.campaign_outlined,
      width: 480,
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(
            icon: Icons.tv_rounded,
            title: 'EN LA PANTALLA',
            subtitle: 'Sobre el slide. Lo lee toda la congregación.',
          ),
          const SizedBox(height: AppSpace.sm),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Text('Cargando los avisos guardados...', style: AppText.rowSubtitle),
            )
          else if (_saved.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.sm),
              child: Text(
                'Todavía no hay avisos guardados. Escribe uno y presiona el marcador '
                'para tenerlo listo la próxima.',
                style: AppText.rowSubtitle,
              ),
            )
          else
            for (final notice in _saved)
              _SavedRow(
                notice: notice,
                onShow: () {
                  cubit.showOverlay(notice.text, autoHideSecs: notice.autoHideSecs);
                  Navigator.pop(context);
                },
                onForget: () => _forget(notice),
                onSetHide: (s) => _setHide(notice, s),
              ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _screen,
                  hintText: 'Escribe un aviso...',
                  onSubmitted: (v) => _showTyped(cubit, v),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Tooltip(
                message: 'Guardar para la próxima',
                child: IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  onPressed: _remember,
                ),
              ),
              FilledButton(
                onPressed: () => _showTyped(cubit, _screen.text),
                child: const Text('Mostrar'),
              ),
            ],
          ),
          if (showing) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.live),
                const SizedBox(width: AppSpace.sm - 2),
                Expanded(
                  child: Text(
                    'En pantalla ahora: ${model?.overlayText ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowSubtitle,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    cubit.hideOverlay();
                    Navigator.pop(context);
                  },
                  child: const Text('Quitar'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpace.lg),
          const _Heading(
            icon: Icons.co_present_outlined,
            title: 'SOLO AL ESCENARIO',
            subtitle: 'Lo ve el equipo en el monitor. La congregación no.',
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _stage,
                  hintText: 'Quedan 5 minutos',
                  onSubmitted: (v) => _sendToStage(cubit, v),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              if ((model?.stageMessage ?? '').isNotEmpty)
                TextButton(
                  onPressed: () {
                    cubit.setStageMessage(null);
                    _stage.clear();
                    setState(() {});
                  },
                  child: const Text('Quitar'),
                ),
              FilledButton(
                onPressed: () => _sendToStage(cubit, _stage.text),
                child: const Text('Enviar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTyped(ControlCubit cubit, String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    cubit.showOverlay(text);
    Navigator.pop(context);
  }

  void _sendToStage(ControlCubit cubit, String value) {
    cubit.setStageMessage(value);
    Navigator.pop(context);
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.sectionLabel),
              Text(subtitle, style: AppText.rowSubtitle),
            ],
          ),
        ),
      ],
    );
  }
}

/// One saved notice: press it to show it, or change how long it stays.
class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.notice,
    required this.onShow,
    required this.onForget,
    required this.onSetHide,
  });

  final SavedNotice notice;
  final VoidCallback onShow;
  final VoidCallback onForget;
  final ValueChanged<int> onSetHide;

  static const _durations = [0, 5, 10, 20, 30];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm - 3),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onShow,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceControl,
                    borderRadius: AppRadius.all(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 15, color: AppColors.accent),
                      const SizedBox(width: AppSpace.sm - 2),
                      Expanded(
                        child: Text(
                          notice.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.rowTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm - 3),
          Tooltip(
            message: 'Cuánto se queda en pantalla',
            child: PopupMenuButton<int>(
              tooltip: '',
              color: AppColors.surfaceControl,
              itemBuilder: (_) => [
                for (final seconds in _durations)
                  PopupMenuItem(
                    value: seconds,
                    height: 34,
                    child: Text(
                      seconds == 0 ? 'Hasta quitarlo' : '$seconds segundos',
                      style: AppText.body,
                    ),
                  ),
              ],
              onSelected: onSetHide,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.all(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  notice.hides ? '${notice.autoHideSecs}s' : '∞',
                  style: AppText.rowSubtitle,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Quitar de los avisos guardados',
            icon: const Icon(Icons.close, size: 15, color: AppColors.textDisabled),
            onPressed: onForget,
          ),
        ],
      ),
    );
  }
}
