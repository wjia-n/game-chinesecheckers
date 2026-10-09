import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/cc_themes.dart';

/// Shared Imperial Porcelain widgets: plaques, lacquer buttons, porcelain
/// bead toggles, marble-knob sliders, seal checkboxes, dialogs.
///
/// Every widget accepts an optional [CcTheme]; when omitted the default
/// Midnight Silk theme is used.

CcTheme _th(CcTheme? t) => t ?? CcThemes.all.first;

TextStyle _body(double size, CcTheme t, {Color? color}) => TextStyle(
      fontFamily: 'serif',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? t.ivory,
      height: 1.45,
    );

TextStyle _label(double size, CcTheme t, {Color? color}) => TextStyle(
      fontFamily: 'serif',
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color ?? t.gold,
      letterSpacing: 3.0,
    );

/// Ivory porcelain plaque with dual-line gold border.
class PorcelainPlaque extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final CcTheme? theme;

  const PorcelainPlaque({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 14,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.ivory,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.goldOxidized, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: t.goldBright.withValues(alpha: 0.55),
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
      ),
      child: child,
    );
  }
}

/// Dark silk tray card.
class SilkTray extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final CcTheme? theme;

  const SilkTray({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(radius),
        border:
            Border.all(color: t.goldOxidized.withValues(alpha: 0.8), width: 1.2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x99000000), offset: Offset(0, 8), blurRadius: 18),
        ],
      ),
      child: child,
    );
  }
}

/// Cinnabar lacquer button with gold inner stroke; press sinks 1.5px
/// with a compressed shadow (physical weight).
class LacquerButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double fontSize;
  final EdgeInsets padding;
  final CcTheme? theme;

  const LacquerButton({
    super.key,
    required this.text,
    this.onPressed,
    this.fontSize = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
    this.theme,
  });

  @override
  State<LacquerButton> createState() => _LacquerButtonState();
}

class _LacquerButtonState extends State<LacquerButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = _th(widget.theme);
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: Matrix4.translationValues(0, _down ? 1.5 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled
                ? [t.lacquer, t.lacquerDeep]
                : [
                    t.silkRaised,
                    t.silk,
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: t.gold.withValues(alpha: enabled ? 0.9 : 0.4), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0x99000000),
              offset: Offset(0, _down ? 2 : 6),
              blurRadius: _down ? 6 : 14,
            ),
            const BoxShadow(
              color: Color(0x22FFE9C4),
              offset: Offset(0, 1),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          widget.text.toUpperCase(),
          textAlign: TextAlign.center,
          style: _label(widget.fontSize, t,
              color: enabled
                  ? t.ivory
                  : t.ivory.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

/// Porcelain (ivory) secondary button.
class PorcelainButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CcTheme? theme;

  const PorcelainButton(
      {super.key, required this.text, this.onPressed, this.icon, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.ivory, t.ivoryShade],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.goldOxidized.withValues(alpha: 0.9)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000000),
                offset: Offset(0, 4),
                blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: t.lacquerDeep, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              text.toUpperCase(),
              style: _label(15, t, color: t.lacquerDeep),
            ),
          ],
        ),
      ),
    );
  }
}

/// Porcelain bead toggle: a glossy bead sliding in an incised gold track.
class BeadToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final CcTheme? theme;

  const BeadToggle(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 62,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? t.lacquerDeep : t.silkRaised,
          border: Border.all(color: t.goldOxidized, width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0xAA000000),
                offset: Offset(0, 2),
                blurRadius: 5,
                spreadRadius: -1),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    radius: 1.1,
                    colors: [const Color(0xFFFFFFFF), t.ivoryShade],
                  ),
                  border: Border.all(color: t.gold, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x88000000),
                        offset: Offset(0, 2),
                        blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lacquer brush-stroke volume slider with a porcelain marble knob.
class MarbleSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final CcTheme? theme;

  const MarbleSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        activeTrackColor: t.lacquer,
        inactiveTrackColor: t.silkRaised,
        thumbShape: _MarbleThumb(theme: t),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        overlayColor: t.gold.withValues(alpha: 0.25),
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _MarbleThumb extends SliderComponentShape {
  final CcTheme theme;
  const _MarbleThumb({required this.theme});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    const r = 13.0;
    canvas.drawCircle(center + const Offset(1.5, 2.5), r,
        Paint()..color = const Color(0x88000000));
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.45),
            radius: 1.15,
            colors: [
              Colors.white,
              theme.ivoryShade,
              theme.goldOxidized
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)));
    canvas.drawCircle(center + const Offset(-4, -5), 3.4,
        Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = theme.gold);
  }
}

