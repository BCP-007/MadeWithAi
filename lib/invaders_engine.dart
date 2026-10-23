import 'dart:math';
import 'shell.dart';

const double fw = 360, fh = 480;
const int iCols = 8, iRows = 5;
const double iSx = 32, iSy = 28, iW = 24, iH = 16, iStep = 7;
const double shipY = 440;
const double shY = 372, shCell = 6;
const List<String> shMask = ['.XXXXXX.', 'XXXXXXXX', 'XXXXXXXX', 'XXX..XXX'];

double shieldX(int i) => fw * (i + .5) / 4 - 24;
List<int> _newShield() => [
      for (final row in shMask)
        for (var i = 0; i < 8; i++) row[i] == 'X' ? 3 : 0
    ];

class Bullet {
  double x, y;
  final double vy;
  Bullet(this.x, this.y, this.vy);
}

class Fx {
  final double x, y;
  final int life, color;
  final String? text;
  int age = 0;
  Fx(this.x, this.y, this.color, {this.life = 450, this.text});
}

class InvGame extends ArcadeGame {
  bool over = false;
  int score = 0, level = 1, elapsedMs = 0;
  int lives = 3, kills = 0;

  final List<bool> alive = List<bool>.filled(iCols * iRows, true);
  double gx = 20, gy = 56;
  int dir = 1, frame = 0;
  double stepAcc = 0, shootAcc = 0;

  double shipX = fw / 2;
  int shipDead = -1, invuln = 0, fireCd = 0, waveMs = 0;

  final List<Bullet> pBullets = [], eBullets = [];
  final List<Fx> fx = [];
  final List<List<int>> shields = [for (var i = 0; i < 4; i++) _newShield()];

  double ufoX = 0;
  int ufoDir = 0, ufoMs = 12000;
  final Random _rng = Random();

  InvGame() {
    _newWave();
  }

  factory InvGame.fromJson(Map<String, dynamic> j) {
    final g = InvGame();
    final a = List<int>.from(j['a'] as List);
    final sh = List<int>.from(j['sh'] as List);
    if (a.length != iCols * iRows || sh.length != 128) throw const FormatException('bad save');
    for (var i = 0; i < a.length; i++) {
      g.alive[i] = a[i] == 1;
    }
    for (var i = 0; i < 4; i++) {
      for (var k = 0; k < 32; k++) {
        g.shields[i][k] = sh[i * 32 + k];
      }
    }
    g.gx = (j['gx'] as num).toDouble();
    g.gy = (j['gy'] as num).toDouble();
    g.dir = j['dir'] as int;
    g.score = j['s'] as int;
    g.level = j['v'] as int;
    g.lives = j['l'] as int;
    g.kills = j['n'] as int;
    g.elapsedMs = j['e'] as int;
    g.shipX = (j['x'] as num).toDouble();
    g.invuln = 1500;
    g.waveMs = 900;
    return g;
  }

  @override
  Map<String, dynamic> toJson() => {
        'a': [for (final b in alive) b ? 1 : 0],
        'sh': [for (final s in shields) ...s],
        'gx': gx,
        'gy': gy,
        'dir': dir,
        's': score,
        'v': level,
        'l': lives,
        'n': kills,
        'e': elapsedMs,
        'x': shipX,
      };

  @override
  Map<String, dynamic> record() => {
        's': score,
        'v': level,
        'n': kills,
        'd': DateTime.now().millisecondsSinceEpoch,
        't': elapsedMs,
      };

  void _ev(String e) => onEvent?.call(e);

  int get aliveCount => alive.where((b) => b).length;

  static int pts(int row) => row == 0 ? 30 : (row <= 2 ? 20 : 10);
  static int colorOf(int row) => row == 0 ? 0xFFB400FF : (row <= 2 ? 0xFF00F0FF : 0xFF39FF14);

  void _newWave() {
    for (var i = 0; i < alive.length; i++) {
      alive[i] = true;
    }
    for (var i = 0; i < 4; i++) {
      final f = _newShield();
      for (var k = 0; k < 32; k++) {
        shields[i][k] = f[k];
      }
    }
    gx = 20;
    gy = 56.0 + min(level - 1, 6) * 10;
    dir = 1;
    stepAcc = 0;
    shootAcc = 0;
    pBullets.clear();
    eBullets.clear();
    ufoDir = 0;
    ufoMs = 8000 + _rng.nextInt(8000);
    waveMs = 1500;
  }

