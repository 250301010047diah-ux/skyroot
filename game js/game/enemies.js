// Thorn Guards (straight bursts from a nest), Shield Beetles (front plate blocks
// arrows), Cannon Frogs (lobbed mud with a ground marker).
import { isSolidTile, tileAt, TILE } from "./world.js";
import { hurtPlayer } from "./player.js";
import { rectsOverlap, bodyRect, clearLine, moveBody } from "./physics.js";
import { MONSTERS } from "./content.js";

export const ENEMY_SIZE = {
  thorn: { w: 1.1, h: 1.2, hp: 2 },
  beetle: { w: 1.6, h: 0.95, hp: 2 },
  frog: { w: 1.5, h: 1.1, hp: 3 },
};

export function createEnemy(id, type, x, y, area = 0) {
  const m = MONSTERS[type];
  const s = m || ENEMY_SIZE[type];
  const hp = Math.round(s.hp * (1 + area * 0.35));
  return {
    id, type, x: x + 0.5, y: y + 1, w: s.w, h: s.h, hp, maxHp: hp, face: -1,
    state: "idle", t: 0, cd: 1 + (x % 3) * 0.4, shots: 0, hurtT: 0, animT: (x * 0.37) % 1,
    tx: 0, ty: 0, hx: x + 0.5, hy: y + 1, vx: 0, vy: 0, burnT: 0, slowT: 0, burnTick: 0, ai: m ? m.ai : type,
  };
}

export function enemyRect(e) {
  return { x0: e.x - e.w / 2, x1: e.x + e.w / 2, y0: e.y - e.h, y1: e.y };
}

export function updateEnemies(g, baseDt) {
  let dt = baseDt;
  const p = g.player;
  const alive = p.mode !== "dead";
  for (const e of g.enemies) {
    // Status effects from skins: slow halves its clock, burn ticks damage.
    e.slowT = Math.max(0, e.slowT - dt);
    if (e.burnT > 0) {
      e.burnT -= dt;
      e.burnTick -= dt;
      if (e.burnTick <= 0) {
        e.burnTick = 0.6;
        e.hp -= 1;
        e.hurtT = 0.12;
        if (e.hp <= 0 && !e.dead) {
          e.dead = true;
          g.events.push({ type: "defeat", x: e.x, y: e.y - e.h / 2, enemy: true });
        }
      }
    }
    dt = e.slowT > 0 ? baseDt * 0.45 : baseDt;
    e.animT += dt;
    e.hurtT = Math.max(0, e.hurtT - dt);
    e.cd = Math.max(0, e.cd - dt);
    const dx = p.x - e.x;
    const dy = p.y - e.y;
    if (e.type === "thorn") updateThorn(g, e, dt, dx, dy, alive);
    else if (e.type === "beetle") updateBeetle(g, e, dt);
    else if (e.type === "frog") updateFrog(g, e, dt, dx, dy, alive);
    else if (e.ai === "diver") updateDiver(g, e, dt, dx, dy, alive);
    else if (e.ai === "flyer") updateFlyer(g, e, dt, dx, dy, alive);
    else if (e.ai === "archer") updateArcher(g, e, dt, dx, dy, alive);
    else if (e.ai === "hopper") updateHopper(g, e, dt, dx, dy, alive);
    else if (e.ai === "dropper") updateDropper(g, e, dt, dx, dy, alive);
    else if (e.ai === "walkerLob") updateWalkerLob(g, e, dt, dx, dy, alive);
    else if (e.ai === "radial") updateRadial(g, e, dt, dx, dy, alive);
    if (alive && p.invuln <= 0 && rectsOverlap(enemyRect(e), bodyRect(p))) {
      if (hurtPlayer(g, p, 1, e.x)) {
        const m = MONSTERS[e.type];
        if (m && (m.freeze || e.ai === "hopper")) p.freezeT = 1.4;
        if (e.ai === "diver" || e.ai === "flyer") {
          e.state = "return";
          e.t = 0;
          e.cd = 1.2;
        }
      }
    }
  }
}

