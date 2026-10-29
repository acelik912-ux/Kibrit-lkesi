import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kibrit_ulke/game/bot.dart';
import 'package:kibrit_ulke/game/controller.dart';
import 'package:kibrit_ulke/game/progress.dart';
import 'package:kibrit_ulke/game/models.dart';
import 'package:kibrit_ulke/game/rules.dart';

List<Player> makePlayers(int n, {BotLevel level = BotLevel.zor}) => [
      for (var i = 0; i < n; i++)
        Player(
          id: i,
          name: 'P$i',
          color: kPenColors[i],
          isBot: true,
          level: level,
        ),
    ];

void main() {
  test('başlangıçta herkesin 25 karesi ve başkenti var', () {
    for (var n = 2; n <= 4; n++) {
      final ps = makePlayers(n);
      final b = Rules.setup(ps);
      for (final p in ps) {
        expect(b.count(p.id), 25);
        expect(b.cells[p.capital], p.id);
        expect(Rules.capitalDepth(b, p.id, p.capital), 2);
      }
    }
  });

  test('ekleme sadece sınıra bitişik boş karelere olur', () {
    final ps = makePlayers(2);
    final b = Rules.setup(ps);
    final valid = Rules.validNext(b, ps, 0, []);
    for (final i in valid) {
      final o = b.cells[i];
      if (o < 0) {
        expect(b.neighbors(i).any((n) => b.cells[n] == 0), isTrue);
      } else {
        expect(o, 1);
        expect(Rules.isBorder(b, i), isTrue);
      }
    }
    // İlk seçim boş kareyse sonrakiler de boş kare olmalı.
    final first = valid.firstWhere((i) => b.cells[i] < 0);
    final next = Rules.validNext(b, ps, 0, [first]);
    expect(next.every((i) => b.cells[i] < 0), isTrue);
  });

  test('başkent tur başında sınırda değilse kesilemez', () {
    final ps = makePlayers(2);
    final b = Rules.setup(ps);
    final cap = ps[1].capital;
    // Başkentin üstündeki iki kareyi kes: başkent komşusu seçili olsa da olmaz.
    final above1 = cap - b.w;
    final above2 = cap - 2 * b.w;
    final next = Rules.validNext(b, ps, 0, [above2, above1]);
    expect(next.contains(cap), isFalse);
  });

  test('başkent kesilince ülke tamamen silinir', () {
    final ps = makePlayers(2);
    final b = Rules.setup(ps);
    final cap = ps[1].capital;
    // Başkenti sınıra getir.
    b.cells[cap - b.w] = 0; // oyuncu 0 başkente kadar dayandı
    b.cells[cap - 2 * b.w] = 0;
    expect(Rules.isBorder(b, cap), isTrue);
    expect(Rules.validNext(b, ps, 0, []).contains(cap), isTrue);
    final res = Rules.apply(b, ps, 0, [cap]);
    expect(res.victimEliminated, isTrue);
    expect(b.count(1), 0);
  });

  test('başkentten kopan parça silinir', () {
    final ps = makePlayers(2);
    final b = Rules.setup(ps);
    final cap = ps[1].capital;
    final cx = b.xOf(cap);
    final cy = b.yOf(cap);
    // Sağdaki iki sütunu (cx+1) keserek cx+2 sütununu kopar.
    final cut = [for (var dy = -2; dy <= 2; dy++) b.idx(cx + 1, cy + dy)];
    final res = Rules.apply(b, ps, 0, cut);
    expect(res.victimEliminated, isFalse);
    expect(res.dropped.length, 5);
    expect(b.count(1), 15);
  });

  test('botlar oyunu hatasız bitirir', () {
    for (var n = 2; n <= 4; n++) {
      for (final level in BotLevel.values) {
        final r = Random(n * 10 + level.index);
        final ps = makePlayers(n, level: level);
        final b = Rules.setup(ps);
        var turns = 0;
        var current = 0;
        while (turns < Rules.maxRounds * n) {
          final face = Rules.toss(r);
          final move = Bot.chooseMove(b, ps, current, face.squares, r);
          expect(move.length, lessThanOrEqualTo(face.squares));
          // Hamle kurallara uygun olmalı.
          final sel = <int>[];
          for (final c in move) {
            expect(Rules.validNext(b, ps, current, sel).contains(c), isTrue);
            sel.add(c);
          }
          final res = Rules.apply(b, ps, current, move);
          if (res.victimEliminated) ps[res.victim!].alive = false;
          if (ps.where((p) => p.alive).length == 1) break;
          do {
            current = (current + 1) % n;
          } while (!ps[current].alive);
          turns++;
        }
        for (final p in ps) {
          if (p.alive) expect(b.cells[p.capital], p.id);
        }
      }
    }
  });

  test('tam 7 sallama iyi yüzleri sıklaştırır', () {
    int good(bool lucky) {
      final r = Random(1);
      var g = 0;
      for (var i = 0; i < 5000; i++) {
        final f = Rules.toss(r, lucky: lucky);
        if (f != MatchFace.yatik) g++;
      }
      return g;
    }

    final normal = good(false);
    final lucky = good(true);
    expect(normal, inInclusiveRange(1900, 2300)); // ~%42
    expect(lucky, inInclusiveRange(3550, 3950)); // ~%75
  });

  test('yıldız kuralı: 1.→3, 2.→2, 3.→1, sonuncu 0', () {
    expect(GameController.starsFor(1, 2), 3);
    expect(GameController.starsFor(2, 2), 0);
    expect(GameController.starsFor(1, 4), 3);
    expect(GameController.starsFor(2, 4), 2);
    expect(GameController.starsFor(3, 4), 1);
    expect(GameController.starsFor(4, 4), 0);
    expect(GameController.starsFor(2, 3), 2);
    expect(GameController.starsFor(3, 3), 0);
  });

  test('rütbe ilerlemesi', () {
    expect(const Progress(stars: 0).rankName, 'Acemi Çizer');
    expect(const Progress(stars: 12).rankName, 'Kalem Ustası');
    expect(const Progress(stars: 20).progressToNext, closeTo(0.5, 0.001));
    expect(const Progress(stars: 500).nextRank, isNull);
  });

  test('kesme sadece ülkenin değdiği yerden yapılır', () {
    final ps = makePlayers(2);
    final b = Rules.setup(ps);
    // Başlangıçta ülkeler birbirine uzak: hiç kesilecek kare yok.
    final start = Rules.validNext(b, ps, 0, []);
    expect(start.every((i) => b.cells[i] < 0), isTrue);
    // Oyuncu 0, rakibin alt sınırına kadar bir köprü kursun.
    final cap1 = ps[1].capital;
    final x = b.xOf(cap1);
    final bottom1 = b.yOf(cap1) + 2; // rakibin en alt satırı
    final top0 = b.yOf(ps[0].capital) - 2;
    for (var y = bottom1 + 1; y < top0; y++) {
      b.cells[b.idx(x, y)] = 0;
    }
    expect(Rules.distanceToEnemy(b, 0), 1);
    final v = Rules.validNext(b, ps, 0, []);
    final cuts = v.where((i) => b.cells[i] == 1).toList();
    expect(cuts, [b.idx(x, bottom1)], reason: 'sadece değdiği kare');
    // O kareyi seçince içeri doğru devam edilebilir.
    final v2 = Rules.validNext(b, ps, 0, [b.idx(x, bottom1)]);
    expect(v2.contains(b.idx(x, bottom1 - 1)), isTrue);
    expect(v2.contains(b.idx(x - 2, bottom1)), isFalse);
  });

  test('gizli yıldız ülkelerden uzağa saklanır', () {
    for (var seed = 0; seed < 20; seed++) {
      for (var n = 2; n <= 4; n++) {
        final ps = makePlayers(n);
        final b = Rules.setup(ps, Random(seed));
        final s = b.hiddenStar;
        expect(s, greaterThanOrEqualTo(0));
        expect(b.cells[s], -1);
        for (var i = 0; i < b.cells.length; i++) {
          if (b.cells[i] < 0) continue;
          final d = (b.xOf(i) - b.xOf(s)).abs() + (b.yOf(i) - b.yOf(s)).abs();
          expect(d, greaterThanOrEqualTo(5));
        }
        // Botlar kopyada yıldızı göremez.
        expect(b.copy().hiddenStar, -1);
      }
    }
  });

  test('gizli yıldızı bulan çevresini kazanır', () {
    final ps = makePlayers(2);
    final b = Rules.setup(ps, Random(1));
    final s = b.hiddenStar;
    // Oyuncu 0'ın toprağını yıldızın hemen yanına kadar getir.
    final left = s - 1;
    b.cells[left] = 0;
    final before = b.count(0);
    final res = Rules.apply(b, ps, 0, [s]);
    expect(res.starFound, isTrue);
    expect(b.hiddenStar, -1);
    expect(b.foundStarCell, s);
    expect(b.cells[s], 0);
    expect(res.bonus.length, 7); // 3x3 içindeki diğer boş kareler
    expect(b.count(0), before + 1 + 7);
  });

  test('ipucu yönü ve sıcaklığı söyler', () {
    final ps = makePlayers(2);
    final b = Rules.setup(ps, Random(2));
    final cap = ps[0].capital;
    // Yıldızı başkentin sağ üstüne, uzağa koy.
    b.hiddenStar = b.idx(b.xOf(cap) + 6, b.yOf(cap) - 8);
    final h = Rules.starHint(b, 0, cap)!;
    expect(h, contains('sağ üstünde'));
    expect(h, contains('Soğuk'));
    // Hemen yanına koy.
    b.hiddenStar = b.idx(b.xOf(cap), b.yOf(cap) - 4);
    expect(Rules.starHint(b, 0, cap), contains('Yanıyorsun'));
  });
}
