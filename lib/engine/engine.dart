// Skyroot — The Last Archer. Owns the run's state and wires the systems together.
// Port of game js/game/game.js (without the DOM/HUD, which live in Flutter widgets).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'boss.dart';
import 'combat.dart';
import 'content.dart';
import 'enemies.dart';
import 'entities.dart';
import 'objects.dart';
import 'physics.dart';
import 'player.dart';
import 'save.dart';
import 'state.dart';
import 'world.dart';

/// Pixel size of the play area, set by the renderer so the camera knows the viewport.
class ViewInfo {
  double w = 400, h = 700, scale = 32;
}

class SkyrootEngine extends ChangeNotifier {
  SkyrootEngine({required List<List<String>> maps, Progress? saved}) : world = World(maps) {
    state = GameState(world);
    state.progress = saved ?? Progress();
  }

  final World world;
  late final GameState state;
  final InputState input = InputState();
  final ViewInfo view = ViewInfo();

  // ---- Hooks supplied by the host (audio, storage, asset streaming).
  void Function(String name, bool flag)? onSfx;
  void Function(Progress progress)? onPersist;
  void Function(int ms)? onHaptic;
  void Function(int music)? onArea;

  /// Loads sprites for [area] and [skin]; completes when the run can start.
  Future<void> Function(int area, int skin)? loadAssets;
  void Function(int area)? prefetchArea;

  /// True while a menu panel (map, wardrobe, pause) freezes the simulation.
  bool uiBlocking = false;
  bool destroyed = false;

  int _loadVersion = 0;

  /// Completes when the most recent asset load (area or skin change) has finished.
  Future<void> loaded = Future.value();
  bool _introShown = false;

  Progress get progress => state.progress;

  // ---- Tuning (formerly tweaks.json)
  Tune _readTune() {
    final skin = skins[progress.skin.clamp(0, skins.length - 1)];
    return Tune(
      runSpeed: 7.5 * skin.speed,
      jumpV: math.sqrt(2 * gravityBase * 3.5),
      gravity: areas[progress.area].gravity,
      skin: skin,
    );
  }

  void _sfx(String name, [bool flag = false]) => onSfx?.call(name, flag);
  void _persist() => onPersist?.call(progress);
  void _haptic(int ms) => onHaptic?.call(ms);

  void toast(String text, [double dur = 2.6]) {
    state.toast = Toast(text, dur);
  }

