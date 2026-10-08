import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const ChineseCheckersApp());

class ChineseCheckersApp extends StatelessWidget {
  const ChineseCheckersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.retroCabinet,
      title: 'Chinese Checkers',
      tagline: 'Hop, skip and jump your marbles across the star! 🔮',
      emoji: '🔮',
      slug: 'chinesecheckers',
      howToPlay:
          '• Tap one of your glowing marbles, then tap a highlighted hole.\n• Move one step — or hop over marbles for a mega chain-jump!\n• Long hop chains in a single turn are totally legal. Go wild!\n• First to park all 10 marbles in the opposite star point wins. 🏆',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => ChineseCheckersScreen(players: players, callbacks: cb),
    );
  }
}
