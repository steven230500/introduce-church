import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_dialog.dart';

/// Keyboard reference.
///
/// The shortcuts existed before but nothing in the interface said so, so nobody
/// used them. Reachable from the sidebar and from Shift + /.
Future<void> showShortcutsDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _ShortcutsDialog());
}

class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog();

  static const _groups = <String, List<(String, String)>>{
    'Avanzar slides': [
      ('→   ·   ↓   ·   Espacio', 'Siguiente slide'),
      ('←   ·   ↑', 'Slide anterior'),
      ('Inicio   ·   Fin', 'Primer o último slide del elemento'),
      ('1 … 9', 'Saltar a ese elemento del set list'),
    ],
    'Proyección': [
      ('L', 'Entrar o salir de vivo'),
      ('B', 'Pantalla negra'),
      ('Esc', 'Quitar la pantalla negra'),
    ],
    'Contenido': [('V', 'Versículo rápido: escribe "jn 3:16" y Enter')],
    'Buscar sin cortar': [
      ('K', 'Retener la pantalla, o volver a seguirte'),
      ('Enter', 'Enviar a la pantalla lo que estás viendo'),
    ],
    'Vista': [
      ('G', 'Alternar cuadrícula y slide grande'),
      ('F', 'Mostrar u ocultar la biblioteca'),
      ('Shift + /', 'Abrir esta ayuda'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Atajos de teclado',
      icon: Icons.keyboard_outlined,
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in _groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.sm),
              child: Text(entry.key.toUpperCase(), style: AppText.sectionLabel),
            ),
            for (final (keys, description) in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Row(
                  children: [
                    SizedBox(width: 150, child: _KeyCap(label: keys)),
                    const SizedBox(width: AppSpace.md),
                    Expanded(child: Text(description, style: AppText.body)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpace.sm),
          const Text(
            'Los atajos no se activan mientras escribes en un campo de texto.',
            style: AppText.rowSubtitle,
          ),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs + 1),
      decoration: BoxDecoration(
        color: AppColors.surfaceControl,
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
