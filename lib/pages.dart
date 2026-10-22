import 'dart:math';
import 'package:flutter/material.dart';
import 'package:neon_tetris/sound.dart';
import 'arcade_page.dart';
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

Widget _aboutRow(String key, String value, Pal p) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(key, style: TextStyle(color: p.sub))),
        Expanded(child: Text(value, style: TextStyle(color: p.text))),
      ]),
    );

class _ArcadeGame {
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ArcadeGame(this.key, this.label, this.subtitle, this.icon, this.color);
}

const _games = [
  _ArcadeGame('TETRIS', 'TETRIS', 'STACK THE FUTURE', Icons.grid_4x4, Color(0xFF00F0FF)),
  _ArcadeGame('SPACE INVADERS', 'INVADERS', 'DEFEND THE GALAXY', Icons.rocket_launch, Color(0xFF39FF14)),
  _ArcadeGame('PAC-MAN', 'PAC-MAN', 'EAT. RUN. REPEAT.', Icons.mood, Color(0xFFFFE600)),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selected = 0;

  _ArcadeGame get _game => _games[_selected];

  Future<void> _playTetris(bool resume) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(resume: resume)));
    if (mounted) setState(() {});
  }

  Future<void> _startTetris() async {
    if (!Store.hasSave) {
      await _playTetris(false);
      return;
    }
    final result = await showNeonDialog<int>(
      context,
      title: 'UNFINISHED GAME',
      message: 'Resume your saved match, or discard it and start a new one?',
      buttons: (dialogContext) => [
        NeonButton('RESUME', const Color(0xFF39FF14), () => Navigator.pop(dialogContext, 1), width: double.infinity),
        NeonButton('DISCARD & NEW', const Color(0xFFFF2040), () => Navigator.pop(dialogContext, 2), width: double.infinity),
        NeonButton('CANCEL', const Color(0xFF00F0FF), () => Navigator.pop(dialogContext, 0), width: double.infinity),
      ],
    );
    if (result == 1) {
      await _playTetris(true);
    } else if (result == 2) {
      await Store.clearSave();
      if (mounted) await _playTetris(false);
    }
  }

  void _playArcade() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArcadePage(kind: _selected == 1 ? ArcadeKind.invaders : ArcadeKind.pacman)),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openScores() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ScoresPage(game: _game.key)));
  }

  Widget _gameTab(_ArcadeGame game, int index, Pal p) {
    final active = index == _selected;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Snd.play('click');
          setState(() => _selected = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active ? game.color.withAlpha(p.dark ? 55 : 35) : p.panel.withAlpha(150),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? game.color : p.accent.withAlpha(45), width: active ? 2 : 1),
            boxShadow: active ? [BoxShadow(color: game.color.withAlpha(80), blurRadius: 12)] : [],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(game.icon, color: active ? game.color : p.sub, size: 18),
            const SizedBox(height: 2),
            Text(game.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: active ? p.text : p.sub, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ]),
        ),
      ),
    );
  }

  Widget _selectedPanel(Pal p) {
    final records = Store.scores(_game.key);
    final best = records.isEmpty ? 0 : records.map((e) => (e['s'] as num?)?.toInt() ?? 0).reduce(max);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.panel.withAlpha(220),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _game.color.withAlpha(150), width: 1.5),
        boxShadow: [BoxShadow(color: _game.color.withAlpha(45), blurRadius: 20)],
      ),
      child: Column(children: [
        Icon(_game.icon, color: _game.color, size: 42),
        const SizedBox(height: 6),
        Text(_game.label, style: TextStyle(color: p.text, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3)),
        Text(_game.subtitle, style: TextStyle(color: p.sub, fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 12),
        Text(best == 0 ? 'NO HIGH SCORE YET' : 'BEST SCORE  $best',
            style: TextStyle(color: _game.color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 18),
        if (_selected == 0 && Store.hasSave) ...[
          NeonButton('CONTINUE GAME', const Color(0xFF39FF14), () => _playTetris(true), width: double.infinity),
          const SizedBox(height: 12),
        ],
        NeonButton(_selected == 0 ? 'START GAME' : 'PLAY NOW', _game.color,
            _selected == 0 ? _startTetris : _playArcade, width: double.infinity),
        const SizedBox(height: 12),
        NeonButton('VIEW SCORES', const Color(0xFFB400FF), _openScores, width: double.infinity),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(children: [
                const NeonTitle(),
                const SizedBox(height: 4),
                Text('NEON ARCADE', style: TextStyle(color: p.sub, letterSpacing: 6, fontSize: 12)),
                const SizedBox(height: 30),
                Row(children: [for (var i = 0; i < _games.length; i++) _gameTab(_games[i], i, p)]),
                const SizedBox(height: 18),
                AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: _selectedPanel(p)),
                const SizedBox(height: 28),
                NeonButton('SETTINGS', const Color(0xFFFF8A00), () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                }),
                const SizedBox(height: 30),
                Text('MADE WITH AI', style: TextStyle(color: pieceColors[0], fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 4,
                    shadows: [Shadow(color: pieceColors[0].withAlpha(p.dark ? 200 : 90), blurRadius: 10)])),
                Text('BY BCP', style: TextStyle(color: pieceColors[0], fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 4,
                    shadows: [Shadow(color: pieceColors[0].withAlpha(p.dark ? 200 : 90), blurRadius: 10)])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class ScoresPage extends StatefulWidget {
  final String game;
  const ScoresPage({super.key, required this.game});

  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> {
  bool byScore = true;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final list = Store.scores(widget.game);
    list.sort((a, b) => byScore
        ? ((b['s'] as num?)?.toInt() ?? 0).compareTo((a['s'] as num?)?.toInt() ?? 0)
        : ((b['d'] as num?)?.toInt() ?? 0).compareTo((a['d'] as num?)?.toInt() ?? 0));
    final best = list.isEmpty ? 0 : list.map((e) => (e['s'] as num?)?.toInt() ?? 0).reduce(max);
    final arcade = widget.game != 'TETRIS';
    return Scaffold(
      appBar: AppBar(title: Text('${widget.game} SCORES'), centerTitle: true),
      body: Backdrop(
        animate: false,
        child: list.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.emoji_events_outlined, size: 72, color: p.sub),
                const SizedBox(height: 12),
                Text('No matches yet', style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Play a round and your score will appear here.', style: TextStyle(color: p.sub)),
              ]))
            : Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
                  Expanded(child: Text('${list.length} completed matches', style: TextStyle(color: p.text, fontWeight: FontWeight.bold))),
                  ChoiceChip(label: const Text('Highest'), selected: byScore, onSelected: (_) => setState(() => byScore = true)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('Recent'), selected: !byScore, onSelected: (_) => setState(() => byScore = false)),
                ])),
                Expanded(child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final score = (list[i]['s'] as num?)?.toInt() ?? 0;
                    final level = (list[i]['v'] as num?)?.toInt() ?? 1;
                    final count = (list[i]['n'] as num?)?.toInt() ?? 0;
                    final date = (list[i]['d'] as num?)?.toInt() ?? 0;
                    final duration = (list[i]['t'] as num?)?.toInt() ?? 0;
                    final top = best > 0 && score == best;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: p.panel.withAlpha(210), borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: top ? Colors.amber : p.accent.withAlpha(60), width: top ? 2 : 1),
                          boxShadow: top ? [BoxShadow(color: Colors.amber.withAlpha(90), blurRadius: 14)] : []),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$score', style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w900)),
                          Text(arcade ? 'Level $level  •  Waves $count  •  ${_dur(duration)}' : 'Level $level  •  $count lines  •  ${_dur(duration)}', style: TextStyle(color: p.text)),
                          Text(_date(date), style: TextStyle(color: p.sub, fontSize: 12)),
                        ])),
                        if (top) const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                      ]),
                    );
                  },
                )),
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
      body: Backdrop(animate: false, child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(decoration: BoxDecoration(color: p.panel.withAlpha(210), borderRadius: BorderRadius.circular(16), border: Border.all(color: p.accent.withAlpha(80))),
          child: Column(children: [
            ValueListenableBuilder<bool>(valueListenable: Store.sound, builder: (_, value, __) => SwitchListTile(
              title: Text('Sound effects', style: TextStyle(color: p.text)), secondary: Icon(value ? Icons.volume_up : Icons.volume_off, color: p.accent),
              value: value, onChanged: (next) => Store.sound.value = next,
            )),
            ValueListenableBuilder<bool>(valueListenable: Store.dark, builder: (_, value, __) => SwitchListTile(
              title: Text('Dark theme', style: TextStyle(color: p.text)), secondary: Icon(value ? Icons.dark_mode : Icons.light_mode, color: p.accent),
              value: value, onChanged: (next) => Store.dark.value = next,
            )),
          ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: p.panel.withAlpha(210), borderRadius: BorderRadius.circular(16), border: Border.all(color: p.accent.withAlpha(80))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ABOUT', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, letterSpacing: 3)),
            const SizedBox(height: 10),
            _aboutRow('App', 'Neon Arcade v1.0.0', p),
            _aboutRow('Made by', 'BCP', p),
            _aboutRow('Built with', 'Flutter & Dart', p),
          ])),
      ]),
    ));
  }
}