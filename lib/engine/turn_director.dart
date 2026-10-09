import 'dart:async';
import 'ai.dart';
import 'game.dart';

/// Turn phases owned by the engine — never by UI timers (master rules:
/// engine-owned turn state machine + watchdog).
enum TurnPhase {
  idle, // no game attached / between games
  awaitingHuman, // a human's turn: the UI must collect a move via humanMove
  botThinking, // a bot's turn: the engine is choosing a move
  animating, // a move was chosen and the UI is animating it visibly
  committing, // the move is being committed to the engine
  finished, // game over (won or draw)
}

/// Events the engine emits so the UI can narrate and render trays.
enum TurnEventKind {
  turnStarted, // data: player index
  botThinking, // data: player index
  botMoveChosen, // data: Move
  humanPrompt, // data: player index
  animating, // data: Move
  committed, // data: Move
  skipped, // data: player index (auto-skip, no legal move)
  gameFinished, // data: null
  watchdogRecovered, // data: phase name that was recovered
}

class TurnEvent {
  final TurnEventKind kind;
  final Object? data;
  const TurnEvent(this.kind, [this.data]);
}

/// Engine-owned turn controller.
///
/// The director owns every turn phase transition. The UI only:
/// - renders [phase], [narration], [activePlayer],
/// - animates moves when asked via [animateMove],
/// - forwards human moves via [humanMove],
/// - persists when told via [onCommitted].
///
/// A watchdog timer watches every phase: if a phase makes no progress
/// within its deadline, the director recovers on its own (bot thinking that
/// hangs falls back to a simple legal move; an animation that never reports
/// back is force-completed). Stuck states are impossible by construction:
/// every phase either advances, recovers, or the game is finished.
class TurnDirector {
  final GameState game;
  final Ai ai;
  final _events = StreamController<TurnEvent>.broadcast();

  TurnPhase phase = TurnPhase.idle;
  String narration = '';
  int activePlayer = -1;

  /// UI hook: animate [move] hop-by-hop, visibly. Must complete.
  Future<void> Function(Move move)? animateMove;

  /// UI hook: called after every committed turn (persist + repaint).
  void Function()? onCommitted;

  /// UI hook: called once when the game finishes.
  void Function()? onFinished;

  Timer? _watchdog;
  DateTime _phaseEntered = DateTime.now();
  int _token = 0; // cancels stale async work
  bool _disposed = false;
  Move? _pendingMove; // the move currently being animated/committed

  /// Watchdog deadlines. Overridable in tests to prove recovery quickly.
  Duration botThinkTimeout;
  Duration animateTimeout;

  /// Minimum visible "thinking" beat before a bot's move is computed, so a
  /// bot turn is never resolved instantly (master rules: bot visibility).
  Duration thinkDelay;

  TurnDirector({
    required this.game,
    Ai? ai,
    this.botThinkTimeout = const Duration(seconds: 15),
    this.animateTimeout = const Duration(seconds: 12),
    this.thinkDelay = const Duration(milliseconds: 750),
  }) : ai = ai ?? Ai();

  Stream<TurnEvent> get events => _events.stream;

  void _emit(TurnEventKind kind, [Object? data]) {
    if (!_disposed) _events.add(TurnEvent(kind, data));
  }

  void _setPhase(TurnPhase p) {
    phase = p;
    _phaseEntered = DateTime.now();
  }

  /// Start (or restart) directing turns for the current game state.
  void start() {
    if (_disposed) return;
    _watchdog ??= Timer.periodic(
        const Duration(milliseconds: 500), (_) => _watchdogTick());
    _token++;
    _beginTurn();
  }

