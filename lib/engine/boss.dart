// Rusa Menara (the Tower Stag) and
// The ten upper-area bosses.
import 'dart:math' as math;

import 'content.dart';
import 'entities.dart';
import 'physics.dart';
import 'player.dart';
import 'state.dart';

abstract class BossBase {
  double x = 0, y = 0, hp = 0, maxHp = 0;
  String state = 'sleep';
  double t = 0, animT = 0, hurtT = 0, fade = 0;
}

// ---------------------------------------------------------------------------
// Rusa Menara, the Tower Stag. Shoot its three antler nodes to bring its head
// down, then hit the glowing rune on its forehead. Two phases.

/// Sheet pixels -> tiles. The sheet draws the stag facing left.
const stagScale = 7 / 337;
const _nodeOffsets = [(-109.0, -270.0), (-15.0, -276.0), (43.0, -276.0)];
const _weakOffset = (-92.0, -62.0);
const _stagFloorY = 12.0;

class StagBoss extends BossBase {
  StagBoss(double bx, double by, bool defeated, int maxHpValue) {
    x = bx + 0.5;
    y = by + 1;
    hp = maxHpValue.toDouble();
    maxHp = maxHpValue.toDouble();
    state = defeated ? 'gone' : 'sleep';
  }
  List<bool> nodes = [true, true, true];
  List<double> nodeFlash = [0, 0, 0];
  String next = 'shoot';
  bool fired = false;
}

({double x, double y}) nodePos(StagBoss b, int i) =>
    (x: b.x + _nodeOffsets[i].$1 * stagScale, y: b.y + _nodeOffsets[i].$2 * stagScale);

({double x, double y}) weakPos(StagBoss b) => (x: b.x + _weakOffset.$1 * stagScale, y: b.y + _weakOffset.$2 * stagScale);

Aabb stagBodyRect(StagBoss b) => Aabb(b.x - 1.7, b.x + 1.7, b.y - 3.4, b.y);

void updateBoss(GameState g, double dt) {
  final b = g.boss;
  if (b is! StagBoss || b.state == 'gone') return;
  final p = g.player;
  b.animT += dt;
  b.hurtT = math.max(0, b.hurtT - dt);
  for (var i = 0; i < 3; i++) {
    b.nodeFlash[i] = math.max(0, b.nodeFlash[i] - dt);
  }
  final phase2 = b.hp <= (b.maxHp / 2).ceil();
  if (b.state == 'sleep') {
    if (p.y < _stagFloorY + 0.2 && p.mode != 'dead') {
      b.state = 'idle';
      b.t = 0;
      g.events.add(GameEvent('bossStart'));
    }
    return;
  }
  if (b.state == 'dying') {
    b.t += dt;
    b.fade = math.min(1, b.t / 1.8);
    if (b.t > 2.0) {
      b.state = 'gone';
      g.events.add(GameEvent('bossDefeated'));
    }
    return;
  }
  b.t += dt;
  if (b.state == 'idle') {
    if (b.t > (phase2 ? 0.75 : 1.3)) {
      b.state = b.next;
      b.next = b.next == 'shoot' ? 'stomp' : 'shoot';
      b.t = 0;
      b.animT = 0;
      b.fired = false;
    }
  } else if (b.state == 'shoot') {
    if (!b.fired && b.t >= 0.75) {
      b.fired = true;
      final n = phase2 ? 5 : 3;
      final ox = b.x - 1.2;
      final oy = b.y - 5.8;
      for (var i = 0; i < n; i++) {
        final tx = math.max(11.5, math.min(27.0, p.x + (i - (n - 1) / 2) * 2.2));
        final tt = 1.05 + i * 0.06;
        const gg = 18.0;
        g.eproj.add(EProj(
          kind: 'seed', x: ox, y: oy, vx: (tx - ox) / tt, vy: (_stagFloorY - 0.2 - oy - 0.5 * gg * tt * tt) / tt, g: gg, r: 0.32,
        ));
      }
      g.events.add(GameEvent('bossShoot'));
    }
    if (b.t > 1.35) _toIdle(b);
  } else if (b.state == 'stomp') {
    if (!b.fired && b.t >= 0.62) {
      b.fired = true;
      g.eproj.add(EProj(kind: 'shock', x: b.x - 1.8, y: _stagFloorY - 0.4, vx: phase2 ? -11 : -9, vy: 0, r: 0.45, life: 3.2));
      g.events.add(GameEvent('stomp'));
      if (phase2) {
        for (var i = 0; i < 4; i++) {
          final x = 11 + ((g.uid * 7 + i * 5) % 16);
          g.warnings.add(Warning(x, 0, 0.75));
        }
      }
    }
    if (b.t > 1.3) _toIdle(b);
  } else if (b.state == 'stunned') {
    if (b.t > 4.2) {
      b.nodes = [true, true, true];
      _toIdle(b);
    }
  }
  // Body contact hurts unless the stag is stunned.
  if (b.state != 'stunned' && p.mode != 'dead' && rectsOverlap(stagBodyRect(b), bodyRect(p))) {
    hurtPlayer(g, p, 1, b.x);
  }
}

