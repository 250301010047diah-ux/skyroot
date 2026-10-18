// Living platforms and world objects: folding leaves, crumbling slabs, launch
// flowers, wind gusts, shrines, pickups, cracked walls, lift, rope and bell.
import { rectsOverlap, bodyRect } from "./physics.js";
import { setCrackSolid } from "./world.js";

const LEAF = { trem: 0.55, fold: 0.25, closed: 1.6, open: 0.3 };
const CRUMBLE = { shake: 0.5, fall: 0.35, gone: 2.6, back: 0.4 };

// One-way surfaces the player can stand on this frame.
export function collectPlatforms(g) {
  const out = [];
  for (const l of g.leaves) if (l.state === "open" || l.state === "trem") out.push({ x0: l.x0, x1: l.x1 + 1, top: l.y, id: "leaf:" + l.id });
  for (const c of g.crumbles) if (c.state === "ok" || c.state === "shake") out.push({ x0: c.x0, x1: c.x1 + 1, top: c.y, id: "crumble:" + c.id });
  for (const f of g.footings) if (f.t > 0.12) out.push({ x0: f.x0, x1: f.x1, top: f.top, id: "foot:" + f.id });
  if (g.areaIndex === 0 && g.progress.areas[0].boss) for (const n of g.bridge) out.push({ x0: n.x0, x1: n.x1 + 1, top: n.y, id: "bridge" });
  for (const m of g.movers) out.push({ x0: m.px, x1: m.px + m.w, top: m.py, id: "mover:" + m.id });
  return out;
}

// Moving platforms carry whoever stands on them; run before the player moves.
export function updateMovers(g, dt) {
  const p = g.player;
  for (const m of g.movers) {
    m.t += dt;
    const off = Math.sin(m.t * m.speed + m.phase) * m.amp;
    const nx = m.axis === "x" ? m.x0 + off : m.x0;
    const ny = m.axis === "y" ? m.y + off : m.y;
    const dx = nx - m.px;
    m.px = nx;
    m.py = ny;
    if (p.onGround && p.groundId === "mover:" + m.id && p.mode === "normal") {
      p.x += dx;
      p.y = ny;
    }
  }
}

export function updateHazards(g, dt) {
  const p = g.player;
  // Stalactites shake, then drop on whoever walks beneath.
  for (const v of g.stalactites) {
    v.t += dt;
    if (v.state === "hang" && Math.abs(p.x - (v.x + 0.5)) < 1.1 && p.y > v.y && p.y - v.y < 9) {
      v.state = "shake";
      v.t = 0;
    } else if (v.state === "shake" && v.t > 0.45) {
      v.state = "gone";
      v.t = 0;
      g.eproj.push({ kind: "shot", sheet: "AREA_PROPS", sprite: "stalactite", x: v.x + 0.5, y: v.y + 0.6, vx: 0, vy: 2, g: 38, t: 0, r: 0.35, splash: true, upright: true });
    } else if (v.state === "gone" && v.t > 3.5) {
      v.state = "hang";
      v.t = 0;
    }
  }
  // Gate to the next area.
  const gt = g.gate;
  // gateHold stays set after "Jelajah lagi" until the archer steps out of the gate,
  // so standing in it doesn't reopen the ending panel every frame.
  const inGate = !!gt && Math.abs(p.x - (gt.x + 0.5)) < 0.9 && Math.abs(p.y - (gt.y + 1)) < 1.5;
  if (!inGate) g.gateHold = false;
  if (gt && gt.active && p.mode === "normal" && inGate && !g.gateHold) g.events.push({ type: "gate" });
}

