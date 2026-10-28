import 'dart:math';

import 'package:flutter/material.dart';

import '../game/models.dart';
import '../game/rules.dart';
import 'paper.dart';

/// Kareli defteri, ülkeleri, başkentleri ve seçimi çizer.
class BoardPainter extends CustomPainter {
  final Board board;
  final List<Player> players;
  final List<int> selection;
  final MoveKind? kind;
  final int current;
  final Set<int> valid;
  final List<int> dropped;
  final int version;

  BoardPainter({
    required this.board,
    required this.players,
    required this.selection,
    required this.kind,
    required this.current,
    required this.valid,
    required this.dropped,
    required this.version,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / board.w;
    final ch = size.height / board.h;
    Rect cellRect(int i) =>
        Rect.fromLTWH(board.xOf(i) * cw, board.yOf(i) * ch, cw, ch);

    canvas.drawRect(Offset.zero & size, Paint()..color = Paper.background);

    // Silgi izi: son hamlede kopan kareler.
    final eraser = Paint()..color = Paper.pencil.withAlpha(38);
    for (final i in dropped) {
      if (board.cells[i] < 0) canvas.drawRect(cellRect(i).deflate(1), eraser);
    }

    // Ülkelerin içi: açık dolgu + kalem taraması.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < board.cells.length; i++) {
      final o = board.cells[i];
      if (o < 0) continue;
      final color = players[o].color;
      final r = cellRect(i);
      canvas.drawRect(r, Paint()..color = color.withAlpha(46));
      final hatch = Paint()
        ..color = color.withAlpha(110)
        ..strokeWidth = 0.9;
      canvas.drawLine(r.bottomLeft, r.topRight, hatch);
    }
    canvas.restore();

    // Kareli çizgiler.
    final grid = Paint()
      ..color = Paper.gridLine
      ..strokeWidth = 0.6;
    for (var x = 0; x <= board.w; x++) {
      canvas.drawLine(Offset(x * cw, 0), Offset(x * cw, size.height), grid);
    }
    for (var y = 0; y <= board.h; y++) {
      canvas.drawLine(Offset(0, y * ch), Offset(size.width, y * ch), grid);
    }

    // Ülke sınırları: tükenmez kalemle çizilmiş gibi.
    for (var i = 0; i < board.cells.length; i++) {
      final o = board.cells[i];
      if (o < 0) continue;
      final pen = Paint()
        ..color = players[o].color
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final r = cellRect(i);
      final x = board.xOf(i);
      final y = board.yOf(i);
      bool diff(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= board.w || ny >= board.h) return true;
        return board.cells[board.idx(nx, ny)] != o;
      }

      if (diff(x, y - 1)) canvas.drawLine(r.topLeft, r.topRight, pen);
      if (diff(x, y + 1)) canvas.drawLine(r.bottomLeft, r.bottomRight, pen);
      if (diff(x - 1, y)) canvas.drawLine(r.topLeft, r.bottomLeft, pen);
      if (diff(x + 1, y)) canvas.drawLine(r.topRight, r.bottomRight, pen);
    }

    // Başkentler.
    for (final p in players) {
      if (!p.alive || p.capital < 0) continue;
      final r = cellRect(p.capital);
      _star(canvas, r.center, min(cw, ch) * 0.42, p.color);
    }

    // Seçilebilir kareler: küçük kurşun kalem noktası.
    final dot = Paint()..color = Paper.pencil.withAlpha(150);
    for (final i in valid) {
      canvas.drawCircle(cellRect(i).center, min(cw, ch) * 0.11, dot);
    }

    // Seçim.
    final myColor = players[current].color;
    for (var k = 0; k < selection.length; k++) {
      final r = cellRect(selection[k]).deflate(min(cw, ch) * 0.12);
      if (kind == MoveKind.ekle) {
        canvas.drawRect(r, Paint()..color = myColor.withAlpha(150));
        canvas.drawRect(
            r,
            Paint()
              ..color = myColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6);
      } else {
        final x = Paint()
          ..color = myColor
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(r.topLeft, r.bottomRight, x);
        canvas.drawLine(r.topRight, r.bottomLeft, x);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double radius, Color color) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rr = k.isEven ? radius : radius * 0.45;
      final a = -pi / 2 + k * pi / 5;
      final p = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
