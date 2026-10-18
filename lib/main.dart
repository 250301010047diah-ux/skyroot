import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/skyroot_game.dart';
import 'game/controls.dart';
import 'game/original_game_screen.dart';
import 'game/main_menu_view.dart';

bool get usesOriginalGame =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
const originalProgress = MethodChannel('skyroot/progress');

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

  static const _areas = [
    'Akar Berkabut',
    'Kebun Gantung',
    'Kota Kulit Pohon',
    'Rawa Getah',
    'Gua Kristal Akar',
    'Hutan Jamur Senja',
    'Sarang Sutra',
    'Lautan Awan',
    'Reruntuhan Bara',
    'Puncak Beku',
    'Mahkota Bintang',
  ];
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
  static const _skinNames = [
    'Ranger',
    'Pemburu Embun',
    'Penjaga Duri',
    'Pemanah Kembar',
    'Penari Angin',
    'Pemanah Bara',
    'Pemanah Es',
    'Pemanah Badai',
    'Pemanah Bulan',
    'Pemanah Bintang',
    'Mahkota Akar',
  ];
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

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? original;
    if (usesOriginalGame) {
      try {
        final raw = await originalProgress.invokeMethod<String>('load');
        if (raw != null) original = jsonDecode(raw) as Map<String, dynamic>;
      } on MissingPluginException {
        // Widget tests and older native builds have no original-game bridge.
      }
    }
    if (mounted) {
      setState(() {
        _savedProgress = prefs.getInt('progress') ?? 0;
        _lightMode = prefs.getBool('lightMode') ?? true;
        _selectedTheme = prefs.getString('theme') ?? _selectedTheme;
        _selectedSkin = prefs.getString('skin') ?? _selectedSkin;
        _selectedStage = prefs.getInt('stage') ?? _selectedStage;
        _hasSave = _savedProgress > 0;
        if (usesOriginalGame) {
          _hasSave = original != null;
          _savedProgress = 0;
          _selectedStage = 0;
          _selectedTheme = _themes.first.$1;
          _selectedSkin = _skins.first.$1;
        }
        if (original != null) {
          final areas = original['areas'] as List<dynamic>;
          _savedProgress =
              (areas.where((area) => area['boss'] == true).length * 100 / 11)
                  .round();
          _selectedStage = (original['area'] as int).clamp(0, 10);
          _selectedTheme = _themes[_selectedStage].$1;
          _selectedSkin = _skins[(original['skin'] as int).clamp(0, 10)].$1;
        }
        _selectedStage = _selectedStage.clamp(0, 10);
        if (!_themes.any((item) => item.$1 == _selectedTheme)) {
          _selectedTheme = _themes[_selectedStage].$1;
        }
        if (!_skins.any((item) => item.$1 == _selectedSkin)) {
          _selectedSkin = _skins.first.$1;
        }
      });
    }
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
    if (usesOriginalGame) await originalProgress.invokeMethod<void>('reset');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('progress');
    await prefs.remove('score');
    await prefs.remove('savedX');
    await prefs.remove('savedStage');
    if (mounted) {
      setState(() {
        _savedProgress = 0;
        _hasSave = false;
        _selectedStage = 0;
        _selectedTheme = _themes.first.$1;
        _selectedSkin = _skins.first.$1;
      });
      await prefs.setInt('stage', 0);
      await prefs.setString('theme', _themes.first.$1);
      await prefs.setString('skin', _skins.first.$1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress berhasil direset.')),
      );
    }
  }

  void _startGame() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => usesOriginalGame
                ? OriginalGameScreen(
                    lightMode: _lightMode,
                    stage: _selectedStage,
                    skin: _skins
                        .indexWhere((item) => item.$1 == _selectedSkin)
                        .clamp(0, 10),
                  )
                : GameScreen(
                    themeAsset: _selectedTheme,
                    skinAsset: _selectedSkin,
                    stage: _selectedStage,
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
    skin: _skins.indexWhere((item) => item.$1 == _selectedSkin).clamp(0, 10),
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

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.themeAsset,
    required this.skinAsset,
    required this.stage,
  });
  final String themeAsset;
  final String skinAsset;
  final int stage;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final SkyrootGame game;
  bool showTutorial = true;

  @override
  void initState() {
    super.initState();
    game = SkyrootGame(
      onProgressChanged: (_) {},
      themeAsset: widget.themeAsset,
      skinAsset: widget.skinAsset,
      stage: widget.stage,
    );
    game.setPaused(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(
            game: game,
            loadingBuilder: (context) =>
                const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Game gagal dimuat. Coba kembali ke menu dan mulai lagi.\n$error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          _Hud(
            game: game,
            onTutorial: () {
              game.setPaused(true);
              setState(() => showTutorial = true);
            },
          ),
          if (showTutorial)
            _Tutorial(
              onClose: () {
                game.audio.unlock();
                game.setPaused(false);
                setState(() => showTutorial = false);
              },
            ),
        ],
      ),
    ),
  );
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.onTutorial});
  final SkyrootGame game;
  final VoidCallback onTutorial;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: 12,
        right: 12,
        child: Row(
          children: [
            _HudButton(
              icon: game.volumeEnabled ? Icons.volume_up : Icons.volume_off,
              onTap: game.toggleVolume,
            ),
            const SizedBox(width: 8),
            _HudButton(icon: Icons.help_outline_rounded, onTap: onTutorial),
            const SizedBox(width: 8),
            _HudButton(icon: Icons.refresh_rounded, onTap: game.restart),
            const SizedBox(width: 8),
            _HudButton(
              icon: Icons.home_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      Positioned(left: 16, bottom: 18, child: _TouchPad(game: game)),
      Positioned(right: 18, bottom: 22, child: _ActionPad(game: game)),
    ],
  );
}

