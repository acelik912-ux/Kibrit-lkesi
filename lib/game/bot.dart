import 'dart:math';

import 'models.dart';
import 'rules.dart';

/// Bilgisayar oyuncuları.
///  - Kolay: rastgele ekler ya da keser.
///  - Orta: en iyi planı seçer ama ara sıra dikkatsizlik yapar.
///  - Zor: her kareyi tek tek değerlendirir, başkentini korur,
///    açıkta kalan başkentleri avlar.
class Bot {
  static List<int> chooseMove(
      Board b, List<Player> players, int me, int n, Random r) {
    final level = players[me].level;

    // Planlar: kendine ekle, ya da her rakipten kes.
    final plans = <int?>[null]; // null = ekle
    for (final p in players) {
      if (p.id != me && p.alive) plans.add(p.id);
    }

    if (level == BotLevel.kolay) {
      plans.shuffle(r);
      for (final plan in plans) {
        final sel = _build(b, players, me, n, plan, r, random: true);
        if (sel.isNotEmpty) return sel;
      }
      return const [];
    }

    List<int> best = const [];
    var bestScore = double.negativeInfinity;
    for (final plan in plans) {
      final careless = level == BotLevel.orta && r.nextDouble() < 0.35;
      final sel = _build(b, players, me, n, plan, r, random: careless);
      if (sel.isEmpty) continue;
      final sim = b.copy();
      Rules.apply(sim, players, me, sel);
      var score = evaluate(sim, players, me);
      if (level == BotLevel.orta) score += r.nextDouble() * 6 - 3;
      if (score > bestScore) {
        bestScore = score;
        best = sel;
      }
    }
    return best;
  }

  /// Bir plan için kareleri tek tek seç.
  static List<int> _build(Board b, List<Player> players, int me, int n,
      int? victim, Random r,
      {bool random = false}) {
    final sel = <int>[];
    for (var k = 0; k < n; k++) {
      var cand = Rules.validNext(b, players, me, sel).toList();
      if (sel.isEmpty) {
        cand = cand
            .where((i) => victim == null ? b.cells[i] < 0 : b.cells[i] == victim)
            .toList();
      }
      if (cand.isEmpty) break;
      if (random) {
        sel.add(cand[r.nextInt(cand.length)]);
        continue;
      }
      var bestCell = cand.first;
      var bestScore = double.negativeInfinity;
      for (final c in cand) {
        final sim = b.copy();
        Rules.apply(sim, players, me, [...sel, c]);
        // Küçük rastgelelik: botlar hep aynı oynamasın.
        final s = evaluate(sim, players, me) + r.nextDouble() * 0.05;
        if (s > bestScore) {
          bestScore = s;
          bestCell = c;
        }
      }
      sel.add(bestCell);
    }
    return sel;
  }

  /// Tahtanın bu oyuncu açısından ne kadar iyi olduğu.
  static double evaluate(Board b, List<Player> players, int me) {
    final mine = b.count(me);
    if (mine == 0) return -1e6;
    var s = mine.toDouble();
    s += min(Rules.capitalDepth(b, me, players[me].capital), 3) * 4.0;

    var myBorder = 0;
    for (var i = 0; i < b.cells.length; i++) {
      if (b.cells[i] == me && Rules.isBorder(b, i)) myBorder++;
    }
    s -= myBorder * 0.25;

    // Rakibe doğru ilerle: kesebilmek için sınıra dayanmak gerekir.
    final d = Rules.distanceToEnemy(b, me);
    if (d < 999) s -= d * 1.2;

    for (final p in players) {
      if (p.id == me || !p.alive) continue;
      final c = b.count(p.id);
      if (c == 0) {
        s += 200; // rakibi oyundan çıkardı
        continue;
      }
      s -= c * 0.7;
      s -= min(Rules.capitalDepth(b, p.id, p.capital), 3) * 2.0;
    }
    return s;
  }

  /// Bot bu tur bir silah kullanmalı mı? (silah, hedef kare) ya da null.
  static (Silah, int)? chooseWeapon(
      Board b, List<Player> players, int me, int round, Random r) {
    final p = players[me];
    final level = p.level;

    // Kalkan: başkent tehlikedeyse.
    if (!p.usedWeapons.contains(Silah.kalkan) &&
        level != BotLevel.kolay &&
        Rules.distanceToEnemy(b, me) <= 1 &&
        Rules.capitalDepth(b, me, p.capital) <= 1) {
      return (Silah.kalkan, -1);
    }
    if (round < 3) return null;

    if (level == BotLevel.kolay) {
      if (p.usedWeapons.contains(Silah.bomba) || r.nextDouble() > 0.12) {
        return null;
      }
      final t = Rules.bombTargets(b, players, me).toList();
      if (t.isEmpty) return null;
      return (Silah.bomba, t[r.nextInt(t.length)]);
    }

    (Silah, int)? best;
    var bestGain = 0;
    for (final w in [Silah.bomba, Silah.mizrak]) {
      if (p.usedWeapons.contains(w)) continue;
      final targets = w == Silah.bomba
          ? Rules.bombTargets(b, players, me)
          : Rules.spearTargets(b, players, me);
      for (final t in targets) {
        final cells = w == Silah.bomba
            ? Rules.bombCells(b, players, me, t)
            : Rules.spearCells(b, players, me, t);
        if (cells.length < 3) continue;
        final sim = b.copy();
        final res = Rules.removeCells(sim, players, cells);
        final gain = cells.length + res.dropped.length;
        if (gain > bestGain) {
          bestGain = gain;
          best = (w, t);
        }
      }
    }
    final need = level == BotLevel.zor ? 6 : 8;
    if (best == null || bestGain < need) return null;
    if (level == BotLevel.orta && r.nextDouble() < 0.4) return null;
    return best;
  }
}