function updateThorn(g, e, dt, dx, dy, alive) {
  const inRange = alive && Math.abs(dx) < 10 && Math.abs(dy) < 2.4 && clearLine(e.x, e.y - 0.6, g.player.x, g.player.y - 0.8);
  if (e.state === "idle") {
    if (inRange) e.face = dx > 0 ? 1 : -1;
    if (inRange && e.cd <= 0) {
      e.state = "wind";
      e.t = 0;
      e.shots = 0;
    }
  } else if (e.state === "wind") {
    e.t += dt;
    if (e.t >= 0.62) {
      e.state = "fire";
      e.t = 0;
    }
  } else if (e.state === "fire") {
    e.t += dt;
    if (e.shots < 3 && e.t >= e.shots * 0.24) {
      e.shots++;
      g.eproj.push({ kind: "thorn", x: e.x + e.face * 0.55, y: e.y - 0.62, vx: e.face * 8.5, vy: 0, g: 0, t: 0, r: 0.22 });
      g.events.push({ type: "spit", x: e.x, y: e.y });
    }
    if (e.t > 0.9) {
      e.state = "idle";
      e.cd = 2.3;
    }
  }
}

function updateBeetle(g, e, dt) {
  const speed = 1.5;
  if (e.face === 0) e.face = 1;
  const nx = e.x + e.face * speed * dt;
  const front = e.face > 0 ? nx + e.w / 2 : nx - e.w / 2;
  const fx = Math.floor(front);
  const groundRow = Math.round(e.y);
  const wall = isSolidTile(fx, groundRow - 1);
  const t = tileAt(fx, groundRow);
  const floor = isSolidTile(fx, groundRow) || t === TILE.ONEWAY;
  if (wall || !floor) e.face = -e.face;
  else e.x = nx;
}

function updateFrog(g, e, dt, dx, dy, alive) {
  const p = g.player;
  const inRange = alive && Math.abs(dx) < 11 && Math.abs(dy) < 7;
  if (e.state === "idle") {
    if (inRange) e.face = dx > 0 ? 1 : -1;
    if (inRange && e.cd <= 0) {
      e.state = "wind";
      e.t = 0;
      // Mark where the mud will land: where the archer stands, leading a little.
      let tx = p.x + p.vx * 0.35;
      let ty = p.y;
      if (!p.onGround) {
        for (let r = Math.floor(p.y); r < Math.floor(p.y) + 8; r++)
          if (isSolidTile(Math.floor(tx), r) || tileAt(Math.floor(tx), r) === TILE.ONEWAY) {
            ty = r;
            break;
          }
      }
      e.tx = tx;
      e.ty = ty;
    }
  } else if (e.state === "wind") {
    e.t += dt;
    if (e.t >= 0.72) {
      const sx = e.x + e.face * 0.5;
      const sy = e.y - 1.0;
      const T = 1.05;
      const G = 20;
      g.eproj.push({ kind: "mud", x: sx, y: sy, vx: (e.tx - sx) / T, vy: (e.ty - 0.3 - sy - 0.5 * G * T * T) / T, g: G, t: 0, r: 0.35 });
      g.events.push({ type: "lob", x: e.x, y: e.y });
      e.state = "recover";
      e.t = 0;
    }
  } else if (e.state === "recover") {
    e.t += dt;
    if (e.t > 0.5) {
      e.state = "idle";
      e.cd = 2.6;
    }
  }
}

// Returns "hit" | "block" | null for an arrow touching this enemy.
export function arrowHitsEnemy(e, a) {
  if (a.x < e.x - e.w / 2 || a.x > e.x + e.w / 2 || a.y < e.y - e.h || a.y > e.y) return null;
  if (e.type === "beetle") {
    const fromFront = a.vx * e.face < 0 && Math.abs(a.vy) < Math.abs(a.vx) * 1.1;
    if (fromFront) return "block";
  }
  return "hit";
}

// ---------------- Monsters of the upper areas

