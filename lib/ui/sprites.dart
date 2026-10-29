import 'package:flutter/material.dart';

import '../game/models.dart';
import 'paper.dart';

/// Canva'da hazırlanan görseller.
class Sprites {
  static const _dir = 'assets/images';

  /// Oyuncu karakterleri: Sen = tükenmez, sonra kalem, silgi, pergel.
  static const _characters = ['tukenmez', 'kalem', 'silgi', 'pergel'];

  /// Karakterlerin ışık renkleri (koyu zeminde okunur).
  static const glow = [
    Color(0xFF5AA9FF),
    Color(0xFFFF6A4D),
    Color(0xFF5BE37D),
    Color(0xFFB98CFF),
  ];

  static String character(int id) => '$_dir/${_characters[id % 4]}.png';
  static Color glowOf(int id) => glow[id % 4];

  static String matchbox(MatchFace f) {
    switch (f) {
      case MatchFace.yatik:
        return '$_dir/kibrit_yatik.png';
      case MatchFace.yan:
        return '$_dir/kibrit_yan.png';
      case MatchFace.dik:
        return '$_dir/kibrit_dik.png';
    }
  }

  static const flag = '$_dir/bayrak.png';
  static const stamp = '$_dir/damga.png';
  static const menu = '$_dir/menu.jpg';

  static void precacheAll(BuildContext context) {
    for (final f in MatchFace.values) {
      precacheImage(AssetImage(matchbox(f)), context);
    }
    for (var i = 0; i < 4; i++) {
      precacheImage(AssetImage(character(i)), context);
    }
    precacheImage(const AssetImage(flag), context);
    precacheImage(const AssetImage(stamp), context);
  }
}

/// Oyuncunun karakteri; sırası gelince ışığı parlar.
class CharacterAvatar extends StatelessWidget {
  final int id;
  final double size;
  final bool active;
  final bool alive;

  const CharacterAvatar({
    super.key,
    required this.id,
    this.size = 32,
    this.active = false,
    this.alive = true,
  });

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      Sprites.character(id),
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    return AnimatedScale(
      scale: active ? 1.15 : 1,
      duration: const Duration(milliseconds: 250),
      child: Opacity(
        opacity: alive ? 1 : 0.3,
        child: alive
            ? img
            : ColorFiltered(
                colorFilter: const ColorFilter.mode(Night.dim, BlendMode.saturation),
                child: img,
              ),
      ),
    );
  }
}
