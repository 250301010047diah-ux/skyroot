// The bow (aim, quick shot, full draw, Air Focus), arrows in flight, Footing
// Arrow steps, and enemy projectiles. Port of game js/game/combat.js.
import 'dart:math' as math;

import 'entities.dart';
import 'physics.dart';
import 'player.dart';
import 'state.dart';
import 'world.dart';

const _fullDraw = 0.55;
const _quickTime = 0.17;

void updateBow(GameState g, Player p, InputState inp, double realDt, Tune tune) {
  final fullDraw = _fullDraw * tune.skin.draw;
  final canAim = p.mode == 'normal';
  if (!canAim) {
    p.aiming = false;
    return;
  }
  if (inp.bowDown && !p.aiming) {
    p.aiming = true;
    p.aimT = 0;
    p.aimX = p.face.toDouble();
    p.aimY = 0;
  }
  if (!p.aiming) return;
  p.aimT += realDt;
  double dx = p.face.toDouble();
  double dy = 0;
  if (inp.aimSource == 'pointer') {
    dx = inp.aimWX - p.x;
    dy = inp.aimWY - (p.y - 1.0);
  } else if (inp.aimSource == 'drag' && inp.dragLen > 14) {
    dx = inp.dragX;
    dy = inp.dragY;
  } else if (inp.aimSource == 'key') {
    if (inp.mx.abs() > 0.3) p.face = inp.mx > 0 ? 1 : -1;
    dx = p.face.toDouble();
    dy = inp.my < -0.4 ? -1 : (inp.my > 0.4 ? 0.6 : 0);
  }
  var len = hypot(dx, dy);
  if (len == 0) len = 1;
  p.aimX = dx / len;
  p.aimY = dy / len;
  if (p.aimX.abs() > 0.08) p.face = p.aimX > 0 ? 1 : -1;

  if (inp.bowReleased) {
    final quick = p.aimT < _quickTime && !(inp.aimSource == 'drag' && inp.dragLen > 14);
    var ax = p.aimX;
    var ay = p.aimY;
    var power = math.min(1.0, p.aimT / fullDraw);
    if (quick) {
      power = 0.35;
      if (inp.aimSource != 'pointer') {
        final t = _autoTarget(g, p);
        if (t != null) {
          final ddx = t.x - p.x;
          final ddy = t.y - (p.y - 1.0);
          var l = hypot(ddx, ddy);
          if (l == 0) l = 1;
          ax = ddx / l;
          ay = ddy / l;
          // Lift a little against arrow drop.
          ay -= math.min(0.12, l * 0.008);
        } else {
          ax = p.face.toDouble();
          ay = 0;
        }
      }
    }
    _fireArrow(g, p, ax, ay, power, tune);
    p.aiming = false;
    p.releaseT = 0.16;
    p.face = ax >= 0 ? 1 : -1;
  }
}

AimTarget? _autoTarget(GameState g, Player p) {
  AimTarget? best;
  var bestD = 11.0;
  for (final t in g.aimTargets) {
    final d = hypot(t.x - p.x, t.y - (p.y - 1));
    if (d < bestD && g.world.clearLine(p.x, p.y - 1, t.x, t.y)) {
      best = t;
      bestD = d;
    }
  }
  return best;
}

typedef ArrowLaunch = ({double x, double y, double vx, double vy, double g});

ArrowLaunch arrowLaunch(Player p, double ax, double ay, double power, Tune tune) {
  final speed = tune.arrowSpeed * (0.72 + 0.48 * power);
  return (x: p.x + p.face * 0.3, y: p.y - 1.0, vx: ax * speed, vy: ay * speed, g: 20 * (1 - 0.7 * power));
}

