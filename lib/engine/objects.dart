// Living platforms and world objects: folding leaves, crumbling slabs, launch
// flowers, wind gusts, shrines, pickups, cracked walls, lift, rope and bell.
// Port of game js/game/objects.js.
import 'dart:math' as math;

import 'entities.dart';
import 'physics.dart';
import 'state.dart';
import 'world.dart';

const _leafTrem = 0.55, _leafFold = 0.25, _leafClosed = 1.6, _leafOpen = 0.3;
const _crumbleShake = 0.5, _crumbleFall = 0.35, _crumbleGone = 2.6, _crumbleBack = 0.4;

/// One-way surfaces the player can stand on this frame.
List<Platform> collectPlatforms(GameState g) {
  final out = <Platform>[];
  for (final l in g.leaves) {
    if (l.state == 'open' || l.state == 'trem') out.add(Platform(l.x0.toDouble(), l.x1 + 1.0, l.y.toDouble(), 'leaf:${l.id}'));
  }
  for (final c in g.crumbles) {
    if (c.state == 'ok' || c.state == 'shake') out.add(Platform(c.x0.toDouble(), c.x1 + 1.0, c.y.toDouble(), 'crumble:${c.id}'));
  }
  for (final f in g.footings) {
    if (f.t > 0.12) out.add(Platform(f.x0, f.x1, f.top, 'foot:${f.id}'));
  }
  if (g.areaIndex == 0 && g.progress.areas[0].boss) {
    for (final n in g.bridge) {
      out.add(Platform(n.x0.toDouble(), n.x1 + 1.0, n.y.toDouble(), 'bridge'));
    }
  }
  for (final m in g.movers) {
    out.add(Platform(m.px, m.px + m.w, m.py, 'mover:${m.id}'));
  }
  return out;
}

/// Moving platforms carry whoever stands on them; run before the player moves.
void updateMovers(GameState g, double dt) {
  final p = g.player;
  for (final m in g.movers) {
    m.t += dt;
    final off = math.sin(m.t * m.speed + m.phase) * m.amp;
    final nx = m.axis == 'x' ? m.x0 + off : m.x0.toDouble();
    final ny = m.axis == 'y' ? m.y + off : m.y.toDouble();
    final dx = nx - m.px;
    m.px = nx;
    m.py = ny;
    if (p.onGround && p.groundId == 'mover:${m.id}' && p.mode == 'normal') {
      p.x += dx;
      p.y = ny;
    }
  }
}

void updateHazards(GameState g, double dt) {
  final p = g.player;
  // Stalactites shake, then drop on whoever walks beneath.
  for (final v in g.stalactites) {
    v.t += dt;
    if (v.state == 'hang' && (p.x - (v.x + 0.5)).abs() < 1.1 && p.y > v.y && p.y - v.y < 9) {
      v.state = 'shake';
      v.t = 0;
    } else if (v.state == 'shake' && v.t > 0.45) {
      v.state = 'gone';
      v.t = 0;
      g.eproj.add(EProj(
        kind: 'shot', sheet: 'AREA_PROPS', sprite: 'stalactite', x: v.x + 0.5, y: v.y + 0.6, vx: 0, vy: 2, g: 38,
        r: 0.35, splash: true, upright: true,
      ));
    } else if (v.state == 'gone' && v.t > 3.5) {
      v.state = 'hang';
      v.t = 0;
    }
  }
  // Gate to the next area.
  final gt = g.gate;
  // gateHold stays set after "Jelajah lagi" until the archer steps out of the gate,
  // so standing in it doesn't reopen the ending panel every frame.
  final inGate = gt != null && (p.x - (gt.x + 0.5)).abs() < 0.9 && (p.y - (gt.y + 1)).abs() < 1.5;
  if (!inGate) g.gateHold = false;
  if (gt != null && gt.active && p.mode == 'normal' && inGate && !g.gateHold) g.events.add(GameEvent('gate'));
}

void _set(dynamic o, String state) {
  o.state = state;
  o.t = 0.0;
}

