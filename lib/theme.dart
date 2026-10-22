import 'dart:math';
import 'package:flutter/material.dart';
import 'sound.dart';

const List<Color> pieceColors = [
  Color(0xFF00F0FF), // I cyan
  Color(0xFFFFE600), // O yellow
  Color(0xFFB400FF), // T purple
  Color(0xFF39FF14), // S green
  Color(0xFFFF2040), // Z red
  Color(0xFF2979FF), // J blue
  Color(0xFFFF8A00), // L orange
];

class Pal {
  final bool dark;
  const Pal(this.dark);
  static Pal of(BuildContext c) => Pal(Theme.of(c).brightness == Brightness.dark);
  Color get bg1 => dark ? const Color(0xFF05060F) : const Color(0xFFEAF1FF);
  Color get bg2 => dark ? const Color(0xFF16103F) : const Color(0xFFD6E4FF);
  Color get text => dark ? Colors.white : const Color(0xFF101636);
  Color get sub => dark ? Colors.white60 : Colors.black54;
  Color get panel => dark ? const Color(0xFF0C1030) : Colors.white;
  Color get accent => dark ? const Color(0xFF00F0FF) : const Color(0xFF6200EA);
  Color get board => dark ? const Color(0xFF070A1E) : const Color(0xFFF7F9FF);
  Color get grid => dark ? const Color(0x1A00F0FF) : const Color(0x22000000);
}

class Backdrop extends StatefulWidget {
  final Widget child;
  final bool animate;
  const Backdrop({super.key, required this.child, this.animate = true});
  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    if (widget.animate) c.repeat();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.bg2, p.bg1]),
      ),
      child: CustomPaint(painter: _Glow(c, p.dark), child: widget.child),
    );
  }
}

class _Glow extends CustomPainter {
  final Animation<double> a;
  final bool dark;
  _Glow(this.a, this.dark) : super(repaint: a);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 5; i++) {
      final t = a.value * 2 * pi + i * 1.3;
      final o = Offset(size.width * (0.5 + 0.4 * sin(t)), size.height * (0.5 + 0.4 * cos(t * 0.7 + i)));
      final r = size.width * 0.55;
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [pieceColors[i].withAlpha(dark ? 40 : 28), Colors.transparent],
          ).createShader(Rect.fromCircle(center: o, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_Glow o) => o.dark != dark;
}

class NeonButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double width;
  const NeonButton(this.label, this.color, this.onTap, {super.key, this.width = 260});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: () {
        Snd.play('click');
        onTap();
      },
      child: Container(
        width: width,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withAlpha(p.dark ? 30 : 40),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: color.withAlpha(p.dark ? 110 : 70), blurRadius: 14)],
        ),
        child: Text(label,
            style: TextStyle(
                color: p.text, fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 15)),
      ),
    );
  }
}

class NeonTitle extends StatelessWidget {
  const NeonTitle({super.key});
  @override
  Widget build(BuildContext context) {
    const idx = [4, 6, 1, 3, 0, 5];
    final dark = Pal.of(context).dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 6; i++)
          Text('TETRIS'[i],
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: pieceColors[idx[i]],
                shadows: [Shadow(color: pieceColors[idx[i]].withAlpha(dark ? 230 : 120), blurRadius: dark ? 20 : 6)],
              )),
      ],
    );
  }
}

/// App-themed popup (same look as the pause screen).
Future<T?> showNeonDialog<T>(BuildContext context,
    {required String title,
    String? message,
    required List<Widget> Function(BuildContext) buttons}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (c) {
      final p = Pal.of(c);
      return PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: p.panel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.accent, width: 2),
              boxShadow: [BoxShadow(color: p.accent.withAlpha(p.dark ? 110 : 60), blurRadius: 24)],
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: p.text, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3)),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.sub, fontSize: 15, height: 1.4)),
                ],
                const SizedBox(height: 20),
                for (final b in buttons(c)) ...[b, const SizedBox(height: 12)],
              ]),
            ),
          ),
        ),
      );
    },
  );
}
