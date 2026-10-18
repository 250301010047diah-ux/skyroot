// Run simulation: wave flow, projectiles, pickups, effects. Called from
// update() with the SDK's dt only — no timers or wall clock here.
import { STAGES, ENEMIES, BOSSES, UPGRADES, WAVES_PER_STAGE, buildWave, HEROES } from "./data.js";
import { spawnEnemy, spawnBoss, updateEnemy } from "./enemies.js";
import { updateWeapon, updateTurrets, updateHeroAnim, resetWeapon } from "./hero.js";
import { nextId, spawnFx, hurt, bodyOf, isAlive, aoeDamage, damageTree, kill } from "./combat.js";

export function newRun(state, stageIdx, endless, heroes, tw) {
  const maxHp = tw.treeMaxHp;
  state.enemies = [];
  state.shots = [];
  state.fx = [];
  state.coins = [];
  state.texts = [];
  state.stageIdx = endless ? 0 : stageIdx;
  state.run = {
    stage: state.stageIdx, endless, wave: 0, hp: maxHp, maxHp,
    coins: 0, gems: 0, kills: 0, phase: "intro", phaseT: 0,
    queue: [], queueT: 0, waveTotal: 1, waveDone: 0, pendingBoss: null, bossId: 0,
    upg: {}, heroes: heroes.slice(0, 2), active: 0,
    heroAnim: { row: "idle", t: 0, flip: false, hitT: 0, castT: 0, shootT: 0, heroX: 0 },
    aim: { on: false, x: 0, y: 0, holdT: 0 }, fireRequest: false, releasedHold: 0, buffered: 0,
    weapon: { cd: 0, mag: 0, reloadT: 0 },
    skillCd: [4, 6, 6], ladders: [0, 0, 0], shake: 0, hurtFlash: 0,
    bannerT: 0, banner: "", choices: [], picked: [],
    tutorial: !endless && stageIdx === 0 && !state.profile.tutorialDone, tutorialShots: 0,
    result: null,
  };
  resetWeapon(state.run);
  startWave(state);
}

export function stageOf(state) {
  const run = state.run;
  if (!run) return STAGES[0];
  if (run.endless) return STAGES[Math.floor((Math.max(1, run.wave) - 1) / 5) % STAGES.length];
  return STAGES[run.stage];
}

export function startWave(state) {
  const run = state.run;
  run.wave++;
  const stageIdx = run.endless ? STAGES.indexOf(stageOf(state)) : run.stage;
  run.waveStage = stageIdx;
  const w = buildWave(stageIdx, run.wave, {
    endless: run.endless,
    sizeMult: state.tw.waveSize,
    intervalMult: state.tw.spawnInterval / 1.4,
  });
  run.queue = w.list;
  run.queueT = 0;
  run.waveTotal = w.list.length + (w.boss ? 1 : 0);
  run.waveDone = 0;
  run.pendingBoss = w.boss;
  run.ladders = [0, 0, 0];
  run.phase = "intro";
  run.phaseT = 1.6;
  run.banner = w.boss ? (w.boss.mini ? "MINI BOS!" : "BOS!") : `WAVE ${run.wave}`;
  run.bannerSub = w.boss ? bossName(w.boss.type) : run.endless ? "Mode Tanpa Akhir" : stageOf(state).name;
  run.bannerT = 1.8;
}

function bossName(type) {
  return BOSSES[type]?.name || type;
}

export function pickUpgradeChoices(state) {
  const run = state.run;
  const pool = Object.keys(UPGRADES).filter((k) => (run.upg[k] || 0) < UPGRADES[k].max);
  const out = [];
  // Deterministic per wave so a retry offers the same cards.
  let seed = run.wave * 7919 + run.stage * 104729 + (run.endless ? 13 : 0);
  while (out.length < 3 && pool.length) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    out.push(pool.splice(seed % pool.length, 1)[0]);
  }
  run.choices = out;
}

export function applyUpgrade(state, key) {
  const run = state.run;
  run.upg[key] = (run.upg[key] || 0) + 1;
  if (key === "treehp") { run.maxHp += 30; run.hp = Math.min(run.maxHp, run.hp + 30); }
  run.picked.push(key);
}

