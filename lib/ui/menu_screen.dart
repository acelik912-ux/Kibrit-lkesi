import 'package:flutter/material.dart';

import '../game/models.dart';
import 'game_screen.dart';
import 'matchbox.dart';
import 'paper.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int bots = 1;
  BotLevel level = BotLevel.orta;

  void _start() {
    final players = <Player>[
      Player(id: 0, name: 'Sen', color: kPenColors[0], isBot: false),
      for (var i = 0; i < bots; i++)
        Player(
          id: i + 1,
          name: kBotNames[i],
          color: kPenColors[i + 1],
          isBot: true,
          level: level,
        ),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(players: players)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: NotebookBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(
                      height: 110,
                      child: Center(
                        child: MatchboxView(face: MatchFace.yan, tossId: 0),
                      ),
                    ),
                    Text('Kibrit Ülkesi',
                        textAlign: TextAlign.center,
                        style: t.displayMedium?.copyWith(height: 1)),
                    const SizedBox(height: 4),
                    Text('Defterin ortasında bir ülke, cebinde bir kibrit kutusu',
                        textAlign: TextAlign.center,
                        style: t.titleMedium?.copyWith(color: Paper.pencil)),
                    const SizedBox(height: 28),
                    Text('Rakip sayısı', style: t.titleLarge),
                    const SizedBox(height: 6),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1 bot')),
                        ButtonSegment(value: 2, label: Text('2 bot')),
                        ButtonSegment(value: 3, label: Text('3 bot')),
                      ],
                      selected: {bots},
                      onSelectionChanged: (s) => setState(() => bots = s.first),
                    ),
                    const SizedBox(height: 18),
                    Text('Zorluk', style: t.titleLarge),
                    const SizedBox(height: 6),
                    SegmentedButton<BotLevel>(
                      segments: [
                        for (final l in BotLevel.values)
                          ButtonSegment(value: l, label: Text(l.label)),
                      ],
                      selected: {level},
                      onSelectionChanged: (s) =>
                          setState(() => level = s.first),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: t.headlineSmall,
                      ),
                      child: const Text('Oyuna başla'),
                    ),
                    const SizedBox(height: 28),
                    const _HowToPlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const rules = [
      'Kibrit kutusunu at: yatık 1, yan 3, dik 6 kare.',
      'Boş karelere dokun → ülkene ekle (sınırına bitişik olmalı).',
      'Rakibin sınırındaki karelere dokun → kes.',
      'Ülkesinden kopan parçalar silinir, başkente bağlı kalan yaşar.',
      'Başkent ★ ancak tur başında sınırdaysa kesilebilir; kesilirse ülke düşer.',
      'Son kalan ya da 30. turda en büyük ülke kazanır.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nasıl oynanır?', style: t.titleLarge),
        const SizedBox(height: 4),
        for (final r in rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $r', style: t.bodyLarge),
          ),
        Text('İpucu: parmağını sürükleyerek birden çok kare seçebilirsin.',
            style: t.bodyMedium?.copyWith(color: Paper.pencil)),
      ],
    );
  }
}
