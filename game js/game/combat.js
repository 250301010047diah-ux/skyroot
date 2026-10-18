// The bow (aim, quick shot, full draw, Air Focus), arrows in flight, Footing
// Arrow steps, and enemy projectiles.
import { isSolidTile, tileAt, TILE, crackAt } from "./world.js";
import { clearLine } from "./physics.js";
import { hurtPlayer } from "./player.js";

const FULL_DRAW = 0.55;
const QUICK_TIME = 0.17;

export function updateBow(g, p, inp, realDt, tune) {
  const fullDraw = FULL_DRAW * (tune.skin ? tune.skin.draw : 1);
  const canAim = p.mode === "normal";
  if (!canAim) {
    p.aiming = false;
    return;
  }
  if (inp.bowDown && !p.aiming) {
    p.aiming = true;
    p.aimT = 0;
    p.aimX = p.face;
    p.aimY = 0;
  }
  if (!p.aiming) return;
  p.aimT += realDt;
  let dx = p.face;
  let dy = 0;
  if (inp.aimSource === "pointer") {
    dx = inp.aimWX - p.x;
    dy = inp.aimWY - (p.y - 1.0);
  } else if (inp.aimSource === "drag" && inp.dragLen > 14) {
    dx = inp.dragX;
    dy = inp.dragY;
  } else if (inp.aimSource === "key") {
    if (Math.abs(inp.mx) > 0.3) p.face = inp.mx > 0 ? 1 : -1;
    dx = p.face;
    dy = inp.my < -0.4 ? -1 : inp.my > 0.4 ? 0.6 : 0;
  }
  const len = Math.hypot(dx, dy) || 1;
  p.aimX = dx / len;
  p.aimY = dy / len;
  if (Math.abs(p.aimX) > 0.08) p.face = p.aimX > 0 ? 1 : -1;

  if (inp.bowReleased) {
    const quick = p.aimT < QUICK_TIME && !(inp.aimSource === "drag" && inp.dragLen > 14);
    let ax = p.aimX;
    let ay = p.aimY;
    let power = Math.min(1, p.aimT / fullDraw);
    if (quick) {
      power = 0.35;
      if (inp.aimSource !== "pointer") {
        const t = autoTarget(g, p);
        if (t) {
          const ddx = t.x - p.x;
          const ddy = t.y - (p.y - 1.0);
          const l = Math.hypot(ddx, ddy) || 1;
          ax = ddx / l;
          ay = ddy / l;
          // Lift a little against arrow drop.
          ay -= Math.min(0.12, l * 0.008);
        } else {
          ax = p.face;
          ay = 0;
        }
      }
    }
    fireArrow(g, p, ax, ay, power, tune);
    p.aiming = false;
    p.releaseT = 0.16;
    p.face = ax >= 0 ? 1 : -1;
  }
}

function autoTarget(g, p) {
  let best = null;
  let bestD = 11;
  for (const t of g.aimTargets) {
    const d = Math.hypot(t.x - p.x, t.y - (p.y - 1));
    if (d < bestD && clearLine(p.x, p.y - 1, t.x, t.y)) {
      best = t;
      bestD = d;
    }
  }
  return best;
}

export function arrowLaunch(p, ax, ay, power, tune) {
  const speed = tune.arrowSpeed * (0.72 + 0.48 * power);
  return { x: p.x + p.face * 0.3, y: p.y - 1.0, vx: ax * speed, vy: ay * speed, g: 20 * (1 - 0.7 * power) };
}

