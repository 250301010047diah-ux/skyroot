// Bosses of the ten upper areas, driven by their attack lists in content.js.
// The arena is the same in every area: floor at row 12, walls at columns 11 and 33.
import { BOSSES } from "./content.js";
import { hurtPlayer } from "./player.js";
import { rectsOverlap, bodyRect } from "./physics.js";

const FLOOR = 12;
const LEFT = 11.5;
const RIGHT = 32.5;

export function createAreaBoss(area, x, y, defeated) {
  const cfg = BOSSES[area];
  return {
    generic: true, area, x: x + 0.5, y: cfg.fly ? 7.5 : y + 1, homeX: x + 0.5, hp: cfg.hp, maxHp: cfg.hp,
    state: defeated ? "gone" : "sleep", t: 0, animT: 0, hurtT: 0, fade: 0, face: -1, next: 0,
    vx: 0, vy: 0, tired: 0, phase: 1, fired: 0,
  };
}

export function bossRect(b) {
  const cfg = BOSSES[b.area];
  const h = cfg.height * 0.78;
  const w = cfg.height * 0.55;
  return { x0: b.x - w / 2, x1: b.x + w / 2, y0: b.y - h, y1: b.y };
}

function attacksFor(b) {
  const cfg = BOSSES[b.area];
  let list = cfg.attacks.slice();
  if (b.phase >= 2) list = list.concat(cfg.p2 || []);
  if (b.phase >= 3) list = list.concat(cfg.p3 || []);
  return list;
}

export function updateAreaBoss(g, dt) {
  const b = g.boss;
  if (!b || !b.generic || b.state === "gone") return;
  const cfg = BOSSES[b.area];
  const p = g.player;
  b.animT += dt;
  b.hurtT = Math.max(0, b.hurtT - dt);
  b.tired = Math.max(0, b.tired - dt);
  if (b.state === "sleep") {
    if (p.y < FLOOR + 0.2 && p.mode !== "dead") {
      b.state = "idle";
      b.t = 0;
      g.events.push({ type: "bossStart", name: cfg.name });
    }
    return;
  }
  if (b.state === "dying") {
    b.t += dt;
    b.fade = Math.min(1, b.t / 1.6);
    if (b.t > 1.8) {
      b.state = "gone";
      g.events.push({ type: "bossDefeated", generic: true });
    }
    return;
  }
  // Phases
  const ratio = b.hp / b.maxHp;
  const newPhase = cfg.p3 && ratio <= 0.3 ? 3 : ratio <= 0.55 ? 2 : 1;
  if (newPhase > b.phase) {
    b.phase = newPhase;
    b.hurtT = 0.6;
    g.events.push({ type: "bossPhase", phase: newPhase });
  }
  const fast = b.phase >= 2 ? 0.7 : 1;
  b.face = p.x < b.x ? -1 : 1;
  b.t += dt;

  // Flyers drift around the upper arena between attacks.
  if (cfg.fly && (b.state === "idle" || b.state === "spray" || b.state === "ring" || b.state === "beam" || b.state === "summon")) {
    const tx = 22 + Math.sin(b.animT * 0.5) * 7;
    const ty = 7.2 + Math.sin(b.animT * 1.1) * 1.2;
    b.x += (tx - b.x) * Math.min(1, dt * 0.9);
    b.y += (ty - b.y) * Math.min(1, dt * 1.2);
  }

  if (b.state === "idle") {
    if (!cfg.fly) b.x += (b.homeX - b.x) * Math.min(1, dt * 1.5);
    if (b.t > 1.2 * fast) {
      const list = attacksFor(b);
      b.state = list[b.next % list.length];
      b.next++;
      b.t = 0;
      b.animT = 0;
      b.fired = 0;
      if (b.state === "charge" && cfg.fly) b.state = "dive";
      if ((b.state === "shock" || b.state === "charge") && cfg.fly) b.state = "spray";
    }
  } else if (b.state === "spray") {
    if (b.t > 0.6 && b.fired === 0) {
      b.fired = 1;
      const n = b.phase >= 2 ? 5 : 3;
      const ox = b.x + b.face * 1.2;
      const oy = b.y - cfg.height * 0.65;
      for (let i = 0; i < n; i++) {
        const tx = Math.max(LEFT, Math.min(RIGHT, p.x + (i - (n - 1) / 2) * 2));
        const T = 1.0 + i * 0.05;
        const G = 18;
        g.eproj.push({ kind: "shot", sprite: cfg.shot, x: ox, y: oy, vx: (tx - ox) / T, vy: (FLOOR - 0.3 - oy - 0.5 * G * T * T) / T, g: G, t: 0, r: 0.35, splash: true, spin: true });
      }
      g.events.push({ type: "bossShoot" });
    }
    if (b.t > 1.2) toIdle(b);
  } else if (b.state === "ring") {
    if (b.t > 0.7 && b.fired < (b.phase >= 2 ? 2 : 1) && b.t > 0.7 + b.fired * 0.45) {
      const n = b.phase >= 2 ? 14 : 10;
      const off = b.fired * (Math.PI / n);
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + off;
        g.eproj.push({ kind: "shot", sprite: cfg.shot, x: b.x, y: b.y - cfg.height * 0.5, vx: Math.cos(a) * 5.5, vy: Math.sin(a) * 5.5, g: 0, t: 0, r: 0.3, spin: true });
      }
      b.fired++;
      g.events.push({ type: "bossShoot" });
    }
    if (b.t > 1.7) toIdle(b);
  } else if (b.state === "shock") {
    if (b.t > 0.65 && !b.fired) {
      b.fired = 1;
      const sp = b.phase >= 2 ? 11 : 9;
      g.eproj.push({ kind: "shock", x: b.x - 1.5, y: FLOOR - 0.4, vx: -sp, vy: 0, g: 0, t: 0, r: 0.45, life: 2.8 });
      g.eproj.push({ kind: "shock", x: b.x + 1.5, y: FLOOR - 0.4, vx: sp, vy: 0, g: 0, t: 0, r: 0.45, life: 2.8 });
      g.events.push({ type: "stomp" });
    }
    if (b.t > 1.25) toIdle(b);
  } else if (b.state === "rain") {
    if (b.t > 0.4 && !b.fired) {
      b.fired = 1;
      const n = b.phase >= 2 ? 7 : 5;
      for (let i = 0; i < n; i++) {
        const x = Math.round(LEFT + 1 + ((g.uid * 3 + i * 5.3) % (RIGHT - LEFT - 2)));
        g.warnings.push({ x, t: -i * 0.08, dur: 0.8, sprite: cfg.shot });
      }
      g.warnings.push({ x: Math.floor(p.x), t: 0, dur: 0.8, sprite: cfg.shot });
    }
    if (b.t > 1.4) toIdle(b);
  } else if (b.state === "charge") {
    if (b.t < 0.6) {
      b.vx = 0;
    } else {
      if (!b.vx) b.vx = (p.x < b.x ? -1 : 1) * (b.phase >= 2 ? 16 : 13);
      b.x += b.vx * dt;
      if (b.x < LEFT + 1.8 || b.x > RIGHT - 1.8) {
        b.x = Math.max(LEFT + 1.8, Math.min(RIGHT - 1.8, b.x));
        b.vx = 0;
        b.tired = 1.3;
        g.events.push({ type: "stomp" });
        b.state = "tired";
        b.t = 0;
      }
    }
  } else if (b.state === "tired") {
    if (b.t > 1.3) toIdle(b);
  } else if (b.state === "dive") {
    if (b.t < 0.5) {
      b.y -= dt * 2;
    } else if (!b.fired) {
      b.fired = 1;
      const l = Math.hypot(p.x - b.x, p.y - 1 - b.y) || 1;
      b.vx = ((p.x - b.x) / l) * 15;
      b.vy = ((p.y - 1 - b.y) / l) * 15;
    } else {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.y > FLOOR - 0.2 || b.x < LEFT || b.x > RIGHT || b.t > 1.6) {
        b.y = Math.min(b.y, FLOOR - 0.2);
        b.x = Math.max(LEFT, Math.min(RIGHT, b.x));
        b.tired = 0.9;
        b.state = "tired";
        b.t = 0;
      }
    }
  } else if (b.state === "beam") {
    if (!b.fired) {
      b.fired = 1;
      const n = b.phase >= 2 ? 5 : 3;
      for (let i = 0; i < n; i++) {
        const x = Math.max(LEFT, Math.min(RIGHT, p.x + (i - (n - 1) / 2) * 3.2));
        g.beams.push({ x, t: -i * 0.12, warn: 0.85, life: 0.35 });
      }
    }
    if (b.t > 1.6) toIdle(b);
  } else if (b.state === "summon") {
    if (b.t > 0.7 && !b.fired) {
      b.fired = 1;
      const alive = g.enemies.filter((e) => e.summoned).length;
      if (alive < 4) g.events.push({ type: "summon", x: b.x, y: b.y });
    }
    if (b.t > 1.2) toIdle(b);
  }

  if (p.mode !== "dead" && b.state !== "tired" && rectsOverlap(bossRect(b), bodyRect(p))) hurtPlayer(g, p, 1, b.x);
}

