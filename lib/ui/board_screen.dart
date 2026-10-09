import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/sound_engine.dart';
import '../engine/ai.dart';
import '../engine/board.dart';
import '../engine/game.dart';
import '../engine/turn_director.dart';
import '../state/save.dart';
import '../state/settings.dart';
import '../theme/cc_themes.dart';
import 'gameover_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// The Imperial Arena: lacquered star board, porcelain marbles, gold inlay
/// move rings, weighty hop-by-hop animations.
///
/// Turn flow is owned by [TurnDirector] (engine-owned state machine +
/// watchdog). The screen only renders, animates moves visibly, narrates,
/// and forwards human input — it never owns turn timers.
class BoardScreen extends StatefulWidget {
  final GameState game;
  final AppSettings settings;
  final SoundEngine sound;
  final Map<String, int> matchScores;
  final VoidCallback onExitToMenu;

  const BoardScreen({
    super.key,
    required this.game,
    required this.settings,
    required this.sound,
    required this.matchScores,
    required this.onExitToMenu,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameState g;
  late TurnDirector director;
  StreamSubscription<TurnEvent>? _events;

  int _selected = -1;
  Set<int> _dests = {};

  // Hop-by-hop move animation state.
  AnimationController? _animCtl;
  List<int> _animPath = [];
  int _animSeg = -1; // current path segment being flown
  int _animHidden = -1; // destination hole hidden while marble flies

  // Invalid-move shake.
  AnimationController? _shake;
  int _shakeHole = -1;

  // Hint display.
  Move? _hint;
  Timer? _hintTimer;

  bool _drawOffered = false;

  CcTheme get _t => widget.settings.theme;
  BoardAccent get _accent =>
      CcThemes.accentById(widget.settings.boardAccentId);

  @override
  void initState() {
    super.initState();
    g = widget.game;
    WidgetsBinding.instance.addObserver(this);
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _wireDirector();
    widget.settings.addListener(_onSettingsChanged);
  }

  void _wireDirector() {
    director = TurnDirector(game: g);
    director.displayNames = _displayNames();
    director.animateMove = _animateMoveStepped;
    director.onCommitted = () {
      _persist();
      if (mounted) setState(() {});
    };
    director.onFinished = () {
      if (mounted) _finishGame();
    };
    _events = director.events.listen((e) {
      if (!mounted) return;
      if (e.kind == TurnEventKind.humanPrompt) {
        widget.sound.play(SfxKind.turnTick);
      }
      setState(() {}); // narration / tray highlight / phase
    });
    director.start();
  }

  List<String> _displayNames() => [
        for (int pi = 0; pi < g.players.length; pi++)
          widget.settings.playerNames[g.players[pi].seat],
      ];

  void _onSettingsChanged() {
    director.displayNames = _displayNames();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    director.dispose();
    _animCtl?.dispose();
    _shake?.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _persist();
    }
  }

  Future<void> _persist() async {
    if (g.status == GameStatus.playing) {
      await SaveManager.saveGame(g, widget.matchScores);
    }
  }

  // ---------------- interaction ----------------

  void _tapHole(int idx) {
    if (director.phase != TurnPhase.awaitingHuman) return;
    if (g.status != GameStatus.playing) return;
    if (!g.current.isHuman) return;
    final pi = g.turnIndex;
    if (_selected != -1 && _dests.contains(idx)) {
      final move = g.findPath(_selected, idx, pi);
      if (move != null) {
        _humanMove(move);
        return;
      }
    }
    if (g.holes[idx] == pi) {
      setState(() {
        if (_selected == idx) {
          _selected = -1;
          _dests = {};
        } else {
          _selected = idx;
          _dests = g.destinationsFor(idx, pi);
          if (_dests.isEmpty) {
            widget.sound.play(SfxKind.invalid);
            _shakeIt(idx);
          } else {
            widget.sound.play(SfxKind.select);
          }
        }
      });
    } else if (_selected != -1) {
      widget.sound.play(SfxKind.invalid);
      _shakeIt(_selected);
      HapticFeedback.lightImpact();
    }
  }

  void _shakeIt(int hole) {
    _shakeHole = hole;
    _shake?.reset();
    _shake?.forward();
  }

  Future<void> _humanMove(Move move) async {
    setState(() {
      _selected = -1;
      _dests = {};
      _hint = null;
    });
    final ok = await director.humanMove(move);
    if (!ok) widget.sound.play(SfxKind.invalid);
  }

  /// Animates a move hop-by-hop, visibly: every hop flies as its own beat
  /// with a short dwell on each landing and its own sound. Never instant.
  Future<void> _animateMoveStepped(Move move) async {
    _animCtl?.dispose();
    _animPath = move.path;
    _animHidden = move.to;
    _animSeg = -1;
    final hops = move.hopCount;
    final isBot = !g.current.isHuman;
    final who = director.nameOf(g.turnIndex);
    for (int sgi = 0; sgi < hops; sgi++) {
      if (!mounted) return;
      _animSeg = sgi;
      _animCtl = AnimationController(
        vsync: this,
        duration:
            Duration(milliseconds: move.isStep ? 210 : 240),
      );
      if (!move.isStep && isBot && hops > 1) {
        director.narration = '$who hops… (${sgi + 1}/$hops)';
      }
      setState(() {});
      // Per-hop sound at the start of each beat.
      widget.sound.play(move.isStep ? SfxKind.step : SfxKind.hop);
      try {
        await _animCtl!.forward();
      } catch (_) {
        break; // disposed mid-flight: stop quietly, engine still commits
      }
      if (sgi < hops - 1) {
        // Dwell on the landing so each hop reads as a distinct step.
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
    _animCtl?.dispose();
    _animCtl = null;
    _animPath = [];
    _animSeg = -1;
    _animHidden = -1;
    if (mounted) setState(() {});
  }

  void _undo() {
    if (director.phase != TurnPhase.awaitingHuman) return;
    if (!g.canUndo || !g.current.isHuman) return;
    widget.sound.play(SfxKind.click);
    setState(() {
      g.undo();
      _selected = -1;
      _dests = {};
      _hint = null;
    });
    _persist();
    director.resync();
  }

  void _showHint() {
    if (director.phase != TurnPhase.awaitingHuman ||
        g.status != GameStatus.playing ||
        !g.current.isHuman) {
      return;
    }
    widget.sound.play(SfxKind.hint);
    final pi = g.turnIndex;
    final ai = Ai();
    Future(() => ai.chooseMove(g, pi, widget.settings.aiDifficulty))
        .then((move) {
      if (!mounted) return;
      setState(() => _hint = move);
      _hintTimer?.cancel();
      _hintTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _hint = null);
      });
    });
  }

