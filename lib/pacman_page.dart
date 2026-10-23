import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart' show CtrlButton;
import 'sound.dart';
import 'store.dart';
import 'theme.dart';

const int pc = 19, pr = 21;

// # wall, . dot, o power pellet, - ghost door, P pac start
const List<String> _maze = [
  '###################',
  '#........#........#',
  '#o##.###.#.###.##o#',
  '#.................#',
  '#.##.#.#####.#.##.#',
  '#....#...#...#....#',
  '####.### # ###.####',
  '####.#       #.####',
  '####.# ##-## #.####',
  '    .  #   #  .    ',
  '####.# ##### #.####',
  '####.#       #.####',
  '####.# ##### #.####',
  '#........#........#',
  '#.##.###.#.###.##.#',
  '#o.#.....P.....#.o#',
  '##.#.#.#####.#.#.##',
  '#....#...#...#....#',
  '#.######.#.######.#',
  '#.................#',
  '###################',
];

bool _open(int c, int r, bool door) {
  if (r < 0 || r >= pr) return false;
  final ch = _maze[r][(c + pc) % pc];
  if (ch == '#') return false;
  if (ch == '-') return door;
  return true;
}

class Mv {
  int c, r, dx = 0, dy = 0;
  double t = 0;
  Mv(this.c, this.r);
  double get x => c + dx * t;
  double get y => r + dy * t;
}

class Ghost extends Mv {
  final int id, sc, sr;
  final double base;
  int mode = 0; // 0 house, 1 active, 2 eaten (eyes)
  bool out = false, scared = false;
  double wait;
  Ghost(this.id, int c, int r, double w)
      : sc = c,
        sr = r,
        base = w,
        wait = w,
        super(c, r);

  void reset(double k) {
    c = sc;
    r = sr;
    dx = 0;
    dy = 0;
    t = 0;
    mode = id == 0 ? 1 : 0;
    out = id == 0;
    scared = false;
    wait = base * k;
  }
}

class PacGame {
  final Random _rng = Random();
  late List<int> food;
  int left = 0,
      eaten = 0,
      score = 0,
      level = 1,
      lives = 3,
      elapsedMs = 0,
      freeze = 0,
      fright = 0,
      combo = 0;
  int wdx = 0, wdy = 0, fdx = -1, fdy = 0;
  bool over = false, dying = false;
  late Mv pac;
  late List<Ghost> ghosts;
  void Function(String)? onEvent;

  PacGame() {
    ghosts = [
      Ghost(0, 9, 7, 0),
      Ghost(1, 9, 9, 3),
      Ghost(2, 8, 9, 7),
      Ghost(3, 10, 9, 11)
    ];
    _fillFood();
    _resetPos();
  }

  void _ev(String e) => onEvent?.call(e);

  void _fillFood() {
    food = List<int>.filled(pc * pr, 0);
    left = 0;
    for (var r = 0; r < pr; r++) {
      for (var c = 0; c < pc; c++) {
        final ch = _maze[r][c];
        if (ch == '.' || ch == 'o') {
          food[r * pc + c] = ch == '.' ? 1 : 2;
          left++;
        }
      }
    }
  }

  void _resetPos() {
    pac = Mv(9, 15);
    wdx = 0;
    wdy = 0;
    fdx = -1;
    fdy = 0;
    fright = 0;
    combo = 0;
    final k = pow(0.85, level - 1).toDouble();
    for (final g in ghosts) {
      g.reset(k);
    }
  }

  double get _pacSpeed => min(7.4, 6.0 + 0.2 * (level - 1));
  double _gSpeed(Ghost g) =>
      g.mode == 2 ? 12 : (g.scared ? 3.3 : min(7.0, 5.0 + 0.3 * (level - 1)));

  void setDir(int x, int y) {
    wdx = x;
    wdy = y;
  }

  void _reverse(Mv m) {
    m.c = (m.c + m.dx + pc) % pc;
    m.r += m.dy;
    m.t = 1 - m.t;
    m.dx = -m.dx;
    m.dy = -m.dy;
  }

