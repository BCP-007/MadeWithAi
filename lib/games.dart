import 'package:flutter/material.dart';
import 'game_page.dart';
import 'invaders_page.dart';
import 'pacman_page.dart';

class GameDef {
  final String id, name, tagline, unit;
  final Color color;
  final IconData icon;
  final Widget Function(bool resume) builder;
  const GameDef(this.id, this.name, this.tagline, this.unit, this.color, this.icon, this.builder);
}

/// Add a new game here and it appears on the home page automatically.
final List<GameDef> games = [
  GameDef('tetris', 'TETRIS', 'SCI-FI ARCADE', 'lines', const Color(0xFF00F0FF),
      Icons.grid_view_rounded, (r) => GamePage(resume: r)),
  GameDef('pacman', 'PAC-MAN', 'CHOMP & CHASE', 'dots', const Color(0xFFFFE600),
      Icons.pie_chart, (r) => PacmanScreen(resume: r)),
  GameDef('invaders', 'INVADERS', 'DEFEND THE EARTH', 'aliens', const Color(0xFFFF4FD8),
      Icons.smart_toy, (r) => InvadersScreen(resume: r)),
];

GameDef gameById(String id) => games.firstWhere((g) => g.id == id, orElse: () => games.first);
