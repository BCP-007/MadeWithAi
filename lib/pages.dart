import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart';
import 'invaders_page.dart' show InvadersPage;
import 'pacman_page.dart' show PacmanPage;
import 'sound.dart';
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

Widget _aboutRow(String k, String v, Pal p) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(k, style: TextStyle(color: p.sub))),
        Expanded(child: Text(v, style: TextStyle(color: p.text))),
      ]),
    );

class _G {
  final String name, id, tag, unit;
  final Color color;
  final IconData icon;
  const _G(this.name, this.id, this.color, this.tag, this.unit, this.icon);
}

const _games = [
  _G('TETRIS', 'tetris', Color(0xFF00F0FF), 'BLOCK STACKER', 'lines',
      Icons.grid_view_rounded),
  _G('PAC-MAN', 'pacman', Color(0xFFFFE600), 'MAZE CHASER', 'dots',
      Icons.pie_chart),
  _G('INVADERS', 'invaders', Color(0xFF39FF14), 'SPACE DEFENDER', 'kills',
      Icons.rocket_launch),
];

Widget _credit(String t, Pal p) => Text(t,
    style: TextStyle(
        color: pieceColors[0],
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 6,
        shadows: [
          Shadow(
              color: pieceColors[0].withAlpha(p.dark ? 200 : 90),
              blurRadius: 10)
        ]));

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _play(bool resume) => _go(GamePage(resume: resume));

  Future<void> _start() async {
    if (!Store.hasSave) {
      await _play(false);
      return;
    }
    final r = await showNeonDialog<int>(
      context,
      title: 'UNFINISHED GAME',
      message: 'Resume your saved match, or discard it and start a new one?',
      buttons: (c) => [
        NeonButton('RESUME', const Color(0xFF39FF14), () => Navigator.pop(c, 1),
            width: double.infinity),
        NeonButton(
            'DISCARD & NEW', const Color(0xFFFF2040), () => Navigator.pop(c, 2),
            width: double.infinity),
        NeonButton('CANCEL', const Color(0xFF00F0FF), () => Navigator.pop(c, 0),
            width: double.infinity),
      ],
    );
    if (r == 1) {
      await _play(true);
    } else if (r == 2) {
      await Store.clearSave();
      if (mounted) await _play(false);
    }
  }

  Widget _tabs(Pal p) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
        child: Row(children: [
          for (var i = 0; i < _games.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (tab == i) return;
                  Snd.play('click');
                  setState(() => tab = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tab == i
                        ? _games[i].color.withAlpha(60)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: tab == i
                            ? _games[i].color
                            : _games[i].color.withAlpha(90),
                        width: tab == i ? 2 : 1),
                    boxShadow: tab == i
                        ? [
                            BoxShadow(
                                color: _games[i]
                                    .color
                                    .withAlpha(p.dark ? 120 : 70),
                                blurRadius: 14)
                          ]
                        : [],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_games[i].icon,
                          size: 18,
                          color: tab == i
                              ? _games[i].color
                              : _games[i].color.withAlpha(150)),
                      const SizedBox(width: 5),
                      Text(_games[i].name,
                          style: TextStyle(
                              color: tab == i ? p.text : p.sub,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );

  List<Widget> _buttons(_G g) => [
        if (tab == 0 && Store.hasSave) ...[
          NeonButton(
              'CONTINUE GAME', const Color(0xFF39FF14), () => _play(true)),
          const SizedBox(height: 16),
        ],
        NeonButton('START GAME', g.color, () {
          if (tab == 0) {
            _start();
          } else {
            _go(tab == 1 ? const PacmanPage() : const InvadersPage());
          }
        }),
        const SizedBox(height: 16),
        NeonButton('SCORES', const Color(0xFFB400FF),
            () => _go(ScoresPage(game: tab))),
        const SizedBox(height: 16),
        NeonButton('SETTINGS', const Color(0xFFFF8A00),
            () => _go(const SettingsPage())),
      ];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = _games[tab];
    final best = Store.best(g.id);
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: NeonTitle(text: 'CLASSIC GAMES', size: 58),
            ),
            _tabs(p),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                        key: ValueKey(tab),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NeonTitle(text: g.name),
                          const SizedBox(height: 6),
                          Text(g.tag,
                              style: TextStyle(
                                  color: p.sub,
                                  letterSpacing: 6,
                                  fontSize: 12)),
                          const SizedBox(height: 12),
                          Text(best > 0 ? 'BEST  $best' : 'NO SCORE YET',
                              style: TextStyle(
                                  color: best > 0 ? g.color : p.sub,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3,
                                  fontSize: 13)),
                          const SizedBox(height: 32),
                          ..._buttons(g),
                          const SizedBox(height: 40),
                          _credit('Made With AI', p),
                          _credit('BY BCP', p),
                        ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class ScoresPage extends StatefulWidget {
  final int game;
  const ScoresPage({super.key, this.game = 0});
  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> {
  bool byScore = true;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = _games[widget.game];
    final list = Store.scores(g.id);
    if (byScore) {
      list.sort((a, b) => (b['s'] as int).compareTo(a['s'] as int));
    } else {
      list.sort((a, b) => (b['d'] as int).compareTo(a['d'] as int));
    }
    final best = list.isEmpty ? 0 : list.map((e) => e['s'] as int).reduce(max);
    return Scaffold(
      appBar: AppBar(title: Text('${g.name} SCORES'), centerTitle: true),
      body: Backdrop(
        animate: false,
        child: list.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.sports_esports, size: 72, color: p.sub),
                  const SizedBox(height: 12),
                  Text('No matches yet',
                      style: TextStyle(
                          color: p.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Finish a game and it will appear here.',
                      style: TextStyle(color: p.sub)),
                ]),
              )
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(children: [
                    Expanded(
                        child: Text('${list.length} completed matches',
                            style: TextStyle(
                                color: p.text, fontWeight: FontWeight.bold))),
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
                              color: top ? Colors.amber : g.color.withAlpha(90),
                              width: top ? 2 : 1),
                          boxShadow: top
                              ? [
                                  BoxShadow(
                                      color: Colors.amber.withAlpha(90),
                                      blurRadius: 14)
                                ]
                              : [],
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${e['s']}',
                                      style: TextStyle(
                                          color: p.text,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900)),
                                  Text(
                                      'Level ${e['v']}  •  ${e['n']} ${g.unit}  •  ${_dur(e['t'] as int)}',
                                      style: TextStyle(color: p.text)),
                                  Text(_date(e['d'] as int),
                                      style: TextStyle(
                                          color: p.sub, fontSize: 12)),
                                ]),
                          ),
                          if (top)
                            const Icon(Icons.emoji_events,
                                color: Colors.amber, size: 32),
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
                  secondary: Icon(v ? Icons.volume_up : Icons.volume_off,
                      color: p.accent),
                  value: v,
                  onChanged: (x) => Store.sound.value = x,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Store.dark,
                builder: (_, v, __) => SwitchListTile(
                  title: Text('Dark theme', style: TextStyle(color: p.text)),
                  secondary: Icon(v ? Icons.dark_mode : Icons.light_mode,
                      color: p.accent),
                  value: v,
                  onChanged: (x) => Store.dark.value = x,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.panel.withAlpha(210),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.accent.withAlpha(80)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ABOUT',
                  style: TextStyle(
                      color: p.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3)),
              const SizedBox(height: 10),
              _aboutRow('App', 'Classic Arcade v1.2.0', p),
              _aboutRow('Games', 'Tetris, Pac-Man, Invaders', p),
              _aboutRow('Made by', 'BCP', p),
              _aboutRow('Built with', 'Flutter & Dart', p),
              _aboutRow('AI model', 'Claude Sonnet 5.5 (Anthropic)', p),
            ]),
          ),
        ]),
      ),
    );
  }
}
