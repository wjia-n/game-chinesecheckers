import 'dart:math';
import 'board.dart';
import 'game.dart';

/// AI strategist (RULES.md §11).
///
/// Evaluation: for each candidate move, score = forward progress made +
/// bonus per marble already home-locked. Search depth by difficulty:
/// Porcelain = 1-ply greedy, Lacquer = 2-ply, Imperial = 3-ply with
/// hop-chain lookahead. Hop chains are enumerated fully — never truncated.
class Ai {
  final Random _rnd;

  Ai({int? seed}) : _rnd = Random(seed);

  /// Distance from [holeIdx] to the nearest hole of player [pi]'s
  /// destination triangle, in hex steps.
  double _distToDest(Board b, int holeIdx, int pi, Set<int> destHoles,
      Map<int, double> cache) {
    return cache.putIfAbsent(holeIdx, () {
      final h = b.holes[holeIdx];
      // Axial coords from offset (odd-r).
      final q = h.x;
      var best = 1e9;
      for (final d in destHoles) {
        final dh = b.holes[d];
        final dq = q - dh.x;
        final dr = (h.y - dh.y) / Board.dy;
        final dist = (dq.abs() + dr.abs() + (dq + dr).abs()) / 2.0;
        if (dist < best) best = dist;
      }
      return best;
    });
  }

  /// Static evaluation of the position from player [pi]'s perspective.
  double evaluate(GameState g, int pi) {
    final destHoles = g.board.armHoles(g.players[pi].destArm).toSet();
    final cache = <int, double>{};
    var score = 0.0;
    var home = 0;
    for (final h in g.board.holes) {
      if (g.holes[h.idx] != pi) continue;
      final d = _distToDest(g.board, h.idx, pi, destHoles, cache);
      score -= d;
      if (g.inDest(h.idx, pi)) home++;
    }
    score += home * 0.6; // home-locked marbles are banked progress
    // Endgame: with >= 7 home, the farthest stragglers matter most.
    if (home >= 7) score += home * 0.4;
    return score;
  }

  /// Cheap static score used for sorting/pruning candidates — no cloning.
  /// Full evaluation runs only on the pruned shortlist.
  double _quickScore(GameState g, int pi, Move m) {
    final seat = g.players[pi].seat;
    var s =
        g.board.progressOf(m.to, seat) - g.board.progressOf(m.from, seat);
    s += m.hopCount * 0.35;
    if (!g.inDest(m.from, pi) && g.inDest(m.to, pi)) s += 2.0;
    return s;
  }

  double _scoreMove(GameState g, int pi, Move m) {
    // Apply on a scratch copy for exact evaluation.
    final scratch = _cloneFor(g);
    scratch.commitMove(m);
    var score = evaluate(scratch, pi);
    // Prefer the longest productive hop chain; chains ending home win big.
    score += m.hopCount * 0.35;
    if (!g.inDest(m.from, pi) && g.inDest(m.to, pi)) score += 2.0;
    // Avoid stopping one step short of the destination.
    final destHoles = g.board.armHoles(g.players[pi].destArm).toSet();
    final cache = <int, double>{};
    if (!g.inDest(m.to, pi) &&
        _distToDest(g.board, m.to, pi, destHoles, cache) < 1.5) {
      score -= 0.8;
    }
    // Defense: don't open a lane — penalize landings crowded by opponents.
    var adjOpp = 0;
    for (final nb in g.board.neighbors[m.to]) {
      final occ = scratch.holes[nb];
      if (occ != -1 && occ != pi) adjOpp++;
    }
    if (!g.inDest(m.to, pi)) score -= adjOpp * 0.15;
    return score;
  }

  GameState _cloneFor(GameState g) => g.cloneForSearch();