  /// Begin the turn for game.turnIndex. Skips players with no legal move
  /// (RULES.md §3) — the engine, not the UI, owns skipping.
  void _beginTurn() {
    if (_disposed) return;
    final token = _token;
    if (game.status != GameStatus.playing) {
      _finish();
      return;
    }
    // Auto-skip players with no legal move; the engine owns this loop.
    var guard = 0;
    while (game.legalMoves(game.turnIndex).isEmpty &&
        game.status == GameStatus.playing &&
        guard++ < game.players.length + 1) {
      final skipped = game.turnIndex;
      _emit(TurnEventKind.skipped, skipped);
      game.totalTurns++;
      game.turnsSinceDestEntry++;
      game.turnIndex = (game.turnIndex + 1) % game.players.length;
      if (guard > game.players.length) break;
    }
    if (game.status != GameStatus.playing) {
      _finish();
      return;
    }
    // Full round with no legal moves anywhere -> draw (RULES.md §12).
    if (game.legalMoves(game.turnIndex).isEmpty) {
      game.status = GameStatus.draw;
      game.drawReason = 'No legal moves remain for any player.';
      _finish();
      return;
    }
    if (token != _token) return; // superseded
    activePlayer = game.turnIndex;
    _emit(TurnEventKind.turnStarted, activePlayer);
    if (game.current.isHuman) {
      narration = '${nameOf(activePlayer)}, your move — tap a marble.';
      _setPhase(TurnPhase.awaitingHuman);
      _emit(TurnEventKind.humanPrompt, activePlayer);
    } else {
      narration = '${nameOf(activePlayer)} is thinking…';
      _setPhase(TurnPhase.botThinking);
      _emit(TurnEventKind.botThinking, activePlayer);
      _runBot(activePlayer, token);
    }
  }

  /// Display names are injected by the UI layer (renameable slots).
  List<String> displayNames = const [];

  String nameOf(int pi) {
    if (pi >= 0 && pi < displayNames.length && displayNames[pi].isNotEmpty) {
      return displayNames[pi];
    }
    return 'Player ${pi + 1}';
  }

  /// Computes the bot's move.
  ///
  /// Visible for testing: a test may override it with a never-completing
  /// future to simulate a hung brain and prove the timeout race recovers.
  Future<Move> computeMove(int pi) =>
      Future(() => ai.chooseMove(game, pi, game.current.difficulty));

  Future<void> _runBot(int pi, int token) async {
    Move? move;
    try {
      // Visible thinking beat — a bot turn is never resolved instantly.
      await Future.delayed(thinkDelay);
      if (_disposed || token != _token || phase != TurnPhase.botThinking) {
        return;
      }
      try {
        // A brain that hangs past the watchdog deadline loses the turn to
        // the fallback move — the game never waits forever.
        move = await computeMove(pi).timeout(botThinkTimeout);
      } on TimeoutException {
        move = null;
      }
    } catch (_) {
      move = null;
    }
    if (_disposed || token != _token) return;
    if (phase != TurnPhase.botThinking) return; // watchdog already recovered
    move ??= _fallbackMove(pi);
    if (move == null) {
      // No legal move after all — skip and move on (cannot get stuck).
      _emit(TurnEventKind.skipped, pi);
      game.turnIndex = (game.turnIndex + 1) % game.players.length;
      _beginTurn();
      return;
    }
    narration =
        '${nameOf(pi)} ${move.isStep ? 'steps forward' : 'hops ${move.hopCount}× across the star'}!';
    _pendingMove = move;
    _setPhase(TurnPhase.animating);
    _emit(TurnEventKind.botMoveChosen, move);
    _emit(TurnEventKind.animating, move);
    await _animateAndCommit(move, token);
  }

  /// Simplest legal move — watchdog fallback when the AI hangs.
  Move? _fallbackMove(int pi) {
    final moves = game.legalMoves(pi);
    if (moves.isEmpty) return null;
    moves.sort((a, b) => b.hopCount.compareTo(a.hopCount));
    return moves.first;
  }

  Future<void> _animateAndCommit(Move move, int token) async {
    final anim = animateMove;
    if (anim != null) {
      try {
        await anim(move).timeout(animateTimeout + const Duration(seconds: 5));
      } catch (_) {
        // Animation failed or hung: the watchdog/commit path still completes
        // the turn. The move is never lost.
      }
    }
    if (_disposed || token != _token) return;
    if (phase != TurnPhase.animating) return; // watchdog recovered already
    _setPhase(TurnPhase.committing);
    _commit(move);
  }