  // ---- Build (or rebuild) the run for the current area from saved progress. Synchronous and repeatable.
  void buildRun() {
    final s = state;
    final area = progress.area;
    // Later maps have no traversal relics; direct area selection needs these tools.
    if (area > 0) {
      progress.footing = true;
      progress.dash = true;
    }
    world.loadArea(area);
    final ap = progress.areas[area];
    final tune = _readTune();
    final skin = tune.skin;
    s
      ..t = 0
      ..phase = 'loading'
      ..areaIndex = area
      ..areaProg = ap
      ..tune = tune
      ..uid = 1000
      ..arrows = []
      ..footings = []
      ..eproj = []
      ..fx = []
      ..particles = []
      ..warnings = []
      ..beams = []
      ..bolts = []
      ..platforms = []
      ..aimTargets = []
      ..slow = 1
      ..shake = 0
      ..speech = null
      ..bellRing = 0
      ..bridgeT = ap.boss ? 1 : 0
      ..emberT = 0
      ..emberOn = false
      ..cloneT = 0
      ..skillCd = 0
      ..nearShrine = false
      ..maxHp = progress.maxHp + skin.hp
      ..maxEnergy = progress.maxEnergy + skin.energy
      ..arrowType = progress.footing ? (s.arrowType.isEmpty ? 'footing' : s.arrowType) : 'normal'
      ..inMx = 0
      ..inMy = 0
      ..inUpPressed = false;
    s.events.clear();

    var id = 1;
    final areaMonster = areas[area].monster;
    s.enemies = world.singles.where((o) => 'TBQ*'.contains(o.g)).map((o) {
      final type = o.g == 'T' ? 'thorn' : o.g == 'B' ? 'beetle' : o.g == 'Q' ? 'frog' : (areaMonster ?? 'thorn');
      return createEnemy(id++, type, o.x, o.y, area);
    }).toList();
    final O = world.single('O');
    s.boss = O.isEmpty
        ? null
        : (area == 0 ? StagBoss(O[0].x.toDouble(), O[0].y.toDouble(), ap.boss, tune.bossHp) : AreaBoss(area, O[0].x.toDouble(), O[0].y.toDouble(), ap.boss));
    s.leaves = [
      for (final (i, r) in world.runs['L']!.indexed) Leaf(i, r.x0, r.x1, r.y),
    ];
    s.crumbles = [
      for (final (i, r) in world.runs['C']!.indexed) Crumble(i, r.x0, r.x1, r.y),
    ];
    s.bridge = world.runs['n']!.map((r) => BridgeRun(r.x0, r.x1, r.y)).toList();
    final moverRuns = [
      ...world.runs['M']!.map((r) => (r: r, axis: 'x')),
      ...world.runs['N']!.map((r) => (r: r, axis: 'y')),
    ];
    s.movers = [
      for (final (i, m) in moverRuns.indexed)
        Mover(
          id: i,
          x0: m.r.x0,
          w: m.r.x1 - m.r.x0 + 1,
          y: m.r.y,
          axis: m.axis,
          amp: m.axis == 'x' ? 1.2 : 1.4,
          speed: 1.15,
          phase: i * 1.7,
        ),
    ];
    s.flowers = [for (final (i, o) in world.single('F').indexed) Flower(i, o.x, o.y)];
    s.winds = [for (final (i, w) in world.winds.indexed) Wind(i, w.x0, w.x1, w.y0, w.y1, i * 0.9)];
    s.stalactites = world.single('v').map((o) => Stalactite(o.x, o.y)).toList();
    s.checkpoints = world.single('K').map((o) {
      final cid = 'K@${o.x},${o.y}';
      return Checkpoint(cid, o.x, o.y, ap.cp == cid);
    }).toList();
    s.pickups = world.singles
        .where((o) => 'HEDARY'.contains(o.g))
        .map((o) => Pickup('${o.g}@${o.x},${o.y}', o.g, o.x, o.y))
        .where((it) => it.kind == 'H' || !ap.got.contains(it.id))
        .toList();
    s.cracks = world.cracks.map((c) {
      final cid = 'X@${c.x},${c.y0}';
      final broken = ap.broken.contains(cid);
      world.setCrackSolid(c, !broken);
      return Crack(cid, c.x, c.y0, c.y1, broken);
    }).toList();
    final U = world.single('U'), u = world.single('u');
    s.lift = U.isNotEmpty && u.isNotEmpty ? Lift(LiftStation(U[0].x, U[0].y), LiftStation(u[0].x, u[0].y)) : null;
    final z = world.single('z');
    s.rope = z.isNotEmpty ? (x: z[0].x, y: z[0].y) : null;
    world.setRope(ropeStrip, progress.rope);
    final b = world.single('b');
    s.bell = b.isNotEmpty ? Bell(b[0].x, b[0].y) : null;
    final G = world.single('G');
    s.gate = G.isNotEmpty ? Gate(G[0].x, G[0].y, area == 0 ? progress.bell : ap.boss) : null;
    s.villagers = world.single('V').map((o) => Villager(o.x, o.y)).toList();
    s.decor = world.singles.where((o) => 'hlms'.contains(o.g)).map((o) => Decor(o.g, o.x, o.y)).toList();
    final cp = s.checkpoints.where((k) => k.id == ap.cp).firstOrNull;
    final start = cp != null ? (x: cp.x, y: cp.y) : (x: world.single('P')[0].x, y: world.single('P')[0].y);
    s.player = Player(start.x + 0.5, start.y + 1.0, s.maxHp, s.maxEnergy);
    s.cam = Cam(s.player.x, s.player.y - 1);
    onArea?.call(areas[area].music);
    loaded = _loadCurrent();
  }

  // ---- Named actions
  void travelTo(int area) {
    if (area < 0 || area >= areaCount) return;
    uiBlocking = false;
    progress.area = math.max(0, math.min(progress.unlocked, area));
    _persist();
    state.phase = 'play';
    buildRun();
    if (state.phase == 'play') {
      _announceArea();
    } else {
      state.pendingAnnounce = true;
    }
    notifyListeners();
  }

  void _announceArea() {
    toast('Wilayah ${state.areaIndex} · ${areas[state.areaIndex].name}', 2.8);
  }

