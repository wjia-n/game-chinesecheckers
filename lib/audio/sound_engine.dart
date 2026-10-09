import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'synth.dart';

Uint8List _renderBed(bool calm) => Synth.wav(Synth.musicBed(calm: calm));

enum SfxKind {
  click,
  select, // ceramic tok — marble selected
  step, // wooden thock — single step
  hop, // ascending toks — hop chain
  invalid, // dull knock — illegal move
  start, // game-start chime
  win,
  lose,
  turnTick,
  hint,
}

/// Porcelain audio: synthesized SFX + looping generated music beds.
///
/// Reliability design (mirrors the proven Ludo pattern):
/// - Music clips are synthesized once and cached; starting music never
///   blocks the UI thread after the first build (heavy beds render in an
///   isolate via [prewarm]/lazy [compute]).
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu
///   in/out, pause/resume, toggles) can never swallow a start or leave the
///   player half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call,
///   backgrounding) resumes exactly where it left off.
/// - Every public method catches player errors; audio can never crash the app.
class SoundEngine extends ChangeNotifier {
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();

  bool _musicOn = true;
  bool _sfxOn = true;
  double _musicVolume = 0.6;
  double _sfxVolume = 0.8;
  bool _inGame = false;

  bool get musicOn => _musicOn;
  bool get sfxOn => _sfxOn;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  // Cache synthesized clips so we only build them once.
  final Map<SfxKind, Uint8List> _sfxCache = {};
  Uint8List? _menuMusic;
  Uint8List? _gameMusic;
  Future<void>? _bedBuilding;

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  SoundEngine() {
    // Fire-and-forget is fine: configure() runs before any play.
    _music.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> init({
    required bool musicOn,
    required bool sfxOn,
    required double musicVolume,
    required double sfxVolume,
  }) async {
    applySettings(
      musicOn: musicOn,
      sfxOn: sfxOn,
      musicVolume: musicVolume,
      sfxVolume: sfxVolume,
    );
  }

  void applySettings({
    required bool musicOn,
    required bool sfxOn,
    required double musicVolume,
    required double sfxVolume,
  }) {
    final musicToggled = musicOn != _musicOn;
    _musicOn = musicOn;
    _sfxOn = sfxOn;
    _musicVolume = musicVolume.clamp(0.0, 1.0);
    _sfxVolume = sfxVolume.clamp(0.0, 1.0);
    _music.setVolume(_musicOn ? _musicVolume * 0.55 : 0.0);
    _sfx.setVolume(_sfxOn ? _sfxVolume : 0.0);
    if (musicToggled) {
      if (_musicOn) {
        _playCurrentBed();
      } else {
        stopMusic();
      }
    }
    notifyListeners();
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  /// Called from the splash screen so music starts instantly on the menu.
  Future<void> prewarm() async {
    if (_disposed || _bedBuilding != null) return;
    _bedBuilding = Future(() async {
      try {
        _menuMusic ??= await compute(_renderBed, true);
        _gameMusic ??= await compute(_renderBed, false);
      } catch (_) {}
    });
    await _bedBuilding;
  }

  // ------------------------------------------------------------ SFX cache
  Uint8List _clip(SfxKind kind) => _sfxCache.putIfAbsent(kind, () {
        switch (kind) {
          case SfxKind.click:
            return Synth.wav(Synth.click());
          case SfxKind.select:
            return Synth.wav(Synth.tok(760, 0.09));
          case SfxKind.step:
            return Synth.wav(Synth.thock());
          case SfxKind.hop:
            return Synth.wav(Synth.hop());
          case SfxKind.invalid:
            return Synth.wav(Synth.knock());
          case SfxKind.start:
            return Synth.wav(Synth.start());
          case SfxKind.win:
            return Synth.wav(Synth.win());
          case SfxKind.lose:
            return Synth.wav(Synth.lose());
          case SfxKind.turnTick:
            return Synth.wav(Synth.turnTick());
          case SfxKind.hint:
            return Synth.wav(Synth.hint());
        }
      });

  Future<void> play(SfxKind kind) async {
    if (!_sfxOn || _disposed) return;
    try {
      final bytes = _clip(kind);
      await _sfx.play(BytesSource(bytes));
    } catch (_) {
      // Audio is best-effort; never crash the game.
    }
  }

  // -------------------------------------------------------------- music
  Future<void> _ensureBed(bool inGame) async {
    if (inGame && _gameMusic == null) {
      _gameMusic = await compute(_renderBed, false);
    } else if (!inGame && _menuMusic == null) {
      _menuMusic = await compute(_renderBed, true);
    }
  }

  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    // Wait for any in-flight op, then bail if superseded meanwhile.
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !_musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !_musicOn) return;
      await _ensureBed(track == 'game');
      if (gen != _musicGen || _disposed || !_musicOn) return;
      _currentTrack = track;
      _inGame = track == 'game';
      _pausedByLifecycle = false;
      await _music.setVolume(_musicVolume * 0.55);
      await _music.play(
          BytesSource(track == 'game' ? _gameMusic! : _menuMusic!));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> _playCurrentBed() =>
      _startTrack(_inGame ? 'game' : 'menu');

  /// Switch between the menu bed and the gameplay bed.
  Future<void> setInGame(bool inGame) async {
    if (_inGame == inGame) {
      if (_musicOn) await _playCurrentBed();
      return;
    }
    await _startTrack(inGame ? 'game' : 'menu');
  }

  Future<void> startMenuMusic() => _startTrack('menu');
  Future<void> startGameMusic() => _startTrack('game');

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where we left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !_musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track != null) await _startTrack(track);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      _sfx.dispose();
      _music.dispose();
    } catch (_) {}
    super.dispose();
  }
}
