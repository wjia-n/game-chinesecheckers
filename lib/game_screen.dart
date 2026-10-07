import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Chinese Checkers — hop your marbles across the star.
class ChineseCheckersScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const ChineseCheckersScreen({super.key, required this.players, required this.callbacks});

  @override
  State<ChineseCheckersScreen> createState() => _ChineseCheckersScreenState();
}

class _Hole {
  final int row, col, idx;
  final double x, y; // in spacing units
  _Hole(this.row, this.col, this.idx, this.x, this.y);
}

class _ChineseCheckersScreenState extends State<ChineseCheckersScreen> {
  static const _rows = [1, 2, 3, 4, 13, 12, 11, 10, 9, 10, 11, 12, 13, 4, 3, 2, 1];
  static const _dy = 0.87;

  late List<_Hole> holes;
  late List<List<int>> neighbors;
  late List<int> board; // -1 empty, else player index
  int turn = 0;
  int selected = -1;
  List<int> dests = [];
  bool over = false;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    _buildBoard();
    _reset();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBot());
  }

  void _buildBoard() {
    holes = [];
    var idx = 0;
    for (int r = 0; r < _rows.length; r++) {
      for (int c = 0; c < _rows[r]; c++) {
        holes.add(_Hole(r, c, idx++, c - (_rows[r] - 1) / 2, (r - 8) * _dy));
      }
    }
    neighbors = List.generate(holes.length, (_) => []);
    for (int i = 0; i < holes.length; i++) {
      for (int j = 0; j < holes.length; j++) {
        if (i == j) continue;
        final dx = holes[i].x - holes[j].x;
        final dy = holes[i].y - holes[j].y;
        final d = sqrt(dx * dx + dy * dy);
        if (d > 0.9 && d < 1.15) neighbors[i].add(j);
      }
    }
  }

  void _reset() {
    board = List.filled(holes.length, -1);
    for (final h in holes) {
      if (h.row <= 3) board[h.idx] = 0;
      if (h.row >= 13) board[h.idx] = 1;
    }
    turn = 0;
    selected = -1;
    dests = [];
    over = false;
    widget.callbacks.setActivePlayer(0);
  }

  bool _inGoalHome(int idx, int p) {
    final r = holes[idx].row;
    return p == 0 ? r >= 13 : r <= 3;
  }

  /// All legal destinations from idx: single steps + full hop chains.
  List<int> _destinations(int idx) {
    final out = <int>{};
    for (final nb in neighbors[idx]) {
      if (board[nb] == -1) {
        out.add(nb);
      } else {
        final lx = 2 * holes[nb].x - holes[idx].x;
        final ly = 2 * holes[nb].y - holes[idx].y;
        for (final h in holes) {
          if (board[h.idx] != -1) continue;
          final dx = h.x - lx, dy = h.y - ly;
          if (dx * dx + dy * dy < 0.09) {
            if (out.add(h.idx)) {
              out.addAll(_hopChain(h.idx, out));
            }
          }
        }
      }
    }
    return out.toList();
  }

  Set<int> _hopChain(int from, Set<int> seen) {
    final found = <int>{};
    for (final nb in neighbors[from]) {
      if (board[nb] == -1) continue;
      final lx = 2 * holes[nb].x - holes[from].x;
      final ly = 2 * holes[nb].y - holes[from].y;
      for (final h in holes) {
        if (board[h.idx] != -1 || seen.contains(h.idx) || found.contains(h.idx)) continue;
        final dx = h.x - lx, dy = h.y - ly;
        if (dx * dx + dy * dy < 0.09) {
          found.add(h.idx);
          found.addAll(_hopChain(h.idx, {...seen, ...found}));
        }
      }
    }
    return found;
  }

  void _tapHole(int idx) {
    if (over || widget.players[turn].isBot) return;
    if (selected != -1 && dests.contains(idx)) {
      _move(selected, idx);
      return;
    }
    if (board[idx] == turn) {
      setState(() {
        if (selected == idx) {
          selected = -1;
          dests = [];
        } else {
          selected = idx;
          dests = _destinations(idx);
        }
      });
      Sfx.tap();
    } else {
      setState(() {
        selected = -1;
        dests = [];
      });
    }
  }

  void _move(int from, int to) {
    final wasHop = !neighbors[from].contains(to);
    setState(() {
      board[from] = -1;
      board[to] = turn;
      selected = -1;
      dests = [];
    });
    if (wasHop) {
      Sfx.move();
    } else {
      Sfx.tap();
    }
    if (_countInGoal(turn) == 10) {
      _endGame(turn);
      return;
    }
    setState(() => turn = 1 - turn);
    widget.callbacks.setActivePlayer(turn);
    _maybeBot();
  }

  int _countInGoal(int p) {
    var n = 0;
    for (final h in holes) {
      if (board[h.idx] == p && _inGoalHome(h.idx, p)) n++;
    }
    return n;
  }

  void _maybeBot() {
    if (over || !widget.players[turn].isBot) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || over || !widget.players[turn].isBot) return;
      final m = _botMove();
      _move(m[0], m[1]);
    });
  }

  List<int> _botMove() {
    final p = turn;
    final goalC = _goalCenter(p);
    var best = [0, 0];
    var bestScore = -1e9;
    var found = false;
    for (final h in holes) {
      if (board[h.idx] != p) continue;
      for (final d in _destinations(h.idx)) {
        final dh = holes[d];
        final progress = _dist(h.x, h.y, goalC) - _dist(dh.x, dh.y, goalC);
        var score = progress * 3;
        if (_inGoalHome(d, p) && !_inGoalHome(h.idx, p)) score += 6;
        if (_inGoalHome(h.idx, p) && _inGoalHome(d, p)) score += 1;
        score += _rnd.nextDouble() * 1.2;
        if (!found || score > bestScore) {
          found = true;
          bestScore = score;
          best = [h.idx, d];
        }
      }
    }
    return best;
  }

  double _dist(double x, double y, Offset c) {
    final dx = x - c.dx, dy = y - c.dy;
    return sqrt(dx * dx + dy * dy);
  }

  Offset _goalCenter(int p) {
    var sx = 0.0, sy = 0.0, n = 0;
    for (final h in holes) {
      if (_inGoalHome(h.idx, p)) {
        sx += h.x;
        sy += h.y;
        n++;
      }
    }
    return Offset(sx / n, sy / n);
  }

  void _endGame(int winnerIdx) {
    setState(() => over = true);
    final w = widget.players[winnerIdx];
    w.score += 1;
    widget.callbacks.refreshHud();
    Sfx.win();
    widget.callbacks.finish(
      winner: w,
      headline: '${w.name} conquered the star! 🔮🎉',
      subline: 'All 10 marbles home. Hop-tastic victory!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final current = widget.players[turn];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (!over)
            TurnBanner(
              player: current,
              action: current.isBot
                  ? ' is hopping… 🤖'
                  : (selected == -1 ? ' — tap a marble! 👆' : ' — tap a glowing hole! ✨'),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.92,
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: t.radius,
                    boxShadow: [
                      BoxShadow(
                          color: t.primary.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Builder(
                    builder: (ctx) => GestureDetector(
                      onTapUp: (d) {
                        final box = ctx.findRenderObject() as RenderBox;
                        final idx = _StarPainter.holeAt(d.localPosition, box.size, holes);
                        if (idx != null) _tapHole(idx);
                      },
                      child: CustomPaint(
                        painter: _StarPainter(
                          holes: holes,
                          board: board,
                          players: widget.players,
                          turn: turn,
                          selected: selected,
                          dests: dests,
                          hole: t.muted.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Chain your hops — one turn can cross the whole star! 🌟',
              style: TextStyle(color: t.muted, fontSize: 13)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final List<_Hole> holes;
  final List<int> board;
  final List<Player> players;
  final int turn;
  final int selected;
  final List<int> dests;
  final Color hole;

  _StarPainter({
    required this.holes,
    required this.board,
    required this.players,
    required this.turn,
    required this.selected,
    required this.dests,
    required this.hole,
  });

  static Offset _pos(_Hole h, Size size) {
    const pad = 20.0;
    final s = min((size.width - pad * 2) / 13.5, (size.height - pad * 2) / 14.6);
    final ox = size.width / 2;
    final oy = size.height / 2;
    return Offset(ox + h.x * s, oy + h.y * s + s * 0.4);
  }

  static double _scale(Size size) {
    const pad = 20.0;
    return min((size.width - pad * 2) / 13.5, (size.height - pad * 2) / 14.6);
  }

  static int? holeAt(Offset p, Size size, List<_Hole> holes) {
    final s = _scale(size);
    var bestD = 1e9;
    int? best;
    for (final h in holes) {
      final d = (p - _pos(h, size)).distance;
      if (d < bestD) {
        bestD = d;
        best = h.idx;
      }
    }
    return bestD <= s * 0.48 ? best : null;
  }

  bool _isGoal(_Hole h, int p) => p == 0 ? h.row >= 13 : h.row <= 3;

  @override
  void paint(Canvas canvas, Size size) {
    final s = _scale(size);
    // goal-home rings
    for (final h in holes) {
      final p = _pos(h, size);
      for (int pl = 0; pl < 2; pl++) {
        if (_isGoal(h, pl)) {
          canvas.drawCircle(
              p,
              s * 0.42,
              Paint()
                ..color = players[pl].color.withValues(alpha: 0.35)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
        }
      }
    }
    for (final h in holes) {
      final p = _pos(h, size);
      final v = board[h.idx];
      if (v == -1) {
        canvas.drawCircle(p, s * 0.30, Paint()..color = hole);
      } else {
        canvas.drawCircle(p, s * 0.40, Paint()..color = players[v].color);
        canvas.drawCircle(
            p,
            s * 0.40,
            Paint()
              ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
      if (h.idx == selected) {
        canvas.drawCircle(
            p,
            s * 0.52,
            Paint()
              ..color = players[board[h.idx]].color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      }
      if (dests.contains(h.idx)) {
        canvas.drawCircle(p, s * 0.18, Paint()..color = players[turn].color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => true;
}
