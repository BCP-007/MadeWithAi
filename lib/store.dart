import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Store {
  static late SharedPreferences _p;
  static final sound = ValueNotifier<bool>(true);
  static final dark = ValueNotifier<bool>(true);

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    sound.value = _p.getBool('sound') ?? true;
    dark.value = _p.getBool('dark') ?? true;
    sound.addListener(() => _p.setBool('sound', sound.value));
    dark.addListener(() => _p.setBool('dark', dark.value));
  }

  // Tetris keeps its original keys ('save', 'scores') so old data survives.
  // Other games use 'save_<id>' and 'scores_<id>'.
  static String _k(String base, String g) => g == 'tetris' ? base : '${base}_$g';

  static String get lastGame => _p.getString('game') ?? 'tetris';
  static Future<void> setLastGame(String g) => _p.setString('game', g);

  static bool hasSave([String g = 'tetris']) => _p.containsKey(_k('save', g));

  static Future<void> save(Map<String, dynamic> j, [String g = 'tetris']) async {
    await _p.setString(_k('save', g), jsonEncode(j));
  }

  static Map<String, dynamic>? load([String g = 'tetris']) {
    final s = _p.getString(_k('save', g));
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSave([String g = 'tetris']) async {
    await _p.remove(_k('save', g));
  }

  // Score record keys: s=score v=level n=count d=date(ms) t=duration(ms)
  static List<Map<String, dynamic>> scores([String g = 'tetris']) {
    final l = List<String>.from(_p.getStringList(_k('scores', g)) ?? <String>[]);
    return [for (final s in l) jsonDecode(s) as Map<String, dynamic>];
  }

  static Future<void> addScore(Map<String, dynamic> m, [String g = 'tetris']) async {
    final l = List<String>.from(_p.getStringList(_k('scores', g)) ?? <String>[]);
    l.add(jsonEncode(m));
    await _p.setStringList(_k('scores', g), l);
  }
}