function updateDiver(g, e, dt, dx, dy, alive) {
  const d = Math.hypot(dx, dy - 0.6);
  e.face = dx > 0 ? 1 : -1;
  if (e.state === "idle") {
    e.x += (e.hx + Math.sin(e.animT * 1.3) * 1.2 - e.x) * Math.min(1, dt * 2);
    e.y += (e.hy + Math.sin(e.animT * 2.4) * 0.4 - e.y) * Math.min(1, dt * 2);
    if (alive && d < 7.5 && e.cd <= 0 && clearLine(e.x, e.y - 0.5, g.player.x, g.player.y - 0.8)) {
      e.state = "wind";
      e.t = 0;
    }
  } else if (e.state === "wind") {
    e.t += dt;
    if (e.t > 0.5) {
      const sp = e.type === "bird" ? 14 : 11;
      const l = Math.hypot(dx, dy - 0.7) || 1;
      e.vx = (dx / l) * sp;
      e.vy = ((dy - 0.7) / l) * sp;
      e.state = "dive";
      e.t = 0;
    }
  } else if (e.state === "dive") {
    e.t += dt;
    e.x += e.vx * dt;
    e.y += e.vy * dt;
    if (e.t > 0.7 || isSolidTile(Math.floor(e.x), Math.floor(e.y - 0.4))) {
      e.state = "return";
      e.t = 0;
    }
  } else if (e.state === "return") {
    const rx = e.hx - e.x;
    const ry = e.hy - e.y;
    const l = Math.hypot(rx, ry);
    if (l < 0.3) {
      e.state = "idle";
      e.cd = 1.4;
    } else {
      e.x += (rx / l) * 4.5 * dt;
      e.y += (ry / l) * 4.5 * dt;
    }
  }
}

function updateFlyer(g, e, dt, dx, dy, alive) {
  const m = MONSTERS[e.type];
  const d = Math.hypot(dx, dy);
  e.face = dx > 0 ? 1 : -1;
  if (e.state === "return") {
    e.t += dt;
    e.x -= Math.sign(dx) * 2.5 * dt;
    e.y -= 1.5 * dt;
    if (e.t > 0.8) e.state = "idle";
    return;
  }
  if (alive && d < 10) {
    let sp = m.speed;
    if (m.light && g.player.aiming) sp *= 1.8;
    const tx = dx / (d || 1);
    const ty = (dy - 0.8) / (d || 1);
    e.x += (tx * sp + Math.cos(e.animT * 3) * 0.8) * dt;
    e.y += (ty * sp + Math.sin(e.animT * 4) * 1.1) * dt;
    e.state = d < 2.2 ? "attack" : "chase";
    if (!m.freeze) {
      // Non-phasing flyers stay out of the walls.
      if (isSolidTile(Math.floor(e.x), Math.floor(e.y - 0.4))) {
        e.x -= tx * sp * dt * 1.5;
        e.y -= ty * sp * dt * 1.5;
      }
    }
  } else {
    e.state = "idle";
    e.x += (e.hx - e.x) * Math.min(1, dt * 0.8);
    e.y += (e.hy + Math.sin(e.animT * 2) * 0.5 - e.y) * Math.min(1, dt * 0.8);
  }
}

function updateArcher(g, e, dt, dx, dy, alive) {
  const inRange = alive && Math.abs(dx) < 11 && Math.abs(dy) < 6 && clearLine(e.x, e.y - 0.8, g.player.x, g.player.y - 0.8);
  if (inRange) e.face = dx > 0 ? 1 : -1;
  if (e.state === "idle") {
    if (inRange && e.cd <= 0) {
      e.state = "wind";
      e.t = 0;
    }
  } else if (e.state === "wind") {
    e.t += dt;
    if (e.t > 0.6) {
      const sx = e.x + e.face * 0.5;
      const sy = e.y - 0.9;
      const T = 0.85;
      const G = 14;
      const tx = g.player.x;
      const ty = g.player.y - 0.7;
      g.eproj.push({ kind: "shot", sprite: "twig_arrow", x: sx, y: sy, vx: (tx - sx) / T, vy: (ty - sy - 0.5 * G * T * T) / T, g: G, t: 0, r: 0.25, orient: true });
      g.events.push({ type: "spit" });
      e.state = "recover";
      e.t = 0;
    }
  } else if (e.state === "recover") {
    e.t += dt;
    if (e.t > 0.45) {
      e.state = "idle";
      e.cd = 2.0;
    }
  }
}

function updateHopper(g, e, dt, dx, dy, alive) {
  e.vy = Math.min(20, e.vy + 40 * dt);
  const r = moveBody(e, e.vx * dt, e.vy * dt, g.platforms);
  const grounded = r.landed;
  if (r.landed) {
    e.vy = 0;
    e.vx *= 0.6;
  }
  if (r.hitX) e.vx = -e.vx * 0.3;
  if (grounded) {
    if (e.state === "hop") {
      e.state = "idle";
      e.cd = 1.2;
    }
    if (alive && Math.abs(dx) < 7 && Math.abs(dy) < 4 && e.cd <= 0) {
      e.face = dx > 0 ? 1 : -1;
      e.vy = -11;
      e.vx = e.face * 4.2;
      e.state = "hop";
      e.t = 0;
      e.y -= 0.02;
    }
  }
  if (e.y > g.rows + 2) e.dead = true;
}

