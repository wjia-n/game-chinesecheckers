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

/// Audio engine: synthesized SFX + looping generated music beds.
/// Music toggle, SFX toggle and both volume sliders actually work.
class SoundEngine extends ChangeNotifier {
  AudioPlayer? _music;
  bool _musicOn = true;
  bool _sfxOn = true;
  double _musicVolume = 0.6;
  double _sfxVolume = 0.8;
  bool _inGame = false;
  bool _ready = false;

  final Map<SfxKind, Uint8List> _sfxCache = {};
  Uint8List? _menuMusic;
  Uint8List? _gameMusic;

  bool get musicOn => _musicOn;
  bool get sfxOn => _sfxOn;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  Future<void> init({
    required bool musicOn,
    required bool sfxOn,
    required double musicVolume,
    required double sfxVolume,
  }) async {
    _musicOn = musicOn;
    _sfxOn = sfxOn;
    _musicVolume = musicVolume;
    _sfxVolume = sfxVolume;
    // Pre-render the short SFX eagerly; music beds lazily (they're long).
    _sfxCache[SfxKind.click] = Synth.wav(Synth.click());
    _sfxCache[SfxKind.select] = Synth.wav(Synth.tok(760, 0.09));
    _sfxCache[SfxKind.step] = Synth.wav(Synth.thock());
    _sfxCache[SfxKind.hop] = Synth.wav(Synth.hop());
    _sfxCache[SfxKind.invalid] = Synth.wav(Synth.knock());
    _sfxCache[SfxKind.start] = Synth.wav(Synth.start());
    _sfxCache[SfxKind.win] = Synth.wav(Synth.win());
    _sfxCache[SfxKind.lose] = Synth.wav(Synth.lose());
    _sfxCache[SfxKind.turnTick] = Synth.wav(Synth.turnTick());
    _sfxCache[SfxKind.hint] = Synth.wav(Synth.hint());
    _ready = true;
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
    _musicVolume = musicVolume;
    _sfxVolume = sfxVolume;
    _music?.setVolume(_musicVolume);
    if (musicToggled) {
      if (_musicOn) {
        _playCurrentBed();
      } else {
        _music?.stop();
      }
    }
    notifyListeners();
  }

  Future<void> play(SfxKind kind) async {
    if (!_ready || !_sfxOn) return;
    final bytes = _sfxCache[kind];
    if (bytes == null) return;
    try {
      final p = AudioPlayer();
      await p.setVolume(_sfxVolume);
      p.onPlayerComplete.listen((_) => p.dispose());
      await p.play(BytesSource(bytes));
    } catch (_) {
      // Audio is best-effort; never crash the game.
    }
  }

  Future<void> _ensureBed(bool inGame) async {
    if (inGame && _gameMusic == null) {
      _gameMusic = await compute(_renderBed, false);
    } else if (!inGame && _menuMusic == null) {
      _menuMusic = await compute(_renderBed, true);
    }
  }

  Future<void> _playCurrentBed() async {
    if (!_musicOn) return;
    try {
      await _ensureBed(_inGame);
      final bytes = _inGame ? _gameMusic : _menuMusic;
      if (bytes == null) return;
      _music ??= AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(_musicVolume);
      await _music!.play(BytesSource(bytes));
    } catch (_) {}
  }

  /// Switch between the menu bed and the gameplay bed.
  Future<void> setInGame(bool inGame) async {
    if (_inGame == inGame) {
      if (_musicOn && _music?.state != PlayerState.playing) {
        await _playCurrentBed();
      }
      return;
    }
    _inGame = inGame;
    await _music?.stop();
    await _playCurrentBed();
  }

  Future<void> startMenuMusic() => setInGame(false);
  Future<void> startGameMusic() => setInGame(true);

  Future<void> stopMusic() async {
    try {
      await _music?.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _music?.dispose();
    super.dispose();
  }
}
