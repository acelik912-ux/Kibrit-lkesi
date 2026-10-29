import 'package:shared_preferences/shared_preferences.dart';

/// Biriken yıldızlar ve rütbe. Telefonda saklanır.
class Progress {
  final int stars;
  final int games;
  final int firsts;

  const Progress({this.stars = 0, this.games = 0, this.firsts = 0});

  static const _kStars = 'yildiz';
  static const _kGames = 'oyun';
  static const _kFirsts = 'birincilik';

  /// Rütbeler: (gereken yıldız, ad).
  static const ranks = [
    (0, 'Acemi Çizer'),
    (10, 'Kalem Ustası'),
    (30, 'Harita Bekçisi'),
    (60, 'Sınır Komutanı'),
    (100, 'Kibrit Paşası'),
    (160, 'Defter İmparatoru'),
  ];

  int get rankIndex {
    var r = 0;
    for (var i = 0; i < ranks.length; i++) {
      if (stars >= ranks[i].$1) r = i;
    }
    return r;
  }

  String get rankName => ranks[rankIndex].$2;

  /// Sonraki rütbe (yoksa null).
  (int, String)? get nextRank =>
      rankIndex + 1 < ranks.length ? ranks[rankIndex + 1] : null;

  /// Sonraki rütbeye ilerleme, 0..1.
  double get progressToNext {
    final next = nextRank;
    if (next == null) return 1;
    final from = ranks[rankIndex].$1;
    return ((stars - from) / (next.$1 - from)).clamp(0, 1).toDouble();
  }

  static Future<Progress> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return Progress(
        stars: p.getInt(_kStars) ?? 0,
        games: p.getInt(_kGames) ?? 0,
        firsts: p.getInt(_kFirsts) ?? 0,
      );
    } catch (_) {
      return const Progress();
    }
  }

  /// Bir oyunun sonucunu ekler; yeni durumu döner.
  static Future<Progress> addGame({required int stars, required int place}) async {
    final old = await load();
    final now = Progress(
      stars: old.stars + stars,
      games: old.games + 1,
      firsts: old.firsts + (place == 1 ? 1 : 0),
    );
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kStars, now.stars);
      await p.setInt(_kGames, now.games);
      await p.setInt(_kFirsts, now.firsts);
    } catch (_) {}
    return now;
  }
}
