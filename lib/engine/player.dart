// The archer: movement, climbing, ledge grabs, wall jumps, dash, and the bow.

import 'dart:math' as math;

import 'entities.dart';
import 'physics.dart';
import 'state.dart';
import 'world.dart';

const gravityBase = 75.0;
const _maxFall = 22.0;
const _ledgeTime = 0.42;
const _dashTime = 0.22;

double _sign(double v) => v > 0 ? 1 : (v < 0 ? -1 : 0);

void _setAnim(Player p, String name) {
  if (p.anim != name) {
    p.anim = name;
    p.animT = 0;
  }
}

/// [tune] is assembled by the game each frame (run speed, jump velocity, gravity, skin).
void updatePlayer(GameState g, Player p, InputState inp, double dt, Tune tune) {
  final world = g.world;
  final gr = gravityBase * tune.gravity;
  final skin = tune.skin;
  p.freezeT = math.max(0, p.freezeT - dt);
  p.animT += dt;
  p.invuln = math.max(0, p.invuln - dt);
  p.dashCD = math.max(0, p.dashCD - dt);
  p.wallLock = math.max(0, p.wallLock - dt);
  p.climbCooldown = math.max(0, p.climbCooldown - dt);
  p.dropT = math.max(0, p.dropT - dt);
  p.landT = math.max(0, p.landT - dt);
  p.releaseT = math.max(0, p.releaseT - dt);
  if (inp.jumpPressed) {
    p.jumpBuffer = 0.13;
  } else {
    p.jumpBuffer = math.max(0, p.jumpBuffer - dt);
  }

  if (p.mode == 'dead' || p.mode == 'lift') return;
  final platforms = g.platforms;

  if (p.mode == 'hurt') {
    p.hurtT -= dt;
    p.vy = math.min(_maxFall, p.vy + gr * dt);
    p.vx *= math.pow(0.02, dt);
    final r = world.moveBody(p, p.vx * dt, p.vy * dt, platforms);
    if (r.landed) p.vy = 0;
    if (r.hitUp) p.vy = 0;
    if (p.hurtT <= 0) p.mode = 'normal';
    _setAnim(p, 'hurt');
    return;
  }

  if (p.mode == 'ledge') {
    final l = p.ledge!;
    l.t += dt;
    if (l.t >= _ledgeTime) {
      p.x = l.fx;
      p.y = l.fy;
      p.vx = 0;
      p.vy = 0;
      p.mode = 'normal';
      p.onGround = true;
      p.ledge = null;
      p.landT = 0.16;
      _setAnim(p, 'land');
      return;
    }
    _setAnim(p, 'ledge_climb');
    return;
  }

  final mx = inp.mx.abs() > 0.25 ? inp.mx : 0.0;
  final my = inp.my;

  // ---- Climbing vines
  if (p.mode == 'climb') {
    final cx = p.climbX ?? p.x.floor();
    p.x += (cx + 0.5 - p.x) * math.min(1, dt * 14);
    p.vx = 0;
    p.vy = my.abs() > 0.3 ? _sign(my) * 4.6 : 0;
    final midRow = (p.y - p.h * 0.55).floor();
    if (p.vy < 0 && !world.isVine(cx, (p.y - p.h - 0.05).floor()) && !world.isVine(cx, midRow - 1)) {
      // Top of the vine: hop off upward.
      p.mode = 'normal';
      p.vy = -17;
      p.onGround = false;
      p.jumping = false;
      p.climbCooldown = 0.3;
      _setAnim(p, 'jump');
      return;
    } else if (inp.jumpPressed) {
      p.mode = 'normal';
      p.vy = -17;
      p.vx = mx * 6;
      p.jumpBuffer = 0;
      p.climbCooldown = 0.3;
      p.onGround = false;
      p.jumping = true;
      p.jumpCut = false;
      _setAnim(p, 'jump');
      return;
    } else if (mx.abs() > 0.75 && my.abs() < 0.35) {
      p.mode = 'normal';
      p.vx = mx * 4;
      p.climbCooldown = 0.3;
      _setAnim(p, 'fall');
      return;
    } else {
      final r = world.moveBody(p, 0, p.vy * dt, platforms, true);
      if (r.landed && p.vy > 0) p.mode = 'normal';
      if (!world.isVine(cx, (p.y - p.h + 0.05).floor()) && !world.isVine(cx, midRow) && !world.isVine(cx, (p.y - 0.2).floor())) {
        p.mode = 'normal';
      }
    }
    p.airDash = true;
    p.airDashLeft = skin.airDashes;
    p.focus = 1.6 * skin.focus;
    if (p.vy != 0) p.climbT += dt;
    _setAnim(p, 'climb');
    return;
  }

  // ---- Dash
  if (p.mode == 'dash') {
    p.dashT -= dt;
    p.vy = 0;
    final r = world.moveBody(p, p.vx * dt, 0, platforms);
    if (r.hitX != 0 || p.dashT <= 0) {
      p.mode = 'normal';
      p.vx = p.face * 7.0;
    }
    _setAnim(p, 'dash');
    return;
  }

  // ---- Normal movement
  final under = p.onGround ? world.tileAt(p.x.floor(), jsRound(p.y)) : Tile.empty;
  final onSap = under == Tile.sap;
  final onIce = under == Tile.ice;
  final aimSlow = p.aiming && p.onGround ? 0.35 : 1.0;
  final slowMul = (onSap ? 0.5 : 1.0) * (p.freezeT > 0 ? 0.55 : 1.0);
  final target = mx * tune.runSpeed * aimSlow * slowMul;
  if (p.wallLock <= 0) {
    final accel = p.onGround ? (onIce ? 9.0 : 70.0) : 42.0;
    final dv = target - p.vx;
    p.vx += _sign(dv) * math.min(dv.abs(), accel * dt);
  }
  if (mx != 0 && !p.aiming) p.face = mx > 0 ? 1 : -1;

  // Grab a vine.
  final cx = p.x.floor();
  final vineX = p.climbCooldown <= 0 ? _reachableVine(world, p) : null;
  if (vineX != null) {
    if (my < -0.5 || (my > 0.5 && !p.onGround)) {
      p.mode = 'climb';
      p.climbX = vineX;
      p.onGround = false;
      p.vx = 0;
      p.vy = 0;
      p.aiming = false;
      _setAnim(p, 'climb');
      return;
    }
  }
  // Drop through a vine top / one-way branch.
  if (p.onGround && my > 0.6 && !p.groundIsTileSolid) {
    p.dropT = 0.22;
    p.onGround = false;
    p.y += 0.05;
    if (world.isVine(cx, (p.y + 0.3).floor())) {
      p.mode = 'climb';
      p.climbX = cx;
      return;
    }
  }

  // Jump
  if (p.jumpBuffer > 0 && (p.onGround || p.coyote > 0)) {
    p.vy = -tune.jumpV * (onSap ? 0.85 : 1);
    p.onGround = false;
    p.coyote = 0;
    p.jumpBuffer = 0;
    p.jumping = true;
    p.jumpCut = false;
    g.events.add(GameEvent('jump', x: p.x, y: p.y));
  } else if (p.jumpBuffer > 0 && p.wallSlide != 0) {
    p.vy = -19;
    p.vx = -p.wallSlide * 6.5;
    p.face = -p.wallSlide;
    p.wallLock = 0.13;
    p.jumpBuffer = 0;
    p.jumping = true;
    p.jumpCut = false;
    p.wallSlide = 0;
    g.events.add(GameEvent('walljump', x: p.x, y: p.y));
  } else if (p.jumpBuffer > 0 && !p.onGround && p.airJumps > 0) {
    p.vy = -tune.jumpV * 0.92;
    p.airJumps--;
    p.jumpBuffer = 0;
    p.jumping = true;
    p.jumpCut = false;
    g.events.add(GameEvent('doublejump', x: p.x, y: p.y));
  }
  if (p.jumping && !inp.jumpHeld && p.vy < -4 && !p.jumpCut) {
    p.vy *= 0.45;
    p.jumpCut = true;
  }

  // Dash
  if (inp.dashPressed && g.progress.dash && p.dashCD <= 0 && (p.onGround || p.airDashLeft > 0)) {
    if (mx != 0) p.face = mx > 0 ? 1 : -1;
    p.mode = 'dash';
    p.dashT = _dashTime;
    p.dashCD = 0.42;
    p.vx = p.face * 19.0;
    p.vy = 0;
    if (!p.onGround) p.airDashLeft--;
    p.aiming = false;
    g.events.add(GameEvent('dash', x: p.x, y: p.y));
    return;
  }

  // Gravity, wall slide
  p.vy = math.min(_maxFall, p.vy + gr * dt);
  p.wallSlide = 0;
  if (!p.onGround && p.vy > 0 && mx != 0) {
    final dir = mx > 0 ? 1 : -1;
    final wx = (dir > 0 ? p.x + p.w / 2 + 0.06 : p.x - p.w / 2 - 0.06).floor();
    final r0 = (p.y - p.h + 0.2).floor();
    final r1 = (p.y - 0.2).floor();
    var moss = false;
    for (var r = r0; r <= r1; r++) {
      if (world.tileAt(wx, r) == Tile.moss) moss = true;
    }
    if (moss) {
      p.wallSlide = dir;
      p.vy = math.min(p.vy, 3.2);
      p.face = dir;
    }
  }

  final wasGround = p.onGround;
  final prevVy = p.vy;
  final res = world.moveBody(p, p.vx * dt, p.vy * dt, platforms, p.dropT > 0);
  if (res.hitX != 0) p.vx = 0;
  if (res.hitUp) p.vy = math.max(p.vy, 0);
  if (res.landed) {
    if (prevVy > 15) {
      p.landT = 0.16;
      g.events.add(GameEvent('land', x: p.x, y: p.y, hard: true));
    } else if (!wasGround && prevVy > 4) {
      g.events.add(GameEvent('land', x: p.x, y: p.y));
    }
    p.vy = 0;
  }
  final ground = p.vy >= 0 ? world.groundUnder(p, platforms) : null;
  p.onGround = ground != null && p.dropT <= 0 ? true : ground != null && res.landed;
  if (ground != null && p.dropT > 0 && !res.landed) p.onGround = false;
  p.groundId = ground?.id;
  p.groundIsTileSolid = ground != null && ground.tile && world.isSolidTile(p.x.floor(), jsRound(p.y));
  if (p.onGround) {
    p.coyote = 0.1;
    p.airDash = true;
    p.airDashLeft = skin.airDashes;
    p.airJumps = skin.doubleJump ? 1 : 0;
    p.jumping = false;
    p.focus = math.min(1.6 * skin.focus, p.focus + dt * 3);
  } else {
    p.coyote = math.max(0, p.coyote - dt);
  }

  // Ledge grab: automatic when a jump nearly makes it.
  if (!p.onGround && p.vy > -6 && p.wallLock <= 0) _tryLedge(g, p, mx);

  // Remember safe ground for hazard respawns.
  p.safeT -= dt;
  if (p.onGround && p.groundId == null && p.safeT <= 0 && !world.overlapsTile(p, Tile.spike, w: 2.2, h: 1.6)) {
    p.safeX = p.x;
    p.safeY = p.y;
    p.safeT = 0.25;
  }

  // Animation choice
  if (p.aiming) {
    _setAnim(p, 'aim');
  } else if (p.releaseT > 0) {
    _setAnim(p, 'release');
  } else if (p.wallSlide != 0) {
    _setAnim(p, 'wall_slide');
  } else if (!p.onGround) {
    _setAnim(p, p.vy < -2 ? 'jump' : 'fall');
  } else if (p.landT > 0) {
    _setAnim(p, 'land');
  } else if (p.vx.abs() > 0.6) {
    _setAnim(p, 'run');
  } else {
    _setAnim(p, 'idle');
  }
}

