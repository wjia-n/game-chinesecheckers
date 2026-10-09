import 'dart:convert';
import 'board.dart';

/// AI difficulty tiers (RULES.md §11).
enum Difficulty { porcelain, lacquer, imperial }

String difficultyName(Difficulty d) => switch (d) {
      Difficulty.porcelain => 'Porcelain',
      Difficulty.lacquer => 'Lacquer',
      Difficulty.imperial => 'Imperial',
    };

/// One competitor in the game. A seat always owns exactly one arm of marbles;
/// in the symmetric 2-player variant one human may own two seats.
class Competitor {
  final int seat; // 0..5, also the start arm
  final bool isHuman;
  final Difficulty difficulty;
  final int owner; // human index that controls this seat (symmetric variant)

  const Competitor({
    required this.seat,
    required this.isHuman,
    this.difficulty = Difficulty.lacquer,
    this.owner = 0,
  });

  int get destArm => (seat + 3) % 6;

  Competitor copy() => Competitor(
        seat: seat,
        isHuman: isHuman,
        difficulty: difficulty,
        owner: owner,
      );

  Map<String, dynamic> toJson() => {
        'seat': seat,
        'isHuman': isHuman,
        'difficulty': difficulty.index,
        'owner': owner,
      };

  static Competitor fromJson(Map<String, dynamic> j) => Competitor(
        seat: j['seat'] as int,
        isHuman: j['isHuman'] as bool,
        difficulty: Difficulty.values[j['difficulty'] as int],
        owner: (j['owner'] as int?) ?? 0,
      );
}

/// A legal move: a path of hole indices. Length 2 + adjacent = step;
/// otherwise a hop chain (every consecutive pair is a hop).
class Move {
  final List<int> path;
  const Move(this.path);

  int get from => path.first;
  int get to => path.last;
  bool get isStep => path.length == 2;
  int get hopCount => path.length - 1;

  Map<String, dynamic> toJson() => {'path': path};
  static Move fromJson(Map<String, dynamic> j) =>
      Move(List<int>.from(j['path'] as List));
}

enum GameStatus { playing, won, draw }

/// Seat -> arm mapping per player count (RULES.md §2).
List<int> seatsForPlayerCount(int n) => switch (n) {
      2 => [0, 3],
      3 => [0, 2, 4],
      4 => [0, 1, 3, 4],
      5 => [0, 1, 2, 3, 4],
      6 => [0, 1, 2, 3, 4, 5],
      _ => [0, 3],
    };

class GameState {
  final Board board;
  final List<Competitor> players;
  List<int> holes; // hole idx -> player index in [players], or -1
  int turnIndex;
  List<int> moveCounts;
  int totalTurns = 0;
  int turnsSinceDestEntry = 0;
  int consecutiveSkips = 0;
  GameStatus status = GameStatus.playing;
  int winnerIndex = -1;
  String drawReason = '';
  final List<int> finishOrder = [];
  final List<_Snapshot> _history = [];
  final bool forwardProgress;

  GameState({
    required this.board,
    required this.players,
    this.forwardProgress = true,
  })  : holes = List.filled(board.holes.length, -1),
        turnIndex = 0,
        moveCounts = List.filled(players.length, 0) {
    _setup();
  }

  GameState._empty(this.board, this.players, this.forwardProgress)
      : holes = [],
        turnIndex = 0,
        moveCounts = [];

  void _setup() {
    for (int pi = 0; pi < players.length; pi++) {
      for (final h in board.armHoles(players[pi].seat)) {
        holes[h] = pi;
      }
    }
  }

  Competitor get current => players[turnIndex];

  Set<int> _destHoles(int pi) =>
      board.armHoles(players[pi].destArm).toSet();

  bool inDest(int holeIdx, int pi) =>
      board.armOf[holeIdx] == players[pi].destArm;

  int countInDest(int pi) {
    var n = 0;
    for (final h in board.armHoles(players[pi].destArm)) {
      if (holes[h] == pi) n++;
    }
    return n;
  }

  // ---------------- move generation ----------------

