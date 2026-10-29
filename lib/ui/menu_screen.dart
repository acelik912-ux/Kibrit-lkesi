import 'package:flutter/material.dart';

import '../game/models.dart';
import '../game/progress.dart';
import 'game_screen.dart';
import 'paper.dart';
import 'sprites.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int bots = 1;
  BotLevel level = BotLevel.orta;
  Progress? progress;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final p = await Progress.load();
    if (mounted) setState(() => progress = p);
  }

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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameScreen(players: players)))
        .then((_) => _loadProgress());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: NotebookBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Night.ember.withAlpha(110),
                            blurRadius: 30,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: AspectRatio(
                          aspectRatio: 1.35,
                          child: Image.asset(Sprites.menu, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Kibrit Ülkesi',
                        textAlign: TextAlign.center,
                        style: t.displaySmall?.copyWith(
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Night.gold,
                          shadows: const [
                            Shadow(color: Night.ember, blurRadius: 18),
                          ],
                        )),
                    const SizedBox(height: 6),
                    Text('Defterin ortasında bir ülke, cebinde bir kibrit kutusu',
                        textAlign: TextAlign.center,
                        style: t.titleMedium?.copyWith(color: Night.dim)),
                    if (progress != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(70),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Night.gold.withAlpha(90)),
                        ),
                        child: RankBar(p: progress!),
                      ),
                    ],
                    const SizedBox(height: 22),
                    // Seçilen rakipler masada.
                    SizedBox(
                      height: 78,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 4; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: AnimatedOpacity(
                                opacity: i <= bots ? 1 : 0.18,
                                duration: const Duration(milliseconds: 250),
                                child: CharacterAvatar(
                                    id: i, size: i == 0 ? 74 : 62),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
                        textStyle: t.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        backgroundColor: Night.gold,
                        foregroundColor: Night.deep,
                        shadowColor: Night.ember,
                        elevation: 10,
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
      'Atmadan önce kutuyu parmağınla sağa sola salla, 10\'a kadar. '
          'Doğru sayıyı tutturursan şans senden yana olur!',
      'Boş karelere dokun → ülkene ekle (sınırına bitişik olmalı).',
      'Rakibin karelerine dokun → kes. Ama sadece ülkenin rakibe '
          'değdiği yerden! Önce ülkeni rakibe doğru büyüt.',
      'Ülkesinden kopan parçalar silinir, başkente bağlı kalan yaşar.',
      'Başkent ★ ancak tur başında sınırdaysa kesilebilir; kesilirse ülke düşer.',
      'Son kalan ya da 30. turda en büyük ülke kazanır.',
      'Sıralamana göre yıldız kazanırsın: 1. ⭐⭐⭐, 2. ⭐⭐, 3. ⭐ '
          '(sonuncu yıldız alamaz). Zor botları yenersen +1 bonus!',
      'Yıldız biriktir, rütbe atla: Acemi Çizer → Kalem Ustası → … → '
          'Defter İmparatoru.',
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
            style: t.bodyMedium?.copyWith(color: Night.dim)),
      ],
    );
  }
}
