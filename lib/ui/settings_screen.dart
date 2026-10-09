import 'package:flutter/material.dart';
import '../audio/sound_engine.dart';
import '../engine/game.dart';
import '../state/settings.dart';
import '../theme/cc_themes.dart';
import 'custom_theme_screen.dart';
import 'widgets.dart';

/// Settings: porcelain cards for Audio, Players (renameable slots),
/// Table (themes, marble styles, board accents, custom creator),
/// Game rules, and Reset.
class SettingsScreen extends StatelessWidget {
  final AppSettings settings;
  final SoundEngine sound;

  const SettingsScreen(
      {super.key, required this.settings, required this.sound});

  CcTheme _t() => settings.theme;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) {
        final t = _t();
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
            title: Text('Settings',
                style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: t.ivory)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
            child: Column(
              children: [
                _card(t, 'AUDIO', [
                  SettingRow(
                    title: 'Music',
                    subtitle: 'Menu & gameplay beds',
                    theme: t,
                    control: BeadToggle(
                      value: settings.musicOn,
                      theme: t,
                      onChanged: (v) => settings.setMusicOn(v),
                    ),
                  ),
                  SettingRow(
                    title: 'Sound effects',
                    subtitle: 'Ceramic toks & knocks',
                    theme: t,
                    control: BeadToggle(
                      value: settings.sfxOn,
                      theme: t,
                      onChanged: (v) => settings.setSfxOn(v),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _sliderLabel('Music volume', t),
                  MarbleSlider(
                    value: settings.musicVolume,
                    theme: t,
                    onChanged: (v) => settings.setMusicVolume(v),
                  ),
                  _sliderLabel('Effects volume', t),
                  MarbleSlider(
                    value: settings.sfxVolume,
                    theme: t,
                    onChanged: (v) => settings.setSfxVolume(v),
                  ),
                ]),
                const SizedBox(height: 14),
                _card(t, 'PLAYERS', [
                  Text(
                    'Rename every seat — names appear on trays and in narration.',
                    style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 12.5,
                        color: t.ivory.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 8),
                  for (int seat = 0; seat < 6; seat++)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          MarbleDot(
                            base: t.marbles[seat],
                            size: 30,
                            style: settings.marbleStyleId,
                            theme: t,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _NameField(
                              seat: seat,
                              settings: settings,
                              theme: t,
                            ),
                          ),
                        ],
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                _card(t, 'PORCELAIN THEMES', [
                  _swatchGrid(
                    t,
                    items: [
                      for (final th in CcThemes.all)
                        _SwatchItem(
                          label: th.name,
                          locked:
                              th.pro && !settings.isPro,
                          selected: settings.themeId == th.id,
                          preview: th.marbles[0],
                          ring: th.gold,
                          onTap: () {
                            sound.play(SfxKind.click);
                            settings.setTheme(th.id);
                          },
                        ),
                      _SwatchItem(
                        label: 'My Creation',
                        locked: !settings.isPro,
                        selected: settings.themeId == 'custom',
                        preview:
                            Color(settings.customColors['lacquer'] ??
                                0xFF8B1E1E),
                        ring: t.gold,
                        onTap: () {
                          sound.play(SfxKind.click);
                          if (settings.isPro) {
                            settings.setTheme('custom');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: PorcelainButton(
                      text: settings.isPro
                          ? 'Custom Theme Creator'
                          : 'Custom Creator — PRO',
                      icon: Icons.palette,
                      theme: t,
                      onPressed: settings.isPro
                          ? () {
                              sound.play(SfxKind.click);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomThemeScreen(
                                    settings: settings,
                                    sound: sound,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                _card(t, 'MARBLE STYLES', [
                  _swatchGrid(
                    t,
                    items: [
                      for (final s in CcThemes.marbleStyles)
                        _SwatchItem(
                          label: s.name,
                          locked: s.pro && !settings.isPro,
                          selected:
                              settings.marbleStyleId == s.id,
                          custom: MarbleDot(
                            base: t.marbles[0],
                            size: 34,
                            style: s.id,
                            theme: t,
                          ),
                          onTap: () {
                            sound.play(SfxKind.select);
                            settings.setMarbleStyle(s.id);
                          },
                        ),
                    ],
                  ),
                ]),
                const SizedBox(height: 14),
                _card(t, 'BOARD ACCENTS', [
                  _swatchGrid(
                    t,
                    items: [
                      for (final a in CcThemes.boardAccents)
                        _SwatchItem(
                          label: a.name,
                          locked: a.pro && !settings.isPro,
                          selected:
                              settings.boardAccentId == a.id,
                          preview: a.inlay,
                          ring: a.rim,
                          onTap: () {
                            sound.play(SfxKind.click);
                            settings.setBoardAccent(a.id);
                          },
                        ),
                    ],
                  ),
                ]),
                const SizedBox(height: 14),
                _card(t, 'GAME RULES', [
                  SettingRow(
                    title: 'Default bot difficulty',
                    subtitle: settings.isPro
                        ? 'Applies to new bot seats'
                        : 'Imperial (hard) needs PRO',
                    theme: t,
                    control: GestureDetector(
                      onTap: () {
                        sound.play(SfxKind.click);
                        final cur = settings.aiDifficulty;
                        var next = Difficulty.values[
                            (cur.index + 1) % Difficulty.values.length];
                        if (next == Difficulty.imperial &&
                            !settings.isPro) {
                          next = Difficulty.porcelain;
                        }
                        settings.setDifficulty(next);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: t.goldOxidized
                                  .withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          difficultyName(settings.aiDifficulty)
                              .toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                              color: t.gold),
                        ),
                      ),
                    ),
                  ),
                  SettingRow(
                    title: 'Forward progress',
                    subtitle: 'House rule: no backward stalling',
                    theme: t,
                    control: BeadToggle(
                      value: settings.forwardProgress,
                      theme: t,
                      onChanged: (v) =>
                          settings.setForwardProgress(v),
                    ),
                  ),
                  SettingRow(
                    title: 'Symmetric 2-player variant',
                    subtitle: 'Two humans, four colors each',
                    theme: t,
                    control: BeadToggle(
                      value: settings.symmetricVariant,
                      theme: t,
                      onChanged: (v) =>
                          settings.setSymmetricVariant(v),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: LacquerButton(
                    text: 'Reset to Defaults',
                    theme: t,
                    fontSize: 15,
                    onPressed: () {
                      sound.play(SfxKind.click);
                      settings.resetDefaults();
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

  Widget _card(CcTheme t, String title, List<Widget> children) {
    return SilkTray(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                  color: t.gold)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _sliderLabel(String text, CcTheme t) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text,
          style: TextStyle(
              fontFamily: 'serif',
              fontSize: 13,
              color: t.ivory.withValues(alpha: 0.8))),
    );
  }

  Widget _swatchGrid(CcTheme t, {required List<_SwatchItem> items}) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.82,
      children: items,
    );
  }
}

class _SwatchItem extends StatelessWidget {
  final String label;
  final bool locked;
  final bool selected;
  final Color? preview;
  final Color? ring;
  final Widget? custom;
  final VoidCallback onTap;

  const _SwatchItem({
    required this.label,
    required this.locked,
    required this.selected,
    this.preview,
    this.ring,
    this.custom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? (ring ?? Colors.white)
                          : Colors.white.withValues(alpha: 0.25),
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: (ring ?? Colors.white)
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: custom ??
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: preview,
                        ),
                      ),
                ),
                if (locked)
                  const Icon(Icons.lock_outline,
                      size: 16, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 10,
                  color: Colors.white70),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final int seat;
  final AppSettings settings;
  final CcTheme theme;
  const _NameField(
      {required this.seat, required this.settings, required this.theme});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
        text: widget.settings.playerNames[widget.seat]);
    // Focus-loss commit: persist the final value when the field is
    // dismissed any way other than the keyboard "done" action (tapping
    // elsewhere, back gesture, screen navigation). Belt-and-braces on top
    // of the save-on-keystroke [onChanged] below.
    _focus = FocusNode()
      ..addListener(() {
        if (!_focus.hasFocus) {
          widget.settings.setPlayerName(widget.seat, _c.text);
        }
      });
  }

  @override
  void dispose() {
    // Commit anything pending before the widget goes away.
    widget.settings.setPlayerName(widget.seat, _c.text);
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return TextField(
      controller: _c,
      focusNode: _focus,
      style:
          TextStyle(fontFamily: 'serif', fontSize: 15, color: t.ivory),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: t.goldOxidized.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.goldBright),
        ),
      ),
      onChanged: (v) => widget.settings.setPlayerName(widget.seat, v),
      onEditingComplete: () => widget.settings.setPlayerName(widget.seat, _c.text),
    );
  }
}
