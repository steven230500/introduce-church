import 'package:flutter/material.dart';

import '../../../../core/services/locale_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/ui/flag.dart';
import '../../../../core/widgets/ui/hover_builder.dart';
import '../../../../l10n/l10n.dart';

/// The first thing a new computer shows: which language the app speaks.
///
/// Asked before sign-in because everything after it is words. Every line here
/// is written in both languages at once, each in its own - somebody who reads
/// only one of them has to be able to find their button without guessing.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key, required this.controller, required this.onChosen});

  final LocaleController controller;
  final VoidCallback onChosen;

  Future<void> _choose(Locale locale) async {
    await controller.choose(locale);
    onChosen();
  }

  @override
  Widget build(BuildContext context) {
    final languages = [
      for (final locale in LocaleController.supported) (locale, lookupL10n(locale)),
    ];

    return Scaffold(
      backgroundColor: AppColors.chrome,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/casavida-isologo-white.png', width: 96),
                const SizedBox(height: AppSpace.xl * 2),
                for (final (_, strings) in languages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: Text(
                      strings.languagePickTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpace.xl),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpace.lg,
                  runSpacing: AppSpace.lg,
                  children: [
                    for (final (locale, strings) in languages)
                      _LanguageCard(
                        flag: Flag.forLanguage(locale.languageCode),
                        name: strings.languageName,
                        caption: strings.languagePickCaption,
                        onTap: () => _choose(locale),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                for (final (_, strings) in languages)
                  Text(
                    strings.languagePickLater,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.flag,
    required this.name,
    required this.caption,
    required this.onTap,
  });

  final String flag;
  final String name;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovering) => GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: hovering ? 1.03 : 1,
          duration: AppMotion.normal,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            width: 220,
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xxl, AppSpace.lg, AppSpace.xl),
            decoration: BoxDecoration(
              color: hovering ? AppColors.surfaceRaised : AppColors.surface,
              borderRadius: AppRadius.all(AppRadius.xl),
              border: Border.all(
                color: hovering ? AppColors.accent : AppColors.border,
                width: hovering ? 1.5 : 1,
              ),
              boxShadow: [
                if (hovering)
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Column(
              children: [
                Flag(country: flag, width: 96, radius: 8),
                const SizedBox(height: AppSpace.xl),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
