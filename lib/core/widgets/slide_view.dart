import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'fit_text.dart';
import 'slide_background.dart';
import '../models/slide_layer.dart';
import '../models/slide_template.dart';
import '../../core/theme/app_colors.dart';

/// Renders a slide, at whatever size it is given.
///
/// Designs are authored against a [designWidth]-wide slide, so every size in a
/// template is scaled by how wide this widget actually ended up. The scale used
/// to be passed in by hand at each call site, which meant a preview only told
/// the truth at one particular window size: at any other, text that fits on the
/// projector was silently cut off in the preview, or the other way round.
///
/// If [imagePath] is set, renders that image instead of text.
class SlideView extends StatelessWidget {
  const SlideView({
    required this.content,
    required this.reference,
    required this.template,
    this.imagePath,
    this.showBackground = true,
    super.key,
  });

  /// The width every template is designed against.
  static const designWidth = 1920.0;

  /// The height that goes with it. Slides are 16:9 everywhere: the projector
  /// window, the previews and the stream output all letterbox to it.
  static const designHeight = designWidth * 9 / 16;

  final String content;
  final String reference;
  final SlideTemplate template;
  final String? imagePath;

  /// Off where the background is drawn once underneath, rather than again with
  /// every slide: the projector does that for a moving background, so a new
  /// slide changes the words without restarting the picture behind them.
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return Image.file(
        File(imagePath!),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (ctx, err, st) => const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF000000)),
          child: Center(
            child: Text('⚠', style: TextStyle(color: AppColors.textTertiary, fontSize: 48)),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded width means nothing to scale against; fall back to the
        // design size so the slide renders rather than throwing.
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : designWidth;
        final scale = width / designWidth;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (showBackground) SlideBackground(template: template),
            if (template.layers.isNotEmpty)
              _LayerStack(
                layers: template.layers,
                content: content,
                reference: reference,
                scale: scale,
              )
            else ...[
              _BodyText(content: content, template: template, scale: scale),
              if (template.showReference && reference.isNotEmpty)
                _Reference(reference: reference, template: template, scale: scale),
            ],
          ],
        );
      },
    );
  }
}

// ── Layer stack ───────────────────────────────────────────────────────────────

class _LayerStack extends StatelessWidget {
  const _LayerStack({
    required this.layers,
    required this.content,
    required this.reference,
    required this.scale,
  });

  final List<SlideLayer> layers;
  final String content;
  final String reference;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final sorted = [...layers]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: sorted.map((layer) {
            return Positioned(
              left: layer.x * w,
              top: layer.y * h,
              width: layer.width * w,
              height: layer.height * h,
              child: _LayerContent(
                layer: layer,
                content: content,
                reference: reference,
                scale: scale,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _LayerContent extends StatelessWidget {
  const _LayerContent({
    required this.layer,
    required this.content,
    required this.reference,
    required this.scale,
  });

  final SlideLayer layer;
  final String content;
  final String reference;
  final double scale;

  @override
  Widget build(BuildContext context) => switch (layer) {
    TextSlideLayer l => SizedBox.expand(
      child: FitText(
        text: content,
        textAlign: l.textAlign,
        minFontSize: 10 * scale,
        style: TextStyle(
          fontFamily: l.fontFamily,
          color: Color(l.textColor),
          fontSize: l.fontSize * scale,
          fontWeight: FontWeight.values.firstWhere(
            (w) => w.value == l.fontWeight,
            orElse: () => FontWeight.w300,
          ),
          height: l.lineHeight,
          letterSpacing: 0.3,
          shadows: l.textShadow
              ? const [Shadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(1, 2))]
              : null,
        ),
      ),
    ),
    ReferenceSlideLayer l =>
      reference.isEmpty
          ? const SizedBox.shrink()
          : Align(
              alignment: _alignFor(l.textAlign),
              child: Text(
                reference,
                textAlign: l.textAlign,
                style: TextStyle(
                  fontFamily: l.fontFamily,
                  color: Color(l.textColor),
                  fontSize: l.fontSize * scale,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),
  };

  Alignment _alignFor(TextAlign a) => switch (a) {
    TextAlign.left || TextAlign.start => Alignment.centerLeft,
    TextAlign.right || TextAlign.end => Alignment.centerRight,
    _ => Alignment.center,
  };
}

// ── Body text ─────────────────────────────────────────────────────────────────

class _BodyText extends StatelessWidget {
  const _BodyText({required this.content, required this.template, required this.scale});

  final String content;
  final SlideTemplate template;
  final double scale;

  Alignment get _align => switch (template.textValign) {
    TextVerticalAlign.top => Alignment.topCenter,
    TextVerticalAlign.center => Alignment.center,
    TextVerticalAlign.bottom => Alignment.bottomCenter,
  };

  FontWeight get _fontWeight => FontWeight.values.firstWhere(
    (w) => w.value == template.fontWeight,
    orElse: () => FontWeight.w300,
  );

  @override
  Widget build(BuildContext context) {
    // Moving the text is moving its box: one margin grows by as much as the
    // other shrinks, so up to the design's own margin the words keep the room
    // they had and a long verse still fits the same way. Past that the margin
    // being eaten is already at the slide's edge and stops there, so the box
    // keeps rising but loses height, and the words shrink into what is left -
    // which is what a screen blocked along the bottom needs.
    final shift = template.textOffsetY * SlideView.designHeight * scale;
    final margin = template.paddingV * scale;

    return Align(
      alignment: _align,
      child: Padding(
        padding: EdgeInsets.only(
          left: template.paddingH * scale,
          right: template.paddingH * scale,
          top: math.max(0, margin + shift),
          bottom: math.max(0, margin - shift),
        ),
        // The design's size is a ceiling, not a fixed value: a long verse
        // gives way rather than running off the bottom of the screen.
        child: FitText(
          text: content,
          textAlign: template.textAlign,
          style: TextStyle(
            color: Color(template.textColor),
            fontSize: template.fontSize * scale,
            fontWeight: _fontWeight,
            fontFamily: template.fontFamily,
            height: template.lineHeight,
            letterSpacing: 0.3,
            shadows: template.textShadow
                ? const [Shadow(color: Color(0x88000000), blurRadius: 12, offset: Offset(1, 2))]
                : null,
          ),
          minFontSize: 10 * scale,
        ),
      ),
    );
  }
}

// ── Reference ────────────────────────────────────────────────────────────────

class _Reference extends StatelessWidget {
  const _Reference({required this.reference, required this.template, required this.scale});

  final String reference;
  final SlideTemplate template;
  final double scale;

  Alignment get _align => switch (template.referencePosition) {
    ReferencePosition.bottomRight => Alignment.bottomRight,
    ReferencePosition.bottomCenter => Alignment.bottomCenter,
    ReferencePosition.bottomLeft => Alignment.bottomLeft,
  };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _align,
      child: Padding(
        padding: EdgeInsets.all(20 * scale),
        child: Text(
          reference,
          style: TextStyle(
            color: Color(template.referenceColor),
            fontSize: template.referenceFontSize * scale,
            fontWeight: FontWeight.w400,
            fontFamily: template.fontFamily,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
