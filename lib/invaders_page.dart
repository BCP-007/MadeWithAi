import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'game_page.dart' show CtrlButton;
import 'sound.dart';
import 'store.dart';
import 'theme.dart';

const double iw = 360, ih = 560;
const double shipY = ih - 34;
const double bunkY = ih - 120;
double bunkX(int b) => iw * (b + .5) / 4 - 30;

const List<int> _rowType = [0, 1, 1, 2, 2];
const List<int> _rowCol = [4, 6, 1, 3, 0];

// 8x8 sprites, index = type*2 + animation frame
const List<List<String>> _spr = [
  [
    '...XX...',
    '..XXXX..',
    '.XXXXXX.',
    'XX.XX.XX',
    'XXXXXXXX',
    '..X..X..',
    '.X.XX.X.',
    'X.X..X.X'
  ],
  [
    '...XX...',
    '..XXXX..',
    '.XXXXXX.',
    'XX.XX.XX',
    'XXXXXXXX',
    '.X.XX.X.',
    'X......X',
    '.X....X.'
  ],
  [
    '..X..X..',
    '...XX...',
    '..XXXX..',
    '.XXXXXX.',
    'XX.XX.XX',
    'XXXXXXXX',
    'X.X..X.X',
    'X......X'
  ],
  [
    '..X..X..',
    'X..XX..X',
    'X.XXXX.X',
    'XXXXXXXX',
    '.XX..XX.',
    '..XXXX..',
    '.X....X.',
    'X......X'
  ],
  [
    '.XXXXXX.',
    'XXXXXXXX',
    'XX.XX.XX',
    'XXXXXXXX',
    '..XXXX..',
    '.XX..XX.',
    'XX....XX',
    '.X....X.'
  ],
  [
    '.XXXXXX.',
    'XXXXXXXX',
    'XX.XX.XX',
    'XXXXXXXX',
    '..XXXX..',
    '..X..X..',
    '.XX..XX.',
    'XX....XX'
  ],
];
final Map<int, Path> _sp = {};
Path _spritePath(int k) => _sp.putIfAbsent(k, () {
      final path = Path();
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          if (_spr[k][y][x] == 'X')
            path.addRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1));
        }
      }
      return path;
    });

class _B {
  double x, y;
  bool dead = false;
  _B(this.x, this.y);
}

class _Pt {
  double x, y, vx, vy, life;
  Color c;
  _Pt(this.x, this.y, this.vx, this.vy, this.life, this.c);
}

class InvGame {
  final Random _rng = Random();
  final List<bool> alive = [];
  double ox = 41, oy = 56;
  int dir = 1, frame = 0, aliveN = 0;
  double shipX = iw / 2;
  final List<_B> pb = [], eb = [];
  final List<_Pt> pts = [];
  late List<List<bool>> bunk;
  int score = 0,
      level = 1,
      lives = 3,
      kills = 0,
      elapsedMs = 0,
      cool = 0,
      shield = 0;
  double stepAcc = 0, fireAcc = 0, nextFire = 900;
  double ufoX = -100, ufoTimer = 12000;
  int ufoDir = 1;
  bool ufoOn = false, over = false;
  void Function(String)? onEvent;

  InvGame() {
    _wave();
  }

  void _ev(String e) => onEvent?.call(e);
  double ix(int c) => ox + c * 36;
  double iy(int r) => oy + r * 30;

  bool _cellOn(int i) {
    final x = i % 12, y = i ~/ 12;
    if (y == 0 && (x == 0 || x == 11)) return false;
    if (y >= 6 && x >= 4 && x <= 7) return false;
    return true;
  }

  void _wave() {
    alive
      ..clear()
      ..addAll(List<bool>.filled(40, true));
    aliveN = 40;
    ox = 41;
    oy = 56 + min(level - 1, 5) * 12.0;
    dir = 1;
    frame = 0;
    stepAcc = 0;
    pb.clear();
    eb.clear();
    bunk = [
      for (var b = 0; b < 4; b++) [for (var i = 0; i < 96; i++) _cellOn(i)]
    ];
  }

  void moveShip(int d) {
    if (over) return;
    shipX = (shipX + d * 9).clamp(22.0, iw - 22.0);
  }

  void fire() {
    if (over || cool > 0 || pb.length >= 3) return;
    pb.add(_B(shipX, shipY - 16));
    cool = 260;
    _ev('shoot');
  }

  double get _iv =>
      max(30.0, (60.0 + aliveN * 14.0) * pow(0.9, level - 1).toDouble());

