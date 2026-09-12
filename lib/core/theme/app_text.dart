import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Type scale. Five roles, each with one job. Picking a size outside this list
/// is what made every panel header a different height, so don't.
abstract final class AppText {
  /// Page title in a library view.
  static const pageTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Header of a panel inside the presenter.
  static const panelTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Primary row text: a song title, an item name.
  static const rowTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Secondary row text: author, reference, count.
  ///
  /// Tertiary, not muted: at 11px this is the line that says which version a
  /// reading is in and how many slides an item runs for, and muted grey does
  /// not clear the contrast floor on any panel it sits on.
  static const rowSubtitle = TextStyle(color: AppColors.textTertiary, fontSize: 11);

  /// Body copy inside dialogs and empty states.
  static const body = TextStyle(color: AppColors.textSecondary, fontSize: 13);

  /// Uppercase group label above a list.
  static const sectionLabel = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  /// Small badge text.
  static const badge = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 9,
    fontWeight: FontWeight.w600,
  );
}