// Advance everything one step.
export function stepRun(state, geo, dt, hooks) {
  const run = state.run;
  run.heroAnim.heroX = geo.heroX;
  if (run.shake > 0) run.shake = Math.max(0, run.shake - dt * 30);
  if (run.hurtFlash > 0) run.hurtFlash -= dt;
  if (run.bannerT > 0) run.bannerT -= dt;
  for (let i = 0; i < 3; i++) if (run.skillCd[i] > 0) run.skillCd[i] -= dt;

  if (run.phase === "intro") {
    run.phaseT -= dt;
    // Endless: the next area's art may still be streaming in; hold the intro.
    if (run.phaseT <= 0 && hooks.stageReady(run.waveStage)) run.phase = "wave";
  }
  if (run.endless && run.wave % 5 === 4) hooks.prefetchStage((run.waveStage + 1) % STAGES.length);
  updateHazards(state, geo, dt, hooks);
  if (run.phase === "wave") {
    run.queueT += dt;
    while (run.queue.length && run.queue[0].t <= run.queueT) {
      const s = run.queue.shift();
      spawnEnemy(state, geo, s.type, s.side, s.hpMult, { coinMult: s.coinMult });
    }
    if (run.pendingBoss && run.queueT > 1.2) {
      const b = run.pendingBoss;
      run.pendingBoss = null;
      const boss = spawnBoss(state, geo, b.type, b.hpMult, b.mini, hooks);
      boss.coinMult = b.coinMult || 1;
    }
    const alive = state.enemies.some((e) => isAlive(e) && !e.summoned) || state.enemies.some((e) => isAlive(e));
    if (!run.queue.length && !run.pendingBoss && !alive) {
      run.phase = "clear";
      run.phaseT = 1.1;
      hooks.sfx("levelup");
    }
  }
  if (run.phase === "clear") {
    run.phaseT -= dt;
    if (run.phaseT <= 0) {
      if (!run.endless && run.wave >= WAVES_PER_STAGE) hooks.win();
      else hooks.openUpgrade();
    }
  }
  if (run.phase === "win" || run.phase === "lose") {
    run.phaseT -= dt;
    if (run.phaseT <= 0 && !run.result) hooks.finish();
  }

  if (run.phase !== "lose") {
    updateWeapon(state, geo, dt, hooks);
    updateTurrets(state, geo, dt, hooks);
  }
  updateHeroAnim(run, dt);

  for (const e of state.enemies) updateEnemy(state, geo, e, dt, hooks);
  state.enemies = state.enemies.filter((e) => !e.remove);

  updateShots(state, geo, dt, hooks);
  updateCoins(state, geo, dt, hooks);
  for (const f of state.fx) f.t += dt;
  state.fx = state.fx.filter((f) => f.loop ? f.t < f.loop : f.t < 5 / f.fps);
  for (const t of state.texts) { t.t += dt; t.y -= 26 * dt; }
  state.texts = state.texts.filter((t) => t.t < 0.9);

  if (run.tutorial && run.tutorialShots >= 3) {
    run.tutorial = false;
    hooks.tutorialDone();
  }

  if (run.hp <= 0 && run.phase !== "lose") hooks.lose();
}

