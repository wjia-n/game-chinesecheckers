import 'package:flutter/material.dart';
import '../audio/sound_engine.dart';
import '../state/settings.dart';
import '../theme/cc_themes.dart';
import 'widgets.dart';

/// Custom theme creator (PRO): pick colors for the silk canvas, lacquer
/// board, gold inlay, ivory text and all six marble colors. Everything is
/// persisted; the "My Creation" theme applies it everywhere instantly.
class CustomThemeScreen extends StatelessWidget {
  final AppSettings settings;
  final SoundEngine sound;

  const CustomThemeScreen(
      {super.key, required this.settings, required this.sound});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) {
        final t = settings.theme;
        final keys = CcThemes.customColorLabels.keys.toList();
        return Scaffold(
          backgroundColor: t.silk,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: t.goldBright),
              onPressed: () {
                sound.play(SfxKind.click);
                Navigator.of(context).pop();
              },
            ),
            title: Text('Custom Theme Creator',
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: t.ivory)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
            child: Column(
              children: [
                SilkTray(
                  theme: t,
                  child: Row(
                    children: [
                      for (int i = 0; i < 6; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3),
                            child: MarbleDot(
                              base: Color(settings
                                      .customColors['m$i'] ??
                                  0xFF8B1E1E),
                              size: 44,
                              style: settings.marbleStyleId,
                              theme: t,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final key in keys)
                  _ColorRow(
                    label: CcThemes.customColorLabels[key]!,
                    color: Color(settings.customColors[key] ??
                        0xFF8B1E1E),
                    theme: t,
                    onPick: (argb) {
                      sound.play(SfxKind.select);
                      settings.setCustomColor(key, argb);
                      settings.setTheme('custom');
                    },
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: LacquerButton(
                    text: 'Reset My Creation',
                    theme: t,
                    fontSize: 15,
                    onPressed: () {
                      sound.play(SfxKind.click);
                      settings.resetCustomColors();
                      settings.setTheme('custom');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final Color color;
  final CcTheme theme;
  final ValueChanged<int> onPick;

  const _ColorRow({
    required this.label,
    required this.color,
    required this.theme,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SilkTray(
      theme: t,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(
                      color: t.goldOxidized.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      color: t.ivory)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in CcThemes.swatches)
                GestureDetector(
                  onTap: () => onPick(s),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(s),
                      border: Border.all(
                        color: color.toARGB32() == s
                            ? t.goldBright
                            : Colors.white.withValues(alpha: 0.25),
                        width:
                            color.toARGB32() == s ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