  void equipSkin(int i) {
    if (!progress.skinOwned(i)) return;
    if (progress.skin == i) return;
    final s = state;
    progress.skin = i;
    s.tune = _readTune();
    final skin = skins[i];
    s.maxHp = progress.maxHp + skin.hp;
    s.maxEnergy = progress.maxEnergy + skin.energy;
    // Changing clothes must not become an unlimited heal/skill-reset exploit.
    s.player.hp = math.min(s.player.hp, s.maxHp.toDouble());
    s.player.energy = math.min(s.player.energy, s.maxEnergy.toDouble());
    uiBlocking = false;
    loaded = _loadCurrent();
    _sfx('relic');
    toast('${skin.name} dipakai', 2);
    _persist();
    notifyListeners();
  }

  void resetProgress() {
    state.progress = Progress();
    _persist();
    uiBlocking = false;
    state.phase = 'play';
    buildRun();
    toast('Petualangan baru dimulai', 2.2);
    notifyListeners();
  }

  void respawn() {
    uiBlocking = false;
    buildRun();
    notifyListeners();
  }

  /// Called by the UI when the ending panel's "Jelajah lagi" is pressed.
  void continueAfterEnding() {
    state.phase = 'play';
    state.gateHold = true;
    notifyListeners();
  }

  // ---- Damage from arrows and skills
  void _damageEnemy(Enemy e, int dmg) {
    final s = state;
    if (e.dead) return;
    e.hp -= dmg;
    e.hurtT = 0.2;
    if (e.hp <= 0) {
      e.dead = true;
      s.events.add(GameEvent('defeat', x: e.x, y: e.y - e.h / 2, enemy: true));
      if (e.id % 3 == 0 && !e.summoned) {
        s.pickups.add(Pickup('drop${s.uid++}', 'H', e.x.floor(), (e.y - 1).floor()));
      }
    }
  }

  bool _hitTest(Arrow a) {
    final s = state;
    for (final e in s.enemies) {
      if (e.dead || a.hits.contains(e.id)) continue;
      final r = arrowHitsEnemy(e, a);
      if (r == 'hit') {
        _damageEnemy(e, a.dmg);
        if (a.burn) e.burnT = 3;
        if (a.slow) e.slowT = 2.5;
        s.fx.add(Fx('arrow_hit', a.x, a.y, dur: 0.3));
        if (!e.dead) s.events.add(GameEvent('thunk'));
        if (a.chain) _chainFrom(e, a.dmg);
        a.hits.add(e.id);
        if (a.pierce > 0) {
          a.pierce--;
          return false;
        }
        return true;
      }
      if (r == 'block') {
        if (s.tune.skin.pierce >= 2) {
          // High-tier skins punch straight through shields.
          _damageEnemy(e, a.dmg);
          a.hits.add(e.id);
          return true;
        }
        a.state = 'drop';
        a.t = 0;
        a.vx = -a.vx * 0.25;
        a.vy = -5;
        s.fx.add(Fx('arrow_hit', a.x, a.y, dur: 0.3));
        s.events.add(GameEvent('block'));
        return false;
      }
    }
    if (a.hits.contains('boss')) return false;
    final consumed = s.areaIndex == 0 ? arrowHitsBoss(s, a) : arrowHitsAreaBoss(s, a);
    if (consumed && a.pierce > 0) {
      a.hits.add('boss');
      a.pierce--;
      return false;
    }
    return consumed;
  }