function updateShots(state, geo, dt, hooks) {
  const shots = state.shots;
  for (const s of shots) {
    s.t += dt;
    if (s.grav) s.vy += s.grav * dt;
    if (!s.hostile && state.stage?.hazard === "wind") s.vx += Math.sin(state.clock * 0.8) * 90 * dt;
    if (s.homing && s.t > 0.08) steer(state, s, dt);
    if (s.boomerang && !s.returned && s.t > 0.55) { s.returned = true; s.vx *= -1; s.vy *= -1; s.hit = []; s.life = 1.2; }
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    if (s.spin) s.rot += s.spin * dt;
    else s.rot = Math.atan2(s.vy, s.vx);
    s.life -= dt;
    if (s.detonate && s.life <= 0) { explode(state, s, hooks, 1); continue; }
    if (s.y > geo.groundY + 10 && !s.hostile) {
      if (s.aoe) explode(state, s, hooks, 0.8);
      else spawnFx(state, "FX_COMBAT", "hit_spark", s.x, geo.groundY, 22);
      s.life = 0;
      continue;
    }
    if (s.x < -80 || s.x > geo.W + 80 || s.y < -400 || s.y > geo.H + 40) { s.life = 0; continue; }

    if (s.hostile) {
      const hh = geo.heroHit;
      if (Math.hypot(s.x - hh.x, s.y - hh.y) < hh.r) {
        damageTree(state, s.dmg, hooks, hh.x, hh.y - 20);
        if (s.kind === "web") { state.run.webT = 2; spawnFx(state, "FX_EXTRA", "ice_burst", hh.x, hh.y, 70, { fps: 8 }); }
        spawnFx(state, "FX_COMBAT", "hit_spark", s.x, s.y, 34);
        s.life = 0;
      }
      continue;
    }
    if (s.detonate) continue;
    // Player shots can knock hostile projectiles out of the air.
    for (const o of shots) {
      if (!o.hostile || o.life <= 0) continue;
      if (Math.hypot(o.x - s.x, o.y - s.y) < 16) {
        o.life = 0;
        spawnFx(state, "FX_COMBAT", "hit_spark", o.x, o.y, 30);
        hooks.sfx("block");
        if (!s.aoe) s.pierce--;
      }
    }
    if (s.pierce <= 0) { s.life = 0; continue; }
    for (const e of state.enemies) {
      if (!isAlive(e) || s.hit.includes(e.id)) continue;
      const b = bodyOf(e);
      if (Math.hypot(b.x - s.x, b.y - s.y) > b.r + 6) continue;
      s.hit.push(e.id);
      if (s.aoe) { explode(state, s, hooks, 1); break; }
      // Crystal golems bounce every third shot back at the hero.
      if (ENEMIES[e.type]?.reflect && !e.boss && !s.legend) {
        e.reflectN = (e.reflectN || 0) + 1;
        if (e.reflectN % 3 === 0) {
          hooks.hostileShot("crystal", s.x, s.y, 240, 6);
          spawnFx(state, "FX_COMBAT", "hit_spark", s.x, s.y, 36);
          hooks.sfx("block");
          s.life = 0;
          break;
        }
      }
      const landed = hurt(state, e, s.dmg, { fromAbove: s.vy > 0, hitY: s.y, effects: s.fx, crit: s.crit }, hooks);
      if (landed && !isAlive(e) && s.lifesteal) state.run.hp = Math.min(state.run.maxHp, state.run.hp + 1);
      spawnFx(state, "FX_COMBAT", "hit_spark", s.x, s.y, s.big ? 44 : 30, { fps: 22 });
      if (landed) {
        hooks.sfx("hit");
        if (s.chain) chainLightning(state, e, s, hooks);
      }
      s.pierce--;
      if (s.pierce <= 0) { s.life = 0; break; }
    }
  }
  state.shots = shots.filter((s) => s.life > 0);
}

function steer(state, s, dt) {
  let best = null, bd = 220;
  for (const e of state.enemies) {
    if (!isAlive(e) || s.hit.includes(e.id)) continue;
    const b = bodyOf(e);
    const d = Math.hypot(b.x - s.x, b.y - s.y);
    if (d < bd) { bd = d; best = b; }
  }
  if (!best) return;
  const sp = Math.hypot(s.vx, s.vy);
  const cur = Math.atan2(s.vy, s.vx);
  const want = Math.atan2(best.y - s.y, best.x - s.x);
  let diff = want - cur;
  while (diff > Math.PI) diff -= Math.PI * 2;
  while (diff < -Math.PI) diff += Math.PI * 2;
  const a = cur + Math.max(-5 * dt, Math.min(5 * dt, diff));
  s.vx = Math.cos(a) * sp;
  s.vy = Math.sin(a) * sp;
}

