import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/models.dart';
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

  void _restart() {
    setState(() {
      c.dispose();
      c = GameController(widget.players);
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
              return Column(
                children: [
                  _TopBar(c: c),
                  Expanded(child: _buildBoard()),
                  _BottomPanel(c: c, onRestart: _restart),
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
                if (c.phase == Phase.bitti) _GameOverBanner(c: c),
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
    final canToss = c.phase == Phase.atis && c.humanTurn;
    final showResult = c.face != null && c.phase != Phase.atiliyor;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 4, 12, 8),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShakeBox(
                enabled: canToss,
                onShake: c.shake,
                onRelease: c.tossByHuman,
                child: MatchboxView(
                  key: const ValueKey('kibrit'),
                  face: c.face,
                  tossId: c.tossId,
                  duration: GameController.tossDuration,
                  onTap: canToss ? c.tossByHuman : null,
                ),
              ),
              SizedBox(
                height: 22,
                child: Text(
                  showResult
                      ? '${c.face!.label} = ${c.need}'
                      : (canToss && c.shakes > 0 ? 'Salla: ${c.shakes}' : ''),
                  style: t.titleMedium?.copyWith(
                    color: Sprites.glowOf(c.current),
                    shadows: [
                      Shadow(color: Sprites.glowOf(c.current), blurRadius: 8),
                    ],
                  ),
                ),
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
    if (c.phase == Phase.atis && c.humanTurn) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: c.tossByHuman,
          icon: const Icon(Icons.casino_outlined),
          label: _fit('Kibriti at'),
        ),
      );
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
  const _GameOverBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = c.winner;
    final won = w != null && w >= 0;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 2.2, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Transform.rotate(
          angle: -0.14,
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 215,
                  height: 215,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Night.deep.withAlpha(215),
                  ),
                ),
                Image.asset(Sprites.stamp, fit: BoxFit.contain),
                Padding(
                  padding: const EdgeInsets.all(54),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (won) CharacterAvatar(id: w, size: 66),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          c.message,
                          textAlign: TextAlign.center,
                          style: t.headlineMedium?.copyWith(
                            color: const Color(0xFFFF4A3D),
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(color: Color(0xFFFF2A1A), blurRadius: 12),
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
    );
  }
}
