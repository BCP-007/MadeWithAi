import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'sound.dart';
import 'store.dart';
import 'theme.dart';

enum ArcadeKind { invaders, pacman }

class ArcadePage extends StatefulWidget {
  final ArcadeKind kind;
  const ArcadePage({super.key, required this.kind});

  @override
  State<ArcadePage> createState() => _ArcadePageState();
}

class _ArcadePageState extends State<ArcadePage> with WidgetsBindingObserver {
  late SpaceInvadersGame _invaders;
  late PacmanGame _pacman;
  final tick = ValueNotifier<int>(0);
  Timer? _loop;
  int _lastMs = 0;
  bool _paused = false;
  bool _overShown = false;

  bool get isInvaders => widget.kind == ArcadeKind.invaders;
  bool get over => isInvaders ? _invaders.over : _pacman.over;
  int get score => isInvaders ? _invaders.score : _pacman.score;
  int get level => isInvaders ? _invaders.level : _pacman.level;
  int get lives => isInvaders ? _invaders.lives : _pacman.lives;
  String get title => isInvaders ? 'SPACE INVADERS' : 'PAC-MAN';
  Color get accent =>
      isInvaders ? const Color(0xFF39FF14) : const Color(0xFFFFE600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newGames();
    _startLoop();
  }

  void _newGames() {
    _invaders = SpaceInvadersGame()..onEvent = Snd.play;
    _pacman = PacmanGame()..onEvent = Snd.play;
  }