  void _chainFrom(Enemy from, int dmg) {
    final s = state;
    Enemy? best;
    var bd = 6.0;
    for (final e in s.enemies) {
      if (identical(e, from) || e.dead) continue;
      final d = hypot(e.x - from.x, e.y - from.y);
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    if (best != null) {
      s.bolts.add(Bolt(from.x, from.y - from.h / 2, best.x, best.y - best.h / 2, 0.25));
      _damageEnemy(best, math.max(1, jsRound(dmg * 0.7)));
    }
  }

  ({double left, double top}) camBox(Cam cam) {
    final sc = view.scale * cam.zoom;
    return (left: cam.x - view.w / 2 / sc, top: cam.y - (view.h * 0.47) / sc);
  }

  void castSkill() {
    final s = state;
    final skin = s.tune.skin;
    if (skin.skill == null || s.skillCd > 0) return;
    final box = camBox(s.cam);
    final sc = view.scale * s.cam.zoom;
    final vw = view.w / sc;
    final vh = view.h / sc;
    bool inView(double x, double y) => x > box.left - 1 && x < box.left + vw + 1 && y > box.top - 1 && y < box.top + vh + 1;
    s.skillCd = 10;
    void bossHit(double dmg) {
      final b = s.boss;
      if (b is AreaBoss && inView(b.x, b.y - 2)) {
        damageAreaBoss(s, dmg);
        s.bolts.add(Bolt(b.x, box.top, b.x, b.y - 2, 0.4));
      }
    }

    switch (skin.skill) {
      case 'icerain':
        rainArrows(s, box.left, vw, box.top - 0.5, 14, 'ice_arrow', 2 + skin.dmg, slow: true);
      case 'starrain':
        rainArrows(s, box.left, vw, box.top - 0.5, 20, 'star_arrow', 3 + skin.dmg, pierce: 2);
      case 'thunder':
        for (final e in s.enemies) {
          if (!e.dead && inView(e.x, e.y)) {
            s.bolts.add(Bolt(e.x + 0.4, box.top, e.x, e.y - e.h / 2, 0.35));
            _damageEnemy(e, 5 + skin.dmg);
          }
        }
        bossHit(8);
        s.events.add(GameEvent('thunder'));
      case 'clone':
        s.cloneT = 8;
      case 'guardian':
        for (final e in s.enemies) {
          if (!e.dead && inView(e.x, e.y)) {
            _damageEnemy(e, 10 + skin.dmg);
            s.fx.add(Fx('leaf_burst', e.x, e.y, dur: 0.6, scale: 1.4));
          }
        }
        bossHit(16);
        for (var i = 0; i < 6; i++) {
          s.fx.add(Fx('leaf_burst', box.left + ((i + 0.5) / 6) * vw, box.top + vh * 0.6, t: -i * 0.06, dur: 0.6, scale: 2));
        }
        s.shake = 0.45;
        s.events.add(GameEvent('stomp'));
    }
    _sfx('relic');
    toast('${skillNames[skin.skill]}!', 1.4);
    _haptic(40);
  }

  String villagerLine() {
    if (!progress.footing) return 'Gua di bawah desa menyimpan Panah Pijakan.';
    if (!progress.areas[0].boss) return 'Menara lonceng ada di puncak. Reruntuhan, batang berlubang, atau akar luar — pilih jalanmu.';
    if (!progress.bell) return 'Rusa Menara tumbang! Bunyikan loncengnya.';
    return 'Gerbang di menara membawamu ke atas. Kamu juga bisa memilih wilayah lewat peta dan jubah lewat lemari.';
  }

  // ---- Events
  void _processEvents() {
    final s = state;
    final p = s.player;
    final ap = s.areaProg;
    // Events handlers may rebuild the run (gate -> travelTo), which clears the list.
    final events = List<GameEvent>.of(s.events);
    s.events.clear();
    for (final ev in events) {
      switch (ev.type) {
        case 'jump' || 'walljump' || 'doublejump':
          _sfx('jump');
          s.fx.add(Fx('dust', ev.x, ev.y, dur: 0.35, scale: ev.type == 'doublejump' ? 0.9 : 0.7));
        case 'land':
          _sfx('land', ev.hard);
          s.fx.add(Fx('dust', ev.x, ev.y, dur: 0.4, scale: ev.hard ? 1.1 : 0.8));
        case 'dash':
          _sfx('dash');
          s.fx.add(Fx('dust', ev.x, ev.y, dur: 0.35, scale: 0.9, flip: p.face > 0));
        case 'hurt':
          _sfx('hurt');
          s.shake = 0.25;
          _haptic(40);
        case 'shoot':
          _sfx('shoot', ev.full);
        case 'thunk':
          _sfx('thunk');
        case 'sprout':
          _sfx('sprout');
        case 'footfail':
          _sfx('footfail');
        case 'noenergy':
          _sfx('noenergy');
          toast('Energi habis — berdiri di tanah untuk memulihkan', 2);
        case 'crack':
          if (ev.quiet) {
            _sfx('crack');
            break;
          }
          final c = breakCrackAt(s, ev.x.toInt(), ev.y.toInt());
          if (c != null) {
            ap.broken.add(c.id);
            s.fx.add(Fx('leaf_burst', c.x + 0.5, c.y1 + 1.0, dur: 0.6, scale: 1.2));
            _sfx('crumble');
            toast(s.areaIndex == 6 ? 'Jaring putus!' : 'Dinding rapuh runtuh!');
            _persist();
          }
        case 'crumble':
          _sfx('crumble');
        case 'leaf':
          _sfx('leaf');
        case 'launch':
          _sfx('launch');
        case 'spit':
          _sfx('spit');
        case 'lob':
          _sfx('lob');
        case 'splat':
          _sfx('splat');
        case 'defeat':
          _sfx('defeat');
          s.fx.add(Fx('leaf_burst', ev.x, ev.y + 0.9, dur: 0.55));
          if (ev.enemy) s.skillCd = math.max(0, s.skillCd - 0.7);
        case 'block':
          _sfx('block');
        case 'pickup':
          _applyPickup(ev);
        case 'checkpoint':
          _sfx('checkpoint');
          toast(progress.areas.indexed.any((e) => e.$1 > 0 && e.$2.boss) ? 'Titik istirahat · buka Lemari Skin di sini' : 'Titik istirahat menyala');
          _persist();
        case 'liftOn':
          if (!progress.lift) {
            progress.lift = true;
            _sfx('checkpoint');
            toast('Lift akar menyala — jalan pintas ke desa', 3);
            _persist();
          }
        case 'lift':
          _sfx('lift');
        case 'ropeOpen':
          if (!progress.rope) {
            progress.rope = true;
            world.setRope(ropeStrip, true);
            _sfx('rope');
            toast('Tali terjulur ke desa — jalan pintas', 3);
            _persist();
          }
        case 'bossStart':
          _sfx('stomp');
          toast(ev.name != null ? '${ev.name} bangkit!' : 'Rusa Menara terbangun! Tembak simpul di tanduknya', 3);
        case 'bossPhase':
          toast(ev.phase == 3 ? 'Fase terakhir!' : 'Fase 2 — serangannya makin cepat!', 2.2);
          s.shake = 0.3;
        case 'bossShoot':
          _sfx('shoot');
        case 'stomp':
          _sfx('stomp');
          s.shake = math.max(s.shake, 0.3);
          _haptic(50);
        case 'thunder':
          _sfx('nodeBreak');
          s.shake = math.max(s.shake, 0.15);
        case 'nodeBreak':
          _sfx('nodeBreak');
        case 'bossStun':
          toast('Kepalanya turun — bidik rune emas!', 2.4);
        case 'bossHurt':
          if (!ev.quiet || (s.t * 8).floor() % 2 == 0) _sfx(ev.quiet ? 'thunk' : 'hurt');
          if (!ev.quiet) {
            s.shake = 0.2;
            _haptic(30);
          }
        case 'summon':
          final type = areas[s.areaIndex].monster!;
          for (var i = 0; i < 2; i++) {
            final m = monsters[type]!;
            final e = createEnemy(s.uid++, type, i == 1 ? 26 : 16, m.fly ? 6 : 11, s.areaIndex);
            e.summoned = true;
            e.cd = 1;
            s.enemies.add(e);
            s.fx.add(Fx('leaf_burst', e.x, e.y, dur: 0.5));
          }
        case 'bossDying':
          // Count the victory as soon as the boss starts to fall, so dying or leaving
          // during its 2-second death animation can't bring it back.
          ap.boss = true;
          _persist();
        case 'bossDefeated':
          ap.boss = true;
          if (s.gate != null) s.gate!.active = s.areaIndex == 0 ? progress.bell : true;
          s.enemies = s.enemies.where((e) => !e.summoned).toList();
          s.eproj.clear();
          s.bridgeT = 0;
          _sfx('defeat');
          _sfx('relic');
          final bb = s.boss!;
          for (var i = 0; i < 4; i++) {
            s.fx.add(Fx('leaf_burst', bb.x - 2 + i * 1.3, bb.y - 1 - (i % 2) * 2, t: -i * 0.12, dur: 0.6, scale: 1.4));
          }
          if (s.areaIndex == 0) {
            toast('Rusa Menara tumbang — jembatan akar tumbuh ke lonceng', 3.2);
          } else {
            toast(s.areaIndex == areaCount - 1 ? 'Jantung Kabut hancur! Masuki gerbang' : '${bosses[s.areaIndex]!.name} tumbang! Gerbang wilayah terbuka', 4);
          }
          _persist();
        case 'bell':
          if (!progress.bell) {
            progress.bell = true;
            progress.unlocked = math.max(progress.unlocked, 1);
            s.bellRing = 1;
            if (s.gate != null) s.gate!.active = true;
            _sfx('bell');
            toast('Lonceng berbunyi — gerbang ke Kebun Gantung terbuka!', 3.5);
            prefetchArea?.call(1);
            _persist();
          }
        case 'gate':
          if (s.areaIndex == areaCount - 1) {
            if (s.phase != 'ending') {
              s.phase = 'ending';
              _sfx('bell');
              _sfx('win');
              notifyListeners();
            }
          } else {
            progress.unlocked = math.max(progress.unlocked, s.areaIndex + 1);
            travelTo(s.areaIndex + 1);
            return;
          }
      }
    }
  }

  void _applyPickup(GameEvent ev) {
    final s = state;
    final p = s.player;
    final ap = s.areaProg;
    final id = ev.id!;
    final secret = secretIdsFor(s.areaIndex).contains(id);
    if (ev.kind != 'H' && !ap.got.contains(id)) ap.got.add(id);
    String tag() => secret ? ' · Rahasia ${progress.secretsFound}/$totalSecrets' : '';
    switch (ev.kind) {
      case 'H':
        p.hp = math.min(s.maxHp.toDouble(), p.hp + 1);
        _sfx('pickup');
        return;
      case 'E':
        progress.maxEnergy = math.min(13, progress.maxEnergy + 1);
        s.maxEnergy = progress.maxEnergy + s.tune.skin.energy;
        p.energy = s.maxEnergy.toDouble();
        toast('Batu Energi! Energi maks +1${tag()}', 3);
      case 'D':
        progress.dash = true;
        toast('Dash didapat! Melesat di darat atau udara', 3.4);
      case 'A':
        progress.footing = true;
        s.arrowType = 'footing';
        toast('Panah Pijakan! Tembak kayu terang untuk membuat tangga', 3.8);
      case 'R':
        progress.maxHp = math.min(14, progress.maxHp + 1);
        s.maxHp = progress.maxHp + s.tune.skin.hp;
        p.hp = s.maxHp.toDouble();
        toast('Jantung Akar! Nyawa maks +1${tag()}', 3);
      case 'Y':
        progress.feather = true;
        toast('Bulu Emas ditemukan!${tag()}', 3);
    }
    _sfx('relic');
    s.fx.add(Fx('leaf_burst', ev.x, ev.y + 0.8, dur: 0.6, scale: 0.9));
    _persist();
  }

  void _markExplored() {
    final s = state;
    final p = s.player;
    final ap = s.areaProg;
    final bw = (world.cols / exploreBlock).ceil();
    final bh = (world.rows / exploreBlock).ceil();
    final ex = ap.explored.padRight(bw * bh, '0').split('');
    final bx = (p.x / exploreBlock).floor();
    final by = (p.y / exploreBlock).floor();
    var changed = false;
    for (var dy = -3; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final x = bx + dx;
        final y = by + dy;
        if (x < 0 || y < 0 || x >= bw || y >= bh) continue;
        if (ex[y * bw + x] != '1') {
          ex[y * bw + x] = '1';
          changed = true;
        }
      }
    }
    if (changed) ap.explored = ex.join();
  }

