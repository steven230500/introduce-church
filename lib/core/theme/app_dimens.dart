import 'package:flutter/material.dart';

/// Spacing scale. Every gap and padding in the app comes from here so panels
/// line up across screens instead of each one inventing its own rhythm.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal gutter for every full-page library view.
  static const pageGutter = 32.0;

  /// Horizontal gutter inside a docked or side panel.
  static const panelGutter = 12.0;
}

/// Corner radii, matched to the control they wrap.
abstract final class AppRadius {
  /// Chips, small badges.
  static const xs = 4.0;

  /// Toolbar buttons, inline controls.
  static const sm = 6.0;

  /// Inputs, list rows, popup menus.
  static const md = 8.0;

  /// Sidebar buttons, cards.
  static const lg = 10.0;

  /// Dialogs and large cards.
  static const xl = 14.0;

  static BorderRadius all(double r) => BorderRadius.circular(r);
}

/// Fixed sizes that several widgets must agree on.
abstract final class AppSizes {
  /// Icon rail on the far left.
  static const sidebarWidth = 64.0;

  /// Always-visible bar at the top of the window.
  static const liveBarHeight = 52.0;

  /// Set list panel on the left of the presenter.
  static const setListWidth = 260.0;

  /// Library dock on the right of the presenter.
  static const dockWidth = 300.0;

  /// Slide queue strip.
  static const queueWidth = 220.0;

  /// Header strip inside a panel.
  static const panelHeaderHeight = 40.0;
}

/// Shared animation timing. Short enough to feel instant during a service.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 150);
  static const slow = Duration(milliseconds: 220);
}
