import 'dart:math';

import 'package:flutter/material.dart';

import '../game/models.dart';
import 'paper.dart';

/// Havaya atılıp dönen ve sonunda bir yüzüne düşen kibrit kutusu.
class MatchboxView extends StatefulWidget {
  final MatchFace? face;
  final int tossId;
  final VoidCallback? onTap;
  final Duration duration;

  const MatchboxView({
    super.key,
    required this.face,
    required this.tossId,
    this.onTap,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<MatchboxView> createState() => _MatchboxViewState();
}

class _MatchboxViewState extends State<MatchboxView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration, value: 1);
  int _spins = 3;

  @override
  void didUpdateWidget(covariant MatchboxView old) {
    super.didUpdateWidget(old);
    if (widget.tossId != old.tossId) {
      _spins = 2 + Random().nextInt(3);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final flying = t < 1;
          // Uçuş: yukarı çık, dön, yere sek.
          final height = flying ? sin(pi * t) * 46 * (1 - t * 0.4) : 0.0;
          final spin = Curves.easeOutCubic.transform(t) * _spins * 2 * pi;
          // Havadayken yüzler hızla değişir, son %15'te gerçek yüz görünür.
          final MatchFace shown;
          if (!flying || t > 0.85 || widget.face == null) {
            shown = widget.face ?? MatchFace.yan;
          } else {
            shown = MatchFace.values[(t * 14).floor() % 3];
          }
          final squash = flying && t > 0.85 ? 1 - sin((t - 0.85) / 0.15 * pi) * 0.12 : 1.0;
          return SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Gölge
                Positioned(
                  bottom: 8,
                  child: Container(
                    width: 70 - height * 0.6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 11 + height,
                  child: Transform.rotate(
                    angle: spin,
                    alignment: Alignment.bottomCenter,
                    child: Transform.scale(
                      scaleY: squash,
                      alignment: Alignment.bottomCenter,
                      child: CustomPaint(
                        size: _sizeFor(shown),
                        painter: _BoxPainter(shown),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Size _sizeFor(MatchFace f) {
    switch (f) {
      case MatchFace.yatik:
        return const Size(80, 20);
      case MatchFace.yan:
        return const Size(80, 54);
      case MatchFace.dik:
        return const Size(54, 80);
    }
  }
}

class _BoxPainter extends CustomPainter {
  final MatchFace face;
  _BoxPainter(this.face);

  static const _yellow = Color(0xFFF2C94C);
  static const _red = Color(0xFFC0392B);
  static const _brown = Color(0xFF6D4C41);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    final outline = Paint()
      ..color = Paper.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    if (face == MatchFace.yatik) {
      // Yatık: yandan bakınca ince kutu, sürtünme şeridi görünür.
      canvas.drawRRect(rr, Paint()..color = _yellow);
      final strip = rect.deflate(4);
      canvas.drawRect(strip, Paint()..color = _brown);
      final grain = Paint()..color = Colors.black.withAlpha(60);
      final r = Random(7);
      for (var i = 0; i < 40; i++) {
        canvas.drawCircle(
            Offset(strip.left + r.nextDouble() * strip.width,
                strip.top + r.nextDouble() * strip.height),
            0.7,
            grain);
      }
      canvas.drawRRect(rr, outline);
      return;
    }

    // Yan ve dik: etiketli geniş yüz görünür.
    canvas.drawRRect(rr, Paint()..color = _yellow);
    canvas.save();
    if (face == MatchFace.dik) {
      canvas.translate(size.width, 0);
      canvas.rotate(pi / 2);
    }
    final w = face == MatchFace.dik ? size.height : size.width;
    final h = face == MatchFace.dik ? size.width : size.height;
    final band = Rect.fromLTWH(0, h * 0.30, w, h * 0.40);
    canvas.drawRect(band, Paint()..color = _red);
    // Küçük alev
    final flame = Path()
      ..moveTo(w * 0.16, h * 0.62)
      ..quadraticBezierTo(w * 0.08, h * 0.48, w * 0.16, h * 0.36)
      ..quadraticBezierTo(w * 0.24, h * 0.48, w * 0.16, h * 0.62);
    canvas.drawPath(flame, Paint()..color = _yellow);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'KİBRİT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(w * 0.58 - tp.width / 2, h * 0.5 - tp.height / 2));
    canvas.restore();
    canvas.drawRRect(rr, outline);
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) => old.face != face;
}