  /// Every legal move for player [pi]. Enumerates full hop chains —
  /// never truncated mid-chain (RULES.md §11).
  List<Move> legalMoves(int pi) {
    final moves = <Move>[];
    final dest = _destHoles(pi);
    for (final h in board.holes) {
      if (holes[h.idx] != pi) continue;
      // Steps.
      for (final nb in board.neighbors[h.idx]) {
        if (holes[nb] != -1) continue;
        if (!_homeLockOk([h.idx, nb], pi, dest)) continue;
        moves.add(Move([h.idx, nb]));
      }
      // Hop chains (every prefix of length >= 1 hop is a legal move).
      _extendChain([h.idx], pi, dest, moves);
    }
    if (forwardProgress) return _applyForwardProgress(moves, pi);
    return moves;
  }

  void _extendChain(
      List<int> path, int pi, Set<int> dest, List<Move> out) {
    // Holes the marble has already vacated this turn are EMPTY for the rest
    // of the chain (the marble is conceptually at path.last). Without this,
    // the generator could "hop over" its own trail — an illegal move that
    // isLegalMove would later reject (RULES.md §5: hopping over an empty
    // hole is illegal).
    final trail = path.toSet();
    final from = path.last;
    for (final over in board.neighbors[from]) {
      if (trail.contains(over)) continue; // vacated: empty, cannot hop over
      if (holes[over] == -1) continue;
      final land = board.hopLanding(from, over);
      if (land == -1 || trail.contains(land)) continue;
      // Landing must be truly empty: trail holes are empty, board holes
      // must be vacant.
      if (holes[land] != -1) continue;
      final next = [...path, land];
      if (!_homeLockOk(next, pi, dest)) continue;
      out.add(Move(next));
      _extendChain(next, pi, dest, out);
    }
  }

  /// Home-lock (RULES.md §7): once a marble enters its destination it may
  /// never leave it again — not even mid-chain.
  bool _homeLockOk(List<int> path, int pi, Set<int> dest) {
    var entered = dest.contains(path.first);
    for (final h in path.skip(1)) {
      if (dest.contains(h)) {
        entered = true;
      } else if (entered) {
        return false;
      }
    }
    return true;
  }

  /// Forward-progress house rule (RULES.md §7, default ON): a marble may not
  /// end its turn farther from its destination than it started, unless no
  /// forward-progress move exists for the player.
  List<Move> _applyForwardProgress(List<Move> moves, int pi) {
    final seat = players[pi].seat;
    bool isForward(Move m) =>
        board.progressOf(m.to, seat) >= board.progressOf(m.from, seat) - 1e-9;
    final fwd = moves.where(isForward).toList();
    return fwd.isEmpty ? moves : fwd;
  }

  /// All legal destinations for the marble at [holeIdx] (steps + full
  /// hop-chain reachability) — used for move highlight (RULES.md §7).
  Set<int> destinationsFor(int holeIdx, int pi) {
    final moves =
        legalMoves(pi).where((m) => m.from == holeIdx).toList();
    return {for (final m in moves) m.to};
  }

  /// A legal path from [from] to [to] for player [pi], preferring fewer hops.
  Move? findPath(int from, int to, int pi) {
    Move? best;
    for (final m in legalMoves(pi)) {
      if (m.from == from && m.to == to) {
        if (best == null || m.hopCount < best.hopCount) best = m;
      }
    }
    return best;
  }

  /// Validate an arbitrary path (used by tests and defensive checks).
  bool isLegalMove(List<int> path, int pi) {
    if (path.length < 2) return false;
    if (holes[path.first] != pi) return false;
    if (path.toSet().length != path.length) return false;
    final dest = _destHoles(pi);
    if (!_homeLockOk(path, pi, dest)) return false;
    final occ = List<int>.from(holes)..[path.first] = -1;
    for (int i = 0; i + 1 < path.length; i++) {
      final a = path[i], b = path[i + 1];
      if (occ[b] != -1) return false;
      final adjacent = board.neighbors[a].contains(b);
      if (adjacent) {
        if (path.length != 2) return false; // no step+hop mixes
      } else {
        // Must be a genuine hop over an occupied adjacent hole.
        var ok = false;
        for (final over in board.neighbors[a]) {
          if (occ[over] != -1 && board.hopLanding(a, over) == b) {
            ok = true;
            break;
          }
        }
        if (!ok) return false;
      }
      occ[b] = pi;
    }
    if (forwardProgress) {
      final seat = players[pi].seat;
      if (board.progressOf(path.last, seat) <
          board.progressOf(path.first, seat) - 1e-9) {
        // Allowed only if no forward move exists at all.
        if (legalMoves(pi).isNotEmpty) {
          final seatArm = players[pi].seat;
          final anyFwd = legalMoves(pi).any((m) =>
              board.progressOf(m.to, seatArm) >=
              board.progressOf(m.from, seatArm) - 1e-9);
          if (anyFwd) return false;
        }
      }
    }
    return true;
  }

