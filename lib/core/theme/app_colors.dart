import 'package:flutter/material.dart';

/// Single source of truth for every color in the app.
///
/// Surfaces are ordered darkest → lightest so the elevation hierarchy reads
/// top-to-bottom. Never write a `Color(0xFF…)` literal in a widget: add a token
/// here instead, otherwise the palette drifts per screen.
abstract final class AppColors {
  // ── Surfaces ───────────────────────────────────────────────────────────────
  /// Chrome: sidebar, live bar. Darkest surface, frames everything else.
  static const chrome = Color(0xFF0D0D0F);

  /// Page background behind library content.
  static const background = Color(0xFF111113);

  /// Canvas behind the slide preview.
  static const canvas = Color(0xFF1A1A1E);

  /// Panels, cards, dialogs.
  static const surface = Color(0xFF1C1C1E);

  /// Dialog header strip, one step above [surface].
  static const surfaceRaised = Color(0xFF252528);

  /// Inputs, chips, popup menus, inactive buttons.
  static const surfaceControl = Color(0xFF2C2C2E);

  // ── Borders ────────────────────────────────────────────────────────────────
  /// Hairline between panels. Low contrast on purpose.
  static const divider = Color(0xFF2C2C2E);

  /// Visible outline on controls and cards.
  static const border = Color(0xFF3A3A3C);

  // ── Text ───────────────────────────────────────────────────────────────────
  /// Titles and active values.
  static const textPrimary = Color(0xFFFFFFFF);

  /// Body copy, secondary values.
  static const textSecondary = Color(0xFFAEAEB2);

  /// Icons and labels at rest.
  static const textTertiary = Color(0xFF949499);

  /// Captions, metadata, hints.
  static const textMuted = Color(0xFF636366);

  /// Disabled controls and placeholder text.
  static const textDisabled = Color(0xFF48484A);

  // ── Accents ────────────────────────────────────────────────────────────────
  /// Primary action and selection.
  static const accent = Color(0xFF0A84FF);

  /// Light accent for text on accent-tinted fills.
  static const accentLight = Color(0xFF64B5F6);

  /// Broadcasting to the projector. Reserved — never use for anything else.
  static const live = Color(0xFFFF3B30);

  /// Destructive action.
  static const danger = Color(0xFFFF453A);

  /// Confirmation, media present, auto-advance armed.
  static const success = Color(0xFF30D158);

  /// Countdown running.
  static const warning = Color(0xFFFF9F0A);

  /// Operator notes.
  static const note = Color(0xFFFFD60A);

  // ── Tints ──────────────────────────────────────────────────────────────────
  /// Fill behind a selected row or tile.
  static Color get accentFill => accent.withValues(alpha: 0.20);

  /// Fill behind a hovered or lightly active control.
  static Color get accentFillSoft => accent.withValues(alpha: 0.15);

  /// Outline on a selected row.
  static Color get accentOutline => accent.withValues(alpha: 0.50);

  /// Scrim over media thumbnails so overlaid labels stay readable.
  static Color get scrim => Colors.black.withValues(alpha: 0.65);
}
