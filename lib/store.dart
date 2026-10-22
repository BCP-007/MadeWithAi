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

  // Tetris keeps the original save key so existing unfinished matches continue working.
  static bool get hasSave => _p.containsKey('save');

  static Future<void> save(Map<String, dynamic> json) async {
    await _p.setString('save', jsonEncode(json));
  }

  static Map<String, dynamic>? load() {
    final value = _p.getString('save');
    if (value == null) return null;
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSave() async => _p.remove('save');

  static String _scoresKey(String game) =>
      game == 'TETRIS' ? 'scores' : 'scores_$game';

  static List<Map<String, dynamic>> scores([String game = 'TETRIS']) {
    final values =
        List<String>.from(_p.getStringList(_scoresKey(game)) ?? <String>[]);
    final result = <Map<String, dynamic>>[];
    for (final value in values) {
      try {
        final item = Map<String, dynamic>.from(jsonDecode(value) as Map);
        item['g'] ??= 'TETRIS';
        result.add(item);
      } catch (_) {
        // Ignore one damaged score instead of breaking the leaderboard.
      }
    }
    return result;
  }

  static Future<void> addScore(Map<String, dynamic> score) async {
    final game = (score['g'] as String? ?? 'TETRIS').toUpperCase();
    final values =
        List<String>.from(_p.getStringList(_scoresKey(game)) ?? <String>[]);
    final copy = Map<String, dynamic>.from(score)..['g'] = game;
    values.add(jsonEncode(copy));
    await _p.setStringList(_scoresKey(game), values);
  }
}
