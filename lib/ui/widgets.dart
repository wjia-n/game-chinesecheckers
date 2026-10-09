import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/imperial.dart';

/// Shared Imperial Porcelain widgets: plaques, lacquer buttons, porcelain
/// bead toggles, marble-knob sliders, seal checkboxes, dialogs.

/// Ivory porcelain plaque with dual-line gold border.
class PorcelainPlaque extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const PorcelainPlaque({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: Imperial.plaque(radius: radius),
      child: child,
    );
  }
}

/// Dark silk tray card.
class SilkTray extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const SilkTray({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: Imperial.tray(radius: radius),
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

  const LacquerButton({
    super.key,
    required this.text,
    this.onPressed,
    this.fontSize = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
  });

  @override
  State<LacquerButton> createState() => _LacquerButtonState();
}

class _LacquerButtonState extends State<LacquerButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
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
                ? [Imperial.cinnabar, Imperial.cinnabarDeep]
                : [const Color(0xFF4A2020), const Color(0xFF331414)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Imperial.gold.withValues(alpha: enabled ? 0.9 : 0.4),
              width: 1.4),
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
          style: Imperial.label(widget.fontSize,
              color: enabled ? Imperial.ivory : Imperial.ivory.withValues(alpha: 0.4)),
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

  const PorcelainButton(
      {super.key, required this.text, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Imperial.ivory, Imperial.ivoryShade],
          ),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Imperial.goldOxidized.withValues(alpha: 0.9)),
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
              Icon(icon, color: Imperial.cinnabarDeep, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              text.toUpperCase(),
              style: Imperial.label(15, color: Imperial.cinnabarDeep),
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

  const BeadToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 62,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? Imperial.cinnabarDeep : Imperial.silkLow,
          border: Border.all(color: Imperial.goldOxidized, width: 1.5),
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
                  gradient: const RadialGradient(
                    center: Alignment(-0.35, -0.4),
                    radius: 1.1,
                    colors: [Color(0xFFFFFFFF), Imperial.ivoryShade],
                  ),
                  border: Border.all(color: Imperial.gold, width: 1.2),
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

  const MarbleSlider(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        activeTrackColor: Imperial.cinnabar,
        inactiveTrackColor: Imperial.silkLow,
        thumbShape: const _MarbleThumb(),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        overlayColor: Imperial.gold.withValues(alpha: 0.25),
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _MarbleThumb extends SliderComponentShape {
  const _MarbleThumb();

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
    canvas.drawCircle(
        center + const Offset(1.5, 2.5),
        r,
        Paint()..color = const Color(0x88000000));
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.45),
            radius: 1.15,
            colors: [Colors.white, Imperial.ivoryShade, Imperial.goldOxidized],
          ).createShader(Rect.fromCircle(center: center, radius: r)));
    canvas.drawCircle(
        center + const Offset(-4, -5),
        3.4,
        Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Imperial.gold);
  }
}

/// Cinnabar seal-stamp checkbox with a gold brushmark.
class SealCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const SealCheck(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.label});

  @override
  Widget build(BuildContext context) {
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
              color: value ? Imperial.cinnabar : Imperial.silkLow,
              border: Border.all(color: Imperial.gold, width: 1.4),
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
                ? const Icon(Icons.check,
                    color: Imperial.goldBright, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Imperial.body(15, color: Imperial.ivoryText)),
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

  const SettingRow(
      {super.key, required this.title, this.subtitle, required this.control});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Imperial.body(16, color: Imperial.ivory)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: Imperial.body(12.5,
                          color: Imperial.ivoryText
                              .withValues(alpha: 0.65))),
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
Future<T?> imperialDialog<T>(BuildContext context, Widget child) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: Imperial.lacquer(radius: 18),
        child: child,
      ),
    ),
  );
}

/// A single glossy porcelain marble, painted — used for menus, plaques,
/// standings and the hero.
class MarbleDot extends StatelessWidget {
  final Color base;
  final double size;
  final bool selected;

  const MarbleDot(
      {super.key, required this.base, this.size = 44, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: Imperial.goldBright, width: 2.5)
            : Border.all(
                color: Imperial.goldOxidized.withValues(alpha: 0.7),
                width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: Offset(0, size * 0.14),
            blurRadius: size * 0.28,
          ),
        ],
      ),
      child: CustomPaint(painter: _MarbleFacePainter(base: base)),
    );
  }
}

class _MarbleFacePainter extends CustomPainter {
  final Color base;
  _MarbleFacePainter({required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final dark = Imperial.marbleDark(base);
    final light = Imperial.marbleLight(base);
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
    // Qinghua motif: five petals in contrast porcelain.
    final motif = Imperial.motifOn(base).withValues(alpha: 0.75);
    for (int i = 0; i < 5; i++) {
      final a = i * 2 * 3.14159 / 5 - 1.5708;
      canvas.drawCircle(
          c + Offset(cos(a) * r * 0.34, sin(a) * r * 0.34),
          r * 0.13,
          Paint()..color = motif);
    }
    canvas.drawCircle(c, r * 0.1, Paint()..color = motif);
    // Crescent specular highlight, top-left.
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(-r * 0.34, -r * 0.4),
            width: r * 0.52,
            height: r * 0.34),
        Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant _MarbleFacePainter old) => old.base != base;
}

/// Faint silk-brocade diamond lattice background.
class BrocadeBackground extends StatelessWidget {
  final Widget child;
  const BrocadeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Imperial.silk,
      child: CustomPaint(
        painter: _BrocadePainter(),
        child: child,
      ),
    );
  }
}

class _BrocadePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Imperial.gold.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 46.0;
    for (double y = -step; y < size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width * 0.35), paint);
      canvas.drawLine(Offset(0, y + size.width * 0.35), Offset(size.width, y), paint);
    }
    // Corner ornaments.
    final c = Paint()..color = Imperial.gold.withValues(alpha: 0.16);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
