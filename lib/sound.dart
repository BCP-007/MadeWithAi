import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'store.dart';

class Snd {
  static const _names = [
    'move',
    'rotate',
    'hold',
    'land',
    'hard',
    'clear',
    'tetris',
    'level',
    'over',
    'click'
  ];
  static final Map<String, AudioPlayer> _ps = {};

  static void init() {
    AudioCache.instance.loadAll(
        [for (final n in _names) 'sounds/$n.wav']).catchError((Object e) {
      debugPrint('SND preload error: $e');
      return <Uri>[];
    });
    for (final n in _names) {
      _ps[n] = AudioPlayer();
    }
    Store.sound.addListener(() {
      if (!Store.sound.value) {
        for (final p in _ps.values) {
          p.stop();
        }
      }
    });
  }

  static Future<void> play(String name) async {
    if (!Store.sound.value) return;
    final p = _ps[name];
    if (p == null) return;
    try {
      await p.stop();
      await p.play(AssetSource('sounds/$name.wav'));
    } catch (e) {
      debugPrint('SND error ($name): $e');
    }
  }
}
