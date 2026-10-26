// Thorn Guards (straight bursts from a nest), Shield Beetles (front plate blocks
// arrows), Cannon Frogs (lobbed mud with a ground marker), plus the upper-area
// monsters. Port of game js/game/enemies.js.
import 'dart:math' as math;

import 'content.dart';
import 'entities.dart';
import 'physics.dart';
import 'player.dart';
import 'state.dart';
import 'world.dart';

class _EnemySize {
  const _EnemySize(this.w, this.h, this.hp);
  final double w, h;
  final int hp;
}

const _enemySize = <String, _EnemySize>{
  'thorn': _EnemySize(1.1, 1.2, 2),
  'beetle': _EnemySize(1.6, 0.95, 2),
  'frog': _EnemySize(1.5, 1.1, 3),
};

Enemy createEnemy(int id, String type, int x, int y, [int area = 0]) {
  final m = monsters[type];
  final baseHp = m?.hp ?? _enemySize[type]!.hp;
  final w = m?.w ?? _enemySize[type]!.w;
  final h = m?.h ?? _enemySize[type]!.h;
  final hp = jsRound(baseHp * (1 + area * 0.35));
  return Enemy(
    id: id,
    type: type,
    hp: hp,
    ai: m?.ai ?? type,
    ex: x + 0.5,
    ey: y + 1,
    ew: w,
    eh: h,
    hx: x + 0.5,
    hy: y + 1,
    cd: 1 + (x % 3) * 0.4,
    animT: (x * 0.37) % 1,
  );
}

Aabb enemyRect(Enemy e) => Aabb(e.x - e.w / 2, e.x + e.w / 2, e.y - e.h, e.y);

void updateEnemies(GameState g, double baseDt) {
  var dt = baseDt;
  final p = g.player;
  final alive = p.mode != 'dead';
  for (final e in g.enemies) {
    // Status effects from skins: slow halves its clock, burn ticks damage.
    e.slowT = math.max(0, e.slowT - dt);
    if (e.burnT > 0) {
      e.burnT -= dt;
      e.burnTick -= dt;
      if (e.burnTick <= 0) {
        e.burnTick = 0.6;
        e.hp -= 1;
        e.hurtT = 0.12;
        if (e.hp <= 0 && !e.dead) {
          e.dead = true;
          g.events.add(GameEvent('defeat', x: e.x, y: e.y - e.h / 2, enemy: true));
        }
      }
    }
    dt = e.slowT > 0 ? baseDt * 0.45 : baseDt;
    e.animT += dt;
    e.hurtT = math.max(0, e.hurtT - dt);
    e.cd = math.max(0, e.cd - dt);
    final dx = p.x - e.x;
    final dy = p.y - e.y;
    if (e.type == 'thorn') {
      _updateThorn(g, e, dt, dx, dy, alive);
    } else if (e.type == 'beetle') {
      _updateBeetle(g, e, dt);
    } else if (e.type == 'frog') {
      _updateFrog(g, e, dt, dx, dy, alive);
    } else {
      switch (e.ai) {
        case 'diver':
          _updateDiver(g, e, dt, dx, dy, alive);
        case 'flyer':
          _updateFlyer(g, e, dt, dx, dy, alive);
        case 'archer':
          _updateArcher(g, e, dt, dx, dy, alive);
        case 'hopper':
          _updateHopper(g, e, dt, dx, dy, alive);
        case 'dropper':
          _updateDropper(g, e, dt, dx, dy, alive);
        case 'walkerLob':
          _updateWalkerLob(g, e, dt, dx, dy, alive);
        case 'radial':
          _updateRadial(g, e, dt, dx, dy, alive);
      }
    }
    if (alive && p.invuln <= 0 && rectsOverlap(enemyRect(e), bodyRect(p))) {
      if (hurtPlayer(g, p, 1, e.x)) {
        final m = monsters[e.type];
        if (m != null && (m.freeze || e.ai == 'hopper')) p.freezeT = 1.4;
        if (e.ai == 'diver' || e.ai == 'flyer') {
          e.state = 'return';
          e.t = 0;
          e.cd = 1.2;
        }
      }
    }
  }
}