class _HudButton extends StatelessWidget {
  const _HudButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon)),
    ),
  );
}

class _TouchPad extends StatelessWidget {
  const _TouchPad({required this.game});
  final SkyrootGame game;

  Widget controlButton(GameDirection direction, IconData icon) =>
      GestureDetector(
        onTapDown: (_) => game.setDirection(direction, true),
        onTapUp: (_) => game.setDirection(direction, false),
        onTapCancel: () => game.setDirection(direction, false),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon),
        ),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 164,
    height: 164,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: 0,
          child: controlButton(
            GameDirection.down,
            Icons.keyboard_arrow_down_rounded,
          ),
        ),
        Positioned(
          left: 0,
          child: controlButton(
            GameDirection.left,
            Icons.keyboard_arrow_left_rounded,
          ),
        ),
        Positioned(
          right: 0,
          child: controlButton(
            GameDirection.right,
            Icons.keyboard_arrow_right_rounded,
          ),
        ),
      ],
    ),
  );
}

class _ActionPad extends StatelessWidget {
  const _ActionPad({required this.game});
  final SkyrootGame game;

  Widget button(String action, IconData icon, {double size = 68}) =>
      GestureDetector(
        onTapDown: (_) => game.setAction(action, true),
        onTapUp: (_) => game.setAction(action, false),
        onTapCancel: () => game.setAction(action, false),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: action == 'shoot'
                ? const Color(0xccb95842)
                : const Color(0xccd8a84e),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: size * .45),
        ),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 168,
    height: 140,
    child: Stack(
      alignment: Alignment.bottomRight,
      children: [
        Positioned(
          right: 0,
          bottom: 0,
          child: button('shoot', Icons.adjust_rounded, size: 76),
        ),
        Positioned(
          left: 0,
          bottom: 4,
          child: button('jump', Icons.arrow_upward_rounded, size: 64),
        ),
      ],
    ),
  );
}

class _Tutorial extends StatelessWidget {
  const _Tutorial({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withValues(alpha: .78),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(24),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.explore_rounded,
              size: 48,
              color: Color(0xffd8a84e),
            ),
            const SizedBox(height: 12),
            const Text(
              'TUTORIAL',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bergerak dengan tombol kiri/kanan. Tekan panah atas untuk melompat dan tombol panah di kanan untuk menembak musuh. Ambil orb emas untuk menambah nyawa; kalahkan boss untuk menyelesaikan area.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onClose,
              child: const Text('MULAI BERMAIN'),
            ),
            TextButton(
              onPressed: onClose,
              child: const Text('Lewati tutorial'),
            ),
          ],
        ),
      ),
    ),
  );
}