  void _startLoop() {
    _loop?.cancel();
    _lastMs = DateTime.now().millisecondsSinceEpoch;
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_paused || over) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final dt = math.min(now - _lastMs, 100);
      _lastMs = now;
      if (isInvaders) {
        _invaders.update(dt);
      } else {
        _pacman.update(dt);
      }
      tick.value++;
      if (over) _gameOver();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !over)
      setState(() => _paused = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loop?.cancel();
    tick.dispose();
    super.dispose();
  }

  void _pause() {
    if (!over && mounted) setState(() => _paused = true);
  }

  void _resume() {
    if (mounted) {
      setState(() => _paused = false);
      _startLoop();
    }
  }

  void _gameOver() {
    if (_overShown || !mounted) return;
    _overShown = true;
    _loop?.cancel();
    _loop = null;
    Store.addScore({
      'g': isInvaders ? 'SPACE INVADERS' : 'PAC-MAN',
      's': score,
      'v': level,
      'n': isInvaders ? _invaders.waves : _pacman.level - 1,
      'd': DateTime.now().millisecondsSinceEpoch,
      't': isInvaders ? _invaders.elapsedMs : _pacman.elapsedMs,
    });
    showNeonDialog<void>(
      context,
      title: 'GAME OVER',
      message: '$title\nScore $score\nLevel $level',
      buttons: (dialogContext) => [
        NeonButton('PLAY AGAIN', const Color(0xFF39FF14), () {
          Navigator.pop(dialogContext);
          _restart();
        }, width: double.infinity),
        NeonButton('HOME', const Color(0xFFFF2040), () {
          Navigator.pop(dialogContext);
          Navigator.pop(context);
        }, width: double.infinity),
      ],
    );
  }

  void _restart() {
    setState(() {
      _newGames();
      _paused = false;
      _overShown = false;
    });
    _startLoop();
  }

  Future<void> _exit() async {
    if (over) {
      Navigator.pop(context);
      return;
    }
    _pause();
    final result = await showNeonDialog<int>(
      context,
      title: 'LEAVE MATCH?',
      message: 'Your arcade run will end if you leave.',
      buttons: (dialogContext) => [
        NeonButton('KEEP PLAYING', const Color(0xFF00F0FF),
            () => Navigator.pop(dialogContext, 0),
            width: double.infinity),
        NeonButton('EXIT TO HOME', const Color(0xFFFF2040),
            () => Navigator.pop(dialogContext, 1),
            width: double.infinity),
      ],
    );
    if (!mounted) return;
    if (result == 1) {
      Navigator.pop(context);
    } else {
      _resume();
    }
  }

  void _move(int direction) {
    if (_paused || over) return;
    if (isInvaders) {
      _invaders.move(direction);
    } else {
      _pacman.queueDirection(
          direction == -1 ? PacDirection.left : PacDirection.right);
    }
    tick.value++;
  }

  void _pacDirection(PacDirection direction) {
    if (!_paused && !over) {
      _pacman.queueDirection(direction);
      tick.value++;
    }
  }

  Widget _control(IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Snd.play('click');
          onTap();
        },
        child: Container(
          height: 58,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.5),
            boxShadow: [BoxShadow(color: color.withAlpha(55), blurRadius: 9)],
          ),
          child:
              Center(child: Icon(icon, color: Pal.of(context).text, size: 30)),
        ),
      ),
    );
  }

  Widget _controls() {
    if (isInvaders) {
      return Row(children: [
        _control(Icons.keyboard_arrow_left, const Color(0xFF00F0FF),
            () => _move(-1)),
        _control(Icons.keyboard_arrow_right, const Color(0xFF00F0FF),
            () => _move(1)),
        _control(Icons.flash_on, const Color(0xFFFF2040), _invaders.fire),
      ]);
    }
    return Column(children: [
      Expanded(
          child: Row(children: [
        const Spacer(),
        _control(Icons.keyboard_arrow_up, const Color(0xFFFFE600),
            () => _pacDirection(PacDirection.up)),
        const Spacer(),
      ])),
      Expanded(
          child: Row(children: [
        _control(Icons.keyboard_arrow_left, const Color(0xFFFFE600),
            () => _pacDirection(PacDirection.left)),
        _control(Icons.keyboard_arrow_down, const Color(0xFFFFE600),
            () => _pacDirection(PacDirection.down)),
        _control(Icons.keyboard_arrow_right, const Color(0xFFFFE600),
            () => _pacDirection(PacDirection.right)),
      ])),
    ]);
  }

  Widget _hud(Pal p) {
    return ValueListenableBuilder<int>(
      valueListenable: tick,
      builder: (_, __, ___) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(children: [
          Icon(isInvaders ? Icons.rocket_launch : Icons.mood,
              color: accent, size: 28),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: p.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
                Text('LEVEL $level   •   SCORE $score',
                    style: TextStyle(
                        color: p.sub, fontSize: 11, letterSpacing: 1)),
              ])),
          Row(children: [
            for (var i = 0; i < lives; i++)
              Icon(Icons.favorite, color: const Color(0xFFFF3366), size: 19)
          ]),
          IconButton(
              onPressed: _pause,
              icon:
                  Icon(Icons.pause_circle_outline, color: p.accent, size: 30)),
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
        if (!didPop) _exit();
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Center(
                    child: AspectRatio(
                  aspectRatio: isInvaders ? .68 : .82,
                  child: Stack(children: [
                    Positioned.fill(
                        child: ValueListenableBuilder<int>(
                      valueListenable: tick,
                      builder: (_, __, ___) => CustomPaint(
                        painter: ArcadePainter(
                            kind: widget.kind,
                            invaders: _invaders,
                            pacman: _pacman,
                            dark: p.dark),
                      ),
                    )),
                    if (_paused)
                      Positioned.fill(
                          child: Container(
                        color: Colors.black.withAlpha(190),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('PAUSED',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4)),
                              const SizedBox(height: 20),
                              NeonButton(
                                  'RESUME', const Color(0xFF39FF14), _resume),
                              const SizedBox(height: 12),
                              NeonButton(
                                  'EXIT', const Color(0xFFFF2040), _exit),
                            ]),
                      )),
                  ]),
                )),
              )),
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: SizedBox(
                      height: isInvaders ? 74 : 126, child: _controls())),
            ]))),
      ),
    );
  }
}

class ArcadePainter extends CustomPainter {
  final ArcadeKind kind;
  final SpaceInvadersGame invaders;
  final PacmanGame pacman;
  final bool dark;

  ArcadePainter(
      {required this.kind,
      required this.invaders,
      required this.pacman,
      required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Pal(dark);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
        Paint()..color = p.board);
    if (kind == ArcadeKind.invaders) {
      _paintInvaders(canvas, size, invaders);
    } else {
      _paintPacman(canvas, size, pacman);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kind == ArcadeKind.invaders
              ? const Color(0xFF39FF14)
              : const Color(0xFFFFE600));
  }