  void _step() {
    frame ^= 1;
    var mn = 1e9, mx = -1e9;
    for (var i = 0; i < 40; i++) {
      if (!alive[i]) continue;
      final x = ix(i % 8);
      if (x < mn) mn = x;
      if (x > mx) mx = x;
    }
    if (dir > 0 ? mx + 26 + 10 > iw - 6 : mn - 10 < 6) {
      dir = -dir;
      oy += 16;
    } else {
      ox += dir * 10;
    }
  }

  double _lowest() {
    var m = 0.0;
    for (var i = 0; i < 40; i++) {
      if (alive[i]) m = max(m, iy(i ~/ 8) + 24);
    }
    return m;
  }

  int _bottom(int c) {
    for (var r = 4; r >= 0; r--) {
      if (alive[r * 8 + c]) return r;
    }
    return -1;
  }

  void _enemyFire() {
    if (eb.length >= min(2 + level, 6)) return;
    final cs = [
      for (var c = 0; c < 8; c++)
        if (_bottom(c) >= 0) c
    ];
    if (cs.isEmpty) return;
    final c = cs[_rng.nextInt(cs.length)];
    eb.add(_B(ix(c) + 13, iy(_bottom(c)) + 24));
  }

  void _boom(double x, double y, Color c, int n) {
    if (pts.length > 150) return;
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * pi, v = 40 + _rng.nextDouble() * 120;
      pts.add(
          _Pt(x, y, cos(a) * v, sin(a) * v, .35 + _rng.nextDouble() * .5, c));
    }
  }

  bool _hitBunker(double x, double y) {
    for (var b = 0; b < 4; b++) {
      final bx = bunkX(b);
      if (x < bx || x >= bx + 60 || y < bunkY || y >= bunkY + 40) continue;
      final cx = (x - bx) ~/ 5, cy = (y - bunkY) ~/ 5;
      if (!bunk[b][cy * 12 + cx]) continue;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = cx + dx, ny = cy + dy;
          if (nx < 0 || nx > 11 || ny < 0 || ny > 7) continue;
          if ((dx == 0 && dy == 0) || _rng.nextBool())
            bunk[b][ny * 12 + nx] = false;
        }
      }
      return true;
    }
    return false;
  }

  bool _hitInv(_B b) {
    for (var i = 0; i < 40; i++) {
      if (!alive[i]) continue;
      final x = ix(i % 8), y = iy(i ~/ 8);
      if (b.x >= x && b.x <= x + 26 && b.y >= y && b.y <= y + 24) {
        alive[i] = false;
        aliveN--;
        kills++;
        final r = i ~/ 8;
        score += r == 0 ? 30 : (r < 3 ? 20 : 10);
        _boom(x + 13, y + 12, pieceColors[_rowCol[r]], 12);
        _ev('kill');
        return true;
      }
    }
    return false;
  }

  void _ufoHit() {
    score += const [50, 100, 150, 300][_rng.nextInt(4)];
    ufoOn = false;
    ufoTimer = 15000 + _rng.nextInt(10000).toDouble();
    _boom(ufoX, 34, pieceColors[4], 18);
    _ev('ufo');
  }

  void _hitShip() {
    lives--;
    shield = 1800;
    _boom(shipX, shipY, pieceColors[0], 24);
    _ev('hit');
    if (lives <= 0) {
      over = true;
      _ev('over');
    }
  }

  void _bullets(double s) {
    final ps = 560 * s;
    for (final b in pb) {
      final n = (ps / 4).ceil().clamp(1, 8);
      for (var i = 0; i < n && !b.dead; i++) {
        b.y -= ps / n;
        if (b.y < -8 || _hitBunker(b.x, b.y)) {
          b.dead = true;
        } else if (ufoOn && (b.x - ufoX).abs() < 17 && (b.y - 34).abs() < 8) {
          _ufoHit();
          b.dead = true;
        } else if (_hitInv(b)) {
          b.dead = true;
        }
      }
    }
    pb.removeWhere((b) => b.dead);
    final es = (170 + level * 12.0) * s;
    for (final b in eb) {
      final n = (es / 4).ceil().clamp(1, 8);
      for (var i = 0; i < n && !b.dead; i++) {
        b.y += es / n;
        if (b.y > ih || _hitBunker(b.x, b.y)) {
          b.dead = true;
        } else if (shield <= 0 &&
            (b.x - shipX).abs() < 18 &&
            b.y > shipY - 10 &&
            b.y < shipY + 12) {
          b.dead = true;
          _hitShip();
        }
      }
    }
    eb.removeWhere((b) => b.dead);
  }

  void update(int dt) {
    if (over) return;
    final s = dt / 1000.0;
    elapsedMs += dt;
    cool -= dt;
    shield -= dt;
    stepAcc += dt;
    final iv = _iv;
    var n = 0;
    while (stepAcc >= iv && n < 3) {
      stepAcc -= iv;
      _step();
      n++;
    }
    if (stepAcc > iv) stepAcc = iv;
    fireAcc += dt;
    if (fireAcc >= nextFire) {
      fireAcc = 0;
      nextFire = 400 + _rng.nextInt(max(300, 1100 - level * 70)).toDouble();
      _enemyFire();
    }
    _bullets(s);
    if (!ufoOn) {
      ufoTimer -= dt;
      if (ufoTimer <= 0) {
        ufoOn = true;
        ufoDir = _rng.nextBool() ? 1 : -1;
        ufoX = ufoDir > 0 ? -20 : iw + 20;
      }
    } else {
      ufoX += ufoDir * 95 * s;
      if (ufoX < -30 || ufoX > iw + 30) {
        ufoOn = false;
        ufoTimer = 15000 + _rng.nextInt(10000).toDouble();
      }
    }
    for (final p in pts) {
      p.x += p.vx * s;
      p.y += p.vy * s;
      p.life -= s;
    }
    pts.removeWhere((p) => p.life <= 0);
    if (over) return;
    if (aliveN == 0) {
      level++;
      score += 100 * level;
      _ev('level');
      _wave();
    } else if (_lowest() >= shipY - 12) {
      lives = 0;
      over = true;
      _ev('over');
    }
  }
}