  void update(int dt) {
    if (over) return;
    elapsedMs += dt;
    if (freeze > 0) {
      freeze -= dt;
      if (freeze <= 0 && dying) {
        dying = false;
        if (lives <= 0) {
          over = true;
          _ev('over');
        } else {
          _resetPos();
        }
      }
      return;
    }
    final s = dt / 1000.0;
    if (fright > 0) {
      fright -= dt;
      if (fright <= 0) {
        for (final g in ghosts) {
          g.scared = false;
        }
      }
    }
    _movePac(s);
    for (final g in ghosts) {
      _moveGhost(g, s);
    }
    _collide();
    if (!dying && left == 0) {
      level++;
      _ev('level');
      _fillFood();
      _resetPos();
      freeze = 900;
    }
  }

  void _movePac(double s) {
    var d = _pacSpeed * s;
    if ((pac.dx != 0 || pac.dy != 0) && wdx == -pac.dx && wdy == -pac.dy)
      _reverse(pac);
    while (d > 0) {
      if (pac.dx == 0 && pac.dy == 0) {
        _pacChoose();
        if (pac.dx == 0 && pac.dy == 0) break;
      }
      final need = 1 - pac.t;
      if (d < need) {
        pac.t += d;
        d = 0;
      } else {
        d -= need;
        pac.c = (pac.c + pac.dx + pc) % pc;
        pac.r += pac.dy;
        pac.t = 0;
        _eat();
        _pacChoose();
      }
    }
  }

  void _pacChoose() {
    if ((wdx != 0 || wdy != 0) && _open(pac.c + wdx, pac.r + wdy, false)) {
      pac.dx = wdx;
      pac.dy = wdy;
      fdx = wdx;
      fdy = wdy;
      return;
    }
    if ((pac.dx != 0 || pac.dy != 0) &&
        _open(pac.c + pac.dx, pac.r + pac.dy, false)) {
      fdx = pac.dx;
      fdy = pac.dy;
      return;
    }
    pac.dx = 0;
    pac.dy = 0;
  }

  void _eat() {
    final i = pac.r * pc + pac.c;
    final f = food[i];
    if (f == 0) return;
    food[i] = 0;
    left--;
    eaten++;
    if (f == 1) {
      score += 10;
      if (eaten % 2 == 0) _ev('munch');
    } else {
      score += 50;
      fright = max(2500, 7000 - (level - 1) * 800);
      combo = 0;
      for (final g in ghosts) {
        if (g.mode == 2) continue;
        g.scared = true;
        if (g.mode == 1 && g.out && (g.dx != 0 || g.dy != 0)) _reverse(g);
      }
      _ev('power');
    }
  }

  void _moveGhost(Ghost g, double s) {
    if (g.mode == 0) {
      g.wait -= s;
      if (g.wait > 0) return;
      g.mode = 1;
      g.out = false;
    }
    var d = _gSpeed(g) * s;
    while (d > 0) {
      if (g.dx == 0 && g.dy == 0) {
        _gChoose(g);
        if (g.dx == 0 && g.dy == 0) break;
      }
      final need = 1 - g.t;
      if (d < need) {
        g.t += d;
        d = 0;
      } else {
        d -= need;
        g.c = (g.c + g.dx + pc) % pc;
        g.r += g.dy;
        g.t = 0;
        if (g.mode == 2 && g.c == 9 && g.r == 9) {
          g.mode = 1;
          g.out = false;
          g.scared = false;
        }
        if (!g.out && g.r < 8) g.out = true;
        _gChoose(g);
      }
    }
  }

  Offset _target(Ghost g) {
    if (g.mode == 2) return const Offset(9, 9);
    if (!g.out) return const Offset(9, 7);
    final px = pac.x, py = pac.y;
    if (elapsedMs / 1000 % 27 < 7)
      return const [
        Offset(17, 0),
        Offset(1, 0),
        Offset(17, 20),
        Offset(1, 20)
      ][g.id];
    switch (g.id) {
      case 0:
        return Offset(px, py);
      case 1:
        return Offset(px + 4 * fdx, py + 4 * fdy);
      case 2:
        return Offset(px - 4 * fdx, py - 4 * fdy);
      default:
        {
          final dx = g.x - px, dy = g.y - py;
          return dx * dx + dy * dy > 36 ? Offset(px, py) : const Offset(1, 20);
        }
    }
  }