/// Reach a visible vine with the head/body, including its hanging lower tip.
/// The small horizontal tolerance matches the art without grabbing through walls.
int? _reachableVine(World world, Player p) {
  final rows = [(p.y - p.h + 0.05).floor(), (p.y - p.h * 0.55).floor(), (p.y - 0.3).floor()];
  final center = p.x.floor();
  for (final col in [center, center - 1, center + 1]) {
    if ((p.x - (col + 0.5)).abs() > 0.7) continue;
    if (rows.any((row) => world.isVine(col, row)) && !world.overlapsSolid(col + 0.5, p.y, p.w, p.h)) return col;
  }
  return null;
}

void _tryLedge(GameState g, Player p, double mx) {
  final world = g.world;
  final dir = mx != 0 ? (mx > 0 ? 1 : -1) : 0;
  if (dir == 0) return;
  final col = (dir > 0 ? p.x + p.w / 2 + 0.12 : p.x - p.w / 2 - 0.12).floor();
  final top = p.y - p.h;
  final r = jsRound(top + 0.15);
  if ((top - r).abs() > 0.5) return;
  if (!world.isSolidTile(col, r) || world.isSolidTile(col, r - 1) || world.isSolidTile(col, r - 2)) return;
  final fx = dir > 0 ? col + 0.42 : col + 0.58;
  final fy = r.toDouble();
  if (world.overlapsSolid(fx, fy, p.w, p.h)) return;
  // Column the player occupies must be open above the ledge too.
  if (world.isSolidTile(p.x.floor(), r - 1)) return;
  p.mode = 'ledge';
  p.face = dir;
  p.vx = 0;
  p.vy = 0;
  p.aiming = false;
  p.ledge = Ledge(
    sx: dir > 0 ? col - p.w / 2 - 0.02 : col + 1 + p.w / 2 + 0.02,
    sy: r + p.h - 0.1,
    fx: fx,
    fy: fy,
  );
  p.x = p.ledge!.sx;
  p.y = p.ledge!.sy;
  g.events.add(GameEvent('ledge', x: p.x, y: p.y));
}

