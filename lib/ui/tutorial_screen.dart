import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'paper.dart';

/// "Nasıl oynanır?" sesli tanıtım videosu.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  static const asset = 'assets/video/nasil_oynanir.mp4';

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final VideoPlayerController _v =
      VideoPlayerController.asset(TutorialScreen.asset);
  bool _ready = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _v.addListener(_tick);
    _v.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _v.play();
    }).catchError((_) {});
  }

  void _tick() {
    final v = _v.value;
    final ended =
        v.isInitialized && !v.isPlaying && v.position >= v.duration - const Duration(milliseconds: 300);
    if (ended != _ended) setState(() => _ended = ended);
  }

  @override
  void dispose() {
    _v.removeListener(_tick);
    _v.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_ended) {
        _v.seekTo(Duration.zero);
        _v.play();
      } else if (_v.value.isPlaying) {
        _v.pause();
      } else {
        _v.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _ready
                  ? GestureDetector(
                      onTap: _toggle,
                      child: AspectRatio(
                        aspectRatio: _v.value.aspectRatio,
                        child: VideoPlayer(_v),
                      ),
                    )
                  : const CircularProgressIndicator(color: Night.gold),
            ),
            // Duraklatınca ya da bitince ortada düğme
            if (_ready && (!_v.value.isPlaying || _ended))
              Center(
                child: GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha(150),
                      border: Border.all(color: Night.gold, width: 2),
                    ),
                    child: Icon(
                      _ended ? Icons.replay_rounded : Icons.play_arrow_rounded,
                      size: 52,
                      color: Night.gold,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              left: 6,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 30),
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (_ready)
              Positioned(
                left: 12,
                right: 12,
                bottom: 6,
                child: VideoProgressIndicator(
                  _v,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Night.gold,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            if (_ended)
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Night.gold,
                      foregroundColor: Night.deep,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                    ),
                    child: const Text('Oyuna dön',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
