import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../../core/services/service_file.dart';
import '../../../../../l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show Modular;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../../../../../core/models/collection.dart';
import '../../../../../core/models/collection_item_type.dart';
import '../../../../../core/models/slide_template.dart';
import '../../../../../core/repositories/template_repository.dart';
import '../../../../../core/services/pptx_import_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/free_slide_dialog.dart';
import '../../../../../core/widgets/slide_transition_view.dart';
import '../../../../../core/widgets/slide_view.dart';
import '../../../../../core/widgets/template_picker/template_picker_dialog.dart';
import '../../../../../core/widgets/ui/app_buttons.dart';
import '../../../../../core/widgets/ui/empty_state.dart';
import '../../../../../core/widgets/ui/hover_builder.dart';
import '../../../../../core/widgets/ui/page_header.dart';
import '../../../../../core/widgets/ui/panel_resizer.dart';
import '../../../shell/shell_cubit.dart';
import '../../../shell/widgets/collection_dialog.dart';
import '../../../shell/widgets/quick_verse_dialog.dart';
import 'cubit/cubit.dart';

part 'widgets/body.dart';
part 'widgets/set_list/panel.dart';
part 'widgets/set_list/add_menu.dart';
part 'widgets/set_list/importers.dart';
part 'widgets/set_list/items.dart';
part 'widgets/set_list/export.dart';
part 'widgets/slide_preview.dart';
part 'widgets/slide_queue.dart';
part 'widgets/up_next.dart';

/// The presenter workspace: set list, live preview, slide queue.
///
/// Deliberately has no Scaffold, no toolbar and no key handling of its own.
/// The shell owns all three so they keep working in every section.
class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: AppColors.canvas, child: _Body());
  }
}
