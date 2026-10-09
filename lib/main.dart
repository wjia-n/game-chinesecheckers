import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio/sound_engine.dart';
import 'state/settings.dart';
import 'theme/imperial.dart';
import 'ui/menu_screen.dart';

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
  runApp(ChineseCheckersApp(settings: settings, sound: sound));
}

class ChineseCheckersApp extends StatelessWidget {
  final AppSettings settings;
  final SoundEngine sound;

  const ChineseCheckersApp(
      {super.key, required this.settings, required this.sound});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chinese Checkers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Imperial.silk,
        colorScheme: const ColorScheme.dark(
          primary: Imperial.cinnabar,
          secondary: Imperial.gold,
          surface: Imperial.silk,
        ),
      ),
      home: MenuScreen(settings: settings, sound: sound),
    );
  }
}