  void _gChoose(Ghost g) {
    final door = g.mode == 2 || !g.out;
    final tg = _target(g);
    const dirs = [
      [0, -1],
      [-1, 0],
      [0, 1],
      [1, 0]
    ];
    var bdx = 0, bdy = 0;
    var best = 1e9;
    final moving = g.dx != 0 || g.dy != 0;
    for (final d in dirs) {
      if (moving && d[0] == -g.dx && d[1] == -g.dy) continue;
      if (!_open(g.c + d[0], g.r + d[1], door)) continue;
      final nx = g.c + d[0] - tg.dx, ny = g.r + d[1] - tg.dy;
      final dd =
          (g.scared && g.mode != 2) ? _rng.nextDouble() : nx * nx + ny * ny;
      if (dd < best) {
        best = dd;
        bdx = d[0];
        bdy = d[1];
      }
    }
    if (best >= 1e9 && moving && _open(g.c - g.dx, g.r - g.dy, door)) {
      bdx = -g.dx;
      bdy = -g.dy;
    }
    g.dx = bdx;
    g.dy = bdy;
  }

  void _collide() {
    for (final g in ghosts) {
      if (g.mode != 1) continue;
      final dx = g.x - pac.x, dy = g.y - pac.y;
      if (dx * dx + dy * dy > .36) continue;
      if (g.scared) {
        g.scared = false;
        g.mode = 2;
        combo++;
        score += 200 << (min(combo, 4) - 1);
        _ev('ghost');
      } else {
        lives--;
        dying = true;
        freeze = 1200;
        _ev('death');
        return;
      }
    }
  }
}