void _toIdle(StagBoss b) {
  b.state = 'idle';
  b.t = 0;
  b.animT = 0;
}

/// Arrow vs boss: returns true when the arrow is consumed.
bool arrowHitsBoss(GameState g, Arrow a) {
  final b = g.boss;
  if (b is! StagBoss || b.state == 'gone' || b.state == 'sleep' || b.state == 'dying') return false;
  if (b.state == 'stunned') {
    final w = weakPos(b);
    if (hypot(a.x - w.x, a.y - w.y) < 0.75) {
      b.hp -= a.dmg;
      b.hurtT = 0.25;
      g.events.add(GameEvent('bossHurt', x: w.x, y: w.y));
      g.fx.add(Fx('arrow_hit', a.x, a.y, dur: 0.3, scale: 1.6));
      if (b.hp <= 0) {
        b.state = 'dying';
        b.t = 0;
        g.events.add(GameEvent('bossDying'));
      }
      return true;
    }
  } else {
    for (var i = 0; i < 3; i++) {
      if (!b.nodes[i]) continue;
      final n = nodePos(b, i);
      if (hypot(a.x - n.x, a.y - n.y) < 0.62) {
        b.nodes[i] = false;
        b.nodeFlash[i] = 0.4;
        g.fx.add(Fx('leaf_burst', n.x, n.y + 0.6, dur: 0.5, scale: 0.8));
        g.events.add(GameEvent('nodeBreak', x: n.x, y: n.y));
        if (!b.nodes.any((e) => e)) {
          b.state = 'stunned';
          b.t = 0;
          b.animT = 0;
          g.events.add(GameEvent('bossStun'));
        }
        return true;
      }
    }
  }
  final r = stagBodyRect(b);
  if (a.x > r.x0 && a.x < r.x1 && a.y > r.y0 - 2.5 && a.y < r.y1) {
    g.fx.add(Fx('arrow_hit', a.x, a.y, dur: 0.3));
    a.state = 'drop';
    a.t = 0;
    a.vx = -a.vx * 0.2;
    a.vy = -4;
    g.events.add(GameEvent('block', x: a.x, y: a.y));
    return false;
  }
  return false;
}

void updateWarnings(GameState g, double dt) {
  for (final w in g.warnings) {
    w.t += dt;
    if (w.t >= w.dur && !w.done) {
      w.done = true;
      g.eproj.add(EProj(kind: 'debris', sprite: w.sprite, x: w.x + 0.5, y: 1.5, vx: 0, vy: 6, g: 40, r: 0.4));
    }
  }
  g.warnings = g.warnings.where((w) => !w.done || w.t < w.dur + 0.1).toList();
}

// ---------------------------------------------------------------------------
// Bosses of the ten upper areas, driven by their attack lists in content.dart.
// The arena is the same in every area: floor at row 12, walls at columns 11 and 33.

const _floor = 12.0;
const _left = 11.5;
const _right = 32.5;

class AreaBoss extends BossBase {
  AreaBoss(this.area, double bx, double by, bool defeated) {
    final cfg = bosses[area]!;
    x = bx + 0.5;
    y = cfg.fly ? 7.5 : by + 1;
    homeX = bx + 0.5;
    hp = cfg.hp.toDouble();
    maxHp = cfg.hp.toDouble();
    state = defeated ? 'gone' : 'sleep';
  }
  final int area;
  late final double homeX;
  int face = -1, next = 0, phase = 1, fired = 0;
  double vx = 0, vy = 0, tired = 0;
}

Aabb bossRect(AreaBoss b) {
  final cfg = bosses[b.area]!;
  final h = cfg.height * 0.78;
  final w = cfg.height * 0.55;
  return Aabb(b.x - w / 2, b.x + w / 2, b.y - h, b.y);
}

List<String> _attacksFor(AreaBoss b) {
  final cfg = bosses[b.area]!;
  final list = [...cfg.attacks];
  if (b.phase >= 2) list.addAll(cfg.p2);
  if (b.phase >= 3) list.addAll(cfg.p3);
  return list;
}

