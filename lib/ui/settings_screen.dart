import 'package:flutter/material.dart';
import '../audio/sound_engine.dart';
import '../engine/game.dart';
import '../state/settings.dart';
import '../theme/imperial.dart';
import 'widgets.dart';

/// Settings: stacked porcelain cards — Audio, Gameplay, Reset.
class SettingsScreen extends StatelessWidget {
  final AppSettings settings;
  final SoundEngine sound;

  const SettingsScreen(
      {super.key, required this.settings, required this.sound});

  void _sync() {
    sound.applySettings(
      musicOn: settings.musicOn,
      sfxOn: settings.sfxOn,
      musicVolume: settings.musicVolume,
      sfxVolume: settings.sfxVolume,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Imperial.ivory),
            onPressed: () {
              sound.play(SfxKind.click);
              Navigator.pop(context);
            },
          ),
          title: Text('SETTINGS', style: Imperial.label(18)),
          centerTitle: true,
        ),
        body: BrocadeBackground(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // ---- Audio card ----
              SilkTray(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AUDIO', style: Imperial.label(14)),
                    Imperial.divider(),
                    SettingRow(
                      title: 'Music',
                      subtitle: 'Ceremonial ambient bed',
                      control: BeadToggle(
                        value: settings.musicOn,
                        onChanged: (v) {
                          settings.setMusicOn(v);
                          _sync();
                          sound.play(SfxKind.click);
                        },
                      ),
                    ),
                    if (settings.musicOn)
                      MarbleSlider(
                        value: settings.musicVolume,
                        onChanged: (v) {
                          settings.setMusicVolume(v);
                          _sync();
                        },
                      ),
                    SettingRow(
                      title: 'Sound Effects',
                      subtitle: 'Ceramic toks & wooden knocks',
                      control: BeadToggle(
                        value: settings.sfxOn,
                        onChanged: (v) {
                          settings.setSfxOn(v);
                          _sync();
                          sound.play(SfxKind.click);
                        },
                      ),
                    ),
                    if (settings.sfxOn)
                      MarbleSlider(
                        value: settings.sfxVolume,
                        onChanged: (v) {
                          settings.setSfxVolume(v);
                          _sync();
                          sound.play(SfxKind.click);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ---- Gameplay card ----
              SilkTray(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GAMEPLAY', style: Imperial.label(14)),
                    Imperial.divider(),
                    Text('Bot difficulty',
                        style: Imperial.body(16, color: Imperial.ivory)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final d in Difficulty.values)
                          ChoiceChip(
                            label: Text(difficultyName(d)),
                            selected: settings.aiDifficulty == d,
                            onSelected: (_) {
                              settings.setDifficulty(d);
                              sound.play(SfxKind.click);
                            },
                            selectedColor: Imperial.cinnabar,
                            backgroundColor: Imperial.silkLow,
                            labelStyle: Imperial.body(
                              13,
                              color: settings.aiDifficulty == d
                                  ? Imperial.ivory
                                  : Imperial.ivoryText
                                      .withValues(alpha: 0.7),
                            ),
                            side: BorderSide(
                              color: settings.aiDifficulty == d
                                  ? Imperial.gold
                                  : Imperial.goldOxidized
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SealCheck(
                      value: settings.forwardProgress,
                      onChanged: (v) {
                        settings.setForwardProgress(v);
                        sound.play(SfxKind.click);
                      },
                      label:
                          'Forward progress — marbles may not drift away from home unless no forward move exists',
                    ),
                    const SizedBox(height: 10),
                    SealCheck(
                      value: settings.symmetricVariant,
                      onChanged: (v) {
                        settings.setSymmetricVariant(v);
                        sound.play(SfxKind.click);
                      },
                      label:
                          'Symmetric 2-player — each player commands two colors (four arms)',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'New games use these rules. Changes apply to the next game you start.',
                      style: Imperial.body(12,
                          color: Imperial.ivoryText
                              .withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: LacquerButton(
                  text: 'Reset to Defaults',
                  fontSize: 15,
                  onPressed: () {
                    settings.resetDefaults();
                    _sync();
                    sound.play(SfxKind.click);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