void _fireArrow(GameState g, Player p, double ax, double ay, double power, Tune tune) {
  final skin = tune.skin;
  var kind = 'normal';
  if (g.progress.footing && g.arrowType == 'footing') {
    if (p.energy >= 1) {
      p.energy -= 1;
      kind = 'footing';
    } else {
      g.events.add(GameEvent('noenergy'));
    }
  }
  final full = power >= 1;
  final shots = kind == 'footing' ? 1 : skin.shots * (g.cloneT > 0 ? 2 : 1);
  final base = math.atan2(ay, ax);
  final perVolley = kind == 'footing' ? 1 : skin.shots;
  for (var i = 0; i < shots; i++) {
    final volley = i ~/ perVolley;
    final j = i % perVolley;
    final spread = perVolley > 1 ? (j - (perVolley - 1) / 2) * 0.13 : 0.0;
    final ang = base + spread;
    final l = arrowLaunch(p, math.cos(ang), math.sin(ang), power, tune);
    // The moon clone fires from above the archer.
    final ly = volley == 1 ? l.y - 1.6 : l.y;
    g.arrows.add(Arrow(
      id: g.uid++,
      kind: kind == 'footing' ? 'footing' : 'normal',
      sprite: kind == 'footing' ? 'footing_arrow' : skin.arrow,
      x: l.x, y: ly, vx: l.vx, vy: l.vy, g: l.g,
      dmg: (full ? 2 : 1) + skin.dmg,
      full: full,
      pierce: skin.pierce,
      burn: skin.burn,
      slow: skin.slow,
      chain: skin.chain && full,
      homing: skin.homing,
    ));
  }
  g.events.add(GameEvent('shoot', full: full, kind: kind));
}

/// Arrows rained from the sky by skills.
void rainArrows(GameState g, double left, double width, double top, int count, String sprite, int dmg, {bool slow = false, int pierce = 0}) {
  for (var i = 0; i < count; i++) {
    final x = left + ((i + 0.5) / count) * width + math.sin(i * 12.9) * 0.4;
    g.arrows.add(Arrow(
      id: g.uid++, kind: 'normal', sprite: sprite, x: x, y: top - (i % 3) * 0.8, vx: 0.6, vy: 26, g: 10,
      dmg: dmg, full: true, pierce: pierce, burn: false, slow: slow, chain: false, homing: false, bounces: 9, rain: true,
    ));
  }
}

/// [hitTest] returns true when an enemy/boss consumed the arrow.
void updateArrows(GameState g, double dt, bool Function(Arrow) hitTest) {
  final world = g.world;
  for (final a in g.arrows) {
    a.t += dt;
    if (a.state == 'stuck' || a.state == 'drop') {
      if (a.state == 'drop') {
        a.vy += 30 * dt;
        a.x += a.vx * dt;
        a.y += a.vy * dt;
        a.spin += dt * 14;
      }
      if (a.t > 1.4) a.dead = true;
      continue;
    }
    if (a.homing && a.t > 0.06) {
      AimTarget? best;
      var bd = 9.0;
      for (final t in g.aimTargets) {
        final d = hypot(t.x - a.x, t.y - a.y);
        if (d < bd && !a.hits.contains(t.id)) {
          bd = d;
          best = t;
        }
      }
      if (best != null) {
        final sp = hypot(a.vx, a.vy);
        final want = math.atan2(best.y - a.y, best.x - a.x);
        var cur = math.atan2(a.vy, a.vx);
        var diff = want - cur;
        while (diff > math.pi) {
          diff -= math.pi * 2;
        }
        while (diff < -math.pi) {
          diff += math.pi * 2;
        }
        cur += math.max(-1.0, math.min(1.0, diff)) * math.min(1.0, dt * 9);
        a.vx = math.cos(cur) * sp;
        a.vy = math.sin(cur) * sp;
        a.g = 0;
      }
    }
    final steps = math.max(1, (hypot(a.vx, a.vy) * dt / 0.2).ceil());
    final sdt = dt / steps;
    for (var i = 0; i < steps && a.state == 'fly'; i++) {
      a.vy += a.g * sdt;
      final px = a.x;
      final py = a.y;
      a.x += a.vx * sdt;
      a.y += a.vy * sdt;
      if (hitTest(a)) {
        a.dead = true;
        break;
      }
      final cx = a.x.floor();
      final cy = a.y.floor();
      if (world.isSolidTile(cx, cy)) {
        final side = px.floor() != cx && world.isSolidTile(cx, py.floor()) ? true : py.floor() == cy;
        if (world.crackAt(cx, cy)) {
          g.events.add(GameEvent('crack', x: cx.toDouble(), y: cy.toDouble()));
          a.dead = true;
          break;
        }
        if (world.tileAt(cx, cy) == Tile.crystal && a.bounces < 3) {
          a.x = px;
          a.y = py;
          if (side) {
            a.vx = -a.vx;
          } else {
            a.vy = -a.vy;
          }
          a.bounces++;
          a.hits.clear();
          g.fx.add(Fx('arrow_hit', px, py, dur: 0.25, scale: 0.7));
          g.events.add(GameEvent('block'));
          continue;
        }
        if (a.rain) {
          a.dead = true;
          g.fx.add(Fx('arrow_hit', px, py, dur: 0.3));
          break;
        }
        // Back the tip out to the surface.
        a.x = px;
        a.y = py;
        a.state = 'stuck';
        a.t = 0;
        g.fx.add(Fx('arrow_hit', a.x, a.y, dur: 0.3));
        g.events.add(GameEvent('thunk', x: a.x, y: a.y));
        if (a.kind == 'footing') {
          final ok = side && world.tileAt(cx, cy) == Tile.soft && _makeFooting(g, cx, cy, a.vx > 0 ? 1 : -1, a.y);
          if (!ok) {
            g.player.energy = math.min(g.maxEnergy.toDouble(), g.player.energy + 1);
            g.events.add(GameEvent('footfail', x: a.x, y: a.y));
          } else {
            a.dead = true;
          }
        }
      }
    }
    if (a.t > 3 || a.y > 120 || a.y < -5) a.dead = true;
  }
  g.arrows = g.arrows.where((a) => !a.dead).toList();
}

