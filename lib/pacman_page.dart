import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'game_page.dart' show CtrlButton;
import 'pacman_engine.dart';
import 'shell.dart';
import 'theme.dart';

const List<Color> _ghostColors = [
  Color(0xFFFF2040), // blinky red
  Color(0xFFFF4FD8), // pinky pink
  Color(0xFF00F0FF), // inky cyan
  Color(0xFFFF8A00), // clyde orange
];
const List<Color> _wallColors = [
  Color(0xFF2979FF),
  Color(0xFFB400FF),
  Color(0xFF00F0FF),
  Color(0xFF39FF14),
  Color(0xFFFF8A00),
];

class PacmanScreen extends StatelessWidget {
  final bool resume;
  const PacmanScreen({super.key, required this.resume});

  @override
  Widget build(BuildContext context) {
    return ArcadeShell(
      id: 'pacman',
      resume: resume,
      create: (j) => j == null ? PacGame() : PacGame.fromJson(j),
      builder: (ctx, s) => _PacBody(s: s),
    );
  }
}

class _PacBody extends StatefulWidget {
  final ArcadeShellState s;
  const _PacBody({required this.s});
  @override
  State<_PacBody> createState() => _PacBodyState();
}

class _PacBodyState extends State<_PacBody> {
  Offset _acc = Offset.zero;

  ArcadeShellState get s => widget.s;
  PacGame get g => s.game as PacGame;

  void _dir(int dx, int dy) => s.act(() => g.setDir(dx, dy));

