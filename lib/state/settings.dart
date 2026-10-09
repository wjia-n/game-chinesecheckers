import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/game.dart';

/// App settings persisted via shared_preferences.
class AppSettings extends ChangeNotifier {
  static const _kMusic = 'music_on';
  static const _kSfx = 'sfx_on';
  static const _kMusicVol = 'music_vol';
  static const _kSfxVol = 'sfx_vol';
  static const _kDifficulty = 'ai_difficulty';
  static const _kForward = 'forward_progress';
  static const _kSymmetric = 'symmetric_variant';

  bool musicOn = true;
  bool sfxOn = true;
  double musicVolume = 0.6;
  double sfxVolume = 0.8;
  Difficulty aiDifficulty = Difficulty.lacquer;
  bool forwardProgress = true;
  bool symmetricVariant = false;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    musicVolume = p.getDouble(_kMusicVol) ?? 0.6;
    sfxVolume = p.getDouble(_kSfxVol) ?? 0.8;
    aiDifficulty =
        Difficulty.values[p.getInt(_kDifficulty) ?? Difficulty.lacquer.index];
    forwardProgress = p.getBool(_kForward) ?? true;
    symmetricVariant = p.getBool(_kSymmetric) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kMusicVol, musicVolume);
    await p.setDouble(_kSfxVol, sfxVolume);
    await p.setInt(_kDifficulty, aiDifficulty.index);
    await p.setBool(_kForward, forwardProgress);
    await p.setBool(_kSymmetric, symmetricVariant);
  }

  void setMusicOn(bool v) {
    musicOn = v;
    _save();
    notifyListeners();
  }

  void setSfxOn(bool v) {
    sfxOn = v;
    _save();
    notifyListeners();
  }

  void setMusicVolume(double v) {
    musicVolume = v.clamp(0.0, 1.0);
    _save();
    notifyListeners();
  }

  void setSfxVolume(double v) {
    sfxVolume = v.clamp(0.0, 1.0);
    _save();
    notifyListeners();
  }

  void setDifficulty(Difficulty d) {
    aiDifficulty = d;
    _save();
    notifyListeners();
  }

  void setForwardProgress(bool v) {
    forwardProgress = v;
    _save();
    notifyListeners();
  }

  void setSymmetricVariant(bool v) {
    symmetricVariant = v;
    _save();
    notifyListeners();
  }

  Future<void> resetDefaults() async {
    musicOn = true;
    sfxOn = true;
    musicVolume = 0.6;
    sfxVolume = 0.8;
    aiDifficulty = Difficulty.lacquer;
    forwardProgress = true;
    symmetricVariant = false;
    await _save();
    notifyListeners();
  }
}
