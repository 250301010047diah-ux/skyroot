// The hero on the platform: weapon stats, firing per weapon type, skills,
// branch turrets and the hero animation state machine.
import { HEROES, SKILLS, SKILL3, skinBuffs } from "./data.js";
import { bowPoint } from "./geometry.js";
import { nextId, spawnFx, bodyOf, isAlive, floatText } from "./combat.js";

export function activeHero(run) {
  return run.heroes[run.active] || run.heroes[0];
}

export function equippedTier(state, heroId) {
  return state.profile.equipped?.[heroId] || 1;
}

// Combined weapon numbers from hero base, permanent level, skin tier, run
// upgrades and tweaks.
export function weaponStats(state, heroId) {
  const h = HEROES[heroId];
  const lvl = state.profile.levels[heroId] || 1;
  const up = state.run.upg;
  const special = lvl >= 5 ? h.special : null;
  const sk = skinBuffs(heroId, equippedTier(state, heroId));
  const fx = {};
  if (sk.element === "fire") fx.burn = 6;
  if (sk.element === "ice") fx.slow = 1.8;
  if (sk.element === "poison") fx.poison = 5;
  if (up.fire || special === "fire" || special === "burn") fx.burn = 3 + 3 * (up.fire || 0) + (special ? 3 : 0);
  if (h.burn) fx.burn = (fx.burn || 0) + h.burn * (special === "bigburn" ? 2 : 1);
  if (up.ice || special === "ice") fx.slow = 1.2 + (up.ice || 0) * 0.8;
  if (up.poison || special === "poison") fx.poison = 2.5 * (up.poison || 0) + (special === "poison" ? 4 : 0);
  const chain = (up.lightning || 0) + (special === "lightning" ? 2 : 0) + (sk.element === "lightning" ? 2 : 0);
  return {
    dmg: h.dmg * (1 + 0.2 * (lvl - 1)) * (1 + 0.25 * (up.dmg || 0)) * sk.dmg * state.tw.heroDamage,
    cd: h.cd * Math.pow(0.85, up.rate || 0) * sk.rate,
    reload: (h.reload || 0) * Math.pow(0.9, up.rate || 0) * sk.rate,
    speed: h.speed * state.tw.projectileSpeed * sk.speed,
    shots: sk.shots,
    extra: up.multi || 0,
    pierce: (h.pierce || 1) + sk.pierce,
    fx: Object.keys(fx).length ? fx : null,
    chain,
    special,
    sk,
  };
}

function projKind(h, stats) {
  if (h.proj === "arrow") return stats.fx?.burn ? "fire_arrow" : stats.fx?.slow ? "ice_arrow" : "arrow";
  return h.proj;
}

// Legendary (tier 10) giant shot per hero, every 5th shot.
const LEGEND = {
  ranger: { kind: "phoenix", size: 76, mul: 4, pierce: 99, speed: 1 },
  gunner: { kind: "laser", size: 48, mul: 3, pierce: 12, speed: 1.3 },
  bomber: { kind: "nuke", size: 52, mul: 4, pierce: 1, aoe: 120, speed: 0.9 },
  hunter: { kind: "bolt_l", size: 54, mul: 3, pierce: 6, chain: 6, speed: 1.1 },
  mage: { kind: "fireball", size: 96, mul: 3, pierce: 10, burn: 14, speed: 0.8 },
  ninja: { kind: "gshuriken", size: 64, mul: 3, pierce: 99, speed: 0.9, boomerang: true },
};

function pushShot(state, from, a, sp, props) {
  state.shots.push({
    id: nextId(state), x: from.x, y: from.y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, rot: a,
    spin: 0, pierce: 1, aoe: 0, fx: null, chain: 0, life: 1.6, hit: [], hostile: false, t: 0,
    ...props,
  });
}