class InvPainter extends CustomPainter {
  final InvGame g;
  final bool dark;
  final ValueNotifier<ui.Image?> img;
  InvPainter(this.g, this.dark, Listenable repaint, this.img)
      : super(repaint: repaint);
  static final Paint _f = Paint();
  static final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  static final List<List<double>> _stars = () {
    final r = Random(7);
    return [
      for (var i = 0; i < 70; i++)
        [r.nextDouble() * iw, r.nextDouble() * ih, r.nextDouble() * 1.4 + .4]
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Pal(dark);
    final box =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.clipRRect(box);
    canvas.drawRRect(box, Paint()..color = p.board);
    canvas.save();
    canvas.scale(size.width / iw);
    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      _f.color = pieceColors[i % 7].withAlpha(dark ? 190 : 110);
      canvas.drawCircle(Offset(s[0], (s[1] + g.elapsedMs * 0.012 * s[2]) % ih),
          s[2] * .8, _f);
    }
    _f.color = pieceColors[3].withAlpha(160);
    canvas.drawRect(const Rect.fromLTWH(0, shipY + 22, iw, 2), _f);
    for (var b = 0; b < 4; b++) {
      for (var i = 0; i < 96; i++) {
        if (!g.bunk[b][i]) continue;
        _f.color = pieceColors[3].withAlpha(i ~/ 12 < 3 ? 255 : 215);
        canvas.drawRect(
            Rect.fromLTWH(bunkX(b) + (i % 12) * 5, bunkY + (i ~/ 12) * 5, 5, 5),
            _f);
      }
    }
    for (var i = 0; i < 40; i++) {
      if (!g.alive[i]) continue;
      final r = i ~/ 8;
      _f.color = pieceColors[_rowCol[r]];
      canvas.save();
      canvas.translate(g.ix(i % 8), g.iy(r));
      canvas.scale(26 / 8);
      canvas.drawPath(_spritePath(_rowType[r] * 2 + g.frame), _f);
      canvas.restore();
    }
    if (g.ufoOn) {
      _glow.color = pieceColors[4].withAlpha(160);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(g.ufoX, 34), width: 36, height: 14),
          _glow);
      _f.color = pieceColors[4];
      canvas.drawOval(
          Rect.fromCenter(center: Offset(g.ufoX, 34), width: 34, height: 12),
          _f);
      _f.color = pieceColors[0];
      canvas.drawCircle(Offset(g.ufoX, 29), 6, _f);
    }
    for (final b in g.pb) {
      _glow.color = pieceColors[1].withAlpha(200);
      canvas.drawRect(Rect.fromLTWH(b.x - 2, b.y - 7, 4, 14), _glow);
      _f.color = pieceColors[1];
      canvas.drawRect(Rect.fromLTWH(b.x - 1.5, b.y - 6, 3, 12), _f);
    }
    for (final b in g.eb) {
      _glow.color = pieceColors[4].withAlpha(200);
      canvas.drawRect(Rect.fromLTWH(b.x - 2, b.y - 5, 4, 10), _glow);
      _f.color = pieceColors[6];
      canvas.drawRect(Rect.fromLTWH(b.x - 1.5, b.y - 5, 3, 10), _f);
    }
    if (!g.over && !(g.shield > 0 && (g.elapsedMs ~/ 100) % 2 == 0))
      _ship(canvas);
    for (final t in g.pts) {
      _f.color = t.c.withAlpha((255 * (t.life / .8).clamp(0.0, 1.0)).round());
      canvas.drawRect(Rect.fromLTWH(t.x - 1.5, t.y - 1.5, 3, 3), _f);
    }
    canvas.restore();
    canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = p.accent);
  }

  void _ship(Canvas canvas) {
    final x = g.shipX, y = shipY;
    final im = img.value;
    if (im != null) {
      canvas.drawImageRect(
          im,
          Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
          Rect.fromCenter(center: Offset(x, y), width: 46, height: 46),
          Paint()..filterQuality = FilterQuality.medium);
      return;
    }
    final path = Path()
      ..moveTo(x, y - 16)
      ..lineTo(x + 7, y - 4)
      ..lineTo(x + 20, y + 8)
      ..lineTo(x + 20, y + 12)
      ..lineTo(x + 8, y + 8)
      ..lineTo(x + 5, y + 12)
      ..lineTo(x - 5, y + 12)
      ..lineTo(x - 8, y + 8)
      ..lineTo(x - 20, y + 12)
      ..lineTo(x - 20, y + 8)
      ..lineTo(x - 7, y - 4)
      ..close();
    _glow.color = pieceColors[0].withAlpha(170);
    canvas.drawPath(path, _glow);
    _f.color = pieceColors[0];
    canvas.drawPath(path, _f);
    _f.color = Colors.white;
    canvas.drawCircle(Offset(x, y - 2), 3.5, _f);
    final fl = 5 + 3 * sin(g.elapsedMs / 40).abs();
    _f.color = pieceColors[6];
    canvas.drawPath(
        Path()
          ..moveTo(x - 4, y + 12)
          ..lineTo(x + 4, y + 12)
          ..lineTo(x, y + 12 + fl)
          ..close(),
        _f);
  }

  @override
  bool shouldRepaint(InvPainter o) => true;
}

