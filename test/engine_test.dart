import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:skyroot/engine/content.dart';
import 'package:skyroot/engine/engine.dart';
import 'package:skyroot/engine/entities.dart';
import 'package:skyroot/engine/player.dart';
import 'package:skyroot/engine/save.dart';
import 'package:skyroot/engine/state.dart';
import 'package:skyroot/engine/world.dart';

List<List<String>> loadMaps() {
  final raw = jsonDecode(File('assets/game/maps.json').readAsStringSync()) as List;
  return raw.map((m) => (m as List).cast<String>()).toList();
}

void main() {
  final maps = loadMaps();

  test('maps parse into worlds with a start tile', () {
    final w = World(maps);
    for (var i = 0; i < 11; i++) {
      w.loadArea(i);
      expect(w.single('P'), isNotEmpty, reason: 'area $i has a start');
      expect(w.cols, 40);
    }
  });

  test('player physics match the reference trajectories frame by frame', () {
    final ref = jsonDecode(File('test/fixtures/player_ref.json').readAsStringSync()) as List;
    for (final run in ref) {
      final area = run['area'] as int;
      final skinIdx = run['skin'] as int;
      final world = World(maps)..loadArea(area);
      final g = GameState(world);
      g.progress
        ..footing = true
        ..dash = true;
      final start = run['start'] as List;
      final p = Player((start[0] as num).toDouble(), (start[1] as num).toDouble(), 3, 3);
      g.player = p;
      final skin = skins[skinIdx];
      final tune = Tune(
        runSpeed: 7.5 * skin.speed,
        jumpV: math.sqrt(2 * gravityBase * 3.5),
        gravity: area == 10 ? 0.7 : 1,
        skin: skin,
      );
      // Same deterministic input script that produced the reference trajectories.
      var s = run['seed'] as int;
      double rnd() {
        s = (s * 48271) % 2147483647;
        return s / 2147483647;
      }

      var mx = 0.0, my = 0.0;
      var jumpHeld = false;
      final traj = run['traj'] as List;
      final inp = InputState();
      for (var f = 0; f < traj.length; f++) {
        if (f % 30 == 0) {
          final r = rnd();
          mx = r < 0.3 ? -1 : (r < 0.7 ? 1 : 0);
          final q = rnd();
          my = q < 0.2 ? -1 : (q < 0.3 ? 1 : 0);
        }
        final jumpPressed = f % 47 == 0 || rnd() < 0.01;
        if (jumpPressed) {
          jumpHeld = true;
        } else if (rnd() < 0.08) {
          jumpHeld = false;
        }
        final dash = rnd() < 0.01;
        inp
          ..mx = mx
          ..my = my
          ..jumpPressed = jumpPressed
          ..jumpHeld = jumpHeld
          ..dashPressed = dash;
        g.events.clear();
        updatePlayer(g, p, inp, 1 / 60, tune);
        final e = traj[f] as List;
        final where = 'area $area seed ${run['seed']} frame $f';
        expect(p.mode, e[4], reason: 'mode @ $where');
        expect(p.x, closeTo((e[0] as num).toDouble(), 1e-6), reason: 'x @ $where');
        expect(p.y, closeTo((e[1] as num).toDouble(), 1e-6), reason: 'y @ $where');
        expect(p.vx, closeTo((e[2] as num).toDouble(), 1e-6), reason: 'vx @ $where');
        expect(p.vy, closeTo((e[3] as num).toDouble(), 1e-6), reason: 'vy @ $where');
        expect(p.onGround ? 1 : 0, e[5], reason: 'ground @ $where');
        expect(p.anim, e[6], reason: 'anim @ $where');
      }
    }
  });

  test('every area builds and survives a fuzzed playthrough', () async {
    for (var area = 0; area < 11; area++) {
      final progress = Progress()..area = area;
      final engine = SkyrootEngine(maps: maps, saved: progress);
      engine.buildRun();
      await engine.loaded;
      expect(engine.state.phase, 'play');
      final rnd = math.Random(area + 1);
      var mx = 0.0, my = 0.0;
      for (var f = 0; f < 3600; f++) {
        if (f % 20 == 0) {
          mx = rnd.nextInt(3) - 1.0;
          my = rnd.nextInt(4) == 0 ? (rnd.nextBool() ? -1 : 1) : 0;
        }
        final i = engine.input;
        i.mx = mx;
        i.my = my;
        if (rnd.nextInt(25) == 0) {
          i.jumpPressed = true;
          i.jumpHeld = true;
        } else if (rnd.nextInt(10) == 0) {
          i.jumpHeld = false;
        }
        if (rnd.nextInt(60) == 0) i.dashPressed = true;
        if (rnd.nextInt(40) == 0) {
          i.bowDown = true;
          i.bowHeld = true;
        } else if (i.bowHeld && rnd.nextInt(15) == 0) {
          i.bowHeld = false;
          i.bowReleased = true;
        }
        if (rnd.nextInt(200) == 0) i.skillPressed = true;
        engine.update(1 / 60);
      }
      expect(engine.state.player.hp.isFinite, isTrue);
      expect(engine.state.player.x.isFinite, isTrue);
    }
  });

  test('skins accumulate perks and saves round-trip', () {
    expect(skins.length, 11);
    expect(skins[10].shots, 5);
    expect(skins[10].hp, 3);
    expect(skins[10].skill, 'guardian');
    final p = Progress()
      ..dash = true
      ..maxHp = 5;
    p.areas[2].got.add('E@19,33');
    final again = Progress.sanitize(jsonDecode(jsonEncode(p.toJson())));
    expect(again.dash, isTrue);
    expect(again.maxHp, 5);
    expect(again.areas[2].got, ['E@19,33']);
    expect(Progress.sanitize(null).maxHp, 3);
  });
}
