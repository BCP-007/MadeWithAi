import 'dart:math';
import 'shell.dart';

const int pCols = 19, pRows = 21;

// # wall  . dot  o power pellet  - ghost door  (space) empty  P pac start  G ghost house
const List<String> _layout = [
  '###################',
  '#........#........#',
  '#o##.###.#.###.##o#',
  '#.................#',
  '#.##.#.#####.#.##.#',
  '#....#...#...#....#',
  '####.###.#.###.####',
  '####.#.......#.####',
  '####.# ##-## #.####',
  '    .  #GGG#  .    ',
  '####.# ##### #.####',
  '####.#.......#.####',
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

// tile codes: 0 wall, 1 empty, 2 dot, 3 power, 4 door
List<int> _parse() => [
      for (final row in _layout)
        for (var i = 0; i < pCols; i++)
          switch (row[i]) {
            '#' => 0,
            '.' => 2,
            'o' => 3,
            '-' => 4,
            _ => 1,
          }
    ];

final List<int> pBase = _parse();

/// Tile lookup with horizontal tunnel wrap.
int pTile(int c, int r) {
  if (r < 0 || r >= pRows) return 0;
  return pBase[r * pCols + (c % pCols)];
}

/// Wall test without wrap (used for drawing).
bool pWall(int c, int r) => c < 0 || c >= pCols || r < 0 || r >= pRows || pBase[r * pCols + c] == 0;

const List<List<int>> _dirs = [
  [0, -1],
  [-1, 0],
  [0, 1],
  [1, 0],
];

List<int> _bfs(int sc, int sr) {
  const inf = 1 << 20;
  final d = List<int>.filled(pCols * pRows, inf);
  final q = <int>[sr * pCols + sc];
  d[q.first] = 0;
  for (var i = 0; i < q.length; i++) {
    final cur = q[i];
    final c = cur % pCols, r = cur ~/ pCols;
    for (final dir in _dirs) {
      final nc = (c + dir[0]) % pCols, nr = r + dir[1];
      if (nr < 0 || nr >= pRows) continue;
      final ni = nr * pCols + nc;
      if (pBase[ni] == 0 || d[ni] < inf) continue;
      d[ni] = d[cur] + 1;
      q.add(ni);
    }
  }
  return d;
}

final List<int> _exitD = _bfs(9, 7); // route out of the ghost house
final List<int> _homeD = _bfs(9, 9); // route back into it

class PGhost {
  final int id; // 0 blinky, 1 pinky, 2 inky, 3 clyde
  int c = 0, r = 0, dx = 0, dy = 0;
  double p = 0;
  int mode = 0; // 0 house, 1 leaving, 2 normal, 3 frightened, 4 eaten
  double release = 0;
  bool rev = false;
  PGhost(this.id);
  double get x => c + dx * p;
  double get y => r + dy * p;
}

class PacGame extends ArcadeGame {
  List<int> cells = List<int>.from(pBase);
  int pc = 9, pr = 15, pdx = 0, pdy = 0, ndx = 0, ndy = 0, fdx = -1, fdy = 0;
  double pp = 0;
  final List<PGhost> ghosts = [for (var i = 0; i < 4; i++) PGhost(i)];

  /// 0 ready, 1 playing, 2 dying, 3 level clear
  int state = 0;
  double stateMs = 0, phaseMs = 0, frightMs = 0, modeMs = 0;
  int modeIdx = 0, combo = 0, dotsLeft = 0, eaten = 0, lastChomp = 0;
  bool bonus = false;
  bool over = false;
  int score = 0, level = 1, lives = 3, elapsedMs = 0;
  final Random _rng = Random();

  static const List<int> _sched = [7000, 20000, 7000, 20000, 5000, 20000, 5000, 0];

  PacGame() {
    _recount();
    _reset();
  }

  factory PacGame.fromJson(Map<String, dynamic> j) {
    final g = PacGame();
    final c = List<int>.from(j['c'] as List);
    if (c.length != pCols * pRows) throw const FormatException('bad maze');
    g.cells = c;
    g.score = j['s'] as int;
    g.level = j['l'] as int;
    g.lives = j['v'] as int;
    g.elapsedMs = j['e'] as int;
    g.eaten = j['n'] as int;
    g.bonus = j['b'] as bool;
    g._recount();
    g._reset();
    return g;
  }

  @override
  Map<String, dynamic> toJson() => {
        'c': cells,
        's': score,
        'l': level,
        'v': lives,
        'e': elapsedMs,
        'n': eaten,
        'b': bonus,
      };

  @override
  Map<String, dynamic> record() => {
        's': score,
        'v': level,
        'n': eaten,
        'd': DateTime.now().millisecondsSinceEpoch,
        't': elapsedMs,
      };

  double get pacX => pc + pdx * pp;
  double get pacY => pr + pdy * pp;
  bool get chasing => modeIdx.isOdd;
  bool get moving => pdx != 0 || pdy != 0;

  void _ev(String e) => onEvent?.call(e);

  void _recount() {
    dotsLeft = cells.where((t) => t == 2 || t == 3).length;
  }

  void _reset() {
    pc = 9;
    pr = 15;
    pdx = pdy = ndx = ndy = 0;
    fdx = -1;
    fdy = 0;
    pp = 0;
    phaseMs = 0;
    frightMs = 0;
    combo = 0;
    const starts = [
      [9, 7],
      [9, 9],
      [8, 9],
      [10, 9],
    ];
    const rel = [0, 1800, 4500, 8000];
    final k = max(0.4, 1 - 0.12 * (level - 1));
    for (var i = 0; i < 4; i++) {
      final g = ghosts[i];
      g.c = starts[i][0];
      g.r = starts[i][1];
      g.dx = g.dy = 0;
      g.p = 0;
      g.rev = false;
      g.release = rel[i] * k;
      g.mode = i == 0 ? 2 : 0;
    }
    ghosts[0].dx = -1;
    state = 0;
    stateMs = 0;
  }

  // ---------------- input ----------------
  void setDir(int dx, int dy) {
    if (over) return;
    if (pp > 0 && pdx == -dx && pdy == -dy && (dx != 0 || dy != 0)) {
      pc += pdx;
      pr += pdy;
      pdx = dx;
      pdy = dy;
      pp = 1 - pp;
      fdx = dx;
      fdy = dy;
    }
    ndx = dx;
    ndy = dy;
  }

  // ---------------- update ----------------
  @override
  void update(int dt) {
    if (over) return;
    elapsedMs += dt;
    stateMs += dt;
    switch (state) {
      case 0:
        if (stateMs >= 1800) {
          state = 1;
          stateMs = 0;
        }
        break;
      case 1:
        _play(dt);
        break;
      case 2:
        if (stateMs >= 1500) _afterDeath();
        break;
      case 3:
        if (stateMs >= 1800) _nextLevel();
        break;
    }
  }

  void _afterDeath() {
    lives--;
    if (lives <= 0) {
      over = true;
      _ev('over');
    } else {
      _reset();
    }
  }

  void _nextLevel() {
    level++;
    cells = List<int>.from(pBase);
    _recount();
    modeIdx = 0;
    modeMs = 0;
    _reset();
  }

  void _play(int dt) {
    final s = dt / 1000.0;
    phaseMs += dt;
    if (frightMs > 0) {
      frightMs -= dt;
      if (frightMs <= 0) {
        frightMs = 0;
        for (final g in ghosts) {
          if (g.mode == 3) g.mode = 2;
        }
      }
    } else if (modeIdx < 7) {
      modeMs += dt;
      if (modeMs >= _sched[modeIdx]) {
        modeMs = 0;
        modeIdx++;
        for (final g in ghosts) {
          if (g.mode == 2) g.rev = true;
        }
      }
    }
    _movePac(7.0 * s);
    for (final g in ghosts) {
      if (g.mode == 0) {
        if (phaseMs >= g.release) g.mode = 1;
        continue;
      }
      _moveGhost(g, _speed(g) * s);
    }
    _collide();
    if (state == 1 && dotsLeft == 0) {
      state = 3;
      stateMs = 0;
      _ev('level');
    }
  }

  double _speed(PGhost g) {
    switch (g.mode) {
      case 1:
        return 4.5;
      case 3:
        return 4.2;
      case 4:
        return 13;
      default:
        return 6.4 + min(level - 1, 6) * 0.25;
    }
  }

  // ---------------- pac movement ----------------
  bool _pacOk(int c, int r) {
    final t = pTile(c, r);
    return t != 0 && t != 4;
  }

  void _movePac(double move) {
    while (move > 1e-9) {
      if (!moving) {
        if ((ndx != 0 || ndy != 0) && _pacOk(pc + ndx, pr + ndy)) {
          pdx = ndx;
          pdy = ndy;
          fdx = pdx;
          fdy = pdy;
        } else {
          return;
        }
      }
      final remain = 1 - pp;
      if (move < remain) {
        pp += move;
        return;
      }
      move -= remain;
      pp = 0;
      pc += pdx;
      pr += pdy;
      if (pc < 0) {
        pc = pCols;
      } else if (pc >= pCols) {
        pc = -1;
      }
      _eat();
      if ((ndx != 0 || ndy != 0) && _pacOk(pc + ndx, pr + ndy)) {
        pdx = ndx;
        pdy = ndy;
        fdx = pdx;
        fdy = pdy;
      } else if (!_pacOk(pc + pdx, pr + pdy)) {
        pdx = pdy = 0;
      }
    }
  }

  void _addScore(int n) {
    score += n;
    if (!bonus && score >= 10000) {
      bonus = true;
      lives++;
      _ev('tetris');
    }
  }

  void _eat() {
    if (pc < 0 || pc >= pCols) return;
    final i = pr * pCols + pc;
    final t = cells[i];
    if (t == 2) {
      cells[i] = 1;
      dotsLeft--;
      eaten++;
      _addScore(10);
      if (elapsedMs - lastChomp > 140) {
        lastChomp = elapsedMs;
        _ev('move');
      }
    } else if (t == 3) {
      cells[i] = 1;
      dotsLeft--;
      eaten++;
      _addScore(50);
      frightMs = max(2500, 7500 - (level - 1) * 900).toDouble();
      combo = 0;
      for (final g in ghosts) {
        if (g.mode == 2 || g.mode == 3) {
          g.mode = 3;
          g.rev = true;
        }
      }
      _ev('hold');
    }
  }

  // ---------------- ghost movement ----------------
  void _moveGhost(PGhost g, double move) {
    while (move > 1e-9) {
      if (g.dx == 0 && g.dy == 0) {
        _choose(g);
        if (g.dx == 0 && g.dy == 0) return;
      }
      final remain = 1 - g.p;
      if (move < remain) {
        g.p += move;
        return;
      }
      move -= remain;
      g.p = 0;
      g.c += g.dx;
      g.r += g.dy;
      if (g.c < 0) {
        g.c = pCols;
      } else if (g.c >= pCols) {
        g.c = -1;
      }
      _arrive(g);
      _choose(g);
    }
  }

  void _arrive(PGhost g) {
    if (g.mode == 1 && g.r == 7 && g.c == 9) {
      g.mode = frightMs > 0 ? 3 : 2;
    } else if (g.mode == 4 && g.r == 9 && g.c == 9) {
      g.mode = 1;
    }
  }

  List<int> _target(PGhost g) {
    const corners = [
      [17, 0],
      [1, 0],
      [17, 20],
      [1, 20],
    ];
    final px = pc % pCols, py = pr;
    if (!chasing) return corners[g.id];
    switch (g.id) {
      case 0:
        return [px, py];
      case 1:
        return [px + 4 * fdx, py + 4 * fdy];
      case 2:
        final bx = px + 2 * fdx, by = py + 2 * fdy;
        final b = ghosts[0];
        return [bx * 2 - b.c, by * 2 - b.r];
      default:
        final dx = g.c - px, dy = g.r - py;
        return dx * dx + dy * dy > 64 ? [px, py] : corners[3];
    }
  }

  void _choose(PGhost g) {
    if (g.mode == 0) {
      g.dx = g.dy = 0;
      return;
    }
    final isMoving = g.dx != 0 || g.dy != 0;
    if (g.rev && (g.mode == 2 || g.mode == 3) && isMoving) {
      g.rev = false;
      g.dx = -g.dx;
      g.dy = -g.dy;
      return;
    }
    g.rev = false;
    final opts = <int>[];
    for (var i = 0; i < 4; i++) {
      final t = pTile(g.c + _dirs[i][0], g.r + _dirs[i][1]);
      if (t == 0) continue;
      if (t == 4 && g.mode != 1 && g.mode != 4) continue;
      opts.add(i);
    }
    if (opts.isEmpty) {
      g.dx = g.dy = 0;
      return;
    }
    var cand = opts;
    if (isMoving && g.mode != 1 && g.mode != 4) {
      final f = opts.where((i) => !(_dirs[i][0] == -g.dx && _dirs[i][1] == -g.dy)).toList();
      if (f.isNotEmpty) cand = f;
    }
    var best = cand.first;
    if (g.mode == 3) {
      best = cand[_rng.nextInt(cand.length)];
    } else if (g.mode == 1 || g.mode == 4) {
      final field = g.mode == 1 ? _exitD : _homeD;
      var bd = 1 << 30;
      for (final i in cand) {
        final nc = (g.c + _dirs[i][0]) % pCols, nr = g.r + _dirs[i][1];
        final d = field[nr * pCols + nc];
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
    } else {
      final t = _target(g);
      var bd = 1 << 30;
      for (final i in cand) {
        final dx = g.c + _dirs[i][0] - t[0], dy = g.r + _dirs[i][1] - t[1];
        final d = dx * dx + dy * dy;
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
    }
    g.dx = _dirs[best][0];
    g.dy = _dirs[best][1];
  }

  // ---------------- collisions ----------------
  void _collide() {
    final px = pacX, py = pacY;
    for (final g in ghosts) {
      if (g.mode == 0 || g.mode == 4) continue;
      var dx = g.x - px;
      if (dx.abs() > pCols / 2) dx -= dx.sign * pCols;
      final dy = g.y - py;
      if (dx * dx + dy * dy < 0.4) {
        if (g.mode == 3) {
          g.mode = 4;
          _addScore(200 << min(combo, 3));
          combo++;
          _ev('clear');
        } else {
          state = 2;
          stateMs = 0;
          _ev('hard');
          return;
        }
      }
    }
  }
}
