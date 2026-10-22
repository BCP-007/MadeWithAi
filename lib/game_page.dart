import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'sound.dart';
import 'store.dart';
import 'theme.dart';

final Paint _bp = Paint();

void drawBlock(Canvas c, Rect rect, Color color) {
  final w = rect.width;
  final o = RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(w * .2));
  _bp
    ..style = PaintingStyle.fill
    ..color = color;
  c.drawRRect(o, _bp);
  _bp.color = Colors.white.withAlpha(85);
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + w * .2, rect.top + w * .15, w * .6, w * .22), Radius.circular(w * .1)),
      _bp);
  _bp
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Colors.black.withAlpha(70);
  c.drawRRect(o, _bp);
}

class BoardPainter extends CustomPainter {
  final Game g;
  final bool dark;
  BoardPainter(this.g, this.dark, Listenable repaint) : super(repaint: repaint);
  static final Paint _glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Pal(dark);
    final cs = size.width / cols;
    final box = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(box, Paint()..color = p.board);
    final gp = Paint()
      ..color = p.grid
      ..strokeWidth = 1;
    for (var i = 1; i < cols; i++) {
      canvas.drawLine(Offset(i * cs, 0), Offset(i * cs, size.height), gp);
    }
    for (var i = 1; i < rows; i++) {
      canvas.drawLine(Offset(0, i * cs), Offset(size.width, i * cs), gp);
    }
    for (var i = 0; i < cols * rows; i++) {
      final b = g.board[i];
      if (b != 0) {
        drawBlock(canvas, Rect.fromLTWH((i % cols) * cs, (i ~/ cols) * cs, cs, cs), pieceColors[b - 1]);
      }
    }
    if (!g.over) {
      final col = pieceColors[g.type];
      final cells = g.cells;
      final gy = g.ghostY();
      final gh = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = col.withAlpha(150);
      for (final c in cells) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH((g.px + c[0]) * cs, (gy + c[1]) * cs, cs, cs).deflate(2), Radius.circular(cs * .2)),
            gh);
      }
      _glow.color = col.withAlpha(140);
      for (final c in cells) {
        final r = Rect.fromLTWH((g.px + c[0]) * cs, (g.py + c[1]) * cs, cs, cs);
        canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(1), Radius.circular(cs * .2)), _glow);
      }
      for (final c in cells) {
        drawBlock(canvas, Rect.fromLTWH((g.px + c[0]) * cs, (g.py + c[1]) * cs, cs, cs), col);
      }
    }
    final age = g.elapsedMs - g.flashAt;
    if (age < 260) {
      final fp = Paint()..color = Colors.white.withAlpha(((1 - age / 260) * 220).round());
      for (final y in g.flashRows) {
        canvas.drawRect(Rect.fromLTWH(0, y * cs, size.width, cs), fp);
      }
    }
    canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = p.accent);
  }

  @override
  bool shouldRepaint(BoardPainter o) => true;
}

class PiecePainter extends CustomPainter {
  final int type;
  final bool dim;
  PiecePainter(this.type, this.dim);

  @override
  void paint(Canvas canvas, Size size) {
    if (type < 0) return;
    final cells = cellsOf(type, 0);
    var minX = 9, maxX = 0, minY = 9, maxY = 0;
    for (final c in cells) {
      minX = min(minX, c[0]);
      maxX = max(maxX, c[0]);
      minY = min(minY, c[1]);
      maxY = max(maxY, c[1]);
    }
    final cs = size.width / 4.6;
    final ox = (size.width - (maxX - minX + 1) * cs) / 2 - minX * cs;
    final oy = (size.height - (maxY - minY + 1) * cs) / 2 - minY * cs;
    final col = dim ? pieceColors[type].withAlpha(70) : pieceColors[type];
    for (final c in cells) {
      drawBlock(canvas, Rect.fromLTWH(ox + c[0] * cs, oy + c[1] * cs, cs, cs), col);
    }
  }

  @override
  bool shouldRepaint(PiecePainter o) => true;
}

class CtrlButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPress;
  final int rate; // 0 = no auto-repeat
  const CtrlButton(this.icon, this.color, this.onPress, {super.key, this.rate = 0});
  @override
  State<CtrlButton> createState() => _CtrlButtonState();
}

class _CtrlButtonState extends State<CtrlButton> {
  Timer? _d, _r;
  bool down = false;

  void _cancel() {
    _d?.cancel();
    _r?.cancel();
    _d = null;
    _r = null;
  }

  void _down() {
    setState(() => down = true);
    widget.onPress();
    if (widget.rate > 0) {
      _d = Timer(const Duration(milliseconds: 170), () {
        _r = Timer.periodic(Duration(milliseconds: widget.rate), (_) => widget.onPress());
      });
    }
  }

  void _up() {
    _cancel();
    if (mounted) setState(() => down = false);
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = widget.color;
    return Listener(
      onPointerDown: (_) => _down(),
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.withAlpha(down ? 110 : 35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c, width: 1.5),
          boxShadow: down ? [] : [BoxShadow(color: c.withAlpha(60), blurRadius: 8)],
        ),
        child: Center(child: Icon(widget.icon, color: p.text, size: 30)),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  final bool resume;
  const GamePage({super.key, required this.resume});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late Game g;
  final tick = ValueNotifier<int>(0);
  final pausedN = ValueNotifier<bool>(false);
  final Stopwatch _sw = Stopwatch();
  Timer? _loop;
  int _last = 0, _saved = 0, _saveAt = 0;
  bool _overShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Game? loaded;
    if (widget.resume) {
      final j = Store.load();
      if (j != null) {
        try {
          loaded = Game.fromJson(j);
        } catch (_) {
          loaded = null;
        }
      }
    }
    g = loaded ?? Game();
    g.onEvent = Snd.play;
    _sw.start();
    if (loaded != null) {
      pausedN.value = true; // resume on tap so the player is ready
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loop?.cancel();
    tick.dispose();
    pausedN.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !g.over && !pausedN.value) _pause();
  }