class PacPainter extends CustomPainter {
  final PacGame g;
  final bool dark;
  PacPainter(this.g, this.dark, Listenable repaint) : super(repaint: repaint);
  static final Paint _f = Paint();
  static final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
  static const _blue = Color(0xFF2979FF);
  static const _gc = [
    Color(0xFFFF2040),
    Color(0xFFFF4FD8),
    Color(0xFF00F0FF),
    Color(0xFFFF8A00)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Pal(dark);
    final cs = size.width / pc;
    final box =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.clipRRect(box);
    canvas.drawRRect(box, Paint()..color = p.board);
    final wf = Paint()..color = _blue.withAlpha(dark ? 60 : 45);
    final ws = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _blue;
    for (var r = 0; r < pr; r++) {
      for (var c = 0; c < pc; c++) {
        final ch = _maze[r][c];
        if (ch == '#') {
          final rr = RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cs, r * cs, cs, cs).deflate(cs * .1),
              Radius.circular(cs * .3));
          canvas.drawRRect(rr, wf);
          canvas.drawRRect(rr, ws);
        } else if (ch == '-') {
          _f.color = pieceColors[4];
          canvas.drawRect(Rect.fromLTWH(c * cs, (r + .5) * cs - 2, cs, 4), _f);
        }
      }
    }
    final pulse = .22 + .07 * sin(g.elapsedMs / 110);
    for (var i = 0; i < pc * pr; i++) {
      final f = g.food[i];
      if (f == 0) continue;
      final o = Offset((i % pc + .5) * cs, (i ~/ pc + .5) * cs);
      if (f == 1) {
        _f.color = dark ? const Color(0xFFFFE9A8) : const Color(0xFFE69500);
        canvas.drawCircle(o, cs * .1, _f);
      } else {
        _glow.color = pieceColors[1].withAlpha(200);
        canvas.drawCircle(o, cs * .3, _glow);
        _f.color = dark ? pieceColors[1] : const Color(0xFFFF8A00);
        canvas.drawCircle(o, cs * pulse, _f);
      }
    }
    if (!g.dying) {
      for (final gh in g.ghosts) {
        _ghost(canvas, gh, cs);
      }
    }
    final o = Offset((g.pac.x + .5) * cs, (g.pac.y + .5) * cs);
    final ang = atan2(g.fdy.toDouble(), g.fdx.toDouble());
    final moving = g.pac.dx != 0 || g.pac.dy != 0;
    double mouth =
        moving ? .06 * pi + .26 * pi * sin(g.elapsedMs / 70).abs() : .12 * pi;
    if (g.dying)
      mouth = .25 * pi + .75 * pi * (1 - g.freeze / 1200).clamp(0.0, 1.0);
    _glow.color = pieceColors[1].withAlpha(150);
    canvas.drawCircle(o, cs * .55, _glow);
    _f.color = pieceColors[1];
    canvas.drawArc(Rect.fromCircle(center: o, radius: cs * .46), ang + mouth,
        2 * pi - 2 * mouth, true, _f);
    canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = p.accent);
  }

  void _ghost(Canvas canvas, Ghost gh, double cs) {
    final cx = (gh.x + .5) * cs, cy = (gh.y + .5) * cs, r = cs * .46;
    final flash = g.fright < 1800 && (g.elapsedMs ~/ 200) % 2 == 0;
    final col = gh.scared ? (flash ? Colors.white : _blue) : _gc[gh.id];
    if (gh.mode != 2) {
      final path = Path()
        ..moveTo(cx - r, cy + r)
        ..lineTo(cx - r, cy)
        ..arcTo(
            Rect.fromCircle(center: Offset(cx, cy), radius: r), pi, pi, false)
        ..lineTo(cx + r, cy + r)
        ..lineTo(cx + r * .66, cy + r * .72)
        ..lineTo(cx + r * .33, cy + r)
        ..lineTo(cx, cy + r * .72)
        ..lineTo(cx - r * .33, cy + r)
        ..lineTo(cx - r * .66, cy + r * .72)
        ..close();
      _glow.color = col.withAlpha(150);
      canvas.drawPath(path, _glow);
      _f.color = col;
      canvas.drawPath(path, _f);
    }
    final ex = r * .38, ey = cy - r * .15;
    if (gh.scared && gh.mode != 2) {
      _f.color = Colors.white;
      canvas.drawCircle(Offset(cx - ex * .8, ey), r * .13, _f);
      canvas.drawCircle(Offset(cx + ex * .8, ey), r * .13, _f);
    } else {
      for (final s in [-1.0, 1.0]) {
        _f.color = Colors.white;
        canvas.drawCircle(Offset(cx + s * ex, ey), r * .28, _f);
        _f.color = const Color(0xFF1A237E);
        canvas.drawCircle(
            Offset(cx + s * ex + gh.dx * r * .12, ey + gh.dy * r * .12),
            r * .14,
            _f);
      }
    }
  }

  @override
  bool shouldRepaint(PacPainter o) => true;
}

class PacmanPage extends StatefulWidget {
  const PacmanPage({super.key});
  @override
  State<PacmanPage> createState() => _PacmanPageState();
}

class _PacmanPageState extends State<PacmanPage> with WidgetsBindingObserver {
  late PacGame g;
  final tick = ValueNotifier<int>(0);
  final pausedN = ValueNotifier<bool>(false);
  final Stopwatch _sw = Stopwatch();
  Timer? _loop;
  int _last = 0;
  bool _overShown = false;
  Offset _acc = Offset.zero;
  static const _m = {
    'munch': 'move',
    'power': 'hard',
    'ghost': 'clear',
    'death': 'land'
  };

