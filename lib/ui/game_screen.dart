import 'package:flutter/material.dart';

import '../game/controller.dart';
import '../game/models.dart';
import '../game/rules.dart';
import 'board_painter.dart';
import 'matchbox.dart';
import 'paper.dart';

class GameScreen extends StatefulWidget {
  final List<Player> players;
  const GameScreen({super.key, required this.players});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController c = GameController(widget.players);
  int _paintVersion = 0;

  /// Testler için.
  GameController get controller => c;
  int debugMoves = 0;
  int debugDrags = 0;
  final List<String> debugLog = [];

  void _restart() {
    setState(() {
      c.dispose();
      c = GameController(widget.players);
    });
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

  void _onDown(Offset p) {
    _down = p;
    _last = p;
    _moved = false;
  }

  void _onMove(Offset p, Size size) {
    debugMoves++;
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
      if (i != null) {
        debugDrags++;
        final before = c.selection.length;
        c.dragCell(i);
        if (debugLog.length < 30) {
          debugLog.add('(${c.board.xOf(i)},${c.board.yOf(i)})'
              '${c.selection.length > before ? '+' : '-'}');
        }
      }
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
                  onPointerDown: (e) => _onDown(e.localPosition),
                  onPointerMove: (e) => _onMove(e.localPosition, size),
                  onPointerUp: (_) => _onUp(size),
                  onPointerCancel: (_) => _down = null,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Paper.gridLine, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CustomPaint(
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
                if (c.phase == Phase.bitti) _GameOverBanner(c: c),
              ],
            );
          }),
        ),
      ),
    );
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
                color: Paper.ink,
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text('Tur ${c.round}/${Rules.maxRounds}', style: t.titleLarge),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: active ? p.color.withAlpha(40) : Colors.transparent,
        border: Border.all(
            color: p.alive ? p.color : Paper.pencil, width: active ? 2 : 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        p.alive ? '${p.name} · ${c.countOf(p.id)}' : p.name,
        style: t.titleMedium?.copyWith(
          color: p.alive ? p.color : Paper.pencil,
          decoration: p.alive ? null : TextDecoration.lineThrough,
        ),
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
              MatchboxView(
                face: c.face,
                tossId: c.tossId,
                duration: GameController.tossDuration,
                onTap: canToss ? c.tossByHuman : null,
              ),
              SizedBox(
                height: 22,
                child: Text(
                  showResult ? '${c.face!.label} = ${c.need}' : '',
                  style: t.titleMedium?.copyWith(color: c.me.color),
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
                Text(c.message, style: t.titleMedium, maxLines: 3),
                const SizedBox(height: 8),
                _buttons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    if (c.phase == Phase.bitti) {
      return Wrap(spacing: 8, children: [
        FilledButton(onPressed: onRestart, child: const Text('Tekrar oyna')),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Menü'),
        ),
      ]);
    }
    if (c.phase == Phase.atis && c.humanTurn) {
      return FilledButton.icon(
        onPressed: c.tossByHuman,
        icon: const Icon(Icons.casino_outlined),
        label: const Text('Kibriti at'),
      );
    }
    if (c.phase == Phase.secim) {
      return Wrap(spacing: 8, runSpacing: 4, children: [
        OutlinedButton(
          onPressed: c.selection.isEmpty ? null : c.undo,
          child: const Text('Geri al'),
        ),
        FilledButton(
          onPressed: c.canConfirm ? c.confirm : null,
          child: Text('Onayla ${c.selection.length}/${c.need}'),
        ),
      ]);
    }
    return const SizedBox(height: 40);
  }
}

class _GameOverBanner extends StatelessWidget {
  final GameController c;
  const _GameOverBanner({required this.c});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final w = c.winner;
    final color = (w != null && w >= 0) ? c.players[w].color : Paper.margin;
    return Center(
      child: Transform.rotate(
        angle: -0.08,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: Paper.background.withAlpha(235),
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(c.message,
              style: t.displaySmall?.copyWith(color: color)),
        ),
      ),
    );
  }
}
