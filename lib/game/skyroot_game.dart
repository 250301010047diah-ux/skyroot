import 'dart:math' as math;
import 'dart:ui'
    show
        Canvas,
        Color,
        FilterQuality,
        Image,
        Offset,
        Paint,
        Radius,
        Rect,
        RRect,
        StrokeCap;

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/material.dart'
    show
        Colors,
        FontWeight,
        Shadow,
        TextAlign,
        TextDirection,
        TextPainter,
        TextSpan,
        TextStyle;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_engine.dart';
import 'controls.dart';

class SkyrootGame extends FlameGame with KeyboardEvents {
  SkyrootGame({
    required this.onProgressChanged,
    required this.themeAsset,
    required this.skinAsset,
    this.stage = 0,
  });

  final void Function(int progress) onProgressChanged;
  final String themeAsset;
  final String skinAsset;
  final int stage;

  final AudioEngine audio = AudioEngine();

  static const gravity = 1750.0;
  static const floor = 444.0;
  static const worldEnd = 5900.0;
  static const areas = [
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

  final Set<GameDirection> held = {};
  final Set<String> actions = {};
  final List<FoeData> foes = [];
  final List<ArrowData> arrows = [];
  final List<PickupData> pickups = [];
  final List<PlatformData> platforms = [];
  late Image backdrop;
  late Image heroSheet;
  late Image enemySheet;
  late Image bossSheet;
  late Image monstersSheet;
  late Image effectSheet;
  late Image propSheet;
  late Image shrineSheet;

  double px = 140, py = floor, vx = 0, vy = 0, cameraX = 0;
  double _animT = 0, _shotCd = 0, _hurtCd = 0, _saveTimer = 0, _spawnTimer = 2;
  int hp = 5, score = 0, bestProgress = 0, _lastProgress = -1;
  bool grounded = true,
      facingRight = true,
      volumeEnabled = true,
      gameOver = false,
      won = false,
      gamePaused = false;
  bool _wasJump = false, _wasShoot = false;
  double _prevVy = 0;
  bool _wasAirborne = false, _wasMoving = false, _bossWarned = false;
  int _milestone = 0;

  static const _themeColors = [
    Color(0xff63b8a4),
    Color(0xffda9cab),
    Color(0xffb98f5c),
    Color(0xff89aa60),
    Color(0xffa08dd6),
    Color(0xffdc9b62),
    Color(0xffb4a8bd),
    Color(0xffb9d6e8),
    Color(0xffdb7950),
    Color(0xffc6e0ed),
    Color(0xffe6d186),
  ];
  Color get accent => _themeColors[stage.clamp(0, 10)];

  // Flame's image cache resolves bare filenames relative to assets/images.
  String _assetPath(String file) => file;

  @override
  Future<void> onLoad() async {
    backdrop = await images.load(_assetPath(themeAsset));
    heroSheet = await images.load(_assetPath(skinAsset));
    enemySheet = await images.load(_assetPath('enemies_a-transparent.webp'));
    monstersSheet = await images.load(
      _assetPath('monsters_${(stage ~/ 2 + 1).clamp(1, 5)}-transparent.webp'),
    );
    bossSheet = await images.load(
      _assetPath(
        'boss_${stage == 0 ? 'stag' : stage.clamp(1, 10)}-transparent.webp',
      ),
    );
    effectSheet = await images.load(_assetPath('effects-transparent.webp'));
    propSheet = await images.load(_assetPath('props-transparent.webp'));
    shrineSheet = await images.load(_assetPath('shrines-transparent.webp'));

    final prefs = await SharedPreferences.getInstance();
    volumeEnabled = prefs.getBool('volume') ?? true;
    audio.setEnabled(volumeEnabled);
    audio.setStage(stage);
    score = prefs.getInt('score') ?? 0;
    bestProgress = prefs.getInt('progress') ?? 0;
    if (prefs.getInt('savedStage') == stage) {
      px = (prefs.getDouble('savedX') ?? px).clamp(140, worldEnd - 90);
    }
    _buildStage();
  }

  void _buildStage() {
    platforms
      ..clear()
      ..addAll([
        for (var x = 0.0; x < worldEnd; x += 520)
          PlatformData(x, floor, 500, 34),
        const PlatformData(300, 355, 180, 22),
        const PlatformData(650, 300, 220, 22),
        const PlatformData(1030, 365, 190, 22),
        const PlatformData(1410, 315, 240, 22),
        const PlatformData(1810, 355, 220, 22),
        const PlatformData(2220, 285, 190, 22),
        const PlatformData(2590, 350, 230, 22),
        const PlatformData(3020, 300, 220, 22),
        const PlatformData(3430, 365, 190, 22),
        const PlatformData(3820, 305, 240, 22),
        const PlatformData(4250, 355, 220, 22),
        const PlatformData(4660, 295, 220, 22),
        const PlatformData(5090, 350, 240, 22),
        const PlatformData(5480, 325, 230, 22),
      ]);
    foes
      ..clear()
      ..addAll(
        List.generate(
          10,
          (i) => FoeData(
            x: 520 + i * 540.0,
            y: floor,
            hp: i == 9 ? 16 : 3,
            boss: i == 9,
          ),
        ),
      );
    pickups
      ..clear()
      ..addAll(
        List.generate(
          18,
          (i) => PickupData(x: 360 + i * 305.0, y: i.isEven ? 318 : 407),
        ),
      );
    px = px.clamp(140, worldEnd - 90);
    py = floor;
    vx = vy = 0;
    cameraX = 0;
    hp = 5;
    gameOver = won = false;
    _prevVy = 0;
    _wasAirborne = false;
    _wasMoving = false;
    _bossWarned = false;
    _milestone = 0;
  }

  void setDirection(GameDirection direction, bool pressed) {
    if (pressed) {
      held.add(direction);
    } else {
      held.remove(direction);
    }
  }

  void setAction(String action, bool pressed) {
    if (pressed) {
      actions.add(action);
    } else {
      actions.remove(action);
    }
  }

  void toggleVolume() async {
    volumeEnabled = !volumeEnabled;
    audio.setEnabled(volumeEnabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('volume', volumeEnabled);
  }

  void restart() {
    px = 140;
    score = 0;
    audio.resetEnd();
    _buildStage();
  }

  void setPaused(bool value) => gamePaused = value;

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final pressed = event is KeyDownEvent;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      setDirection(GameDirection.left, pressed);
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      setDirection(GameDirection.right, pressed);
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyW) {
      setAction('jump', pressed);
    }
    if (key == LogicalKeyboardKey.keyJ ||
        key == LogicalKeyboardKey.keyF ||
        key == LogicalKeyboardKey.enter) {
      setAction('shoot', pressed);
    }
    return KeyEventResult.handled;
  }