/// A step grows out of the wall face the arrow hit. wallDir = +1 when the wall is to the right.
bool _makeFooting(GameState g, int cx, int cy, int wallDir, double hitY) {
  final world = g.world;
  final row = hitY - cy > 0.75 ? cy + 1 : cy;
  final nx0 = wallDir > 0 ? cx - 2 : cx + 1;
  // Standing room above both cells, and open air where the step itself sits.
  for (var i = 0; i < 2; i++) {
    if (world.isSolidTile(nx0 + i, row - 1)) return false;
  }
  if (world.isSolidTile(wallDir > 0 ? cx - 1 : cx + 1, row)) return false;
  // One step per spot: replace a footing already here.
  for (final f in g.footings) {
    if ((f.top - row).abs() < 0.6 && (f.x0 - nx0).abs() < 1.1) f.dying = 0.01;
  }
  g.footings.add(Footing(id: g.uid++, x0: nx0.toDouble(), x1: nx0 + 2.0, top: row.toDouble(), wallDir: wallDir));
  final alive = g.footings.where((f) => f.dying == 0).toList();
  final max = g.tune.footingMax;
  if (alive.length > max) {
    alive.sort((a, b) => a.id - b.id);
    for (var i = 0; i < alive.length - max; i++) {
      alive[i].dying = 0.65;
    }
  }
  g.events.add(GameEvent('sprout', x: nx0 + 1.0, y: row.toDouble()));
  return true;
}

void updateFootings(GameState g, double dt) {
  for (final f in g.footings) {
    f.t += dt;
    if (f.dying != 0) {
      f.dying -= dt;
      if (f.dying <= 0) f.dead = true;
    }
  }
  g.footings = g.footings.where((f) => !f.dead).toList();
}

// ---- Enemy projectiles
void updateProjectiles(GameState g, double dt) {
  final world = g.world;
  final p = g.player;
  for (final s in g.eproj) {
    s.t += dt;
    s.vy += s.g * dt;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    final r = s.r;
    if (p.mode != 'dead' && (s.x - p.x).abs() < r + p.w / 2 && s.y > p.y - p.h - r && s.y < p.y + r) {
      if (hurtPlayer(g, p, s.dmg, s.x)) {
        if (s.freeze) p.freezeT = 1.6;
        s.dead = true;
        g.fx.add(Fx('arrow_hit', s.x, s.y, dur: 0.3));
        continue;
      }
    }
    if (s.kind == 'shock') {
      if (s.t > (s.life ?? 5)) s.dead = true;
      continue;
    }
    if (world.isSolidTile(s.x.floor(), s.y.floor()) ||
        (s.kind == 'mud' && s.vy > 0 && world.tileAt(s.x.floor(), s.y.floor()) == Tile.oneway)) {
      s.dead = true;
      if (s.kind == 'mud' || s.kind == 'debris' || s.kind == 'seed' || s.splash) {
        g.fx.add(Fx('dust', s.x, s.y.floor().toDouble(), dur: 0.45, scale: 1.1));
        if ((s.x - p.x).abs() < 1.0 && (s.y.floor() - p.y).abs() < 1.2) hurtPlayer(g, p, 1, s.x);
        g.events.add(GameEvent('splat', x: s.x, y: s.y));
      }
    }
    if (s.t > 6) s.dead = true;
  }
  g.eproj = g.eproj.where((s) => !s.dead).toList();
}
