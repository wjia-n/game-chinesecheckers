import 'dart:math';
import 'package:flutter/material.dart';
import '../audio/sound_engine.dart';
import '../engine/board.dart';
import '../engine/game.dart';
import '../state/save.dart';
import '../state/settings.dart';
import '../theme/imperial.dart';
import 'board_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// Main menu: ivory title plaque, hero porcelain marble, player-count
/// tokens, per-seat Human/Bot assignment, lacquered Play button.
class MenuScreen extends StatefulWidget {
  final AppSettings settings;
  final SoundEngine sound;

  const MenuScreen({super.key, required this.settings, required this.sound});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _playerCount = 2;
  Set<int> _humans = {0};
  final Map<int, Difficulty> _botDiff = {};
  bool _hasSave = false;
  final Map<String, int> _matchScores = {};

  @override
  void initState() {
    super.initState();
    _refreshSave();
    widget.sound.startMenuMusic();
  }

  Future<void> _refreshSave() async {
    final has = await SaveManager.hasSave();
    if (mounted) setState(() => _hasSave = has);
  }

  List<int> get _seats => seatsForPlayerCount(_playerCount);

  void _setCount(int n) {
    widget.sound.play(SfxKind.click);
    setState(() {
      _playerCount = n;
      _humans = {_seats.first};
      _botDiff.clear();
    });
  }

  void _toggleHuman(int seat) {
    widget.sound.play(SfxKind.click);
    setState(() {
      if (_humans.contains(seat)) {
        if (_humans.length > 1) _humans.remove(seat);
      } else {
        _humans.add(seat);
      }
    });
  }

  void _cycleDiff(int seat) {
    widget.sound.play(SfxKind.click);
    setState(() {
      final cur = _botDiff[seat] ?? widget.settings.aiDifficulty;
      _botDiff[seat] =
          Difficulty.values[(cur.index + 1) % Difficulty.values.length];
    });
  }

  List<Competitor> _buildCompetitors() {
    final symmetric =
        widget.settings.symmetricVariant && _playerCount == 2;
    if (symmetric) {
      // Four arms, alternating turns per color; two local humans.
      final seats = [0, 1, 3, 4];
      return [
        for (int i = 0; i < seats.length; i++)
          Competitor(
            seat: seats[i],
            isHuman: true,
            difficulty: widget.settings.aiDifficulty,
            owner: i.isEven ? 0 : 1,
          ),
      ];
    }
    return [
      for (final seat in _seats)
        Competitor(
          seat: seat,
          isHuman: _humans.contains(seat),
          difficulty: _botDiff[seat] ?? widget.settings.aiDifficulty,
        ),
    ];
  }

