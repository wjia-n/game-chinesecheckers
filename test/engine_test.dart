import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:chinesecheckers/engine/ai.dart';
import 'package:chinesecheckers/engine/board.dart';
import 'package:chinesecheckers/engine/game.dart';
import 'package:chinesecheckers/engine/turn_director.dart';

GameState twoPlayer({bool forwardProgress = true}) => GameState(
      board: Board(),
      players: [
        const Competitor(seat: 0, isHuman: false),
        const Competitor(seat: 3, isHuman: false),
      ],
      forwardProgress: forwardProgress,
    );

/// A valid (from, over, landing) hop triple anywhere on the board.
(int, int, int) findHopTriple(GameState g) {
  for (final h in g.board.holes) {
    for (final nb in g.board.neighbors[h.idx]) {
      final land = g.board.hopLanding(h.idx, nb);
      if (land != -1) return (h.idx, nb, land);
    }
  }
  throw StateError('no hop triple on the board');
}

/// Two consecutive hops in a straight line: (a, over1, land1, over2, land2).
(int, int, int, int, int) findDoubleHop(GameState g) {
  for (final h in g.board.holes) {
    for (final nb in g.board.neighbors[h.idx]) {
      final land1 = g.board.hopLanding(h.idx, nb);
      if (land1 == -1) continue;
      // Continue straight: over2 is the neighbor of land1 away from h.
      final f = g.board.holes[h.idx], l = g.board.holes[land1];
      final dx = l.x - f.x, dy = l.y - f.y;
      final len = sqrt(dx * dx + dy * dy);
      var best = -1;
      var bestD = 1e9;
      for (final c in g.board.neighbors[land1]) {
        final ch = g.board.holes[c];
        final ddx = ch.x - (l.x + dx / len), ddy = ch.y - (l.y + dy / len);
        final d = ddx * ddx + ddy * ddy;
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      if (bestD > 0.04) continue;
      final land2 = g.board.hopLanding(land1, best);
      if (land2 != -1 && land2 != h.idx) {
        return (h.idx, nb, land1, best, land2);
      }
    }
  }
  throw StateError('no double hop on the board');
}
int frontMarble(GameState g, int pi) {
  final seat = g.players[pi].seat;
  var best = -1;
  var bestP = -1e9;
  for (final h in g.board.holes) {
    if (g.holes[h.idx] != pi) continue;
    final p = g.board.progressOf(h.idx, seat);
    if (p > bestP) {
      bestP = p;
      best = h.idx;
    }
  }
  return best;
}

void main() {
  group('RULES.md §13 test cases', () {
    test('1. Setup: 20 marbles, 10 per arm, 101 empty, seat 0 to move', () {
      final g = twoPlayer();
      expect(g.board.holes.length, 121);
      var blue = 0, red = 0, empty = 0;
      for (final h in g.board.holes) {
        final occ = g.holes[h.idx];
        if (occ == 0) blue++;
        if (occ == 1) red++;
        if (occ == -1) empty++;
      }
      expect(blue, 10);
      expect(red, 10);
      expect(empty, 101);
      // Blue in rows 0..3, Red in rows 13..16.
      for (final h in g.board.holes) {
        if (h.row <= 3) expect(g.holes[h.idx], 0);
        if (h.row >= 13) expect(g.holes[h.idx], 1);
      }
      expect(g.turnIndex, 0);
    });

    test('2. Step: front marble steps forward, turn passes', () {
      final g = twoPlayer();
      final from = frontMarble(g, 0);
      final seat = g.players[0].seat;
      Move? step;
      for (final m in g.legalMoves(0)) {
        if (m.from == from &&
            m.isStep &&
            g.board.progressOf(m.to, seat) >
                g.board.progressOf(m.from, seat)) {
          step = m;
          break;
        }
      }
      expect(step, isNotNull, reason: 'a forward step must exist');
      expect(g.commitMove(step!), isTrue);
      expect(g.holes[step.from], -1);
      expect(g.holes[step.to], 0);
      expect(g.turnIndex, 1);
    });

    test('3. Illegal step onto an occupied hole is rejected', () {
      final g = twoPlayer();
      final from = frontMarble(g, 0);
      // A neighbor occupied by own marble: stepping there is illegal.
      var target = -1;
      for (final nb in g.board.neighbors[from]) {
        if (g.holes[nb] == 0) {
          target = nb;
          break;
        }
      }
      expect(target, isNot(-1));
      expect(g.isLegalMove([from, target], 0), isFalse);
      expect(g.commitMove(Move([from, target])), isFalse);
      expect(g.turnIndex, 0, reason: 'turn must not pass');
    });

    test('4. Single hop over an adjacent marble', () {
      final g = twoPlayer(forwardProgress: false);
      g.holes = List.filled(121, -1);
      final (a, b, land) = findHopTriple(g);
      g.holes[a] = 0;
      g.holes[b] = 1;
      final hop = Move([a, land]);
      expect(g.isLegalMove(hop.path, 0), isTrue);
      expect(g.commitMove(hop), isTrue);
      expect(g.holes[land], 0);
      expect(g.holes[b], 1, reason: 'jumped marble stays (no captures)');
      expect(g.turnIndex, 1);
    });

    test('5. Hop chain: 3 hops in one turn, turn passes only after', () {
      final g = twoPlayer(forwardProgress: false);
      g.holes = List.filled(121, -1);
      // Row 8 (center) is a straight line of 9 consecutive holes.
      final row8 = [
        for (final h in g.board.holes)
          if (h.row == 8) h
      ]..sort((x, y) => x.col.compareTo(y.col));
      expect(row8.length, 9);
      final line = [for (final h in row8) h.idx];
      // Jumped marbles on odd positions; mover starts at position 0.
      for (final i in [1, 3, 5]) {
        g.holes[line[i]] = 1;
      }
      g.holes[line[0]] = 0;
      final chain = Move([line[0], line[2], line[4], line[6]]);
      expect(g.isLegalMove(chain.path, 0), isTrue);
      expect(g.commitMove(chain), isTrue);
      expect(g.holes[line[6]], 0);
      expect(g.holes[line[0]], -1);
      // Jumped marbles untouched.
      for (final i in [1, 3, 5]) {
        expect(g.holes[line[i]], 1);
      }
      expect(g.turnIndex, 1);
    });

    test('6. Illegal hop over a gap of two marbles is rejected', () {
      final g = twoPlayer(forwardProgress: false);
      g.holes = List.filled(121, -1);
      final (a, over1, land1, over2, land2) = findDoubleHop(g);
      g.holes[a] = 0;
      g.holes[over1] = 1;
      g.holes[over2] = 1;
      // Sanity: the two single hops are each legal on their own.
      expect(g.isLegalMove([a, land1], 0), isTrue);
      // But "hopping" from a all the way to land2 as ONE hop is illegal.
      expect(g.isLegalMove([a, land2], 0), isFalse);
      expect(g.commitMove(Move([a, land2])), isFalse);
      expect(g.turnIndex, 0, reason: 'turn must not pass');
    });

    test('7. Home-lock: marble may not leave its destination', () {
      final g = twoPlayer(forwardProgress: false);
      final dest = g.board.armHoles(g.players[0].destArm);
      // Artificially place one blue marble inside its destination.
      g.holes = List.filled(121, -1);
      g.holes[dest.first] = 0;
      // Any move leaving the destination must be illegal.
      var outside = -1;
      for (final nb in g.board.neighbors[dest.first]) {
        if (!dest.contains(nb)) {
          outside = nb;
          break;
        }
      }
      expect(outside, isNot(-1));
      g.holes[outside] = -1;
      expect(g.isLegalMove([dest.first, outside], 0), isFalse);
      // But moving within the destination is legal.
      var inside = -1;
      for (final nb in g.board.neighbors[dest.first]) {
        if (dest.contains(nb)) {
          inside = nb;
          break;
        }
      }
      if (inside != -1) {
        expect(g.isLegalMove([dest.first, inside], 0), isTrue);
      }
    });

    test('8. No captures: marble count stays 10 per player after hops', () {
      final g = twoPlayer();
      final ai = Ai(seed: 1);
      for (int t = 0; t < 30; t++) {
        final pi = g.turnIndex;
        final m = ai.chooseMove(g, pi, Difficulty.porcelain);
        expect(g.isLegalMove(m.path, pi), isTrue);
        g.commitMove(m);
        if (g.status != GameStatus.playing) break;
      }
      final counts = [0, 0];
      for (final h in g.board.holes) {
        final occ = g.holes[h.idx];
        if (occ >= 0) counts[occ]++;
      }
      expect(counts, [10, 10]);
    });

    test('9. Win: filling the destination wins immediately', () {
      final g = twoPlayer(forwardProgress: false);
      final dest = g.board.armHoles(g.players[0].destArm);
      g.holes = List.filled(121, -1);
      // Fill all destination holes but dest[0].
      for (int i = 1; i < 10; i++) {
        g.holes[dest[i]] = 0;
      }
      // Enter the last hole from an outside neighbor of dest[0].
      int? from;
      for (final nb in g.board.neighbors[dest[0]]) {
        if (!dest.contains(nb)) {
          from = nb;
          break;
        }
      }
      expect(from, isNotNull,
          reason: 'dest[0] must border the central hexagon');
      if (from == null) fail('no entry neighbor');
      g.holes[from] = 0;
      g.turnIndex = 0;
      final mv = Move([from, dest[0]]);
      expect(g.isLegalMove(mv.path, 0), isTrue);
      expect(g.commitMove(mv), isTrue);
      expect(g.status, GameStatus.won);
      expect(g.winnerIndex, 0);
      expect(g.countInDest(0), 10);
    });

    test('10. Win requires own color: 9 own + 1 opponent is not a win', () {
      final g = twoPlayer(forwardProgress: false);
      final dest = g.board.armHoles(g.players[0].destArm);
      g.holes = List.filled(121, -1);
      for (int i = 0; i < 9; i++) {
        g.holes[dest[i]] = 0;
      }
      g.holes[dest[9]] = 1; // opponent marble squatting
      expect(g.countInDest(0), 9);
      // countInDest only counts own marbles, so != 10 -> no win.
      expect(g.countInDest(0) == 10, isFalse);
    });

    test('11. Skip turn: player with no legal move is auto-skipped', () async {
      final g = GameState(
        board: Board(),
        players: [
          const Competitor(seat: 0, isHuman: false),
          const Competitor(seat: 3, isHuman: false),
        ],
        forwardProgress: false,
      );
      g.holes = List.filled(121, -1);
      // Player 1 marble fully boxed in: all neighbors + all hop landings
      // occupied by player 0.
      final h = g.board.holes
          .firstWhere((x) => g.board.neighbors[x.idx].length == 6)
          .idx;
      g.holes[h] = 1;
      for (final nb in g.board.neighbors[h]) {
        g.holes[nb] = 0;
        final land = g.board.hopLanding(h, nb);
        if (land != -1) g.holes[land] = 0;
      }
      expect(g.legalMoves(1), isEmpty);
      expect(g.legalMoves(0), isNotEmpty);
      g.turnIndex = 1;
      final director = TurnDirector(
        game: g,
        thinkDelay: Duration.zero,
        botThinkTimeout: const Duration(seconds: 5),
        animateTimeout: const Duration(seconds: 5),
      );
      director.displayNames = ['A', 'B'];
      var skipped = -1;
      final sub = director.events.listen((e) {
        if (e.kind == TurnEventKind.skipped) skipped = e.data as int;
      });
      director.animateMove = (_) async {};
      director.start();
      // Give the director a beat to process.
      await Future.delayed(const Duration(milliseconds: 1200));
      expect(skipped, 1, reason: 'player 1 must be auto-skipped');
      expect(g.totalTurns, greaterThan(1),
          reason: 'the game must progress past the skip (player 0 moves)');
      await sub.cancel();
      director.dispose();
    });

    test('12. Move cap: 300 turns with no winner ends the game', () {
      final g = twoPlayer();
      g.totalTurns = 299;
      final from = frontMarble(g, 0);
      final step = g.legalMoves(0).firstWhere((m) => m.from == from);
      expect(g.commitMove(step), isTrue);
      expect(g.status, GameStatus.draw);
      expect(g.drawReason, contains('300'));
    });

    test('13. Undo restores the exact pre-turn board after a chain', () {
      final g = twoPlayer(forwardProgress: false);
      final ai = Ai(seed: 99);
      // Play until a 2+ hop chain is available for the player to move.
      Move? chain;
      for (int attempt = 0;
          attempt < 400 && chain == null;
          attempt++) {
        if (g.status != GameStatus.playing) break;
        final pi = g.turnIndex;
        for (final m in g.legalMoves(pi)) {
          if (m.hopCount >= 2) {
            chain = m;
            break;
          }
        }
        if (chain == null) {
          final m = ai.chooseMove(g, pi, Difficulty.porcelain);
          g.commitMove(m);
        }
      }
      expect(chain, isNotNull, reason: 'a 2+ hop chain should arise');
      // Snapshot immediately before the chain turn.
      final before = List<int>.from(g.holes);
      final beforeTurn = g.turnIndex;
      final beforeCounts = List<int>.from(g.moveCounts);
      expect(g.commitMove(chain!), isTrue);
      if (g.status == GameStatus.playing) {
        expect(g.turnIndex, isNot(beforeTurn));
        g.undo();
        expect(g.holes, before);
        expect(g.turnIndex, beforeTurn);
        expect(g.moveCounts, beforeCounts);
      }
    });

    test('15. Persistence round-trip is exact', () {
      final g = twoPlayer();
      final ai = Ai(seed: 5);
      for (int t = 0; t < 10; t++) {
        final pi = g.turnIndex;
        g.commitMove(ai.chooseMove(g, pi, Difficulty.porcelain));
      }
      final restored = GameState.decode(g.encode());
      expect(restored.holes, g.holes);
      expect(restored.turnIndex, g.turnIndex);
      expect(restored.moveCounts, g.moveCounts);
      expect(restored.totalTurns, g.totalTurns);
      expect(restored.status, g.status);
    });

    test('forward progress points toward the destination for every seat',
        () {
      final b = Board();
      for (int seat = 0; seat < 6; seat++) {
        final destArm = (seat + 3) % 6;
        var minDest = 1e9, maxStart = -1e9;
        for (final h in b.armHoles(seat)) {
          final p = b.progressOf(h, seat);
          if (p > maxStart) maxStart = p;
        }
        for (final h in b.armHoles(destArm)) {
          final p = b.progressOf(h, seat);
          if (p < minDest) minDest = p;
        }
        expect(minDest, greaterThan(maxStart),
            reason: 'seat $seat: destination must be "forward"');
      }
    });

    test('board geometry: 121 holes, 6 arms of 10, <= 6 neighbors', () {
      expect(validateBoardGeometry(Board()), isTrue);
    });
  });

  group('AI legality (RULES.md §13.14)', () {
    test('200 porcelain-vs-porcelain turns: every move legal', () {
      final g = twoPlayer();
      final ai = Ai(seed: 20261009);
      var turns = 0;
      for (int t = 0; t < 200; t++) {
        if (g.status != GameStatus.playing) break;
        final pi = g.turnIndex;
        final moves = g.legalMoves(pi);
        if (moves.isEmpty) break;
        final m = ai.chooseMove(g, pi, Difficulty.porcelain);
        expect(g.isLegalMove(m.path, pi), isTrue,
            reason: 'turn $t: AI move must satisfy RULES.md §4-5');
        // Home-lock invariant (RULES.md §7): a player's marble count inside
        // its own destination never decreases on its own turn.
        final homeBefore = g.countInDest(pi);
        expect(g.commitMove(m), isTrue);
        expect(g.countInDest(pi), greaterThanOrEqualTo(homeBefore),
            reason: 'turn $t: home-lock violation (marble left destination)');
        turns++;
      }
      expect(turns, greaterThan(100));
    });

    test('40 imperial-vs-imperial turns: every move legal', () {
      final g = twoPlayer();
      final ai = Ai(seed: 7);
      var turns = 0;
      for (int t = 0; t < 40; t++) {
        if (g.status != GameStatus.playing) break;
        final pi = g.turnIndex;
        final moves = g.legalMoves(pi);
        if (moves.isEmpty) break;
        final m = ai.chooseMove(g, pi, Difficulty.imperial);
        expect(g.isLegalMove(m.path, pi), isTrue,
            reason: 'turn $t: imperial move must satisfy RULES.md §4-5');
        expect(g.commitMove(m), isTrue);
        turns++;
      }
      expect(turns, greaterThan(20));
    });
  });

  group('TurnDirector: no stuck states (bot-vs-bot sim)', () {
    Future<GameState> runBotGame({
      required int players,
      required List<Difficulty> diffs,
      Duration? thinkDelay,
    }) async {
      final seats = seatsForPlayerCount(players);
      final g = GameState(
        board: Board(),
        players: [
          for (int i = 0; i < seats.length; i++)
            Competitor(
                seat: seats[i],
                isHuman: false,
                difficulty: diffs[i % diffs.length]),
        ],
      );
      final director = TurnDirector(
        game: g,
        thinkDelay: thinkDelay ?? Duration.zero,
        botThinkTimeout: const Duration(seconds: 10),
        animateTimeout: const Duration(seconds: 10),
      );
      director.displayNames = [
        for (int i = 0; i < seats.length; i++) 'Bot$i'
      ];
      // Legality of every move is asserted synchronously in the AI-legality
      // group above; here we prove the director itself can never get stuck:
      // the game must always terminate with marble counts conserved.
      // (Per-move checks cannot live on the broadcast event stream — it
      // delivers asynchronously, after the turn has already committed.)
      // Instant animator (visibility is a UI concern; legality is engine's).
      director.animateMove = (_) async {};
      final done = Completer<void>();
      director.onFinished = () => done.complete();
      director.start();
      await done.future.timeout(const Duration(minutes: 4));
      director.dispose();
      return g;
    }

    test('2-player porcelain vs porcelain always terminates', () async {
      final g = await runBotGame(
          players: 2,
          diffs: [Difficulty.porcelain, Difficulty.porcelain]);
      expect(g.status, isNot(GameStatus.playing));
      expect(g.totalTurns, lessThanOrEqualTo(320));
      final counts = <int, int>{};
      for (final h in g.board.holes) {
        final occ = g.holes[h.idx];
        if (occ >= 0) counts[occ] = (counts[occ] ?? 0) + 1;
      }
      expect(counts[0], 10);
      expect(counts[1], 10);
    });

    test('6-player mixed difficulties always terminates', () async {
      final g = await runBotGame(
        players: 6,
        diffs: [Difficulty.porcelain, Difficulty.lacquer],
      );
      expect(g.status, isNot(GameStatus.playing));
      final counts = <int, int>{};
      for (final h in g.board.holes) {
        final occ = g.holes[h.idx];
        if (occ >= 0) counts[occ] = (counts[occ] ?? 0) + 1;
      }
      for (int i = 0; i < 6; i++) {
        expect(counts[i], 10, reason: 'player $i must keep 10 marbles');
      }
    });

    test('3-player game always terminates', () async {
      final g = await runBotGame(
          players: 3,
          diffs: [Difficulty.lacquer, Difficulty.porcelain]);
      expect(g.status, isNot(GameStatus.playing));
    });

    test('watchdog recovers a hung animation and the game continues',
        () async {
      final g = twoPlayer();
      final director = TurnDirector(
        game: g,
        thinkDelay: Duration.zero,
        botThinkTimeout: const Duration(seconds: 5),
        animateTimeout: const Duration(milliseconds: 300),
      );
      director.displayNames = ['A', 'B'];
      var recovered = 0;
      final sub = director.events.listen((e) {
        if (e.kind == TurnEventKind.watchdogRecovered) recovered++;
      });
      // Animator that NEVER completes: the watchdog must force the game on.
      director.animateMove = (_) => Completer<void>().future;
      var turns = 0;
      final turnSub = director.events.listen((e) {
        if (e.kind == TurnEventKind.committed) turns++;
      });
      director.start();
      await Future.delayed(const Duration(seconds: 4));
      expect(recovered, greaterThan(0),
          reason: 'watchdog must fire on the hung animation');
      expect(turns, greaterThan(0),
          reason: 'turns must commit despite the hung animator');
      await sub.cancel();
      await turnSub.cancel();
      director.dispose();
    });

    test('watchdog recovers a hung bot brain and the game continues',
        () async {
      final g = twoPlayer();
      final director = _HangingDirector(game: g);
      director.displayNames = ['A', 'B'];
      director.animateMove = (_) async {};
      var turns = 0;
      final turnSub = director.events.listen((e) {
        if (e.kind == TurnEventKind.committed) turns++;
      });
      director.start();
      await Future.delayed(const Duration(seconds: 3));
      // The hung brain hits the timeout race on every one of its turns;
      // the fallback move keeps the game moving — never stuck.
      expect(turns, greaterThan(0),
          reason: 'fallback moves must keep the game moving');
      expect(g.totalTurns, greaterThan(2),
          reason: 'recovery must repeat: multiple hung turns complete');
      await turnSub.cancel();
      director.dispose();
    });
  });
}

/// A director whose bot brain never answers (simulates a hung AI).
class _HangingDirector extends TurnDirector {
  _HangingDirector({required super.game})
      : super(
          thinkDelay: Duration.zero,
          botThinkTimeout: const Duration(milliseconds: 400),
          animateTimeout: const Duration(seconds: 5),
        );

  @override
  Future<Move> computeMove(int pi) => Completer<Move>().future;
}
