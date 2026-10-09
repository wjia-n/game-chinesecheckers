import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio/sound_engine.dart';
import 'services/iap_service.dart';
import 'state/settings.dart';
import 'ui/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = AppSettings();
  await settings.load();
  final sound = SoundEngine();
  await sound.init(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    musicVolume: settings.musicVolume,
    sfxVolume: settings.sfxVolume,
  );
  // Keep audio in sync when settings change from any screen.
  settings.addListener(() {
    sound.applySettings(
      musicOn: settings.musicOn,
      sfxOn: settings.sfxOn,
      musicVolume: settings.musicVolume,
      sfxVolume: settings.sfxVolume,
    );
  });
  final store = StoreService();
  // Store init is best-effort and must never block launch.
  unawaited(store.init());
  runApp(ChineseCheckersApp(
      settings: settings, sound: sound, store: store));
}

class ChineseCheckersApp extends StatefulWidget {
  final AppSettings settings;
  final SoundEngine sound;
  final StoreService store;

  const ChineseCheckersApp({
    super.key,
    required this.settings,
    required this.sound,
    required this.store,
  });

  @override
  State<ChineseCheckersApp> createState() => _ChineseCheckersAppState();
}

class _ChineseCheckersAppState extends State<ChineseCheckersApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.sound.dispose();
    widget.store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause music on interruption/backgrounding; resume exactly where it
    // left off. Music never silently dies.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      widget.sound.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.sound.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) {
        final t = widget.settings.theme;
        return MaterialApp(
          title: 'Chinese Checkers',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: t.silk.computeLuminance() > 0.4
                ? Brightness.light
                : Brightness.dark,
            scaffoldBackgroundColor: t.silk,
            colorScheme: ColorScheme(
              brightness: t.silk.computeLuminance() > 0.4
                  ? Brightness.light
                  : Brightness.dark,
              primary: t.lacquer,
              onPrimary: t.ivory,
              secondary: t.gold,
              onSecondary: t.silk,
              surface: t.silkRaised,
              onSurface: t.ivory,
              error: const Color(0xFFB00020),
              onError: t.ivory,
            ),
          ),
          home: SplashScreen(
            settings: widget.settings,
            sound: widget.sound,
            store: widget.store,
          ),
        );
      },
    );
  }
}