// Area hazards: tide (area 7), embers (8), clock (12), storm (14).
function updateHazards(state, geo, dt, hooks) {
  const run = state.run;
  const hz = state.stage?.hazard;
  if (run.clockT > 0) run.clockT -= dt;
  if (!hz || run.phase !== "wave") return;
  run.hazT = (run.hazT ?? 6) - dt;
  if (run.hazT > 0) return;
  if (hz === "tide") {
    run.hazT = 12;
    for (const e of state.enemies) if (isAlive(e) && !e.boss && (e.phase === "climb" || e.phase === "top")) { e.y = Math.min(geo.groundY - 4, e.y + 50); if (e.phase === "top") e.phase = "climb"; }
    run.bannerT = 1; run.banner = "PASANG!"; run.bannerSub = "Ombak menyeret pemanjat turun";
    hooks.sfx("explode");
  } else if (hz === "embers") {
    run.hazT = 7;
    hooks.hostileShot("lava", geo.heroX + (Math.random() - 0.5) * 200, -30, 150, 4);
  } else if (hz === "clock") {
    run.hazT = 12;
    run.clockT = 2.5;
    run.bannerT = 1; run.banner = "WAKTU BERHENTI!"; run.bannerSub = "Musuh melambat";
    hooks.sfx("levelup");
  } else if (hz === "storm") {
    run.hazT = 6;
    const alive = state.enemies.filter((e) => isAlive(e));
    if (alive.length) {
      const e = alive[Math.floor(Math.random() * alive.length)];
      const b = bodyOf(e);
      spawnFx(state, "FX_ELEMENT", "lightning", b.x, b.y - 20, 90, { fps: 16 });
      hurt(state, e, 30 * state.tw.heroDamage, {}, hooks);
      hooks.sfx("zap");
    }
  } else {
    run.hazT = 99;
  }
}

function explode(state, s, hooks, scale) {
  s.life = 0;
  const r = s.aoe * scale;
  spawnFx(state, "FX_COMBAT", "explosion", s.x, s.y, r * 2.1, { fps: 13 });
  hooks.sfx("explode");
  hooks.shake(s.kind === "bomb" ? 10 : 4);
  aoeDamage(state, s.x, s.y, r, s.dmg, hooks, s.fx);
}

function chainLightning(state, from, s, hooks) {
  let src = from;
  const hitIds = new Set([from.id]);
  for (let i = 0; i < s.chain; i++) {
    let best = null, bd = 110;
    for (const e of state.enemies) {
      if (!isAlive(e) || hitIds.has(e.id)) continue;
      const d = Math.hypot(e.x - src.x, e.y - src.y);
      if (d < bd) { bd = d; best = e; }
    }
    if (!best) break;
    hitIds.add(best.id);
    const b = bodyOf(best);
    spawnFx(state, "FX_ELEMENT", "lightning", b.x, b.y - 10, 70, { fps: 18 });
    hurt(state, best, s.dmg * 0.5, { silent: false }, hooks);
    src = best;
  }
  hooks.sfx("zap");
}

function updateCoins(state, geo, dt, hooks) {
  const run = state.run;
  for (const c of state.coins) {
    c.t += dt;
    if (c.phase === "pop") {
      c.vy += 520 * dt;
      c.x += c.vx * dt;
      c.y = Math.min(geo.groundY - 6, c.y + c.vy * dt);
      if (c.t > 0.5) { c.phase = "fly"; c.t = 0; c.sx = c.x; c.sy = c.y; }
    } else if (c.phase === "fly") {
      const p = Math.min(1, c.t / 0.45);
      const e = p * p;
      c.x = c.sx + (geo.coinTarget.x - c.sx) * e;
      c.y = c.sy + (geo.coinTarget.y - c.sy) * e - Math.sin(p * Math.PI) * 40;
      if (p >= 1) {
        c.done = true;
        if (c.stolen) continue;
        if (c.gem) { run.gems += c.value; hooks.sfx("gem"); }
        else { run.coins += c.value; hooks.sfx("coin"); }
        run.coinPulse = 0.2;
      }
    }
  }
  if (run.coinPulse > 0) run.coinPulse -= dt;
  state.coins = state.coins.filter((c) => !c.done);
}

// Creator / debug verbs.
export function debugSpawn(state, geo, type) {
  if (!state.run) return;
  if (ENEMIES[type]) spawnEnemy(state, geo, type, Math.random() < 0.5 ? -1 : 1, 1, { summoned: true });
}

export function killAll(state, hooks) {
  for (const e of state.enemies) if (isAlive(e)) kill(state, e, hooks);
}

export function heroName(id) {
  return HEROES[id]?.name || id;
}

export { nextId };
