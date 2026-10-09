import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/sound_engine.dart';
import '../engine/ai.dart';
import '../engine/board.dart';
import '../engine/game.dart';
import '../state/save.dart';
import '../state/settings.dart';
import '../theme/imperial.dart';
import 'gameover_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

/// The Imperial Arena: cinnabar lacquer star board, porcelain marbles,
/// gold inlay move rings, weighty hop animations.
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
  final Ai _ai = Ai();
  int _selected = -1;
  Set<int> _dests = {};
  bool _busy = false; // animation or bot thinking

  // Move animation state.
  AnimationController? _anim;
  List<int> _animPath = [];
  int _animHidden = -1; // destination hole hidden while marble flies

  // Invalid-move shake.
  AnimationController? _shake;
  int _shakeHole = -1;

  // Hint display.
  Move? _hint;
  Timer? _hintTimer;

  // Draw offer state.
  bool _drawOffered = false;

  @override
  void initState() {
    super.initState();
    g = widget.game;
    WidgetsBinding.instance.addObserver(this);
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _afterTurn());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anim?.dispose();
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
    if (_busy || g.status != GameStatus.playing) return;
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
      // Tapped an illegal hole while a marble is selected.
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
    final wasHop = !move.isStep;
    setState(() {
      _busy = true;
      _selected = -1;
      _dests = {};
      _hint = null;
    });
    await _animateMove(move);
    final ok = g.commitMove(move);
    if (!ok) {
      // Should never happen: the move came from legal generation.
      setState(() => _busy = false);
      return;
    }
    widget.sound.play(wasHop ? SfxKind.hop : SfxKind.step);
    await _persist();
    if (!mounted) return;
    setState(() => _busy = false);
    if (g.status != GameStatus.playing) {
      _finishGame();
      return;
    }
    _afterTurn();
  }

  Future<void> _animateMove(Move move) async {
    _anim?.dispose();
    _animPath = move.path;
    _animHidden = move.to;
    final hops = move.hopCount;
    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 170 * hops + 130),
    );
    setState(() {});
    await _anim!.forward();
    _anim?.dispose();
    _anim = null;
    _animPath = [];
    _animHidden = -1;
  }

  void _afterTurn() {
    if (!mounted || g.status != GameStatus.playing) return;
    if (!g.current.isHuman && !_busy) {
      setState(() => _busy = true);
      final gameGen = g; // stale bot callbacks must not touch a restarted game
      Future.delayed(const Duration(milliseconds: 650), () async {
        if (!mounted ||
            !identical(gameGen, g) ||
            g.status != GameStatus.playing) {
          return;
        }
        final pi = g.turnIndex;
        if (g.current.isHuman) {
          setState(() => _busy = false);
          return;
        }
        final move =
            await Future(() => _ai.chooseMove(g, pi, g.current.difficulty));
        await _animateMove(move);
        g.commitMove(move);
        widget.sound.play(move.isStep ? SfxKind.step : SfxKind.hop);
        await _persist();
        if (!mounted) return;
        setState(() => _busy = false);
        if (g.status != GameStatus.playing) {
          _finishGame();
          return;
        }
        if (g.current.isHuman) widget.sound.play(SfxKind.turnTick);
        _afterTurn();
      });
    }
  }

  void _undo() {
    if (_busy || !g.canUndo || !g.current.isHuman) return;
    widget.sound.play(SfxKind.click);
    setState(() {
      g.undo();
      _selected = -1;
      _dests = {};
      _hint = null;
    });
    _persist();
  }

  void _showHint() {
    if (_busy || g.status != GameStatus.playing || !g.current.isHuman) {
      return;
    }
    widget.sound.play(SfxKind.hint);
    final pi = g.turnIndex;
    Future(() => _ai.chooseMove(g, pi, widget.settings.aiDifficulty))
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
    // Update cumulative match scores.
    final pts = g.matchPoints();
    pts.forEach((pi, p) {
      final key = Imperial.marbleNames[g.players[pi].seat];
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
    if (_busy) return;
    widget.sound.play(SfxKind.click);
    final humans = g.players.where((p) => p.isHuman).length;
    imperialDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('PAUSED', style: Imperial.plaqueTitle(26)),
          const SizedBox(height: 4),
          Imperial.divider(),
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
            _applyAudio();
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
    );
  }

  Widget _pauseBtn(String text, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: PorcelainButton(text: text, icon: icon, onPressed: onTap),
    );
  }

  void _restart() {
    widget.sound.play(SfxKind.start);
    final fresh = GameState(
      board: Board(),
      players: [for (final p in g.players) p.copy()],
      forwardProgress: widget.settings.forwardProgress,
    );
    // Randomize first player among humans (RULES.md §3).
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
      _busy = false;
      _drawOffered = false;
    });
    SaveManager.clearGame();
    _persist();
    _afterTurn();
  }

  void _offerDraw() {
    if (_drawOffered) return;
    _drawOffered = true;
    final botsAgree = g.botsAcceptDraw();
    imperialDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('OFFER DRAW?', style: Imperial.plaqueTitle(24)),
          const SizedBox(height: 8),
          Text(
            botsAgree
                ? 'The porcelain minds sense the stalemate and accept.'
                : 'The porcelain minds decline — the game plays on.',
            style: Imperial.body(15, color: Imperial.cinnabarDeep),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'All local players must agree to end in a draw.',
            style: Imperial.body(13,
                color: Imperial.cinnabarDeep.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PorcelainButton(
                    text: 'Keep Playing',
                    onPressed: () {
                      _drawOffered = false;
                      Navigator.pop(context);
                    }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LacquerButton(
                  text: 'Agree',
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
    );
  }

  void _applyAudio() {
    widget.sound.applySettings(
      musicOn: widget.settings.musicOn,
      sfxOn: widget.settings.sfxOn,
      musicVolume: widget.settings.musicVolume,
      sfxVolume: widget.settings.sfxVolume,
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final current = g.current;
    final marbleColor = Imperial.marbleBase[current.seat];
    return BrocadeBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Top plaque: current player + move counter + pause.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: PorcelainPlaque(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    MarbleDot(base: marbleColor, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${Imperial.marbleNames[current.seat]}${current.isHuman ? '' : '  •  ${difficultyName(current.difficulty)}'}',
                            style: Imperial.plaqueTitle(17),
                          ),
                          Text(
                            current.isHuman ? 'YOUR MOVE' : 'THINKING…',
                            style: Imperial.label(11,
                                color: Imperial.cinnabar),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('MOVE',
                            style: Imperial.label(10,
                                color: Imperial.goldOxidized)),
                        Text('${g.totalTurns} / 300',
                            style: Imperial.body(14,
                                color: Imperial.cinnabarDeep)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    _discButton(Icons.pause, () => _pause()),
                  ],
                ),
              ),
            ),
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
                        animation: Listenable.merge(
                            [_anim ?? const AlwaysStoppedAnimation(0),
                             _shake ?? const AlwaysStoppedAnimation(0)]),
                        builder: (_, _) => CustomPaint(
                          painter: StarBoardPainter(
                            board: g.board,
                            holesState: g.holes,
                            players: g.players,
                            selected: _selected,
                            dests: _dests,
                            hint: _hint,
                            animPath: _animPath,
                            animT: _anim?.value ?? 0,
                            animHidden: _animHidden,
                            shakeHole: _shakeHole,
                            shakeT: _shake?.value ?? 0,
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
                      g.canUndo && g.current.isHuman && !_busy
                          ? _undo
                          : null),
                  _dockDisc(Icons.lightbulb_outline, 'Hint',
                      g.current.isHuman && !_busy ? _showHint : null),
                  LacquerButton(
                    text: 'Menu',
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    onPressed: () => _pause(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _discButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Imperial.cinnabar, Imperial.cinnabarDeep],
          ),
          border: Border.all(color: Imperial.gold, width: 1.4),
          boxShadow: const [
            BoxShadow(
                color: Color(0x88000000),
                offset: Offset(0, 3),
                blurRadius: 6),
          ],
        ),
        child: Icon(icon, color: Imperial.ivory, size: 22),
      ),
    );
  }

  Widget _dockDisc(IconData icon, String label, VoidCallback? onTap) {
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
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.4),
                  radius: 1.2,
                  colors: [Colors.white, Imperial.ivoryShade],
                ),
                border: Border.all(
                    color: enabled
                        ? Imperial.gold
                        : Imperial.goldOxidized.withValues(alpha: 0.5),
                    width: 1.6),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x99000000),
                      offset: Offset(0, 4),
                      blurRadius: 8),
                ],
              ),
              child: Icon(icon,
                  color: Imperial.cinnabarDeep, size: 26),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: Imperial.label(9,
                  color: Imperial.gold.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

// =====================================================================
// The star board painter — cinnabar lacquer, gold inlay, concave dimples,
// glossy qinghua porcelain marbles with real weight in their motion.
// =====================================================================

class StarBoardPainter extends CustomPainter {
  final Board board;
  final List<int> holesState;
  final List<Competitor> players;
  final int selected;
  final Set<int> dests;
  final Move? hint;
  final List<int> animPath;
  final double animT;
  final int animHidden;
  final int shakeHole;
  final double shakeT;

  StarBoardPainter({
    required this.board,
    required this.holesState,
    required this.players,
    required this.selected,
    required this.dests,
    required this.hint,
    required this.animPath,
    required this.animT,
    required this.animHidden,
    required this.shakeHole,
    required this.shakeT,
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
    final s = _scale(size);
    final r = s * 0.40;

    // Lacquer tray behind the star.
    final trayRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(22));
    canvas.drawRRect(
        trayRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A1414), Color(0xFF220C0C)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawRRect(
        trayRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Imperial.goldOxidized.withValues(alpha: 0.9));

    // Star plate.
    final outline = _starOutline(size);
    final starPath = Path()..addPolygon(outline, true);
    canvas.drawPath(
        starPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Imperial.cinnabar, Imperial.cinnabarDeep],
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

    // Gold inlay grid lines between neighbors.
    final inlay = Paint()
      ..color = Imperial.gold.withValues(alpha: 0.30)
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
      final wash = Imperial.marbleBase[players[pi].seat]
          .withValues(alpha: 0.14);
      for (final h in board.armHoles(players[pi].destArm)) {
        canvas.drawCircle(
            _pos(board.holes[h], size), r * 1.25, Paint()..color = wash);
      }
    }

    // Dimples: concave wells with gold rim crescent + qinghua hint.
    for (final h in board.holes) {
      _paintDimple(canvas, _pos(h, size), r);
    }
    canvas.restore();
    // Star edge: gold stroke.
    canvas.drawPath(
        starPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = Imperial.gold.withValues(alpha: 0.85));

    // Destination rings: thin antique-gold inlay rings (never neon dots).
    for (final d in dests) {
      final p = _pos(board.holes[d], size);
      canvas.drawCircle(
          p,
          r * 0.62,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = Imperial.goldBright);
      canvas.drawCircle(
          p,
          r * 0.62,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = Imperial.gold.withValues(alpha: 0.25));
    }

    // Hint path.
    if (hint != null) {
      final pulse = 0.5 + 0.5 * sin(DateTime.now().millisecondsSinceEpoch / 300);
      for (final h in hint!.path) {
        canvas.drawCircle(
            _pos(board.holes[h], size),
            r * (0.30 + 0.08 * pulse),
            Paint()..color = Imperial.goldBright.withValues(alpha: 0.8));
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
        // Gold inlay ring under the lifted marble.
        canvas.drawCircle(
            p,
            r * 1.28,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = Imperial.goldBright);
      }
      if (h.idx == shakeHole && shakeT > 0 && shakeT < 1) {
        p += Offset(sin(shakeT * pi * 5) * s * 0.10 * (1 - shakeT), 0);
      }
      _paintMarble(canvas, p, r * scale,
          Imperial.marbleBase[players[pi].seat], lift);
    }

    // Flying marble along the animation path.
    if (animPath.length >= 2 && animT > 0) {
      final pos = _animPos(size, s);
      if (pos != null) {
        _paintMarble(canvas, pos.offset, r * (1 + 0.10 * pos.elev),
            Imperial.marbleBase[players[pos.pi].seat], pos.elev,
            squash: pos.squash);
      }
    }
  }

  void _paintDimple(Canvas canvas, Offset p, double r) {
    // Contact occlusion under the well.
    canvas.drawCircle(
        p + Offset(r * 0.12, r * 0.18),
        r * 0.78,
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    // Concave well: dark inset.
    canvas.drawCircle(
        p,
        r * 0.72,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.35, 0.45),
            radius: 1.1,
            colors: [
              const Color(0xFF1A0808),
              const Color(0xFF3D1212),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: r * 0.72)));
    // Inset top-left shadow + bottom-right gold rim crescent.
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
          ..color = Imperial.gold.withValues(alpha: 0.55));
    // Faint cobalt floral line drawing (20% opacity).
    final floral = Imperial.cobalt.withValues(alpha: 0.20);
    canvas.drawCircle(
        p,
        r * 0.20,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = floral);
    for (int i = 0; i < 4; i++) {
      final a = i * pi / 2 + pi / 4;
      canvas.drawCircle(
          p + Offset(cos(a) * r * 0.34, sin(a) * r * 0.34),
          r * 0.07,
          Paint()..color = floral);
    }
  }

  void _paintMarble(
      Canvas canvas, Offset p, double r, Color base, double lift,
      {double squash = 0}) {
    // Soft contact shadow, growing with lift.
    canvas.drawOval(
        Rect.fromCenter(
            center: p + Offset(r * 0.25 + lift * r * 0.5, r * (0.75 + lift * 0.9)),
            width: r * (1.7 - lift * 0.4),
            height: r * (0.62 - lift * 0.14)),
        Paint()..color = Colors.black.withValues(alpha: 0.55 - lift * 0.15));
    final c = p - Offset(0, lift * r * 1.1);
    final sy = squash > 0 ? 1 - squash * 0.16 : 1.0;
    final sx = squash > 0 ? 1 + squash * 0.12 : 1.0;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(sx, sy);
    final dark = Imperial.marbleDark(base);
    final light = Imperial.marbleLight(base);
    canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.42, -0.48),
            radius: 1.25,
            colors: [light, base, dark],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)));
    // Hand-painted qinghua floral motif.
    final motif = Imperial.motifOn(base).withValues(alpha: 0.8);
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5 - pi / 2;
      canvas.drawCircle(
          Offset(cos(a) * r * 0.36, sin(a) * r * 0.36),
          r * 0.13,
          Paint()..color = motif);
    }
    canvas.drawCircle(Offset.zero, r * 0.10, Paint()..color = motif);
    // Crescent specular highlight, top-left (warm key light).
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(-r * 0.34, -r * 0.40),
            width: r * 0.52,
            height: r * 0.32),
        Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(r * 0.30, r * 0.42),
            width: r * 0.40,
            height: r * 0.22),
        Paint()..color = Colors.white.withValues(alpha: 0.12));
    canvas.restore();
  }

  _AnimPos? _animPos(Size size, double s) {
    if (animPath.length < 2) return null;
    final segs = animPath.length - 1;
    final total = animT * segs;
    var seg = total.floor().clamp(0, segs - 1);
    var lt = (total - seg).clamp(0.0, 1.0);
    // Last 12% of each hop is the landing squash.
    var squash = 0.0;
    if (lt > 0.88) squash = (lt - 0.88) / 0.12;
    final a = _pos(board.holes[animPath[seg]], size);
    final b = _pos(board.holes[animPath[seg + 1]], size);
    final isHop = (b - a).distance > s * 1.3;
    final peak = (isHop ? s * 0.55 : s * 0.28) * sin(pi * lt.clamp(0.0, 1.0));
    final mid = (a + b) / 2 - Offset(0, peak * 2);
    final q0 = a + (mid - a) * lt;
    final q1 = mid + (b - mid) * lt;
    final pos = q0 + (q1 - q0) * lt;
    final elev = sin(pi * lt.clamp(0.0, 1.0));
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
