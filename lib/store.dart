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

  static bool get hasSave => _p.containsKey('save');

  static Future<void> save(Map<String, dynamic> j) async {
    await _p.setString('save', jsonEncode(j));
  }

  static Map<String, dynamic>? load() {
    final s = _p.getString('save');
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSave() async {
    await _p.remove('save');
  }

  // Score record keys: s=score v=level n=lines d=date(ms) t=duration(ms)
  static List<Map<String, dynamic>> scores() {
    final l = List<String>.from(_p.getStringList('scores') ?? <String>[]);
    return [for (final s in l) jsonDecode(s) as Map<String, dynamic>];
  }

  static Future<void> addScore(Map<String, dynamic> m) async {
    final l = List<String>.from(_p.getStringList('scores') ?? <String>[]);
    l.add(jsonEncode(m));
    await _p.setStringList('scores', l);
  }
}
