// The playable screen: boots the engine, runs the fixed-step loop, paints the
// world and hosts the HUD, touch controls and panels.
// Replaces the WebView host (game js/android-main.js).
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../engine/content.dart';
import '../engine/engine.dart';
import '../engine/entities.dart';
import '../engine/save.dart';
import '../render/art.dart';
import '../render/renderer.dart';
import 'audio_engine.dart';
import 'controls.dart';
import 'hud.dart';
import 'save_store.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.stage, required this.skin, this.lightMode = true});
  final int stage, skin;

  /// Cheaper image filtering for older phones.
  final bool lightMode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _step = 1 / 60;

  final ArtLibrary _art = ArtLibrary();
  final AudioEngine _audio = AudioEngine.instance;
  late final WorldRenderer _renderer = WorldRenderer(_art, quality: widget.lightMode ? FilterQuality.low : FilterQuality.medium);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_onTick);
  final FocusNode _focus = FocusNode();

  SkyrootEngine? _engine;
  Duration _last = Duration.zero;
  double _acc = 0;
  bool _tutorial = true, _paused = false, _mapOpen = false, _wardrobeOpen = false, _suspended = false, _muted = false;
  String? _fatal;
  Offset? _joy;
  final Set<LogicalKeyboardKey> _keys = {};

  bool get _frozen => _suspended || _tutorial || _paused || _mapOpen || _wardrobeOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio.start();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _boot();
  }

  Future<void> _boot() async {
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/game/maps.json')) as List;
      final maps = raw.map((m) => (m as List).cast<String>()).toList();
      final saved = await SaveStore.load() ?? Progress();
      saved.area = widget.stage.clamp(0, saved.unlocked);
      if (saved.skinOwned(widget.skin)) saved.skin = widget.skin;
      await _art.loadCore();
      if (!mounted) return;
      final e = SkyrootEngine(maps: maps, saved: saved)
        ..onSfx = ((name, flag) => _audio.play(name, loud: flag))
        ..onPersist = ((p) => SaveStore.save(p))
        ..onHaptic = ((_) => HapticFeedback.lightImpact())
        ..onArea = ((_) => _audio.setArea(_engine?.progress.area ?? 0))
        ..loadAssets = ((area, skin) async {
          await Future.wait([_art.ensureArea(area), _art.ensureSkin(skin)]);
          _art.retain(area, skin);
        })
        ..prefetchArea = ((a) => _art.ensureArea(a).catchError((Object _) {}))
        ..addListener(_onEngineChanged);
      _engine = e;
      e.uiBlocking = true;
      e.buildRun();
      _ticker.start();
      setState(() {});
    } catch (error, stack) {
      debugPrint('Skyroot boot failed: $error\n$stack');
      if (mounted) setState(() => _fatal = error.toString());
    }
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  // Music keeps playing under menus; only the app going to the background pauses it (main.dart).
  void _sync() {
    _engine?.uiBlocking = _frozen;
  }

  void _resetInput() {
    final e = _engine;
    if (e == null) return;
    _keys.clear();
    _joy = null;
    e.input
      ..jumpHeld = false
      ..bowHeld = false
      ..clearEdges();
    e.state.player.aiming = false;
  }

  void _setFlags({bool? tutorial, bool? paused, bool? map, bool? wardrobe}) {
    setState(() {
      _tutorial = tutorial ?? _tutorial;
      _paused = paused ?? _paused;
      _mapOpen = map ?? _mapOpen;
      _wardrobeOpen = wardrobe ?? _wardrobeOpen;
    });
    _resetInput();
    _last = Duration.zero;
    _acc = 0;
    if (_frozen) {
      final e = _engine;
      if (e != null) SaveStore.save(e.progress);
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away = state != AppLifecycleState.resumed;
    if (away == _suspended) return;
    _suspended = away;
    if (away) {
      _resetInput();
      final e = _engine;
      if (e != null) SaveStore.save(e.progress);
    }
    _last = Duration.zero;
    _acc = 0;
    _sync();
  }

  // ---- Loop
  void _onTick(Duration elapsed) {
    final e = _engine;
    if (e == null) return;
    final dt = _last == Duration.zero ? 0.0 : math.min((elapsed - _last).inMicroseconds / 1e6, 0.1);
    _last = elapsed;
    if (!_frozen) {
      _acc += dt;
      while (_acc >= _step) {
        _applyInput(e);
        e.update(_step);
        _acc -= _step;
      }
    }
    _frame.value++;
  }

  void _applyInput(SkyrootEngine e) {
    final i = e.input;
    final kx = (_keys.any(_right.contains) ? 1.0 : 0.0) - (_keys.any(_left.contains) ? 1.0 : 0.0);
    final ky = (_keys.any(_down.contains) ? 1.0 : 0.0) - (_keys.any(_up.contains) ? 1.0 : 0.0);
    final joy = _joy;
    if (joy != null) {
      i.mx = joy.dx.abs() < 0.22 ? 0 : joy.dx;
      i.my = joy.dy;
    } else {
      i.mx = kx;
      i.my = ky;
    }
  }

  // ---- Keyboard (desktop / emulator testing)
  static final _left = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA};
  static final _right = {LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD};
  static final _up = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW};
  static final _down = {LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS};
  static final _jump = {LogicalKeyboardKey.space, LogicalKeyboardKey.keyK};
  static final _dash = {LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight, LogicalKeyboardKey.keyL};
  static final _swap = {LogicalKeyboardKey.keyQ, LogicalKeyboardKey.keyE};

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final e = _engine;
    if (e == null) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final i = e.input;
    if (event is KeyDownEvent) {
      if (_jump.contains(k)) {
        i.jumpPressed = true;
        i.jumpHeld = true;
      } else if (_dash.contains(k)) {
        i.dashPressed = true;
      } else if (_swap.contains(k)) {
        i.switchPressed = true;
      } else if (k == LogicalKeyboardKey.keyR) {
        i.skillPressed = true;
      } else if (k == LogicalKeyboardKey.keyM) {
        _setFlags(map: !_mapOpen);
      } else if (k == LogicalKeyboardKey.escape) {
        _back();
      } else if (_up.contains(k)) {
        i.upPressed = true;
      } else if (k == LogicalKeyboardKey.keyJ) {
        i
          ..bowDown = true
          ..bowHeld = true
          ..aimSource = 'key';
      }
      _keys.add(k);
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _keys.remove(k);
      if (_jump.contains(k)) i.jumpHeld = false;
      if (k == LogicalKeyboardKey.keyJ && i.aimSource == 'key' && i.bowHeld) {
        i
          ..bowHeld = false
          ..bowReleased = true;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- Navigation
  void _back() {
    if (_engine == null || _fatal != null) {
      _home();
    } else if (_tutorial) {
      _closeTutorial();
    } else if (_mapOpen || _wardrobeOpen) {
      _setFlags(map: false, wardrobe: false);
    } else {
      _setFlags(paused: !_paused);
    }
  }

  void _closeTutorial() {
    _setFlags(tutorial: false);
  }

  void _home() {
    final e = _engine;
    if (e != null) SaveStore.save(e.progress);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _focus.dispose();
    _engine?.dispose();
    // Back in the menu: return to the menu track.
    _audio.setArea(0);
    _art.dispose();
    _frame.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = _engine;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07130F),
        body: _fatal != null
            ? _fatalView()
            : e == null
                ? LoadingView(message: 'Menyiapkan hutan…', error: false, onRetry: () {})
                : Focus(autofocus: true, focusNode: _focus, onKeyEvent: _onKey, child: _gameView(e)),
      ),
    );
  }

  Widget _fatalView() => PanelShell(
        title: 'Game gagal dimuat',
        child: Column(mainAxisSize: MainAxisSize.min, spacing: 12, children: [
          Text(_fatal!, style: const TextStyle(color: Color(0xbce1eee2))),
          GameButton(label: 'MENU UTAMA', primary: true, onTap: _home),
        ]),
      );

  Widget _gameView(SkyrootEngine e) {
    final s = e.state;
    final loading = s.phase == 'loading';
    return LayoutBuilder(builder: (context, box) {
      e.view
        ..w = box.maxWidth
        ..h = box.maxHeight
        ..scale = math.max(20.0, math.min(54.0, math.min(box.maxWidth / 13, box.maxHeight / 16.5)));
      return Stack(
        fit: StackFit.expand,
        children: [
          // The world, aimed with the mouse on desktop.
          Listener(
            onPointerDown: (ev) {
              if (ev.kind != PointerDeviceKind.mouse || ev.buttons != kPrimaryMouseButton || _frozen) return;
              e.input
                ..bowDown = true
                ..bowHeld = true
                ..aimSource = 'pointer'
                ..pointerX = ev.localPosition.dx
                ..pointerY = ev.localPosition.dy;
            },
            onPointerMove: (ev) {
              if (ev.kind == PointerDeviceKind.mouse) {
                e.input
                  ..pointerX = ev.localPosition.dx
                  ..pointerY = ev.localPosition.dy;
              }
            },
            onPointerUp: (ev) {
              if (ev.kind == PointerDeviceKind.mouse && e.input.aimSource == 'pointer' && e.input.bowHeld) {
                e.input
                  ..bowHeld = false
                  ..bowReleased = true;
              }
            },
            child: CustomPaint(painter: _WorldPainter(e, _renderer, _art, _frame), size: Size.infinite),
          ),
          if (!loading && s.phase != 'ending') ...[
            ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (_, _, _) => HudLayer(
                engine: e,
                onPause: () => _setFlags(paused: true),
                onMap: () => _setFlags(map: true),
                onWardrobe: () => _setFlags(wardrobe: true),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (_, _, _) => TouchControls(engine: e, onJoystick: (v) => _joy = v),
            ),
          ],
          if (_mapOpen && !loading)
            MapPanel(
              engine: e,
              onClose: () => _setFlags(map: false),
              onReset: () {
                e.resetProgress();
                _setFlags(map: false);
              },
            ),
          if (_wardrobeOpen && !loading) WardrobePanel(engine: e, art: _art, onClose: () => _setFlags(wardrobe: false)),
          if (_paused)
            PauseMenu(
              muted: _muted,
              onResume: () => _setFlags(paused: false),
              onRespawn: () {
                e.respawn();
                _setFlags(paused: false);
              },
              onMap: () => _setFlags(paused: false, map: true),
              onSound: () {
                setState(() => _muted = !_muted);
                _audio.setMuted(_muted);
              },
              onHelp: () => _setFlags(paused: false, tutorial: true),
              onHome: _home,
            ),
          if (_tutorial && !loading) TutorialCard(onPlay: _closeTutorial),
          if (s.phase == 'ending')
            EndPanel(progress: e.progress, onContinue: e.continueAfterEnding, onRestart: e.resetProgress),
          if (loading)
            LoadingView(
              message: s.loadingError != null
                  ? 'Gagal memuat ${areas[s.areaIndex].name}. Ketuk di sini untuk coba lagi.'
                  : 'Memuat ${areas[s.areaIndex].name} · ${skins[e.progress.skin].name}…',
              error: s.loadingError != null,
              onRetry: e.retryLoad,
            ),
        ],
      );
    });
  }
}

class _WorldPainter extends CustomPainter {
  _WorldPainter(this.engine, this.renderer, this.art, Listenable repaint) : super(repaint: repaint);
  final SkyrootEngine engine;
  final WorldRenderer renderer;
  final ArtLibrary art;

  @override
  void paint(Canvas canvas, Size size) {
    final s = engine.state;
    if (s.phase == 'loading' || art.atlas == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF07130F));
      return;
    }
    var cam = s.cam;
    if (s.shake > 0) {
      // Gentle nudge only: the camera sways a few hundredths of a tile.
      final k = s.shake * 0.08;
      cam = Cam(cam.x + math.sin(s.t * 91) * k, cam.y + math.cos(s.t * 77) * k, snap: false, zoom: cam.zoom);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    renderer.draw(canvas, size, engine, camOverride: cam);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WorldPainter old) => true;
}
