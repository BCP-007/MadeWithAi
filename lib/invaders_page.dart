import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart' show CtrlButton;
import 'invaders_engine.dart';
import 'shell.dart';
import 'theme.dart';

const List<List<List<String>>> _sprites = [
  // squid
  [
    ['...XX...', '..XXXX..', '.XXXXXX.', 'XX.XX.XX', 'XXXXXXXX', '..X..X..', '.X.XX.X.', 'X.X..X.X'],
    ['...XX...', '..XXXX..', '.XXXXXX.', 'XX.XX.XX', 'XXXXXXXX', '.X.XX.X.', 'X......X', '.X....X.'],
  ],
  // crab
  [
    ['..X.....X..', '...X...X...', '..XXXXXXX..', '.XX.XXX.XX.', 'XXXXXXXXXXX', 'X.XXXXXXX.X', 'X.X.....X.X', '...XX.XX...'],
    ['..X.....X..', 'X..X...X..X', 'X.XXXXXXX.X', 'XXX.XXX.XXX', 'XXXXXXXXXXX', '.XXXXXXXXX.', '..X.....X..', '.X.......X.'],
  ],
  // octopus
  [
    ['....XXXX....', '.XXXXXXXXXX.', 'XXXXXXXXXXXX', 'XXX..XX..XXX', 'XXXXXXXXXXXX', '...XX..XX...', '..XX.XX.XX..', 'XX........XX'],
    ['....XXXX....', '.XXXXXXXXXX.', 'XXXXXXXXXXXX', 'XXX..XX..XXX', 'XXXXXXXXXXXX', '..XXX..XXX..', '.XX..XX..XX.', '..XX....XX..'],
  ],
];

int _typeOf(int row) => row == 0 ? 0 : (row <= 2 ? 1 : 2);

class InvadersScreen extends StatelessWidget {
  final bool resume;
  const InvadersScreen({super.key, required this.resume});

  @override
  Widget build(BuildContext context) {
    return ArcadeShell(
      id: 'invaders',
      resume: resume,
      create: (j) => j == null ? InvGame() : InvGame.fromJson(j),
      builder: (ctx, s) => _InvBody(s: s),
    );
  }
}

class _InvBody extends StatelessWidget {
  final ArcadeShellState s;
  const _InvBody({required this.s});

  InvGame get g => s.game as InvGame;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(children: [
      ArcadeHud(
        s: s,
        icon: Icons.rocket,
        color: pieceColors[1],
        lives: (x) => (x as InvGame).lives,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Center(
            child: AspectRatio(
              aspectRatio: fw / fh,
              child: LayoutBuilder(
                builder: (_, c) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => s.act(g.fire),
                  onPanUpdate: (d) => s.act(() => g.moveBy(d.delta.dx * fw / c.maxWidth)),
                  child: CustomPaint(painter: InvPainter(g, p.dark, s.tick), size: Size.infinite),
                ),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: SizedBox(
          height: 104,
          child: Row(children: [
            Expanded(
                flex: 2,
                child: CtrlButton(Icons.keyboard_arrow_left, pieceColors[0], () => s.act(() => g.moveShip(-1)), rate: 22)),
            Expanded(
                flex: 3,
                child: CtrlButton(Icons.bolt, pieceColors[4], () => s.act(g.fire), rate: 120)),
            Expanded(
                flex: 2,
                child: CtrlButton(Icons.keyboard_arrow_right, pieceColors[0], () => s.act(() => g.moveShip(1)), rate: 22)),
          ]),
        ),
      ),
    ]);
  }
}

class InvPainter extends CustomPainter {
  final InvGame g;
  final bool dark;
  InvPainter(this.g, this.dark, Listenable repaint) : super(repaint: repaint);

  static final Map<int, Path> _paths = {};
  static final List<List<double>> _stars = _mkStars();

  static List<List<double>> _mkStars() {
    final r = Random(7);
    return [for (var i = 0; i < 55; i++) [r.nextDouble() * fw, r.nextDouble() * fh, r.nextDouble() * 1.4 + .5, r.nextDouble() * 6]];
  }

