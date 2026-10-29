import 'dart:math';

import 'package:flutter/material.dart';

/// Matematik defteri renkleri (oyun tahtası).
class Paper {
  static const background = Color(0xFFFBF8EF);
  static const gridLine = Color(0xFFBFD5EA);
  static const margin = Color(0xFFE57373);
  static const ink = Color(0xFF1F3A68);
  static const pencil = Color(0xFF8A8A8A);
}

/// Işıklı karakterlerin parladığı gece masası renkleri.
class Night {
  static const deep = Color(0xFF0C0806);
  static const wood = Color(0xFF2A1A10);
  static const text = Color(0xFFF6EBD9);
  static const dim = Color(0xFFB9A68D);
  static const gold = Color(0xFFFFC94A);
  static const ember = Color(0xFFFF8A3D);
}

/// Ekranın arkasına sıcak ışıklı koyu bir masa çizer.
/// (Adı eski; artık kâğıt değil gece masası.)
class NotebookBackground extends StatelessWidget {
  final Widget child;
  const NotebookBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DeskPainter(), child: child);
  }
}

class _DeskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.1,
          colors: [Color(0xFF3B2414), Night.wood, Night.deep],
          stops: [0, 0.45, 1],
        ).createShader(rect),
    );
    // Uçuşan küçük kıvılcımlar.
    final r = Random(11);
    for (var i = 0; i < 40; i++) {
      final p = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final rad = 0.6 + r.nextDouble() * 1.6;
      final a = 40 + r.nextInt(90);
      canvas.drawCircle(
        p,
        rad * 3,
        Paint()
          ..color = Night.gold.withAlpha(a ~/ 5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(p, rad, Paint()..color = Night.gold.withAlpha(a));
    }
  }

  @override
  bool shouldRepaint(covariant _DeskPainter old) => false;
}