// Fire the active weapon toward the aim point.
export function fireWeapon(state, geo, hooks, charge = 0) {
  const run = state.run;
  const heroId = activeHero(run);
  const h = HEROES[heroId];
  const st = weaponStats(state, heroId);
  const flip = run.aim.x < geo.heroX;
  const from = bowPoint(geo, flip);
  const base = Math.atan2(run.aim.y - from.y, run.aim.x - from.x);
  const count = st.shots + st.extra;
  const spread = h.shots ? h.spread : 0.12;
  const dmgMul = h.charge ? 1 + 1.6 * charge : 1;
  const sources = [from];
  // Klon Bayangan: two shadow clones fire alongside.
  if (run.cloneT > 0) sources.push({ x: geo.heroX - 74, y: from.y + 4 }, { x: geo.heroX + 74, y: from.y + 4 });
  for (const src of sources) {
    const a0 = Math.atan2(run.aim.y - src.y, run.aim.x - src.x);
    for (let i = 0; i < count; i++) {
      const off = count === 1 ? 0 : (i - (count - 1) / 2) * spread;
      const crit = Math.random() < st.sk.crit;
      pushShot(state, src, a0 + off, st.speed * (h.charge ? 1 + 0.35 * charge : 1), {
        kind: projKind(h, st), spin: h.proj === "shuriken" ? 18 : 0,
        dmg: st.dmg * dmgMul * (src === from ? 1 : 0.6), pierce: st.pierce, aoe: h.aoe || 0,
        fx: st.fx, chain: st.chain, big: charge > 0.8, crit, homing: st.sk.homing, lifesteal: st.sk.lifesteal,
      });
    }
  }
  run.shotCount = (run.shotCount || 0) + 1;
  if (st.sk.legendary && run.shotCount % 5 === 0) {
    const L = LEGEND[heroId];
    pushShot(state, from, base, st.speed * L.speed, {
      kind: L.kind, size: L.size, dmg: st.dmg * L.mul * 3, pierce: L.pierce, aoe: L.aoe || 0,
      fx: L.burn ? { burn: L.burn, burnTime: 3 } : st.fx, chain: L.chain || st.chain, life: 2.2, legend: true,
      spin: L.kind === "gshuriken" ? 14 : 0, boomerang: L.boomerang, homing: false,
    });
    spawnFx(state, "FX_PICKUP", "level_up", geo.heroX, geo.platformY - 40, 80, { fps: 16 });
    hooks.sfx("zap");
  }
  run.heroAnim.shootT = 0.25;
  run.heroAnim.flip = flip;
  if (h.proj === "bullet") spawnFx(state, "FX_COMBAT", "muzzle_flash", from.x + Math.cos(base) * 14, from.y + Math.sin(base) * 14, 30, { fps: 30 });
  hooks.sfx(h.proj === "bullet" ? "gun" : h.proj === "rocket" ? "rocket" : h.proj === "fireball" ? "fire" : "shoot");
  if (run.tutorial) run.tutorialShots = (run.tutorialShots || 0) + 1;
}

// Per-frame weapon logic: cooldowns, auto-fire while held, release-to-fire.
export function updateWeapon(state, geo, dt, hooks) {
  const run = state.run;
  const w = run.weapon;
  const h = HEROES[activeHero(run)];
  const st = weaponStats(state, activeHero(run));
  if (run.sporeT > 0) { run.sporeT -= dt; st.cd *= 1.7; }
  if (run.stormT > 0) { run.stormT -= dt; st.cd *= 0.5; if (h.mag) w.mag = Math.max(w.mag, 1); }
  if (run.cloneT > 0) run.cloneT -= dt;
  if (run.webT > 0) { run.webT -= dt; run.fireRequest = false; run.buffered = 0; return; }
  if (w.cd > 0) w.cd -= dt;
  if (w.reloadT > 0) {
    w.reloadT -= dt;
    if (w.reloadT <= 0) w.mag = h.mag || 0;
  }
  if (run.aim.on) run.aim.holdT += dt;
  const ready = w.cd <= 0 && w.reloadT <= 0;

  if (h.auto) {
    if (run.aim.on && ready && w.mag > 0) {
      fireWeapon(state, geo, hooks);
      w.cd = st.cd;
      if (!(run.stormT > 0)) w.mag--;
      if (w.mag <= 0) { w.reloadT = st.reload; run.weaponReloadTotal = st.reload; }
    }
    run.fireRequest = false;
    return;
  }
  if (run.fireRequest) {
    run.fireRequest = false;
    run.buffered = 0.35;
    run.bufferedCharge = h.charge ? Math.min(1, run.releasedHold / 0.9) : 0;
  }
  if (run.buffered > 0) {
    run.buffered -= dt;
    if (ready) {
      fireWeapon(state, geo, hooks, run.bufferedCharge || 0);
      run.buffered = 0;
      w.cd = st.cd;
      if (h.mag) { w.mag--; if (w.mag <= 0) { w.reloadT = st.reload; run.weaponReloadTotal = st.reload; } }
    }
  }
}

export function resetWeapon(run) {
  const h = HEROES[activeHero(run)];
  run.weapon = { cd: 0.2, mag: h.mag || 0, reloadT: 0 };
}

