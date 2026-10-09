import 'package:flutter/material.dart';
import '../audio/sound_engine.dart';
import '../services/iap_service.dart';
import '../state/settings.dart';
import 'menu_screen.dart';

/// Launch splash (single): WAJIHA company moment, then the game logo +
/// game name + animated loading line + "Credits: WAJIHA".
/// Audio is pre-warmed here so menu music starts instantly.
class SplashScreen extends StatefulWidget {
  final AppSettings settings;
  final SoundEngine sound;
  final StoreService store;

  const SplashScreen(
      {super.key,
      required this.settings,
      required this.sound,
      required this.store});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _run();
  }

  Future<void> _run() async {
    widget.sound.prewarm(); // fire-and-forget: builds music beds in isolate
    widget.sound.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          settings: widget.settings,
          sound: widget.sound,
          store: widget.store,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    return Scaffold(
      backgroundColor: t.silk,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Company moment: the official WAJIHA logo (never redrawn).
            Image.asset(
              'assets/wajiha_logo.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 6),
            Text(
              'WAJIHA',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 15,
                letterSpacing: 8,
                fontWeight: FontWeight.w600,
                color: t.gold,
              ),
            ),
            const SizedBox(height: 34),
            // Game logo.
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: t.gold, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/cc_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text(
              'CHINESE CHECKERS',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: t.ivory,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'THE IMPERIAL PORCELAIN EDITION',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
                color: t.goldOxidized,
              ),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: _loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: t.gold.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [t.goldBright, t.gold],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _loader.value < 1
                          ? 'Polishing the porcelain…'
                          : 'Ready!',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 13,
                        color: t.ivory.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: t.gold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