  void _updateCamera(double dt) {
    final s = state;
    final p = s.player;
    final v = view;
    // The boss arena zooms out so the whole fight fits a phone frame.
    final arena = p.y < 12.8 && p.x > 10 && p.x < 34;
    final zoomTarget = arena ? math.min(1.0, v.w / 21.5 / v.scale) : 1.0;
    s.cam.zoom += (zoomTarget - s.cam.zoom) * (s.cam.snap ? 1 : math.min(1, dt * 3));
    final sc = v.scale * s.cam.zoom;
    var px = p.x;
    var py = p.y;
    if (p.mode == 'ledge' && p.ledge != null) {
      final lp = ledgeDrawPos(p);
      px = lp.x;
      py = lp.y;
    }
    // While drawing the bow the view only leans a little toward the aim, so it doesn't tug.
    var tx = px + p.face * 1.2 + (p.aiming ? p.aimX * 0.5 : 0);
    var ty = py - 1.0 + (p.aiming ? p.aimY * 0.4 : 0) + (p.vy > 12 ? 1.5 : 0);
    if (arena) {
      tx = 22.5 + (px - 22.5) * 0.25;
      ty = 6.0 + (py - 6.0) * 0.1;
    }
    final halfW = v.w / 2 / sc;
    final topOff = (v.h * 0.47) / sc;
    final botOff = (v.h * 0.53) / sc;
    final cols = world.cols.toDouble(), rows = world.rows.toDouble();
    tx = cols < halfW * 2 ? cols / 2 : math.max(halfW, math.min(cols - halfW, tx));
    // In the arena the view may rise above the crown so the fight sits below the HUD.
    final minTy = arena ? math.min(topOff, 6.0) : topOff;
    ty = rows < topOff + botOff ? rows / 2 : math.max(minTy, math.min(rows - botOff, ty));
    if (s.cam.snap) {
      s.cam.x = tx;
      s.cam.y = ty;
      s.cam.snap = false;
    } else {
      s.cam.x += (tx - s.cam.x) * math.min(1, dt * 6);
      s.cam.y += (ty - s.cam.y) * math.min(1, dt * 6);
    }
  }