class LedgePos {
  const LedgePos(this.x, this.y, this.e);
  final double x, y, e;
}

LedgePos ledgeDrawPos(Player p) {
  final l = p.ledge;
  if (l == null) return LedgePos(p.x, p.y, 1);
  final k = math.min(1.0, l.t / _ledgeTime);
  final e = k * k * (3 - 2 * k);
  final yk = math.min(1.0, k * 1.35);
  return LedgePos(
    l.sx + (l.fx - l.sx) * math.max(0, (k - 0.45) / 0.55),
    l.sy + (l.fy - l.sy) * (yk * yk * (3 - 2 * yk)),
    e,
  );
}

/// Returns true when the hit landed (not blocked by invulnerability).
bool hurtPlayer(GameState g, Player p, int dmg, [double? fromX]) {
  if (p.invuln > 0 || p.mode == 'dead' || p.mode == 'lift') return false;
  p.hp -= dmg;
  p.invuln = 1.2;
  p.aiming = false;
  g.events.add(GameEvent('hurt', x: p.x, y: p.y));
  if (p.hp <= 0) {
    p.hp = 0;
    p.mode = 'dead';
    p.deadT = 0;
    p.anim = 'defeat';
    p.animT = 0;
    p.vx = 0;
    p.vy = 0;
    return true;
  }
  p.ledge = null;
  p.mode = 'hurt';
  _setAnim(p, 'hurt');
  p.hurtT = 0.32;
  final dir = fromX == null ? -p.face : (p.x >= fromX ? 1 : -1);
  p.vx = dir * 7.0;
  p.vy = -9;
  return true;
}