  // ---------------- turn execution ----------------

  /// Commits [move] for the current player. Returns false if illegal.
  bool commitMove(Move move) {
    final pi = turnIndex;
    if (status != GameStatus.playing) return false;
    if (!isLegalMove(move.path, pi)) return false;
    _pushHistory();

    var enteredDest = false;
    for (final h in move.path.skip(1)) {
      if (inDest(h, pi) && !inDest(move.from, pi)) enteredDest = true;
    }
    holes[move.from] = -1;
    holes[move.to] = pi;
    moveCounts[pi]++;
    totalTurns++;
    turnsSinceDestEntry = enteredDest ? 0 : turnsSinceDestEntry + 1;
    consecutiveSkips = 0;

    // Win is evaluated only after the turn is committed (RULES.md §9/§12).
    if (countInDest(pi) == 10) {
      finishOrder.add(pi);
      status = GameStatus.won;
      winnerIndex = pi;
      return true;
    }
    if (_checkDraw()) return true;
    _advance();
    return true;
  }

  void _advance() {
    final n = players.length;
    for (int k = 0; k < n; k++) {
      turnIndex = (turnIndex + 1) % n;
      if (legalMoves(turnIndex).isNotEmpty) {
        consecutiveSkips = 0;
        return;
      }
      // No legal move: auto-skip (RULES.md §3/§12).
      consecutiveSkips++;
      totalTurns++;
      turnsSinceDestEntry++; // a skipped turn enters no destination either
    }
    // Full round with nobody able to move -> draw.
    status = GameStatus.draw;
    drawReason = 'No legal moves remain for any player.';
  }

  bool _checkDraw() {
    if (totalTurns >= 300) {
      status = GameStatus.draw;
      drawReason = 'Move cap reached (300 turns).';
      return true;
    }
    if (turnsSinceDestEntry >= 40 && !_anyLongChain()) {
      status = GameStatus.draw;
      drawReason = 'Deadlock: 40 turns without progress.';
      return true;
    }
    return false;
  }

  bool _anyLongChain() {
    for (int pi = 0; pi < players.length; pi++) {
      for (final m in legalMoves(pi)) {
        if (m.hopCount >= 2) return true;
      }
    }
    return false;
  }

  /// Bots accept a mutual draw when the deadlock is within 10 turns
  /// (RULES.md §10).
  bool botsAcceptDraw() => turnsSinceDestEntry >= 30;

  // ---------------- undo ----------------

  bool get canUndo => _history.isNotEmpty && status == GameStatus.playing;

  void undo() {
    if (!canUndo) return;
    final s = _history.removeLast();
    holes = s.holes;
    turnIndex = s.turnIndex;
    moveCounts = s.moveCounts;
    totalTurns = s.totalTurns;
    turnsSinceDestEntry = s.turnsSinceDestEntry;
    consecutiveSkips = s.consecutiveSkips;
    finishOrder
      ..clear()
      ..addAll(s.finishOrder);
    status = GameStatus.playing;
    winnerIndex = -1;
    drawReason = '';
  }

  void _pushHistory() {
    _history.add(_Snapshot(
      holes: List<int>.from(holes),
      turnIndex: turnIndex,
      moveCounts: List<int>.from(moveCounts),
      totalTurns: totalTurns,
      turnsSinceDestEntry: turnsSinceDestEntry,
      consecutiveSkips: consecutiveSkips,
      finishOrder: List<int>.from(finishOrder),
    ));
    if (_history.length > 50) _history.removeAt(0);
  }

  // ---------------- ranks & scoring ----------------