  // ---------------- input ----------------
  void moveShip(int d) => moveBy(d * 7.0);

  void moveBy(double dx) {
    if (shipDead >= 0 || over) return;
    shipX = (shipX + dx).clamp(20.0, fw - 20.0).toDouble();
  }

  void fire() {
    if (shipDead >= 0 || over || fireCd > 0 || pBullets.length >= 2) return;
    pBullets.add(Bullet(shipX, shipY - 14, -520));
    fireCd = 280;
    _ev('move');
  }

  // ---------------- update ----------------
  @override
  void update(int dt) {
    if (over) return;
    elapsedMs += dt;
    if (fireCd > 0) fireCd -= dt;
    if (invuln > 0) invuln -= dt;
    for (final f in fx) {
      f.age += dt;
    }
    fx.removeWhere((f) => f.age > f.life);

    if (shipDead >= 0) {
      shipDead += dt;
      if (shipDead >= 1200) {
        lives--;
        if (lives <= 0) {
          over = true;
          _ev('over');
          return;
        }
        shipDead = -1;
        invuln = 2000;
        shipX = fw / 2;
      }
      return;
    }
    if (waveMs > 0) {
      waveMs -= dt;
      return;
    }

    final s = dt / 1000.0;
    final maxMove = 520 * s;
    final sub = max(1, (maxMove / 4).ceil());
    for (var k = 0; k < sub && shipDead < 0; k++) {
      for (final b in pBullets) {
        b.y += b.vy * s / sub;
      }
      for (final b in eBullets) {
        b.y += b.vy * s / sub;
      }
      _collide();
    }
    pBullets.removeWhere((b) => b.y < -12);
    eBullets.removeWhere((b) => b.y > fh + 12);
    if (shipDead >= 0) return;

    stepAcc += dt;
    final iv = max(40.0, (60 + aliveCount * 10.0) * pow(0.92, level - 1));
    if (stepAcc >= iv) {
      stepAcc = 0;
      _step();
      if (over) return;
    }
    _shoot(dt);
    _ufo(dt, s);

    if (aliveCount == 0) {
      level++;
      _ev('level');
      _newWave();
    }
  }

  void _step() {
    var minC = iCols, maxC = -1, maxR = -1;
    for (var i = 0; i < alive.length; i++) {
      if (!alive[i]) continue;
      final c = i % iCols, r = i ~/ iCols;
      minC = min(minC, c);
      maxC = max(maxC, c);
      maxR = max(maxR, r);
    }
    if (maxC < 0) return;
    final left = gx + minC * iSx, right = gx + maxC * iSx + iW;
    if (dir > 0 ? right + iStep > fw - 8 : left - iStep < 8) {
      gy += 14;
      dir = -dir;
    } else {
      gx += dir * iStep;
    }
    frame ^= 1;
    _crush();
    if (gy + maxR * iSy + iH >= shipY - 18) {
      over = true;
      lives = 0;
      _ev('over');
    }
  }

  void _crush() {
    for (final sh in shields) {
      final i = shields.indexOf(sh);
      final x0 = shieldX(i);
      for (var k = 0; k < sh.length; k++) {
        if (sh[k] == 0) continue;
        final cx = x0 + (k % 8) * shCell, cy = shY + (k ~/ 8) * shCell;
        for (var a = 0; a < alive.length; a++) {
          if (!alive[a]) continue;
          final ix = gx + (a % iCols) * iSx, iy = gy + (a ~/ iCols) * iSy;
          if (cx < ix + iW && cx + shCell > ix && cy < iy + iH && cy + shCell > iy) {
            sh[k] = 0;
            break;
          }
        }
      }
    }
  }