function fireArrow(g, p, ax, ay, power, tune) {
  const skin = tune.skin;
  let kind = "normal";
  if (g.progress.abilities.footing && g.arrowType === "footing") {
    if (p.energy >= 1) {
      p.energy -= 1;
      kind = "footing";
    } else g.events.push({ type: "noenergy" });
  }
  const full = power >= 1;
  const shots = kind === "footing" ? 1 : skin.shots * (g.cloneT > 0 ? 2 : 1);
  const base = Math.atan2(ay, ax);
  const perVolley = kind === "footing" ? 1 : skin.shots;
  for (let i = 0; i < shots; i++) {
    const volley = Math.floor(i / perVolley);
    const j = i % perVolley;
    const spread = perVolley > 1 ? (j - (perVolley - 1) / 2) * 0.13 : 0;
    const ang = base + spread;
    const l = arrowLaunch(p, Math.cos(ang), Math.sin(ang), power, tune);
    if (volley === 1) l.y -= 1.6; // the moon clone fires from above the archer
    g.arrows.push({
      id: g.uid++, kind: kind === "footing" ? "footing" : "normal", sprite: kind === "footing" ? "footing_arrow" : skin.arrow,
      x: l.x, y: l.y, vx: l.vx, vy: l.vy, g: l.g,
      dmg: (full ? 2 : 1) + skin.dmg, full, state: "fly", t: 0,
      pierce: skin.pierce, burn: skin.burn, slow: skin.slow, chain: skin.chain && full, homing: skin.homing, hits: [], bounces: 0,
    });
  }
  g.events.push({ type: "shoot", full, kind });
}

// Arrows rained from the sky by skills.
export function rainArrows(g, left, width, top, count, sprite, dmg, extra = {}) {
  for (let i = 0; i < count; i++) {
    const x = left + ((i + 0.5) / count) * width + Math.sin(i * 12.9) * 0.4;
    g.arrows.push({
      id: g.uid++, kind: "normal", sprite, x, y: top - (i % 3) * 0.8, vx: 0.6, vy: 26, g: 10,
      dmg, full: true, state: "fly", t: 0, pierce: extra.pierce || 0, burn: false, slow: !!extra.slow, chain: false, homing: false, hits: [], bounces: 9, rain: true,
    });
  }
}

// hitTest(arrow) -> true when an enemy/boss consumed the arrow.
export function updateArrows(g, dt, hitTest) {
  for (const a of g.arrows) {
    a.t += dt;
    if (a.state === "stuck" || a.state === "drop") {
      if (a.state === "drop") {
        a.vy += 30 * dt;
        a.x += a.vx * dt;
        a.y += a.vy * dt;
        a.spin = (a.spin || 0) + dt * 14;
      }
      if (a.t > 1.4) a.dead = true;
      continue;
    }
    if (a.homing && a.t > 0.06) {
      let best = null;
      let bd = 9;
      for (const t of g.aimTargets) {
        const d = Math.hypot(t.x - a.x, t.y - a.y);
        if (d < bd && !a.hits.includes(t.id)) {
          bd = d;
          best = t;
        }
      }
      if (best) {
        const sp = Math.hypot(a.vx, a.vy);
        const want = Math.atan2(best.y - a.y, best.x - a.x);
        let cur = Math.atan2(a.vy, a.vx);
        let diff = want - cur;
        while (diff > Math.PI) diff -= Math.PI * 2;
        while (diff < -Math.PI) diff += Math.PI * 2;
        cur += Math.max(-1, Math.min(1, diff)) * Math.min(1, dt * 9);
        a.vx = Math.cos(cur) * sp;
        a.vy = Math.sin(cur) * sp;
        a.g = 0;
      }
    }
    const steps = Math.max(1, Math.ceil((Math.hypot(a.vx, a.vy) * dt) / 0.2));
    const sdt = dt / steps;
    for (let i = 0; i < steps && a.state === "fly"; i++) {
      a.vy += a.g * sdt;
      const px = a.x;
      const py = a.y;
      a.x += a.vx * sdt;
      a.y += a.vy * sdt;
      if (hitTest(a)) {
        a.dead = true;
        break;
      }
      const cx = Math.floor(a.x);
      const cy = Math.floor(a.y);
      if (isSolidTile(cx, cy)) {
        const side = Math.floor(px) !== cx && isSolidTile(cx, Math.floor(py)) ? true : Math.floor(py) === cy;
        if (crackAt(cx, cy)) {
          g.events.push({ type: "crack", x: cx, y: cy });
          a.dead = true;
          break;
        }
        if (tileAt(cx, cy) === TILE.CRYSTAL && a.bounces < 3) {
          a.x = px;
          a.y = py;
          if (side) a.vx = -a.vx;
          else a.vy = -a.vy;
          a.bounces++;
          a.hits.length = 0;
          g.fx.push({ kind: "arrow_hit", x: px, y: py, t: 0, dur: 0.25, scale: 0.7 });
          g.events.push({ type: "block" });
          continue;
        }
        if (a.rain) {
          a.dead = true;
          g.fx.push({ kind: "arrow_hit", x: px, y: py, t: 0, dur: 0.3 });
          break;
        }
        // Back the tip out to the surface.
        a.x = px;
        a.y = py;
        a.state = "stuck";
        a.t = 0;
        g.fx.push({ kind: "arrow_hit", x: a.x, y: a.y, t: 0, dur: 0.3 });
        g.events.push({ type: "thunk", x: a.x, y: a.y });
        if (a.kind === "footing") {
          const ok = side && tileAt(cx, cy) === TILE.SOFT && makeFooting(g, cx, cy, a.vx > 0 ? 1 : -1, a.y);
          if (!ok) {
            g.player.energy = Math.min(g.maxEnergy, g.player.energy + 1);
            g.events.push({ type: "footfail", x: a.x, y: a.y });
          } else a.dead = true;
        }
      }
    }
    if (a.t > 3 || a.y > 120 || a.y < -5) a.dead = true;
  }
  g.arrows = g.arrows.filter((a) => !a.dead);
}

