import 'package:flutter/material.dart';

/// Matematik defteri renkleri ve arka planı.
class Paper {
  static const background = Color(0xFFFBF8EF);
  static const gridLine = Color(0xFFBFD5EA);
  static const margin = Color(0xFFE57373);
  static const ink = Color(0xFF1F3A68);
  static const pencil = Color(0xFF8A8A8A);
}

/// Ekranın tamamına kareli kâğıt ve kırmızı kenar çizgisi çizer.
class NotebookBackground extends StatelessWidget {
  final Widget child;
  final double cell;

  const NotebookBackground({super.key, required this.child, this.cell = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotebookPainter(cell),
      child: child,
    );
  }
}

class _NotebookPainter extends CustomPainter {
  final double cell;
  _NotebookPainter(this.cell);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Paper.background);
    final grid = Paint()
      ..color = Paper.gridLine.withAlpha(110)
      ..strokeWidth = 0.6;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final margin = Paint()
      ..color = Paper.margin.withAlpha(170)
      ..strokeWidth = 1.4;
    canvas.drawLine(const Offset(14, 0), Offset(14, size.height), margin);
  }

  @override
  bool shouldRepaint(covariant _NotebookPainter old) => old.cell != cell;
}
