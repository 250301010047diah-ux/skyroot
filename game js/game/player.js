// The archer: movement, climbing, ledge grabs, wall jumps, dash, and the bow.
import { moveBody, groundUnder, overlapsSolid, overlapsTile } from "./physics.js";
import { isSolidTile, isVine, tileAt, TILE } from "./world.js";

export const PLAYER_W = 0.6;
export const PLAYER_H = 1.45;
export const GRAVITY = 75;
const MAX_FALL = 22;
const LEDGE_TIME = 0.42;
const DASH_TIME = 0.22;

export function createPlayer(x, y, progress) {
  return {
    x, y, vx: 0, vy: 0, w: PLAYER_W, h: PLAYER_H,
    face: 1, mode: "normal", onGround: false, groundId: null, groundIsTile: false,
    coyote: 0, jumpBuffer: 0, jumpCut: false, jumping: false,
    hp: progress.maxHp, energy: progress.maxEnergy,
    invuln: 0, hurtT: 0, deadT: 0, dashT: 0, dashCD: 0, airDash: true, airDashLeft: 1, airJumps: 0, freezeT: 0,
    wallSlide: 0, wallLock: 0, ledge: null, dropT: 0, landT: 0, fallPeak: 0,
    climbX: null, climbCooldown: 0,
    aiming: false, aimT: 0, aimX: 1, aimY: 0, releaseT: 0, focus: 1.6,
    anim: "idle", animT: 0, safeX: x, safeY: y, safeT: 0, regenT: 0, idleT: 0,
  };
}

