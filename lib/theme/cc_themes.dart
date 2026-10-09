import 'package:flutter/material.dart';

/// Imperial Porcelain theme catalog for Chinese Checkers.
/// Every theme fits the Stitch art direction: lacquered wood, porcelain,
/// antique gold, dark silk — no neon, no cyberpunk, no flat digital styling.
///
/// Free tier: 4 themes, 4 marble styles, 2 board accents.
/// Pro unlocks the full catalog + the custom theme creator.

class CcTheme {
  final String id;
  final String name;
  final Color silk; // app background
  final Color silkRaised; // cards / trays
  final Color panel; // dialogs
  final Color lacquer; // board plate
  final Color lacquerDeep; // board shading
  final Color gold; // inlay / trim
  final Color goldBright; // highlights
  final Color goldOxidized; // aged trim
  final Color ivory; // primary text
  final Color ivoryShade;
  final List<Color> marbles; // 6 seat colors, RULES.md §2 order
  final bool pro;

  const CcTheme({
    required this.id,
    required this.name,
    required this.silk,
    required this.silkRaised,
    required this.panel,
    required this.lacquer,
    required this.lacquerDeep,
    required this.gold,
    required this.goldBright,
    required this.goldOxidized,
    required this.ivory,
    required this.ivoryShade,
    required this.marbles,
    this.pro = false,
  });
}

class MarbleStyle {
  final String id;
  final String name;
  final bool pro;
  const MarbleStyle(this.id, this.name, {this.pro = false});
}

class BoardAccent {
  final String id;
  final String name;
  final Color inlay; // gold inlay grid lines
  final Color rim; // dimple rim crescent
  final bool pro;
  const BoardAccent(this.id, this.name, this.inlay, this.rim,
      {this.pro = false});
}

