import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kibrit_ulke/game/controller.dart';
import 'package:kibrit_ulke/game/models.dart';
import 'package:kibrit_ulke/ui/board_painter.dart';
import 'package:kibrit_ulke/ui/game_screen.dart';
import 'package:kibrit_ulke/ui/menu_screen.dart';

List<Player> makePlayers(int bots) => [
      Player(id: 0, name: 'Sen', color: kPenColors[0], isBot: false),
      for (var i = 0; i < bots; i++)
        Player(
          id: i + 1,
          name: kBotNames[i],
          color: kPenColors[i + 1],
          isBot: true,
          level: BotLevel.values[i % 3],
        ),
    ];

/// Telefon boyutunda ekran (Android, 1080x2400 ~ 412x915 dp).
void phoneSize(WidgetTester tester, {double w = 412, double h = 915}) {
  tester.view.physicalSize = Size(w * 2.625, h * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('menü telefonda taşmadan açılır', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(const MaterialApp(home: MenuScreen()));
    await tester.pump();
    expect(find.text('Kibrit Ülkesi'), findsOneWidget);
    expect(find.text('Oyuna başla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final bots in [1, 2, 3]) {
    for (final size in [const Size(412, 915), const Size(360, 640)]) {
      testWidgets(
          'oyun ekranı $bots bot, ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        phoneSize(tester, w: size.width, h: size.height);
        await tester.pumpWidget(
            MaterialApp(home: GameScreen(players: makePlayers(bots))));
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Kibriti at → animasyon → seçim.
        expect(find.text('Kibriti at'), findsOneWidget);
        await tester.tap(find.text('Kibriti at'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Onayla'), findsOneWidget);

        // Deftere dokun: senin ülkenin hemen üstündeki boş kare seçilmeli.
        final board = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is BoardPainter);
        expect(board, findsOneWidget);
        final painter =
            tester.widget<CustomPaint>(board).painter! as BoardPainter;
        final b = painter.board;
        final cap = painter.players[0].capital;
        final rect = tester.getRect(board);
        final cw = rect.width / b.w;
        final ch = rect.height / b.h;
        final cx = b.xOf(cap);
        final cy = b.yOf(cap) - 3; // ülkenin bir üst satırı
        expect(b.cells[b.idx(cx, cy)], -1);
        await tester.tapAt(Offset(
            rect.left + (cx + 0.5) * cw, rect.top + (cy + 0.5) * ch));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Onayla 1/'), findsOneWidget,
            reason: 'deftere dokununca kare seçilmeli');

        // Onayla → kare ülkeye eklenmiş olmalı.
        final onayla = find.textContaining('Onayla 1/');
        final need = int.parse(
            tester.widget<Text>(onayla).data!.split('/').last);
        // Defter yerinden kaymamalı.
        expect(tester.getRect(board), rect, reason: 'defter kaymamalı');
        if (need > 1) {
          // Kalan kareleri sürükleyerek seç (aynı satırda sağa doğru).
          final start = Offset(
              rect.left + (cx + 0.5) * cw, rect.top + (cy + 0.5) * ch);
          final gesture = await tester.startGesture(
              start + Offset(cw, 0));
          for (var k = 1; k <= need + 2; k++) {
            await gesture.moveTo(start + Offset(cw * k, 0));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await gesture.up();
          await tester.pump(const Duration(milliseconds: 100));
        }
        final dynamic st = tester.state(find.byType(GameScreen));
        final GameController gc = st.controller;
        final diag = ''
            'sel=${gc.selection.map((i) => '(${b.xOf(i)},${b.yOf(i)})').join()} '
            'cap=($cx,${b.yOf(cap)}) phase=${gc.phase} need=${gc.need} '
            'validNext=${gc.valid.contains(b.idx(cx + 1, cy))} '
            'cell=${cw.toStringAsFixed(1)}x${ch.toStringAsFixed(1)} rect=$rect';
        final labels = tester
            .widgetList<Text>(find.textContaining('Onayla'))
            .map((t) => t.data)
            .join(' | ');
        expect(find.text('Onayla $need/$need'), findsOneWidget,
            reason: 'sürükleyerek seçim çalışmalı, ekranda: $labels | $diag');
        await tester.tap(find.widgetWithText(FilledButton, 'Onayla $need/$need'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(b.cells[b.idx(cx, cy)], 0, reason: 'kare ülkeye eklenmeli');
        expect(tester.takeException(), isNull);

        // Ekranı kapat; bekleyen zamanlayıcılar sorun çıkarmasın.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }

  testWidgets('denetleyici: dokun + sürükle kare ekler', (tester) async {
    final c = GameController(makePlayers(1), random: Random(3));
    c.tossByHuman();
    await tester.pump(const Duration(seconds: 2));
    expect(c.phase, Phase.secim);
    final b = c.board;
    final cap = c.players[0].capital;
    final cx = b.xOf(cap), cy = b.yOf(cap) - 3;
    c.tapCell(b.idx(cx, cy));
    c.dragCell(b.idx(cx + 1, cy));
    expect(c.selection.length, c.need >= 2 ? 2 : 1,
        reason: 'need=${c.need} valid=${c.valid.length}');
    c.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('tam oyun: sen + 3 bot sonuna kadar oynanır', (tester) async {
    final r = Random(42);
    final c = GameController(makePlayers(3), random: Random(7));
    var steps = 0;
    while (c.phase != Phase.bitti && steps < 20000) {
      if (!c.players[0].isBot && c.current == 0) {
        if (c.phase == Phase.atis) c.tossByHuman();
        if (c.phase == Phase.secim) {
          while (c.valid.isNotEmpty && c.selection.length < c.need) {
            final v = c.valid.toList();
            c.tapCell(v[r.nextInt(v.length)]);
          }
          if (c.canConfirm) c.confirm();
        }
      }
      await tester.pump(const Duration(milliseconds: 200));
      steps++;
    }
    expect(c.phase, Phase.bitti);
    expect(c.winner, isNotNull);
    c.dispose();
    await tester.pump(const Duration(seconds: 5));
  });
}
