/// Reading and judging colours the way a congregation does.
library;

import 'dart:ui';
import '../../l10n/l10n.dart';

/// Reads a colour someone typed.
///
/// Takes `#1A73E8`, `1a73e8`, `#FFF` and `1A73E8FF`, because those are all
/// things people paste out of a brand guide. Returns null for anything else
/// rather than guessing at it.
int? parseHexColor(String input) {
  var text = input.trim().replaceAll('#', '').replaceAll(' ', '');
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) return null;

  // Three digits is the shorthand: each one doubled.
  if (text.length == 3) {
    text = text.split('').map((c) => '$c$c').join();
  }
  if (text.length == 6) return int.parse('FF$text', radix: 16);
  if (text.length == 8) {
    // Pasted as RRGGBBAA, which is what design tools hand out.
    final rgb = text.substring(0, 6);
    final alpha = text.substring(6, 8);
    return int.parse('$alpha$rgb', radix: 16);
  }
  return null;
}

/// The six digits, ready to be shown in a field or copied back out.
String hexOf(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// How far apart two colours are, by the WCAG measure.
///
/// One is unreadable, twenty-one is black on white. It is the same arithmetic
/// the app's own palette is held to, applied to the thing that matters more:
/// what the back row is trying to read off a wall.
double contrastRatio(int a, int b) {
  final lighter = _luminance(a) > _luminance(b) ? _luminance(a) : _luminance(b);
  final darker = _luminance(a) > _luminance(b) ? _luminance(b) : _luminance(a);
  return (lighter + 0.05) / (darker + 0.05);
}

/// What to tell the operator about a pairing.
enum ContrastVerdict { good, tight, poor }

extension ContrastVerdictX on ContrastVerdict {
  String labelIn(L10n t) => switch (this) {
    ContrastVerdict.good => t.contrastGood,
    ContrastVerdict.tight => t.contrastTight,
    ContrastVerdict.poor => t.contrastPoor,
  };
}

/// Judges a ratio.
///
/// Projected text is large, so the bar is the one WCAG sets for large type
/// rather than for body copy. Below it, somebody at the back is squinting.
ContrastVerdict verdictFor(double ratio) {
  if (ratio >= 4.5) return ContrastVerdict.good;
  if (ratio >= 3.0) return ContrastVerdict.tight;
  return ContrastVerdict.poor;
}

double _luminance(int argb) => Color(argb).computeLuminance();