// tune: { runSpeed, jumpV, gravity, skin } assembled each frame by game.js.
export function updatePlayer(g, p, inp, dt, tune) {
  const G = GRAVITY * (tune.gravity || 1);
  const skin = tune.skin;
  p.freezeT = Math.max(0, (p.freezeT || 0) - dt);
  p.animT += dt;
  p.invuln = Math.max(0, p.invuln - dt);
  p.dashCD = Math.max(0, p.dashCD - dt);
  p.wallLock = Math.max(0, p.wallLock - dt);
  p.climbCooldown = Math.max(0, (p.climbCooldown || 0) - dt);
  p.dropT = Math.max(0, p.dropT - dt);
  p.landT = Math.max(0, p.landT - dt);
  p.releaseT = Math.max(0, p.releaseT - dt);
  if (inp.jumpPressed) p.jumpBuffer = 0.13;
  else p.jumpBuffer = Math.max(0, p.jumpBuffer - dt);

  if (p.mode === "dead" || p.mode === "lift") return;
  const platforms = g.platforms;

  if (p.mode === "hurt") {
    p.hurtT -= dt;
    p.vy = Math.min(MAX_FALL, p.vy + G * dt);
    p.vx *= Math.pow(0.02, dt);
    const r = moveBody(p, p.vx * dt, p.vy * dt, platforms);
    if (r.landed) p.vy = 0;
    if (r.hitUp) p.vy = 0;
    if (p.hurtT <= 0) p.mode = "normal";
    setAnim(p, "hurt");
    return;
  }

  if (p.mode === "ledge") {
    p.ledge.t += dt;
    if (p.ledge.t >= LEDGE_TIME) {
      p.x = p.ledge.fx;
      p.y = p.ledge.fy;
      p.vx = 0;
      p.vy = 0;
      p.mode = "normal";
      p.onGround = true;
      p.ledge = null;
      p.landT = 0.16;
      setAnim(p, "land");
      return;
    }
    setAnim(p, "ledge_climb");
    return;
  }

  const mx = Math.abs(inp.mx) > 0.25 ? inp.mx : 0;
  const my = inp.my;

  // ---- Climbing vines
  if (p.mode === "climb") {
    const cx = p.climbX ?? Math.floor(p.x);
    p.x += (cx + 0.5 - p.x) * Math.min(1, dt * 14);
    p.vx = 0;
    p.vy = Math.abs(my) > 0.3 ? Math.sign(my) * 4.6 : 0;
    const midRow = Math.floor(p.y - p.h * 0.55);
    if (p.vy < 0 && !isVine(cx, Math.floor(p.y - p.h - 0.05)) && !isVine(cx, midRow - 1)) {
      // Top of the vine: hop off upward.
      p.mode = "normal";
      p.vy = -17;
      p.onGround = false;
      p.jumping = false;
      p.climbCooldown = 0.3;
      setAnim(p, "jump");
      return;
    } else if (inp.jumpPressed) {
      p.mode = "normal";
      p.vy = -17;
      p.vx = mx * 6;
      p.jumpBuffer = 0;
      p.climbCooldown = 0.3;
      p.onGround = false;
      p.jumping = true;
      p.jumpCut = false;
      setAnim(p, "jump");
      return;
    } else if (Math.abs(mx) > 0.75 && Math.abs(my) < 0.35) {
      p.mode = "normal";
      p.vx = mx * 4;
      p.climbCooldown = 0.3;
      setAnim(p, "fall");
      return;
    } else {
      const r = moveBody(p, 0, p.vy * dt, platforms, true);
      if (r.landed && p.vy > 0) p.mode = "normal";
      if (!isVine(cx, Math.floor(p.y - p.h + 0.05)) && !isVine(cx, midRow) && !isVine(cx, Math.floor(p.y - 0.2))) p.mode = "normal";
    }
    p.airDash = true;
    p.airDashLeft = skin ? skin.airDashes : 1;
    p.focus = 1.6 * (skin ? skin.focus : 1);
    if (p.vy !== 0) p.climbT = (p.climbT || 0) + dt;
    setAnim(p, "climb");
    return;
  }

  // ---- Dash
  if (p.mode === "dash") {
    p.dashT -= dt;
    p.vy = 0;
    const r = moveBody(p, p.vx * dt, 0, platforms);
    if (r.hitX || p.dashT <= 0) {
      p.mode = "normal";
      p.vx = p.face * 7;
    }
    setAnim(p, "dash");
    return;
  }

  // ---- Normal movement
  const under = p.onGround ? tileAt(Math.floor(p.x), Math.round(p.y)) : TILE.EMPTY;
  const onSap = under === TILE.SAP;
  const onIce = under === TILE.ICE;
  const aimSlow = p.aiming && p.onGround ? 0.35 : 1;
  const slowMul = (onSap ? 0.5 : 1) * (p.freezeT > 0 ? 0.55 : 1);
  const target = mx * tune.runSpeed * aimSlow * slowMul;
  if (p.wallLock <= 0) {
    const accel = p.onGround ? (onIce ? 9 : 70) : 42;
    const dv = target - p.vx;
    p.vx += Math.sign(dv) * Math.min(Math.abs(dv), accel * dt);
  }
  if (mx !== 0 && !p.aiming) p.face = mx > 0 ? 1 : -1;

  // Grab a vine.
  const cx = Math.floor(p.x);
  const vineX = p.climbCooldown <= 0 ? reachableVine(p) : null;
  if (vineX !== null) {
    if (my < -0.5 || (my > 0.5 && !p.onGround)) {
      p.mode = "climb";
      p.climbX = vineX;
      p.onGround = false;
      p.vx = 0;
      p.vy = 0;
      p.aiming = false;
      setAnim(p, "climb");
      return;
    }
  }
  // Drop through a vine top / one-way branch.
  if (p.onGround && my > 0.6 && !p.groundIsTileSolid) {
    p.dropT = 0.22;
    p.onGround = false;
    p.y += 0.05;
    if (isVine(cx, Math.floor(p.y + 0.3))) {
      p.mode = "climb";
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
    g.events.push({ type: "jump", x: p.x, y: p.y });
  } else if (p.jumpBuffer > 0 && p.wallSlide !== 0) {
    p.vy = -19;
    p.vx = -p.wallSlide * 6.5;
    p.face = -p.wallSlide;
    p.wallLock = 0.13;
    p.jumpBuffer = 0;
    p.jumping = true;
    p.jumpCut = false;
    p.wallSlide = 0;
    g.events.push({ type: "walljump", x: p.x, y: p.y });
  } else if (p.jumpBuffer > 0 && !p.onGround && p.airJumps > 0) {
    p.vy = -tune.jumpV * 0.92;
    p.airJumps--;
    p.jumpBuffer = 0;
    p.jumping = true;
    p.jumpCut = false;
    g.events.push({ type: "doublejump", x: p.x, y: p.y });
  }
  if (p.jumping && !inp.jumpHeld && p.vy < -4 && !p.jumpCut) {
    p.vy *= 0.45;
    p.jumpCut = true;
  }

  // Dash
  if (inp.dashPressed && g.progress.abilities.dash && p.dashCD <= 0 && (p.onGround || p.airDashLeft > 0)) {
    if (mx !== 0) p.face = mx > 0 ? 1 : -1;
    p.mode = "dash";
    p.dashT = DASH_TIME;
    p.dashCD = 0.42;
    p.vx = p.face * 19;
    p.vy = 0;
    if (!p.onGround) p.airDashLeft--;
    p.aiming = false;
    g.events.push({ type: "dash", x: p.x, y: p.y });
    return;
  }

  // Gravity, wall slide
  p.vy = Math.min(MAX_FALL, p.vy + G * dt);
  p.wallSlide = 0;
  if (!p.onGround && p.vy > 0 && mx !== 0) {
    const dir = mx > 0 ? 1 : -1;
    const wx = Math.floor(dir > 0 ? p.x + p.w / 2 + 0.06 : p.x - p.w / 2 - 0.06);
    const r0 = Math.floor(p.y - p.h + 0.2);
    const r1 = Math.floor(p.y - 0.2);
    let moss = false;
    for (let r = r0; r <= r1; r++) if (tileAt(wx, r) === TILE.MOSS) moss = true;
    if (moss) {
      p.wallSlide = dir;
      p.vy = Math.min(p.vy, 3.2);
      p.face = dir;
    }
  }

  const wasGround = p.onGround;
  const prevVy = p.vy;
  const res = moveBody(p, p.vx * dt, p.vy * dt, platforms, p.dropT > 0);
  if (res.hitX) p.vx = 0;
  if (res.hitUp) p.vy = Math.max(p.vy, 0);
  if (res.landed) {
    if (prevVy > 15) {
      p.landT = 0.16;
      g.events.push({ type: "land", x: p.x, y: p.y, hard: true });
    } else if (!wasGround && prevVy > 4) g.events.push({ type: "land", x: p.x, y: p.y });
    p.vy = 0;
  }
  const ground = p.vy >= 0 ? groundUnder(p, platforms) : null;
  p.onGround = !!ground && p.dropT <= 0 ? true : !!ground && res.landed;
  if (ground && p.dropT > 0 && !res.landed) p.onGround = false;
  p.groundId = ground ? ground.id : null;
  p.groundIsTileSolid = !!ground && ground.tile && isSolidTile(Math.floor(p.x), Math.round(p.y));
  if (p.onGround) {
    p.coyote = 0.1;
    p.airDash = true;
    p.airDashLeft = skin ? skin.airDashes : 1;
    p.airJumps = skin && skin.doubleJump ? 1 : 0;
    p.jumping = false;
    p.focus = Math.min(1.6 * (skin ? skin.focus : 1), p.focus + dt * 3);
  } else p.coyote = Math.max(0, p.coyote - dt);

  // Ledge grab: automatic when a jump nearly makes it.
  if (!p.onGround && p.vy > -6 && p.wallLock <= 0) tryLedge(g, p, mx);

  // Remember safe ground for hazard respawns.
  p.safeT -= dt;
  if (p.onGround && p.groundId === null && p.safeT <= 0 && !overlapsTile({ ...p, w: 2.2, h: 1.6 }, TILE.SPIKE)) {
    p.safeX = p.x;
    p.safeY = p.y;
    p.safeT = 0.25;
  }

  // Animation choice
  if (p.aiming) setAnim(p, "aim");
  else if (p.releaseT > 0) setAnim(p, "release");
  else if (p.wallSlide) setAnim(p, "wall_slide");
  else if (!p.onGround) setAnim(p, p.vy < -2 ? "jump" : "fall");
  else if (p.landT > 0) setAnim(p, "land");
  else if (Math.abs(p.vx) > 0.6) setAnim(p, "run");
  else setAnim(p, "idle");
}

// Reach a visible vine with the head/body, including its hanging lower tip.
// The small horizontal tolerance matches the art without grabbing through walls.
function reachableVine(p) {
  const rows = [Math.floor(p.y - p.h + 0.05), Math.floor(p.y - p.h * 0.55), Math.floor(p.y - 0.3)];
  const center = Math.floor(p.x);
  for (const col of [center, center - 1, center + 1]) {
    if (Math.abs(p.x - (col + 0.5)) > 0.7) continue;
    if (rows.some(row => isVine(col, row)) && !overlapsSolid(col + 0.5, p.y, p.w, p.h)) return col;
  }
  return null;
}

function tryLedge(g, p, mx) {
  const dir = mx !== 0 ? (mx > 0 ? 1 : -1) : 0;
  if (!dir) return;
  const col = Math.floor(dir > 0 ? p.x + p.w / 2 + 0.12 : p.x - p.w / 2 - 0.12);
  const top = p.y - p.h;
  const r = Math.round(top + 0.15);
  if (Math.abs(top - r) > 0.5) return;
  if (!isSolidTile(col, r) || isSolidTile(col, r - 1) || isSolidTile(col, r - 2)) return;
  const fx = dir > 0 ? col + 0.42 : col + 0.58;
  const fy = r;
  if (overlapsSolid(fx, fy, p.w, p.h)) return;
  // Column the player occupies must be open above the ledge too.
  if (isSolidTile(Math.floor(p.x), r - 1)) return;
  p.mode = "ledge";
  p.face = dir;
  p.vx = 0;
  p.vy = 0;
  p.aiming = false;
  p.ledge = { t: 0, sx: dir > 0 ? col - p.w / 2 - 0.02 : col + 1 + p.w / 2 + 0.02, sy: r + p.h - 0.1, fx, fy };
  p.x = p.ledge.sx;
  p.y = p.ledge.sy;
  g.events.push({ type: "ledge", x: p.x, y: p.y });
}

export function ledgeDrawPos(p) {
  const L = p.ledge;
  if (!L) return { x: p.x, y: p.y, e: 1 };
  const k = Math.min(1, L.t / LEDGE_TIME);
  const e = k * k * (3 - 2 * k);
  const yk = Math.min(1, k * 1.35);
  return { x: L.sx + (L.fx - L.sx) * Math.max(0, (k - 0.45) / 0.55), y: L.sy + (L.fy - L.sy) * (yk * yk * (3 - 2 * yk)), e };
}

function setAnim(p, name) {
  if (p.anim !== name) {
    p.anim = name;
    p.animT = 0;
  }
}

export function hurtPlayer(g, p, dmg, fromX) {
  if (p.invuln > 0 || p.mode === "dead" || p.mode === "lift") return false;
  p.hp -= dmg;
  p.invuln = 1.2;
  p.aiming = false;
  g.events.push({ type: "hurt", x: p.x, y: p.y });
  if (p.hp <= 0) {
    p.hp = 0;
    p.mode = "dead";
    p.deadT = 0;
    p.anim = "defeat";
    p.animT = 0;
    p.vx = 0;
    p.vy = 0;
    return true;
  }
  if (p.mode === "climb" || p.mode === "ledge") p.mode = "normal";
  p.ledge = null;
  p.mode = "hurt";
  setAnim(p, "hurt");
  p.hurtT = 0.32;
  const dir = fromX === undefined ? -p.face : p.x >= fromX ? 1 : -1;
  p.vx = dir * 7;
  p.vy = -9;
  return true;
}