void updateAreaBoss(GameState g, double dt) {
  final b = g.boss;
  if (b is! AreaBoss || b.state == 'gone') return;
  final cfg = bosses[b.area]!;
  final p = g.player;
  b.animT += dt;
  b.hurtT = math.max(0, b.hurtT - dt);
  b.tired = math.max(0, b.tired - dt);
  if (b.state == 'sleep') {
    if (p.y < _floor + 0.2 && p.mode != 'dead') {
      b.state = 'idle';
      b.t = 0;
      g.events.add(GameEvent('bossStart', name: cfg.name));
    }
    return;
  }
  if (b.state == 'dying') {
    b.t += dt;
    b.fade = math.min(1, b.t / 1.6);
    if (b.t > 1.8) {
      b.state = 'gone';
      g.events.add(GameEvent('bossDefeated', generic: true));
    }
    return;
  }
  // Phases
  final ratio = b.hp / b.maxHp;
  final newPhase = cfg.p3.isNotEmpty && ratio <= 0.3 ? 3 : (ratio <= 0.55 ? 2 : 1);
  if (newPhase > b.phase) {
    b.phase = newPhase;
    b.hurtT = 0.6;
    g.events.add(GameEvent('bossPhase', phase: newPhase));
  }
  final fast = b.phase >= 2 ? 0.7 : 1.0;
  b.face = p.x < b.x ? -1 : 1;
  b.t += dt;

  // Flyers drift around the upper arena between attacks.
  if (cfg.fly && (b.state == 'idle' || b.state == 'spray' || b.state == 'ring' || b.state == 'beam' || b.state == 'summon')) {
    final tx = 22 + math.sin(b.animT * 0.5) * 7;
    final ty = 7.2 + math.sin(b.animT * 1.1) * 1.2;
    b.x += (tx - b.x) * math.min(1, dt * 0.9);
    b.y += (ty - b.y) * math.min(1, dt * 1.2);
  }

  if (b.state == 'idle') {
    if (!cfg.fly) b.x += (b.homeX - b.x) * math.min(1, dt * 1.5);
    if (b.t > 1.2 * fast) {
      final list = _attacksFor(b);
      b.state = list[b.next % list.length];
      b.next++;
      b.t = 0;
      b.animT = 0;
      b.fired = 0;
      if (b.state == 'charge' && cfg.fly) b.state = 'dive';
      if ((b.state == 'shock' || b.state == 'charge') && cfg.fly) b.state = 'spray';
    }
  } else if (b.state == 'spray') {
    if (b.t > 0.6 && b.fired == 0) {
      b.fired = 1;
      final n = b.phase >= 2 ? 5 : 3;
      final ox = b.x + b.face * 1.2;
      final oy = b.y - cfg.height * 0.65;
      for (var i = 0; i < n; i++) {
        final tx = math.max(_left, math.min(_right, p.x + (i - (n - 1) / 2) * 2));
        final tt = 1.0 + i * 0.05;
        const gg = 18.0;
        g.eproj.add(EProj(
          kind: 'shot', sprite: cfg.shot, x: ox, y: oy, vx: (tx - ox) / tt, vy: (_floor - 0.3 - oy - 0.5 * gg * tt * tt) / tt,
          g: gg, r: 0.35, splash: true, spin: true,
        ));
      }
      g.events.add(GameEvent('bossShoot'));
    }
    if (b.t > 1.2) _areaToIdle(b);
  } else if (b.state == 'ring') {
    if (b.t > 0.7 && b.fired < (b.phase >= 2 ? 2 : 1) && b.t > 0.7 + b.fired * 0.45) {
      final n = b.phase >= 2 ? 14 : 10;
      final off = b.fired * (math.pi / n);
      for (var i = 0; i < n; i++) {
        final a = (i / n) * math.pi * 2 + off;
        g.eproj.add(EProj(
          kind: 'shot', sprite: cfg.shot, x: b.x, y: b.y - cfg.height * 0.5, vx: math.cos(a) * 5.5, vy: math.sin(a) * 5.5,
          r: 0.3, spin: true,
        ));
      }
      b.fired++;
      g.events.add(GameEvent('bossShoot'));
    }
    if (b.t > 1.7) _areaToIdle(b);
  } else if (b.state == 'shock') {
    if (b.t > 0.65 && b.fired == 0) {
      b.fired = 1;
      final sp = b.phase >= 2 ? 11.0 : 9.0;
      g.eproj.add(EProj(kind: 'shock', x: b.x - 1.5, y: _floor - 0.4, vx: -sp, vy: 0, r: 0.45, life: 2.8));
      g.eproj.add(EProj(kind: 'shock', x: b.x + 1.5, y: _floor - 0.4, vx: sp, vy: 0, r: 0.45, life: 2.8));
      g.events.add(GameEvent('stomp'));
    }
    if (b.t > 1.25) _areaToIdle(b);
  } else if (b.state == 'rain') {
    if (b.t > 0.4 && b.fired == 0) {
      b.fired = 1;
      final n = b.phase >= 2 ? 7 : 5;
      for (var i = 0; i < n; i++) {
        final x = jsRound(_left + 1 + ((g.uid * 3 + i * 5.3) % (_right - _left - 2)));
        g.warnings.add(Warning(x, -i * 0.08, 0.8, cfg.shot));
      }
      g.warnings.add(Warning(p.x.floor(), 0, 0.8, cfg.shot));
    }
    if (b.t > 1.4) _areaToIdle(b);
  } else if (b.state == 'charge') {
    if (b.t < 0.6) {
      b.vx = 0;
    } else {
      if (b.vx == 0) b.vx = (p.x < b.x ? -1 : 1) * (b.phase >= 2 ? 16.0 : 13.0);
      b.x += b.vx * dt;
      if (b.x < _left + 1.8 || b.x > _right - 1.8) {
        b.x = math.max(_left + 1.8, math.min(_right - 1.8, b.x));
        b.vx = 0;
        b.tired = 1.3;
        g.events.add(GameEvent('stomp'));
        b.state = 'tired';
        b.t = 0;
      }
    }
  } else if (b.state == 'tired') {
    if (b.t > 1.3) _areaToIdle(b);
  } else if (b.state == 'dive') {
    if (b.t < 0.5) {
      b.y -= dt * 2;
    } else if (b.fired == 0) {
      b.fired = 1;
      final l = hypot(p.x - b.x, p.y - 1 - b.y);
      final len = l == 0 ? 1.0 : l;
      b.vx = ((p.x - b.x) / len) * 15;
      b.vy = ((p.y - 1 - b.y) / len) * 15;
    } else {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.y > _floor - 0.2 || b.x < _left || b.x > _right || b.t > 1.6) {
        b.y = math.min(b.y, _floor - 0.2);
        b.x = math.max(_left, math.min(_right, b.x));
        b.tired = 0.9;
        b.state = 'tired';
        b.t = 0;
      }
    }
  } else if (b.state == 'beam') {
    if (b.fired == 0) {
      b.fired = 1;
      final n = b.phase >= 2 ? 5 : 3;
      for (var i = 0; i < n; i++) {
        final x = math.max(_left, math.min(_right, p.x + (i - (n - 1) / 2) * 3.2));
        g.beams.add(Beam(x, -i * 0.12, 0.85, 0.35));
      }
    }
    if (b.t > 1.6) _areaToIdle(b);
  } else if (b.state == 'summon') {
    if (b.t > 0.7 && b.fired == 0) {
      b.fired = 1;
      final alive = g.enemies.where((e) => e.summoned).length;
      if (alive < 4) g.events.add(GameEvent('summon', x: b.x, y: b.y));
    }
    if (b.t > 1.2) _areaToIdle(b);
  }

  if (p.mode != 'dead' && b.state != 'tired' && rectsOverlap(bossRect(b), bodyRect(p))) {
    hurtPlayer(g, p, 1, b.x);
  }
}