export function swapHero(state) {
  const run = state.run;
  if (!run.heroes[1] || run.phase === "lose" || run.phase === "win") return false;
  run.active = run.active ? 0 : 1;
  resetWeapon(run);
  run.heroAnim.castT = 0.3;
  return true;
}

// Skills: 0 = arrow rain, 1 = bomb.
export function skill3Of(state) {
  const run = state.run;
  const heroId = activeHero(run);
  return equippedTier(state, heroId) >= 8 ? SKILL3[heroId] : null;
}

export function castSkill(state, geo, idx, hooks) {
  const run = state.run;
  if (run.skillCd[idx] > 0 || run.phase === "lose" || run.phase === "win") return false;
  const st = weaponStats(state, activeHero(run));
  const dmgBase = 10 * (1 + 0.25 * (run.upg.dmg || 0)) * state.tw.heroDamage * (1 + 0.15 * (equippedTier(state, activeHero(run)) - 1));
  if (idx === 2) {
    const sk = skill3Of(state);
    if (!sk) return false;
    run.skillCd[2] = sk.cd;
    run.heroAnim.castT = 0.5;
    castSkill3(state, geo, sk.id, dmgBase, st, hooks);
    return true;
  }
  run.skillCd[idx] = SKILLS[idx].cd;
  run.heroAnim.castT = 0.5;
  if (idx === 0) {
    const targets = state.enemies.filter(isAlive);
    for (let i = 0; i < 18; i++) {
      const tgt = targets.length && i % 2 === 0 ? targets[(i / 2) % targets.length] : null;
      const x = tgt ? bodyOf(tgt).x + (Math.random() - 0.5) * 20 : geo.cx + (Math.random() - 0.5) * 240;
      state.shots.push({
        id: nextId(state), kind: st.fx?.burn ? "fire_arrow" : "arrow", x, y: -30 - i * 34,
        vx: 0, vy: 820, rot: Math.PI / 2, spin: 0, dmg: dmgBase * 1.6, pierce: 2, aoe: 0,
        fx: st.fx, chain: 0, life: 3, hit: [], hostile: false, t: 0, skill: true,
      });
    }
    hooks.sfx("shoot");
  } else {
    // Bomb lands on the most dangerous target: the boss, else the highest climber.
    const alive = state.enemies.filter(isAlive);
    let target = alive.find((e) => e.boss) || alive.filter((e) => !e.boss).sort((a, b) => a.y - b.y)[0];
    const tx = target ? bodyOf(target).x : geo.cx;
    const ty = target ? bodyOf(target).y : (geo.platformY + geo.groundY) / 2;
    const from = bowPoint(geo, tx < geo.heroX);
    const T = 0.65, g = 900;
    state.shots.push({
      id: nextId(state), kind: "bomb", x: from.x, y: from.y,
      vx: (tx - from.x) / T, vy: (ty - from.y) / T - 0.5 * g * T, grav: g, rot: 0, spin: 8,
      dmg: dmgBase * 7, pierce: 99, aoe: 92, fx: { burn: 4 }, chain: 0, life: T, hit: [], hostile: false, t: 0, detonate: true,
    });
    hooks.sfx("fuse");
  }
  return true;
}

