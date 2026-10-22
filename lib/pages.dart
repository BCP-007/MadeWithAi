import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart';
import 'store.dart';
import 'theme.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _dur(int ms) {
  final s = ms ~/ 1000;
  return '${_two(s ~/ 60)}:${_two(s % 60)}';
}

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _play(bool resume) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(resume: resume)));
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (!Store.hasSave) {
      await _play(false);
      return;
    }
    final r = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Unfinished game found'),
        content: const Text('Resume your saved match, or discard it and start a new one?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 0), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, 2), child: const Text('Discard & New')),
          FilledButton(onPressed: () => Navigator.pop(c, 1), child: const Text('Resume')),
        ],
      ),
    );
    if (r == 1) {
      await _play(true);
    } else if (r == 2) {
      await Store.clearSave();
      if (mounted) await _play(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const NeonTitle(),
                const SizedBox(height: 6),
                Text('SCI-FI ARCADE', style: TextStyle(color: p.sub, letterSpacing: 6, fontSize: 12)),
                const SizedBox(height: 44),
                if (Store.hasSave) ...[
                  NeonButton('CONTINUE GAME', const Color(0xFF39FF14), () => _play(true)),
                  const SizedBox(height: 16),
                ],
                NeonButton('START GAME', const Color(0xFF00F0FF), _start),
                const SizedBox(height: 16),
                NeonButton('SCORES', const Color(0xFFB400FF), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ScoresPage()));
                }),
                const SizedBox(height: 16),
                NeonButton('SETTINGS', const Color(0xFFFF8A00), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                }),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class ScoresPage extends StatefulWidget {
  const ScoresPage({super.key});
  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> {
  bool byScore = true;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final list = Store.scores();
    if (byScore) {
      list.sort((a, b) => (b['s'] as int).compareTo(a['s'] as int));
    } else {
      list.sort((a, b) => (b['d'] as int).compareTo(a['d'] as int));
    }
    final best = list.isEmpty ? 0 : list.map((e) => e['s'] as int).reduce(max);
    return Scaffold(
      appBar: AppBar(title: const Text('SCORES'), centerTitle: true),
      body: Backdrop(
        animate: false,
        child: list.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.sports_esports, size: 72, color: p.sub),
                  const SizedBox(height: 12),
                  Text('No matches yet', style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Finish a game and it will appear here.', style: TextStyle(color: p.sub)),
                ]),
              )
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(children: [
                    Expanded(
                        child: Text('${list.length} completed matches',
                            style: TextStyle(color: p.text, fontWeight: FontWeight.bold))),
                    ChoiceChip(
                        label: const Text('Highest'),
                        selected: byScore,
                        onSelected: (_) => setState(() => byScore = true)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                        label: const Text('Recent'),
                        selected: !byScore,
                        onSelected: (_) => setState(() => byScore = false)),
                  ]),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final e = list[i];
                      final top = best > 0 && (e['s'] as int) == best;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.panel.withAlpha(210),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: top ? Colors.amber : p.accent.withAlpha(60), width: top ? 2 : 1),
                          boxShadow: top ? [BoxShadow(color: Colors.amber.withAlpha(90), blurRadius: 14)] : [],
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${e['s']}',
                                  style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w900)),
                              Text('Level ${e['v']}  •  ${e['n']} lines  •  ${_dur(e['t'] as int)}',
                                  style: TextStyle(color: p.text)),
                              Text(_date(e['d'] as int), style: TextStyle(color: p.sub, fontSize: 12)),
                            ]),
                          ),
                          if (top) const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                        ]),
                      );
                    },
                  ),
                ),
              ]),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS'), centerTitle: true),
      body: Backdrop(
        animate: false,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            decoration: BoxDecoration(
              color: p.panel.withAlpha(210),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.accent.withAlpha(80)),
            ),
            child: Column(children: [
              ValueListenableBuilder<bool>(
                valueListenable: Store.sound,
                builder: (_, v, __) => SwitchListTile(
                  title: Text('Sound effects', style: TextStyle(color: p.text)),
                  secondary: Icon(v ? Icons.volume_up : Icons.volume_off, color: p.accent),
                  value: v,
                  onChanged: (x) => Store.sound.value = x,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Store.dark,
                builder: (_, v, __) => SwitchListTile(
                  title: Text('Dark theme', style: TextStyle(color: p.text)),
                  secondary: Icon(v ? Icons.dark_mode : Icons.light_mode, color: p.accent),
                  value: v,
                  onChanged: (x) => Store.dark.value = x,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