  @override
  void update(double dt) {
    super.update(dt);
    dt = dt.clamp(0, 1 / 30);
    if (gameOver || won || gamePaused) return;
    _animT += dt;
    _shotCd = math.max(0, _shotCd - dt);
    _hurtCd = math.max(0, _hurtCd - dt);
    final direction =
        (held.contains(GameDirection.right) ? 1 : 0) -
        (held.contains(GameDirection.left) ? 1 : 0);
    vx = direction * 290;
    if (direction != 0) facingRight = direction > 0;
    if (actions.contains('jump') && !_wasJump && grounded) {
      vy = -690;
      grounded = false;
      audio.jump();
    }
    _wasJump = actions.contains('jump');
    if (actions.contains('shoot') && !_wasShoot) {
      if (_shotCd <= 0) {
        arrows.add(
          ArrowData(
            px + (facingRight ? 30 : -30),
            py - 48,
            facingRight ? 650 : -650,
          ),
        );
        _shotCd = .32;
        audio.shoot();
        if (direction != 0) audio.lob();
      } else {
        audio.noenergy();
      }
    }
    _wasShoot = actions.contains('shoot');

    // Derap lari: mulai jalan -> dash, berhenti -> leaf.
    final moving = grounded && direction != 0;
    if (moving && !_wasMoving) audio.dash();
    if (!moving && _wasMoving) audio.leaf();
    _wasMoving = moving;

    final oldY = py;
    px = (px + vx * dt).clamp(35, worldEnd - 90);
    _prevVy = vy;
    vy = math.min(1050, vy + gravity * dt);
    py += vy * dt;
    grounded = false;
    for (final p in platforms) {
      if (px + 24 < p.x || px - 24 > p.x + p.w) continue;
      if (oldY <= p.y && py >= p.y && vy >= 0) {
        py = p.y;
        vy = 0;
        grounded = true;
      }
    }
    // Talo turun: puncak lompatan -> rope, mendarat -> land.
    if (_prevVy < 0 && vy >= 0 && !grounded) audio.rope();
    if (_wasAirborne && grounded) audio.land();
    _wasAirborne = !grounded;
    if (py > size.y * 1.5 + floor) {
      audio.footfail();
      _hurt();
    }
    final scale = size.y / 540;
    final viewW = size.x / scale;
    cameraX = (px - viewW * .43).clamp(0, worldEnd - viewW);

    for (final a in arrows) {
      a.x += a.vx * dt;
      a.life -= dt;
      for (final f in foes.where((f) => !f.dead)) {
        if ((a.x - f.x).abs() < (f.boss ? 80 : 38) &&
            (a.y - (f.y - 45)).abs() < (f.boss ? 150 : 65)) {
          f.hp--;
          a.life = 0;
          a.sounded = true;
          if (f.hp <= 0) {
            f.dead = true;
            score += f.boss ? 100 : 10;
            if (f.boss) {
              audio.thunk();
              audio.crumble();
              audio.relic();
            } else {
              audio.nodeBreak();
            }
          } else {
            if (f.boss) {
              audio.stomp();
            } else {
              audio.crack();
            }
          }
          break;
        }
      }
    }
    for (final a in arrows) {
      if (a.life <= 0 && !a.sounded) {
        a.sounded = true;
        audio.splat();
      }
    }
    arrows.removeWhere(
      (a) => a.life <= 0 || a.x < cameraX - 200 || a.x > cameraX + size.x + 300,
    );

    _spawnTimer -= dt;
    if (_spawnTimer <= 0 &&
        foes
                .where((f) => !f.dead && !f.boss && (f.x - px).abs() < 1100)
                .length <
            4) {
      foes.add(
        FoeData(x: (px + 550).clamp(250, worldEnd - 180), y: floor, hp: 3),
      );
      audio.spit();
      _spawnTimer = 4.5;
    }
    for (final f in foes.where((f) => !f.dead)) {
      f.t += dt;
      if (f.boss && !_bossWarned && (f.x - px).abs() < 540) {
        _bossWarned = true;
        audio.bell();
        audio.launch();
      }
      if ((f.x - px).abs() < 540 && (f.x - px).abs() > (f.boss ? 85 : 38)) {
        f.x += (px > f.x ? 1 : -1) * (f.boss ? 64 : 84) * dt;
      }
      if ((f.x - px).abs() < (f.boss ? 100 : 45) &&
          (py - f.y).abs() < (f.boss ? 150 : 80) &&
          _hurtCd <= 0) {
        _hurt();
      }
    }
    for (final c in pickups.where((c) => !c.taken)) {
      if ((px - c.x).abs() < 42 && (py - c.y).abs() < 72) {
        c.taken = true;
        hp = math.min(5, hp + 1);
        score += 5;
        audio.pickup();
        audio.lift();
      }
    }
    final tier = ((px / worldEnd) * 4).floor();
    if (tier > _milestone && tier <= 3) {
      _milestone = tier;
      audio.checkpoint();
    }
    if (px >= worldEnd - 180 && foes.where((f) => f.boss && !f.dead).isEmpty) {
      won = true;
      audio.win();
    }
    _saveTimer += dt;
    if (_saveTimer >= 1) {
      _saveTimer = 0;
      _saveProgress();
    }
  }

