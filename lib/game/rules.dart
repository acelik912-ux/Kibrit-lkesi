import 'dart:math';

import 'models.dart';

/// Kareli defter: her kare ya boştur (-1) ya da bir oyuncuya aittir.
class Board {
  final int w;
  final int h;
  final List<int> cells;

  Board(this.w, this.h) : cells = List<int>.filled(w * h, -1);
  Board._(this.w, this.h, this.cells);

  Board copy() => Board._(w, h, List<int>.from(cells));

  int idx(int x, int y) => y * w + x;
  int xOf(int i) => i % w;
  int yOf(int i) => i ~/ w;

  /// Yukarı, aşağı, sol, sağ komşular (çapraz sayılmaz).
  List<int> neighbors(int i) {
    final x = xOf(i);
    final y = yOf(i);
    final r = <int>[];
    if (x > 0) r.add(i - 1);
    if (x < w - 1) r.add(i + 1);
    if (y > 0) r.add(i - w);
    if (y < h - 1) r.add(i + w);
    return r;
  }

  int count(int player) {
    var c = 0;
    for (final v in cells) {
      if (v == player) c++;
    }
    return c;
  }
}

class MoveResult {
  final MoveKind kind;
  final int? victim;

  /// Ana topraktan koptuğu için silinen kareler.
  final List<int> dropped;

  /// Başkenti kesildiği için oyundan çıkan oyuncu.
  final bool victimEliminated;

  const MoveResult({
    required this.kind,
    this.victim,
    this.dropped = const [],
    this.victimEliminated = false,
  });
}

class Rules {
  /// Oyunun bitmesi için tur sınırı (herkes bir kez oynayınca bir tur).
  static const int maxRounds = 30;

  /// Sallamanın sırrı: kutuyu tam bu kadar sallayan şanslı atar.
  static const int luckyShakes = 7;

  /// Kibrit kutusu atışı. Dik gelmesi en nadir, yatık en sık.
  /// [lucky]: tam [luckyShakes] kez sallandıysa iyi yüzler çok daha sık gelir.
  static MatchFace toss(Random r, {bool lucky = false}) {
    final v = r.nextDouble();
    final dik = lucky ? 0.30 : 0.10;
    final yan = lucky ? 0.75 : 0.42; // birikimli
    if (v < dik) return MatchFace.dik;
    if (v < yan) return MatchFace.yan;
    return MatchFace.yatik;
  }