  /// Ranked player indices: finish order first, then non-finishers by
  /// marbles in destination, then fewest moves, then seat order (RULES §8).
  List<int> ranks() {
    final rest = [
      for (int i = 0; i < players.length; i++)
        if (!finishOrder.contains(i)) i
    ];
    rest.sort((a, b) {
      final da = countInDest(b).compareTo(countInDest(a));
      if (da != 0) return da;
      final mb = moveCounts[a].compareTo(moveCounts[b]);
      if (mb != 0) return mb;
      return players[a].seat.compareTo(players[b].seat);
    });
    return [...finishOrder, ...rest];
  }

  /// Match points per RULES.md §8.
  Map<int, int> matchPoints() {
    const table = [100, 60, 40, 25, 15, 10];
    final pts = <int, int>{};
    final r = ranks();
    for (int i = 0; i < r.length; i++) {
      final pi = r[i];
      pts[pi] = finishOrder.contains(pi)
          ? table[i.clamp(0, table.length - 1)]
          : countInDest(pi) * 5;
    }
    return pts;
  }

  // ---------------- persistence ----------------

  Map<String, dynamic> toJson() => {
        'players': [for (final p in players) p.toJson()],
        'holes': holes,
        'turnIndex': turnIndex,
        'moveCounts': moveCounts,
        'totalTurns': totalTurns,
        'turnsSinceDestEntry': turnsSinceDestEntry,
        'consecutiveSkips': consecutiveSkips,
        'status': status.index,
        'winnerIndex': winnerIndex,
        'drawReason': drawReason,
        'finishOrder': finishOrder,
        'forwardProgress': forwardProgress,
      };

  static GameState fromJson(Map<String, dynamic> j) {
    final board = Board();
    final players = [
      for (final p in (j['players'] as List)) Competitor.fromJson(p)
    ];
    final fp = (j['forwardProgress'] as bool?) ?? true;
    final g = GameState._empty(board, players, fp);
    g.holes = List<int>.from(j['holes'] as List);
    g.turnIndex = j['turnIndex'] as int;
    g.moveCounts = List<int>.from(j['moveCounts'] as List);
    g.totalTurns = (j['totalTurns'] as int?) ?? 0;
    g.turnsSinceDestEntry = (j['turnsSinceDestEntry'] as int?) ?? 0;
    g.consecutiveSkips = (j['consecutiveSkips'] as int?) ?? 0;
    g.status = GameStatus.values[(j['status'] as int?) ?? 0];
    g.winnerIndex = (j['winnerIndex'] as int?) ?? -1;
    g.drawReason = (j['drawReason'] as String?) ?? '';
    g.finishOrder.addAll(List<int>.from((j['finishOrder'] as List?) ?? []));
    return g;
  }

  String encode() => jsonEncode(toJson());
  static GameState decode(String s) =>
      fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Fast structural clone for AI search. The board and competitor list are
  /// immutable and shared; the mutable arrays are copied. History is not
  /// needed for search and starts empty.
  GameState cloneForSearch() {
    final c = GameState._empty(board, players, forwardProgress);
    c.holes = List<int>.from(holes);
    c.turnIndex = turnIndex;
    c.moveCounts = List<int>.from(moveCounts);
    c.totalTurns = totalTurns;
    c.turnsSinceDestEntry = turnsSinceDestEntry;
    c.drawReason = drawReason;
    c.status = status;
    c.winnerIndex = winnerIndex;
    c.consecutiveSkips = consecutiveSkips;
    c.finishOrder.addAll(finishOrder);
    return c;
  }
}

class _Snapshot {
  final List<int> holes;
  final int turnIndex;
  final List<int> moveCounts;
  final int totalTurns;
  final int turnsSinceDestEntry;
  final int consecutiveSkips;
  final List<int> finishOrder;
  const _Snapshot({
    required this.holes,
    required this.turnIndex,
    required this.moveCounts,
    required this.totalTurns,
    required this.turnsSinceDestEntry,
    required this.consecutiveSkips,
    required this.finishOrder,
  });
}

/// Deterministic sanity helper used by the test harness (RULES.md §13.14):
/// every hole must have at most 6 neighbors and the board 121 holes.
bool validateBoardGeometry(Board b) {
  if (b.holes.length != 121) return false;
  for (final n in b.neighbors) {
    if (n.length > 6) return false;
  }
  var total = 0;
  for (int a = 0; a < 6; a++) {
    if (b.armHoles(a).length != 10) return false;
    total += b.armHoles(a).length;
  }
  return total == 60;
}