function toIdle(b) {
  b.state = "idle";
  b.t = 0;
  b.animT = 0;
  b.vx = 0;
}

// Arrow vs area boss: true when consumed.
export function arrowHitsAreaBoss(g, a) {
  const b = g.boss;
  if (!b || !b.generic || b.state === "gone" || b.state === "sleep" || b.state === "dying") return false;
  const r = bossRect(b);
  if (a.x < r.x0 || a.x > r.x1 || a.y < r.y0 || a.y > r.y1) return false;
  damageAreaBoss(g, a.dmg * (b.tired > 0 ? 1.5 : 1));
  g.fx.push({ kind: "arrow_hit", x: a.x, y: a.y, t: 0, dur: 0.3, scale: 1.2 });
  return true;
}

export function damageAreaBoss(g, dmg) {
  const b = g.boss;
  if (!b || !b.generic || b.state === "gone" || b.state === "sleep" || b.state === "dying") return;
  b.hp -= dmg;
  b.hurtT = Math.max(b.hurtT, 0.18);
  g.events.push({ type: "bossHurt", quiet: true });
  if (b.hp <= 0) {
    b.hp = 0;
    b.state = "dying";
    b.t = 0;
    g.events.push({ type: "bossDying" });
  }
}

export function updateBeams(g, dt) {
  const p = g.player;
  for (const bm of g.beams) {
    bm.t += dt;
    if (bm.t >= bm.warn && !bm.struck) {
      bm.struck = true;
      g.events.push({ type: "thunder" });
      if (Math.abs(p.x - bm.x) < 0.8 && p.mode !== "dead") hurtPlayer(g, p, 1, bm.x);
    }
  }
  g.beams = g.beams.filter((bm) => bm.t < bm.warn + bm.life);
}
