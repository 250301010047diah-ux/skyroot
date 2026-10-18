// Rusa Menara, the Tower Stag. Shoot its three antler nodes to bring its head
// down, then hit the glowing rune on its forehead. Two phases.
import { rectsOverlap, bodyRect } from "./physics.js";
import { hurtPlayer } from "./player.js";

// Sheet pixels -> tiles. The sheet draws the stag facing left.
export const STAG_SCALE = 7 / 337;
const NODE_OFFSETS = [
  [-109, -270],
  [-15, -276],
  [43, -276],
];
const WEAK_OFFSET = [-92, -62];
const FLOOR_Y = 12;

export function createBoss(x, y, defeated, maxHp) {
  return {
    x: x + 0.5, y: y + 1, hp: maxHp, maxHp, state: defeated ? "gone" : "sleep",
    t: 0, animT: 0, nodes: [true, true, true], nodeFlash: [0, 0, 0], hurtT: 0, next: "shoot", fade: 0,
  };
}

export function nodePos(b, i) {
  return { x: b.x + NODE_OFFSETS[i][0] * STAG_SCALE, y: b.y + NODE_OFFSETS[i][1] * STAG_SCALE };
}

export function weakPos(b) {
  return { x: b.x + WEAK_OFFSET[0] * STAG_SCALE, y: b.y + WEAK_OFFSET[1] * STAG_SCALE };
}

export function bossBodyRect(b) {
  return { x0: b.x - 1.7, x1: b.x + 1.7, y0: b.y - 3.4, y1: b.y };
}

export function updateBoss(g, dt) {
  const b = g.boss;
  if (!b || b.state === "gone") return;
  const p = g.player;
  b.animT += dt;
  b.hurtT = Math.max(0, b.hurtT - dt);
  for (let i = 0; i < 3; i++) b.nodeFlash[i] = Math.max(0, b.nodeFlash[i] - dt);
  const phase2 = b.hp <= Math.ceil(b.maxHp / 2);
  if (b.state === "sleep") {
    if (p.y < FLOOR_Y + 0.2 && p.mode !== "dead") {
      b.state = "idle";
      b.t = 0;
      g.events.push({ type: "bossStart" });
    }
    return;
  }
  if (b.state === "dying") {
    b.t += dt;
    b.fade = Math.min(1, b.t / 1.8);
    if (b.t > 2.0) {
      b.state = "gone";
      g.events.push({ type: "bossDefeated" });
    }
    return;
  }
  b.t += dt;
  if (b.state === "idle") {
    if (b.t > (phase2 ? 0.75 : 1.3)) {
      b.state = b.next;
      b.next = b.next === "shoot" ? "stomp" : "shoot";
      b.t = 0;
      b.animT = 0;
      b.fired = false;
    }
  } else if (b.state === "shoot") {
    if (!b.fired && b.t >= 0.75) {
      b.fired = true;
      const n = phase2 ? 5 : 3;
      const ox = b.x - 1.2;
      const oy = b.y - 5.8;
      for (let i = 0; i < n; i++) {
        const tx = Math.max(11.5, Math.min(27, p.x + (i - (n - 1) / 2) * 2.2));
        const T = 1.05 + i * 0.06;
        const G = 18;
        g.eproj.push({ kind: "seed", x: ox, y: oy, vx: (tx - ox) / T, vy: (FLOOR_Y - 0.2 - oy - 0.5 * G * T * T) / T, g: G, t: 0, r: 0.32 });
      }
      g.events.push({ type: "bossShoot" });
    }
    if (b.t > 1.35) toIdle(b);
  } else if (b.state === "stomp") {
    if (!b.fired && b.t >= 0.62) {
      b.fired = true;
      g.eproj.push({ kind: "shock", x: b.x - 1.8, y: FLOOR_Y - 0.4, vx: phase2 ? -11 : -9, vy: 0, g: 0, t: 0, r: 0.45, life: 3.2 });
      g.events.push({ type: "stomp" });
      if (phase2) {
        for (let i = 0; i < 4; i++) {
          const x = 11 + ((g.uid * 7 + i * 5) % 16);
          g.warnings.push({ x, t: 0, dur: 0.75 });
        }
      }
    }
    if (b.t > 1.3) toIdle(b);
  } else if (b.state === "stunned") {
    if (b.t > 4.2) {
      b.nodes = [true, true, true];
      toIdle(b);
    }
  }
  // Body contact hurts unless the stag is stunned.
  if (b.state !== "stunned" && p.mode !== "dead" && rectsOverlap(bossBodyRect(b), bodyRect(p))) hurtPlayer(g, p, 1, b.x);
}

function toIdle(b) {
  b.state = "idle";
  b.t = 0;
  b.animT = 0;
}

// Arrow vs boss: returns true when the arrow is consumed.
export function arrowHitsBoss(g, a) {
  const b = g.boss;
  if (!b || b.state === "gone" || b.state === "sleep" || b.state === "dying") return false;
  if (b.state === "stunned") {
    const w = weakPos(b);
    if (Math.hypot(a.x - w.x, a.y - w.y) < 0.75) {
      b.hp -= a.dmg;
      b.hurtT = 0.25;
      g.events.push({ type: "bossHurt", x: w.x, y: w.y });
      g.fx.push({ kind: "arrow_hit", x: a.x, y: a.y, t: 0, dur: 0.3, scale: 1.6 });
      if (b.hp <= 0) {
        b.state = "dying";
        b.t = 0;
        g.events.push({ type: "bossDying" });
      }
      return true;
    }
  } else {
    for (let i = 0; i < 3; i++) {
      if (!b.nodes[i]) continue;
      const n = nodePos(b, i);
      if (Math.hypot(a.x - n.x, a.y - n.y) < 0.62) {
        b.nodes[i] = false;
        b.nodeFlash[i] = 0.4;
        g.fx.push({ kind: "leaf_burst", x: n.x, y: n.y + 0.6, t: 0, dur: 0.5, scale: 0.8 });
        g.events.push({ type: "nodeBreak", x: n.x, y: n.y });
        if (!b.nodes.some(Boolean)) {
          b.state = "stunned";
          b.t = 0;
          b.animT = 0;
          g.events.push({ type: "bossStun" });
        }
        return true;
      }
    }
  }
  const r = bossBodyRect(b);
  if (a.x > r.x0 && a.x < r.x1 && a.y > r.y0 - 2.5 && a.y < r.y1) {
    g.fx.push({ kind: "arrow_hit", x: a.x, y: a.y, t: 0, dur: 0.3 });
    a.state = "drop";
    a.t = 0;
    a.vx = -a.vx * 0.2;
    a.vy = -4;
    g.events.push({ type: "block", x: a.x, y: a.y });
    return false;
  }
  return false;
}

export function updateWarnings(g, dt) {
  for (const w of g.warnings) {
    w.t += dt;
    if (w.t >= w.dur && !w.done) {
      w.done = true;
      g.eproj.push({ kind: "debris", sprite: w.sprite, x: w.x + 0.5, y: 1.5, vx: 0, vy: 6, g: 40, t: 0, r: 0.4 });
    }
  }
  g.warnings = g.warnings.filter((w) => !w.done || w.t < w.dur + 0.1);
}