void _updateThorn(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  final inRange = alive && dx.abs() < 10 && dy.abs() < 2.4 && g.world.clearLine(e.x, e.y - 0.6, g.player.x, g.player.y - 0.8);
  if (e.state == 'idle') {
    if (inRange) e.face = dx > 0 ? 1 : -1;
    if (inRange && e.cd <= 0) {
      e.state = 'wind';
      e.t = 0;
      e.shots = 0;
    }
  } else if (e.state == 'wind') {
    e.t += dt;
    if (e.t >= 0.62) {
      e.state = 'fire';
      e.t = 0;
    }
  } else if (e.state == 'fire') {
    e.t += dt;
    if (e.shots < 3 && e.t >= e.shots * 0.24) {
      e.shots++;
      g.eproj.add(EProj(kind: 'thorn', x: e.x + e.face * 0.55, y: e.y - 0.62, vx: e.face * 8.5, vy: 0, r: 0.22));
      g.events.add(GameEvent('spit', x: e.x, y: e.y));
    }
    if (e.t > 0.9) {
      e.state = 'idle';
      e.cd = 2.3;
    }
  }
}

void _updateBeetle(GameState g, Enemy e, double dt) {
  final world = g.world;
  const speed = 1.5;
  if (e.face == 0) e.face = 1;
  final nx = e.x + e.face * speed * dt;
  final front = e.face > 0 ? nx + e.w / 2 : nx - e.w / 2;
  final fx = front.floor();
  final groundRow = jsRound(e.y);
  final wall = world.isSolidTile(fx, groundRow - 1);
  final t = world.tileAt(fx, groundRow);
  final floor = world.isSolidTile(fx, groundRow) || t == Tile.oneway;
  if (wall || !floor) {
    e.face = -e.face;
  } else {
    e.x = nx;
  }
}

void _updateFrog(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  final world = g.world;
  final p = g.player;
  final inRange = alive && dx.abs() < 11 && dy.abs() < 7;
  if (e.state == 'idle') {
    if (inRange) e.face = dx > 0 ? 1 : -1;
    if (inRange && e.cd <= 0) {
      e.state = 'wind';
      e.t = 0;
      // Mark where the mud will land: where the archer stands, leading a little.
      final tx = p.x + p.vx * 0.35;
      var ty = p.y;
      if (!p.onGround) {
        for (var r = p.y.floor(); r < p.y.floor() + 8; r++) {
          if (world.isSolidTile(tx.floor(), r) || world.tileAt(tx.floor(), r) == Tile.oneway) {
            ty = r.toDouble();
            break;
          }
        }
      }
      e.tx = tx;
      e.ty = ty;
    }
  } else if (e.state == 'wind') {
    e.t += dt;
    if (e.t >= 0.72) {
      final sx = e.x + e.face * 0.5;
      final sy = e.y - 1.0;
      const tt = 1.05;
      const gg = 20.0;
      g.eproj.add(EProj(
        kind: 'mud', x: sx, y: sy, vx: (e.tx - sx) / tt, vy: (e.ty - 0.3 - sy - 0.5 * gg * tt * tt) / tt, g: gg, r: 0.35,
      ));
      g.events.add(GameEvent('lob', x: e.x, y: e.y));
      e.state = 'recover';
      e.t = 0;
    }
  } else if (e.state == 'recover') {
    e.t += dt;
    if (e.t > 0.5) {
      e.state = 'idle';
      e.cd = 2.6;
    }
  }
}

/// Returns 'hit' | 'block' | null for an arrow touching this enemy.
String? arrowHitsEnemy(Enemy e, Arrow a) {
  if (a.x < e.x - e.w / 2 || a.x > e.x + e.w / 2 || a.y < e.y - e.h || a.y > e.y) return null;
  if (e.type == 'beetle') {
    final fromFront = a.vx * e.face < 0 && a.vy.abs() < a.vx.abs() * 1.1;
    if (fromFront) return 'block';
  }
  return 'hit';
}

// ---------------- Monsters of the upper areas