void updateObjects(GameState g, double dt) {
  final p = g.player;
  final standing = p.onGround ? p.groundId : null;

  for (final l in g.leaves) {
    l.t += dt;
    final on = standing == 'leaf:${l.id}';
    if (l.state == 'open' && on) {
      _set(l, 'trem');
    } else if (l.state == 'trem' && l.t >= _leafTrem) {
      _set(l, 'fold');
      g.events.add(GameEvent('leaf', x: (l.x0 + l.x1) / 2, y: l.y.toDouble()));
    } else if (l.state == 'fold' && l.t >= _leafFold) {
      _set(l, 'closed');
    } else if (l.state == 'closed' && l.t >= _leafClosed) {
      _set(l, 'opening');
    } else if (l.state == 'opening' && l.t >= _leafOpen) {
      _set(l, 'open');
    }
  }

  for (final c in g.crumbles) {
    c.t += dt;
    final on = standing == 'crumble:${c.id}';
    if (c.state == 'ok' && on) {
      _set(c, 'shake');
      g.events.add(GameEvent('crack', x: (c.x0 + c.x1) / 2 + 0.5, y: c.y.toDouble(), quiet: true));
    } else if (c.state == 'shake' && c.t >= _crumbleShake) {
      _set(c, 'fall');
      g.events.add(GameEvent('crumble', x: (c.x0 + c.x1) / 2 + 0.5, y: c.y.toDouble()));
    } else if (c.state == 'fall' && c.t >= _crumbleFall) {
      _set(c, 'gone');
    } else if (c.state == 'gone' && c.t >= _crumbleGone) {
      _set(c, 'back');
    } else if (c.state == 'back' && c.t >= _crumbleBack) {
      _set(c, 'ok');
    }
  }

  for (final f in g.flowers) {
    f.t += dt;
    final near = p.onGround && (p.x - (f.x + 0.5)).abs() < 0.65 && (p.y - (f.y + 1)).abs() < 0.1;
    if (f.state == 'idle' && near) {
      _set(f, 'charge');
    } else if (f.state == 'charge' && f.t >= 0.45) {
      _set(f, 'launch');
      if ((p.x - (f.x + 0.5)).abs() < 0.9 && (p.y - (f.y + 1)).abs() < 0.6 && p.mode == 'normal') {
        p.vy = -34;
        p.onGround = false;
        p.jumping = false;
        p.y -= 0.05;
        g.events.add(GameEvent('launch', x: f.x + 0.5, y: f.y + 1.0));
      }
    } else if (f.state == 'launch' && f.t >= 0.9) {
      _set(f, 'idle');
    }
  }

  final windMul = g.tune.windStrength;
  for (final w in g.winds) {
    w.t += dt;
    final cycle = w.on ? 2.7 : 1.4;
    if (w.t >= cycle) {
      w.on = !w.on;
      w.t = 0;
    }
    if (!w.on || p.mode != 'normal') continue;
    final r = Aabb(w.x0.toDouble(), w.x1 + 1.0, w.y0.toDouble(), w.y1 + 1.0);
    if (rectsOverlap(r, bodyRect(p))) {
      p.vy -= 118 * windMul * dt;
      if (p.vy < -9 * windMul) p.vy = -9 * windMul;
      p.onGround = false;
      p.airDashLeft = math.max(p.airDashLeft, 1);
      p.focus = math.min(1.6, p.focus + dt);
    }
  }

  for (final k in g.checkpoints) {
    k.animT += dt;
    final near = (p.x - (k.x + 0.5)).abs() < 1.0 && (p.y - (k.y + 1)).abs() < 1.4;
    if (near && p.mode != 'dead') {
      if (g.areaProg.cp != k.id) {
        g.areaProg.cp = k.id;
        k.lit = true;
        g.events.add(GameEvent('checkpoint', x: k.x.toDouble(), y: k.y.toDouble()));
      }
      p.hp = math.max(p.hp, g.maxHp.toDouble());
      p.energy = math.min(g.maxEnergy.toDouble(), p.energy + dt * 2.5);
    }
  }

  for (final it in g.pickups) {
    it.t += dt;
    if (it.taken) continue;
    if ((p.x - (it.x + 0.5)).abs() < 0.8 && p.y - p.h < it.y + 1 && p.y > it.y && p.mode != 'dead') {
      it.taken = true;
      g.events.add(GameEvent('pickup', kind: it.kind, id: it.id, x: it.x + 0.5, y: it.y + 0.5));
    }
  }

  // Lift stations.
  final lf = g.lift;
  if (lf != null) {
    for (final st in [lf.top, lf.bottom]) {
      st.near = p.onGround && (p.x - (st.x + 0.5)).abs() < 1.1 && (p.y - (st.y + 1)).abs() < 0.1;
    }
    if (!g.progress.lift && lf.top.near) g.events.add(GameEvent('liftOn'));
    final ride = lf.ride;
    if (ride != null) {
      ride.t += dt;
      if (!ride.moved && ride.t >= 0.55) {
        ride.moved = true;
        final to = ride.to;
        p.x = to.x + 0.5;
        p.y = to.y + 1.0;
        p.vx = 0;
        p.vy = 0;
        g.cam.snap = true;
      }
      if (ride.t >= 1.1) {
        lf.ride = null;
        p.mode = 'normal';
      }
    } else if (g.progress.lift && p.mode == 'normal') {
      final wantUp = g.inMy < -0.6 || g.inUpPressed;
      final wantDown = g.inMy > 0.6;
      if (lf.bottom.near && wantUp) {
        _startRide(g, lf, lf.top);
      } else if (lf.top.near && (wantDown || wantUp)) {
        _startRide(g, lf, lf.bottom);
      }
    }
  }

  // Rope anchor.
  final rope = g.rope;
  if (rope != null && !g.progress.rope && (p.x - (rope.x + 0.5)).abs() < 0.9 && (p.y - (rope.y + 1)).abs() < 1.2) {
    g.events.add(GameEvent('ropeOpen'));
  }

  // Bell: ring it after the stag falls.
  final bell = g.bell;
  if (bell != null && g.progress.areas[0].boss && !g.progress.bell) {
    if ((p.x - (bell.x + 0.5)).abs() < 1.3 && (p.y - (bell.y + 1)).abs() < 1.6) g.events.add(GameEvent('bell'));
  }
  if (bell != null) bell.animT += dt;

  for (final v in g.villagers) {
    v.near = (p.x - (v.x + 0.5)).abs() < 2.6 && (p.y - (v.y + 1)).abs() < 2;
  }
}

void _startRide(GameState g, Lift l, LiftStation to) {
  l.ride = LiftRide(to);
  g.player.mode = 'lift';
  g.player.aiming = false;
  g.events.add(GameEvent('lift'));
}

Crack? breakCrackAt(GameState g, int cx, int cy) {
  for (final c in g.cracks) {
    if (c.broken || c.x != cx || cy < c.y0 || cy > c.y1) continue;
    c.broken = true;
    g.world.setCrackSolid(Strip(c.x, c.y0, c.y1), false);
    return c;
  }
  return null;
}