  // ---- The tick: one fixed step of simulation.
  void update(double dt) {
    final s = state;
    s.toast?.t += dt;
    if (s.phase != 'play' || uiBlocking) {
      input.clearEdges();
      return;
    }
    if (!_introShown) {
      _introShown = true;
      if (s.areaIndex == 0 && !progress.footing) {
        toast('Joystick untuk lari · tahan busur & geser untuk membidik', 4.5);
      }
    }
    final inp = input;
    final box = camBox(s.cam);
    final sc = view.scale * s.cam.zoom;
    inp.aimWX = box.left + inp.pointerX / sc;
    inp.aimWY = box.top + inp.pointerY / sc;
    s.inMx = inp.mx;
    s.inMy = inp.my;
    s.inUpPressed = inp.upPressed;
    if (inp.switchPressed && progress.footing) {
      s.arrowType = s.arrowType == 'footing' ? 'normal' : 'footing';
      _sfx('footfail');
    }
    if (inp.skillPressed) castSkill();
    final p = s.player;
    final tune = s.tune;

    // Air Focus: aiming in mid-air slows the world while the meter lasts.
    final wantSlow = p.aiming && !p.onGround && p.mode == 'normal' && p.focus > 0;
    if (wantSlow) p.focus = math.max(0, p.focus - dt);
    final targetSlow = wantSlow ? tune.focusSlow : 1.0;
    s.slow += (targetSlow - s.slow) * math.min(1, dt * 14);
    final wdt = dt * s.slow;
    s.t += wdt;
    progress.time += dt;
    s.shake = math.max(0, s.shake - dt);
    s.skillCd = math.max(0, s.skillCd - dt);
    s.cloneT = math.max(0, s.cloneT - dt);
    // Ember vents breathe on a shared beat: dormant 1.8 s, flaring 1.2 s.
    s.emberT += wdt;
    if (s.emberT > (s.emberOn ? 1.2 : 1.8)) {
      s.emberOn = !s.emberOn;
      s.emberT = 0;
    }

    updateMovers(s, wdt);
    updateBow(s, p, inp, dt, tune);
    s.platforms = collectPlatforms(s);
    updatePlayer(s, p, inp, wdt, tune);

    // Thorn spikes: hurt and return to the last safe ground. Ember vents: hurt while flaring.
    if (p.mode != 'dead' && p.mode != 'lift' && world.overlapsTile(p, Tile.spike)) {
      if (p.invuln <= 0) hurtPlayer(s, p, 1, p.x);
      if (p.mode != 'dead') {
        p.x = p.safeX;
        p.y = p.safeY;
        p.vx = 0;
        p.vy = 0;
        p.mode = 'normal';
      }
    }
    if (s.emberOn && p.mode != 'dead' && world.overlapsTile(p, Tile.ember)) hurtPlayer(s, p, 1, p.x - p.face);
    // Energy for Footing Arrows recovers on natural ground (slower on steps).
    if (p.onGround && progress.footing) {
      final rate = p.groundId == null ? tune.energyRegen : tune.energyRegen * 0.35;
      p.energy = math.min(s.maxEnergy.toDouble(), p.energy + rate * wdt);
    }

    updateObjects(s, wdt);
    updateHazards(s, wdt);
    updateFootings(s, wdt);
    s.nearShrine = s.checkpoints.any((k) => (p.x - (k.x + 0.5)).abs() < 1.6 && (p.y - (k.y + 1)).abs() < 1.6);

    s.aimTargets = s.enemies.where((e) => !e.dead).map((e) => AimTarget(e.id, e.x, e.y - e.h * 0.55)).toList();
    final b = s.boss;
    if (b != null && b.state != 'gone' && b.state != 'sleep' && b.state != 'dying') {
      if (b is AreaBoss) {
        final r = bossRect(b);
        s.aimTargets.add(AimTarget('boss', (r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2));
      } else if (b is StagBoss) {
        if (b.state == 'stunned') {
          final w = weakPos(b);
          s.aimTargets.add(AimTarget('boss', w.x, w.y));
        } else {
          for (var i = 0; i < 3; i++) {
            if (b.nodes[i]) {
              final n = nodePos(b, i);
              s.aimTargets.add(AimTarget('node$i', n.x, n.y));
            }
          }
        }
      }
    }
    for (final c in s.cracks) {
      if (!c.broken) s.aimTargets.add(AimTarget(c.id, c.x + 0.5, c.y0 + 1.0));
    }

    updateArrows(s, wdt, _hitTest);
    updateEnemies(s, wdt);
    s.enemies = s.enemies.where((e) => !e.dead).toList();
    if (s.areaIndex == 0) {
      updateBoss(s, wdt);
    } else {
      updateAreaBoss(s, wdt);
    }
    updateWarnings(s, wdt);
    updateBeams(s, wdt);
    updateProjectiles(s, wdt);

    for (final f in s.fx) {
      f.t += wdt;
    }
    s.fx = s.fx.where((f) => f.t < f.dur).toList();
    for (final bo in s.bolts) {
      bo.t += wdt;
    }
    s.bolts = s.bolts.where((bo) => bo.t < bo.dur).toList();
    // Dash trail and golden feather sparkles.
    if (p.mode == 'dash' || (progress.feather && p.vx.abs() > 2 && (s.t * 30).floor() % 3 == 0)) {
      s.particles.add(Particle(
        p.x - p.face * 0.3,
        p.y - 0.4 - ((s.uid++ % 7) / 7) * 1.0,
        -p.face * 2.0,
        -0.5,
        0.4,
        0.12,
        progress.feather ? 0xFFFFD86A : 0xFFC9FFF0,
      ));
    }
    for (final q in s.particles) {
      q.life -= wdt;
      q.x += q.vx * wdt;
      q.y += q.vy * wdt;
    }
    s.particles = s.particles.where((q) => q.life > 0).toList();
    if (s.particles.length > 120) s.particles = s.particles.sublist(s.particles.length - 120);
    if (s.areaIndex == 0 && progress.areas[0].boss) s.bridgeT += wdt;

    // Villager speech.
    final v = s.villagers.where((x) => x.near).firstOrNull;
    s.speech = v != null ? Speech(villagerLine(), v.x + 0.5, v.y - 1.1) : null;

    // Defeat: fade, then wake at the last shrine with the area reset.
    if (p.mode == 'dead') {
      p.deadT += dt;
      if (p.deadT > 1.6) {
        progress.deaths++;
        _persist();
        buildRun();
        toast('Bangkit di titik istirahat', 2);
      }
    }

    if ((s.t * 4).floor() != ((s.t - wdt) * 4).floor()) _markExplored();
    _updateCamera(dt);
    _processEvents();
    input.clearEdges();
  }

  /// Streams sprites for the current area + skin, then starts play.
  Future<void> _loadCurrent() async {
    final s = state;
    final version = ++_loadVersion;
    final area = s.areaIndex, skin = progress.skin;
    s.phase = 'loading';
    s.loadingError = null;
    s.player.aiming = false;
    notifyListeners();
    try {
      await loadAssets?.call(area, skin);
      if (destroyed || version != _loadVersion) return;
      s.cam.snap = true;
      _updateCamera(0);
      input.clearEdges();
      s.phase = 'play';
      if (s.pendingAnnounce) _announceArea();
      s.pendingAnnounce = false;
      _persist();
      notifyListeners();
    } catch (error) {
      if (destroyed || version != _loadVersion) return;
      s.loadingError = error.toString();
      notifyListeners();
    }
  }

  void retryLoad() {
    if (state.loadingError != null) loaded = _loadCurrent();
  }

  @override
  void dispose() {
    destroyed = true;
    _loadVersion++;
    super.dispose();
  }
}