function castSkill3(state, geo, id, dmgBase, st, hooks) {
  const run = state.run;
  const alive = state.enemies.filter(isAlive);
  const aimX = run.aim.x || geo.cx, aimY = run.aim.y || (geo.platformY + geo.groundY) / 2;
  if (id === "phoenix") {
    const from = bowPoint(geo, aimX < geo.heroX);
    const a = Math.atan2(aimY - from.y, aimX - from.x);
    pushShot(state, from, a, 620, { kind: "phoenix", size: 96, dmg: dmgBase * 9, pierce: 99, fx: { burn: 10, burnTime: 3 }, life: 2.5, legend: true });
    hooks.sfx("fire");
  } else if (id === "storm") {
    run.stormT = 5;
    floatText(state, geo.heroX, geo.platformY - 90, "HUJAN PELURU!", "#ffd84a", true);
  } else if (id === "airstrike") {
    const xs = [geo.lanes[0], geo.lanes[1], geo.lanes[2], geo.cx - geo.trunkW, geo.cx + geo.trunkW];
    xs.forEach((x, i) => {
      const ty = geo.climbTopY + 40 + Math.random() * (geo.groundY - geo.climbTopY - 60);
      state.shots.push({ id: nextId(state), kind: "nuke", size: 44, x, y: -40 - i * 50, vx: 0, vy: 640, rot: Math.PI / 2, spin: 0,
        dmg: dmgBase * 5.5, pierce: 99, aoe: 78, fx: { burn: 5 }, chain: 0, life: (ty + 40 + i * 50) / 640, hit: [], hostile: false, t: 0, detonate: true });
    });
    hooks.sfx("rocket");
  } else if (id === "net") {
    for (const e of alive) {
      e.netT = e.boss ? 1.2 : 3;
      spawnFx(state, "FX_EXTRA", "ice_burst", bodyOf(e).x, bodyOf(e).y, (e.boss ? 120 : 60), { fps: 10 });
    }
    hooks.sfx("zap");
  } else if (id === "meteor") {
    const tx = geo.cx, ty = (geo.climbTopY + geo.groundY) / 2;
    const T = 0.8;
    state.shots.push({ id: nextId(state), kind: "fireball", size: 130, x: geo.cx - 220, y: -80, vx: 220 / T, vy: (ty + 80) / T, rot: 0, spin: 0,
      dmg: dmgBase * 13, pierce: 99, aoe: 170, fx: { burn: 8 }, chain: 0, life: T, hit: [], hostile: false, t: 0, detonate: true, legend: true });
    void tx;
    hooks.sfx("fire");
  } else if (id === "clones") {
    run.cloneT = 6;
    spawnFx(state, "FX_COMBAT", "death_smoke", geo.heroX - 74, geo.platformY - 30, 60);
    spawnFx(state, "FX_COMBAT", "death_smoke", geo.heroX + 74, geo.platformY - 30, 60);
  }
}

// Branch turrets bought with the Turret upgrade fire at the nearest enemy.
export function turretPositions(geo, n) {
  const pts = [
    { x: geo.cx - geo.trunkW * 0.5 - 4, y: geo.platformY + 150, flip: true },
    { x: geo.cx + geo.trunkW * 0.5 + 4, y: geo.platformY + 230, flip: false },
  ];
  return pts.slice(0, n);
}

export function updateTurrets(state, geo, dt, hooks) {
  const run = state.run;
  const n = run.upg.turret || 0;
  if (!n) return;
  run.turretT = (run.turretT || 0) - dt;
  if (run.turretT > 0) return;
  run.turretT = 1.3 / n;
  const pts = turretPositions(geo, n);
  const p = pts[(run.turretShot = ((run.turretShot || 0) + 1) % pts.length)];
  let best = null, bd = 300;
  for (const e of state.enemies) {
    if (!isAlive(e)) continue;
    const b = bodyOf(e);
    const d = Math.hypot(b.x - p.x, b.y - p.y);
    if (d < bd) { bd = d; best = b; }
  }
  if (!best) return;
  const a = Math.atan2(best.y - p.y, best.x - p.x);
  p.aim = a;
  run.turretAim = a;
  state.shots.push({
    id: nextId(state), kind: "bolt", x: p.x, y: p.y - 10, vx: Math.cos(a) * 640, vy: Math.sin(a) * 640, rot: a, spin: 0,
    dmg: 6 * (1 + 0.25 * (run.upg.dmg || 0)) * state.tw.heroDamage, pierce: 1, aoe: 0, fx: null, chain: 0, life: 1.2, hit: [], hostile: false, t: 0,
  });
  hooks.sfx("shootSoft");
}

// Which row the hero shows this frame (priority order), and its timing.
export function heroRow(run) {
  const ha = run.heroAnim;
  if (run.phase === "lose") return { row: "death", sheet: "B", fps: 8, loop: false };
  if (run.phase === "win") return { row: "victory", sheet: "B", fps: 8, loop: true };
  if (ha.castT > 0) return { row: "cast", sheet: "B", fps: 11, loop: false };
  if (ha.hitT > 0) return { row: "hit", sheet: "B", fps: 14, loop: false };
  if (ha.shootT > 0) return { row: "shoot", sheet: "A", fps: 20, loop: false };
  if (run.weapon.reloadT > 0) return { row: "reload", sheet: "A", fps: 6, loop: false };
  if (run.aim.on) return { row: "aim", sheet: "A", fps: 14, loop: false };
  return { row: "idle", sheet: "A", fps: 7, loop: true };
}

export function updateHeroAnim(run, dt) {
  const ha = run.heroAnim;
  for (const k of ["castT", "hitT", "shootT"]) if (ha[k] > 0) ha[k] -= dt;
  const r = heroRow(run);
  if (r.row !== ha.row) { ha.row = r.row; ha.t = 0; }
  ha.t += dt;
  if (run.aim.on) ha.flip = run.aim.x < ha.heroX;
}