  /// Oyuncu sayısına göre defter boyutu ve başlangıç ülkeleri.
  static Board setup(List<Player> players) {
    final n = players.length;
    final int w;
    final int h;
    if (n <= 2) {
      w = 18;
      h = 24;
    } else if (n == 3) {
      w = 20;
      h = 28;
    } else {
      w = 22;
      h = 30;
    }
    final b = Board(w, h);
    final List<List<int>> centers;
    if (n <= 2) {
      centers = [
        [w ~/ 2, h - 6],
        [w ~/ 2, 5],
      ];
    } else if (n == 3) {
      centers = [
        [w ~/ 2, h - 6],
        [5, 5],
        [w - 6, 5],
      ];
    } else {
      centers = [
        [5, h - 6],
        [w - 6, 5],
        [5, 5],
        [w - 6, h - 6],
      ];
    }
    for (var p = 0; p < n; p++) {
      final cx = centers[p][0];
      final cy = centers[p][1];
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          b.cells[b.idx(cx + dx, cy + dy)] = p;
        }
      }
      players[p].capital = b.idx(cx, cy);
      players[p].alive = true;
    }
    return b;
  }

  /// Bir kare, sahibinin sınırında mı? (Defter kenarı sınır sayılmaz.)
  static bool isBorder(Board b, int i) {
    final o = b.cells[i];
    if (o < 0) return false;
    for (final n in b.neighbors(i)) {
      if (b.cells[n] != o) return true;
    }
    return false;
  }

  static MoveKind? kindOf(Board b, List<int> sel) {
    if (sel.isEmpty) return null;
    return b.cells[sel.first] < 0 ? MoveKind.ekle : MoveKind.kes;
  }

  static bool _validAdd(Board b, int me, int i, Set<int> sel) {
    if (b.cells[i] >= 0 || sel.contains(i)) return false;
    for (final n in b.neighbors(i)) {
      if (b.cells[n] == me || sel.contains(n)) return true;
    }
    return false;
  }

  /// Kesme kuralı: sadece kendi ülkenin değdiği yerden kesebilirsin.
  /// İlk kare senin toprağına komşu olmalı; sonraki kareler senin toprağına
  /// ya da bu turda kestiğin karelere komşu olarak içeri doğru ilerler.
  static bool _validCut(
      Board b, List<Player> players, int me, int? victim, int i, Set<int> sel) {
    final o = b.cells[i];
    if (o < 0 || o == me || sel.contains(i)) return false;
    if (victim != null && o != victim) return false;
    if (!players[o].alive) return false;
    var touches = false;
    for (final n in b.neighbors(i)) {
      if (b.cells[n] == me || sel.contains(n)) {
        touches = true;
        break;
      }
    }
    if (!touches) return false;
    // Başkent ancak tur başında sınırdaysa kesilebilir.
    if (i == players[o].capital) return isBorder(b, i);
    return true;
  }

  /// Bu oyuncunun toprağından en yakın rakip kareye kaç adım var.
  /// (1 = değiyor; rakip yoksa büyük bir sayı)
  static int distanceToEnemy(Board b, int me) {
    final dist = List<int>.filled(b.cells.length, -1);
    var frontier = <int>[];
    for (var i = 0; i < b.cells.length; i++) {
      if (b.cells[i] == me) {
        dist[i] = 0;
        frontier.add(i);
      }
    }
    while (frontier.isNotEmpty) {
      final next = <int>[];
      for (final c in frontier) {
        for (final n in b.neighbors(c)) {
          if (dist[n] >= 0) continue;
          dist[n] = dist[c] + 1;
          final o = b.cells[n];
          if (o >= 0 && o != me) return dist[n];
          next.add(n);
        }
      }
      frontier = next;
    }
    return 999;
  }


  /// Seçime eklenebilecek kareler.
  static Set<int> validNext(
      Board b, List<Player> players, int me, List<int> sel) {
    final selSet = sel.toSet();
    final kind = kindOf(b, sel);
    final int? victim = kind == MoveKind.kes ? b.cells[sel.first] : null;
    final out = <int>{};
    for (var i = 0; i < b.cells.length; i++) {
      if (kind != MoveKind.kes && _validAdd(b, me, i, selSet)) {
        out.add(i);
      } else if (kind != MoveKind.ekle &&
          _validCut(b, players, me, victim, i, selSet)) {
        out.add(i);
      }
    }
    return out;
  }

  /// Hamleyi deftere uygular. Sadece tahtayı değiştirir;
  /// oyuncunun elenmesini çağıran taraf işler.
  static MoveResult apply(
      Board b, List<Player> players, int me, List<int> sel) {
    final kind = kindOf(b, sel);
    if (kind == null) return const MoveResult(kind: MoveKind.ekle);
    if (kind == MoveKind.ekle) {
      for (final i in sel) {
        b.cells[i] = me;
      }
      return const MoveResult(kind: MoveKind.ekle);
    }

    final victim = b.cells[sel.first];
    final capital = players[victim].capital;
    final capitalHit = sel.contains(capital);
    for (final i in sel) {
      b.cells[i] = -1;
    }
    final dropped = <int>[];
    if (capitalHit) {
      for (var i = 0; i < b.cells.length; i++) {
        if (b.cells[i] == victim) {
          b.cells[i] = -1;
          dropped.add(i);
        }
      }
      return MoveResult(
          kind: MoveKind.kes,
          victim: victim,
          dropped: dropped,
          victimEliminated: true);
    }

    // Başkente bağlı olmayan parçalar kopar.
    final keep = <int>{capital};
    final queue = <int>[capital];
    while (queue.isNotEmpty) {
      final c = queue.removeLast();
      for (final n in b.neighbors(c)) {
        if (b.cells[n] == victim && keep.add(n)) queue.add(n);
      }
    }
    for (var i = 0; i < b.cells.length; i++) {
      if (b.cells[i] == victim && !keep.contains(i)) {
        b.cells[i] = -1;
        dropped.add(i);
      }
    }
    return MoveResult(kind: MoveKind.kes, victim: victim, dropped: dropped);
  }

  /// Başkentten en yakın sınıra kaç adım var? (0 = başkent açıkta)
  static int capitalDepth(Board b, int player, int capital) {
    if (capital < 0 || b.cells[capital] != player) return 0;
    final seen = <int>{capital};
    var frontier = <int>[capital];
    var depth = 0;
    while (frontier.isNotEmpty) {
      final next = <int>[];
      for (final c in frontier) {
        if (isBorder(b, c)) return depth;
        for (final n in b.neighbors(c)) {
          if (b.cells[n] == player && seen.add(n)) next.add(n);
        }
      }
      frontier = next;
      depth++;
    }
    return depth;
  }
}
