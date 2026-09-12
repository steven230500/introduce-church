import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/theme/app_colors.dart';
import 'package:introduce_church/core/services/window_bounds_store.dart';
import 'package:introduce_church/core/theme/app_dimens.dart';
import 'package:introduce_church/core/theme/app_text.dart';

void main() {
  group('surfaces', () {
    test('get lighter as they get closer to the operator', () {
      // Luminance is what makes the elevation ramp read as layered. If an edit
      // inverts two of these, panels stop having visible edges.
      final ramp = [
        AppColors.chrome,
        AppColors.background,
        AppColors.canvas,
        AppColors.surface,
        AppColors.surfaceRaised,
        AppColors.surfaceControl,
      ];

      for (var i = 1; i < ramp.length; i++) {
        expect(
          ramp[i].computeLuminance(),
          greaterThan(ramp[i - 1].computeLuminance()),
          reason: 'surface $i must sit above surface ${i - 1}',
        );
      }
    });

    test('a border is visible against the surface it outlines', () {
      expect(
        AppColors.border.computeLuminance(),
        greaterThan(AppColors.surface.computeLuminance()),
      );
    });
  });

  group('text', () {
    test('the hierarchy dims from primary down to disabled', () {
      final ramp = [
        AppColors.textPrimary,
        AppColors.textSecondary,
        AppColors.textTertiary,
        AppColors.textMuted,
        AppColors.textDisabled,
      ];

      for (var i = 1; i < ramp.length; i++) {
        expect(
          ramp[i].computeLuminance(),
          lessThan(ramp[i - 1].computeLuminance()),
          reason: 'text level $i must be dimmer than level ${i - 1}',
        );
      }
    });

    test('body copy clears the WCAG AA ratio on its surface', () {
      expect(_contrast(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('primary text clears AA on every surface', () {
      for (final surface in [
        AppColors.chrome,
        AppColors.background,
        AppColors.surface,
        AppColors.surfaceControl,
      ]) {
        expect(_contrast(AppColors.textPrimary, surface), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('accents', () {
    test('live is distinct from every other accent', () {
      for (final other in [
        AppColors.accent,
        AppColors.success,
        AppColors.warning,
        AppColors.note,
      ]) {
        expect(AppColors.live, isNot(other));
      }
    });

    test('accent text is readable on the panel surface', () {
      expect(_contrast(AppColors.accent, AppColors.surface), greaterThanOrEqualTo(3.0));
    });
  });

  group('dimensions', () {
    test('the spacing scale only grows', () {
      final scale = [AppSpace.xs, AppSpace.sm, AppSpace.md, AppSpace.lg, AppSpace.xl, AppSpace.xxl];

      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('the radius scale only grows', () {
      final scale = [AppRadius.xs, AppRadius.sm, AppRadius.md, AppRadius.lg, AppRadius.xl];

      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('the fixed columns leave real room for the slide preview', () {
      final columns =
          AppSizes.sidebarWidth + AppSizes.setListWidth + AppSizes.queueWidth + AppSizes.dockWidth;

      // Measured against the window the app refuses to shrink below, so
      // widening a panel cannot quietly squeeze the preview into a sliver.
      expect(columns, lessThan(kMinWindowSize.width - 360));
    });
  });

  group('type scale', () {
    test('runs from the page title down to a badge', () {
      final sizes = [
        AppText.pageTitle.fontSize!,
        AppText.panelTitle.fontSize!,
        AppText.rowSubtitle.fontSize!,
        AppText.badge.fontSize!,
      ];

      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], lessThan(sizes[i - 1]));
      }
    });

    test('nothing falls below 9pt, the floor for a sound booth', () {
      for (final style in [
        AppText.pageTitle,
        AppText.panelTitle,
        AppText.rowTitle,
        AppText.rowSubtitle,
        AppText.body,
        AppText.sectionLabel,
        AppText.badge,
      ]) {
        expect(style.fontSize, greaterThanOrEqualTo(9));
      }
    });
  });
}

/// WCAG relative contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
