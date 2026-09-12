import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_dimens.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Introduce Church',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
          error: Color(0xFFFF453A),
          onSurface: Colors.white,
          outline: AppColors.border,
          surfaceContainerHighest: AppColors.surfaceControl,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceControl,
          hintStyle: const TextStyle(color: AppColors.textDisabled),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.textTertiary),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        // Material's default snackbar is a light card. In a dark booth app it
        // reads as something from another program, and the undo it carries is
        // the one control an operator has to find in a hurry.
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceControl,
          contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          actionTextColor: AppColors.accentLight,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        dividerColor: AppColors.border,
        dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: AppColors.textTertiary,
        ),
      ),
      routerConfig: Modular.routerConfig,
    );
  }
}