// A step grows out of the wall face the arrow hit. wallDir = +1 when the wall is to the right.
function makeFooting(g, cx, cy, wallDir, hitY) {
  const row = hitY - cy > 0.75 ? cy + 1 : cy;
  const nx0 = wallDir > 0 ? cx - 2 : cx + 1;
  // Standing room above both cells, and open air where the step itself sits.
  for (let i = 0; i < 2; i++) if (isSolidTile(nx0 + i, row - 1)) return false;
  if (isSolidTile(wallDir > 0 ? cx - 1 : cx + 1, row)) return false;
  // One step per spot: replace a footing already here.
  for (const f of g.footings) if (Math.abs(f.top - row) < 0.6 && Math.abs(f.x0 - nx0) < 1.1) f.dying = 0.01;
  g.footings.push({ id: g.uid++, x0: nx0, x1: nx0 + 2, top: row, wallDir, t: 0, dying: 0 });
  const alive = g.footings.filter((f) => !f.dying);
  const max = g.tune.footingMax;
  if (alive.length > max) {
    alive.sort((a, b) => a.id - b.id);
    for (let i = 0; i < alive.length - max; i++) alive[i].dying = 0.65;
  }
  g.events.push({ type: "sprout", x: nx0 + 1, y: row });
  return true;
}

export function updateFootings(g, dt) {
  for (const f of g.footings) {
    f.t += dt;
    if (f.dying) {
      f.dying -= dt;
      if (f.dying <= 0) f.dead = true;
    }
  }
  g.footings = g.footings.filter((f) => !f.dead);
}

// ---- Enemy projectiles
export function updateProjectiles(g, dt) {
  const p = g.player;
  for (const s of g.eproj) {
    s.t += dt;
    s.vy += (s.g || 0) * dt;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    const r = s.r || 0.25;
    if (p.mode !== "dead" && Math.abs(s.x - p.x) < r + p.w / 2 && s.y > p.y - p.h - r && s.y < p.y + r) {
      if (hurtPlayer(g, p, s.dmg || 1, s.x)) {
        if (s.freeze) p.freezeT = 1.6;
        s.dead = true;
        g.fx.push({ kind: "arrow_hit", x: s.x, y: s.y, t: 0, dur: 0.3 });
        continue;
      }
    }
    if (s.kind === "shock" || s.ghost) {
      if (s.t > (s.life || 5)) s.dead = true;
      continue;
    }
    if (isSolidTile(Math.floor(s.x), Math.floor(s.y)) || (s.kind === "mud" && s.vy > 0 && tileAt(Math.floor(s.x), Math.floor(s.y)) === TILE.ONEWAY)) {
      s.dead = true;
      if (s.kind === "mud" || s.kind === "debris" || s.kind === "seed" || s.splash) {
        g.fx.push({ kind: "dust", x: s.x, y: Math.floor(s.y), t: 0, dur: 0.45, scale: 1.1 });
        if (Math.abs(s.x - p.x) < 1.0 && Math.abs(Math.floor(s.y) - p.y) < 1.2) hurtPlayer(g, p, 1, s.x);
        g.events.push({ type: "splat", x: s.x, y: s.y });
      }
    }
    if (s.t > 6) s.dead = true;
  }
  g.eproj = g.eproj.filter((s) => !s.dead);
}
