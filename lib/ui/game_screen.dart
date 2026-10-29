import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/models.dart';
import '../game/progress.dart';
import '../game/rules.dart';
import 'board_painter.dart';
import 'matchbox.dart';
import 'paper.dart';
import 'shake_box.dart';
import 'sprites.dart';

class GameScreen extends StatefulWidget {
  final List<Player> players;
  const GameScreen({super.key, required this.players});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController c = GameController(widget.players);
  int _paintVersion = 0;
  final _boardKey = GlobalKey();

  /// Testler için.
  GameController get controller => c;

  // Oyun sonu: kazanılan yıldızlar kaydedilir.
  bool _saved = false;
  Progress? _after;
  bool _rankUp = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  Future<void> _onChange() async {
    if (c.phase != Phase.bitti || _saved) return;
    _saved = true;
    final before = await Progress.load();
    final after = await Progress.addGame(stars: c.stars, place: c.myPlace);
    if (!mounted) return;
    setState(() {
      _after = after;
      _rankUp = after.rankIndex > before.rankIndex;
    });
  }

  void _restart() {
    setState(() {
      c.removeListener(_onChange);
      c.dispose();
      for (final p in widget.players) {
        p.alive = true;
      }
      c = GameController(widget.players)..addListener(_onChange);
      _saved = false;
      _after = null;
      _rankUp = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Sprites.precacheAll(context);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  // Parmak hareketi: dokunma mı sürükleme mi, kendimiz ayırt ediyoruz.
  Offset? _down;
  Offset? _last;
  bool _moved = false;

  /// Ekran konumunu defterin kendi koordinatına çevir.
  Offset? _local(Offset global) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global);
  }

  Size _boardSize(Size fallback) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    return (box != null && box.hasSize) ? box.size : fallback;
  }

  void _onDown(Offset p) {
    _down = p;
    _last = p;
    _moved = false;
  }

  void _onMove(Offset p, Size size) {
    final down = _down;
    if (down == null) return;
    final cell = size.width / c.board.w;
    if (!_moved) {
      if ((p - down).distance < cell * 0.35) return;
      _moved = true;
      final i = _cellAt(down, size);
      if (i != null) c.dragCell(i);
    }
    // Hızlı kaydırmada aradaki kareler atlanmasın.
    final from = _last!;
    final steps = ((p - from).distance / (cell / 3)).ceil().clamp(1, 200);
    for (var k = 1; k <= steps; k++) {
      final q = Offset.lerp(from, p, k / steps)!;
      final i = _cellAt(q, size);
      if (i != null) c.dragCell(i);
    }
    _last = p;
  }

  void _onUp(Size size) {
    final down = _down;
    if (down != null && !_moved) {
      final i = _cellAt(down, size);
      if (i != null) c.tapCell(i);
    }
    _down = null;
  }

