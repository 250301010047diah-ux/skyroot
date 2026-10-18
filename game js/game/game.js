// Skyroot — The Last Archer. This file wires the modules together and owns the
// run's state; each system lives in its own sibling module.
import { WORLD, COLS, ROWS, ROPE, TILE, setCrackSolid, setRope, loadArea } from "./world.js";
import { createPlayer, updatePlayer, hurtPlayer, ledgeDrawPos, GRAVITY } from "./player.js";
import { updateBow, updateArrows, updateFootings, updateProjectiles, rainArrows } from "./combat.js";
import { createEnemy, updateEnemies, arrowHitsEnemy } from "./enemies.js";
import { createBoss, updateBoss, updateWarnings, arrowHitsBoss, nodePos, weakPos } from "./boss.js";
import { createAreaBoss, updateAreaBoss, arrowHitsAreaBoss, damageAreaBoss, updateBeams, bossRect } from "./bossGeneric.js";
import { collectPlatforms, updateObjects, updateMovers, updateHazards, breakCrackAt } from "./objects.js";
import { overlapsTile } from "./physics.js";
import { createHud } from "./hud.js";
import { createInput } from "./input.js";
import { createAudio } from "./audio.js";
import { createLoader } from "./loader.js";
import { createTerrain } from "./terrain.js";
import { createRenderer } from "./render.js";
import { sceneNodes } from "./scene.js";
import { AREAS, BOSSES, SKINS, SKILL_NAMES, MONSTERS } from "./content.js";
import { defaultProgress, sanitizeProgress, secretsFound, secretIdsFor, EXPLORE_BLOCK, skinOwned, AREA_COUNT, TOTAL_SECRETS } from "./save.js";

const single = (g) => WORLD.singles.filter((s) => s.g === g);