void _updateDiver(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  final d = hypot(dx, dy - 0.6);
  e.face = dx > 0 ? 1 : -1;
  if (e.state == 'idle') {
    e.x += (e.hx + math.sin(e.animT * 1.3) * 1.2 - e.x) * math.min(1, dt * 2);
    e.y += (e.hy + math.sin(e.animT * 2.4) * 0.4 - e.y) * math.min(1, dt * 2);
    if (alive && d < 7.5 && e.cd <= 0 && g.world.clearLine(e.x, e.y - 0.5, g.player.x, g.player.y - 0.8)) {
      e.state = 'wind';
      e.t = 0;
    }
  } else if (e.state == 'wind') {
    e.t += dt;
    if (e.t > 0.5) {
      final sp = e.type == 'bird' ? 14.0 : 11.0;
      var l = hypot(dx, dy - 0.7);
      if (l == 0) l = 1;
      e.vx = (dx / l) * sp;
      e.vy = ((dy - 0.7) / l) * sp;
      e.state = 'dive';
      e.t = 0;
    }
  } else if (e.state == 'dive') {
    e.t += dt;
    e.x += e.vx * dt;
    e.y += e.vy * dt;
    if (e.t > 0.7 || g.world.isSolidTile(e.x.floor(), (e.y - 0.4).floor())) {
      e.state = 'return';
      e.t = 0;
    }
  } else if (e.state == 'return') {
    final rx = e.hx - e.x;
    final ry = e.hy - e.y;
    final l = hypot(rx, ry);
    if (l < 0.3) {
      e.state = 'idle';
      e.cd = 1.4;
    } else {
      e.x += (rx / l) * 4.5 * dt;
      e.y += (ry / l) * 4.5 * dt;
    }
  }
}

double _sign(double v) => v > 0 ? 1 : (v < 0 ? -1 : 0);

void _updateFlyer(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  final m = monsters[e.type]!;
  final d = hypot(dx, dy);
  e.face = dx > 0 ? 1 : -1;
  if (e.state == 'return') {
    e.t += dt;
    e.x -= _sign(dx) * 2.5 * dt;
    e.y -= 1.5 * dt;
    if (e.t > 0.8) e.state = 'idle';
    return;
  }
  if (alive && d < 10) {
    var sp = m.speed;
    if (m.light && g.player.aiming) sp *= 1.8;
    final tx = dx / (d == 0 ? 1 : d);
    final ty = (dy - 0.8) / (d == 0 ? 1 : d);
    e.x += (tx * sp + math.cos(e.animT * 3) * 0.8) * dt;
    e.y += (ty * sp + math.sin(e.animT * 4) * 1.1) * dt;
    e.state = d < 2.2 ? 'attack' : 'chase';
    if (!m.freeze) {
      // Non-phasing flyers stay out of the walls.
      if (g.world.isSolidTile(e.x.floor(), (e.y - 0.4).floor())) {
        e.x -= tx * sp * dt * 1.5;
        e.y -= ty * sp * dt * 1.5;
      }
    }
  } else {
    e.state = 'idle';
    e.x += (e.hx - e.x) * math.min(1, dt * 0.8);
    e.y += (e.hy + math.sin(e.animT * 2) * 0.5 - e.y) * math.min(1, dt * 0.8);
  }
}

void _updateArcher(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  final inRange = alive && dx.abs() < 11 && dy.abs() < 6 && g.world.clearLine(e.x, e.y - 0.8, g.player.x, g.player.y - 0.8);
  if (inRange) e.face = dx > 0 ? 1 : -1;
  if (e.state == 'idle') {
    if (inRange && e.cd <= 0) {
      e.state = 'wind';
      e.t = 0;
    }
  } else if (e.state == 'wind') {
    e.t += dt;
    if (e.t > 0.6) {
      final sx = e.x + e.face * 0.5;
      final sy = e.y - 0.9;
      const tt = 0.85;
      const gg = 14.0;
      final tx = g.player.x;
      final ty = g.player.y - 0.7;
      g.eproj.add(EProj(
        kind: 'shot', sprite: 'twig_arrow', x: sx, y: sy, vx: (tx - sx) / tt, vy: (ty - sy - 0.5 * gg * tt * tt) / tt,
        g: gg, r: 0.25, orient: true,
      ));
      g.events.add(GameEvent('spit'));
      e.state = 'recover';
      e.t = 0;
    }
  } else if (e.state == 'recover') {
    e.t += dt;
    if (e.t > 0.45) {
      e.state = 'idle';
      e.cd = 2.0;
    }
  }
}

void _updateHopper(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  e.vy = math.min(20, e.vy + 40 * dt);
  final r = g.world.moveBody(e, e.vx * dt, e.vy * dt, g.platforms);
  final grounded = r.landed;
  if (r.landed) {
    e.vy = 0;
    e.vx *= 0.6;
  }
  if (r.hitX != 0) e.vx = -e.vx * 0.3;
  if (grounded) {
    if (e.state == 'hop') {
      e.state = 'idle';
      e.cd = 1.2;
    }
    if (alive && dx.abs() < 7 && dy.abs() < 4 && e.cd <= 0) {
      e.face = dx > 0 ? 1 : -1;
      e.vy = -11;
      e.vx = e.face * 4.2;
      e.state = 'hop';
      e.t = 0;
      e.y -= 0.02;
    }
  }
  if (e.y > g.rows + 2) e.dead = true;
}

