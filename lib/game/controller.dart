import 'dart:math';

import 'package:flutter/foundation.dart';

import 'bot.dart';
import 'models.dart';
import 'rules.dart';

enum Phase { atis, atiliyor, secim, botOynuyor, bitti }

/// Oyunun akışını yönetir: sıra, kibrit atışı, seçim, botlar.
class GameController extends ChangeNotifier {
  static const tossDuration = Duration(milliseconds: 1400);

  final List<Player> players;
  final Random rng;
  late Board board;

  int current = 0;
  int round = 1;
  Phase phase = Phase.atis;
  MatchFace? face;

  /// Her atışta artar; kibrit animasyonu bunu dinler.
  int tossId = 0;

  /// Bu turda kutu kaç kez sallandı.
  int shakes = 0;
  List<int> selection = [];
  Set<int> valid = {};
  List<int> lastDropped = [];
  String message = '';

  /// Kazanan oyuncu; -1 = insan oyuncu elendi.
  int? winner;

  /// Oyundan düşenler, düşme sırasıyla.
  final List<int> eliminated = [];

  /// Oyun bitince: 1., 2., 3. ... sırasıyla oyuncu numaraları.
  List<int> ranking = [];

  /// Senin bu oyunda kazandığın yıldız (bonus dahil).
  int stars = 0;

  /// Zor seviyede birinci olunca verilen ek yıldız.
  bool bonusStar = false;
  bool _disposed = false;

  GameController(this.players, {Random? random}) : rng = random ?? Random() {
    board = Rules.setup(players);
    _startTurn();
  }

  Player get me => players[current];
  int get need => face?.squares ?? 0;
  bool get humanTurn => !me.isBot;
  MoveKind? get kind => Rules.kindOf(board, selection);

  bool get canConfirm =>
      phase == Phase.secim &&
      selection.isNotEmpty &&
      (selection.length == need || valid.isEmpty);

  int countOf(int p) => board.count(p);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _wait(Duration d) => Future.delayed(d);

  void _startTurn() {
    selection = [];
    valid = {};
    face = null;
    shakes = 0;
    if (me.isBot) {
      message = '${me.name} kibrit kutusunu atıyor…';
      _toss();
    } else {
      phase = Phase.atis;
      message = 'Sıra sende: kutuyu salla, sonra at';
      _notify();
    }
  }

  /// İnsan oyuncu kutuya dokunduğunda.
  void tossByHuman() {
    if (phase != Phase.atis || me.isBot) return;
    _toss(lucky: shakes == Rules.luckyShakes);
  }

  /// Kutu parmakla bir kez sağa sola sallandı.
  void shake() {
    if (phase != Phase.atis || me.isBot) return;
    shakes++;
    message = 'Salladın: $shakes';
    _notify();
  }

  Future<void> _toss({bool lucky = false}) async {
    face = Rules.toss(rng, lucky: lucky);
    phase = Phase.atiliyor;
    tossId++;
    _notify();
    await _wait(tossDuration);
    if (_disposed) return;
    if (me.isBot) {
      await _botPlay();
    } else {
      _beginHumanSelection();
    }
  }

  void _beginHumanSelection() {
    phase = Phase.secim;
    valid = Rules.validNext(board, players, current, selection);
    if (valid.isEmpty) {
      message = 'Oynayacak kare yok, sıra geçiyor';
      _notify();
      _passAfterDelay();
      return;
    }
    message = '${face!.label} geldi: $need kare. '
        'Boş kare → ekle, rakip kare → kes';
    _notify();
  }

  Future<void> _passAfterDelay() async {
    await _wait(const Duration(milliseconds: 1200));
    if (_disposed) return;
    _next();
  }

  // ---- İnsan oyuncunun seçimleri ----

  void tapCell(int i) {
    if (phase != Phase.secim) return;
    if (selection.isNotEmpty && selection.last == i) {
      undo();
      return;
    }
    _tryAdd(i);
  }

  void dragCell(int i) {
    if (phase != Phase.secim) return;
    _tryAdd(i);
  }

  void _tryAdd(int i) {
    if (selection.contains(i) || selection.length >= need) return;
    if (!valid.contains(i)) return;
    selection.add(i);
    _refreshValid();
  }

  void undo() {
    if (phase != Phase.secim || selection.isEmpty) return;
    selection.removeLast();
    _refreshValid();
  }

  void _refreshValid() {
    valid = selection.length < need
        ? Rules.validNext(board, players, current, selection)
        : <int>{};
    final left = need - selection.length;
    if (selection.isEmpty) {
      message = '$need kare: boş kare → ekle, rakip kare → kes';
    } else if (left > 0 && valid.isNotEmpty) {
      message = kind == MoveKind.ekle
          ? '$left kare daha ekle'
          : '$left kare daha kes';
    } else {
      message = 'Hazır! Onayla';
    }
    _notify();
  }