void _areaToIdle(AreaBoss b) {
  b.state = 'idle';
  b.t = 0;
  b.animT = 0;
  b.vx = 0;
}

/// Arrow vs area boss: true when consumed.
bool arrowHitsAreaBoss(GameState g, Arrow a) {
  final b = g.boss;
  if (b is! AreaBoss || b.state == 'gone' || b.state == 'sleep' || b.state == 'dying') return false;
  final r = bossRect(b);
  if (a.x < r.x0 || a.x > r.x1 || a.y < r.y0 || a.y > r.y1) return false;
  damageAreaBoss(g, a.dmg * (b.tired > 0 ? 1.5 : 1.0));
  g.fx.add(Fx('arrow_hit', a.x, a.y, dur: 0.3, scale: 1.2));
  return true;
}

void damageAreaBoss(GameState g, double dmg) {
  final b = g.boss;
  if (b is! AreaBoss || b.state == 'gone' || b.state == 'sleep' || b.state == 'dying') return;
  b.hp -= dmg;
  b.hurtT = math.max(b.hurtT, 0.18);
  g.events.add(GameEvent('bossHurt', quiet: true));
  if (b.hp <= 0) {
    b.hp = 0;
    b.state = 'dying';
    b.t = 0;
    g.events.add(GameEvent('bossDying'));
  }
}

void updateBeams(GameState g, double dt) {
  final p = g.player;
  for (final bm in g.beams) {
    bm.t += dt;
    if (bm.t >= bm.warn && !bm.struck) {
      bm.struck = true;
      g.events.add(GameEvent('thunder'));
      if ((p.x - bm.x).abs() < 0.8 && p.mode != 'dead') hurtPlayer(g, p, 1, bm.x);
    }
  }
  g.beams = g.beams.where((bm) => bm.t < bm.warn + bm.life).toList();
}