  void _start() {
    _loop?.cancel();
    _last = _sw.elapsedMilliseconds;
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _sw.elapsedMilliseconds;
      final dt = min(now - _last, 100);
      _last = now;
      g.update(dt);
      tick.value++;
      if (g.over) {
        _gameOver();
      } else if (g.locks != _saved || g.elapsedMs - _saveAt > 5000) {
        _saved = g.locks;
        _saveAt = g.elapsedMs;
        Store.save(g.toJson());
      }
    });
  }

  void _pause() {
    if (g.over) return;
    _loop?.cancel();
    _loop = null;
    pausedN.value = true;
    Store.save(g.toJson());
  }

  void _resume() {
    pausedN.value = false;
    _start();
  }

  void _gameOver() {
    if (_overShown) return;
    _overShown = true;
    _loop?.cancel();
    _loop = null;
    Store.clearSave();
    Store.addScore({
      's': g.score,
      'v': g.level,
      'n': g.lines,
      'd': DateTime.now().millisecondsSinceEpoch,
      't': g.elapsedMs,
    });
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('GAME OVER'),
          content: Text('Score ${g.score}\nLevel ${g.level}  •  Lines ${g.lines}'),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: const Text('Home')),
            FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  _restart();
                },
                child: const Text('Play Again')),
          ],
        ),
      ),
    );
  }

  void _restart() {
    setState(() {
      g = Game();
      g.onEvent = Snd.play;
      _overShown = false;
      _saved = 0;
      _saveAt = 0;
      pausedN.value = false;
    });
    _start();
  }

  Future<void> _exitDialog() async {
    if (g.over) {
      Navigator.pop(context);
      return;
    }
    _pause();
    final r = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Leave match?'),
        content: const Text('The game is paused.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 0), child: const Text('Resume Game')),
          TextButton(onPressed: () => Navigator.pop(c, 2), child: const Text('Exit Without Saving')),
          FilledButton(onPressed: () => Navigator.pop(c, 1), child: const Text('Save & Exit')),
        ],
      ),
    );
    if (!mounted) return;
    if (r == 1) {
      await Store.save(g.toJson());
      if (mounted) Navigator.pop(context);
    } else if (r == 2) {
      await Store.clearSave();
      if (mounted) Navigator.pop(context);
    } else {
      _resume();
    }
  }

  void _a(void Function() f) {
    if (pausedN.value || g.over) return;
    f();
    tick.value++;
  }

  Widget _box(String label, int type, Pal p, {bool dim = false}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: p.sub, fontSize: 10, letterSpacing: 2)),
      const SizedBox(height: 2),
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: p.panel.withAlpha(190),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.accent.withAlpha(110)),
        ),
        child: CustomPaint(painter: PiecePainter(type, dim)),
      ),
    ]);
  }

  Widget _hud(Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 2),
      child: ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (_, __, ___) => Row(children: [
          _box('HOLD', g.hold, p, dim: !g.canHold),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${g.score}',
                    style: TextStyle(
                        color: p.text, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
              Text('LEVEL ${g.level}   LINES ${g.lines}',
                  style: TextStyle(color: p.sub, fontSize: 12, letterSpacing: 1)),
            ]),
          ),
          _box('NEXT', g.queue.first, p),
          IconButton(
              onPressed: _pause,
              icon: Icon(Icons.pause_circle_outline, color: p.accent, size: 30)),
        ]),
      ),
    );
  }

  Widget _controls() {
    return Row(children: [
      Expanded(
        child: Column(children: [
          Expanded(
            child: Row(children: [
              Expanded(
                  child: CtrlButton(Icons.keyboard_arrow_left, pieceColors[0], () => _a(() => g.move(-1)),
                      rate: 55)),
              Expanded(
                  child: CtrlButton(Icons.keyboard_arrow_right, pieceColors[0], () => _a(() => g.move(1)),
                      rate: 55)),
            ]),
          ),
          Expanded(
              child: CtrlButton(Icons.keyboard_arrow_down, pieceColors[5], () => _a(() => g.softDrop()),
                  rate: 45)),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(children: [
          Expanded(
            child: Row(children: [
              Expanded(child: CtrlButton(Icons.rotate_right, pieceColors[2], () => _a(g.rotate))),
              Expanded(child: CtrlButton(Icons.swap_horiz, pieceColors[1], () => _a(g.holdPiece))),
            ]),
          ),
          Expanded(child: CtrlButton(Icons.vertical_align_bottom, pieceColors[4], () => _a(g.hardDrop))),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitDialog();
      },
      child: Scaffold(
        body: Backdrop(
          animate: false,
          child: SafeArea(
            child: Column(children: [
              _hud(p),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 0.5,
                      child: Stack(children: [
                        Positioned.fill(child: CustomPaint(painter: BoardPainter(g, p.dark, tick))),
                        ValueListenableBuilder<bool>(
                          valueListenable: pausedN,
                          builder: (_, paused, __) => paused
                              ? SizedBox.expand(
                                  child: Container(
                                    color: Colors.black.withAlpha(190),
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Text('PAUSED',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 4)),
                                      const SizedBox(height: 20),
                                      NeonButton('RESUME', const Color(0xFF39FF14), _resume),
                                      const SizedBox(height: 12),
                                      NeonButton('EXIT', const Color(0xFFFF2040), _exitDialog),
                                    ]),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: SizedBox(height: 132, child: _controls()),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
