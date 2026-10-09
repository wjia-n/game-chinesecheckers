import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/game.dart';
import '../theme/cc_themes.dart';

/// App settings persisted via shared_preferences. Survives app restarts.
///
/// Stores: audio toggles + volumes, default bot difficulty, renameable
/// player names (6 slots, one per seat), theme/marble/accent appearance
/// choices (incl. custom theme colors), game-mode flags, Pro unlock state,
/// and lifetime stats.
class AppSettings extends ChangeNotifier {
  static const _kMusic = 'cc_music_on';
  static const _kSfx = 'cc_sfx_on';
  static const _kMusicVol = 'cc_music_vol';
  static const _kSfxVol = 'cc_sfx_vol';
  static const _kDifficulty = 'cc_ai_difficulty';
  static const _kForward = 'cc_forward_progress';
  static const _kSymmetric = 'cc_symmetric_variant';
  static const _kNames = 'cc_player_names'; // legacy unordered StringSet key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so the
  /// old key scrambled name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'chinesecheckers_player_names_json';
  static const _kTheme = 'cc_theme_id';
  static const _kStyle = 'cc_marble_style';
  static const _kAccent = 'cc_board_accent';
  static const _kCustomPrefix = 'cc_custom_';
  static const _kIsPro = 'cc_is_pro';
  static const _kWins = 'cc_wins';
  static const _kGames = 'cc_games_played';
  static const _kBestTurns = 'cc_best_turns';

  static const defaultNames = [
    'Cobalt',
    'Cinnabar',
    'Jade',
    'Imperial',
    'Ivory',
    'Ink',
  ];

  /// Encode the 6 player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 6) {
        return [for (int i = 0; i < 6; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double musicVolume = 0.6;
  double sfxVolume = 0.8;
  Difficulty aiDifficulty = Difficulty.lacquer;
  bool forwardProgress = true;
  bool symmetricVariant = false;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'midnight-silk';
  String marbleStyleId = 'qinghua';
  String boardAccentId = 'gold-inlay';
  bool isPro = false;
  int wins = 0;
  int gamesPlayed = 0;
  int bestTurns = 0; // fewest turns to a human win (0 = none yet)

  /// Custom theme colors (ARGB ints).
  Map<String, int> customColors = Map.of(CcThemes.defaultCustomColors);

  CcTheme get customTheme => CcThemes.customFromColors(customColors);

  CcTheme get theme => CcThemes.byId(themeId, custom: customTheme);

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
    // Player names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == 6)
          ? [for (int i = 0; i < 6; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'midnight-silk';
    marbleStyleId = p.getString(_kStyle) ?? 'qinghua';
    boardAccentId = p.getString(_kAccent) ?? 'gold-inlay';
    isPro = p.getBool(_kIsPro) ?? false;
    wins = p.getInt(_kWins) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestTurns = p.getInt(_kBestTurns) ?? 0;
    for (final k in CcThemes.defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? CcThemes.defaultCustomColors[k]!;
    }
    _enforceFreeLimits();
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
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setString(_kStyle, marbleStyleId);
    await p.setString(_kAccent, boardAccentId);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kWins, wins);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBestTurns, bestTurns);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits() {
    if (isPro) return;
    if (CcThemes.isProTheme(themeId)) themeId = 'midnight-silk';
    if (themeId == 'custom') themeId = 'midnight-silk';
    if (CcThemes.isProStyle(marbleStyleId)) marbleStyleId = 'qinghua';
    if (CcThemes.isProAccent(boardAccentId)) boardAccentId = 'gold-inlay';
    if (aiDifficulty == Difficulty.imperial) {
      aiDifficulty = Difficulty.lacquer;
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
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
    // Imperial (hard) is a Pro feature.
    if (d == Difficulty.imperial && !isPro) return;
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

  Future<void> setPlayerName(int seat, String name) async {
    if (seat < 0 || seat > 5) return;
    final clean = name.trim();
    playerNames[seat] = clean.isEmpty ? defaultNames[seat] : clean;
    notifyListeners();
    await _save();
  }

  void setTheme(String id) {
    if (!isPro && (CcThemes.isProTheme(id) || id == 'custom')) return;
    themeId = id;
    _save();
    notifyListeners();
  }

  void setMarbleStyle(String id) {
    if (!isPro && CcThemes.isProStyle(id)) return;
    marbleStyleId = id;
    _save();
    notifyListeners();
  }

  void setBoardAccent(String id) {
    if (!isPro && CcThemes.isProAccent(id)) return;
    boardAccentId = id;
    _save();
    notifyListeners();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!CcThemes.defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(CcThemes.defaultCustomColors);
    notifyListeners();
    await _save();
  }

  /// Record a finished game. [humanWon] true if a human player won.
  Future<void> recordGame({required bool humanWon, required int turns}) async {
    gamesPlayed++;
    if (humanWon) {
      wins++;
      if (bestTurns == 0 || turns < bestTurns) bestTurns = turns;
    }
    notifyListeners();
    await _save();
  }

  Future<void> resetDefaults() async {
    musicOn = true;
    sfxOn = true;
    musicVolume = 0.6;
    sfxVolume = 0.8;
    aiDifficulty = Difficulty.lacquer;
    forwardProgress = true;
    symmetricVariant = false;
    playerNames = List.of(defaultNames);
    themeId = 'midnight-silk';
    marbleStyleId = 'qinghua';
    boardAccentId = 'gold-inlay';
    customColors = Map.of(CcThemes.defaultCustomColors);
    await _save();
    notifyListeners();
  }
}
