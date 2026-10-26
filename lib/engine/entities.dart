// Plain data holders for everything that lives in a run. Behaviour sits in the
// sibling system files (player, combat, enemies, objects, boss...).

/// Axis-aligned body: x is the horizontal centre, y the feet, all in tile units.
abstract class Body {
  double x = 0, y = 0, w = 0, h = 0;
}

/// A one-way surface the body can stand on. x1 is exclusive.
class Platform {
  Platform(this.x0, this.x1, this.top, this.id);
  final double x0, x1, top;
  final String? id;
}

class MoveResult {
  int hitX = 0;
  bool hitUp = false, landed = false;
  String? platformId;
}

class Aabb {
  const Aabb(this.x0, this.x1, this.y0, this.y1);
  final double x0, x1, y0, y1;
}

class GameEvent {
  GameEvent(
    this.type, {
    this.x = 0,
    this.y = 0,
    this.hard = false,
    this.full = false,
    this.quiet = false,
    this.enemy = false,
    this.generic = false,
    this.kind,
    this.id,
    this.name,
    this.phase = 0,
  });
  final String type;
  final double x, y;
  final bool hard, full, quiet, enemy, generic;
  final String? kind, id, name;
  final int phase;
}

class Ledge {
  Ledge({required this.sx, required this.sy, required this.fx, required this.fy});
  double t = 0;
  final double sx, sy, fx, fy;
}

class Player extends Body {
  Player(double px, double py, int maxHp, int maxEnergy)
      : hp = maxHp.toDouble(),
        energy = maxEnergy.toDouble(),
        safeX = px,
        safeY = py {
    x = px;
    y = py;
    w = 0.6;
    h = 1.45;
  }

  double vx = 0, vy = 0;
  int face = 1;
  String mode = 'normal';
  bool onGround = false;
  String? groundId;
  bool groundIsTileSolid = false;
  double coyote = 0, jumpBuffer = 0;
  bool jumpCut = false, jumping = false;
  double hp, energy;
  double invuln = 0, hurtT = 0, deadT = 0, dashT = 0, dashCD = 0;
  bool airDash = true;
  int airDashLeft = 1, airJumps = 0;
  double freezeT = 0;
  int wallSlide = 0;
  double wallLock = 0, dropT = 0, landT = 0;
  Ledge? ledge;
  int? climbX;
  double climbCooldown = 0, climbT = 0;
  bool aiming = false;
  double aimT = 0, aimX = 1, aimY = 0, releaseT = 0, focus = 1.6;
  String anim = 'idle';
  double animT = 0;
  double safeX, safeY, safeT = 0;
}

class Enemy extends Body {
  Enemy({
    required this.id,
    required this.type,
    required this.hp,
    required this.ai,
    required double ex,
    required double ey,
    required double ew,
    required double eh,
    required this.hx,
    required this.hy,
    required this.cd,
    required this.animT,
  }) : maxHp = hp {
    x = ex;
    y = ey;
    w = ew;
    h = eh;
  }
  final int id;
  final String type, ai;
  int hp;
  final int maxHp;
  int face = -1;
  String state = 'idle';
  double t = 0, cd;
  int shots = 0;
  double hurtT = 0, animT;
  double tx = 0, ty = 0;
  final double hx, hy;
  double vx = 0, vy = 0;
  double burnT = 0, slowT = 0, burnTick = 0;
  bool dead = false, summoned = false;
}

class Arrow {
  Arrow({
    required this.id,
    required this.kind,
    required this.sprite,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.g,
    required this.dmg,
    required this.full,
    required this.pierce,
    required this.burn,
    required this.slow,
    required this.chain,
    required this.homing,
    this.bounces = 0,
    this.rain = false,
  });
  final int id;
  final String kind, sprite;
  double x, y, vx, vy, g;
  int dmg;
  final bool full;
  String state = 'fly';
  double t = 0, spin = 0;
  int pierce;
  final bool burn, slow, chain, homing, rain;
  final List<Object> hits = [];
  int bounces;
  bool dead = false;
}

class Footing {
  Footing({required this.id, required this.x0, required this.x1, required this.top, required this.wallDir});
  final int id;
  final double x0, x1, top;
  final int wallDir;
  double t = 0, dying = 0;
  bool dead = false;
}

/// Enemy / boss projectile. [kind] is thorn, mud, seed, debris, shot or shock.
class EProj {
  EProj({
    required this.kind,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.g = 0,
    this.r = 0.25,
    this.sprite,
    this.sheet,
    this.freeze = false,
    this.splash = false,
    this.orient = false,
    this.spin = false,
    this.upright = false,
    this.life,
    this.dmg = 1,
  });
  final String kind;
  final String? sprite, sheet;
  double x, y, vx, vy, g, r, t = 0;
  final bool freeze, splash, orient, spin, upright;
  final double? life;
  final int dmg;
  bool dead = false;
}

