import 'package:flutter/material.dart';

/// A country's flag, drawn rather than typed.
///
/// Flag emoji are letters on Windows ("ES", "US"), and this app runs there
/// too. Drawn flags look the same on every computer and need no image files.
/// Simplified on purpose: no coat of arms, fifty stars as a field of dots -
/// at the size a language button uses, detail is noise.
class Flag extends StatelessWidget {
  const Flag({super.key, required this.country, this.width = 48, this.radius = 6});

  /// ISO 3166 code in lower case: `es`, `us`.
  final String country;
  final double width;
  final double radius;

  /// The flag shown beside a language. One place, so changing which country
  /// stands for a language is one line.
  static String forLanguage(String languageCode) => switch (languageCode) {
    'en' => 'us',
    _ => 'es',
  };

  @override
  Widget build(BuildContext context) {
    final height = width * 2 / 3;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          size: Size(width, height),
          painter: switch (country) {
            'us' => const _UnitedStatesPainter(),
            _ => const _SpainPainter(),
          },
        ),
      ),
    );
  }
}

class _SpainPainter extends CustomPainter {
  const _SpainPainter();

  static const _red = Color(0xFFC60B1E);
  static const _yellow = Color(0xFFFFC400);

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.height / 4;
    canvas.drawRect(Offset.zero & size, Paint()..color = _red);
    canvas.drawRect(Rect.fromLTWH(0, band, size.width, band * 2), Paint()..color = _yellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UnitedStatesPainter extends CustomPainter {
  const _UnitedStatesPainter();

  static const _red = Color(0xFFB22234);
  static const _blue = Color(0xFF3C3B6E);

  @override
  void paint(Canvas canvas, Size size) {
    final stripe = size.height / 13;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final red = Paint()..color = _red;
    for (var i = 0; i < 13; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, stripe * i, size.width, stripe), red);
    }

    final canton = Rect.fromLTWH(0, 0, size.width * 0.4, stripe * 7);
    canvas.drawRect(canton, Paint()..color = _blue);

    // Nine rows, alternately six and five stars, as on the flag.
    final star = Paint()..color = Colors.white;
    final dot = size.width / 110;
    final dx = canton.width / 12;
    final dy = canton.height / 10;
    for (var row = 0; row < 9; row++) {
      final count = row.isEven ? 6 : 5;
      final offset = row.isEven ? 1 : 2;
      for (var col = 0; col < count; col++) {
        canvas.drawCircle(Offset(dx * (offset + col * 2), dy * (row + 1)), dot, star);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
