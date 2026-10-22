import 'package:flutter_test/flutter_test.dart';
import 'package:neon_tetris/engine.dart';

void main() {
  test('every piece has 4 cells in every rotation', () {
    for (var t = 0; t < 7; t++) {
      for (var r = 0; r < 4; r++) {
        expect(cellsOf(t, r).length, 4);
      }
    }
  });

  test('walls block movement', () {
    final g = Game();
    for (var i = 0; i < 12; i++) {
      g.move(-1);
    }
    expect(g.move(-1), false);
  });

  test('hard drop locks piece and spawns next', () {
    final g = Game();
    g.hardDrop();
    expect(g.board.any((c) => c != 0), true);
    expect(g.locks, 1);
  });

  test('line clear scores', () {
    final g = Game();
    for (var x = 0; x < cols; x++) {
      if (x < 3 || x > 6) g.board[19 * cols + x] = 1;
    }
    g.type = 0;
    g.rot = 0;
    g.px = 3;
    g.py = 0;
    g.hardDrop();
    expect(g.lines, 1);
    expect(g.score >= 100, true);
  });

  test('save and restore keeps state', () {
    final g = Game();
    g.hardDrop();
    final r = Game.fromJson(g.toJson());
    expect(r.board, g.board);
    expect(r.queue, g.queue);
    expect(r.type, g.type);
    expect(r.score, g.score);
  });
}