class Fx {
  Fx(this.kind, this.x, this.y, {this.t = 0, required this.dur, this.scale = 1, this.flip = false});
  final String kind;
  final double x, y, dur, scale;
  final bool flip;
  double t;
}

class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color) : max = life;
  double x, y, vx, vy, life;
  final double max, size;
  final int color;
}

class Warning {
  Warning(this.x, this.t, this.dur, [this.sprite]);
  final int x;
  double t;
  final double dur;
  final String? sprite;
  bool done = false;
}

class Beam {
  Beam(this.x, this.t, this.warn, this.life);
  final double x, warn, life;
  double t;
  bool struck = false;
}

class Bolt {
  Bolt(this.x0, this.y0, this.x1, this.y1, this.dur);
  final double x0, y0, x1, y1, dur;
  double t = 0;
}

class AimTarget {
  AimTarget(this.id, this.x, this.y);
  /// An enemy id (int) or a string key such as "boss" / "node0".
  final Object id;
  final double x, y;
}

class Toast {
  Toast(this.text, this.dur);
  final String text;
  final double dur;
  double t = 0;
}

class Speech {
  Speech(this.text, this.x, this.y);
  final String text;
  final double x, y;
}

class Cam {
  Cam(this.x, this.y, {this.snap = true, this.zoom = 1});
  double x, y, zoom;
  bool snap;
}

// ---- Living world objects ----

class Leaf {
  Leaf(this.id, this.x0, this.x1, this.y);
  final int id, x0, x1, y;
  String state = 'open';
  double t = 0;
}

class Crumble {
  Crumble(this.id, this.x0, this.x1, this.y);
  final int id, x0, x1, y;
  String state = 'ok';
  double t = 0;
}

class BridgeRun {
  const BridgeRun(this.x0, this.x1, this.y);
  final int x0, x1, y;
}

class Mover {
  Mover({required this.id, required this.x0, required this.w, required this.y, required this.axis, required this.amp, required this.speed, required this.phase})
      : px = x0.toDouble(),
        py = y.toDouble();
  final int id, x0, w, y;
  final String axis;
  final double amp, speed, phase;
  double t = 0, px, py;
}

class Flower {
  Flower(this.id, this.x, this.y);
  final int id, x, y;
  String state = 'idle';
  double t = 0;
}

class Wind {
  Wind(this.id, this.x0, this.x1, this.y0, this.y1, this.t);
  final int id, x0, x1, y0, y1;
  bool on = true;
  double t;
}

class Stalactite {
  Stalactite(this.x, this.y);
  final int x, y;
  String state = 'hang';
  double t = 0;
}

class Checkpoint {
  Checkpoint(this.id, this.x, this.y, this.lit);
  final String id;
  final int x, y;
  bool lit;
  double animT = 0;
}

class Pickup {
  Pickup(this.id, this.kind, this.x, this.y);
  final String id, kind;
  final int x, y;
  bool taken = false;
  double t = 0;
}

class Crack {
  Crack(this.id, this.x, this.y0, this.y1, this.broken);
  final String id;
  final int x, y0, y1;
  bool broken;
}

class LiftStation {
  LiftStation(this.x, this.y);
  final int x, y;
  bool near = false;
}

class LiftRide {
  LiftRide(this.to);
  final LiftStation to;
  double t = 0;
  bool moved = false;
}

class Lift {
  Lift(this.bottom, this.top);
  final LiftStation bottom, top;
  LiftRide? ride;
}

class Bell {
  Bell(this.x, this.y);
  final int x, y;
  double animT = 0;
}

class Gate {
  Gate(this.x, this.y, this.active);
  final int x, y;
  bool active;
}

class Villager {
  Villager(this.x, this.y);
  final int x, y;
  bool near = false;
}

class Decor {
  const Decor(this.g, this.x, this.y);
  final String g;
  final int x, y;
}

/// Tiny player-input snapshot used by the simulation (touch, keyboard or mouse).
class InputState {
  double mx = 0, my = 0;
  bool jumpPressed = false, jumpHeld = false, dashPressed = false;
  bool bowDown = false, bowHeld = false, bowReleased = false;
  String aimSource = 'drag';
  double dragX = 0, dragY = 0, dragLen = 0, pointerX = 0, pointerY = 0, aimWX = 0, aimWY = 0;
  bool switchPressed = false, upPressed = false, mapPressed = false, skillPressed = false;

  void clearEdges() {
    jumpPressed = false;
    dashPressed = false;
    bowDown = false;
    bowReleased = false;
    switchPressed = false;
    upPressed = false;
    mapPressed = false;
    skillPressed = false;
  }
}
