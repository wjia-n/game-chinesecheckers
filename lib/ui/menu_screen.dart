import 'dart:math';
import 'package:flutter/material.dart';
import '../audio/sound_engine.dart';
import '../engine/board.dart';
import '../engine/game.dart';
import '../services/iap_service.dart';
import '../state/save.dart';
import '../state/settings.dart';
import '../theme/cc_themes.dart';
import 'board_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// Main menu: game logo, title plaque, player-count tokens, per-seat
/// Human/Bot assignment with renameable names and 3 bot difficulties,
/// lacquered Play button, PRO entry.
class MenuScreen extends StatefulWidget {
  final AppSettings settings;
  final SoundEngine sound;
  final StoreService store;

  const MenuScreen(
      {super.key,
      required this.settings,
      required this.sound,
      required this.store});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _playerCount = 2;
  Set<int> _humans = {0};
  final Map<int, Difficulty> _botDiff = {};
  bool _hasSave = false;
  final Map<String, int> _matchScores = {};
  final Map<int, TextEditingController> _nameCtrls = {};

  CcTheme get _t => widget.settings.theme;

  @override
  void initState() {
    super.initState();
    _refreshSave();
    widget.sound.startMenuMusic();
    widget.settings.addListener(_onSettings);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshSave() async {
    final has = await SaveManager.hasSave();
    if (mounted) setState(() => _hasSave = has);
  }

  List<int> get _seats => seatsForPlayerCount(_playerCount);

  TextEditingController _nameCtrl(int seat) {
    return _nameCtrls.putIfAbsent(seat, () {
      final c = TextEditingController(
          text: widget.settings.playerNames[seat]);
      c.addListener(() {
        widget.settings.setPlayerName(seat, c.text);
      });
      return c;
    });
  }

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
      var next = Difficulty.values[(cur.index + 1) % Difficulty.values.length];
      // Imperial (hard) is a Pro feature — skip it for free players.
      if (next == Difficulty.imperial && !widget.settings.isPro) {
        next = Difficulty.porcelain;
      }
      _botDiff[seat] = next;
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

  void _openPro() {
    widget.sound.play(SfxKind.click);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          sound: widget.sound,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    );
  }

  void _howToPlay() {
    final t = _t;
    widget.sound.play(SfxKind.click);
    imperialDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Text('HOW TO PLAY',
                  style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: t.ivory))),
          const SizedBox(height: 8),
          Text(
            'Race all ten of your porcelain marbles across the star into the opposite point.\n\n'
            '• Tap one of your marbles, then tap a gold-ringed hole.\n'
            '• Step to an adjacent hole — or hop over any marble into the empty hole beyond.\n'
            '• Chain hops in one turn: keep jumping with the same marble as far as the board allows.\n'
            '• Jumped marbles stay on the board — there are no captures.\n'
            '• A marble inside your home point may never leave it.\n'
            '• First to fill all ten home holes with their own marbles wins.',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 14.5,
                height: 1.45,
                color: t.ivory),
          ),
          const SizedBox(height: 14),
          Center(
            child: PorcelainButton(
              text: 'Begin',
              theme: t,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      theme: t,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final symmetric =
        widget.settings.symmetricVariant && _playerCount == 2;
    return Scaffold(
      backgroundColor: t.silk,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 14),
              // Game logo.
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: t.gold, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 8),
                      blurRadius: 18,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    Image.asset('assets/cc_logo.png', fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              PorcelainPlaque(
                theme: t,
                child: Column(
                  children: [
                    Text('CHINESE CHECKERS',
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: t.lacquerDeep,
                            letterSpacing: 1.2),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text('THE IMPERIAL PORCELAIN EDITION',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                            color: t.goldOxidized)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Ten marbles. One star. No mercy.',
                  style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: t.ivory.withValues(alpha: 0.75)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              if (_hasSave) ...[
                LacquerButton(
                  text: 'Continue Saved Game',
                  theme: t,
                  fontSize: 16,
                  onPressed: _continue,
                ),
                const SizedBox(height: 10),
              ],
              // Player setup.
              SilkTray(
                theme: t,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLAYERS',
                        style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                            color: t.gold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int n = 2; n <= 6; n++) _countToken(n),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (symmetric)
                      Text(
                        'Symmetric variant: two humans, four colors, alternating turns.',
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 12,
                            color: t.gold.withValues(alpha: 0.9)),
                      )
                    else
                      for (final seat in _seats) _seatRow(seat),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LacquerButton(
                text: 'Play',
                theme: t,
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
                    theme: t,
                    onPressed: _howToPlay,
                  ),
                  const SizedBox(width: 10),
                  _iconDisc(Icons.settings, () {
                    widget.sound.play(SfxKind.click);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          settings: widget.settings,
                          sound: widget.sound,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 10),
                  _iconDisc(
                      widget.settings.isPro
                          ? Icons.workspace_premium
                          : Icons.lock_outline,
                      _openPro),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _openPro,
                child: Text(
                  widget.settings.isPro
                      ? '✦ PRO ACTIVE ✦'
                      : 'Unlock PRO — themes, hard AI & more',
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                      color: t.gold),
                ),
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconDisc(IconData icon, VoidCallback onTap) {
    final t = _t;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.ivory, t.ivoryShade],
          ),
          border: Border.all(color: t.goldOxidized),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000000),
                offset: Offset(0, 4),
                blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: t.lacquerDeep, size: 26),
      ),
    );
  }

  Widget _countToken(int n) {
    final t = _t;
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
                ? [t.lacquer, t.lacquerDeep]
                : [t.silkRaised, t.silk],
          ),
          border: Border.all(
              color: sel ? t.goldBright : t.goldOxidized,
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
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: t.ivory)),
      ),
    );
  }

  Widget _seatRow(int seat) {
    final t = _t;
    final isHuman = _humans.contains(seat);
    final diff = _botDiff[seat] ?? widget.settings.aiDifficulty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          MarbleDot(
            base: t.marbles[seat],
            size: 34,
            style: widget.settings.marbleStyleId,
            theme: t,
          ),
          const SizedBox(width: 8),
          // Renameable player slot.
          Expanded(
            child: TextField(
              controller: _nameCtrl(seat),
              style: TextStyle(
                  fontFamily: 'serif', fontSize: 15, color: t.ivory),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: t.goldOxidized.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.goldBright),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _toggleHuman(seat),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isHuman ? t.lacquer : t.silkRaised,
                border: Border.all(
                    color: isHuman
                        ? t.gold
                        : t.goldOxidized.withValues(alpha: 0.5)),
              ),
              child: Text(isHuman ? 'HUMAN' : 'BOT',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                      color: isHuman
                          ? t.ivory
                          : t.ivory.withValues(alpha: 0.7))),
            ),
          ),
          if (!isHuman) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _cycleDiff(seat),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: t.goldOxidized.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(difficultyName(diff).toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                            color: t.gold)),
                    if (!widget.settings.isPro)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.lock_outline,
                            size: 12,
                            color:
                                t.gold.withValues(alpha: 0.6)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