  int? _cellAt(Offset local, Size size) {
    final b = c.board;
    final x = (local.dx / size.width * b.w).floor();
    final y = (local.dy / size.height * b.h).floor();
    if (x < 0 || y < 0 || x >= b.w || y >= b.h) return null;
    return b.idx(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotebookBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              _paintVersion++;
              return Stack(
                children: [
                  Column(
                    children: [
                      _TopBar(c: c),
                      Expanded(child: _buildBoard()),
                      _BottomPanel(c: c, onRestart: _restart),
                    ],
                  ),
                  // Sıra sende: kutu ortada büyük.
                  Positioned.fill(
                    // Kaybolurken alttaki deftere dokunmayı engellemesin.
                    child: IgnorePointer(
                      ignoring: !c.bigToss,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        // Kutu sol alttaki yerinden kalkar, oraya geri döner.
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: anim,
                            alignment: const Alignment(-0.72, 0.86),
                            child: child,
                          ),
                        ),
                      child: c.bigToss
                          ? _BigToss(key: const ValueKey('ortada'), c: c)
                          : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final b = c.board;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 8, 4),
      child: Center(
        child: AspectRatio(
          aspectRatio: b.w / b.h,
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return Stack(
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    final p = _local(e.position);
                    if (p != null) _onDown(p);
                  },
                  onPointerMove: (e) {
                    final p = _local(e.position);
                    if (p != null) _onMove(p, _boardSize(size));
                  },
                  onPointerUp: (_) => _onUp(_boardSize(size)),
                  onPointerCancel: (_) => _down = null,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Paper.gridLine, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Night.ember.withAlpha(70),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      key: _boardKey,
                      size: size,
                      painter: BoardPainter(
                        board: b,
                        players: c.players,
                        selection: c.selection,
                        kind: c.kind,
                        current: c.current,
                        valid: c.humanTurn && c.phase == Phase.secim
                            ? c.valid
                            : const <int>{},
                        dropped: c.lastDropped,
                        version: _paintVersion,
                      ),
                    ),
                  ),
                ),
                ..._flags(size),
                if (c.phase == Phase.bitti)
                  Positioned.fill(
                    child: _GameOverBanner(
                        c: c, after: _after, rankUp: _rankUp),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

extension on _GameScreenState {
  /// Her başkentin üstüne altın bayrak.
  List<Widget> _flags(Size size) {
    final b = c.board;
    final cw = size.width / b.w;
    final ch = size.height / b.h;
    return [
      for (final p in c.players)
        if (p.alive && p.capital >= 0 && b.cells[p.capital] == p.id)
          Positioned(
            left: b.xOf(p.capital) * cw - cw * 0.3,
            top: (b.yOf(p.capital) + 1) * ch - ch * 1.9,
            width: cw * 1.7,
            height: ch * 1.9,
            child: IgnorePointer(
              child: Image.asset(
                Sprites.flag,
                fit: BoxFit.contain,
                alignment: Alignment.bottomLeft,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
    ];
  }
}

class _TopBar extends StatelessWidget {
  final GameController c;
  const _TopBar({required this.c});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Night.text,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text('Tur ${c.round}/${Rules.maxRounds}',
                  style: t.titleLarge?.copyWith(color: Night.gold)),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final p in c.players) _PlayerChip(c: c, p: p),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final GameController c;
  final Player p;
  const _PlayerChip({required this.c, required this.p});

  @override
  Widget build(BuildContext context) {
    final active = c.current == p.id && c.phase != Phase.bitti;
    final t = Theme.of(context).textTheme;
    final glow = Sprites.glowOf(p.id);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 34,
      padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
      decoration: BoxDecoration(
        color: active ? glow.withAlpha(45) : Colors.black.withAlpha(60),
        border: Border.all(
            color: p.alive ? glow : Night.dim.withAlpha(90),
            width: active ? 2 : 1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: active
            ? [BoxShadow(color: glow.withAlpha(140), blurRadius: 14)]
            : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CharacterAvatar(id: p.id, size: 28, active: active, alive: p.alive),
          const SizedBox(width: 4),
          Text(
            p.alive ? '${p.name} · ${c.countOf(p.id)}' : p.name,
            style: t.titleMedium?.copyWith(
              color: p.alive ? glow : Night.dim,
              height: 1,
              decoration: p.alive ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final GameController c;
  final VoidCallback onRestart;
  const _BottomPanel({required this.c, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final showResult = c.face != null &&
        c.phase != Phase.atiliyor &&
        c.phase != Phase.atis;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 4, 12, 8),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 124,
                height: 116,
                child: c.bigToss
                    ? null
                    : Center(
                        child: MatchboxView(
                          face: c.face,
                          tossId: c.tossId,
                          duration: GameController.tossDuration,
                        ),
                      ),
              ),
              SizedBox(
                height: 24,
                width: 124,
                child: showResult
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                        '${c.face!.label}: ${c.need} kare',
                        style: t.titleMedium?.copyWith(
                          color: Sprites.glowOf(c.current),
                          shadows: [
                            Shadow(
                                color: Sprites.glowOf(c.current),
                                blurRadius: 8),
                          ],
                        ),
                      ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sabit yükseklik: mesaj uzayınca defter kaymasın.
                SizedBox(
                  height: 72,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CharacterAvatar(id: c.current, size: 54, active: true),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(c.message,
                              style: t.titleMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(height: 48, child: _buttons(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// İki düğmeyi her ekran genişliğinde tek satıra sığdırır.
  Widget _pair(Widget a, Widget b) {
    return Row(children: [
      Flexible(child: a),
      const SizedBox(width: 8),
      Flexible(flex: 2, child: b),
    ]);
  }

  Widget _fit(String text) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));

  Widget _buttons(BuildContext context) {
    const pad = EdgeInsets.symmetric(horizontal: 12);
    if (c.phase == Phase.bitti) {
      return _pair(
        OutlinedButton(
          style: OutlinedButton.styleFrom(padding: pad),
          onPressed: () => Navigator.of(context).pop(),
          child: _fit('Menü'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(padding: pad),
          onPressed: onRestart,
          child: _fit('Tekrar oyna'),
        ),
      );
    }
    if (c.bigToss) {
      return const SizedBox.shrink(); // düğme ortadaki kutunun altında
    }
    if (c.phase == Phase.secim) {
      return _pair(
        OutlinedButton(
          style: OutlinedButton.styleFrom(padding: pad),
          onPressed: c.selection.isEmpty ? null : c.undo,
          child: _fit('Geri al'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(padding: pad),
          onPressed: c.canConfirm ? c.confirm : null,
          child: _fit('Onayla ${c.selection.length}/${c.need}'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _GameOverBanner extends StatelessWidget {
  final GameController c;
  final Progress? after;
  final bool rankUp;
  const _GameOverBanner({required this.c, this.after, this.rankUp = false});

  static const _medals = [
    Color(0xFFFFC94A), // altın
    Color(0xFFD9DEE6), // gümüş
    Color(0xFFE09A5B), // bronz
    Color(0xFF8A7A66),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = c.winner;
    final won = w != null && w >= 0;
    final baseStars = c.stars - (c.bonusStar ? 1 : 0);
    return Container(
      color: Colors.black.withAlpha(150),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Damga
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 2.2, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Transform.rotate(
                angle: -0.14,
                child: SizedBox(
                  width: 170,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 146,
                        height: 146,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Night.deep.withAlpha(225),
                        ),
                      ),
                      Image.asset(Sprites.stamp, fit: BoxFit.contain),
                      Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (won) CharacterAvatar(id: w, size: 44),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                c.message,
                                textAlign: TextAlign.center,
                                style: t.titleLarge?.copyWith(
                                  color: const Color(0xFFFF4A3D),
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                    Shadow(
                                        color: Color(0xFFFF2A1A),
                                        blurRadius: 12),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Sonuç kartı
            Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: Night.wood.withAlpha(240),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Night.gold.withAlpha(160), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Night.ember.withAlpha(90), blurRadius: 22),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Yıldızlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        _PopStar(filled: i < baseStars, delayIndex: i),
                      if (c.bonusStar) ...[
                        const SizedBox(width: 6),
                        const _PopStar(filled: true, delayIndex: 3, bonus: true),
                      ],
                    ],
                  ),
                  Text(
                    c.stars == 0
                        ? 'Bu sefer yıldız yok'
                        : '+${c.stars} yıldız${c.bonusStar ? ' (Zor bonusu dahil)' : ''}',
                    style: t.titleMedium?.copyWith(color: Night.gold),
                  ),
                  const Divider(color: Colors.white24, height: 14),
                  Text('Sıralama',
                      style: t.titleMedium?.copyWith(color: Night.dim)),
                  for (var k = 0; k < c.ranking.length; k++)
                    _rankRow(context, k, c.ranking[k]),
                  if (after != null) ...[
                    const Divider(color: Colors.white24, height: 16),
                    if (rankUp)
                      Text('Yeni rütbe: ${after!.rankName}!',
                          style: t.titleLarge?.copyWith(
                            color: Night.gold,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(color: Night.ember, blurRadius: 14),
                            ],
                          )),
                    RankBar(p: after!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankRow(BuildContext context, int k, int id) {
    final t = Theme.of(context).textTheme;
    final p = c.players[id];
    final me = !p.isBot;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: me ? Sprites.glowOf(id).withAlpha(40) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('${k + 1}.',
                style: t.titleLarge?.copyWith(
                  color: _medals[k.clamp(0, 3)],
                  fontWeight: FontWeight.w800,
                )),
          ),
          CharacterAvatar(id: id, size: 30),
          const SizedBox(width: 6),
          Expanded(
            child: Text(p.name,
                style: t.titleMedium?.copyWith(color: Sprites.glowOf(id))),
          ),
          Text('${c.countOf(id)} kare',
              style: t.bodyMedium?.copyWith(color: Night.dim)),
        ],
      ),
    );
  }
}

/// Sırayla "pıt" diye beliren yıldız.
class _PopStar extends StatelessWidget {
  final bool filled;
  final int delayIndex;
  final bool bonus;
  const _PopStar(
      {required this.filled, required this.delayIndex, this.bonus = false});

  @override
  Widget build(BuildContext context) {
    final start = 0.15 + delayIndex * 0.18;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, v, _) {
        final local = ((v - start) / 0.25).clamp(0.0, 1.0);
        final scale = filled ? Curves.elasticOut.transform(local) : 1.0;
        return Transform.scale(
          scale: filled ? scale : 1,
          child: Icon(
            Icons.star_rounded,
            size: bonus ? 34 : 46,
            color: filled
                ? (bonus ? Night.ember : Night.gold)
                : Colors.white.withAlpha(40),
            shadows: filled
                ? const [Shadow(color: Night.ember, blurRadius: 16)]
                : null,
          ),
        );
      },
    );
  }
}

/// Toplam yıldız, rütbe ve sonraki rütbeye ilerleme.
class RankBar extends StatelessWidget {
  final Progress p;
  const RankBar({required this.p});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final next = p.nextRank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Night.gold, size: 20),
            Text(' ${p.stars}  ·  ${p.rankName}',
                style: t.titleMedium?.copyWith(color: Night.text)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p.progressToNext,
            minHeight: 8,
            color: Night.gold,
            backgroundColor: Colors.white12,
          ),
        ),
        if (next != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('${next.$2} için ${next.$1 - p.stars} yıldız daha',
                style: t.bodySmall?.copyWith(color: Night.dim)),
          ),
      ],
    );
  }
}

/// Kutu sallanırken köşede büyüyen sayaç.
class _ShakeCounter extends StatelessWidget {
  final int count;
  const _ShakeCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 1.6, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Night.gold,
          boxShadow: const [BoxShadow(color: Night.ember, blurRadius: 12)],
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: Night.deep,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// "⟵ salla ⟶" diye sağa sola kayan ipucu.
class _ShakeHint extends StatefulWidget {
  final bool big;
  const _ShakeHint({this.big = false});

  @override
  State<_ShakeHint> createState() => _ShakeHintState();
}

class _ShakeHintState extends State<_ShakeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) => Transform.translate(
        offset: Offset(
            (Curves.easeInOut.transform(_a.value) - 0.5) * (widget.big ? 24 : 14),
            0),
        child: child,
      ),
      child: Text(
        '⟵ salla ⟶',
        style: TextStyle(
          color: Night.gold,
          fontSize: widget.big ? 26 : 16,
          fontWeight: FontWeight.w700,
          shadows: const [Shadow(color: Night.ember, blurRadius: 8)],
        ),
      ),
    );
  }
}

/// Sıra sende olunca ekranın ortasında büyük, sallanabilen kibrit kutusu.
class _BigToss extends StatelessWidget {
  final GameController c;
  const _BigToss({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final canToss = c.phase == Phase.atis;
    final landed = c.phase == Phase.sonuc && c.face != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: landed ? c.acceptResult : null,
      child: Container(
      color: Colors.black.withAlpha(165),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CharacterAvatar(id: c.current, size: 54, active: true),
              const SizedBox(width: 8),
              Text('Sıra sende!',
                  style: t.headlineMedium?.copyWith(
                    color: Night.gold,
                    fontWeight: FontWeight.w800,
                    shadows: const [Shadow(color: Night.ember, blurRadius: 16)],
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ShakeBox(
            enabled: canToss,
            onShake: c.shake,
            onRelease: c.tossByHuman,
            child: SizedBox(
              width: 300,
              height: 280,
              child: FittedBox(
                child: SizedBox(
                  width: 124,
                  height: 116,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      MatchboxView(
                        key: const ValueKey('kibrit'),
                        face: c.face,
                        tossId: c.tossId,
                        duration: GameController.tossDuration,
                        onTap: canToss
                            ? c.tossByHuman
                            : (landed ? c.acceptResult : null),
                      ),
                      if (canToss && c.shakes > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: _ShakeCounter(count: c.shakes),
                        ),
                      // Düştüğü yüzün sayısı kutunun üstünde.
                      if (landed)
                        Positioned(
                          top: -10,
                          right: -10,
                          child: _FaceNumber(n: c.need),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: canToss
                ? (c.shakes == 0
                    ? const _ShakeHint(big: true)
                    : Text('Bırakınca atılır',
                        style: t.titleMedium?.copyWith(color: Night.dim)))
                : (landed ? _TossResult(c: c) : null),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: canToss
                ? FilledButton.icon(
                    onPressed: c.tossByHuman,
                    icon: const Icon(Icons.casino_outlined),
                    label: const Text('Kibriti at'),
                  )
                : (landed ? const _TapHint() : null),
          ),
        ],
      ),
      ),
    );
  }
}

/// Kutu yere düşünce çıkan büyük sonuç yazısı.
class _TossResult extends StatefulWidget {
  final GameController c;
  const _TossResult({required this.c});

  @override
  State<_TossResult> createState() => _TossResultState();
}

class _TossResultState extends State<_TossResult> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.c.face;
    if (f == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedScale(
        scale: _visible ? 1 : 0.6,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: Text(
          '${f.label} geldi: ${f.squares} kare!',
          style: t.headlineSmall?.copyWith(
            color: Night.gold,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Night.ember, blurRadius: 14)],
          ),
        ),
      ),
    );
  }
}

/// Kutunun üstünde duran büyük sayı.
class _FaceNumber extends StatelessWidget {
  final int n;
  const _FaceNumber({required this.n});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Night.gold,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Night.ember, blurRadius: 16)],
        ),
        child: Text(
          '$n',
          style: const TextStyle(
            color: Night.deep,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// "Devam etmek için dokun" — yanıp sönen ipucu.
class _TapHint extends StatefulWidget {
  const _TapHint();

  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_a),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, color: Night.text),
          SizedBox(width: 6),
          Text('Devam etmek için dokun',
              style: TextStyle(color: Night.text, fontSize: 17)),
        ],
      ),
    );
  }
}
