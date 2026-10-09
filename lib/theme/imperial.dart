import 'package:flutter/material.dart';

/// Imperial Porcelain design tokens — the visual source of truth for the
/// Chinese Checkers Stitch rebuild. Midnight silk canvas, cinnabar lacquer,
/// cobalt qinghua porcelain, antique gold inlay.
class Imperial {
  // Silk canvas
  static const Color silk = Color(0xFF11141C);
  static const Color silkRaised = Color(0xFF181C26);
  static const Color silkLow = Color(0xFF181B24);
  static const Color panel = Color(0xFF1C1F28);

  // Cinnabar lacquer
  static const Color cinnabar = Color(0xFF8B1E1E);
  static const Color cinnabarDeep = Color(0xFF5C1212);
  static const Color cinnabarText = Color(0xFFFF9D95);

  // Cobalt glaze
  static const Color cobalt = Color(0xFFB0C7F1);
  static const Color cobaltDeep = Color(0xFF1D3557);

  // Antique gold
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldBright = Color(0xFFE5C158);
  static const Color goldOxidized = Color(0xFF997A15);

  // Ivory porcelain
  static const Color ivory = Color(0xFFF9F6F0);
  static const Color ivoryShade = Color(0xFFEFECE6);
  static const Color ivoryText = Color(0xFFE0E2EE);

  static const Color outline = Color(0xFFA68A87);

  /// Player marble palette in seat order (RULES.md §2).
  static const List<Color> marbleBase = [
    Color(0xFF1E3A8A), // Cobalt Blue
    Color(0xFF8B1E1E), // Cinnabar Red
    Color(0xFF2E7D5B), // Jade Green
    Color(0xFFD4AF37), // Imperial Gold
    Color(0xFFF9F6F0), // Ivory White
    Color(0xFF1A1C22), // Ink Black
  ];

  static const List<String> marbleNames = [
    'Cobalt',
    'Cinnabar',
    'Jade',
    'Imperial',
    'Ivory',
    'Ink',
  ];

  /// Darker shade of a marble base for the sphere's lower hemisphere.
  static Color marbleDark(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness * 0.45).clamp(0.0, 1.0)).toColor();
  }

  /// Lighter glaze tone for the upper hemisphere.
  static Color marbleLight(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness + (1 - hsl.lightness) * 0.55).clamp(0.0, 1.0))
        .toColor();
  }

  /// Painted qinghua motif color that reads on top of [base].
  static Color motifOn(Color base) {
    final lum = base.computeLuminance();
    return lum > 0.45 ? const Color(0xFF1E3A8A) : const Color(0xFFF9F6F0);
  }

  // ---- Typography (system serif/sans fallbacks; no bundled fonts) ----
  static const String serif = 'serif';

  static TextStyle headline(double size) => TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: ivory,
        letterSpacing: 0.5,
      );

  static TextStyle plaqueTitle(double size) => TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: cinnabarDeep,
        letterSpacing: 1.2,
      );

  static TextStyle body(double size, {Color color = ivoryText}) => TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.45,
      );

  static TextStyle label(double size, {Color color = gold}) => TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 3.0,
      );

  // ---- Decorations ----
  /// Ivory porcelain plaque with dual-line gold border.
  static BoxDecoration plaque({double radius = 14}) => BoxDecoration(
        color: ivory,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: goldOxidized, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: goldBright.withValues(alpha: 0.55),
            offset: const Offset(0, 0),
            blurRadius: 0,
            spreadRadius: -6,
          ),
          const BoxShadow(
            color: Color(0x88000000),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      );

  /// Dark silk tray with gold hairline.
  static BoxDecoration tray({double radius = 16}) => BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: goldOxidized.withValues(alpha: 0.8), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), offset: Offset(0, 8), blurRadius: 18),
        ],
      );

  /// Cinnabar lacquer surface.
  static BoxDecoration lacquer({double radius = 14}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cinnabar, cinnabarDeep],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: gold.withValues(alpha: 0.85), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), offset: Offset(0, 5), blurRadius: 12),
          BoxShadow(
            color: Color(0x33FFE9C4),
            offset: Offset(0, 1),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      );

  /// Gold hairline divider.
  static Widget divider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gold.withValues(alpha: 0.0),
              gold.withValues(alpha: 0.8),
              gold.withValues(alpha: 0.0),
            ],
          ),
        ),
      );
}
