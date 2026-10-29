import 'package:flutter/material.dart';

/// Kibrit kutusunun düşebileceği yüzler.
enum MatchFace { yatik, yan, dik }

extension MatchFaceInfo on MatchFace {
  /// Bu yüz gelince kaç kare oynanır.
  int get squares {
    switch (this) {
      case MatchFace.yatik:
        return 1;
      case MatchFace.yan:
        return 3;
      case MatchFace.dik:
        return 6;
    }
  }

  String get label {
    switch (this) {
      case MatchFace.yatik:
        return 'Yatık';
      case MatchFace.yan:
        return 'Yan';
      case MatchFace.dik:
        return 'Dik';
    }
  }
}

enum BotLevel { kolay, orta, zor }

extension BotLevelInfo on BotLevel {
  String get label {
    switch (this) {
      case BotLevel.kolay:
        return 'Kolay';
      case BotLevel.orta:
        return 'Orta';
      case BotLevel.zor:
        return 'Zor';
    }
  }
}

class Player {
  final int id;
  final String name;
  final Color color;
  final bool isBot;
  final BotLevel level;
  int capital;
  bool alive = true;

  Player({
    required this.id,
    required this.name,
    required this.color,
    required this.isBot,
    this.level = BotLevel.orta,
    this.capital = -1,
  });
}

/// Hamlenin türü: kendi ülkene ekleme ya da rakipten kesme.
enum MoveKind { ekle, kes }

/// Oyuncu renkleri: tükenmez kalem tonları.
const List<Color> kPenColors = [
  Color(0xFF1E4FA8), // mavi
  Color(0xFFC62828), // kırmızı
  Color(0xFF2E7D32), // yeşil
  Color(0xFF6A1B9A), // mor
];

const List<String> kBotNames = ['Kurşun', 'Silgi', 'Pergel'];