export function createGame({ mount, sdk, ready, tweaks, assets, saved }) {
  const hud = createHud(mount);
  const audio = createAudio(sdk, tweaks);
  const loader = createLoader(assets);
  let progress = sanitizeProgress(saved);
  let renderer = null;
  let terrain = null;
  let coreJob = null;
  let loadVersion = 0;
  let destroyed = false;
  let ro = null;
  let mapOpen = false;
  let wardrobeOpen = false;
  let resetArmed = 0;
  let run = null;
  let introShown = false;

  // Everything the run needs lives on this one object (plain JSON).
  const state = {};

  const readTune = () => {
    const skin = SKINS[progress.skin] || SKINS[0];
    return {
      runSpeed: Number(tweaks.get("playerSpeed")) * skin.speed,
      jumpV: Math.sqrt(2 * GRAVITY * Number(tweaks.get("jumpHeight"))),
      gravity: AREAS[progress.area]?.gravity || 1,
      focusSlow: Number(tweaks.get("airFocusSlow")),
      arrowSpeed: Number(tweaks.get("arrowSpeed")),
      footingMax: Math.round(Number(tweaks.get("footingMax"))),
      energyRegen: Number(tweaks.get("energyRegen")),
      windStrength: Number(tweaks.get("windStrength")),
      bossHp: Math.round(Number(tweaks.get("bossHp"))),
      showHitboxes: Boolean(tweaks.get("showHitboxes")),
      skin,
    };
  };
  const unsubTune = tweaks.onChange(() => {
    if (state.tune) state.tune = readTune();
  });

  const input = createInput(hud, { onFirstGesture: () => void audio.unlock() });

  function persist() {
    try {
      sdk.gameState.save(progress).catch(() => {});
    } catch {
      // saving is best-effort; play continues
    }
  }

  function toast(s, text, dur = 2.6) {
    s.toast = { text, t: 0, dur };
  }

  function haptic(ms) {
    try {
      if (sdk.device.haptics.isSupported()) sdk.device.haptics.vibrate(ms);
    } catch {
      // haptics are optional
    }
  }

  // ---- Build (or rebuild) the run for the current area from saved progress. Synchronous and repeatable.
  function buildRun(s) {
    const area = progress.area;
    // Later maps have no traversal relics; direct area selection needs these tools.
    if (area > 0) progress.abilities = { footing: true, dash: true };
    loadArea(area);
    const ap = progress.areas[area];
    const tune = readTune();
    const skin = tune.skin;
    Object.assign(s, {
      t: 0,
      phase: "loading",
      progress,
      areaIndex: area,
      areaProg: ap,
      rows: ROWS,
      tune,
      uid: 1000,
      events: [],
      arrows: [],
      footings: [],
      eproj: [],
      fx: [],
      particles: [],
      warnings: [],
      beams: [],
      bolts: [],
      platforms: [],
      aimTargets: [],
      slow: 1,
      shake: 0,
      toast: s.toast || null,
      speech: null,
      bellRing: 0,
      bridgeT: ap.boss ? 1 : 0,
      emberT: 0,
      emberOn: false,
      cloneT: 0,
      skillCd: 0,
      nearShrine: false,
      maxHp: progress.maxHp + skin.hp,
      maxEnergy: progress.maxEnergy + skin.energy,
      arrowType: progress.abilities.footing ? s.arrowType || "footing" : "normal",
      input: { mx: 0, my: 0, upPressed: false },
    });
    let id = 1;
    const areaMonster = AREAS[area].monster;
    s.enemies = WORLD.singles
      .filter((o) => "TBQ*".includes(o.g))
      .map((o) => createEnemy(id++, o.g === "T" ? "thorn" : o.g === "B" ? "beetle" : o.g === "Q" ? "frog" : areaMonster || "thorn", o.x, o.y, area));
    const O = single("O")[0];
    s.boss = O ? (area === 0 ? createBoss(O.x, O.y, ap.boss, tune.bossHp) : createAreaBoss(area, O.x, O.y, ap.boss)) : null;
    s.leaves = WORLD.runs.L.map((r, i) => ({ id: i, ...r, state: "open", t: 0 }));
    s.crumbles = WORLD.runs.C.map((r, i) => ({ id: i, ...r, state: "ok", t: 0 }));
    s.bridge = WORLD.runs.n.map((r) => ({ ...r }));
    s.movers = [
      ...WORLD.runs.M.map((r) => ({ axis: "x", ...r })),
      ...WORLD.runs.N.map((r) => ({ axis: "y", ...r })),
    ].map((r, i) => ({ id: i, x0: r.x0, w: r.x1 - r.x0 + 1, y: r.y, axis: r.axis, amp: r.axis === "x" ? 1.2 : 1.4, speed: 1.15, phase: i * 1.7, t: 0, px: r.x0, py: r.y }));
    s.flowers = single("F").map((o, i) => ({ id: i, x: o.x, y: o.y, state: "idle", t: 0 }));
    s.winds = WORLD.winds.map((w, i) => ({ id: i, ...w, on: true, t: i * 0.9 }));
    s.stalactites = single("v").map((o) => ({ x: o.x, y: o.y, state: "hang", t: 0 }));
    s.checkpoints = single("K").map((o) => {
      const cid = `K@${o.x},${o.y}`;
      return { id: cid, x: o.x, y: o.y, lit: ap.cp === cid, animT: 0 };
    });
    s.pickups = WORLD.singles
      .filter((o) => "HEDARY".includes(o.g))
      .map((o) => ({ id: `${o.g}@${o.x},${o.y}`, kind: o.g, x: o.x, y: o.y, taken: false, t: 0 }))
      .filter((it) => it.kind === "H" || !ap.got.includes(it.id));
    s.cracks = WORLD.cracks.map((c) => {
      const cid = `X@${c.x},${c.y0}`;
      const broken = ap.broken.includes(cid);
      setCrackSolid(c, !broken);
      return { id: cid, ...c, broken };
    });
    const U = single("U")[0];
    const u = single("u")[0];
    s.lift = U && u ? { bottom: { x: U.x, y: U.y, near: false }, top: { x: u.x, y: u.y, near: false }, ride: null } : null;
    const z = single("z")[0];
    s.rope = z ? { x: z.x, y: z.y } : null;
    setRope(ROPE, progress.rope);
    const b = single("b")[0];
    s.bell = b ? { x: b.x, y: b.y, animT: 0 } : null;
    const G = single("G")[0];
    s.gate = G ? { x: G.x, y: G.y, active: area === 0 ? progress.bell : ap.boss } : null;
    s.villagers = single("V").map((o) => ({ x: o.x, y: o.y, near: false }));
    s.decor = WORLD.singles.filter((o) => "hlms".includes(o.g)).map((o) => ({ g: o.g, x: o.x, y: o.y }));
    const cp = s.checkpoints.find((k) => k.id === ap.cp);
    const start = cp || single("P")[0];
    s.player = createPlayer(start.x + 0.5, start.y + 1, { maxHp: s.maxHp, maxEnergy: s.maxEnergy });
    s.cam = { x: s.player.x, y: s.player.y - 1, snap: true, zoom: 1 };
    audio.setArea(AREAS[area].music);
    loadCurrent(s);
  }

  // Named actions --------------------------------------------------------------
  function travelTo(s, area) {
    if (!Number.isInteger(area) || area < 0 || area >= AREA_COUNT) return;
    closePanels();
    progress.area = Math.max(0, Math.min(progress.unlocked, area));
    persist();
    s.phase = "play";
    buildRun(s);
    if (s.phase === "play") announceArea(s);
    else s.pendingAnnounce = true;
  }

  function announceArea(s) {
    toast(s, `Wilayah ${s.areaIndex} · ${AREAS[s.areaIndex].name}`, 2.8);
  }

  function equipSkin(s, i) {
    if (!skinOwned(progress, i)) return;
    if (progress.skin === i) return;
    progress.skin = i;
    s.tune = readTune();
    const skin = SKINS[i];
    s.maxHp = progress.maxHp + skin.hp;
    s.maxEnergy = progress.maxEnergy + skin.energy;
    // Changing clothes must not become an unlimited heal/skill-reset exploit.
    s.player.hp = Math.min(s.player.hp, s.maxHp);
    s.player.energy = Math.min(s.player.energy, s.maxEnergy);
    closePanels();
    loadCurrent(s);
    audio.play("relic");
    toast(s, `${skin.name} dipakai`, 2);
    persist();
  }

  function resetProgress(s) {
    progress = defaultProgress();
    persist();
    closePanels();
    s.phase = "play";
    buildRun(s);
    toast(s, "Petualangan baru dimulai", 2.2);
  }

  // Damage from arrows and skills -----------------------------------------------
  function damageEnemy(s, e, dmg) {
    if (e.dead) return;
    e.hp -= dmg;
    e.hurtT = 0.2;
    if (e.hp <= 0) {
      e.dead = true;
      s.events.push({ type: "defeat", x: e.x, y: e.y - e.h / 2, enemy: true });
      if (e.id % 3 === 0 && !e.summoned) s.pickups.push({ id: `drop${s.uid++}`, kind: "H", x: Math.floor(e.x), y: Math.floor(e.y - 1), taken: false, t: 0 });
    }
  }

  function hitTest(s, a) {
    for (const e of s.enemies) {
      if (e.dead || a.hits.includes(e.id)) continue;
      const r = arrowHitsEnemy(e, a);
      if (r === "hit") {
        damageEnemy(s, e, a.dmg);
        if (a.burn) e.burnT = 3;
        if (a.slow) e.slowT = 2.5;
        s.fx.push({ kind: "arrow_hit", x: a.x, y: a.y, t: 0, dur: 0.3 });
        if (!e.dead) s.events.push({ type: "thunk" });
        if (a.chain) chainFrom(s, e, a.dmg);
        a.hits.push(e.id);
        if (a.pierce > 0) {
          a.pierce--;
          return false;
        }
        return true;
      }
      if (r === "block") {
        if (s.tune.skin.pierce >= 2) {
          // High-tier skins punch straight through shields.
          damageEnemy(s, e, a.dmg);
          a.hits.push(e.id);
          return true;
        }
        a.state = "drop";
        a.t = 0;
        a.vx = -a.vx * 0.25;
        a.vy = -5;
        s.fx.push({ kind: "arrow_hit", x: a.x, y: a.y, t: 0, dur: 0.3 });
        s.events.push({ type: "block" });
        return false;
      }
    }
    if (a.hits.includes("boss")) return false;
    const consumed = s.areaIndex === 0 ? arrowHitsBoss(s, a) : arrowHitsAreaBoss(s, a);
    if (consumed && a.pierce > 0) {
      a.hits.push("boss");
      a.pierce--;
      return false;
    }
    return consumed;
  }

  function chainFrom(s, from, dmg) {
    let best = null;
    let bd = 6;
    for (const e of s.enemies) {
      if (e === from || e.dead) continue;
      const d = Math.hypot(e.x - from.x, e.y - from.y);
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    if (best) {
      s.bolts.push({ x0: from.x, y0: from.y - from.h / 2, x1: best.x, y1: best.y - best.h / 2, t: 0, dur: 0.25 });
      damageEnemy(s, best, Math.max(1, Math.round(dmg * 0.7)));
    }
  }

  function castSkill(s) {
    const skin = s.tune.skin;
    if (!skin.skill || s.skillCd > 0 || !renderer) return;
    const v = renderer.view;
    const box = renderer.camBox(s.cam);
    const sc = v.scale * (s.cam.zoom || 1);
    const vw = v.w / sc;
    const vh = v.h / sc;
    const inView = (x, y) => x > box.left - 1 && x < box.left + vw + 1 && y > box.top - 1 && y < box.top + vh + 1;
    s.skillCd = 10;
    const bossHit = (dmg) => {
      const b = s.boss;
      if (b && b.generic && inView(b.x, b.y - 2)) {
        damageAreaBoss(s, dmg);
        s.bolts.push({ x0: b.x, y0: box.top, x1: b.x, y1: b.y - 2, t: 0, dur: 0.4 });
      }
    };
    switch (skin.skill) {
      case "icerain":
        rainArrows(s, box.left, vw, box.top - 0.5, 14, "ice_arrow", 2 + skin.dmg, { slow: true });
        break;
      case "starrain":
        rainArrows(s, box.left, vw, box.top - 0.5, 20, "star_arrow", 3 + skin.dmg, { pierce: 2 });
        break;
      case "thunder":
        for (const e of s.enemies)
          if (!e.dead && inView(e.x, e.y)) {
            s.bolts.push({ x0: e.x + 0.4, y0: box.top, x1: e.x, y1: e.y - e.h / 2, t: 0, dur: 0.35 });
            damageEnemy(s, e, 5 + skin.dmg);
          }
        bossHit(8);
        s.events.push({ type: "thunder" });
        break;
      case "clone":
        s.cloneT = 8;
        break;
      case "guardian":
        for (const e of s.enemies)
          if (!e.dead && inView(e.x, e.y)) {
            damageEnemy(s, e, 10 + skin.dmg);
            s.fx.push({ kind: "leaf_burst", x: e.x, y: e.y, t: 0, dur: 0.6, scale: 1.4 });
          }
        bossHit(16);
        for (let i = 0; i < 6; i++) s.fx.push({ kind: "leaf_burst", x: box.left + ((i + 0.5) / 6) * vw, y: box.top + vh * 0.6, t: -i * 0.06, dur: 0.6, scale: 2 });
        s.shake = 0.45;
        s.events.push({ type: "stomp" });
        break;
    }
    audio.play("relic");
    toast(s, SKILL_NAMES[skin.skill] + "!", 1.4);
    haptic(40);
  }

  function villagerLine() {
    if (!progress.abilities.footing) return "Gua di bawah desa menyimpan Panah Pijakan.";
    if (!progress.areas[0].boss) return "Menara lonceng ada di puncak. Reruntuhan, batang berlubang, atau akar luar — pilih jalanmu.";
    if (!progress.bell) return "Rusa Menara tumbang! Bunyikan loncengnya.";
    return "Gerbang di menara membawamu ke atas. Kamu juga bisa memilih wilayah lewat peta dan jubah lewat lemari.";
  }

  // Events ------------------------------------------------------------------------
  function processEvents(s) {
    const p = s.player;
    const ap = s.areaProg;
    for (const ev of s.events) {
      switch (ev.type) {
        case "jump":
        case "walljump":
        case "doublejump":
          audio.play("jump");
          s.fx.push({ kind: "dust", x: ev.x, y: ev.y, t: 0, dur: 0.35, scale: ev.type === "doublejump" ? 0.9 : 0.7 });
          break;
        case "land":
          audio.play("land", ev.hard);
          s.fx.push({ kind: "dust", x: ev.x, y: ev.y, t: 0, dur: 0.4, scale: ev.hard ? 1.1 : 0.8 });
          break;
        case "dash":
          audio.play("dash");
          s.fx.push({ kind: "dust", x: ev.x, y: ev.y, t: 0, dur: 0.35, scale: 0.9, flip: p.face > 0 });
          break;
        case "hurt":
          audio.play("hurt");
          s.shake = 0.25;
          haptic(40);
          break;
        case "shoot":
          audio.play("shoot", ev.full);
          break;
        case "thunk":
          audio.play("thunk");
          break;
        case "sprout":
          audio.play("sprout");
          break;
        case "footfail":
          audio.play("footfail");
          break;
        case "noenergy":
          audio.play("noenergy");
          toast(s, "Energi habis — berdiri di tanah untuk memulihkan", 2);
          break;
        case "crack": {
          if (ev.quiet) {
            audio.play("crack");
            break;
          }
          const c = breakCrackAt(s, ev.x, ev.y);
          if (c) {
            ap.broken.push(c.id);
            s.fx.push({ kind: "leaf_burst", x: c.x + 0.5, y: c.y1 + 1, t: 0, dur: 0.6, scale: 1.2 });
            audio.play("crumble");
            toast(s, s.areaIndex === 6 ? "Jaring putus!" : "Dinding rapuh runtuh!");
            persist();
          }
          break;
        }
        case "crumble":
          audio.play("crumble");
          break;
        case "leaf":
          audio.play("leaf");
          break;
        case "launch":
          audio.play("launch");
          break;
        case "spit":
          audio.play("spit");
          break;
        case "lob":
          audio.play("lob");
          break;
        case "splat":
          audio.play("splat");
          break;
        case "defeat":
          audio.play("defeat");
          s.fx.push({ kind: "leaf_burst", x: ev.x, y: ev.y + 0.9, t: 0, dur: 0.55 });
          if (ev.enemy) s.skillCd = Math.max(0, s.skillCd - 0.7);
          break;
        case "block":
          audio.play("block");
          break;
        case "pickup":
          applyPickup(s, ev);
          break;
        case "checkpoint":
          audio.play("checkpoint");
          toast(s, progress.areas.some((a, i) => i > 0 && a.boss) ? "Titik istirahat · buka Lemari Skin di sini" : "Titik istirahat menyala");
          persist();
          break;
        case "liftOn":
          if (!progress.lift) {
            progress.lift = true;
            audio.play("checkpoint");
            toast(s, "Lift akar menyala — jalan pintas ke desa", 3);
            persist();
          }
          break;
        case "lift":
          audio.play("lift");
          break;
        case "ropeOpen":
          if (!progress.rope) {
            progress.rope = true;
            setRope(ROPE, true);
            audio.play("rope");
            toast(s, "Tali terjulur ke desa — jalan pintas", 3);
            persist();
          }
          break;
        case "bossStart":
          audio.play("stomp");
          toast(s, ev.name ? `${ev.name} bangkit!` : "Rusa Menara terbangun! Tembak simpul di tanduknya", 3);
          break;
        case "bossPhase":
          toast(s, ev.phase === 3 ? "Fase terakhir!" : "Fase 2 — serangannya makin cepat!", 2.2);
          s.shake = 0.3;
          break;
        case "bossShoot":
          audio.play("shoot");
          break;
        case "stomp":
          audio.play("stomp");
          s.shake = Math.max(s.shake, 0.3);
          haptic(50);
          break;
        case "thunder":
          audio.play("nodeBreak");
          s.shake = Math.max(s.shake, 0.15);
          break;
        case "nodeBreak":
          audio.play("nodeBreak");
          break;
        case "bossStun":
          toast(s, "Kepalanya turun — bidik rune emas!", 2.4);
          break;
        case "bossHurt":
          if (!ev.quiet || Math.floor(s.t * 8) % 2 === 0) audio.play(ev.quiet ? "thunk" : "hurt");
          if (!ev.quiet) {
            s.shake = 0.2;
            haptic(30);
          }
          break;
        case "summon": {
          const type = AREAS[s.areaIndex].monster;
          for (let i = 0; i < 2; i++) {
            const m = MONSTERS[type];
            const e = createEnemy(s.uid++, type, i ? 26 : 16, m.fly ? 6 : 11, s.areaIndex);
            e.summoned = true;
            e.cd = 1;
            s.enemies.push(e);
            s.fx.push({ kind: "leaf_burst", x: e.x, y: e.y, t: 0, dur: 0.5 });
          }
          break;
        }
        case "bossDying":
          // Count the victory as soon as the boss starts to fall, so dying or leaving
          // during its 2-second death animation can't bring it back.
          ap.boss = true;
          persist();
          break;
        case "bossDefeated":
          ap.boss = true;
          if (s.gate) s.gate.active = s.areaIndex === 0 ? progress.bell : true;
          s.enemies = s.enemies.filter((e) => !e.summoned);
          s.eproj.length = 0;
          s.bridgeT = 0;
          audio.play("defeat");
          audio.play("relic");
          for (let i = 0; i < 4; i++) s.fx.push({ kind: "leaf_burst", x: s.boss.x - 2 + i * 1.3, y: s.boss.y - 1 - (i % 2) * 2, t: -i * 0.12, dur: 0.6, scale: 1.4 });
          if (s.areaIndex === 0) toast(s, "Rusa Menara tumbang — jembatan akar tumbuh ke lonceng", 3.2);
          else {
            toast(s, s.areaIndex === AREA_COUNT - 1 ? "Jantung Kabut hancur! Masuki gerbang" : `${BOSSES[s.areaIndex].name} tumbang! Gerbang wilayah terbuka`, 4);
          }
          persist();
          break;
        case "bell":
          if (!progress.bell) {
            progress.bell = true;
            progress.unlocked = Math.max(progress.unlocked, 1);
            s.bellRing = 1;
            if (s.gate) s.gate.active = true;
            audio.play("bell");
            toast(s, "Lonceng berbunyi — gerbang ke Kebun Gantung terbuka!", 3.5);
            loader.ensureArea(1).catch(() => {});
            persist();
          }
          break;
        case "gate":
          if (s.areaIndex === AREA_COUNT - 1) {
            if (s.phase !== "ending") {
              s.phase = "ending";
              audio.play("bell");
              audio.play("win");
              void sdk.leaderboard?.submit?.(Math.max(0, Math.round(secretsFound(progress) * 100 + 10000 - Math.min(9999, progress.time / 6))))?.catch?.(() => {});
            }
          } else {
            progress.unlocked = Math.max(progress.unlocked, s.areaIndex + 1);
            travelTo(s, s.areaIndex + 1);
            return;
          }
          break;
        default:
          break;
      }
    }
    s.events.length = 0;
  }

  function applyPickup(s, ev) {
    const p = s.player;
    const ap = s.areaProg;
    const secret = secretIdsFor(s.areaIndex).includes(ev.id);
    if (ev.kind !== "H" && !ap.got.includes(ev.id)) ap.got.push(ev.id);
    const tag = () => (secret ? ` · Rahasia ${secretsFound(progress)}/${TOTAL_SECRETS}` : "");
    switch (ev.kind) {
      case "H":
        p.hp = Math.min(s.maxHp, p.hp + 1);
        audio.play("pickup");
        return;
      case "E":
        progress.maxEnergy = Math.min(13, progress.maxEnergy + 1);
        s.maxEnergy = progress.maxEnergy + s.tune.skin.energy;
        p.energy = s.maxEnergy;
        toast(s, "Batu Energi! Energi maks +1" + tag(), 3);
        break;
      case "D":
        progress.abilities.dash = true;
        toast(s, "Dash didapat! Melesat di darat atau udara", 3.4);
        break;
      case "A":
        progress.abilities.footing = true;
        s.arrowType = "footing";
        toast(s, "Panah Pijakan! Tembak kayu terang untuk membuat tangga", 3.8);
        break;
      case "R":
        progress.maxHp = Math.min(14, progress.maxHp + 1);
        s.maxHp = progress.maxHp + s.tune.skin.hp;
        p.hp = s.maxHp;
        toast(s, "Jantung Akar! Nyawa maks +1" + tag(), 3);
        break;
      case "Y":
        progress.feather = true;
        toast(s, "Bulu Emas ditemukan!" + tag(), 3);
        break;
    }
    audio.play("relic");
    s.fx.push({ kind: "leaf_burst", x: ev.x, y: ev.y + 0.8, t: 0, dur: 0.6, scale: 0.9 });
    persist();
  }

  function markExplored(s) {
    const p = s.player;
    const ap = s.areaProg;
    const bw = Math.ceil(COLS / EXPLORE_BLOCK);
    const bh = Math.ceil(ROWS / EXPLORE_BLOCK);
    const ex = ap.explored.padEnd(bw * bh, "0").split("");
    const bx = Math.floor(p.x / EXPLORE_BLOCK);
    const by = Math.floor(p.y / EXPLORE_BLOCK);
    let changed = false;
    for (let dy = -3; dy <= 2; dy++)
      for (let dx = -2; dx <= 2; dx++) {
        const x = bx + dx;
        const y = by + dy;
        if (x < 0 || y < 0 || x >= bw || y >= bh) continue;
        if (ex[y * bw + x] !== "1") {
          ex[y * bw + x] = "1";
          changed = true;
        }
      }
    if (changed) ap.explored = ex.join("");
  }

  function updateCamera(s, dt) {
    const p = s.player;
    const v = renderer ? renderer.view : { w: 400, h: 700, scale: 32 };
    // The boss arena zooms out so the whole fight fits a phone frame.
    const arena = p.y < 12.8 && p.x > 10 && p.x < 34;
    const zoomTarget = arena ? Math.min(1, v.w / 21.5 / v.scale) : 1;
    s.cam.zoom = s.cam.zoom || 1;
    s.cam.zoom += (zoomTarget - s.cam.zoom) * (s.cam.snap ? 1 : Math.min(1, dt * 3));
    const sc = v.scale * s.cam.zoom;
    let px = p.x;
    let py = p.y;
    if (p.mode === "ledge" && p.ledge) {
      const lp = ledgeDrawPos(p);
      px = lp.x;
      py = lp.y;
    }
    // While drawing the bow the view only leans a little toward the aim, so it doesn't tug.
    let tx = px + p.face * 1.2 + (p.aiming ? p.aimX * 0.5 : 0);
    let ty = py - 1.0 + (p.aiming ? p.aimY * 0.4 : 0) + (p.vy > 12 ? 1.5 : 0);
    if (arena) {
      tx = 22.5 + (px - 22.5) * 0.25;
      ty = 6.0 + (py - 6.0) * 0.1;
    }
    const halfW = v.w / 2 / sc;
    const topOff = (v.h * 0.47) / sc;
    const botOff = (v.h * 0.53) / sc;
    tx = COLS < halfW * 2 ? COLS / 2 : Math.max(halfW, Math.min(COLS - halfW, tx));
    // In the arena the view may rise above the crown so the fight sits below the HUD.
    const minTy = arena ? Math.min(topOff, 6.0) : topOff;
    ty = ROWS < topOff + botOff ? ROWS / 2 : Math.max(minTy, Math.min(ROWS - botOff, ty));
    if (s.cam.snap) {
      s.cam.x = tx;
      s.cam.y = ty;
      s.cam.snap = false;
    } else {
      s.cam.x += (tx - s.cam.x) * Math.min(1, dt * 6);
      s.cam.y += (ty - s.cam.y) * Math.min(1, dt * 6);
    }
  }

  const hooks = {
    init(s) {
      buildRun(s);
    },

    update(s, dt) {
      if (s.phase === "play" && !introShown) {
        introShown = true;
        if (s.areaIndex === 0 && !progress.abilities.footing) {
          const touch = hud.el.root.classList.contains("touch");
          toast(s, touch ? "Joystick untuk lari · tahan busur & geser untuk membidik" : "A/D lari · Spasi lompat · tahan klik untuk membidik", 4.5);
        }
      }
      s.toast && (s.toast.t += dt);
      if (s.phase !== "play" || mapOpen || wardrobeOpen) {
        const inp = input.sample();
        if (inp.mapPressed && s.phase === "play" && !wardrobeOpen) toggleMap(s);
        input.clearEdges();
        return;
      }
      const inp = input.sample();
      if (renderer) {
        const box = renderer.camBox(s.cam);
        const sc = renderer.view.scale * (s.cam.zoom || 1);
        inp.aimWX = box.left + inp.pointerX / sc;
        inp.aimWY = box.top + inp.pointerY / sc;
      }
      s.input = { mx: inp.mx, my: inp.my, upPressed: inp.upPressed };
      if (inp.mapPressed) {
        toggleMap(s);
        input.clearEdges();
        return;
      }
      if (inp.switchPressed && progress.abilities.footing) {
        s.arrowType = s.arrowType === "footing" ? "normal" : "footing";
        audio.play("footfail");
      }
      if (inp.skillPressed) castSkill(s);
      const p = s.player;
      const tune = s.tune;

      // Air Focus: aiming in mid-air slows the world while the meter lasts.
      const wantSlow = p.aiming && !p.onGround && p.mode === "normal" && p.focus > 0;
      if (wantSlow) p.focus = Math.max(0, p.focus - dt);
      const targetSlow = wantSlow ? tune.focusSlow : 1;
      s.slow += (targetSlow - s.slow) * Math.min(1, dt * 14);
      const wdt = dt * s.slow;
      s.t += wdt;
      progress.time += dt;
      s.shake = Math.max(0, s.shake - dt);
      s.skillCd = Math.max(0, s.skillCd - dt);
      s.cloneT = Math.max(0, s.cloneT - dt);
      // Ember vents breathe on a shared beat: dormant 1.8 s, flaring 1.2 s.
      s.emberT += wdt;
      if (s.emberT > (s.emberOn ? 1.2 : 1.8)) {
        s.emberOn = !s.emberOn;
        s.emberT = 0;
      }

      updateMovers(s, wdt);
      updateBow(s, p, inp, dt, tune);
      s.platforms = collectPlatforms(s);
      updatePlayer(s, p, inp, wdt, tune);

      // Thorn spikes: hurt and return to the last safe ground. Ember vents: hurt while flaring.
      if (p.mode !== "dead" && p.mode !== "lift" && overlapsTile(p, TILE.SPIKE)) {
        if (p.invuln <= 0) hurtPlayer(s, p, 1, p.x);
        if (p.mode !== "dead") {
          p.x = p.safeX;
          p.y = p.safeY;
          p.vx = 0;
          p.vy = 0;
          p.mode = "normal";
        }
      }
      if (s.emberOn && p.mode !== "dead" && overlapsTile(p, TILE.EMBER)) hurtPlayer(s, p, 1, p.x - p.face);
      // Energy for Footing Arrows recovers on natural ground (slower on steps).
      if (p.onGround && progress.abilities.footing) {
        const rate = p.groundId === null ? tune.energyRegen : tune.energyRegen * 0.35;
        p.energy = Math.min(s.maxEnergy, p.energy + rate * wdt);
      }

      updateObjects(s, wdt);
      updateHazards(s, wdt);
      updateFootings(s, wdt);
      s.nearShrine = s.checkpoints.some((k) => Math.abs(p.x - (k.x + 0.5)) < 1.6 && Math.abs(p.y - (k.y + 1)) < 1.6);

      s.aimTargets = s.enemies.filter((e) => !e.dead).map((e) => ({ id: e.id, x: e.x, y: e.y - e.h * 0.55 }));
      const b = s.boss;
      if (b && b.state !== "gone" && b.state !== "sleep" && b.state !== "dying") {
        if (b.generic) {
          const r = bossRect(b);
          s.aimTargets.push({ id: "boss", x: (r.x0 + r.x1) / 2, y: (r.y0 + r.y1) / 2 });
        } else if (b.state === "stunned") s.aimTargets.push({ id: "boss", ...weakPos(b) });
        else b.nodes.forEach((on, i) => on && s.aimTargets.push({ id: "node" + i, ...nodePos(b, i) }));
      }
      for (const c of s.cracks) if (!c.broken) s.aimTargets.push({ id: c.id, x: c.x + 0.5, y: c.y0 + 1 });

      updateArrows(s, wdt, (a) => hitTest(s, a));
      updateEnemies(s, wdt);
      s.enemies = s.enemies.filter((e) => !e.dead);
      if (s.areaIndex === 0) updateBoss(s, wdt);
      else updateAreaBoss(s, wdt);
      updateWarnings(s, wdt);
      updateBeams(s, wdt);
      updateProjectiles(s, wdt);

      for (const f of s.fx) f.t += wdt;
      s.fx = s.fx.filter((f) => f.t < f.dur);
      for (const bo of s.bolts) bo.t += wdt;
      s.bolts = s.bolts.filter((bo) => bo.t < bo.dur);
      // Dash trail and golden feather sparkles.
      if (p.mode === "dash" || (progress.feather && Math.abs(p.vx) > 2 && Math.floor(s.t * 30) % 3 === 0)) {
        s.particles.push({ x: p.x - p.face * 0.3, y: p.y - 0.4 - ((s.uid++ % 7) / 7) * 1.0, vx: -p.face * 2, vy: -0.5, life: 0.4, max: 0.4, size: 0.12, col: progress.feather ? "#ffd86a" : "#c9fff0" });
      }
      for (const q of s.particles) {
        q.life -= wdt;
        q.x += q.vx * wdt;
        q.y += q.vy * wdt;
      }
      s.particles = s.particles.filter((q) => q.life > 0).slice(-120);
      if (s.areaIndex === 0 && progress.areas[0].boss) s.bridgeT += wdt;

      // Villager speech.
      const v = s.villagers.find((x) => x.near);
      s.speech = v ? { text: villagerLine(), x: v.x + 0.5, y: v.y - 1.1 } : null;

      // Defeat: fade, then wake at the last shrine with the area reset.
      if (p.mode === "dead") {
        p.deadT += dt;
        if (p.deadT > 1.6) {
          progress.deaths++;
          persist();
          buildRun(s);
          toast(s, "Bangkit di titik istirahat", 2);
        }
      }

      if (Math.floor(s.t * 4) !== Math.floor((s.t - wdt) * 4)) markExplored(s);
      updateCamera(s, dt);
      processEvents(s);
      input.clearEdges();
    },

    render(s) {
      const playing = s.phase !== "loading";
      audio.setMusic(playing && !!run && !run.frozen && !document.hidden);
      hud.el.loading.hidden = playing && !!renderer;
      if (!renderer || !s.cam || !playing) {
        return;
      }
      let cam = s.cam;
      if (s.shake > 0) {
        // Gentle nudge only: the camera sways a few hundredths of a tile.
        const k = s.shake * 0.08;
        cam = { x: s.cam.x + Math.sin(s.t * 91) * k, y: s.cam.y + Math.cos(s.t * 77) * k, zoom: s.cam.zoom };
      }
      renderer.draw(s, cam);
      let screen = null;
      if (s.speech) {
        const box = renderer.camBox(cam);
        const sc = renderer.view.scale * (cam.zoom || 1);
        screen = { x: (s.speech.x - box.left) * sc, y: (s.speech.y - box.top) * sc };
      }
      hud.update(s, screen);
      if (mapOpen) {
        hud.drawMap(s);
        hud.updateChips(s, (i) => {
          closePanels();
          travelTo(state, i);
        });
      }
    },
  };

  function closePanels() {
    mapOpen = false;
    wardrobeOpen = false;
    hud.el.mapPanel.hidden = true;
    hud.el.wardrobePanel.hidden = true;
  }

  function toggleMap(s) {
    input.reset();
    s.player.aiming = false;
    mapOpen = !mapOpen;
    hud.el.mapPanel.hidden = !mapOpen;
    resetArmed = 0;
    hud.el.resetBtn.querySelector(".control-label").textContent = "Mulai dari awal";
    if (mapOpen) hud.drawMap(s);
  }

  function openWardrobe(s) {
    input.reset();
    s.player.aiming = false;
    wardrobeOpen = true;
    hud.el.wardrobePanel.hidden = false;
    hud.buildWardrobe(s, loader.sheets.SKIN_ICONS, (i) => equipSkin(state, i));
  }

  // ---- DOM buttons outside the play loop (menus only change flags or call named actions).
  hud.el.mapBtn.addEventListener("click", () => {
    if (state.phase === "play" && !wardrobeOpen) toggleMap(state);
  });
  hud.el.mapClose.addEventListener("click", () => toggleMap(state));
  hud.el.wardrobeBtn.addEventListener("click", () => {
    if (state.phase === "play" && !mapOpen) openWardrobe(state);
  });
  hud.el.wardrobeClose.addEventListener("click", () => closePanels());
  hud.el.resetBtn.addEventListener("click", () => {
    if (!resetArmed) {
      resetArmed = 1;
      hud.el.resetBtn.querySelector(".control-label").textContent = "Yakin? Ketuk lagi";
      return;
    }
    resetProgress(state);
  });
  hud.el.endContinue.addEventListener("click", () => {
    state.phase = "play";
    state.gateHold = true;
  });
  hud.el.endReset.addEventListener("click", () => resetProgress(state));

  // One retryable loading path for startup, travel, respawn and skin changes.
  // Only the latest request may resume play; both area and skin must be ready.
  function ensureCore() {
    if (!coreJob) coreJob = loader.loadCore().then(() => {
      if (!renderer && !destroyed) {
        terrain = createTerrain(loader.kitsFor(progress.area));
        renderer = createRenderer(hud.el.canvas, { sheets: loader.sheets, singles: loader.singles, pixelRatioLimit: assets?.pixelRatioLimit }, terrain);
        renderer.resize();
        ro = new ResizeObserver(() => renderer.resize());
        ro.observe(hud.el.canvas);
        audio.composeMusic();
      }
    }).catch(error => { coreJob = null; throw error; });
    return coreJob;
  }

  async function loadCurrent(s) {
    const version = ++loadVersion;
    const area = s.areaIndex, skin = progress.skin;
    s.phase = "loading";
    s.loadingError = null;
    input.reset();
    s.player.aiming = false;
    hud.el.loading.hidden = false;
    hud.setLoading(0.1, `Memuat ${AREAS[area].name} · ${SKINS[skin].name}…`);
    try {
      await ensureCore();
      if (destroyed || version !== loadVersion) return;
      hud.setLoading(0.65, `Memuat frame ${AREAS[area].name} · ${SKINS[skin].name}…`);
      await Promise.all([loader.ensureArea(area), loader.ensureSkin(skin)]);
      if (destroyed || version !== loadVersion) return;
      loader.retain(area, skin);
      terrain.setKits(loader.kitsFor(area));
      s.cam.snap = true;
      updateCamera(s, 0);
      const v = renderer.view, box = renderer.camBox(s.cam);
      terrain.warm(box.left, box.top, v.w, v.h, v.scale, v.dpr);
      input.reset();
      s.phase = "play";
      if (s.pendingAnnounce) announceArea(s);
      s.pendingAnnounce = false;
      persist();
    } catch (error) {
      if (destroyed || version !== loadVersion) return;
      s.loadingError = error.message;
      console.warn("Skyroot asset loading:", error.message);
      hud.setLoading(0, `Gagal memuat ${AREAS[area].name}. Ketuk di sini untuk coba lagi.`);
    }
  }
  hud.el.loading.addEventListener("click", () => {
    if (state.loadingError) loadCurrent(state);
  });

  return {
    state,
    hooks,
    setRun(r) {
      run = r;
    },
    // Named actions the Creator Tools can call.
    respawn() {
      closePanels();
      buildRun(state);
    },
    resetProgress: () => resetProgress(state),
    travelTo: (i) => travelTo(state, i),
    equipSkin: (i) => equipSkin(state, i),
    assetStatus: () => ({ sheets: Object.keys(loader.sheets), singles: Object.keys(loader.singles), visited: loader.visited() }),
    sceneNodes: () => sceneNodes(state, renderer, hud),
    destroy() {
      destroyed = true;
      ++loadVersion;
      unsubTune();
      audio.destroy();
      input.destroy();
      ro?.disconnect();
      mount.replaceChildren();
    },
    sdk,
    ready,
    tweaks,
    assets,
  };
}