  void _snd(String e) => Snd.play(_m[e] ?? e);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    g = PacGame()..onEvent = _snd;
    _sw.start();
    _start();
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
    if (state != AppLifecycleState.resumed && !g.over && !pausedN.value)
      _pause();
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
      if (g.over) _gameOver();
    });
  }

  void _pause() {
    if (g.over) return;
    _loop?.cancel();
    _loop = null;
    pausedN.value = true;
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
    Store.addScore({
      's': g.score,
      'v': g.level,
      'n': g.eaten,
      'd': DateTime.now().millisecondsSinceEpoch,
      't': g.elapsedMs,
    }, 'pacman');
    showNeonDialog<void>(
      context,
      title: 'GAME OVER',
      message: 'Score ${g.score}\nLevel ${g.level}  •  Dots ${g.eaten}',
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
      g = PacGame()..onEvent = _snd;
      _overShown = false;
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
    final r = await showNeonDialog<int>(
      context,
      title: 'LEAVE MATCH?',
      message: 'The game is paused. Progress will be lost.',
      buttons: (c) => [
        NeonButton(
            'RESUME GAME', const Color(0xFF39FF14), () => Navigator.pop(c, 0),
            width: double.infinity),
        NeonButton('EXIT', const Color(0xFFFF2040), () => Navigator.pop(c, 1),
            width: double.infinity),
      ],
    );
    if (!mounted) return;
    if (r == 1) {
      Navigator.pop(context);
    } else {
      _resume();
    }
  }

  void _dir(int x, int y) {
    if (pausedN.value || g.over) return;
    g.setDir(x, y);
  }

  void _swipe(DragUpdateDetails d) {
    _acc += d.delta;
    if (_acc.distance < 14) return;
    if (_acc.dx.abs() > _acc.dy.abs()) {
      _dir(_acc.dx > 0 ? 1 : -1, 0);
    } else {
      _dir(0, _acc.dy > 0 ? 1 : -1);
    }
    _acc = Offset.zero;
  }

  Widget _hud(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 2),
        child: ValueListenableBuilder<int>(
          valueListenable: tick,
          builder: (_, __, ___) => Row(children: [
            Row(children: [
              for (var i = 0; i < 3; i++)
                Icon(Icons.favorite,
                    size: 20,
                    color: i < g.lives ? pieceColors[4] : p.sub.withAlpha(60)),
            ]),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${g.score}',
                      style: TextStyle(
                          color: p.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                ),
                Text('LEVEL ${g.level}',
                    style: TextStyle(
                        color: p.sub, fontSize: 12, letterSpacing: 2)),
              ]),
            ),
            IconButton(
                onPressed: _pause,
                icon: Icon(Icons.pause_circle_outline,
                    color: p.accent, size: 30)),
          ]),
        ),
      );

  Widget _controls() {
    Widget b(IconData i, Color c, int x, int y) =>
        Expanded(child: CtrlButton(i, c, () => _dir(x, y)));
    return Center(
      child: SizedBox(
        width: 300,
        child: Column(children: [
          Expanded(
              child: Row(children: [
            const Spacer(),
            b(Icons.keyboard_arrow_up, pieceColors[0], 0, -1),
            const Spacer()
          ])),
          Expanded(
              child: Row(children: [
            b(Icons.keyboard_arrow_left, pieceColors[2], -1, 0),
            b(Icons.keyboard_arrow_down, pieceColors[5], 0, 1),
            b(Icons.keyboard_arrow_right, pieceColors[2], 1, 0),
          ])),
        ]),
      ),
    );
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: pc / pr,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => _acc = Offset.zero,
                        onPanUpdate: _swipe,
                        child: Stack(children: [
                          Positioned.fill(
                              child: CustomPaint(
                                  painter: PacPainter(g, p.dark, tick))),
                          ValueListenableBuilder<bool>(
                            valueListenable: pausedN,
                            builder: (_, paused, __) => paused
                                ? SizedBox.expand(
                                    child: Container(
                                      color: Colors.black.withAlpha(190),
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text('PAUSED',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 4)),
                                            const SizedBox(height: 20),
                                            NeonButton(
                                                'RESUME',
                                                const Color(0xFF39FF14),
                                                _resume),
                                            const SizedBox(height: 12),
                                            NeonButton(
                                                'EXIT',
                                                const Color(0xFFFF2040),
                                                _exitDialog),
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
