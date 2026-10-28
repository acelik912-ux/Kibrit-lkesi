import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kibrit_ulke/game/controller.dart';
import 'package:kibrit_ulke/game/models.dart';
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

        // Deftere dokun: alttaki ülkenin hemen üstündeki boş kare.
        final board = find.byType(CustomPaint).last;
        expect(board, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        // Ekranı kapat; bekleyen zamanlayıcılar sorun çıkarmasın.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }

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