  void _finishGame() {
    _persist();
    final isWin = g.status == GameStatus.won;
    widget.sound.play(isWin ? SfxKind.win : SfxKind.lose);
    final humanWon =
        isWin && g.players[g.winnerIndex].isHuman;
    widget.settings.recordGame(
        humanWon: humanWon, turns: g.totalTurns);
    // Update cumulative match scores.
    final pts = g.matchPoints();
    pts.forEach((pi, p) {
      final key = 'seat_${g.players[pi].seat}';
      widget.matchScores[key] = (widget.matchScores[key] ?? 0) + p;
    });
    SaveManager.clearGame();
    widget.sound.startMenuMusic();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameOverScreen(
          game: g,
          settings: widget.settings,
          sound: widget.sound,
          matchScores: widget.matchScores,
          onExitToMenu: widget.onExitToMenu,
        ),
      ),
    );
  }

  // ---------------- pause menu ----------------

  void _pause() {
    if (director.phase != TurnPhase.awaitingHuman) return;
    widget.sound.play(SfxKind.click);
    final t = _t;
    final humans = g.players.where((p) => p.isHuman).length;
    imperialDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('PAUSED', style: _serifTitle(26, t.lacquerDeep)),
          const SizedBox(height: 4),
          goldDivider(t),
          _pauseBtn('Resume', Icons.play_arrow, () {
            Navigator.pop(context);
          }),
          const SizedBox(height: 10),
          _pauseBtn('Restart Game', Icons.refresh, () {
            Navigator.pop(context);
            _restart();
          }),
          const SizedBox(height: 10),
          _pauseBtn('Settings', Icons.settings, () async {
            Navigator.pop(context);
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(
                    settings: widget.settings, sound: widget.sound)));
          }),
          if (humans > 1) ...[
            const SizedBox(height: 10),
            _pauseBtn('Offer Draw', Icons.handshake, () {
              Navigator.pop(context);
              _offerDraw();
            }),
          ],
          const SizedBox(height: 10),
          _pauseBtn('Quit to Menu', Icons.home, () {
            Navigator.pop(context);
            _persist();
            widget.sound.startMenuMusic();
            widget.onExitToMenu();
          }),
        ],
      ),
      theme: t,
    );
  }

  Widget _pauseBtn(String text, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: PorcelainButton(
          text: text, icon: icon, onPressed: onTap, theme: _t),
    );
  }

  void _restart() {
    widget.sound.play(SfxKind.start);
    _events?.cancel();
    director.dispose();
    final fresh = GameState(
      board: Board(),
      players: [for (final p in g.players) p.copy()],
      forwardProgress: widget.settings.forwardProgress,
    );
    // First player randomized among humans (RULES.md §3).
    final humans = [
      for (int i = 0; i < fresh.players.length; i++)
        if (fresh.players[i].isHuman) i
    ];
    if (humans.isNotEmpty) {
      fresh.turnIndex = humans[Random().nextInt(humans.length)];
    }
    setState(() {
      g = fresh;
      _selected = -1;
      _dests = {};
      _hint = null;
      _drawOffered = false;
      _animPath = [];
      _animSeg = -1;
      _animHidden = -1;
    });
    SaveManager.clearGame();
    _wireDirector();
    _persist();
  }

  void _offerDraw() {
    if (_drawOffered) return;
    _drawOffered = true;
    final t = _t;
    final botsAgree = g.botsAcceptDraw();
    imperialDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('OFFER DRAW?', style: _serifTitle(24, t.lacquerDeep)),
          const SizedBox(height: 8),
          Text(
            botsAgree
                ? 'The porcelain minds sense the stalemate and accept.'
                : 'The porcelain minds decline — the game plays on.',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 15,
                color: t.lacquerDeep),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'All local players must agree to end in a draw.',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 13,
                color: t.lacquerDeep.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PorcelainButton(
                    text: 'Keep Playing',
                    theme: t,
                    onPressed: () {
                      _drawOffered = false;
                      Navigator.pop(context);
                    }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LacquerButton(
                  text: 'Agree',
                  theme: t,
                  fontSize: 15,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  onPressed: botsAgree
                      ? () {
                          Navigator.pop(context);
                          setState(() {
                            g.status = GameStatus.draw;
                            g.drawReason = 'Draw by mutual agreement.';
                          });
                          _finishGame();
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
      theme: t,
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final current = g.current;
    final canAct =
        director.phase == TurnPhase.awaitingHuman && current.isHuman;
    return Scaffold(
      backgroundColor: t.silk,
      body: SafeArea(
        child: Column(
          children: [
            // Per-side player trays: every seat has its own tray; the
            // active side highlights with narration. Nobody auto-plays
            // silently — the tray always shows whose turn it is.
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: g.players.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, pi) => _playerTray(pi, t),
              ),
            ),
            // Narration line.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Row(
                  key: ValueKey(director.narration),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (director.phase == TurnPhase.botThinking)
                      _thinkingDots(t),
                    Flexible(
                      child: Text(
                        director.narration,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: t.goldBright.withValues(alpha: 0.95),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Board.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final size = Size(
                        constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onTapUp: (d) {
                        final idx = StarBoardPainter.holeAt(
                            d.localPosition, size, g.board);
                        if (idx != null) _tapHole(idx);
                      },
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _animCtl ?? const AlwaysStoppedAnimation(0),
                          _shake ?? const AlwaysStoppedAnimation(0),
                        ]),
                        builder: (_, _) => CustomPaint(
                          painter: StarBoardPainter(
                            board: g.board,
                            holesState: g.holes,
                            players: g.players,
                            selected: _selected,
                            dests: _dests,
                            hint: _hint,
                            animPath: _animPath,
                            animSeg: _animSeg,
                            animT: _animCtl?.value ?? 0,
                            animHidden: _animHidden,
                            shakeHole: _shakeHole,
                            shakeT: _shake?.value ?? 0,
                            theme: t,
                            accent: _accent,
                            marbleStyle: widget.settings.marbleStyleId,
                          ),
                          size: size,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Bottom dock.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _dockDisc(Icons.undo, 'Undo',
                      canAct && g.canUndo ? _undo : null),
                  _dockDisc(Icons.lightbulb_outline, 'Hint',
                      canAct ? _showHint : null),
                  LacquerButton(
                    text: 'Menu',
                    theme: t,
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    onPressed: director.phase == TurnPhase.awaitingHuman
                        ? () => _pause()
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thinkingDots(CcTheme t) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _PulsingDots(color: t.goldBright),
    );
  }

  /// One side's tray: marble, renameable display name, human/bot chip,
  /// home progress. The active side gets the gold ring.
  Widget _playerTray(int pi, CcTheme t) {
    final p = g.players[pi];
    final active = director.activePlayer == pi &&
        g.status == GameStatus.playing;
    final name = director.displayNames.length > pi
        ? director.displayNames[pi]
        : 'Player ${pi + 1}';
    final home = g.countInDest(pi);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 128,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: active ? t.panel : t.silkRaised.withValues(alpha: 0.6),
        border: Border.all(
          color: active ? t.goldBright : t.goldOxidized.withValues(alpha: 0.4),
          width: active ? 2.2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: t.gold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MarbleDot(
                base: t.marbles[p.seat],
                size: 30,
                selected: active,
                style: widget.settings.marbleStyleId,
                theme: t,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w400,
                    color: t.ivory,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: p.isHuman
                      ? t.lacquer.withValues(alpha: 0.85)
                      : t.silk,
                  border: Border.all(
                      color: t.goldOxidized.withValues(alpha: 0.6)),
                ),
                child: Text(
                  p.isHuman
                      ? 'HUMAN'
                      : difficultyName(p.difficulty).toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: t.goldBright,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$home/10',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 11,
                  color: t.gold.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dockDisc(IconData icon, String label, VoidCallback? onTap) {
    final t = _t;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.35,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.4),
                  radius: 1.2,
                  colors: [Colors.white, t.ivoryShade],
                ),
                border: Border.all(
                    color: enabled
                        ? t.gold
                        : t.goldOxidized.withValues(alpha: 0.5),
                    width: 1.6),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x99000000),
                      offset: Offset(0, 4),
                      blurRadius: 8),
                ],
              ),
              child: Icon(icon, color: t.lacquerDeep, size: 26),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: t.gold.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  TextStyle _serifTitle(double size, Color color) => TextStyle(
        fontFamily: 'serif',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.2,
      );
}

class _PulsingDots extends StatefulWidget {
  final Color color;
  const _PulsingDots({required this.color});

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(
                    alpha: 0.35 +
                        0.65 *
                            (0.5 +
                                0.5 *
                                    sin(_c.value * 2 * pi - i * 2.1))),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================================
// The star board painter — lacquered star, gold inlay, concave dimples,
// glossy porcelain marbles with real weight in their motion.
// Theme-driven: every color comes from the active CcTheme + BoardAccent.
// =====================================================================

class StarBoardPainter extends CustomPainter {
  final Board board;
  final List<int> holesState;
  final List<Competitor> players;
  final int selected;
  final Set<int> dests;
  final Move? hint;
  final List<int> animPath;
  final int animSeg;
  final double animT;
  final int animHidden;
  final int shakeHole;
  final double shakeT;
  final CcTheme theme;
  final BoardAccent accent;
  final String marbleStyle;

  StarBoardPainter({
    required this.board,
    required this.holesState,
    required this.players,
    required this.selected,
    required this.dests,
    required this.hint,
    required this.animPath,
    required this.animSeg,
    required this.animT,
    required this.animHidden,
    required this.shakeHole,
    required this.shakeT,
    required this.theme,
    required this.accent,
    required this.marbleStyle,
  });

  static double _scale(Size size) =>
      min(size.width / 14.2, size.height / 15.4);

  static Offset _pos(Hole h, Size size) {
    final s = _scale(size);
    return Offset(size.width / 2 + h.x * s, size.height / 2 + h.y * s);
  }

  static int? holeAt(Offset p, Size size, Board board) {
    final s = _scale(size);
    var best = 1e9;
    int? idx;
    for (final h in board.holes) {
      final d = (p - _pos(h, size)).distance;
      if (d < best) {
        best = d;
        idx = h.idx;
      }
    }
    return best <= s * 0.5 ? idx : null;
  }

  /// 12-vertex star outline hugging the holes.
  List<Offset> _starOutline(Size size) {
    final s = _scale(size);
    const armAngles = [-90.0, -30.0, 30.0, 90.0, 150.0, 210.0];
    const valleyAngles = [-60.0, 0.0, 60.0, 120.0, 180.0, 240.0];
    final pts = <Offset>[];
    for (int k = 0; k < 6; k++) {
      pts.add(_extreme(size, armAngles[k], 0.85 * s));
      pts.add(_extreme(size, valleyAngles[k], 0.55 * s));
    }
    return pts;
  }

  Offset _extreme(Size size, double deg, double margin) {
    final a = deg * pi / 180.0;
    final dx = cos(a), dy = sin(a);
    var best = -1e9;
    Offset bp = Offset.zero;
    for (final h in board.holes) {
      final p = _pos(h, size);
      final d = (p - Offset(size.width / 2, size.height / 2)).dx * dx +
          (p - Offset(size.width / 2, size.height / 2)).dy * dy;
      if (d > best) {
        best = d;
        bp = p;
      }
    }
    return bp + Offset(dx * margin, dy * margin);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final s = _scale(size);
    final r = s * 0.40;

    // Lacquer tray behind the star.
    final trayRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(22));
    canvas.drawRRect(
        trayRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.lacquerDeep, t.silk],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawRRect(
        trayRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = t.goldOxidized.withValues(alpha: 0.9));

    // Star plate.
    final outline = _starOutline(size);
    final starPath = Path()..addPolygon(outline, true);
    canvas.drawPath(
        starPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.lacquer, t.lacquerDeep],
          ).createShader(starPath.getBounds()));
    // Warm key light from top-left: soft sheen across the plate.
    canvas.drawPath(
        starPath,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.7, -0.8),
            radius: 1.4,
            colors: [
              Color(0x33FFE9C4),
              Color(0x00000000),
            ],
          ).createShader(starPath.getBounds()));
    canvas.save();
    canvas.clipPath(starPath);

    // Inlay grid lines between neighbors.
    final inlay = Paint()
      ..color = accent.inlay.withValues(alpha: 0.30)
      ..strokeWidth = max(1.0, s * 0.035);
    for (int i = 0; i < board.holes.length; i++) {
      for (final nb in board.neighbors[i]) {
        if (nb < i) continue;
        canvas.drawLine(
            _pos(board.holes[i], size), _pos(board.holes[nb], size), inlay);
      }
    }

    // Destination-arm washes (faint player-color tint on each home arm).
    for (int pi = 0; pi < players.length; pi++) {
      final wash =
          t.marbles[players[pi].seat].withValues(alpha: 0.14);
      for (final h in board.armHoles(players[pi].destArm)) {
        canvas.drawCircle(
            _pos(board.holes[h], size), r * 1.25, Paint()..color = wash);
      }
    }

    // Dimples: concave wells with rim crescent + faint inlay motif.
    for (final h in board.holes) {
      _paintDimple(canvas, _pos(h, size), r);
    }
    canvas.restore();
    // Star edge: accent stroke.
    canvas.drawPath(
        starPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = t.gold.withValues(alpha: 0.85));

    // Destination rings: thin antique-gold inlay rings (never neon dots).
    for (final d in dests) {
      final p = _pos(board.holes[d], size);
      canvas.drawCircle(
          p,
          r * 0.62,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = t.goldBright);
      canvas.drawCircle(
          p,
          r * 0.62,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = t.gold.withValues(alpha: 0.25));
    }

    // Hint path.
    if (hint != null) {
      final pulse =
          0.5 + 0.5 * sin(DateTime.now().millisecondsSinceEpoch / 300);
      for (final h in hint!.path) {
        canvas.drawCircle(
            _pos(board.holes[h], size),
            r * (0.30 + 0.08 * pulse),
            Paint()..color = t.goldBright.withValues(alpha: 0.8));
      }
    }

    // Marbles.
    for (final h in board.holes) {
      final pi = holesState[h.idx];
      if (pi == -1 || h.idx == animHidden) continue;
      var p = _pos(h, size);
      var scale = 1.0;
      var lift = 0.0;
      if (h.idx == selected) {
        scale = 1.14;
        lift = 1.0;
        canvas.drawCircle(
            p,
            r * 1.28,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = t.goldBright);
      }
      if (h.idx == shakeHole && shakeT > 0 && shakeT < 1) {
        p += Offset(sin(shakeT * pi * 5) * s * 0.10 * (1 - shakeT), 0);
      }
      _paintMarble(canvas, p, r * scale,
          t.marbles[players[pi].seat], lift);
    }

    // Flying marble along the current animation segment.
    if (animPath.length >= 2 && animSeg >= 0 && animT > 0) {
      final pos = _animPos(size, s);
      if (pos != null) {
        _paintMarble(canvas, pos.offset, r * (1 + 0.10 * pos.elev),
            t.marbles[players[pos.pi].seat], pos.elev,
            squash: pos.squash);
      }
    }
  }

  void _paintDimple(Canvas canvas, Offset p, double r) {
    final t = theme;
    canvas.drawCircle(
        p + Offset(r * 0.12, r * 0.18),
        r * 0.78,
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawCircle(
        p,
        r * 0.72,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.35, 0.45),
            radius: 1.1,
            colors: [
              t.silk.withValues(alpha: 0.85),
              t.lacquerDeep,
            ],
          ).createShader(Rect.fromCircle(center: p, radius: r * 0.72)));
    canvas.drawArc(
        Rect.fromCircle(center: p, radius: r * 0.72),
        pi * 0.9,
        pi * 0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.10
          ..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawArc(
        Rect.fromCircle(center: p, radius: r * 0.66),
        pi * -0.15,
        pi * 0.75,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..color = accent.rim.withValues(alpha: 0.55));
    // Faint inlay line drawing (20% opacity).
    final motif = accent.inlay.withValues(alpha: 0.20);
    canvas.drawCircle(
        p,
        r * 0.20,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = motif);
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2 + pi / 4;
      canvas.drawCircle(
          p + Offset(cos(a) * r * 0.34, sin(a) * r * 0.34),
          r * 0.07,
          Paint()..color = motif);
    }
  }

  void _paintMarble(
      Canvas canvas, Offset p, double r, Color base, double lift,
      {double squash = 0}) {
    canvas.drawOval(
        Rect.fromCenter(
            center:
                p + Offset(r * 0.25 + lift * r * 0.5, r * (0.75 + lift * 0.9)),
            width: r * (1.7 - lift * 0.4),
            height: r * (0.62 - lift * 0.14)),
        Paint()..color = Colors.black.withValues(alpha: 0.55 - lift * 0.15));
    final c = p - Offset(0, lift * r * 1.1);
    final sy = squash > 0 ? 1 - squash * 0.16 : 1.0;
    final sx = squash > 0 ? 1 + squash * 0.12 : 1.0;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(sx, sy);
    paintMarbleFace(canvas, Offset.zero, r, base, marbleStyle);
    canvas.restore();
  }

  _AnimPos? _animPos(Size size, double s) {
    if (animPath.length < 2) return null;
    final seg = animSeg.clamp(0, animPath.length - 2);
    final lt = animT.clamp(0.0, 1.0);
    // Last 12% of each hop is the landing squash.
    var squash = 0.0;
    if (lt > 0.88) squash = (lt - 0.88) / 0.12;
    final a = _pos(board.holes[animPath[seg]], size);
    final b = _pos(board.holes[animPath[seg + 1]], size);
    final isHop = (b - a).distance > s * 1.3;
    final peak = (isHop ? s * 0.55 : s * 0.28) * sin(pi * lt);
    final mid = (a + b) / 2 - Offset(0, peak * 2);
    final q0 = a + (mid - a) * lt;
    final q1 = mid + (b - mid) * lt;
    final pos = q0 + (q1 - q0) * lt;
    final elev = sin(pi * lt);
    final mover = holesState[animPath.first];
    return _AnimPos(
        offset: pos, elev: elev, squash: squash, pi: mover < 0 ? 0 : mover);
  }

  @override
  bool shouldRepaint(covariant StarBoardPainter old) => true;
}

class _AnimPos {
  final Offset offset;
  final double elev;
  final double squash;
  final int pi;
  _AnimPos(
      {required this.offset,
      required this.elev,
      required this.squash,
      required this.pi});
}