  void confirm() {
    if (!canConfirm) return;
    _commit();
  }

  // ---- Botlar ----

  Future<void> _botPlay() async {
    phase = Phase.botOynuyor;
    message = '${me.name}: ${face!.label} geldi, $need kare';
    _notify();
    await _wait(const Duration(milliseconds: 350));
    final move = Bot.chooseMove(board, players, current, need, rng);
    if (move.isEmpty) {
      message = '${me.name} oynayamadı, pas';
      _notify();
      _passAfterDelay();
      return;
    }
    for (final c in move) {
      if (_disposed) return;
      selection.add(c);
      _notify();
      await _wait(const Duration(milliseconds: 220));
    }
    await _wait(const Duration(milliseconds: 350));
    if (_disposed) return;
    _commit();
  }

  // ---- Ortak ----

  void _commit() {
    final mover = me;
    final res = Rules.apply(board, players, current, selection);
    lastDropped = res.dropped;
    final verb = res.kind == MoveKind.ekle ? 'ekledi' : 'kesti';
    final who = mover.isBot ? mover.name : 'Sen';
    final verbYou = res.kind == MoveKind.ekle ? 'ekledin' : 'kestin';
    message = mover.isBot
        ? '$who ${selection.length} kare $verb'
        : '$who ${selection.length} kare $verbYou';
    if (res.victim != null) {
      final v = players[res.victim!];
      if (res.victimEliminated) {
        v.alive = false;
        eliminated.add(v.id);
        message = v.isBot
            ? '${v.name} başkentini kaybetti, oyundan çıktı!'
            : 'Başkentin düştü!';
      } else if (res.dropped.isNotEmpty) {
        message += ' · ${v.isBot ? v.name : "senin"} '
            '${res.dropped.length} karen koptu';
        if (v.isBot) {
          message = message.replaceFirst('karen koptu', 'karesi koptu');
        }
      }
    }
    selection = [];
    valid = {};
    phase = Phase.botOynuyor; // geçiş anında dokunmayı kapat
    _notify();
    _afterMove();
  }

  Future<void> _afterMove() async {
    await _wait(const Duration(milliseconds: 900));
    if (_disposed) return;
    _next();
  }

  void _next() {
    final alive = players.where((p) => p.alive).toList();
    final human = players.firstWhere((p) => !p.isBot);
    if (!human.alive) {
      _finish(-1);
      return;
    }
    if (alive.length == 1) {
      _finish(alive.first.id);
      return;
    }
    var n = current;
    do {
      n = (n + 1) % players.length;
      if (n == 0) round++;
    } while (!players[n].alive);
    if (round > Rules.maxRounds) {
      round = Rules.maxRounds;
      // Tur sınırı: en büyük ülke kazanır.
      alive.sort((a, b) => countOf(b.id).compareTo(countOf(a.id)));
      _finish(alive.first.id);
      return;
    }
    current = n;
    _startTurn();
  }

  /// Sıralama: ayakta kalanlar büyüklüğe göre, sonra en son düşenden
  /// ilk düşene doğru.
  List<int> _computeRanking() {
    final alive = players.where((p) => p.alive).map((p) => p.id).toList()
      ..sort((a, b) => countOf(b).compareTo(countOf(a)));
    return [...alive, ...eliminated.reversed];
  }

  /// 1. → 3 yıldız, 2. → 2, 3. → 1; sonuncu yıldız alamaz.
  static int starsFor(int place, int playerCount) {
    if (place >= playerCount) return 0;
    return (4 - place).clamp(0, 3);
  }

  int get myPlace => ranking.indexOf(0) + 1;

  void _finish(int w) {
    final human = players.firstWhere((p) => !p.isBot);
    if (!human.alive && !eliminated.contains(human.id)) {
      eliminated.add(human.id);
    }
    ranking = _computeRanking();
    if (w >= 0 && ranking.isNotEmpty && ranking.first != w) {
      ranking
        ..remove(w)
        ..insert(0, w);
    }
    stars = starsFor(myPlace, players.length);
    bonusStar = myPlace == 1 &&
        players.where((p) => p.isBot).every((p) => p.level == BotLevel.zor);
    if (bonusStar) stars++;
    winner = w;
    phase = Phase.bitti;
    if (w == -1) {
      message = 'Ülken haritadan silindi';
    } else if (players[w].isBot) {
      message = '${players[w].name} kazandı';
    } else {
      message = 'Kazandın!';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