void _updateDropper(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  e.face = dx > 0 ? 1 : -1;
  if (e.state == 'idle') {
    e.y += (e.hy + math.sin(e.animT * 1.5) * 0.15 - e.y) * math.min(1, dt * 3);
    if (alive && dx.abs() < 1.6 && dy > 0.5 && dy < 9 && e.cd <= 0) {
      e.state = 'drop';
      e.t = 0;
    } else if (alive && dx.abs() < 8 && dy.abs() < 6 && e.cd <= 0) {
      e.state = 'spit';
      e.t = 0;
    }
  } else if (e.state == 'drop') {
    e.t += dt;
    final target = math.min(g.player.y - 0.4, e.hy + 9);
    e.y += math.min(10 * dt, math.max(0, target - e.y));
    if (e.t > 1.1 || g.world.isSolidTile(e.x.floor(), e.y.floor())) {
      e.state = 'retract';
      e.t = 0;
    }
  } else if (e.state == 'retract') {
    e.y -= 3.2 * dt;
    if (e.y <= e.hy) {
      e.y = e.hy;
      e.state = 'idle';
      e.cd = 1.5;
    }
  } else if (e.state == 'spit') {
    e.t += dt;
    if (e.t > 0.5) {
      var l = hypot(dx, dy - 0.6);
      if (l == 0) l = 1;
      g.eproj.add(EProj(
        kind: 'shot', sprite: 'web_shot', x: e.x, y: e.y - 0.5, vx: (dx / l) * 7, vy: ((dy - 0.6) / l) * 7,
        r: 0.3, freeze: true, splash: true,
      ));
      g.events.add(GameEvent('spit'));
      e.state = 'idle';
      e.cd = 2.4;
    }
  }
}

void _updateWalkerLob(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  if (e.state == 'idle' || e.state == 'walk') {
    e.state = 'walk';
    _updateBeetle(g, e, dt * 0.9);
    if (alive && dx.abs() < 10 && dy.abs() < 6 && e.cd <= 0) {
      e.state = 'wind';
      e.t = 0;
      e.face = dx > 0 ? 1 : -1;
    }
  } else if (e.state == 'wind') {
    e.t += dt;
    if (e.t > 0.6) {
      final sx = e.x + e.face * 0.7;
      final sy = e.y - 0.6;
      const tt = 0.95;
      const gg = 18.0;
      final tx = g.player.x + g.player.vx * 0.3;
      final ty = g.player.y - 0.3;
      g.eproj.add(EProj(
        kind: 'shot', sprite: 'fireball', x: sx, y: sy, vx: (tx - sx) / tt, vy: (ty - sy - 0.5 * gg * tt * tt) / tt,
        g: gg, r: 0.32, splash: true,
      ));
      g.events.add(GameEvent('lob'));
      e.state = 'recover';
      e.t = 0;
    }
  } else if (e.state == 'recover') {
    e.t += dt;
    if (e.t > 0.4) {
      e.state = 'walk';
      e.cd = 2.6;
    }
  }
}

void _updateRadial(GameState g, Enemy e, double dt, double dx, double dy, bool alive) {
  e.y = e.hy + math.sin(e.animT * 1.6) * 0.3;
  if (e.state == 'idle') {
    if (alive && hypot(dx, dy) < 11 && e.cd <= 0) {
      e.state = 'wind';
      e.t = 0;
    }
  } else if (e.state == 'wind') {
    e.t += dt;
    if (e.t > 0.75) {
      const n = 8;
      for (var i = 0; i < n; i++) {
        final a = (i / n) * math.pi * 2 + (e.shots % 2) * (math.pi / n);
        g.eproj.add(EProj(kind: 'shot', sprite: 'star_bolt', x: e.x, y: e.y - 0.65, vx: math.cos(a) * 5.5, vy: math.sin(a) * 5.5, r: 0.25));
      }
      e.shots++;
      g.events.add(GameEvent('bossShoot'));
      e.state = 'idle';
      e.cd = 2.8;
    }
  }
}