/// Cinnabar seal-stamp checkbox with a gold brushmark.
class SealCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final CcTheme? theme;

  const SealCheck(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.label,
      this.theme});

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: value ? t.lacquer : t.silkRaised,
              border: Border.all(color: t.gold, width: 1.4),
              boxShadow: value
                  ? const [
                      BoxShadow(
                          color: Color(0x88000000),
                          offset: Offset(0, 2),
                          blurRadius: 5)
                    ]
                  : null,
            ),
            child: value
                ? Icon(Icons.check, color: t.goldBright, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: _body(15, t)),
          ),
        ],
      ),
    );
  }
}

/// Settings row: label + control.
class SettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget control;
  final CcTheme? theme;

  const SettingRow(
      {super.key,
      required this.title,
      this.subtitle,
      required this.control,
      this.theme});

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _body(16, t)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: _body(12.5, t,
                          color: t.ivory.withValues(alpha: 0.65))),
              ],
            ),
          ),
          control,
        ],
      ),
    );
  }
}

/// Lacquered tray dialog on the silk canvas.
Future<T?> imperialDialog<T>(BuildContext context, Widget child,
    {CcTheme? theme}) {
  final t = _th(theme);
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.lacquer, t.lacquerDeep],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.gold.withValues(alpha: 0.85), width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000000),
                offset: Offset(0, 5),
                blurRadius: 12),
          ],
        ),
        child: child,
      ),
    ),
  );
}

/// Gold hairline divider.
Widget goldDivider(CcTheme t) => Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            t.gold.withValues(alpha: 0.0),
            t.gold.withValues(alpha: 0.8),
            t.gold.withValues(alpha: 0.0),
          ],
        ),
      ),
    );

/// A single glossy porcelain marble, painted — used for menus, plaques,
/// standings and the hero. Motif follows the chosen marble style.
class MarbleDot extends StatelessWidget {
  final Color base;
  final double size;
  final bool selected;
  final String style;
  final CcTheme? theme;

  const MarbleDot({
    super.key,
    required this.base,
    this.size = 44,
    this.selected = false,
    this.style = 'qinghua',
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: t.goldBright, width: 2.5)
            : Border.all(
                color: t.goldOxidized.withValues(alpha: 0.7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: Offset(0, size * 0.14),
            blurRadius: size * 0.28,
          ),
        ],
      ),
      child: CustomPaint(
          painter: _MarbleFacePainter(base: base, style: style)),
    );
  }
}

