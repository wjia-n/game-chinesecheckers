import 'package:flutter/material.dart';
import '../audio/sound_engine.dart';
import '../engine/board.dart';
import '../engine/game.dart';
import '../state/save.dart';
import '../state/settings.dart';
import '../theme/imperial.dart';
import 'board_screen.dart';
import 'widgets.dart';

/// Victory celebration: lacquered presentation tray, marble pyramid on silk,
/// porcelain ribbon banner, winner plaque, standings tablets.
class GameOverScreen extends StatelessWidget {
  final GameState game;
  final AppSettings settings;
  final SoundEngine sound;
  final Map<String, int> matchScores;
  final VoidCallback onExitToMenu;

  const GameOverScreen({
    super.key,
    required this.game,
    required this.settings,
    required this.sound,
    required this.matchScores,
    required this.onExitToMenu,
  });

  @override
  Widget build(BuildContext context) {
    final isWin = game.status == GameStatus.won;
    final ranks = game.ranks();
    final pts = game.matchPoints();
    final winnerSeat =
        isWin ? game.players[game.winnerIndex].seat : -1;
    return BrocadeBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Marble pyramid trophy.
              SizedBox(
                height: 150,
                child: CustomPaint(
                  painter: _PyramidPainter(
                    base: isWin
                        ? Imperial.marbleBase[winnerSeat]
                        : Imperial.gold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Ribbon banner.
              PorcelainPlaque(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                child: Text(
                  isWin ? 'VICTORY!' : 'DRAW',
                  style: Imperial.plaqueTitle(34),
                ),
              ),
              const SizedBox(height: 12),
              if (isWin)
                SilkTray(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MarbleDot(
                          base: Imperial.marbleBase[winnerSeat], size: 52),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${Imperial.marbleNames[winnerSeat]} triumphs!',
                            style: Imperial.headline(20),
                          ),
                          Text(
                            'All ten marbles rest in the home star.',
                            style: Imperial.body(13,
                                color: Imperial.ivoryText
                                    .withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                SilkTray(
                  child: Text(
                    game.drawReason.isEmpty
                        ? 'The star rests in perfect balance.'
                        : game.drawReason,
                    style: Imperial.body(15),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 14),
              // Standings tablets.
              SilkTray(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STANDINGS',
                        style: Imperial.label(13)),
                    Imperial.divider(),
                    for (int rank = 0; rank < ranks.length; rank++)
                      _standingRow(ranks[rank], rank, pts),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Match points.
              if (matchScores.isNotEmpty)
                SilkTray(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('MATCH POINTS',
                                  style: Imperial.label(13))),
                          GestureDetector(
                            onTap: () {
                              matchScores.clear();
                              SaveManager.clearMatch();
                              sound.play(SfxKind.click);
                              onExitToMenu();
                            },
                            child: Text('RESET MATCH',
                                style: Imperial.label(11,
                                    color: Imperial.cinnabarText)),
                          ),
                        ],
                      ),
                      Imperial.divider(),
                      for (final e in _sortedMatch())
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(e.key,
                                    style: Imperial.body(15)),
                              ),
                              Text('${e.value}',
                                  style: Imperial.label(14)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              LacquerButton(
                text: 'Play Again',
                onPressed: () {
                  sound.play(SfxKind.start);
                  final fresh = GameState(
                    board: Board(),
                    players: [
                      for (final p in game.players) p.copy()
                    ],
                    forwardProgress: settings.forwardProgress,
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => BoardScreen(
                        game: fresh,
                        settings: settings,
                        sound: sound,
                        matchScores: matchScores,
                        onExitToMenu: onExitToMenu,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              PorcelainButton(
                text: 'Main Menu',
                icon: Icons.home,
                onPressed: onExitToMenu,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _standingRow(int pi, int rank, Map<int, int> pts) {
    final seat = game.players[pi].seat;
    final isWinner = game.status == GameStatus.won && rank == 0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWinner
            ? Imperial.gold.withValues(alpha: 0.12)
            : Imperial.silkLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWinner
              ? Imperial.gold
              : Imperial.goldOxidized.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(isWinner ? '♛' : '${rank + 1}',
                style: Imperial.label(16,
                    color: isWinner
                        ? Imperial.goldBright
                        : Imperial.ivoryText)),
          ),
          MarbleDot(base: Imperial.marbleBase[seat], size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Imperial.marbleNames[seat]}${game.players[pi].isHuman ? '' : '  •  Bot'}',
                  style: Imperial.body(15, color: Imperial.ivory),
                ),
                Text(
                  '${game.countInDest(pi)}/10 home  •  ${game.moveCounts[pi]} moves',
                  style: Imperial.body(12,
                      color:
                          Imperial.ivoryText.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          Text('+${pts[pi] ?? 0}',
              style: Imperial.label(14, color: Imperial.goldBright)),
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _sortedMatch() {
    final list = matchScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

/// Marble pyramid trophy painted on silk.
class _PyramidPainter extends CustomPainter {
  final Color base;
  _PyramidPainter({required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 4;
    final r = size.height / (rows * 2.4);
    final cx = size.width / 2;
    final baseY = size.height - r * 1.2;
    for (int row = 0; row < rows; row++) {
      final count = rows - row;
      for (int i = 0; i < count; i++) {
        final x = cx + (i - (count - 1) / 2) * r * 2.15;
        final y = baseY - row * r * 1.9;
        _marble(canvas, Offset(x, y), r, base, row);
      }
    }
  }

  void _marble(Canvas canvas, Offset c, double r, Color base, int row) {
    final shade =
        HSLColor.fromColor(base).withLightness((0.55 - row * 0.06).clamp(0.15, 0.8)).toColor();
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(r * 0.2, r * 0.9),
            width: r * 1.7,
            height: r * 0.6),
        Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.42, -0.48),
            radius: 1.25,
            colors: [
              Imperial.marbleLight(base),
              shade,
              Imperial.marbleDark(base)
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(-r * 0.34, -r * 0.40),
            width: r * 0.52,
            height: r * 0.32),
        Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Imperial.gold.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant _PyramidPainter old) => old.base != base;
}