  void _hurt() {
    if (_hurtCd > 0) return;
    hp--;
    _hurtCd = 1.1;
    vy = -300;
    audio.hurt();
    audio.block();
    audio.launch();
    if (hp <= 0) {
      gameOver = true;
      audio.gameOver();
    }
  }

  Future<void> _saveProgress() async {
    final progress = ((px / worldEnd) * 100).round().clamp(0, 100);
    final prefs = await SharedPreferences.getInstance();
    if (progress != _lastProgress) {
      _lastProgress = progress;
      bestProgress = math.max(bestProgress, progress);
      await prefs.setInt('progress', bestProgress);
      onProgressChanged(bestProgress);
    }
    await prefs.setInt('score', math.max(score, prefs.getInt('score') ?? 0));
    await prefs.setDouble('savedX', px);
    await prefs.setInt('savedStage', stage);
  }

  @override
  Future<void> onRemove() async {
    await audio.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = size.x, h = size.y;
    final scale = h / 540;
    final viewW = w / scale;
    final cam = cameraX;
    final src = Rect.fromLTWH(
      0,
      0,
      backdrop.width.toDouble(),
      backdrop.height.toDouble(),
    );
    canvas.drawImageRect(
      backdrop,
      src,
      Rect.fromLTWH(0, 0, w, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0x55071510),
    );
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-cam, 0);
    _drawWorld(canvas, cam, viewW);
    canvas.restore();
    _drawHud(canvas, w, h);
    if (gameOver || won) _drawEndCard(canvas, w, h);
  }

  void _drawWorld(Canvas c, double left, double viewW) {
    final groundPaint = Paint()..color = accent.withValues(alpha: .96);
    final dirtPaint = Paint()..color = const Color(0xff30291f);
    for (final p in platforms) {
      if (p.x + p.w < left - 100 || p.x > left + viewW + 100) continue;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x, p.y, p.w, p.h),
          const Radius.circular(9),
        ),
        dirtPaint,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x, p.y, p.w, 10),
          const Radius.circular(7),
        ),
        groundPaint,
      );
    }
    for (final a in arrows) {
      final p = Paint()
        ..color = const Color(0xffffd67d)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      c.drawLine(Offset(a.x, a.y), Offset(a.x - a.vx.sign * 20, a.y), p);
    }
    for (final f in foes.where(
      (e) => !e.dead && e.x > left - 180 && e.x < left + viewW + 180,
    )) {
      if (f.boss) {
        _drawFrame(
          c,
          bossSheet,
          0,
          0,
          6,
          4,
          Rect.fromCenter(
            center: Offset(f.x, f.y - 88),
            width: 192,
            height: 176,
          ),
        );
        final bar = Rect.fromLTWH(f.x - 70, f.y - 190, 140, 10);
        c.drawRect(bar, Paint()..color = const Color(0xff321e23));
        c.drawRect(
          Rect.fromLTWH(
            bar.left,
            bar.top,
            bar.width * (f.hp / 16).clamp(0, 1),
            bar.height,
          ),
          Paint()..color = const Color(0xffe06e52),
        );
      } else {
        final row = (f.t * 7).floor() % 6;
        final sheet = stage == 0 ? enemySheet : monstersSheet;
        _drawFrame(
          c,
          sheet,
          row,
          0,
          6,
          stage == 0 ? 3 : 4,
          Rect.fromCenter(center: Offset(f.x, f.y - 40), width: 76, height: 78),
        );
      }
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(f.x - 23, f.y - (f.boss ? 194 : 93), 46, 5),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xff3c2722),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            f.x - 23,
            f.y - (f.boss ? 194 : 93),
            46 * (f.hp / (f.boss ? 16 : 3)).clamp(0, 1),
            5,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xffff8870),
      );
    }
    for (final p in pickups.where(
      (p) => !p.taken && p.x > left - 50 && p.x < left + viewW + 50,
    )) {
      c.drawCircle(
        Offset(p.x, p.y - 18 + math.sin(_animT * 3 + p.x) * 5),
        13,
        Paint()..color = const Color(0xffffdc78),
      );
      c.drawCircle(
        Offset(p.x, p.y - 18 + math.sin(_animT * 3 + p.x) * 5),
        6,
        Paint()..color = const Color(0xfff8fff0),
      );
    }
    final frame = vx.abs() > 8
        ? (_animT * 12).floor() % 6
        : (_animT * 5).floor() % 6;
    final row = vx.abs() > 8 ? 1 : (grounded ? 0 : 2);
    final body = Rect.fromLTWH(px - 40, py - 88, 80, 88);
    c.save();
    if (!facingRight) {
      c.translate(px * 2, 0);
      c.scale(-1, 1);
    }
    _drawFrame(c, heroSheet, frame, row, 6, 4, body);
    c.restore();
    c.drawRect(
      Rect.fromLTWH(worldEnd - 100, floor - 140, 18, 140),
      Paint()..color = const Color(0xffd5bb77),
    );
    c.drawCircle(
      Offset(worldEnd - 91, floor - 151),
      20,
      Paint()..color = accent,
    );
  }

  void _drawFrame(
    Canvas c,
    Image image,
    int col,
    int row,
    int cols,
    int rows,
    Rect dst,
  ) {
    final fw = image.width / cols, fh = image.height / rows;
    final source = Rect.fromLTWH(col * fw, row * fh, fw, fh);
    c.drawImageRect(
      image,
      source,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _drawHud(Canvas c, double w, double h) {
    final text = TextPainter(textDirection: TextDirection.ltr);
    void label(
      String s,
      double x,
      double y,
      double size,
      Color color, {
      FontWeight weight = FontWeight.bold,
    }) {
      text.text = TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      );
      text.layout(maxWidth: w - x - 12);
      text.paint(c, Offset(x, y));
    }

    final sf = h / 760;
    label(areas[stage.clamp(0, 10)], 18 * sf, 14 * sf, 18 * sf, Colors.white);
    label('SCORE  $score', 18 * sf, 40 * sf, 15 * sf, accent);
    for (var i = 0; i < 5; i++) {
      c.drawCircle(
        Offset(w - (26 + i * 24) * sf, 28 * sf),
        8 * sf,
        Paint()
          ..color = i < hp ? const Color(0xffee806c) : const Color(0x66808080),
      );
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .28, 12 * sf, w * .44, 7 * sf),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0x88404040),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .28, 12 * sf, w * .44 * (px / worldEnd), 7 * sf),
        const Radius.circular(5),
      ),
      Paint()..color = accent,
    );
  }

  void _drawEndCard(Canvas c, double w, double h) {
    c.drawRect(
      Offset.zero & size.toSize(),
      Paint()..color = const Color(0xb8000000),
    );
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.text = TextSpan(
      text: won ? 'AREA CLEARED!' : 'PETUALANGAN BERAKHIR',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
    );
    tp.layout(maxWidth: w - 36);
    tp.paint(c, Offset((w - tp.width) / 2, h * .42));
    tp.text = const TextSpan(
      text: 'Tekan tombol restart untuk bermain lagi',
      style: TextStyle(color: Colors.white70, fontSize: 15),
    );
    tp.layout(maxWidth: w - 36);
    tp.paint(c, Offset((w - tp.width) / 2, h * .49));
  }
}

class PlatformData {
  const PlatformData(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
}

class FoeData {
  FoeData({
    required this.x,
    required this.y,
    required this.hp,
    this.boss = false,
  });
  double x, y, t = 0;
  int hp;
  final bool boss;
  bool dead = false;
}

class ArrowData {
  ArrowData(this.x, this.y, this.vx);
  double x, y, vx;
  double life = 1.8;
  bool sounded = false;
}

class PickupData {
  PickupData({required this.x, required this.y});
  final double x, y;
  bool taken = false;
}
