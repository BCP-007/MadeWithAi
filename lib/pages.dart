import 'dart:math';
import 'package:flutter/material.dart';
import 'games.dart';
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

/// Row of game buttons shown at the top of the home page.
class GameTabs extends StatelessWidget {
  final List<GameDef> items;
  final String selected;
  final ValueChanged<GameDef> onSelect;
  const GameTabs({super.key, required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        for (final g in items)
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (g.id != selected) Snd.play('click');
                onSelect(g);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: g.color.withAlpha(g.id == selected ? 70 : 20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: g.color.withAlpha(g.id == selected ? 255 : 90), width: 2),
                  boxShadow: g.id == selected
                      ? [BoxShadow(color: g.color.withAlpha(p.dark ? 130 : 80), blurRadius: 14)]
                      : [],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(g.icon, color: g.id == selected ? g.color : p.sub, size: 24),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(g.name,
                        style: TextStyle(
                            color: p.text, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GameDef _g = gameById(Store.lastGame);

  Future<void> _play(bool resume) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _g.builder(resume)));
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    if (!Store.hasSave(_g.id)) {
      await _play(false);
      return;
    }
    final r = await showNeonDialog<int>(
      context,
      title: 'UNFINISHED GAME',
      message: 'Resume your saved match, or discard it and start a new one?',
      buttons: (c) => [
        NeonButton('RESUME', const Color(0xFF39FF14), () => Navigator.pop(c, 1), width: double.infinity),
        NeonButton('DISCARD & NEW', const Color(0xFFFF2040), () => Navigator.pop(c, 2), width: double.infinity),
        NeonButton('CANCEL', const Color(0xFF00F0FF), () => Navigator.pop(c, 0), width: double.infinity),
      ],
    );
    if (r == 1) {
      await _play(true);
    } else if (r == 2) {
      await Store.clearSave(_g.id);
      if (mounted) await _play(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = _g;
    final credit = TextStyle(
      color: pieceColors[0],
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 6,
      shadows: [Shadow(color: pieceColors[0].withAlpha(p.dark ? 200 : 90), blurRadius: 10)],
    );
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Column(children: [
            const Padding(padding:EdgeInsets.fromLTRB(16, 14, 16, 2),
            child:NeonTitle(text: 'CLASSIC GAMES', size: 58),
            ),
            const SizedBox(height: 10),
            GameTabs(
              items: games,
              selected: g.id,
              onSelect: (x) {
                Store.setLastGame(x.id);
                setState(() => _g = x);
              },
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(g.id),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NeonTitle(text: g.name),
                        const SizedBox(height: 6),
                        Text(g.tagline, style: TextStyle(color: p.sub, letterSpacing: 6, fontSize: 12)),
                        const SizedBox(height: 44),
                        if (Store.hasSave(g.id)) ...[
                          NeonButton('CONTINUE GAME', const Color(0xFF39FF14), () => _play(true)),
                          const SizedBox(height: 16),
                        ],
                        NeonButton('START GAME', g.color, _start),
                        const SizedBox(height: 16),
                        NeonButton('SCORES', const Color(0xFFB400FF), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ScoresPage(game: g)));
                        }),
                        const SizedBox(height: 16),
                        NeonButton('SETTINGS', const Color(0xFFFF8A00), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                        }),
                        const SizedBox(height: 40),
                        Text('Made With AI', style: credit),
                        Text('BY BCP', style: credit),
                      ],
                    ),
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
  final GameDef game;
  const ScoresPage({super.key, required this.game});
  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> {
  bool byScore = true;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final game = widget.game;
    final list = Store.scores(game.id);
    if (byScore) {
      list.sort((a, b) => (b['s'] as int).compareTo(a['s'] as int));
    } else {
      list.sort((a, b) => (b['d'] as int).compareTo(a['d'] as int));
    }
    final best = list.isEmpty ? 0 : list.map((e) => e['s'] as int).reduce(max);
    return Scaffold(
      appBar: AppBar(title: Text('${game.name} SCORES'), centerTitle: true),
      body: Backdrop(
        animate: false,
        child: list.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(game.icon, size: 72, color: game.color),
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
                              color: top ? Colors.amber : game.color.withAlpha(90), width: top ? 2 : 1),
                          boxShadow: top ? [BoxShadow(color: Colors.amber.withAlpha(90), blurRadius: 14)] : [],
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${e['s']}',
                                  style: TextStyle(color: p.text, fontSize: 26, fontWeight: FontWeight.w900)),
                              Text('Level ${e['v']}  •  ${e['n']} ${game.unit}  •  ${_dur(e['t'] as int)}',
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.panel.withAlpha(210),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.accent.withAlpha(80)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ABOUT',
                  style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, letterSpacing: 3)),
              const SizedBox(height: 10),
              _aboutRow('App', 'Neon Arcade v2.0.0', p),
              _aboutRow('Games', 'Tetris • Pac-Man • Invaders', p),
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
