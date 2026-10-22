import 'dart:math';

const int cols = 10, rows = 20;

// Piece index: 0=I 1=O 2=T 3=S 4=Z 5=J 6=L. Cells are x,y pairs in spawn orientation.
const List<List<int>> _base = [
  [0, 1, 1, 1, 2, 1, 3, 1],
  [0, 0, 1, 0, 0, 1, 1, 1],
  [1, 0, 0, 1, 1, 1, 2, 1],
  [1, 0, 2, 0, 0, 1, 1, 1],
  [0, 0, 1, 0, 1, 1, 2, 1],
  [0, 0, 0, 1, 1, 1, 2, 1],
  [2, 0, 0, 1, 1, 1, 2, 1],
];
const List<int> _box = [4, 2, 3, 3, 3, 3, 3];

// SRS wall kicks (clockwise only). Pairs are (dx, dy) with y pointing up.
const Map<String, List<int>> _jk = {
  '01': [0, 0, -1, 0, -1, 1, 0, -2, -1, -2],
  '12': [0, 0, 1, 0, 1, -1, 0, 2, 1, 2],
  '23': [0, 0, 1, 0, 1, 1, 0, -2, 1, -2],
  '30': [0, 0, -1, 0, -1, -1, 0, 2, -1, 2],
};
const Map<String, List<int>> _ik = {
  '01': [0, 0, -2, 0, 1, 0, -2, -1, 1, 2],
  '12': [0, 0, -1, 0, 2, 0, -1, 2, 2, -1],
  '23': [0, 0, 2, 0, -1, 0, 2, 1, -1, -2],
  '30': [0, 0, 1, 0, -2, 0, 1, -2, -2, 1],
};

List<List<int>> cellsOf(int t, int r) {
  var c = <List<int>>[
    for (var i = 0; i < 8; i += 2) [_base[t][i], _base[t][i + 1]]
  ];
  if (t == 1) return c;
  final n = _box[t];
  for (var k = 0; k < r; k++) {
    c = [
      for (final p in c) [n - 1 - p[1], p[0]]
    ];
  }
  return c;
}

class Game {
  final List<int> board;
  List<int> queue;
  int type = 0, rot = 0, px = 0, py = 0;
  int hold = -1;
  bool canHold = true;
  int score = 0, level = 1, lines = 0, elapsedMs = 0, locks = 0;
  bool over = false;
  double acc = 0;
  List<int> flashRows = [];
  int flashAt = -100000;
  void Function(String)? onEvent;
  final Random _rng = Random();

  Game()
      : board = List<int>.filled(cols * rows, 0),
        queue = [] {
    _fill();
    _spawn();
  }

  Game._(this.board, this.queue);

  factory Game.fromJson(Map<String, dynamic> j) {
    final g = Game._(List<int>.from(j['b'] as List), List<int>.from(j['q'] as List));
    if (g.board.length != cols * rows) throw const FormatException('bad board');
    g.type = j['t'] as int;
    g.rot = j['r'] as int;
    g.px = j['x'] as int;
    g.py = j['y'] as int;
    g.hold = j['h'] as int;
    g.canHold = j['c'] as bool;
    g.score = j['s'] as int;
    g.level = j['l'] as int;
    g.lines = j['n'] as int;
    g.elapsedMs = j['e'] as int;
    g._fill();
    return g;
  }

  Map<String, dynamic> toJson() => {
        'b': board,
        'q': queue,
        't': type,
        'r': rot,
        'x': px,
        'y': py,
        'h': hold,
        'c': canHold,
        's': score,
        'l': level,
        'n': lines,
        'e': elapsedMs,
      };

  List<List<int>> get cells => cellsOf(type, rot);
  double get interval => max(70.0, 800 * pow(0.82, level - 1).toDouble());

  void _ev(String e) => onEvent?.call(e);

  void _fill() {
    while (queue.length < 7) {
      queue.addAll(([0, 1, 2, 3, 4, 5, 6])..shuffle(_rng));
    }
  }

  void _spawn() {
    _place(queue.removeAt(0));
    _fill();
  }

  void _place(int t) {
    type = t;
    rot = 0;
    px = t == 1 ? 4 : 3;
    py = 0;
    canHold = true;
    if (!valid(type, rot, px, py)) {
      over = true;
      _ev('over');
    }
  }

  bool valid(int t, int r, int x, int y) {
    for (final c in cellsOf(t, r)) {
      final cx = x + c[0], cy = y + c[1];
      if (cx < 0 || cx >= cols || cy >= rows) return false;
      if (cy >= 0 && board[cy * cols + cx] != 0) return false;
    }
    return true;
  }

  bool move(int dx) {
    if (over || !valid(type, rot, px + dx, py)) return false;
    px += dx;
    _ev('move');
    return true;
  }

  bool rotate() {
    if (over || type == 1) return false;
    final to = (rot + 1) % 4;
    final k = (type == 0 ? _ik : _jk)['$rot$to']!;
    for (var i = 0; i < 10; i += 2) {
      final nx = px + k[i], ny = py - k[i + 1];
      if (valid(type, to, nx, ny)) {
        px = nx;
        py = ny;
        rot = to;
        _ev('rotate');
        return true;
      }
    }
    return false;
  }

  bool softDrop() {
    if (over || !valid(type, rot, px, py + 1)) return false;
    py++;
    score += 1;
    return true;
  }

  void hardDrop() {
    if (over) return;
    var n = 0;
    while (valid(type, rot, px, py + 1)) {
      py++;
      n++;
    }
    score += 2 * n;
    _ev('hard');
    _lock();
  }

  void holdPiece() {
    if (over || !canHold) return;
    final cur = type;
    if (hold < 0) {
      hold = cur;
      _spawn();
    } else {
      final h = hold;
      hold = cur;
      _place(h);
    }
    canHold = false;
    _ev('hold');
  }

  int ghostY() {
    var y = py;
    while (valid(type, rot, px, y + 1)) {
      y++;
    }
    return y;
  }

  void _gravity() {
    if (valid(type, rot, px, py + 1)) {
      py++;
    } else {
      _lock();
    }
  }

  void update(int dt) {
    if (over) return;
    elapsedMs += dt;
    acc += dt;
    final iv = interval;
    var n = 0;
    while (acc >= iv && !over && n < 5) {
      acc -= iv;
      n++;
      _gravity();
    }
    if (acc > iv) acc = iv;
  }

  void _lock() {
    for (final c in cells) {
      final x = px + c[0], y = py + c[1];
      if (y >= 0) board[y * cols + x] = type + 1;
    }
    locks++;
    final full = <int>[];
    for (var y = 0; y < rows; y++) {
      var f = true;
      for (var x = 0; x < cols; x++) {
        if (board[y * cols + x] == 0) {
          f = false;
          break;
        }
      }
      if (f) full.add(y);
    }
    final n = full.length;
    if (n > 0) {
      final kept = <int>[];
      for (var y = 0; y < rows; y++) {
        if (!full.contains(y)) kept.addAll(board.sublist(y * cols, (y + 1) * cols));
      }
      board.setAll(0, [...List<int>.filled(n * cols, 0), ...kept]);
      flashRows = full;
      flashAt = elapsedMs;
      const pts = [0, 100, 300, 500, 800];
      score += pts[n] * level;
      lines += n;
      final lv = lines ~/ 10 + 1;
      _ev(n == 4 ? 'tetris' : 'clear');
      if (lv > level) {
        level = lv;
        _ev('level');
      }
    } else {
      _ev('land');
    }
    _spawn();
  }
}
