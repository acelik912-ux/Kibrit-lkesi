import 'dart:math';

import 'models.dart';

/// Kareli defter: her kare ya boştur (-1) ya da bir oyuncuya aittir.
class Board {
  final int w;
  final int h;
  final List<int> cells;

  /// Gizli yıldızın saklandığı kare (-1 = yok ya da bulundu).
  int hiddenStar = -1;

  /// Bulunan yıldızın yeri ve bulan oyuncu (çizim için).
  int foundStarCell = -1;
  int foundStarBy = -1;

  Board(this.w, this.h) : cells = List<int>.filled(w * h, -1);
  Board._(this.w, this.h, this.cells);

  /// Kopya: botlar bununla deneme yapar. Gizli yıldız kopyaya geçmez,
  /// yani botlar yerini bilemez.
  Board copy() => Board._(w, h, List<int>.from(cells))
    ..foundStarCell = foundStarCell
    ..foundStarBy = foundStarBy;

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

  /// Gizli yıldız bu hamlede bulundu mu; bonus olarak kazanılan kareler.
  final bool starFound;
  final List<int> bonus;

  const MoveResult({
    required this.kind,
    this.victim,
    this.dropped = const [],
    this.victimEliminated = false,
    this.starFound = false,
    this.bonus = const [],
  });
}

class Rules {
  /// Oyunun bitmesi için tur sınırı (herkes bir kez oynayınca bir tur).
  static const int maxRounds = 30;

  /// Sallamanın sırrı: kutuyu tam bu kadar sallayan şanslı atar.
  static const int luckyShakes = 7;

  /// 1..6 için olasılıklar (yüzde). Kutu çoğunlukla geniş yüzüne düşer,
  /// ucunun üstünde dik durması nadirdir.
  static const List<int> normalOdds = [22, 22, 18, 18, 10, 10]; // ort. ~3,0
  /// Tam [luckyShakes] kez sallanınca büyük sayılar çok daha sık gelir.
  static const List<int> luckyOdds = [8, 8, 16, 18, 25, 25]; // ort. ~4,2

  /// Kibrit kutusu atışı: 1–6 arası kaç kare oynanacağı.
  static int roll(Random r, {bool lucky = false}) {
    final odds = lucky ? luckyOdds : normalOdds;
    var v = r.nextInt(100);
    for (var i = 0; i < 6; i++) {
      v -= odds[i];
      if (v < 0) return i + 1;
    }
    return 6;
  }

  /// Oyuncu sayısına göre defter boyutu ve başlangıç ülkeleri.
  /// Gizli yıldızı bulana verilen bonus alanın yarıçapı (3x3).
  static const int starRadius = 1;