class InvadersPage extends StatefulWidget {
  const InvadersPage({super.key});
  @override
  State<InvadersPage> createState() => _InvadersPageState();
}

class _InvadersPageState extends State<InvadersPage>
    with WidgetsBindingObserver {
  late InvGame g;
  final tick = ValueNotifier<int>(0);
  final pausedN = ValueNotifier<bool>(false);
  final img = ValueNotifier<ui.Image?>(null);
  final Stopwatch _sw = Stopwatch();
  Timer? _loop;
  int _last = 0;
  bool _overShown = false;
  static const _m = {
    'shoot': 'move',
    'kill': 'clear',
    'ufo': 'tetris',
    'hit': 'hard'
  };

  void _snd(String e) => Snd.play(_m[e] ?? e);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    g = InvGame()..onEvent = _snd;
    _sw.start();
    _loadShip();
    _start();
  }

  // Optional custom ship: assets/images/ship.png (falls back to the drawn ship if missing)
  Future<void> _loadShip() async {
    try {
      final d = await rootBundle.load('assets/images/ship.png');
      final codec = await ui.instantiateImageCodec(d.buffer.asUint8List(),
          targetWidth: 128);
      final f = await codec.getNextFrame();
      if (mounted) img.value = f.image;
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loop?.cancel();
    tick.dispose();
    pausedN.dispose();
    img.dispose();
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
      'n': g.kills,
      'd': DateTime.now().millisecondsSinceEpoch,
      't': g.elapsedMs,
    }, 'invaders');
    showNeonDialog<void>(
      context,
      title: 'GAME OVER',
      message: 'Score ${g.score}\nWave ${g.level}  •  Kills ${g.kills}',
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
      g = InvGame()..onEvent = _snd;
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

  void _a(void Function() f) {
    if (pausedN.value || g.over) return;
    f();
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
                Text('WAVE ${g.level}',
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

  Widget _controls() => Row(children: [
        Expanded(
            child: CtrlButton(Icons.keyboard_arrow_left, pieceColors[0],
                () => _a(() => g.moveShip(-1)),
                rate: 25)),
        Expanded(
            child: CtrlButton(Icons.keyboard_arrow_right, pieceColors[0],
                () => _a(() => g.moveShip(1)),
                rate: 25)),
        const SizedBox(width: 12),
        Expanded(
            flex: 2,
            child: CtrlButton(Icons.bolt, pieceColors[4], () => _a(g.fire),
                rate: 90)),
      ]);

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
                      aspectRatio: iw / ih,
                      child: Stack(children: [
                        Positioned.fill(
                            child: CustomPaint(
                                painter: InvPainter(g, p.dark, tick, img))),
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
                                          NeonButton('RESUME',
                                              const Color(0xFF39FF14), _resume),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: SizedBox(height: 120, child: _controls()),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