  Widget _btn(IconData i, int dx, int dy, Color c) =>
      Expanded(child: CtrlButton(i, c, () => _dir(dx, dy)));

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(children: [
      ArcadeHud(
        s: s,
        icon: Icons.circle,
        color: pieceColors[1],
        lives: (x) => (x as PacGame).lives,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Center(
            child: AspectRatio(
              aspectRatio: pCols / pRows,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _acc = Offset.zero,
                onPanUpdate: (d) {
                  _acc += d.delta;
                  if (_acc.distance > 12) {
                    final a = _acc;
                    _acc = Offset.zero;
                    if (a.dx.abs() > a.dy.abs()) {
                      _dir(a.dx > 0 ? 1 : -1, 0);
                    } else {
                      _dir(0, a.dy > 0 ? 1 : -1);
                    }
                  }
                },
                child: CustomPaint(painter: PacPainter(g, p.dark, s.tick)),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: SizedBox(
          height: 132,
          child: Column(children: [
            Expanded(
              child: Row(children: [
                const Spacer(),
                _btn(Icons.keyboard_arrow_up, 0, -1, pieceColors[0]),
                const Spacer(),
              ]),
            ),
            Expanded(
              child: Row(children: [
                _btn(Icons.keyboard_arrow_left, -1, 0, pieceColors[3]),
                _btn(Icons.keyboard_arrow_down, 0, 1, pieceColors[5]),
                _btn(Icons.keyboard_arrow_right, 1, 0, pieceColors[6]),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class PacPainter extends CustomPainter {
  final PacGame g;
  final bool dark;
  PacPainter(this.g, this.dark, Listenable repaint) : super(repaint: repaint);

  static ui.Picture? _pic;
  static int _key = -1;
  static double _w = 0;

  static ui.Picture _buildWalls(double cs, Size size, Color wc, Color bg, bool dark) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final outer = Path(), inner = Path();
    for (var r = 0; r < pRows; r++) {
      for (var col = 0; col < pCols; col++) {
        if (!pWall(col, r)) continue;
        final x = col * cs, y = r * cs;
        outer.addRect(Rect.fromLTWH(x, y, cs, cs));
        final l = pWall(col - 1, r) ? 0.0 : 2.5;
        final rt = pWall(col + 1, r) ? 0.0 : 2.5;
        final t = pWall(col, r - 1) ? 0.0 : 2.5;
        final b = pWall(col, r + 1) ? 0.0 : 2.5;
        inner.addRect(Rect.fromLTRB(x + l, y + t, x + cs - rt, y + cs - b));
      }
    }
    c.drawPath(outer, Paint()..color = wc.withAlpha(150)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    c.drawPath(outer, Paint()..color = wc);
    c.drawPath(inner, Paint()..color = bg);
    c.drawPath(inner, Paint()..color = wc.withAlpha(dark ? 40 : 30));
    // ghost door
    for (var r = 0; r < pRows; r++) {
      for (var col = 0; col < pCols; col++) {
        if (pBase[r * pCols + col] == 4) {
          c.drawRect(Rect.fromLTWH(col * cs, r * cs + cs * .4, cs, cs * .2), Paint()..color = const Color(0xFFFF4FD8));
        }
      }
    }
    return rec.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Pal(dark);
    final cs = size.width / pCols;
    canvas.clipRect(Offset.zero & size);
    final box = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(box, Paint()..color = p.board);

    // walls (cached picture)
    final flash = g.state == 3 && (g.stateMs ~/ 200).isOdd;
    final key = (flash ? 1000 : 0) + (dark ? 100 : 0) + (g.level - 1) % _wallColors.length;
    if (_pic == null || _key != key || (_w - size.width).abs() > 0.5) {
      _pic?.dispose();
      final wc = flash ? Colors.white : _wallColors[(g.level - 1) % _wallColors.length];
      _pic = _buildWalls(cs, size, wc, p.board, dark);
      _key = key;
      _w = size.width;
    }
    canvas.drawPicture(_pic!);

    // dots & power pellets
    final dot = Paint()..color = dark ? const Color(0xFFFFD6A5) : const Color(0xFFFF8A00);
    final pw = g.elapsedMs * 0.008;
    for (var i = 0; i < g.cells.length; i++) {
      final t = g.cells[i];
      if (t != 2 && t != 3) continue;
      final o = Offset((i % pCols + .5) * cs, (i ~/ pCols + .5) * cs);
      if (t == 2) {
        canvas.drawCircle(o, cs * .1, dot);
      } else {
        final r = cs * (.27 + .06 * sin(pw));
        canvas.drawCircle(o, r * 1.6, Paint()..color = const Color(0xFFFF4FD8).withAlpha(120)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(o, r, Paint()..color = const Color(0xFFFF4FD8));
      }
    }

    // ghosts
    if (g.state != 2) {
      for (final gh in g.ghosts) {
        _ghost(canvas, gh, cs);
      }
    }
    _pac(canvas, cs);

    if (g.state == 0) {
      _text(canvas, 'READY!', Offset(size.width / 2, 11.5 * cs), cs * 1.1, pieceColors[1]);
    }

    canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = p.accent);
  }

  void _text(Canvas c, String s, Offset center, double size, Color col) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: col,
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              shadows: [Shadow(color: col, blurRadius: 12), const Shadow(color: Colors.black, blurRadius: 4)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _pac(Canvas c, double cs) {
    final o = Offset((g.pacX + .5) * cs, (g.pacY + .5) * cs);
    final r = cs * .46;
    var mouth = g.moving && g.state == 1 ? 0.08 + 0.55 * (0.5 + 0.5 * sin(g.elapsedMs * 0.03)) : 0.35;
    if (g.state == 2) {
      final t = min(1.0, g.stateMs / 1300);
      if (t >= 1) return;
      mouth = 0.1 + t * (pi - 0.1);
    }
    final base = atan2(g.fdy.toDouble(), g.fdx.toDouble());
    final rect = Rect.fromCircle(center: o, radius: r);
    c.drawCircle(o, r * 1.5, Paint()..color = pieceColors[1].withAlpha(110)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    c.drawArc(rect, base + mouth, 2 * pi - 2 * mouth, true, Paint()..color = pieceColors[1]);
    // highlight
    c.drawCircle(o + Offset(-r * .25, -r * .45), r * .14, Paint()..color = Colors.white.withAlpha(150));
  }

  void _ghost(Canvas c, PGhost gh, double cs) {
    final x = (gh.x + .5) * cs, y = (gh.y + .5) * cs;
    final w = cs * .88;
    final fr = gh.mode == 3;
    final flash = fr && g.frightMs < 2000 && (g.elapsedMs ~/ 170).isOdd;
    final body = fr ? (flash ? Colors.white : const Color(0xFF2979FF)) : _ghostColors[gh.id];
    if (gh.mode != 4) {
      final left = x - w / 2, right = x + w / 2, top = y - w / 2, bottom = y + w / 2;
      final path = Path()
        ..moveTo(left, bottom)
        ..lineTo(left, y)
        ..arcTo(Rect.fromLTWH(left, top, w, w), pi, pi, false)
        ..lineTo(right, bottom);
      final seg = w / 3;
      final amp = cs * .12 * ((g.elapsedMs ~/ 150).isEven ? 1 : -1);
      for (var i = 0; i < 3; i++) {
        final x0 = right - seg * i;
        path.quadraticBezierTo(x0 - seg / 2, bottom + amp * (i.isEven ? 1 : -1), x0 - seg, bottom);
      }
      path.close();
      c.drawPath(path, Paint()..color = body.withAlpha(150)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      c.drawPath(path, Paint()..color = body);
    }
    if (fr) {
      final f = flash ? const Color(0xFFFF2040) : const Color(0xFFFFE9C8);
      c.drawCircle(Offset(x - w * .17, y - w * .05), w * .06, Paint()..color = f);
      c.drawCircle(Offset(x + w * .17, y - w * .05), w * .06, Paint()..color = f);
      final m = Path()..moveTo(x - w * .28, y + w * .2);
      for (var i = 1; i <= 4; i++) {
        m.lineTo(x - w * .28 + w * .14 * i, y + w * (i.isOdd ? .12 : .2));
      }
      c.drawPath(
          m,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = f);
    } else {
      final ey = y - w * .08;
      for (final sx in [-1.0, 1.0]) {
        final e = Offset(x + sx * w * .2, ey);
        c.drawOval(Rect.fromCenter(center: e, width: w * .26, height: w * .32), Paint()..color = Colors.white);
        c.drawCircle(e + Offset(gh.dx * w * .06, gh.dy * w * .07), w * .07, Paint()..color = const Color(0xFF1A237E));
      }
    }
  }

  @override
  bool shouldRepaint(PacPainter o) => true;
}