class _MarbleFacePainter extends CustomPainter {
  final Color base;
  final String style;
  _MarbleFacePainter({required this.base, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    paintMarbleFace(canvas, size.center(Offset.zero), size.width / 2, base,
        style);
  }

  @override
  bool shouldRepaint(covariant _MarbleFacePainter old) =>
      old.base != base || old.style != style;
}

/// Paints a glossy porcelain marble face with a style-specific motif.
/// Shared by the 2D MarbleDot and the 3D board painter.
void paintMarbleFace(
    Canvas canvas, Offset c, double r, Color base, String style) {
  final hsl = HSLColor.fromColor(base);
  final dark =
      hsl.withLightness((hsl.lightness * 0.45).clamp(0.0, 1.0)).toColor();
  final light = hsl
      .withLightness((hsl.lightness + (1 - hsl.lightness) * 0.55)
          .clamp(0.0, 1.0))
      .toColor();
  canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.42, -0.48),
          radius: 1.25,
          colors: [light, base, dark],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)));
  final lum = base.computeLuminance();
  final motif = (lum > 0.45
          ? const Color(0xFF1E3A8A)
          : const Color(0xFFF9F6F0))
      .withValues(alpha: 0.78);
  switch (style) {
    case 'classic':
      break; // pure gloss, no motif
    case 'ivory-bone':
      canvas.drawCircle(
          c,
          r * 0.55,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.0, r * 0.05)
            ..color = motif);
      canvas.drawCircle(c, r * 0.10, Paint()..color = motif);
      break;
    case 'crackle':
      // Deterministic crackle lines from the base color hash.
      final rnd = Random(base.toARGB32());
      for (int i = 0; i < 6; i++) {
        final a = rnd.nextDouble() * 2 * pi;
        final r0 = r * (0.25 + rnd.nextDouble() * 0.3);
        final r1 = r * (0.6 + rnd.nextDouble() * 0.35);
        canvas.drawLine(
            c + Offset(cos(a) * r0, sin(a) * r0),
            c + Offset(cos(a + 0.5) * r1, sin(a + 0.5) * r1),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(1.0, r * 0.045)
              ..color = motif.withValues(alpha: 0.6));
      }
      break;
    case 'jade':
      for (int i = 0; i < 3; i++) {
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * (0.3 + i * 0.2)),
            i * 1.1,
            3.6,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(1.0, r * 0.06)
              ..strokeCap = StrokeCap.round
              ..color = motif);
      }
      break;
    case 'cloisonne':
      for (int i = 0; i < 6; i++) {
        final a = i * 2 * pi / 6;
        canvas.drawCircle(
            c + Offset(cos(a) * r * 0.38, sin(a) * r * 0.38),
            r * 0.20,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(1.0, r * 0.05)
              ..color = motif);
      }
      canvas.drawCircle(c, r * 0.12, Paint()..color = motif);
      break;
    case 'lacquer-red':
      for (final rr in [0.62, 0.42]) {
        canvas.drawCircle(
            c,
            r * rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(1.0, r * 0.06)
              ..color = motif);
      }
      break;
    case 'obsidian':
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.55),
          -0.6,
          2.2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.5, r * 0.10)
            ..strokeCap = StrokeCap.round
            ..color = motif.withValues(alpha: 0.85));
      break;
    case 'pearl':
      for (int i = 0; i < 8; i++) {
        final a = i * 0.9;
        final rr = r * 0.12 * i / 2;
        canvas.drawCircle(
            c + Offset(cos(a) * rr, sin(a) * rr),
            r * 0.07,
            Paint()..color = motif);
      }
      break;
    case 'copper':
      for (int row = -1; row <= 1; row++) {
        for (int col = -1; col <= 1; col++) {
          final o = Offset(col * r * 0.32, row * r * 0.32);
          if (o.distance <= r * 0.72) {
            canvas.drawCircle(c + o, r * 0.07, Paint()..color = motif);
          }
        }
      }
      break;
    case 'qinghua':
    default:
      for (int i = 0; i < 5; i++) {
        final a = i * 2 * pi / 5 - pi / 2;
        canvas.drawCircle(
            c + Offset(cos(a) * r * 0.34, sin(a) * r * 0.34),
            r * 0.13,
            Paint()..color = motif);
      }
      canvas.drawCircle(c, r * 0.10, Paint()..color = motif);
      break;
  }
  // Crescent specular highlight, top-left (warm key light).
  canvas.drawOval(
      Rect.fromCenter(
          center: c + Offset(-r * 0.34, -r * 0.4),
          width: r * 0.52,
          height: r * 0.34),
      Paint()..color = Colors.white.withValues(alpha: 0.85));
}

/// Faint silk-brocade diamond lattice background.
class BrocadeBackground extends StatelessWidget {
  final Widget child;
  final CcTheme? theme;
  const BrocadeBackground({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = _th(theme);
    return Container(
      color: t.silk,
      child: CustomPaint(
        painter: _BrocadePainter(theme: t),
        child: child,
      ),
    );
  }
}

class _BrocadePainter extends CustomPainter {
  final CcTheme theme;
  _BrocadePainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.gold.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 46.0;
    for (double y = -step; y < size.height + step; y += step) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y + size.width * 0.35), paint);
      canvas.drawLine(
          Offset(0, y + size.width * 0.35), Offset(size.width, y), paint);
    }
    final c = Paint()..color = theme.gold.withValues(alpha: 0.16);
    for (final o in [
      const Offset(18, 18),
      Offset(size.width - 18, 18),
      Offset(18, size.height - 18),
      Offset(size.width - 18, size.height - 18),
    ]) {
      canvas.drawCircle(o, 3, c);
    }
  }

  @override
  bool shouldRepaint(covariant _BrocadePainter old) =>
      old.theme.id != theme.id;
}
