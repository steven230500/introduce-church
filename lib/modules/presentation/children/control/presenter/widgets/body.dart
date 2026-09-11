part of '../page.dart';

/// Three columns: the plan, the output, and what comes next.
class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      builder: (context, state) => switch (state) {
        ControlLoadingState() => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        ControlErrorState(:final message) => ErrorStateView(
          message: message,
          onRetry: context.read<ControlCubit>().load,
        ),
        ControlLoadedState(:final model) => Row(
          children: [
            _SetListPanel(model: model),
            const VerticalDivider(width: 1, color: AppColors.divider),
            Expanded(child: _SlidePreview(model: model)),
            const VerticalDivider(width: 1, color: AppColors.divider),
            // The right column always mirrors the projector in some form:
            // the slide queue when the big preview is centre stage, the
            // output panel when the grid is.
            if (model.gridView) _SidePreviewPanel(model: model) else _SlideQueue(model: model),
          ],
        ),
      },
    );
  }
}