class CcThemes {
  static const List<CcTheme> all = [
    // ---- Free ----
    CcTheme(
      id: 'midnight-silk',
      name: 'Midnight Silk',
      silk: Color(0xFF11141C),
      silkRaised: Color(0xFF181C26),
      panel: Color(0xFF1C1F28),
      lacquer: Color(0xFF8B1E1E),
      lacquerDeep: Color(0xFF5C1212),
      gold: Color(0xFFD4AF37),
      goldBright: Color(0xFFE5C158),
      goldOxidized: Color(0xFF997A15),
      ivory: Color(0xFFF9F6F0),
      ivoryShade: Color(0xFFEFECE6),
      marbles: [
        Color(0xFF1E3A8A),
        Color(0xFF8B1E1E),
        Color(0xFF2E7D5B),
        Color(0xFFD4AF37),
        Color(0xFFF9F6F0),
        Color(0xFF1A1C22),
      ],
    ),
    CcTheme(
      id: 'cinnabar-court',
      name: 'Cinnabar Court',
      silk: Color(0xFF1A0E0E),
      silkRaised: Color(0xFF241414),
      panel: Color(0xFF2A1818),
      lacquer: Color(0xFFA8232A),
      lacquerDeep: Color(0xFF6E1418),
      gold: Color(0xFFE5C158),
      goldBright: Color(0xFFF2D67C),
      goldOxidized: Color(0xFFA67C1B),
      ivory: Color(0xFFFBF3E4),
      ivoryShade: Color(0xFFF0E6D2),
      marbles: [
        Color(0xFF0F2042),
        Color(0xFFC0272D),
        Color(0xFF3A8A5C),
        Color(0xFFE8B93B),
        Color(0xFFFBF3E4),
        Color(0xFF2A1214),
      ],
    ),
    CcTheme(
      id: 'jade-garden',
      name: 'Jade Garden',
      silk: Color(0xFF0E1512),
      silkRaised: Color(0xFF141D18),
      panel: Color(0xFF18211B),
      lacquer: Color(0xFF2E5B45),
      lacquerDeep: Color(0xFF1C3A2C),
      gold: Color(0xFFC9A227),
      goldBright: Color(0xFFE0BE55),
      goldOxidized: Color(0xFF8A6D1A),
      ivory: Color(0xFFF2F5EC),
      ivoryShade: Color(0xFFE4EAD9),
      marbles: [
        Color(0xFF1D4E79),
        Color(0xFF9E2B25),
        Color(0xFF3E9B6A),
        Color(0xFFD4AF37),
        Color(0xFFF2F5EC),
        Color(0xFF101A14),
      ],
    ),
    CcTheme(
      id: 'cobalt-qinghua',
      name: 'Cobalt Qinghua',
      silk: Color(0xFF0D1220),
      silkRaised: Color(0xFF131A2C),
      panel: Color(0xFF161E33),
      lacquer: Color(0xFF1E3A8A),
      lacquerDeep: Color(0xFF12245C),
      gold: Color(0xFFD4AF37),
      goldBright: Color(0xFFE5C158),
      goldOxidized: Color(0xFF997A15),
      ivory: Color(0xFFF4F7FF),
      ivoryShade: Color(0xFFE6ECFA),
      marbles: [
        Color(0xFF2A4FA8),
        Color(0xFFA8232A),
        Color(0xFF2E8B6E),
        Color(0xFFE0B93B),
        Color(0xFFF4F7FF),
        Color(0xFF0D1424),
      ],
    ),
    // ---- Pro ----
    CcTheme(
      id: 'imperial-gold',
      name: 'Imperial Gold',
      silk: Color(0xFF171208),
      silkRaised: Color(0xFF201A0C),
      panel: Color(0xFF251E10),
      lacquer: Color(0xFF8A6D1A),
      lacquerDeep: Color(0xFF5C4A12),
      gold: Color(0xFFF2D67C),
      goldBright: Color(0xFFFFE9A8),
      goldOxidized: Color(0xFFA67C1B),
      ivory: Color(0xFFFBF5E2),
      ivoryShade: Color(0xFFF0E7CC),
      marbles: [
        Color(0xFF1E3A8A),
        Color(0xFF9E2B25),
        Color(0xFF2E7D5B),
        Color(0xFFE8B93B),
        Color(0xFFFBF5E2),
        Color(0xFF241C08),
      ],
      pro: true,
    ),
    CcTheme(
      id: 'ivory-porcelain',
      name: 'Ivory Porcelain',
      silk: Color(0xFFEFE9DC),
      silkRaised: Color(0xFFF7F2E8),
      panel: Color(0xFFFDFBF5),
      lacquer: Color(0xFF8B1E1E),
      lacquerDeep: Color(0xFF5C1212),
      gold: Color(0xFFA67C1B),
      goldBright: Color(0xFFC9A227),
      goldOxidized: Color(0xFF8A6D1A),
      ivory: Color(0xFF2A2118),
      ivoryShade: Color(0xFF4A3F30),
      marbles: [
        Color(0xFF1E3A8A),
        Color(0xFF9E2B25),
        Color(0xFF2E7D5B),
        Color(0xFFB8860B),
        Color(0xFFFBF8F0),
        Color(0xFF1A1C22),
      ],
      pro: true,
    ),
    CcTheme(
      id: 'ink-scroll',
      name: 'Ink Scroll',
      silk: Color(0xFF0C0C0E),
      silkRaised: Color(0xFF141416),
      panel: Color(0xFF1A1A1E),
      lacquer: Color(0xFF2A2A30),
      lacquerDeep: Color(0xFF17171B),
      gold: Color(0xFFB8A05A),
      goldBright: Color(0xFFD4BC74),
      goldOxidized: Color(0xFF7A6A3A),
      ivory: Color(0xFFEDEDF0),
      ivoryShade: Color(0xFFD8D8DE),
      marbles: [
        Color(0xFF3A5A9E),
        Color(0xFF9E4A4A),
        Color(0xFF4A8A6E),
        Color(0xFFC9A227),
        Color(0xFFEDEDF0),
        Color(0xFF000000),
      ],
      pro: true,
    ),
    CcTheme(
      id: 'plum-blossom',
      name: 'Plum Blossom',
      silk: Color(0xFF150F16),
      silkRaised: Color(0xFF1E151F),
      panel: Color(0xFF241A25),
      lacquer: Color(0xFF7A2A4A),
      lacquerDeep: Color(0xFF521C33),
      gold: Color(0xFFD4AF37),
      goldBright: Color(0xFFE5C158),
      goldOxidized: Color(0xFF997A15),
      ivory: Color(0xFFF9F0F4),
      ivoryShade: Color(0xFFEFE0E8),
      marbles: [
        Color(0xFF2A3A8A),
        Color(0xFFB03A5A),
        Color(0xFF3E8B5E),
        Color(0xFFE0B93B),
        Color(0xFFF9F0F4),
        Color(0xFF1E1218),
      ],
      pro: true,
    ),
    CcTheme(
      id: 'celadon-mist',
      name: 'Celadon Mist',
      silk: Color(0xFF101512),
      silkRaised: Color(0xFF161E19),
      panel: Color(0xFF1A231E),
      lacquer: Color(0xFF5A7A6A),
      lacquerDeep: Color(0xFF3A5248),
      gold: Color(0xFFC9A227),
      goldBright: Color(0xFFE0BE55),
      goldOxidized: Color(0xFF8A6D1A),
      ivory: Color(0xFFF0F5F0),
      ivoryShade: Color(0xFFDFE8DF),
      marbles: [
        Color(0xFF2A5A8A),
        Color(0xFF9E4A3A),
        Color(0xFF4A9B72),
        Color(0xFFD4AF37),
        Color(0xFFF0F5F0),
        Color(0xFF141A16),
      ],
      pro: true,
    ),
    CcTheme(
      id: 'bronze-mirror',
      name: 'Bronze Mirror',
      silk: Color(0xFF120E08),
      silkRaised: Color(0xFF1A140C),
      panel: Color(0xFF201810),
      lacquer: Color(0xFF6E4A1E),
      lacquerDeep: Color(0xFF4A3012),
      gold: Color(0xFFE0BE55),
      goldBright: Color(0xFFF2D67C),
      goldOxidized: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EEDC),
      ivoryShade: Color(0xFFE8DCC0),
      marbles: [
        Color(0xFF2E4A7A),
        Color(0xFF9E3A2A),
        Color(0xFF3E7D5B),
        Color(0xFFE8B93B),
        Color(0xFFF5EEDC),
        Color(0xFF1A1208),
      ],
      pro: true,
    ),
    CcTheme(
      id: 'lantern-festival',
      name: 'Lantern Festival',
      silk: Color(0xFF140C0A),
      silkRaised: Color(0xFF1E1210),
      panel: Color(0xFF251614),
      lacquer: Color(0xFFB03A1E),
      lacquerDeep: Color(0xFF7A2412),
      gold: Color(0xFFFFC94A),
      goldBright: Color(0xFFFFDD7E),
      goldOxidized: Color(0xFFB8860B),
      ivory: Color(0xFFFBF0E0),
      ivoryShade: Color(0xFFF0E0C8),
      marbles: [
        Color(0xFF2A4A9E),
        Color(0xFFD04A2A),
        Color(0xFF3E9B5E),
        Color(0xFFFFC94A),
        Color(0xFFFBF0E0),
        Color(0xFF201008),
      ],
      pro: true,
    ),
    CcTheme(
      id: 'winter-palace',
      name: 'Winter Palace',
      silk: Color(0xFF0E1218),
      silkRaised: Color(0xFF141A22),
      panel: Color(0xFF182028),
      lacquer: Color(0xFF2E4A5E),
      lacquerDeep: Color(0xFF1E3040),
      gold: Color(0xFFC0C8D4),
      goldBright: Color(0xFFE0E8F2),
      goldOxidized: Color(0xFF8A94A4),
      ivory: Color(0xFFF2F6FA),
      ivoryShade: Color(0xFFE0E8F0),
      marbles: [
        Color(0xFF3A6A9E),
        Color(0xFF9E4A5A),
        Color(0xFF4A8B7E),
        Color(0xFFD4BC74),
        Color(0xFFF2F6FA),
        Color(0xFF0E1418),
      ],
      pro: true,
    ),
    // Custom is synthesized from the creator; never listed directly.
  ];

  static const List<MarbleStyle> marbleStyles = [
    MarbleStyle('classic', 'Classic Gloss'),
    MarbleStyle('qinghua', 'Qinghua Floral'),
    MarbleStyle('ivory-bone', 'Ivory Bone'),
    MarbleStyle('crackle', 'Crackle Glaze'),
    MarbleStyle('jade', 'Jade Carved', pro: true),
    MarbleStyle('cloisonne', 'Cloisonné', pro: true),
    MarbleStyle('lacquer-red', 'Lacquer Red', pro: true),
    MarbleStyle('obsidian', 'Obsidian', pro: true),
    MarbleStyle('pearl', 'Pearl Swirl', pro: true),
    MarbleStyle('copper', 'Copper Patina', pro: true),
  ];

  static const List<BoardAccent> boardAccents = [
    BoardAccent('gold-inlay', 'Gold Inlay',
        Color(0xFFD4AF37), Color(0xFFD4AF37)),
    BoardAccent('jade-trim', 'Jade Trim',
        Color(0xFF4A9B72), Color(0xFF4A9B72)),
    BoardAccent('bronze', 'Bronze Age',
        Color(0xFFB0803A), Color(0xFFB0803A), pro: true),
    BoardAccent('silver', 'Silver Frost',
        Color(0xFFC0C8D4), Color(0xFFC0C8D4), pro: true),
    BoardAccent('vermilion', 'Vermilion',
        Color(0xFFE04A2A), Color(0xFFE04A2A), pro: true),
    BoardAccent('ebony', 'Ebony & Gold',
        Color(0xFF8A6D1A), Color(0xFFE5C158), pro: true),
  ];

  static CcTheme byId(String id, {CcTheme? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) =>
      all.any((t) => t.id == id && t.pro);
  static bool isProStyle(String id) =>
      marbleStyles.any((s) => s.id == id && s.pro);
  static bool isProAccent(String id) =>
      boardAccents.any((a) => a.id == id && a.pro);

  static BoardAccent accentById(String id) {
    for (final a in boardAccents) {
      if (a.id == id) return a;
    }
    return boardAccents.first;
  }

  /// The user-designed custom theme, built from stored ARGB colors.
  static CcTheme customFromColors(Map<String, int> c) {
    Color col(String k, int fallback) => Color(c[k] ?? fallback);
    final marbles = [
      for (int i = 0; i < 6; i++)
        col('m$i', all.first.marbles[i].toARGB32()),
    ];
    return CcTheme(
      id: 'custom',
      name: 'My Creation',
      silk: col('silk', 0xFF11141C),
      silkRaised: col('silkRaised', 0xFF181C26),
      panel: col('panel', 0xFF1C1F28),
      lacquer: col('lacquer', 0xFF8B1E1E),
      lacquerDeep: col('lacquerDeep', 0xFF5C1212),
      gold: col('gold', 0xFFD4AF37),
      goldBright: col('goldBright', 0xFFE5C158),
      goldOxidized: col('goldOxidized', 0xFF997A15),
      ivory: col('ivory', 0xFFF9F6F0),
      ivoryShade: col('ivoryShade', 0xFFEFECE6),
      marbles: marbles,
      pro: true,
    );
  }

  static const Map<String, int> defaultCustomColors = {
    'silk': 0xFF11141C,
    'silkRaised': 0xFF181C26,
    'panel': 0xFF1C1F28,
    'lacquer': 0xFF8B1E1E,
    'lacquerDeep': 0xFF5C1212,
    'gold': 0xFFD4AF37,
    'goldBright': 0xFFE5C158,
    'goldOxidized': 0xFF997A15,
    'ivory': 0xFFF9F6F0,
    'ivoryShade': 0xFFEFECE6,
    'm0': 0xFF1E3A8A,
    'm1': 0xFF8B1E1E,
    'm2': 0xFF2E7D5B,
    'm3': 0xFFD4AF37,
    'm4': 0xFFF9F6F0,
    'm5': 0xFF1A1C22,
  };

  static const Map<String, String> customColorLabels = {
    'silk': 'Silk canvas',
    'lacquer': 'Lacquer board',
    'gold': 'Gold inlay',
    'ivory': 'Ivory text',
    'm0': 'Cobalt marble',
    'm1': 'Cinnabar marble',
    'm2': 'Jade marble',
    'm3': 'Gold marble',
    'm4': 'Ivory marble',
    'm5': 'Ink marble',
  };

  /// A small curated swatch set for the custom creator.
  static const List<int> swatches = [
    0xFF11141C, 0xFF8B1E1E, 0xFF1E3A8A, 0xFF2E7D5B, 0xFFD4AF37, 0xFFF9F6F0,
    0xFF1A1C22, 0xFF5C1212, 0xFF0F2042, 0xFFC0272D, 0xFF3E9B6A, 0xFFE8B93B,
    0xFF7A2A4A, 0xFF5A7A6A, 0xFF6E4A1E, 0xFFB03A1E, 0xFF2E4A5E, 0xFFB0803A,
    0xFFE0BE55, 0xFFC0C8D4, 0xFF4A9B72, 0xFFE04A2A, 0xFFA67C1B, 0xFFFBF3E4,
  ];
}