  static Path _sprite(int type, int frame) {
    return _paths.putIfAbsent(type * 2 + frame, () {
      const px = 2.2;
      final rows = _sprites[type][frame];
      final w = rows[0].length * px, h = rows.length * px;
      final path = Path();
      for (var y = 0; y < rows.length; y++) {
        for (var x = 0; x < rows[y].length; x++) {
          if (rows[y][x] == 'X') path.addRect(Rect.fromLTWH(x * px - w / 2, y * px - h / 2, px + .2, px + .2));
        }
      }
      return path;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Pal(dark);
    final box = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(box, Paint()..color = p.board);
    canvas.save();
    canvas.clipRRect(box);
    canvas.scale(size.width / fw);

    // stars
    final t = g.elapsedMs / 1000.0;
    for (final s in _stars) {
      final a = (0.35 + 0.35 * sin(t * 1.5 + s[3])).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s[0], s[1]), s[2], Paint()..color = (dark ? Colors.white : const Color(0xFF6200EA)).withAlpha((a * 200).round()));
    }

    // ground line
    canvas.drawRect(const Rect.fromLTWH(0, shipY + 16, fw, 2), Paint()..color = pieceColors[0].withAlpha(200)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // shields
    const hpColors = [Colors.transparent, Color(0xFFFF8A00), Color(0xFFFFE600), Color(0xFF39FF14)];
    for (var i = 0; i < 4; i++) {
      final x0 = shieldX(i);
      for (var k = 0; k < 32; k++) {
        final hp = g.shields[i][k];
        if (hp == 0) continue;
        final r = Rect.fromLTWH(x0 + (k % 8) * shCell, shY + (k ~/ 8) * shCell, shCell, shCell);
        canvas.drawRect(r.inflate(.5), Paint()..color = hpColors[hp]);
      }
    }

    // invaders
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final fill = Paint();
    for (var i = 0; i < g.alive.length; i++) {
      if (!g.alive[i]) continue;
      final r = i ~/ iCols, c = i % iCols;
      final type = _typeOf(r);
      final col = Color(InvGame.colorOf(r));
      canvas.save();
      canvas.translate(g.gx + c * iSx + iW / 2, g.gy + r * iSy + iH / 2);
      final path = _sprite(type, g.frame);
      glow.color = col.withAlpha(130);
      canvas.drawPath(path, glow);
      fill.color = col;
      canvas.drawPath(path, fill);
      canvas.restore();
    }

    // UFO
    if (g.ufoDir != 0) {
      final o = Offset(g.ufoX, 36);
      const pink = Color(0xFFFF4FD8);
      canvas.drawOval(Rect.fromCenter(center: o, width: 40, height: 16), Paint()..color = pink.withAlpha(120)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawOval(Rect.fromCenter(center: o, width: 32, height: 10), Paint()..color = pink);
      canvas.drawArc(Rect.fromCenter(center: o + const Offset(0, -2), width: 16, height: 14), pi, pi, true, Paint()..color = pieceColors[0]);
      for (var i = -1; i <= 1; i++) {
        canvas.drawCircle(o + Offset(i * 9.0, 1), 1.5, Paint()..color = (g.elapsedMs ~/ 120 + i).isEven ? Colors.white : pieceColors[1]);
      }
    }

    // bullets
    for (final b in g.pBullets) {
      final r = Rect.fromCenter(center: Offset(b.x, b.y), width: 3, height: 12);
      canvas.drawRect(r.inflate(2), Paint()..color = pieceColors[0].withAlpha(150)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawRect(r, Paint()..color = Colors.white);
    }
    for (final b in g.eBullets) {
      final z = (b.y ~/ 4).isEven ? 3.0 : -3.0;
      final path = Path()
        ..moveTo(b.x, b.y - 8)
        ..lineTo(b.x + z, b.y - 4)
        ..lineTo(b.x - z, b.y)
        ..lineTo(b.x + z, b.y + 4)
        ..lineTo(b.x, b.y + 8);
      final glowP = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = pieceColors[4]
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final coreP = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF8A8A);
      canvas.drawPath(path, glowP);
      canvas.drawPath(path, coreP);
    }

    // ship
    final blink = g.invuln > 0 && (g.elapsedMs ~/ 90).isOdd;
    if (g.shipDead < 0 && !blink) {
      final x = g.shipX;
      const y = shipY;
      final body = Path()
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 18, y - 2, 36, 10), const Radius.circular(3)))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 11, y - 8, 22, 8), const Radius.circular(2)))
        ..addRect(Rect.fromLTWH(x - 2.5, y - 14, 5, 8));
      canvas.drawPath(body, Paint()..color = pieceColors[1].withAlpha(140)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawPath(body, Paint()..color = pieceColors[1]);
      canvas.drawRect(Rect.fromLTWH(x - 14, y + 1, 28, 2), Paint()..color = Colors.white.withAlpha(120));
    }

    // fx
    for (final f in g.fx) {
      final k = f.age / f.life;
      final col = Color(f.color);
      if (f.text != null) {
        final tp = TextPainter(
          text: TextSpan(text: f.text, style: TextStyle(color: col.withAlpha(((1 - k) * 255).round()), fontSize: 14, fontWeight: FontWeight.w900, shadows: [Shadow(color: col, blurRadius: 8)])),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(f.x - tp.width / 2, f.y - 8 - k * 14));
      }
      for (var i = 0; i < 10; i++) {
        final a = i * pi / 5 + f.x;
        final d = k * 26;
        canvas.drawCircle(Offset(f.x + cos(a) * d, f.y + sin(a) * d), (1 - k) * 3 + .4, Paint()..color = col.withAlpha(((1 - k) * 255).round()));
      }
    }

    // wave banner
    if (g.waveMs > 0 && g.shipDead < 0) {
      final tp = TextPainter(
        text: TextSpan(text: 'LEVEL ${g.level}', style: TextStyle(color: pieceColors[0], fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4, shadows: [Shadow(color: pieceColors[0], blurRadius: 14)])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((fw - tp.width) / 2, 250));
    }
    canvas.restore();

    canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = p.accent);
  }

  @override
  bool shouldRepaint(InvPainter o) => true;
}