  void _play() {
    widget.sound.play(SfxKind.start);
    final players = _buildCompetitors();
    final game = GameState(
      board: Board(),
      players: players,
      forwardProgress: widget.settings.forwardProgress,
    );
    // First player randomized among humans (RULES.md §3).
    final humans = [
      for (int i = 0; i < players.length; i++)
        if (players[i].isHuman) i
    ];
    game.turnIndex = humans[Random().nextInt(humans.length)];
    widget.sound.startGameMusic();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => BoardScreen(
          game: game,
          settings: widget.settings,
          sound: widget.sound,
          matchScores: _matchScores,
          onExitToMenu: _exitToMenu,
        ),
      ),
    )
        .then((_) {
      _refreshSave();
      widget.sound.startMenuMusic();
      setState(() {});
    });
  }

  Future<void> _continue() async {
    final loaded = await SaveManager.loadGame();
    if (loaded == null || !mounted) return;
    widget.sound.play(SfxKind.start);
    _matchScores
      ..clear()
      ..addAll(loaded.match);
    widget.sound.startGameMusic();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => BoardScreen(
          game: loaded.game,
          settings: widget.settings,
          sound: widget.sound,
          matchScores: _matchScores,
          onExitToMenu: _exitToMenu,
        ),
      ),
    )
        .then((_) {
      _refreshSave();
      widget.sound.startMenuMusic();
      setState(() {});
    });
  }

  void _exitToMenu() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _refreshSave();
    widget.sound.startMenuMusic();
    setState(() {});
  }

  void _howToPlay() {
    widget.sound.play(SfxKind.click);
    imperialDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Text('HOW TO PLAY',
                  style: Imperial.plaqueTitle(22))),
          const SizedBox(height: 8),
          Text(
            'Race all ten of your porcelain marbles across the star into the opposite point.\n\n'
            '• Tap one of your marbles, then tap a gold-ringed hole.\n'
            '• Step to an adjacent hole — or hop over any marble into the empty hole beyond.\n'
            '• Chain hops in one turn: keep jumping with the same marble as far as the board allows.\n'
            '• Jumped marbles stay on the board — there are no captures.\n'
            '• A marble inside your home point may never leave it.\n'
            '• First to fill all ten home holes with their own marbles wins.',
            style: Imperial.body(14.5, color: Imperial.cinnabarDeep),
          ),
          const SizedBox(height: 14),
          Center(
            child: PorcelainButton(
              text: 'Begin',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symmetric =
        widget.settings.symmetricVariant && _playerCount == 2;
    return BrocadeBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 14),
              // Title plaque.
              PorcelainPlaque(
                child: Column(
                  children: [
                    Text('CHINESE CHECKERS',
                        style: Imperial.plaqueTitle(30),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text('THE IMPERIAL PORCELAIN EDITION',
                        style: Imperial.label(11,
                            color: Imperial.goldOxidized)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Hero marble.
              const MarbleDot(base: Imperial.cobaltDeep, size: 110),
              const SizedBox(height: 6),
              Text('Ten marbles. One star. No mercy.',
                  style: Imperial.body(14,
                      color:
                          Imperial.ivoryText.withValues(alpha: 0.75)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 18),
              if (_hasSave) ...[
                LacquerButton(
                  text: 'Continue Saved Game',
                  fontSize: 16,
                  onPressed: _continue,
                ),
                const SizedBox(height: 10),
              ],
              // Player count tokens.
              SilkTray(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLAYERS', style: Imperial.label(13)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int n = 2; n <= 6; n++)
                          _countToken(n),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (symmetric)
                      Text(
                        'Symmetric variant: two humans, four colors, alternating turns.',
                        style: Imperial.body(12,
                            color: Imperial.gold.withValues(alpha: 0.9)),
                      )
                    else
                      for (final seat in _seats) _seatRow(seat),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LacquerButton(
                text: 'Play',
                fontSize: 22,
                padding: const EdgeInsets.symmetric(
                    horizontal: 70, vertical: 16),
                onPressed: _play,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PorcelainButton(
                    text: 'How to Play',
                    icon: Icons.menu_book,
                    onPressed: _howToPlay,
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      widget.sound.play(SfxKind.click);
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            settings: widget.settings,
                            sound: widget.sound,
                          ),
                        ),
                      )
                          .then((_) {
                        widget.sound.applySettings(
                          musicOn: widget.settings.musicOn,
                          sfxOn: widget.settings.sfxOn,
                          musicVolume: widget.settings.musicVolume,
                          sfxVolume: widget.settings.sfxVolume,
                        );
                      });
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Imperial.ivory,
                            Imperial.ivoryShade
                          ],
                        ),
                        border: Border.all(
                            color: Imperial.goldOxidized),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x99000000),
                              offset: Offset(0, 4),
                              blurRadius: 8),
                        ],
                      ),
                      child: const Icon(Icons.settings,
                          color: Imperial.cinnabarDeep, size: 26),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countToken(int n) {
    final sel = _playerCount == n;
    return GestureDetector(
      onTap: () => _setCount(n),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 1.2,
            colors: sel
                ? [Imperial.cinnabar, Imperial.cinnabarDeep]
                : [Imperial.silkRaised, Imperial.silkLow],
          ),
          border: Border.all(
              color: sel ? Imperial.goldBright : Imperial.goldOxidized,
              width: sel ? 2.4 : 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text('$n',
            style: Imperial.label(17,
                color: sel ? Imperial.ivory : Imperial.ivoryText)),
      ),
    );
  }

  Widget _seatRow(int seat) {
    final isHuman = _humans.contains(seat);
    final diff = _botDiff[seat] ?? widget.settings.aiDifficulty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          MarbleDot(base: Imperial.marbleBase[seat], size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(Imperial.marbleNames[seat],
                style: Imperial.body(15, color: Imperial.ivory)),
          ),
          GestureDetector(
            onTap: () => _toggleHuman(seat),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isHuman
                    ? Imperial.cinnabar
                    : Imperial.silkLow,
                border: Border.all(
                    color: isHuman
                        ? Imperial.gold
                        : Imperial.goldOxidized.withValues(alpha: 0.5)),
              ),
              child: Text(isHuman ? 'HUMAN' : 'BOT',
                  style: Imperial.label(11,
                      color: isHuman
                          ? Imperial.ivory
                          : Imperial.ivoryText
                              .withValues(alpha: 0.7))),
            ),
          ),
          if (!isHuman) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _cycleDiff(seat),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Imperial.goldOxidized.withValues(alpha: 0.6)),
                ),
                child: Text(difficultyName(diff).toUpperCase(),
                    style: Imperial.label(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
