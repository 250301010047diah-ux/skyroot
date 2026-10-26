import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine/content.dart';
import 'engine/save.dart';
import 'game/audio_engine.dart';
import 'game/game_screen.dart';
import 'game/main_menu_view.dart';
import 'game/save_store.dart';

/// The pre-Flutter build kept its save in native storage; read it once to carry progress over.
const legacyProgress = MethodChannel('skyroot/progress');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only: the HUD, joystick and level art are laid out for a tall screen.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  // Music pauses whenever the app leaves the screen, in the menu and in the game alike.
  AppLifecycleListener(
    onHide: AudioEngine.instance.suspend,
    onShow: AudioEngine.instance.resume,
  );
  runApp(const SkyrootApp());
}

class SkyrootApp extends StatelessWidget {
  const SkyrootApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Skyroot The Last Archer',
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xff08151a),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffd8a84e),
        brightness: Brightness.dark,
      ),
    ),
    home: const MainMenu(),
  );
}

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _savedProgress = 0;
  String _selectedTheme = 'backdrop.webp';
  String _selectedSkin = 'archer_a-transparent.webp';
  int _selectedStage = 0;
  bool _hasSave = false;
  bool _lightMode = true;

  static final _areas = [for (final a in areas) a.name];
  static const _themes = [
    ('backdrop.webp', 'assets/images/backdrop.webp'),
    ('bg_1.webp', 'assets/images/bg_1.webp'),
    ('bg_2.webp', 'assets/images/bg_2.webp'),
    ('bg_3.webp', 'assets/images/bg_3.webp'),
    ('bg_4.webp', 'assets/images/bg_4.webp'),
    ('bg_5.webp', 'assets/images/bg_5.webp'),
    ('bg_6.webp', 'assets/images/bg_6.webp'),
    ('bg_7.webp', 'assets/images/bg_7.webp'),
    ('bg_8.webp', 'assets/images/bg_8.webp'),
    ('bg_9.webp', 'assets/images/bg_9.webp'),
    ('bg_10.webp', 'assets/images/bg_10.webp'),
  ];
  static final _skinNames = [for (final s in skins) s.name];
  static const _skins = [
    ('archer_a-transparent.webp', 'assets/images/archer_a-transparent.webp'),
    ('skin1_a-transparent.webp', 'assets/images/skin1_a-transparent.webp'),
    ('skin2_a-transparent.webp', 'assets/images/skin2_a-transparent.webp'),
    ('skin3_a-transparent.webp', 'assets/images/skin3_a-transparent.webp'),
    ('skin4_a-transparent.webp', 'assets/images/skin4_a-transparent.webp'),
    ('skin5_a-transparent.webp', 'assets/images/skin5_a-transparent.webp'),
    ('skin6_a-transparent.webp', 'assets/images/skin6_a-transparent.webp'),
    ('skin7_a-transparent.webp', 'assets/images/skin7_a-transparent.webp'),
    ('skin8_a-transparent.webp', 'assets/images/skin8_a-transparent.webp'),
    ('skin9_a-transparent.webp', 'assets/images/skin9_a-transparent.webp'),
    ('skin10_a-transparent.webp', 'assets/images/skin10_a-transparent.webp'),
  ];

  int get _skinIndex => _skins.indexWhere((item) => item.$1 == _selectedSkin).clamp(0, 10);

  @override
  void initState() {
    super.initState();
    // The menu plays the first track; the game switches tracks per area.
    AudioEngine.instance
      ..setArea(0)
      ..start();
    _loadProgress();
  }

  /// Progress saved by the earlier native build is adopted the first time.
  Future<Progress?> _migrateLegacy() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await legacyProgress.invokeMethod<String>('load');
      if (raw == null) return null;
      final progress = Progress.sanitize(jsonDecode(raw));
      await SaveStore.save(progress);
      await legacyProgress.invokeMethod<void>('reset');
      return progress;
    } on MissingPluginException {
      // Widget tests and fresh installs have no legacy bridge.
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await SaveStore.load() ?? await _migrateLegacy();
    if (!mounted) return;
    setState(() {
      _lightMode = prefs.getBool('lightMode') ?? true;
      _hasSave = saved != null;
      _savedProgress = saved == null ? 0 : (saved.areas.where((a) => a.boss).length * 100 / 11).round();
      _selectedStage = (saved?.area ?? prefs.getInt('stage') ?? 0).clamp(0, 10);
      _selectedTheme = _themes[_selectedStage].$1;
      _selectedSkin = _skins[(saved?.skin ?? 0).clamp(0, 10)].$1;
    });
  }

  Future<void> _selectSkin(String value) async {
    setState(() => _selectedSkin = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skin', value);
  }

  Future<void> _selectLightMode(bool value) async {
    setState(() => _lightMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lightMode', value);
  }

  Future<void> _selectThemeAt(int index) async {
    setState(() {
      _selectedTheme = _themes[index].$1;
      _selectedStage = index;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', _selectedTheme);
    await prefs.setInt('stage', index);
  }

  Future<void> _resetProgress() async {
    await SaveStore.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['progress', 'score', 'savedX', 'savedStage', 'stage', 'theme', 'skin']) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    setState(() {
      _savedProgress = 0;
      _hasSave = false;
      _selectedStage = 0;
      _selectedTheme = _themes.first.$1;
      _selectedSkin = _skins.first.$1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress berhasil direset.')),
    );
  }

  void _startGame() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              stage: _selectedStage,
              skin: _skinIndex,
              lightMode: _lightMode,
            ),
          ),
        )
        .then((_) => _loadProgress());
  }

  @override
  Widget build(BuildContext context) => MainMenuView(
    areas: _areas,
    skinNames: _skinNames,
    themes: _themes,
    stage: _selectedStage,
    skin: _skinIndex,
    progress: _savedProgress,
    hasSave: _hasSave,
    onArea: _selectThemeAt,
    onSkin: (index) => _selectSkin(_skins[index].$1),
    onPlay: _startGame,
    onReset: _resetProgress,
    lightMode: _lightMode,
    onLightMode: _selectLightMode,
  );
}