  void _commit(Move move) {
    final ok = game.commitMove(move);
    _pendingMove = null;
    if (!ok) {
      // Defensive: the move came from legal generation, but if it ever
      // fails, fall back to the first legal move rather than sticking.
      final fb = _fallbackMove(game.turnIndex);
      if (fb != null) game.commitMove(fb);
    }
    _emit(TurnEventKind.committed, move);
    onCommitted?.call();
    if (game.status != GameStatus.playing) {
      _finish();
      return;
    }
    _beginTurn();
  }

  /// Called by the UI when a human taps a legal destination. Returns false
  /// if the move was not accepted (wrong phase / illegal).
  Future<bool> humanMove(Move move) async {
    if (_disposed) return false;
    if (phase != TurnPhase.awaitingHuman) return false;
    if (!game.current.isHuman) return false;
    if (!game.isLegalMove(move.path, game.turnIndex)) return false;
    final token = _token;
    _pendingMove = move;
    _setPhase(TurnPhase.animating);
    _emit(TurnEventKind.animating, move);
    await _animateAndCommit(move, token);
    return true;
  }

  /// Human cancelled selection — no-op for the engine (still awaiting).
  void humanWaiting() {
    if (phase == TurnPhase.animating) {
      // Never happens via UI; kept for API completeness.
    }
  }

  void _finish() {
    _setPhase(TurnPhase.finished);
    narration = game.status == GameStatus.won
        ? '${nameOf(game.winnerIndex)} wins the star!'
        : 'The game ends in a draw.';
    _emit(TurnEventKind.gameFinished);
    onFinished?.call();
  }

  // ------------------------------------------------------------ watchdog
  void _watchdogTick() {
    if (_disposed) return;
    final elapsed = DateTime.now().difference(_phaseEntered);
    switch (phase) {
      case TurnPhase.botThinking:
        if (elapsed > botThinkTimeout) _recover('botThinking');
        break;
      case TurnPhase.animating:
        if (elapsed > animateTimeout) _recover('animating');
        break;
      case TurnPhase.idle:
      case TurnPhase.awaitingHuman:
      case TurnPhase.committing:
      case TurnPhase.finished:
        break; // humans may think forever; committing is synchronous
    }
  }

  /// Watchdog recovery: force the stuck phase forward with a safe fallback.
  /// Never throws; never leaves the game stuck.
  void _recover(String phaseName) {
    if (_disposed) return;
    _token++; // cancel any stale async work from the stuck phase
    _emit(TurnEventKind.watchdogRecovered, phaseName);
    if (game.status != GameStatus.playing) {
      _finish();
      return;
    }
    final pi = game.turnIndex;
    // A hung human animation recovers by committing the human's own chosen
    // move — never a fallback the player didn't pick.
    final pending = _pendingMove;
    final Move? move;
    if (game.current.isHuman && pending != null) {
      move = pending;
    } else {
      move = _fallbackMove(pi);
    }
    if (move == null) {
      game.turnIndex = (game.turnIndex + 1) % game.players.length;
      _beginTurn();
      return;
    }
    _pendingMove = null;
    narration = '${nameOf(pi)} plays on…';
    _setPhase(TurnPhase.committing);
    // Commit synchronously — no animation dependency in recovery.
    game.commitMove(move);
    _emit(TurnEventKind.committed, move);
    onCommitted?.call();
    if (game.status != GameStatus.playing) {
      _finish();
      return;
    }
    _beginTurn();
  }

  /// Re-sync the director with externally mutated game state
  /// (undo, restart). Cancels in-flight work and re-begins the turn.
  void resync() {
    if (_disposed) return;
    _token++;
    _pendingMove = null;
    _setPhase(TurnPhase.idle);
    _beginTurn();
  }

  void dispose() {
    _disposed = true;
    _token++;
    _watchdog?.cancel();
    _watchdog = null;
    _events.close();
  }
}
