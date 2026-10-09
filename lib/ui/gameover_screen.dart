import 'package:flutter/material.dart';
import '../audio/sound_engine.dart';
import '../engine/board.dart';
import '../engine/game.dart';
import '../state/save.dart';
import '../state/settings.dart';
import '../theme/cc_themes.dart';
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

  CcTheme get _t => settings.theme;

  String _nameOf(int pi) {
    final seat = game.players[pi].seat;
    final n = settings.playerNames[seat];
    return n.isEmpty ? 'Player ${pi + 1}' : n;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final isWin = game.status == GameStatus.won;
    final ranks = game.ranks();
    final pts = game.matchPoints();
    final winnerSeat =
        isWin ? game.players[game.winnerIndex].seat : -1;
    return Scaffold(
      backgroundColor: t.silk,
      body: SafeArea(
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
                        ? t.marbles[winnerSeat]
                        : t.gold,
                    gold: t.gold,
                    style: settings.marbleStyleId,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Ribbon banner.
              PorcelainPlaque(
                theme: t,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                child: Text(
                  isWin ? 'VICTORY!' : 'DRAW',
                  style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: t.lacquerDeep,
                      letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 12),
              if (isWin)
                SilkTray(
                  theme: t,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MarbleDot(
                          base: t.marbles[winnerSeat],
                          size: 52,
                          style: settings.marbleStyleId,
                          theme: t),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_nameOf(game.winnerIndex)} triumphs!',
                            style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: t.ivory),
                          ),
                          Text(
                            'All ten marbles rest in the home star.',
                            style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 13,
                                color: t.ivory
                                    .withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                SilkTray(
                  theme: t,
                  child: Text(
                    game.drawReason.isEmpty
                        ? 'The star rests in perfect balance.'
                        : game.drawReason,
                    style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        color: t.ivory),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 14),
              // Standings tablets.
              SilkTray(
                theme: t,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STANDINGS',
                        style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                            color: t.gold)),
                    goldDivider(t),
                    for (int rank = 0; rank < ranks.length; rank++)
                      _standingRow(ranks[rank], rank, pts, t),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Match points.
              if (matchScores.isNotEmpty)
                SilkTray(
                  theme: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('MATCH POINTS',
                                  style: TextStyle(
                                      fontSize: 13,
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w600,
                                      color: t.gold))),
                          GestureDetector(
                            onTap: () {
                              matchScores.clear();
                              SaveManager.clearMatch();
                              sound.play(SfxKind.click);
                              onExitToMenu();
                            },
                            child: Text('RESET MATCH',
                                style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w600,
                                    color: t.goldBright)),
                          ),
                        ],
                      ),
                      goldDivider(t),
                      for (final e in _sortedMatch())
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(_matchName(e.key),
                                    style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 15,
                                        color: t.ivory)),
                              ),
                              Text('${e.value}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                      color: t.gold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              LacquerButton(
                text: 'Play Again',
                theme: t,
                onPressed: () {
                  sound.play(SfxKind.start);
                  final fresh = GameState(
                    board: Board(),
                    players: [
                      for (final p in game.players) p.copy()
                    ],
                    forwardProgress: settings.forwardProgress,
                  );
                  sound.startGameMusic();
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
                theme: t,
                onPressed: onExitToMenu,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _matchName(String key) {
    // Keys are 'seat_<n>' (new) or legacy color names.
    if (key.startsWith('seat_')) {
      final seat = int.tryParse(key.substring(5)) ?? -1;
      if (seat >= 0 && seat < 6) {
        final n = settings.playerNames[seat];
        if (n.isNotEmpty) return n;
      }
    }
    return key;
  }

  Widget _standingRow(int pi, int rank, Map<int, int> pts, CcTheme t) {
    final seat = game.players[pi].seat;
    final isWinner = game.status == GameStatus.won && rank == 0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWinner
            ? t.gold.withValues(alpha: 0.12)
            : t.silkRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWinner
              ? t.gold
              : t.goldOxidized.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(isWinner ? '♛' : '${rank + 1}',
                style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: isWinner
                        ? t.goldBright
                        : t.ivory.withValues(alpha: 0.7))),
          ),
          MarbleDot(
              base: t.marbles[seat],
              size: 34,
              style: settings.marbleStyleId,
              theme: t),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_nameOf(pi)}${game.players[pi].isHuman ? '' : '  •  Bot'}',
                  style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      color: t.ivory),
                ),
                Text(
                  '${game.countInDest(pi)}/10 home  •  ${game.moveCounts[pi]} moves',
                  style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 12,
                      color:
                          t.ivory.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          Text('+${pts[pi] ?? 0}',
              style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: t.goldBright)),
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
  final Color gold;
  final String style;
  _PyramidPainter(
      {required this.base, required this.gold, required this.style});

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
        paintMarbleFace(canvas, Offset(x, y), r, base, style);
        canvas.drawCircle(
            Offset(x, y),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = gold.withValues(alpha: 0.7));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PyramidPainter old) =>
      old.base != base || old.style != style;
}