  static Board setup(List<Player> players, [Random? rng]) {
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
      players[p].usedWeapons.clear();
      players[p].shielded = false;
    }
    _hideStar(b, rng ?? Random());
    return b;
  }

  /// Yıldızı ülkelerden uzak, kenara yapışık olmayan bir boş kareye sakla.
  static void _hideStar(Board b, Random r) {
    final cand = <int>[];
    for (var i = 0; i < b.cells.length; i++) {
      final x = b.xOf(i), y = b.yOf(i);
      if (x < 1 || y < 1 || x > b.w - 2 || y > b.h - 2) continue;
      if (b.cells[i] >= 0) continue;
      var near = false;
      for (var j = 0; j < b.cells.length && !near; j++) {
        if (b.cells[j] < 0) continue;
        final d = (b.xOf(j) - x).abs() + (b.yOf(j) - y).abs();
        if (d < 5) near = true;
      }
      if (!near) cand.add(i);
    }
    if (cand.isNotEmpty) b.hiddenStar = cand[r.nextInt(cand.length)];
  }

  /// İpucu: yıldız ülkene göre ne tarafta, ne kadar yakın?
  static String? starHint(Board b, int me, int capital) {
    final s = b.hiddenStar;
    if (s < 0 || capital < 0) return null;
    // En yakın kendi karene uzaklık.
    var d = 999;
    for (var i = 0; i < b.cells.length; i++) {
      if (b.cells[i] != me) continue;
      final dd = (b.xOf(i) - b.xOf(s)).abs() + (b.yOf(i) - b.yOf(s)).abs();
      if (dd < d) d = dd;
    }
    final dx = b.xOf(s) - b.xOf(capital);
    final dy = b.yOf(s) - b.yOf(capital);
    final dikey = dy < -1 ? 'üst' : (dy > 1 ? 'alt' : '');
    final yatay = dx < -1 ? 'sol' : (dx > 1 ? 'sağ' : '');
    final String yon;
    if (dikey.isNotEmpty && yatay.isNotEmpty) {
      yon = '$yatay ${dikey == 'üst' ? 'üstünde' : 'altında'}';
    } else if (dikey.isNotEmpty) {
      yon = dikey == 'üst' ? 'üstünde' : 'altında';
    } else if (yatay.isNotEmpty) {
      yon = yatay == 'sol' ? 'solunda' : 'sağında';
    } else {
      yon = 'çok yakınında';
    }
    final String isi;
    if (d <= 2) {
      isi = 'Yanıyorsun! 🔥';
    } else if (d <= 4) {
      isi = 'Sıcak!';
    } else if (d <= 7) {
      isi = 'Ilık.';
    } else {
      isi = 'Soğuk ❄️';
    }
    return 'Gizli yıldız ülkenin $yon. $isi';
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
    if (!players[o].alive || players[o].shielded) return false;
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
      final star = b.hiddenStar;
      if (star >= 0 && sel.contains(star)) {
        // Gizli yıldız bulundu: çevresindeki boş kareler bonus.
        final bonus = <int>[];
        final sx = b.xOf(star), sy = b.yOf(star);
        for (var dy = -starRadius; dy <= starRadius; dy++) {
          for (var dx = -starRadius; dx <= starRadius; dx++) {
            final x = sx + dx, y = sy + dy;
            if (x < 0 || y < 0 || x >= b.w || y >= b.h) continue;
            final i = b.idx(x, y);
            if (b.cells[i] < 0) {
              b.cells[i] = me;
              bonus.add(i);
            }
          }
        }
        b.hiddenStar = -1;
        b.foundStarCell = star;
        b.foundStarBy = me;
        return MoveResult(kind: MoveKind.ekle, starFound: true, bonus: bonus);
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

  // ---------------- Silahlar ----------------

  /// Silahın vurabileceği rakip kare mi? (başkent ve kalkanlılar hariç)
  static bool _hittable(Board b, List<Player> players, int me, int i) {
    final o = b.cells[i];
    if (o < 0 || o == me) return false;
    final p = players[o];
    if (!p.alive || p.shielded) return false;
    return i != p.capital;
  }

  static List<int> _plus(Board b, int c) => [c, ...b.neighbors(c)];

  /// Bomba: rakip ülkede her yere atılabilir.
  static Set<int> bombTargets(Board b, List<Player> players, int me) => {
        for (var i = 0; i < b.cells.length; i++)
          if (_hittable(b, players, me, i)) i,
      };

  /// Bombanın vuracağı kareler: artı (+) şeklinde 5 kare.
  static List<int> bombCells(Board b, List<Player> players, int me, int c) =>
      _plus(b, c).where((i) => _hittable(b, players, me, i)).toList();

  static const _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  /// Mızrak için yön: hedeften geriye düz giderken en fazla 6 adımda
  /// kendi toprağına ulaşılan yön. Yoksa null.
  static (int, int)? spearDir(Board b, int me, int t) {
    for (final d in _dirs) {
      var x = b.xOf(t), y = b.yOf(t);
      for (var k = 1; k <= 6; k++) {
        x -= d.$1;
        y -= d.$2;
        if (x < 0 || y < 0 || x >= b.w || y >= b.h) break;
        if (b.cells[b.idx(x, y)] == me) return d;
      }
    }
    return null;
  }

  static Set<int> spearTargets(Board b, List<Player> players, int me) => {
        for (var i = 0; i < b.cells.length; i++)
          if (_hittable(b, players, me, i) && spearDir(b, me, i) != null) i,
      };

  /// Mızrağın vuracağı kareler: hedeften ileri düz 5 kare.
  static List<int> spearCells(Board b, List<Player> players, int me, int t) {
    final d = spearDir(b, me, t);
    if (d == null) return const [];
    final out = <int>[];
    var x = b.xOf(t), y = b.yOf(t);
    for (var k = 0; k < 5; k++) {
      if (x < 0 || y < 0 || x >= b.w || y >= b.h) break;
      final i = b.idx(x, y);
      if (_hittable(b, players, me, i)) out.add(i);
      x += d.$1;
      y += d.$2;
    }
    return out;
  }

  /// Kareleri siler; başkente bağlantısı kopan parçalar da düşer.
  /// Başkentler silahlarla alınamaz, bu yüzden kimse elenmez.
  static MoveResult removeCells(Board b, List<Player> players, List<int> cells) {
    final victims = <int>{};
    for (final i in cells) {
      if (b.cells[i] >= 0) victims.add(b.cells[i]);
      b.cells[i] = -1;
    }
    final dropped = <int>[];
    for (final v in victims) {
      final cap = players[v].capital;
      final keep = <int>{cap};
      final queue = <int>[cap];
      while (queue.isNotEmpty) {
        final c = queue.removeLast();
        for (final n in b.neighbors(c)) {
          if (b.cells[n] == v && keep.add(n)) queue.add(n);
        }
      }
      for (var i = 0; i < b.cells.length; i++) {
        if (b.cells[i] == v && !keep.contains(i)) {
          b.cells[i] = -1;
          dropped.add(i);
        }
      }
    }
    return MoveResult(
      kind: MoveKind.kes,
      victim: victims.isEmpty ? null : victims.first,
      dropped: dropped,
    );
  }
}