function updateDropper(g, e, dt, dx, dy, alive) {
  e.face = dx > 0 ? 1 : -1;
  if (e.state === "idle") {
    e.y += (e.hy + Math.sin(e.animT * 1.5) * 0.15 - e.y) * Math.min(1, dt * 3);
    if (alive && Math.abs(dx) < 1.6 && dy > 0.5 && dy < 9 && e.cd <= 0) {
      e.state = "drop";
      e.t = 0;
    } else if (alive && Math.abs(dx) < 8 && Math.abs(dy) < 6 && e.cd <= 0) {
      e.state = "spit";
      e.t = 0;
    }
  } else if (e.state === "drop") {
    e.t += dt;
    const target = Math.min(g.player.y - 0.4, e.hy + 9);
    e.y += Math.min(10 * dt, Math.max(0, target - e.y));
    if (e.t > 1.1 || isSolidTile(Math.floor(e.x), Math.floor(e.y))) {
      e.state = "retract";
      e.t = 0;
    }
  } else if (e.state === "retract") {
    e.y -= 3.2 * dt;
    if (e.y <= e.hy) {
      e.y = e.hy;
      e.state = "idle";
      e.cd = 1.5;
    }
  } else if (e.state === "spit") {
    e.t += dt;
    if (e.t > 0.5) {
      const l = Math.hypot(dx, dy - 0.6) || 1;
      g.eproj.push({ kind: "shot", sprite: "web_shot", x: e.x, y: e.y - 0.5, vx: (dx / l) * 7, vy: ((dy - 0.6) / l) * 7, g: 0, t: 0, r: 0.3, freeze: true, splash: true });
      g.events.push({ type: "spit" });
      e.state = "idle";
      e.cd = 2.4;
    }
  }
}

function updateWalkerLob(g, e, dt, dx, dy, alive) {
  if (e.state === "idle" || e.state === "walk") {
    e.state = "walk";
    updateBeetle(g, e, dt * 0.9);
    if (alive && Math.abs(dx) < 10 && Math.abs(dy) < 6 && e.cd <= 0) {
      e.state = "wind";
      e.t = 0;
      e.face = dx > 0 ? 1 : -1;
    }
  } else if (e.state === "wind") {
    e.t += dt;
    if (e.t > 0.6) {
      const sx = e.x + e.face * 0.7;
      const sy = e.y - 0.6;
      const T = 0.95;
      const G = 18;
      const tx = g.player.x + g.player.vx * 0.3;
      const ty = g.player.y - 0.3;
      g.eproj.push({ kind: "shot", sprite: "fireball", x: sx, y: sy, vx: (tx - sx) / T, vy: (ty - sy - 0.5 * G * T * T) / T, g: G, t: 0, r: 0.32, splash: true });
      g.events.push({ type: "lob" });
      e.state = "recover";
      e.t = 0;
    }
  } else if (e.state === "recover") {
    e.t += dt;
    if (e.t > 0.4) {
      e.state = "walk";
      e.cd = 2.6;
    }
  }
}

function updateRadial(g, e, dt, dx, dy, alive) {
  e.y = e.hy + Math.sin(e.animT * 1.6) * 0.3;
  if (e.state === "idle") {
    if (alive && Math.hypot(dx, dy) < 11 && e.cd <= 0) {
      e.state = "wind";
      e.t = 0;
    }
  } else if (e.state === "wind") {
    e.t += dt;
    if (e.t > 0.75) {
      const n = 8;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + (e.shots % 2) * (Math.PI / n);
        g.eproj.push({ kind: "shot", sprite: "star_bolt", x: e.x, y: e.y - 0.65, vx: Math.cos(a) * 5.5, vy: Math.sin(a) * 5.5, g: 0, t: 0, r: 0.25 });
      }
      e.shots++;
      g.events.push({ type: "bossShoot" });
      e.state = "idle";
      e.cd = 2.8;
    }
  }
}