export function updateObjects(g, dt) {
  const p = g.player;
  const standing = p.onGround ? p.groundId : null;

  for (const l of g.leaves) {
    l.t += dt;
    const on = standing === "leaf:" + l.id;
    if (l.state === "open" && on) set(l, "trem");
    else if (l.state === "trem" && l.t >= LEAF.trem) {
      set(l, "fold");
      g.events.push({ type: "leaf", x: (l.x0 + l.x1) / 2, y: l.y });
    } else if (l.state === "fold" && l.t >= LEAF.fold) set(l, "closed");
    else if (l.state === "closed" && l.t >= LEAF.closed) set(l, "opening");
    else if (l.state === "opening" && l.t >= LEAF.open) set(l, "open");
  }

  for (const c of g.crumbles) {
    c.t += dt;
    const on = standing === "crumble:" + c.id;
    if (c.state === "ok" && on) {
      set(c, "shake");
      g.events.push({ type: "crack", x: (c.x0 + c.x1) / 2 + 0.5, y: c.y, quiet: true });
    } else if (c.state === "shake" && c.t >= CRUMBLE.shake) {
      set(c, "fall");
      g.events.push({ type: "crumble", x: (c.x0 + c.x1) / 2 + 0.5, y: c.y });
    } else if (c.state === "fall" && c.t >= CRUMBLE.fall) set(c, "gone");
    else if (c.state === "gone" && c.t >= CRUMBLE.gone) set(c, "back");
    else if (c.state === "back" && c.t >= CRUMBLE.back) set(c, "ok");
  }

  for (const f of g.flowers) {
    f.t += dt;
    const near = p.onGround && Math.abs(p.x - (f.x + 0.5)) < 0.65 && Math.abs(p.y - (f.y + 1)) < 0.1;
    if (f.state === "idle" && near) set(f, "charge");
    else if (f.state === "charge" && f.t >= 0.45) {
      set(f, "launch");
      if (Math.abs(p.x - (f.x + 0.5)) < 0.9 && Math.abs(p.y - (f.y + 1)) < 0.6 && p.mode === "normal") {
        p.vy = -34;
        p.onGround = false;
        p.jumping = false;
        p.y -= 0.05;
        g.events.push({ type: "launch", x: f.x + 0.5, y: f.y + 1 });
      }
    } else if (f.state === "launch" && f.t >= 0.9) set(f, "idle");
  }

  const windMul = g.tune.windStrength;
  for (const w of g.winds) {
    w.t += dt;
    const cycle = w.on ? 2.7 : 1.4;
    if (w.t >= cycle) {
      w.on = !w.on;
      w.t = 0;
    }
    if (!w.on || p.mode !== "normal") continue;
    const r = { x0: w.x0, x1: w.x1 + 1, y0: w.y0, y1: w.y1 + 1 };
    if (rectsOverlap(r, bodyRect(p))) {
      p.vy -= 118 * windMul * dt;
      if (p.vy < -9 * windMul) p.vy = -9 * windMul;
      p.onGround = false;
      p.airDashLeft = Math.max(p.airDashLeft || 0, 1);
      p.focus = Math.min(1.6, p.focus + dt);
    }
  }

  for (const k of g.checkpoints) {
    k.animT += dt;
    const near = Math.abs(p.x - (k.x + 0.5)) < 1.0 && Math.abs(p.y - (k.y + 1)) < 1.4;
    if (near && p.mode !== "dead") {
      if (g.areaProg.cp !== k.id) {
        g.areaProg.cp = k.id;
        k.lit = true;
        g.events.push({ type: "checkpoint", x: k.x, y: k.y });
      }
      p.hp = Math.max(p.hp, g.maxHp);
      p.energy = Math.min(g.maxEnergy, p.energy + dt * 2.5);
    }
  }

  for (const it of g.pickups) {
    it.t += dt;
    if (it.taken) continue;
    if (Math.abs(p.x - (it.x + 0.5)) < 0.8 && p.y - p.h < it.y + 1 && p.y > it.y && p.mode !== "dead") {
      it.taken = true;
      g.events.push({ type: "pickup", kind: it.kind, id: it.id, x: it.x + 0.5, y: it.y + 0.5 });
    }
  }

  // Lift stations.
  const L = g.lift;
  if (L) {
    for (const st of [L.top, L.bottom]) {
      st.near = p.onGround && Math.abs(p.x - (st.x + 0.5)) < 1.1 && Math.abs(p.y - (st.y + 1)) < 0.1;
    }
    if (!g.progress.lift && L.top.near) g.events.push({ type: "liftOn" });
    if (L.ride) {
      L.ride.t += dt;
      if (!L.ride.moved && L.ride.t >= 0.55) {
        L.ride.moved = true;
        const to = L.ride.to;
        p.x = to.x + 0.5;
        p.y = to.y + 1;
        p.vx = 0;
        p.vy = 0;
        g.cam.snap = true;
      }
      if (L.ride.t >= 1.1) {
        L.ride = null;
        p.mode = "normal";
      }
    } else if (g.progress.lift && p.mode === "normal") {
      const wantUp = g.input.my < -0.6 || g.input.upPressed;
      const wantDown = g.input.my > 0.6;
      if (L.bottom.near && wantUp) startRide(g, L, L.top);
      else if (L.top.near && (wantDown || wantUp)) startRide(g, L, L.bottom);
    }
  }

  // Rope anchor.
  if (g.rope && !g.progress.rope && Math.abs(p.x - (g.rope.x + 0.5)) < 0.9 && Math.abs(p.y - (g.rope.y + 1)) < 1.2) {
    g.events.push({ type: "ropeOpen" });
  }

  // Bell: ring it after the stag falls.
  if (g.bell && g.progress.areas[0].boss && !g.progress.bell) {
    if (Math.abs(p.x - (g.bell.x + 0.5)) < 1.3 && Math.abs(p.y - (g.bell.y + 1)) < 1.6) g.events.push({ type: "bell" });
  }
  if (g.bell) g.bell.animT += dt;

  for (const v of g.villagers) {
    v.near = Math.abs(p.x - (v.x + 0.5)) < 2.6 && Math.abs(p.y - (v.y + 1)) < 2;
  }
}

function startRide(g, L, to) {
  L.ride = { t: 0, to, moved: false };
  g.player.mode = "lift";
  g.player.aiming = false;
  g.events.push({ type: "lift" });
}

function set(o, state) {
  o.state = state;
  o.t = 0;
}

export function breakCrackAt(g, cx, cy) {
  for (const c of g.cracks) {
    if (c.broken || c.x !== cx || cy < c.y0 || cy > c.y1) continue;
    c.broken = true;
    setCrackSolid(c, false);
    return c;
  }
  return null;
}
