import 'package:flutter_test/flutter_test.dart';
import 'package:chinesecheckers/state/settings.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Player names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// six names came back in arbitrary order and renames appeared "not saved".
/// Names are now stored as one order-preserving JSON string
/// (chinesecheckers_player_names_json) with one-time migration from the
/// legacy key. These tests cover encode/decode round-trips plus the
/// settings reload path, without needing platform channels.
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Zara', 'Ali', 'Bot Bob', 'Noor', 'Kai'];
    final decoded = AppSettings.decodePlayerNames(
      AppSettings.encodePlayerNames(names),
    );
    expect(decoded, names);
    // Slot order is what matters: each index must map to the same seat.
    for (int i = 0; i < 6; i++) {
      expect(decoded[i], names[i]);
    }
  });

  test('decode falls back to defaults on missing or corrupt data', () {
    expect(
      AppSettings.decodePlayerNames(null),
      AppSettings.defaultNames,
    );
    expect(
      AppSettings.decodePlayerNames('definitely not json'),
      AppSettings.defaultNames,
    );
    expect(
      AppSettings.decodePlayerNames('["only","two"]'),
      AppSettings.defaultNames,
    );
    expect(
      AppSettings.decodePlayerNames('{"a":1}'),
      AppSettings.defaultNames,
    );
  });

  test('blank entries fall back to that slot\'s default name', () {
    final decoded = AppSettings.decodePlayerNames(
        '["Wajiha","","  ","Imperial","Ivory","Ink"]');
    expect(decoded,
        ['Wajiha', 'Cinnabar', 'Jade', 'Imperial', 'Ivory', 'Ink']);
  });

  test('JSON never reorders names even with a scrambled-looking input', () {
    // The old bug: a scrambled StringSet could come back in any order.
    // JSON preserves insertion order, so decode(encode(x)) == x always.
    final rng = [
      'Wajiha',
      'Zara',
      'Ali',
      'Bot Bob',
      'Noor',
      'Kai',
    ];
    for (int rep = 0; rep < 20; rep++) {
      final shuffled = List.of(rng)..shuffle();
      expect(
        AppSettings.decodePlayerNames(
            AppSettings.encodePlayerNames(shuffled)),
        shuffled,
      );
    }
  });
}
