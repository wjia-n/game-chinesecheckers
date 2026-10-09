import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/game.dart';

/// Mid-game persistence (RULES.md §12: a killed app resumes mid-game exactly)
/// plus cumulative match scoring (RULES.md §8).
class SaveManager {
  static const _kGame = 'saved_game_v1';
  static const _kMatch = 'match_scores_v1';

  static Future<void> saveGame(GameState g, Map<String, int> match) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kGame, g.encode());
    await p.setString(_kMatch, jsonEncode(match));
  }

  static Future<({GameState game, Map<String, int> match})?> loadGame() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kGame);
    if (raw == null) return null;
    try {
      final game = GameState.decode(raw);
      final matchRaw = p.getString(_kMatch);
      final match = <String, int>{};
      if (matchRaw != null) {
        final m = jsonDecode(matchRaw) as Map<String, dynamic>;
        m.forEach((k, v) => match[k] = (v as num).toInt());
      }
      return (game: game, match: match);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasSave() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kGame);
  }

  static Future<void> clearGame() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kGame);
  }

  static Future<void> clearMatch() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kMatch);
  }
}