  void _shoot(int dt) {
    shootAcc += dt;
    final cooldown = max(380.0, 1300.0 - level * 90 - (40 - aliveCount) * 10);
    final cap = min(5, 2 + level ~/ 2);
    if (shootAcc < cooldown || eBullets.length >= cap) return;
    shootAcc = _rng.nextInt(250).toDouble();
    final cols = <int>[];
    for (var c = 0; c < iCols; c++) {
      for (var r = 0; r < iRows; r++) {
        if (alive[r * iCols + c]) {
          cols.add(c);
          break;
        }
      }
    }
    if (cols.isEmpty) return;
    var col = cols[_rng.nextInt(cols.length)];
    if (_rng.nextInt(100) < 40) {
      var bd = 1e9;
      for (final c in cols) {
        final d = (gx + c * iSx + iW / 2 - shipX).abs();
        if (d < bd) {
          bd = d;
          col = c;
        }
      }
    }
    var row = -1;
    for (var r = iRows - 1; r >= 0; r--) {
      if (alive[r * iCols + col]) {
        row = r;
        break;
      }
    }
    eBullets.add(Bullet(gx + col * iSx + iW / 2, gy + row * iSy + iH, 150.0 + min(level, 8) * 12));
  }

  void _ufo(int dt, double s) {
    if (ufoDir == 0) {
      ufoMs -= dt;
      if (ufoMs <= 0 && aliveCount > 6) {
        ufoDir = _rng.nextBool() ? 1 : -1;
        ufoX = ufoDir > 0 ? -20 : fw + 20;
      }
    } else {
      ufoX += ufoDir * 85 * s;
      if (ufoX < -30 || ufoX > fw + 30) {
        ufoDir = 0;
        ufoMs = 14000 + _rng.nextInt(10000);
      }
    }
  }

  // ---------------- collisions ----------------
  void _boom(double x, double y, int color, {int life = 450, String? text}) {
    fx.add(Fx(x, y, color, life: life, text: text));
  }

  bool _shieldHit(double x, double y) {
    for (var i = 0; i < 4; i++) {
      final x0 = shieldX(i);
      if (x < x0 || x >= x0 + 48 || y < shY || y >= shY + 24) continue;
      final col = ((x - x0) / shCell).floor(), row = ((y - shY) / shCell).floor();
      final k = row * 8 + col;
      if (shields[i][k] > 0) {
        shields[i][k]--;
        _boom(x, y, 0xFF39FF14, life: 250);
        return true;
      }
    }
    return false;
  }

  void _collide() {
    for (final b in pBullets.toList()) {
      var hit = false;
      for (var i = 0; i < alive.length && !hit; i++) {
        if (!alive[i]) continue;
        final c = i % iCols, r = i ~/ iCols;
        final x = gx + c * iSx, y = gy + r * iSy;
        if (b.x >= x - 2 && b.x <= x + iW + 2 && b.y >= y - 2 && b.y <= y + iH + 2) {
          alive[i] = false;
          kills++;
          score += pts(r);
          _boom(x + iW / 2, y + iH / 2, colorOf(r));
          _ev('clear');
          hit = true;
        }
      }
      if (!hit && ufoDir != 0 && b.x >= ufoX - 17 && b.x <= ufoX + 17 && b.y >= 24 && b.y <= 46) {
        const vals = [50, 100, 150, 300];
        final v = vals[_rng.nextInt(4)];
        score += v;
        _boom(ufoX, 36, 0xFFFF4FD8, life: 900, text: '$v');
        ufoDir = 0;
        ufoMs = 14000 + _rng.nextInt(10000);
        _ev('tetris');
        hit = true;
      }
      if (!hit && _shieldHit(b.x, b.y)) hit = true;
      if (hit) pBullets.remove(b);
    }
    for (final b in eBullets.toList()) {
      if (invuln <= 0 && (b.x - shipX).abs() <= 18 && b.y >= shipY - 12 && b.y <= shipY + 8) {
        _hitShip();
        return;
      }
      if (_shieldHit(b.x, b.y + 5)) eBullets.remove(b);
    }
  }

  void _hitShip() {
    shipDead = 0;
    _boom(shipX, shipY, 0xFFFFE600, life: 1000);
    _boom(shipX, shipY, 0xFFFF2040, life: 700);
    eBullets.clear();
    pBullets.clear();
    _ev('hard');
  }
}