  /// Best reply value for the player after [pi] in turn order.
  double _replyValue(GameState g, int pi, Move m, int breadth) {
    final scratch = _cloneFor(g);
    scratch.commitMove(m);
    if (scratch.status != GameStatus.playing) {
      // Moving into an immediate win is priceless; losing on the reply is dire.
      return scratch.winnerIndex == pi ? 1e6 : -1e6;
    }
    final opp = scratch.turnIndex;
    final replies = scratch.legalMoves(opp);
    if (replies.isEmpty) return evaluate(scratch, pi);
    // Cheap sort for pruning; full evaluation only on the shortlist.
    replies.sort((a, b) =>
        _quickScore(scratch, opp, b).compareTo(_quickScore(scratch, opp, a)));
    // Opponent maximizes their own score = minimizes ours.
    var worst = 1e9;
    for (final r in replies.take(breadth)) {
      final s2 = _cloneFor(scratch);
      s2.commitMove(r);
      final v = evaluate(s2, pi);
      if (v < worst) worst = v;
    }
    return worst;
  }

  /// Choose a move for player [pi] at [difficulty]. Runs synchronously but is
  /// cheap enough to call from a Future; breadth caps keep 3-ply fast.
  Move chooseMove(GameState g, int pi, Difficulty difficulty) {
    final moves = g.legalMoves(pi);
    if (moves.isEmpty) {
      throw StateError('AI has no legal move (should have been skipped)');
    }
    if (moves.length == 1) return moves.first;

    double value(Move m) {
      final base = _scoreMove(g, pi, m);
      return switch (difficulty) {
        Difficulty.porcelain => base,
        Difficulty.lacquer => base * 0.4 + _replyValue(g, pi, m, 5) * 0.6,
        Difficulty.imperial => base * 0.25 +
            _replyValueImperial(g, pi, m),
      };
    }

    // Prune to a shortlist with the cheap score first: full (expensive)
    // evaluation runs only on plausible candidates.
    final shortlistN = switch (difficulty) {
      Difficulty.porcelain => 12,
      Difficulty.lacquer => 10,
      Difficulty.imperial => 8,
    };
    final shortlist = [...moves]
      ..sort((a, b) =>
          _quickScore(g, pi, b).compareTo(_quickScore(g, pi, a)));
    final candidates = shortlist.take(shortlistN).toList();

    final pairs = <({Move m, double v})>[
      for (final m in candidates) (m: m, v: value(m))
    ]..sort((a, b) => b.v.compareTo(a.v));

    final topN = switch (difficulty) {
      Difficulty.porcelain => 5,
      Difficulty.lacquer => 3,
      Difficulty.imperial => 1,
    };
    final pool = pairs.take(topN).toList();
    final pick = pool[_rnd.nextInt(pool.length)];
    return pick.m;
  }

  double _replyValueImperial(GameState g, int pi, Move m) {
    // 3-ply: own move, best opponent reply, own best counter (pruned).
    final s1 = _cloneFor(g);
    s1.commitMove(m);
    if (s1.status != GameStatus.playing) {
      return s1.winnerIndex == pi ? 1e6 : -1e6;
    }
    final opp = s1.turnIndex;
    final replies = s1.legalMoves(opp)
      ..sort((a, b) =>
          _quickScore(s1, opp, b).compareTo(_quickScore(s1, opp, a)));
    var worst = 1e9;
    for (final r in replies.take(4)) {
      final s2 = _cloneFor(s1);
      s2.commitMove(r);
      if (s2.status != GameStatus.playing) {
        final v = s2.winnerIndex == pi ? 1e6 : -1e6;
        if (v < worst) worst = v;
        continue;
      }
      // Our counter: best of a pruned candidate set (seats are unique).
      final mine = _ownIndex(s2, g.players[pi].seat);
      final myMoves = s2.legalMoves(mine)
        ..sort((a, b) =>
            _quickScore(s2, mine, b).compareTo(_quickScore(s2, mine, a)));
      var bestCounter = -1e9;
      for (final c in myMoves.take(4)) {
        final s3 = _cloneFor(s2);
        s3.commitMove(c);
        final v = evaluate(s3, pi);
        if (v > bestCounter) bestCounter = v;
      }
      if (bestCounter < worst) worst = bestCounter;
    }
    return worst * 0.75;
  }

  int _ownIndex(GameState s2, int seat) {
    for (int i = 0; i < s2.players.length; i++) {
      if (s2.players[i].seat == seat) return i;
    }
    return 0;
  }
}