  void _paintInvaders(Canvas canvas, Size size, SpaceInvadersGame game) {
    final cellW = size.width / 10;
    final cellH = size.height / 15;
    final grid = Paint()..color = const Color(0x1839FF14);
    for (var x = 1; x < 10; x++)
      canvas.drawLine(
          Offset(x * cellW, 0), Offset(x * cellW, size.height), grid);
    for (var y = 1; y < 15; y++)
      canvas.drawLine(
          Offset(0, y * cellH), Offset(size.width, y * cellH), grid);
    final colors = [
      const Color(0xFFFF2040),
      const Color(0xFFFF8A00),
      const Color(0xFFB400FF),
      const Color(0xFF00F0FF),
      const Color(0xFF39FF14)
    ];
    for (var row = 0; row < SpaceInvadersGame.enemyRows; row++) {
      for (var col = 0; col < SpaceInvadersGame.enemyCols; col++) {
        if (!game.alive[row * SpaceInvadersGame.enemyCols + col]) continue;
        final pos = game.enemyPosition(row, col);
        final x = pos.dx * size.width;
        final y = pos.dy * size.height;
        final color = colors[row];
        final paint = Paint()..color = color;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(x, y),
                    width: size.width * .065,
                    height: size.height * .035),
                const Radius.circular(4)),
            paint);
        canvas.drawCircle(Offset(x - size.width * .018, y), size.width * .008,
            Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x + size.width * .018, y), size.width * .008,
            Paint()..color = Colors.white);
      }
    }
    final ship = Path()
      ..moveTo(game.playerX * size.width, size.height * .91)
      ..lineTo((game.playerX - .045) * size.width, size.height * .96)
      ..lineTo((game.playerX + .045) * size.width, size.height * .96)
      ..close();
    canvas.drawPath(ship, Paint()..color = const Color(0xFF00F0FF));
    for (final bullet in game.bullets) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(bullet.x * size.width, bullet.y * size.height),
                  width: 4,
                  height: 13),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFFFFE600));
    }
    for (final bullet in game.enemyBullets) {
      canvas.drawCircle(Offset(bullet.x * size.width, bullet.y * size.height),
          4, Paint()..color = const Color(0xFFFF3366));
    }
  }

  void _paintPacman(Canvas canvas, Size size, PacmanGame game) {
    final cw = size.width / PacmanGame.cols;
    final ch = size.height / PacmanGame.rows;
    for (var y = 0; y < PacmanGame.rows; y++) {
      for (var x = 0; x < PacmanGame.cols; x++) {
        final rect = Rect.fromLTWH(x * cw, y * ch, cw, ch);
        if (game.isWall(x, y)) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  rect.deflate(1), const Radius.circular(4)),
              Paint()..color = const Color(0xFF183A91));
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  rect.deflate(2), const Radius.circular(3)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = const Color(0xFF00F0FF).withAlpha(120));
        } else if (game.pellets.contains('$x:$y')) {
          canvas.drawCircle(
              rect.center, cw * .075, Paint()..color = const Color(0xFFFFE600));
        }
      }
    }
    final pacCenter = Offset((game.pacX + .5) * cw, (game.pacY + .5) * ch);
    final pacPaint = Paint()..color = const Color(0xFFFFE600);
    canvas.drawCircle(pacCenter, cw * .38, pacPaint);
    for (final ghost in game.ghosts) {
      final center = Offset((ghost.x + .5) * cw, (ghost.y + .5) * ch);
      final color =
          game.frightenedMs > 0 ? const Color(0xFF2979FF) : ghost.color;
      canvas.drawCircle(Offset(center.dx, center.dy - ch * .08), cw * .34,
          Paint()..color = color);
      canvas.drawRect(
          Rect.fromLTWH(
              center.dx - cw * .34, center.dy - ch * .08, cw * .68, ch * .34),
          Paint()..color = color);
      canvas.drawCircle(Offset(center.dx - cw * .12, center.dy - ch * .1),
          cw * .08, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(center.dx + cw * .12, center.dy - ch * .1),
          cw * .08, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(ArcadePainter oldDelegate) => true;
}

class ArcadeBullet {
  double x;
  double y;
  final double speed;
  ArcadeBullet(this.x, this.y, this.speed);
}

class SpaceInvadersGame {
  static const enemyRows = 5;
  static const enemyCols = 8;
  final random = math.Random();
  final alive = List<bool>.filled(enemyRows * enemyCols, true);
  final bullets = <ArcadeBullet>[];
  final enemyBullets = <ArcadeBullet>[];
  double enemyX = .12;
  double enemyY = .08;
  double enemyDirection = 1;
  double playerX = .5;
  double fireTimer = 0;
  int score = 0;
  int lives = 3;
  int level = 1;
  int waves = 0;
  int elapsedMs = 0;
  bool over = false;
  void Function(String)? onEvent;

  Offset enemyPosition(int row, int col) =>
      Offset(enemyX + col * .105, enemyY + row * .065);

  void _event(String value) => onEvent?.call(value);

  void move(int direction) {
    if (over) return;
    playerX = (playerX + direction * .055).clamp(.07, .93).toDouble();
    _event('move');
  }

  void fire() {
    if (over || bullets.length > 3) return;
    bullets.add(ArcadeBullet(playerX, .89, -.95));
    _event('hard');
  }

  void update(int dt) {
    if (over) return;
    elapsedMs += dt;
    final seconds = dt / 1000;
    enemyX += enemyDirection * seconds * (.10 + level * .012);
    if (enemyX < .03 || enemyX + .74 > .97) {
      enemyDirection *= -1;
      enemyY += .025;
      _event('land');
    }
    fireTimer += dt;
    if (fireTimer > math.max(520, 1250 - level * 70)) {
      fireTimer = 0;
      final columns = [
        for (var col = 0; col < enemyCols; col++)
          if (_columnHasEnemy(col)) col
      ];
      if (columns.isNotEmpty) {
        final col = columns[random.nextInt(columns.length)];
        var row = enemyRows - 1;
        while (row >= 0 && !alive[row * enemyCols + col]) row--;
        final pos = enemyPosition(row, col);
        enemyBullets.add(ArcadeBullet(pos.dx, pos.dy + .03, .42 + level * .02));
      }
    }
    for (final bullet in bullets) bullet.y += bullet.speed * seconds;
    for (final bullet in enemyBullets) bullet.y += bullet.speed * seconds;
    bullets.removeWhere((bullet) => bullet.y < 0 || bullet.y > 1);
    enemyBullets.removeWhere((bullet) => bullet.y > 1);
    for (var i = bullets.length - 1; i >= 0; i--) {
      var hit = false;
      for (var row = 0; row < enemyRows && !hit; row++) {
        for (var col = 0; col < enemyCols; col++) {
          final index = row * enemyCols + col;
          if (!alive[index]) continue;
          final pos = enemyPosition(row, col);
          if ((bullets[i].x - pos.dx).abs() < .045 &&
              (bullets[i].y - pos.dy).abs() < .035) {
            alive[index] = false;
            score += (enemyRows - row) * 20;
            bullets.removeAt(i);
            _event('clear');
            hit = true;
            break;
          }
        }
      }
    }
    for (var i = enemyBullets.length - 1; i >= 0; i--) {
      if ((enemyBullets[i].x - playerX).abs() < .06 &&
          enemyBullets[i].y > .86) {
        enemyBullets.removeAt(i);
        lives--;
        _event(lives == 0 ? 'over' : 'land');
        if (lives <= 0) over = true;
      }
    }
    if (enemyY + enemyRows * .065 > .82) {
      lives = 0;
      over = true;
      _event('over');
    }
    if (alive.every((value) => !value)) {
      waves++;
      level++;
      enemyX = .12;
      enemyY = .08;
      alive.setAll(0, List<bool>.filled(alive.length, true));
      _event('level');
    }
  }

  bool _columnHasEnemy(int col) => [
        for (var row = 0; row < enemyRows; row++) alive[row * enemyCols + col]
      ].any((value) => value);
}

enum PacDirection { up, down, left, right }

class PacGhost {
  int x;
  int y;
  int dx;
  int dy;
  final Color color;
  PacGhost(this.x, this.y, this.dx, this.dy, this.color);
}

class PacmanGame {
  static const cols = 19;
  static const rows = 21;
  final random = math.Random();
  final pellets = <String>{};
  final ghosts = <PacGhost>[];
  int pacX = 9;
  int pacY = 15;
  int dx = 0;
  int dy = 0;
  PacDirection? queued;
  int score = 0;
  int lives = 3;
  int level = 1;
  int elapsedMs = 0;
  int frightenedMs = 0;
  int stepMs = 0;
  bool over = false;
  void Function(String)? onEvent;

  PacmanGame() {
    _fillPellets();
    _resetGhosts();
  }

  void _event(String value) => onEvent?.call(value);

  bool isWall(int x, int y) {
    if (x <= 0 || x >= cols - 1 || y <= 0 || y >= rows - 1) return true;
    if ((y == 4 || y == 10 || y == 16) && x >= 2 && x <= 16 && x != 9)
      return true;
    if ((x == 4 || x == 14) && y >= 2 && y <= 18 && y != 8 && y != 15)
      return true;
    return false;
  }

  void _fillPellets() {
    pellets.clear();
    for (var y = 1; y < rows - 1; y++) {
      for (var x = 1; x < cols - 1; x++) {
        if (!isWall(x, y)) pellets.add('$x:$y');
      }
    }
    pellets.remove('$pacX:$pacY');
    pellets.remove('9:9');
  }

  void _resetGhosts() {
    ghosts
      ..clear()
      ..add(PacGhost(9, 9, 1, 0, const Color(0xFFFF3366)))
      ..add(PacGhost(8, 9, -1, 0, const Color(0xFFFF8A00)))
      ..add(PacGhost(10, 9, 0, 1, const Color(0xFF00F0FF)));
  }

  void queueDirection(PacDirection direction) {
    queued = direction;
    _event('move');
  }

  void update(int dt) {
    if (over) return;
    elapsedMs += dt;
    frightenedMs = math.max(0, frightenedMs - dt);
    stepMs += dt;
    while (stepMs >= 135 && !over) {
      stepMs -= 135;
      _step();
    }
  }

  void _step() {
    if (queued != null) {
      final next = _vector(queued!);
      if (_canMove(pacX + next.$1, pacY + next.$2)) {
        dx = next.$1;
        dy = next.$2;
      }
    }
    if (_canMove(pacX + dx, pacY + dy)) {
      pacX += dx;
      pacY += dy;
    }
    final pellet = '$pacX:$pacY';
    if (pellets.remove(pellet)) {
      score += 10;
      if (pacX == 1 || pacX == cols - 2) {
        score += 40;
        frightenedMs = 5000;
      }
      _event('clear');
    }
    for (final ghost in ghosts) _moveGhost(ghost);
    for (final ghost in ghosts) {
      if (ghost.x == pacX && ghost.y == pacY) {
        if (frightenedMs > 0) {
          score += 200;
          ghost.x = 9;
          ghost.y = 9;
          _event('tetris');
        } else {
          lives--;
          _event(lives == 0 ? 'over' : 'land');
          pacX = 9;
          pacY = 15;
          dx = 0;
          dy = 0;
          if (lives <= 0) over = true;
        }
      }
    }
    if (pellets.isEmpty) {
      level++;
      _fillPellets();
      _resetGhosts();
      _event('level');
    }
  }

  (int, int) _vector(PacDirection direction) {
    switch (direction) {
      case PacDirection.up:
        return (0, -1);
      case PacDirection.down:
        return (0, 1);
      case PacDirection.left:
        return (-1, 0);
      case PacDirection.right:
        return (1, 0);
    }
  }

  bool _canMove(int x, int y) =>
      x >= 0 && x < cols && y >= 0 && y < rows && !isWall(x, y);

  void _moveGhost(PacGhost ghost) {
    final options = <List<int>>[];
    for (final vector in const [
      [0, -1],
      [0, 1],
      [-1, 0],
      [1, 0]
    ]) {
      if (_canMove(ghost.x + vector[0], ghost.y + vector[1]) &&
          !(vector[0] == -ghost.dx && vector[1] == -ghost.dy))
        options.add(vector);
    }
    if (options.isEmpty) return;
    final choice = options[random.nextInt(options.length)];
    ghost.dx = choice[0];
    ghost.dy = choice[1];
    ghost.x += ghost.dx;
    ghost.y += ghost.dy;
  }
}
