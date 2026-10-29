import 'dart:math';

import 'package:flutter/material.dart';

import '../game/models.dart';
import 'sprites.dart';

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
                      child: SizedBox.fromSize(
                        size: _sizeFor(shown),
                        child: Image.asset(
                          Sprites.matchbox(shown),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
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
        return const Size(98, 34);
      case MatchFace.yan:
        return const Size(80, 88);
      case MatchFace.dik:
        return const Size(96, 108);
    }
  }
}
