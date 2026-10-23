import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'sound.dart';
import 'store.dart';
import 'theme.dart';

/// Minimal contract every new arcade game engine implements.
abstract class ArcadeGame {
  bool get over;
  int get score;
  int get level;
  int get elapsedMs;
  void Function(String)? onEvent;
  void update(int dt);
  Map<String, dynamic> toJson();

  /// Score record: s=score v=level n=count d=date(ms) t=duration(ms)
  Map<String, dynamic> record();
}

typedef ShellBuilder = Widget Function(BuildContext context, ArcadeShellState s);

/// Shared game screen: loop, pause, save/resume, exit + game-over dialogs.
class ArcadeShell extends StatefulWidget {
  final String id;
  final bool resume;
  final ArcadeGame Function(Map<String, dynamic>? saved) create;
  final ShellBuilder builder;
  const ArcadeShell({
    super.key,
    required this.id,
    required this.resume,
    required this.create,
    required this.builder,
  });
  @override
  State<ArcadeShell> createState() => ArcadeShellState();
}

class ArcadeShellState extends State<ArcadeShell> with WidgetsBindingObserver {
  late ArcadeGame game;
  final tick = ValueNotifier<int>(0);
  final paused = ValueNotifier<bool>(false);
  final Stopwatch _sw = Stopwatch();
  Timer? _loop;
  int _last = 0, _saveAt = 0;
  bool _overShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    var loaded = false;
    ArcadeGame? g;
    if (widget.resume) {
      final j = Store.load(widget.id);
      if (j != null) {
        try {
          g = widget.create(j);
          loaded = true;
        } catch (_) {
          g = null;
        }
      }
    }
    game = g ?? widget.create(null);
    game.onEvent = Snd.play;
    _sw.start();
    if (loaded) {
      paused.value = true; // resume on tap so the player is ready
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loop?.cancel();
    tick.dispose();
    paused.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !game.over && !paused.value) pause();
  }

  void _start() {
    _loop?.cancel();
    _last = _sw.elapsedMilliseconds;
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _sw.elapsedMilliseconds;
      final dt = min(now - _last, 100);
      _last = now;
      game.update(dt);
      tick.value++;
      if (game.over) {
        _gameOver();
      } else if (game.elapsedMs - _saveAt > 5000) {
        _saveAt = game.elapsedMs;
        Store.save(game.toJson(), widget.id);
      }
    });
  }

  void pause() {
    if (game.over) return;
    _loop?.cancel();
    _loop = null;
    paused.value = true;
    Store.save(game.toJson(), widget.id);
  }

  void resume() {
    paused.value = false;
    _start();
  }

  /// Runs a player action only while the game is live.
  void act(void Function() f) {
    if (paused.value || game.over) return;
    f();
    tick.value++;
  }

  void _gameOver() {
    if (_overShown) return;
    _overShown = true;
    _loop?.cancel();
    _loop = null;
    Store.clearSave(widget.id);
    Store.addScore(game.record(), widget.id);
    showNeonDialog<void>(
      context,
      title: 'GAME OVER',
      message: 'Score ${game.score}\nLevel ${game.level}',
      buttons: (c) => [
        NeonButton('PLAY AGAIN', const Color(0xFF39FF14), () {
          Navigator.pop(c);
          _restart();
        }, width: double.infinity),
        NeonButton('HOME', const Color(0xFFFF2040), () {
          Navigator.pop(c);
          Navigator.pop(context);
        }, width: double.infinity),
      ],
    );
  }

  void _restart() {
    setState(() {
      game = widget.create(null);
      game.onEvent = Snd.play;
      _overShown = false;
      _saveAt = 0;
      paused.value = false;
    });
    _start();
  }

  Future<void> _exitDialog() async {
    if (game.over) {
      Navigator.pop(context);
      return;
    }
    pause();
    final r = await showNeonDialog<int>(
      context,
      title: 'LEAVE MATCH?',
      message: 'The game is paused.',
      buttons: (c) => [
        NeonButton('SAVE & EXIT', const Color(0xFF39FF14), () => Navigator.pop(c, 1), width: double.infinity),
        NeonButton('RESUME GAME', const Color(0xFF00F0FF), () => Navigator.pop(c, 0), width: double.infinity),
        NeonButton('EXIT WITHOUT SAVING', const Color(0xFFFF2040), () => Navigator.pop(c, 2),
            width: double.infinity),
      ],
    );
    if (!mounted) return;
    if (r == 1) {
      await Store.save(game.toJson(), widget.id);
      if (mounted) Navigator.pop(context);
    } else if (r == 2) {
      await Store.clearSave(widget.id);
      if (mounted) Navigator.pop(context);
    } else {
      resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitDialog();
      },
      child: Scaffold(
        body: Backdrop(
          animate: false,
          child: SafeArea(
            child: Stack(children: [
              Positioned.fill(child: widget.builder(context, this)),
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: paused,
                  builder: (_, v, __) => v
                      ? Container(
                          color: Colors.black.withAlpha(190),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Text('PAUSED',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4)),
                            const SizedBox(height: 20),
                            NeonButton('RESUME', const Color(0xFF39FF14), resume),
                            const SizedBox(height: 12),
                            NeonButton('EXIT', const Color(0xFFFF2040), _exitDialog),
                          ]),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Top bar: score, level, lives and the pause button.
class ArcadeHud extends StatelessWidget {
  final ArcadeShellState s;
  final IconData icon;
  final Color color;
  final int Function(ArcadeGame g) lives;
  const ArcadeHud({super.key, required this.s, required this.icon, required this.color, required this.lives});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 2),
      child: ValueListenableBuilder<int>(
        valueListenable: s.tick,
        builder: (_, __, ___) {
          final g = s.game;
          return Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('SCORE', style: TextStyle(color: p.sub, fontSize: 10, letterSpacing: 2)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('${g.score}',
                      style: TextStyle(color: p.text, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ]),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('LEVEL', style: TextStyle(color: p.sub, fontSize: 10, letterSpacing: 2)),
              Text('${g.level}', style: TextStyle(color: p.text, fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(width: 14),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < lives(g).clamp(0, 6); i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(icon, color: color, size: 20, shadows: [Shadow(color: color, blurRadius: 8)]),
                ),
            ]),
            IconButton(onPressed: s.pause, icon: Icon(Icons.pause_circle_outline, color: p.accent, size: 30)),
          ]);
        },
      ),
    );
  }
}
