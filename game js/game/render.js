// Canvas renderer: reads state, draws the world. Never changes state.
import { COLS, ROWS, WORLD, ROPE, tileAt, isSolidTile, TILE } from "./world.js";
import { ledgeDrawPos } from "./player.js";
import { STAG_SCALE, nodePos, weakPos } from "./boss.js";
import { arrowLaunch } from "./combat.js";
import { AREAS, BOSSES, MONSTERS, SKINS } from "./content.js";

const ARCHER_K = 1.8 / 292;

export function createRenderer(canvas, art, terrain) {
  const ctx = canvas.getContext("2d", { alpha: false });
  const S = art.sheets;
  let view = { w: 1, h: 1, dpr: 1, scale: 32 };
  // Effective px per tile this frame (base scale x camera zoom).
  let curScale = 32;
  const glowCache = new Map();
  let vignette, bottomFog, fogBand;

  function texture(width, height, paint) {
    const layer = document.createElement("canvas");
    layer.width = Math.ceil(width); layer.height = Math.ceil(height);
    paint(layer.getContext("2d"));
    return layer;
  }

  function cacheAtmosphere(w, h) {
    // Gradients are soft: cache them once at CSS resolution, then composite.
    vignette = texture(w, h, c => {
      const gradient = c.createRadialGradient(w / 2, h * 0.45, Math.min(w, h) * 0.35, w / 2, h * 0.5, Math.max(w, h) * 0.75);
      gradient.addColorStop(0, "rgba(0,0,0,0)");
      gradient.addColorStop(1, "rgba(3,12,10,0.5)");
      c.fillStyle = gradient; c.fillRect(0, 0, w, h);
    });
    bottomFog = texture(1, 128, c => {
      const gradient = c.createLinearGradient(0, 0, 0, 128);
      gradient.addColorStop(0, "rgba(150,200,190,0)");
      gradient.addColorStop(1, "rgba(150,200,190,1)");
      c.fillStyle = gradient; c.fillRect(0, 0, 1, 128);
    });
    fogBand = texture(1, 120, c => {
      const gradient = c.createLinearGradient(0, 0, 0, 120);
      gradient.addColorStop(0, "rgba(170,230,215,0)");
      gradient.addColorStop(0.5, "rgba(170,230,215,0.07)");
      gradient.addColorStop(1, "rgba(170,230,215,0)");
      c.fillStyle = gradient; c.fillRect(0, 0, 1, 120);
    });
  }

  function resize() {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const dpr = Math.min(window.devicePixelRatio || 1, art.pixelRatioLimit || 2);
    if (view.w === rect.width && view.h === rect.height && view.dpr === dpr) return;
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const scale = Math.max(20, Math.min(54, Math.min(rect.width / 13, rect.height / 16.5)));
    view = { w: rect.width, h: rect.height, dpr, scale };
    cacheAtmosphere(view.w, view.h);
  }

  function camBox(cam) {
    const s = view.scale * (cam.zoom || 1);
    return { left: cam.x - view.w / 2 / s, top: cam.y - (view.h * 0.47) / s };
  }

  // ---- sprite helpers
  function frameOf(sheetKey, anim, i) {
    const list = S[sheetKey].anims[anim];
    return list[Math.max(0, Math.min(list.length - 1, i))];
  }
  // Anchored draw: frame anchor pinned at screen point (sx, sy). k = screen px per sheet px.
  function drawAnchored(sheetKey, f, sx, sy, k, flip = false, alpha = 1) {
    const img = S[sheetKey].img;
    const c = f.content || f.source;
    const a = f.anchor || { x: c.x + c.w / 2, y: c.y + c.h };
    ctx.save();
    if (alpha !== 1) ctx.globalAlpha *= alpha;
    ctx.translate(Math.round(sx), Math.round(sy));
    if (flip) ctx.scale(-1, 1);
    ctx.drawImage(img, c.x, c.y, c.w, c.h, -(a.x - c.x) * k, -(a.y - c.y) * k, c.w * k, c.h * k);
    ctx.restore();
  }
  // Centered draw of a frame's content at (cx, cy) with height hpx.
  function drawCentered(sheetKey, f, cx, cy, k, alpha = 1, rot = 0, flip = false) {
    const img = S[sheetKey].img;
    const c = f.content || f.source;
    ctx.save();
    if (alpha !== 1) ctx.globalAlpha *= alpha;
    ctx.translate(cx, cy);
    if (rot) ctx.rotate(rot);
    if (flip) ctx.scale(-1, 1);
    ctx.drawImage(img, c.x, c.y, c.w, c.h, (-c.w * k) / 2, (-c.h * k) / 2, c.w * k, c.h * k);
    ctx.restore();
  }
  // Cell-relative draw: keeps each frame's offset inside its source cell (for in-place animations).
  function drawInCell(sheetKey, f, ox, oy, k, flipAboutX = null, alpha = 1) {
    const img = S[sheetKey].img;
    const c = f.content || f.source;
    const dx = ox + (c.x - f.source.x) * k;
    const dy = oy + (c.y - f.source.y) * k;
    ctx.save();
    if (alpha !== 1) ctx.globalAlpha *= alpha;
    if (flipAboutX !== null) {
      ctx.translate(flipAboutX, 0);
      ctx.scale(-1, 1);
      ctx.translate(-flipAboutX, 0);
    }
    ctx.drawImage(img, c.x, c.y, c.w, c.h, dx, dy, c.w * k, c.h * k);
    ctx.restore();
  }
  function prop(name) {
    return S.PROPS.frames[name];
  }
  function shotSprite(name) {
    if (S.AREA_SHOTS.frames[name]) return ["AREA_SHOTS", S.AREA_SHOTS.frames[name]];
    if (S.PROPS.frames[name]) return ["PROPS", S.PROPS.frames[name]];
    if (S.AREA_PROPS.frames[name]) return ["AREA_PROPS", S.AREA_PROPS.frames[name]];
    return ["PROPS", S.PROPS.frames.mud_ball];
  }
  function aprop(name) {
    return S.AREA_PROPS.frames[name];
  }
  function glow(x, y, r, color, a = 1) {
    if (r <= 0 || a <= 0 || x + r < 0 || y + r < 0 || x - r > view.w || y - r > view.h) return;
    let sprite = glowCache.get(color);
    if (!sprite) {
      sprite = texture(128, 128, c => {
        const grad = c.createRadialGradient(64, 64, 0, 64, 64, 64);
        grad.addColorStop(0, color.replace("A", "0.55"));
        grad.addColorStop(1, color.replace("A", "0"));
        c.fillStyle = grad; c.fillRect(0, 0, 128, 128);
      });
      glowCache.set(color, sprite);
    }
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.globalAlpha *= a;
    ctx.drawImage(sprite, x - r, y - r, r * 2, r * 2);
    ctx.restore();
  }

  function draw(g, camOverride) {
    const cam = camOverride || g.cam;
    curScale = view.scale * (cam.zoom || 1);
    const { w, h } = view;
    const s = curScale;
    ctx.imageSmoothingEnabled = true;
    const { left, top } = camBox(cam);
    const X = (x) => (x - left) * s;
    const Y = (y) => (y - top) * s;
    const onScreen = (x, y, m = 3) => x > left - m && x < left + w / s + m && y > top - m && y < top + h / s + m;
    const time = g.t;

    drawBackdrop(g, left, top);

    // ---- Decor behind gameplay
    for (const d of g.decor) {
      if (!onScreen(d.x, d.y, 5)) continue;
      const fx = X(d.x + 0.5);
      const fy = Y(d.y + 1);
      if (d.g === "h") {
        const img = art.singles.TREEHOUSE;
        const k = (4.4 * s) / img.naturalWidth;
        ctx.drawImage(img, fx - (img.naturalWidth * k) / 2, fy - img.naturalHeight * k + 0.1 * s, img.naturalWidth * k, img.naturalHeight * k);
        glow(fx - 0.6 * s, fy - 1.6 * s, 2.2 * s, "rgba(255,190,90,A)", 0.45);
      } else if (d.g === "l") {
        const sway = Math.sin(time * 1.3 + d.x) * 0.04;
        ctx.save();
        ctx.translate(fx, Y(d.y));
        ctx.rotate(sway);
        drawAnchored("PROPS", prop("lantern"), 0, s * 1.0, (1.4 * s) / 344);
        ctx.restore();
        glow(fx, Y(d.y) + 0.65 * s, 1.9 * s, "rgba(255,180,80,A)", 0.7 + Math.sin(time * 3 + d.x) * 0.08);
      } else if (d.g === "m") {
        drawAnchored("PROPS", prop("glow_mushrooms"), fx, fy, (1.05 * s) / 282);
        glow(fx, fy - 0.5 * s, 1.4 * s, "rgba(80,255,220,A)", 0.5 + Math.sin(time * 2 + d.x) * 0.15);
      } else if (d.g === "s") {
        drawAnchored("PROPS", prop("sign"), fx, fy, (1.2 * s) / 310);
      }
    }

    // ---- Vines and rope
    for (const v of WORLD.vines) drawVine(v.x, v.y0, v.y1, X, Y, onScreen);
    if (g.progress.rope) drawVine(ROPE.x, ROPE.y0, ROPE.y1, X, Y, onScreen);

    // ---- Terrain
    terrain.draw(ctx, left, top, w, h, s, view.dpr, 2, view.scale);

    // Cracked walls
    for (const c of g.cracks) {
      if (c.broken || !onScreen(c.x, c.y0)) continue;
      const web = g.areaIndex === 6;
      const f = web ? aprop("web_wall") : prop("cracked_wall");
      const hh = c.y1 - c.y0 + 1;
      const k = (hh * s) / f.content.h;
      drawCentered(web ? "AREA_PROPS" : "PROPS", f, X(c.x + 0.5), Y(c.y0 + hh / 2), k);
    }

    // Crystal, ice, sap and ember tiles of the upper areas
    if (g.areaIndex > 0) {
      const x0 = Math.max(0, Math.floor(left) - 1);
      const x1 = Math.min(COLS - 1, Math.ceil(left + w / s) + 1);
      const y0 = Math.max(0, Math.floor(top) - 1);
      const y1 = Math.min(ROWS - 1, Math.ceil(top + h / s) + 1);
      const ember = g.emberOn;
      for (let ty = y0; ty <= y1; ty++)
        for (let tx = x0; tx <= x1; tx++) {
          const t = tileAt(tx, ty);
          if (t === TILE.CRYSTAL || t === TILE.ICE) {
            const f = aprop(t === TILE.CRYSTAL ? "crystal_block" : "ice_block");
            ctx.drawImage(S.AREA_PROPS.img, f.content.x, f.content.y, f.content.w, f.content.h, X(tx) - 0.04 * s, Y(ty) - 0.04 * s, s * 1.08, s * 1.08);
          } else if (t === TILE.SAP && tileAt(tx, ty - 1) !== TILE.SAP) {
            const f = aprop("sap_pool");
            ctx.drawImage(S.AREA_PROPS.img, f.content.x, f.content.y, f.content.w, f.content.h, X(tx) - 0.05 * s, Y(ty) - 0.18 * s, s * 1.1, s * 0.34);
          } else if (t === TILE.EMBER) {
            const warn = !ember && g.emberT > 1.4;
            const f = aprop(ember ? "ember_vent" : "ember_vent_off");
            drawAnchored("AREA_PROPS", f, X(tx + 0.5), Y(ty + 1) + 0.05 * s, ((ember ? 2.2 : 1.1) * s) / f.content.h, false, warn && Math.floor(time * 10) % 2 ? 0.6 : 1);
            if (ember) glow(X(tx + 0.5), Y(ty + 0.3), 1.6 * s, "rgba(255,140,40,A)", 0.8);
          }
        }
      for (const m of g.movers) {
        const name = g.areaIndex === 2 ? "gear_platform" : g.areaIndex === 10 ? "star_platform" : "petal_platform";
        const f = aprop(name);
        const k = ((m.w + 0.3) * s) / f.content.w;
        ctx.drawImage(S.AREA_PROPS.img, f.content.x, f.content.y, f.content.w, f.content.h, X(m.px - 0.15), Y(m.py) - 0.15 * s, f.content.w * k, f.content.h * k);
      }
      for (const v of g.stalactites) {
        if (v.state === "gone" || !onScreen(v.x, v.y)) continue;
        const f = aprop("stalactite");
        const jx = v.state === "shake" ? Math.sin(v.t * 80) * 0.06 * s : 0;
        ctx.drawImage(S.AREA_PROPS.img, f.content.x, f.content.y, f.content.w, f.content.h, X(v.x + 0.2) + jx, Y(v.y), s * 0.6, s * 0.95);
      }
    }
    if (g.gate && onScreen(g.gate.x, g.gate.y)) {
      const f = aprop("gate");
      const alpha = g.gate.active ? 1 : 0.18;
      drawAnchored("AREA_PROPS", f, X(g.gate.x + 0.5), Y(g.gate.y + 1) + 0.05 * s, (2.8 * s) / f.content.h, false, alpha);
      if (g.gate.active) glow(X(g.gate.x + 0.5), Y(g.gate.y - 0.3), 2.2 * s, "rgba(90,255,220,A)", 0.7 + Math.sin(time * 3) * 0.2);
    }

    // Branch platforms
    for (const r of WORLD.runs["="]) if (onScreen(r.x0, r.y, 8)) drawBranch(r.x0, r.x1 + 1, r.y, X, Y);
    if (g.areaIndex === 0 && g.progress.areas[0].boss) for (const n of g.bridge) drawBranch(n.x0, n.x1 + 1, n.y, X, Y, Math.min(1, g.bridgeT * 1.5));

    // Spikes
    const sp = prop("thorn_spikes");
    for (const r of WORLD.runs["^"]) {
      if (!onScreen(r.x0, r.y)) continue;
      for (let x = r.x0; x <= r.x1; x++) drawAnchored("PROPS", sp, X(x + 0.5), Y(r.y + 1) + 0.05 * s, (1.3 * s) / sp.content.w);
    }

    // Wind
    for (const wd of g.winds) {
      if (!onScreen(wd.x0, wd.y0, 20)) continue;
      const warn = !wd.on && wd.t > 1.0;
      const alpha = wd.on ? 0.85 : warn ? (Math.floor(time * 12) % 2 ? 0.45 : 0.2) : 0.1;
      const width = (wd.x1 - wd.x0 + 1) * 1.3;
      const frames = S.WORLD_ANIM.anims.wind_gust;
      const k = (width * s) / 175;
      const segH = 380 * k;
      const cx = X((wd.x0 + wd.x1 + 1) / 2);
      ctx.save();
      ctx.beginPath();
      ctx.rect(cx - width * s, Y(wd.y0) - 0.6 * s, width * 2 * s, Y(wd.y1 + 1) - Y(wd.y0) + 0.6 * s);
      ctx.clip();
      let i = 0;
      for (let yy = Y(wd.y1 + 1); yy > Y(wd.y0) - segH; yy -= segH * 0.82) {
        const f = frames[(Math.floor(time * 10) + i * 2) % frames.length];
        drawAnchored("WORLD_ANIM", f, cx, yy, k, i % 2 === 1, alpha);
        i++;
      }
      ctx.restore();
    }

    // Leaves
    for (const l of g.leaves) {
      if (!onScreen(l.x0, l.y, 6)) continue;
      const n = l.x1 - l.x0 + 1;
      const fr = S.WORLD_ANIM.anims.fold_leaf;
      let i = 0;
      if (l.state === "trem") i = 1 + (Math.floor(l.t * 14) % 2);
      else if (l.state === "fold") i = 3 + Math.min(2, Math.floor((l.t / 0.25) * 3));
      else if (l.state === "closed") i = 5;
      else if (l.state === "opening") i = Math.max(0, 5 - Math.floor((l.t / 0.3) * 6));
      const k = ((n + 0.3) * s) / 382;
      if (Number.isFinite(fr[i].surfaceY)) {
        const f = fr[i], c = f.content;
        ctx.drawImage(S.WORLD_ANIM.img, c.x, c.y, c.w, c.h, X(l.x0 + n / 2) - c.w * k / 2, Y(l.y) - (f.surfaceY - c.y) * k, c.w * k, c.h * k);
      } else drawInCell("WORLD_ANIM", fr[i], X(l.x0 - 0.15) + 28 * k, Y(l.y) - 154 * k, k);
    }

    // Crumbling slabs
    for (const c of g.crumbles) {
      if (c.state === "gone" || !onScreen(c.x0, c.y, 6)) continue;
      const n = c.x1 - c.x0 + 1;
      const fr = S.WORLD_ANIM.anims.crumble_platform;
      let i = 0;
      let jx = 0;
      let alpha = 1;
      if (c.state === "shake") {
        i = c.t > 0.3 ? 1 : 0;
        jx = Math.sin(c.t * 70) * 0.05 * s;
      } else if (c.state === "fall") i = 2 + Math.min(3, Math.floor((c.t / 0.35) * 4));
      else if (c.state === "back") alpha = c.t / 0.4;
      if (g.areaIndex === 7) {
        const f = aprop("cloud_platform");
        const k = ((n + 0.4) * s) / f.content.w;
        const a = c.state === "fall" ? Math.max(0, 1 - c.t / 0.35) : alpha;
        ctx.save();
        ctx.globalAlpha = a;
        ctx.drawImage(S.AREA_PROPS.img, f.content.x, f.content.y, f.content.w, f.content.h, X(c.x0 - 0.2) + jx, Y(c.y) - 0.3 * s, f.content.w * k, f.content.h * k);
        ctx.restore();
        continue;
      }
      const k = ((n + 0.25) * s) / 352;
      if (Number.isFinite(fr[i].surfaceY)) {
        const f = fr[i], box = f.content;
        ctx.save();
        ctx.globalAlpha *= alpha;
        ctx.drawImage(S.WORLD_ANIM.img, box.x, box.y, box.w, box.h, X(c.x0 + n / 2) - box.w * k / 2 + jx,
          Y(c.y) - (f.surfaceY - box.y) * k + (c.state === "fall" ? c.t * c.t * 8 * s : 0), box.w * k, box.h * k);
        ctx.restore();
      } else drawInCell("WORLD_ANIM", fr[i], X(c.x0 - 0.12) + 9 * k + jx, Y(c.y) - 65 * k + (c.state === "fall" ? c.t * c.t * 8 * s : 0), k, null, alpha);
    }

    // Launch flowers
    for (const f of g.flowers) {
      if (!onScreen(f.x, f.y)) continue;
      let i = 0;
      if (f.state === "charge") i = 1 + (f.t > 0.25 ? 1 : 0);
      else if (f.state === "launch") i = Math.min(5, 3 + Math.floor(f.t * 6));
      if (g.areaIndex === 5) {
        const fm = aprop("bounce_mushroom");
        const sq = f.state === "charge" ? 0.75 : f.state === "launch" && f.t < 0.2 ? 1.25 : 1;
        ctx.save();
        ctx.translate(X(f.x + 0.5), Y(f.y + 1));
        ctx.scale(1 / Math.sqrt(sq), sq);
        drawAnchored("AREA_PROPS", fm, 0, 0, (1.2 * s) / fm.content.h);
        ctx.restore();
      } else drawAnchored("WORLD_ANIM", S.WORLD_ANIM.anims.launch_flower[i], X(f.x + 0.5), Y(f.y + 1), (1.5 * s) / 224);
      if (f.state === "charge") glow(X(f.x + 0.5), Y(f.y + 0.4), 1.4 * s, "rgba(120,255,200,A)", f.t * 2);
    }

    // Checkpoints
    for (const k of g.checkpoints) {
      if (!onScreen(k.x, k.y)) continue;
      const lit = g.areaProg.cp === k.id || k.lit;
      const i = lit ? 1 + (Math.floor(k.animT * 8) % 5) : 0;
      drawAnchored("SHRINES", S.SHRINES.anims.checkpoint[i], X(k.x + 0.5), Y(k.y + 1), (1.7 * s) / 304);
      if (lit) glow(X(k.x + 0.5), Y(k.y + 0.3), 2.0 * s, "rgba(90,255,220,A)", 0.8);
    }

    // Bell
    if (g.bell && onScreen(g.bell.x, g.bell.y)) {
      const ring = g.progress.bell || g.bellRing > 0;
      const i = ring ? Math.floor(g.bell.animT * 7) % 6 : 0;
      drawAnchored("SHRINES", S.SHRINES.anims.bell[i], X(g.bell.x + 0.5), Y(g.bell.y + 1), (2.3 * s) / 306);
      if (g.progress.areas[0].boss && !g.progress.bell) glow(X(g.bell.x + 0.5), Y(g.bell.y), 2.4 * s, "rgba(255,220,120,A)", 0.6 + Math.sin(time * 4) * 0.3);
    }

    // Lift stations
    if (g.lift) {
      for (const st of [g.lift.top, g.lift.bottom]) {
        if (!onScreen(st.x, st.y)) continue;
        const f = prop("root_lift");
        const k = (2.4 * s) / f.content.w;
        drawAnchored("PROPS", f, X(st.x + 0.5), Y(st.y + 1) + 0.12 * s, k, false, g.progress.lift ? 1 : 0.55);
        if (g.progress.lift && st.near) drawPrompt(X(st.x + 0.5), Y(st.y - 1.6), st === g.lift.bottom ? "up" : "down");
      }
    }

    // Rope anchor
    if (g.rope && onScreen(g.rope.x, g.rope.y)) {
      const f = S.VINE_TILES.frames.top_cap;
      drawCentered("VINE_TILES", f, X(g.rope.x + 0.5), Y(g.rope.y + 0.4), (0.9 * s) / f.content.h * 1.2, 1, g.progress.rope ? 0 : Math.sin(time * 2) * 0.1);
      if (!g.progress.rope) glow(X(g.rope.x + 0.5), Y(g.rope.y + 0.4), 1.4 * s, "rgba(120,255,200,A)", 0.5 + Math.sin(time * 3) * 0.2);
    }

    // Footings
    const sprout = S.EFFECTS.anims.footing_sprout;
    const last = sprout[5];
    const fk = (2.15 * s) / last.content.w;
    for (const f of g.footings) {
      if (!onScreen(f.x0, f.top)) continue;
      const i = Math.min(5, Math.floor((f.t / 0.22) * 6));
      const wallX = f.wallDir > 0 ? X(f.x1) : X(f.x0);
      const rightRel = last.content.x + last.content.w - last.source.x;
      const ox = wallX - rightRel * fk;
      const oy = Y(f.top) - (last.content.y + 24 - last.source.y) * fk;
      const blink = f.dying ? (Math.floor(f.dying * 16) % 2 ? 0.25 : 1) : 1;
      drawInCell("EFFECTS", sprout[i], ox, oy, fk, f.wallDir > 0 ? null : wallX, blink);
      if (f.t < 0.5) glow(X((f.x0 + f.x1) / 2), Y(f.top), 1.6 * s, "rgba(90,255,210,A)", 1 - f.t * 2);
    }

    // Pickups
    for (const it of g.pickups) {
      if (it.taken || !onScreen(it.x, it.y)) continue;
      const name = { H: "heart_pickup", E: "energy_stone", D: "dash_relic", A: "footing_relic", R: "heart_relic", Y: "golden_feather" }[it.kind];
      const size = it.kind === "H" ? 0.75 : 1.15;
      const f = prop(name);
      const bob = Math.sin(it.t * 3 + it.x) * 0.12;
      const col = it.kind === "H" || it.kind === "R" ? "rgba(255,120,120,A)" : it.kind === "Y" ? "rgba(255,220,90,A)" : "rgba(90,255,220,A)";
      glow(X(it.x + 0.5), Y(it.y + 0.5 + bob), (size + 0.8) * s, col, 0.7);
      drawCentered("PROPS", f, X(it.x + 0.5), Y(it.y + 0.5 + bob), (size * s) / Math.max(f.content.w, f.content.h));
    }

    // Villagers
    for (const v of g.villagers) {
      if (!onScreen(v.x, v.y)) continue;
      const px = g.player.x;
      drawAnchored("PROPS", prop("villager"), X(v.x + 0.5), Y(v.y + 1) + Math.sin(time * 2) * 0.02 * s, (1.85 * s) / 328, px < v.x + 0.5);
    }

    // Enemies
    for (const e of g.enemies) {
      if (!onScreen(e.x, e.y)) continue;
      const flash = e.hurtT > 0 && Math.floor(e.hurtT * 30) % 2 === 0 ? 0.45 : 1;
      if (e.type === "thorn") {
        let anim = "thorn_guard";
        let i = Math.floor(e.animT * 6) % 6;
        if (e.state === "wind") {
          anim = "thorn_guard_attack";
          i = Math.min(2, Math.floor((e.t / 0.62) * 3));
        } else if (e.state === "fire") {
          anim = "thorn_guard_attack";
          i = e.t < 0.6 ? 3 + (Math.floor(e.t * 12) % 2) : 5;
        }
        drawAnchored("ENEMIES_A", frameOf("ENEMIES_A", anim, i), X(e.x), Y(e.y) + 0.06 * s, (1.5 * s) / 273, e.face < 0, flash);
        if (e.state === "wind") glow(X(e.x + e.face * 0.2), Y(e.y - 0.7), 1.2 * s, "rgba(255,60,40,A)", e.t * 1.5);
      } else if (e.type === "beetle") {
        const i = Math.floor(e.animT * 9) % 6;
        drawAnchored("ENEMIES_A", frameOf("ENEMIES_A", "shield_beetle", i), X(e.x), Y(e.y) + 0.04 * s, (1.85 * s) / 290, e.face < 0, flash);
      } else if (e.type === "frog") {
        let anim = "cannon_frog";
        let i = Math.floor(e.animT * 6) % 6;
        if (e.state === "wind") {
          anim = "cannon_frog_attack";
          i = Math.min(2, Math.floor((e.t / 0.72) * 3));
        } else if (e.state === "recover") {
          anim = "cannon_frog_attack";
          i = 3 + Math.min(2, Math.floor(e.t * 6));
        }
        drawAnchored("ENEMIES_B", frameOf("ENEMIES_B", anim, i), X(e.x), Y(e.y) + 0.04 * s, (1.85 * s) / 304, e.face < 0, flash);
        if (e.state === "wind") drawTarget(X(e.tx), Y(e.ty), s, e.t / 0.72);
      } else if (MONSTERS[e.type]) {
        const m = MONSTERS[e.type];
        const sh = S[m.sheet];
        if (!sh) continue;
        const attacking = e.state === "wind" || e.state === "dive" || e.state === "attack" || e.state === "spit" || e.state === "drop" || e.state === "recover" || e.state === "hop";
        const row = attacking ? m.anim + "_attack" : m.anim;
        const list = sh.anims[row] || sh.anims[m.anim];
        let i = Math.floor(e.animT * 9) % list.length;
        if (e.state === "wind") i = Math.min(2, Math.floor((e.t / 0.6) * 3));
        if (m.ai === "dropper") {
          ctx.save();
          ctx.strokeStyle = "rgba(240,240,250,0.7)";
          ctx.lineWidth = Math.max(1, s * 0.04);
          ctx.beginPath();
          ctx.moveTo(X(e.x), Y(e.hy - 3));
          ctx.lineTo(X(e.x), Y(e.y - e.h));
          ctx.stroke();
          ctx.restore();
        }
        const f = list[i] || list[0];
        const ch = (f.content || f.source).h;
        drawAnchored(m.sheet, f, X(e.x), Y(e.y) + (m.fly ? 0 : 0.04 * s), (m.size * s) / Math.max(200, ch), e.face < 0, flash);
        if (e.state === "wind") glow(X(e.x), Y(e.y - e.h / 2), 1.2 * s, "rgba(255,90,60,A)", e.t * 1.6);
      }
      if (e.burnT > 0) glow(X(e.x), Y(e.y - e.h / 2), 0.9 * s, "rgba(255,120,30,A)", 0.7);
      if (e.slowT > 0) glow(X(e.x), Y(e.y - e.h / 2), 0.9 * s, "rgba(120,200,255,A)", 0.6);
    }

    // Boss
    const b = g.boss;
    if (b && !b.generic && b.state !== "gone" && onScreen(b.x, b.y, 10)) {
      let anim = "tower_stag";
      let i = Math.floor(b.animT * 6) % 6;
      if (b.state === "shoot") {
        anim = "tower_stag_shoot";
        const seq = b.t < 0.75 ? [0, 0, 1] : [4, 5, 5];
        i = seq[Math.min(2, Math.floor(((b.t < 0.75 ? b.t / 0.75 : (b.t - 0.75) / 0.6)) * 3))];
      } else if (b.state === "stomp") {
        anim = "tower_stag_stomp";
        i = b.t < 0.62 ? 0 : Math.min(5, 1 + Math.floor((b.t - 0.62) * 9));
      } else if (b.state === "stunned") {
        anim = "tower_stag_stunned";
      }
      const alpha = b.state === "dying" ? 1 - b.fade : b.hurtT > 0 && Math.floor(b.hurtT * 30) % 2 ? 0.5 : 1;
      drawAnchored("BOSS_STAG", frameOf("BOSS_STAG", anim, i), X(b.x), Y(b.y) + 0.05 * s, STAG_SCALE * s, false, alpha);
      if (b.state !== "stunned" && b.state !== "dying") {
        for (let n = 0; n < 3; n++) {
          if (!b.nodes[n]) continue;
          const np = nodePos(b, n);
          const flare = b.state === "shoot" && b.t < 0.75 ? 1.3 : 1;
          glow(X(np.x), Y(np.y), 0.9 * s * flare, "rgba(90,255,210,A)", 0.9 + Math.sin(time * 5 + n) * 0.2);
          ctx.save();
          ctx.strokeStyle = "rgba(220,255,245,0.9)";
          ctx.lineWidth = Math.max(1.5, s * 0.06);
          ctx.beginPath();
          ctx.arc(X(np.x), Y(np.y), s * (0.42 + Math.sin(time * 6 + n) * 0.05), 0, Math.PI * 2);
          ctx.stroke();
          ctx.restore();
        }
      }
      if (b.state === "stunned") {
        const wp = weakPos(b);
        glow(X(wp.x), Y(wp.y), 1.4 * s, "rgba(255,210,80,A)", 0.9 + Math.sin(time * 8) * 0.2);
      }
      if (b.state === "stomp" && b.t < 0.62) glow(X(b.x - 1.8), Y(b.y), 2 * s, "rgba(255,150,60,A)", b.t * 1.4);
    }

    if (b && b.generic && b.state !== "gone" && S[BOSSES[b.area].sheet]) {
      const cfg = BOSSES[b.area];
      const sh = S[cfg.sheet];
      let row = cfg.anim;
      if (b.hurtT > 0.3) row = cfg.anim + "_hurt";
      else if (["spray", "ring", "beam", "summon"].includes(b.state)) row = cfg.anim + "_attack";
      else if (["shock", "charge", "dive", "rain"].includes(b.state)) row = cfg.anim + "_special";
      else if (b.state === "tired") row = cfg.anim + "_hurt";
      const list = sh.anims[row] || sh.anims[cfg.anim];
      const i = Math.floor(b.animT * 7) % list.length;
      let f = list[i];
      // Skip frames whose art came out broken (tiny or wildly oversized).
      if (!f || !f.content || f.content.h < 120 || f.content.w > 460) f = sh.anims[cfg.anim][i % sh.anims[cfg.anim].length];
      const alpha = b.state === "dying" ? 1 - b.fade : b.hurtT > 0 && Math.floor(b.hurtT * 30) % 2 ? 0.55 : 1;
      const k = (cfg.height * s) / 340;
      drawAnchored(cfg.sheet, f, X(b.x), Y(b.y) + 0.05 * s, k, b.face > 0, alpha);
      if (b.tired > 0) glow(X(b.x), Y(b.y - cfg.height * 0.5), 2.4 * s, "rgba(255,230,120,A)", 0.5);
      if (b.state === "charge" && b.t < 0.6) glow(X(b.x), Y(b.y - 1), 2 * s, "rgba(255,120,60,A)", b.t * 1.5);
    }

    // Beams (marked lightning columns) and skill bolts
    for (const bm of g.beams) {
      const x = X(bm.x);
      if (bm.t < bm.warn) {
        const k = Math.max(0, bm.t / bm.warn);
        ctx.fillStyle = `rgba(255,240,120,${0.12 + k * 0.25})`;
        ctx.fillRect(x - 0.45 * s, Y(1), 0.9 * s, Y(12) - Y(1));
      } else drawBolt(x, Y(0.5), x + Math.sin(bm.t * 40) * 6, Y(12), s, 1 - (bm.t - bm.warn) / bm.life);
    }
    for (const bo of g.bolts) drawBolt(X(bo.x0), Y(bo.y0), X(bo.x1), Y(bo.y1), s, 1 - bo.t / bo.dur);

    // Arrows
    for (const a of g.arrows) {
      if (!onScreen(a.x, a.y)) continue;
      const [ash, f] = shotSprite(a.sprite || (a.kind === "footing" ? "footing_arrow" : "arrow"));
      const ang = a.state === "drop" ? a.spin || 0 : Math.atan2(a.vy, a.vx);
      const alpha = a.state === "stuck" ? Math.max(0, 1 - Math.max(0, a.t - 1.0) / 0.4) : 1;
      const k = (1.15 * s) / f.content.w;
      const back = a.state === "stuck" ? 0.25 : 0.4;
      drawCentered(ash, f, X(a.x - Math.cos(ang) * back), Y(a.y - Math.sin(ang) * back), k, alpha, ang);
      if (a.state === "fly" && (a.full || a.kind === "footing")) glow(X(a.x), Y(a.y), 0.7 * s, a.kind === "footing" ? "rgba(90,255,210,A)" : "rgba(255,240,200,A)", 0.6);
    }

    // Player
    drawPlayer(g, X, Y, s);

    // Enemy projectiles
    for (const p of g.eproj) {
      if (!onScreen(p.x, p.y)) continue;
      if (p.kind === "thorn") drawCentered("PROPS", prop("thorn_shot"), X(p.x), Y(p.y), (0.85 * s) / 308, 1, 0, p.vx < 0);
      else if (p.kind === "mud") drawCentered("PROPS", prop("mud_ball"), X(p.x), Y(p.y), (0.6 * s) / 229, 1, p.t * 6);
      else if (p.kind === "seed") {
        glow(X(p.x), Y(p.y), 0.8 * s, "rgba(90,255,200,A)", 0.8);
        drawCentered("PROPS", prop("stag_seed"), X(p.x), Y(p.y), (0.65 * s) / 304, 1, p.t * 5);
      } else if (p.kind === "debris" && p.sprite) {
        const [sk, f] = shotSprite(p.sprite);
        drawCentered(sk, f, X(p.x), Y(p.y), (0.85 * s) / Math.max(f.content.w, f.content.h), 1, p.t * 4);
      } else if (p.kind === "debris") drawCentered("PROPS", prop("mud_ball"), X(p.x), Y(p.y), (0.8 * s) / 229, 1, p.t * 3);
      else if (p.kind === "shot") {
        const [sk, f] = p.sheet ? [p.sheet, S[p.sheet].frames[p.sprite]] : shotSprite(p.sprite);
        const size = p.upright ? 0.95 : 0.7;
        const rot = p.orient ? Math.atan2(p.vy, p.vx) : p.spin ? p.t * 6 : 0;
        if (!p.upright) glow(X(p.x), Y(p.y), 0.7 * s, "rgba(255,230,200,A)", 0.35);
        drawCentered(sk, f, X(p.x), Y(p.y), (size * s) / Math.max(f.content.w, f.content.h), 1, rot);
      }
      else if (p.kind === "shock") {
        const f = S.EFFECTS.anims.dust[Math.floor(p.t * 14) % 3];
        drawAnchored("EFFECTS", f, X(p.x), Y(p.y + 0.4), (1.3 * s) / 270);
        glow(X(p.x), Y(p.y), 1.0 * s, "rgba(255,170,90,A)", 0.6);
      }
    }
    for (const wn of g.warnings) {
      const k = Math.min(1, wn.t / wn.dur);
      ctx.save();
      ctx.fillStyle = `rgba(20,10,5,${0.25 + k * 0.35})`;
      ctx.beginPath();
      ctx.ellipse(X(wn.x + 0.5), Y(12) - 0.05 * s, s * (0.3 + k * 0.4), s * 0.12, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    // Effects
    for (const f of g.fx) {
      if (!onScreen(f.x, f.y)) continue;
      const fr = S.EFFECTS.anims[f.kind];
      // Staggered effects start with a negative t; wait until they begin instead of indexing a frame.
      if (!fr || f.t < 0) continue;
      const i = Math.max(0, Math.min(fr.length - 1, Math.floor((f.t / f.dur) * 6)));
      const base = f.kind === "arrow_hit" ? 0.9 : f.kind === "dust" ? 1.0 : 1.9;
      drawAnchored("EFFECTS", fr[i], X(f.x), Y(f.y) + (f.kind === "arrow_hit" ? 0.45 * s * (f.scale || 1) : 0), ((base * (f.scale || 1)) * s) / 260, f.flip);
    }
    for (const p of g.particles) {
      ctx.globalAlpha = Math.max(0, Math.min(1, p.life / p.max));
      ctx.fillStyle = p.col;
      const sz = Math.max(1.5, p.size * s);
      ctx.fillRect(Math.round(X(p.x) - sz / 2), Math.round(Y(p.y) - sz / 2), sz, sz);
    }
    ctx.globalAlpha = 1;

    drawSpores(g, left, top);

    // Aim trajectory
    const pl = g.player;
    if (pl.aiming && pl.mode === "normal") {
      const power = Math.min(1, pl.aimT / 0.55);
      const l = arrowLaunch(pl, pl.aimX, pl.aimY, power, g.tune);
      const footing = g.progress.abilities.footing && g.arrowType === "footing";
      let x = l.x;
      let y = l.y;
      let vx = l.vx;
      let vy = l.vy;
      ctx.save();
      ctx.fillStyle = footing ? "rgba(120,255,220,0.95)" : power >= 1 ? "rgba(255,236,170,0.95)" : "rgba(255,255,255,0.85)";
      for (let i = 0; i < 26; i++) {
        for (let k = 0; k < 3; k++) {
          vy += l.g * 0.012;
          x += vx * 0.012;
          y += vy * 0.012;
        }
        if (isSolidTile(Math.floor(x), Math.floor(y))) break;
        const r = Math.max(1.5, s * 0.07 * (1 - i / 34));
        ctx.globalAlpha = 1 - i / 30;
        ctx.beginPath();
        ctx.arc(X(x), Y(y), r, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
      // Draw meter ring around the archer.
      ctx.save();
      ctx.strokeStyle = power >= 1 ? "rgba(255,230,140,0.95)" : "rgba(255,255,255,0.55)";
      ctx.lineWidth = Math.max(2, s * 0.07);
      ctx.beginPath();
      ctx.arc(X(pl.x), Y(pl.y - 0.8), s * 1.05, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * power);
      ctx.stroke();
      ctx.restore();
    }

    // Bottom fog + vignette
    const fogDepth = Math.max(0, Math.min(1, (cam.y - 60) / 30));
    ctx.globalAlpha = 0.18 + fogDepth * 0.12;
    ctx.drawImage(bottomFog, 0, h * 0.72, w, h * 0.28);
    ctx.globalAlpha = 1;
    ctx.drawImage(vignette, 0, 0, w, h);

    if (g.slow < 0.95) {
      ctx.fillStyle = `rgba(60,200,190,${(1 - g.slow) * 0.16})`;
      ctx.fillRect(0, 0, w, h);
    }
    if (g.lift && g.lift.ride) {
      const t = g.lift.ride.t;
      const a = t < 0.55 ? t / 0.55 : Math.max(0, 1 - (t - 0.55) / 0.55);
      ctx.fillStyle = `rgba(4,10,8,${a})`;
      ctx.fillRect(0, 0, w, h);
    }
    if (g.player.mode === "dead") {
      ctx.fillStyle = `rgba(4,10,8,${Math.max(0, (g.player.deadT - 0.8) / 0.6)})`;
      ctx.fillRect(0, 0, w, h);
    }
    if (g.tune.showHitboxes) drawHitboxes(g, X, Y, s);
  }

  function drawBackdrop(g, left, top) {
    const { w, h } = view;
    const s = curScale;
    const img = art.singles[AREAS[g.areaIndex].bg] || art.singles.BACKDROP;
    const bw = Math.max(w * 1.12, (h * 0.75 * img.naturalWidth) / img.naturalHeight);
    const bh = (bw * img.naturalHeight) / img.naturalWidth;
    const maxLeft = (COLS * s - w) || 1;
    const ox = -((left * s) / Math.max(1, maxLeft)) * (bw - w);
    const scroll = top * s * 0.22;
    const start = Math.floor(scroll / bh);
    for (let i = start; i * bh - scroll < h; i++) {
      const y = i * bh - scroll;
      ctx.save();
      if (i % 2 !== 0) {
        ctx.translate(0, y + bh);
        ctx.scale(1, -1);
        ctx.drawImage(img, ox, 0, bw, bh);
      } else ctx.drawImage(img, ox, y, bw, bh);
      ctx.restore();
    }
    // Altitude light: warm high up, deep teal below, dark in the cave.
    const depth = Math.max(0, Math.min(1, g.cam.y / ROWS));
    ctx.fillStyle = `rgba(255,214,150,${0.16 * (1 - depth) ** 2})`;
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = `rgba(4,22,20,${0.12 + 0.28 * depth * depth})`;
    ctx.fillRect(0, 0, w, h);
    const caveY = (86 - top) * s;
    if (g.areaIndex === 0 && caveY < h) {
      ctx.fillStyle = "rgba(6,12,14,0.62)";
      ctx.fillRect(0, Math.max(0, caveY), w, h - Math.max(0, caveY));
    }
    // Hollow trunk interior is dimmer.
    const tx0 = (17 - left) * s;
    const tx1 = (23 - left) * s;
    const ty0 = (23 - top) * s;
    const ty1 = (80 - top) * s;
    if (g.areaIndex === 0 && tx1 > 0 && tx0 < w && ty1 > 0 && ty0 < h) {
      ctx.fillStyle = "rgba(10,20,14,0.35)";
      ctx.fillRect(tx0, ty0, tx1 - tx0, ty1 - ty0);
    }
    // Drifting fog bands.
    for (let i = 0; i < 3; i++) {
      const y = ((((g.t * (6 + i * 3) + i * 230 - top * s * (0.35 + i * 0.1)) % (h + 300)) + h + 300) % (h + 300)) - 150;
      ctx.drawImage(fogBand, 0, y - 60, w, 120);
    }
  }

  function drawSpores(g, left, top) {
    const { w, h } = view;
    const s = curScale;
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    for (let i = 0; i < 26; i++) {
      const hx = ((i * 7919) % 1000) / 1000;
      const hy = ((i * 104729) % 1000) / 1000;
      const px = ((hx * w + Math.sin(g.t * 0.4 + i) * 30 - left * s * 0.6) % w + w) % w;
      const py = ((hy * h - g.t * (8 + (i % 5) * 3) - top * s * 0.6) % h + h) % h;
      const a = 0.25 + 0.25 * Math.sin(g.t * 2 + i * 1.7);
      ctx.fillStyle = i % 4 === 0 ? `rgba(255,210,120,${a})` : `rgba(120,255,220,${a})`;
      const sz = Math.max(1.5, s * 0.06);
      ctx.fillRect(Math.round(px), Math.round(py), sz, sz);
    }
    ctx.restore();
  }

  function drawVine(x, y0, y1, X, Y, onScreen) {
    if (!onScreen(x, y0, 30) && !onScreen(x, y1, 30)) {
      // still draw if spanning the screen
    }
    const s = curScale;
    const cap = S.VINE_TILES.frames.top_cap;
    const body = S.VINE_TILES.frames.body;
    const k = (0.8 * s) / body.content.w;
    const cx = X(x + 0.5);
    const img = S.VINE_TILES.img;
    const segH = body.content.h * k;
    let yy = Y(y0) + 0.6 * s;
    const end = Y(y1 + 1);
    while (yy < end) {
      const hpx = Math.min(segH, end - yy);
      if (yy + hpx > -10 && yy < view.h + 10) ctx.drawImage(img, body.content.x, body.content.y, body.content.w, hpx / k, cx - (body.content.w * k) / 2, yy, body.content.w * k, hpx);
      yy += segH - 1;
    }
    const ck = (0.8 * s) / body.content.w;
    ctx.drawImage(img, cap.content.x, cap.content.y, cap.content.w, cap.content.h, cx - (cap.content.w * ck) / 2, Y(y0) - 0.4 * s, cap.content.w * ck, cap.content.h * ck);
  }

  function drawBranch(x0, x1, y, X, Y, alpha = 1) {
    const s = curScale;
    const L = S.BRANCH_TILES.frames.left;
    const C = S.BRANCH_TILES.frames.center;
    const R = S.BRANCH_TILES.frames.right;
    const img = S.BRANCH_TILES.img;
    const k = s / 224; // one tile = 224 sheet px
    const surf = L.surfaceY;
    const top = Y(y);
    ctx.save();
    ctx.globalAlpha *= alpha;
    const drawPiece = (f, dx, srcX, srcW) => {
      const c = f.content;
      ctx.drawImage(img, srcX, c.y, srcW, c.h, dx, top - (surf - c.y) * k, srcW * k + 0.5, c.h * k);
    };
    drawPiece(L, X(x0) + (L.content.x - L.source.x) * k, L.content.x, L.content.w);
    let cx = x0 + 1;
    const right = x1 - 1;
    while (cx < right) {
      const tiles = Math.min(3, right - cx);
      drawPiece(C, X(cx), C.content.x, tiles * 224);
      cx += tiles;
    }
    drawPiece(R, X(Math.max(x0 + 1, x1 - 1)) + (R.content.x - R.source.x) * k, R.content.x, R.content.w);
    ctx.restore();
  }

  function drawPlayer(g, X, Y, s) {
    const p = g.player;
    if (p.mode === "lift" && g.lift?.ride && g.lift.ride.t > 0.4 && g.lift.ride.t < 0.7) return;
    if (p.invuln > 0 && p.mode !== "dead" && Math.floor(p.invuln * 14) % 2 === 0) return;
    let sheet = "ARCHER_A";
    let anim = p.anim;
    let i = 0;
    let px = p.x;
    let py = p.y;
    switch (p.anim) {
      case "idle": i = Math.floor(p.animT * 7) % 6; break;
      case "run": i = Math.floor(p.animT * 13) % 6; break;
      case "jump": i = Math.min(3, 1 + Math.floor(p.animT * 12)); break;
      case "fall": i = Math.floor(p.animT * 10) % 6; break;
      case "dash": sheet = "ARCHER_B"; i = Math.min(5, Math.floor((1 - p.dashT / 0.22) * 6)); break;
      case "climb": sheet = "ARCHER_B"; i = Math.floor((p.climbT || 0) * 9) % 6; break;
      case "aim": sheet = "ARCHER_B"; i = Math.min(3, Math.floor((p.aimT / 0.55) * 4)); break;
      case "release": sheet = "ARCHER_B"; anim = "aim"; i = p.releaseT > 0.08 ? 4 : 5; break;
      case "hurt": sheet = "ARCHER_B"; i = Math.min(5, Math.floor(p.animT * 16)); break;
      case "ledge_climb": {
        if (!p.ledge) { anim = "idle"; break; }
        sheet = "ARCHER_C";
        const pos = ledgeDrawPos(p);
        px = pos.x;
        py = pos.y;
        i = Math.min(5, Math.floor((p.ledge.t / 0.42) * 6));
        break;
      }
      case "wall_slide": sheet = "ARCHER_C"; i = Math.floor(p.animT * 10) % 6; break;
      case "land": sheet = "ARCHER_C"; i = Math.min(2, Math.floor((1 - p.landT / 0.16) * 3)); break;
      case "defeat": sheet = "ARCHER_C"; i = Math.min(5, Math.floor(p.deadT * 5)); break;
      default: anim = "idle";
    }
    if (p.mode === "lift" && g.lift?.ride) {
      const t = g.lift.ride.t;
      py -= (t < 0.55 ? t : 1.1 - t) * 1.2;
    }
    const skin = SKINS[g.progress.skin] || SKINS[0];
    const skinSheet = { ARCHER_A: skin.sheets[0], ARCHER_B: skin.sheets[1], ARCHER_C: skin.sheets[2] }[sheet];
    if (skinSheet && S[skinSheet] && S[skinSheet].anims[anim]) sheet = skinSheet;
    const f = frameOf(sheet, anim, i);
    if (g.cloneT > 0) drawAnchored(sheet, f, X(px), Y(py - 1.6), ARCHER_K * s, p.face < 0, 0.4);
    if (g.progress.feather) glow(X(px), Y(py - 0.8), 1.2 * s, "rgba(255,215,90,A)", 0.35);
    drawAnchored(sheet, f, X(px), Y(py) + 0.04 * s, ARCHER_K * s, p.face < 0);
  }

  function drawBolt(x0, y0, x1, y1, s, a) {
    if (a <= 0) return;
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    const segs = 9;
    for (let pass = 0; pass < 2; pass++) {
      ctx.strokeStyle = pass === 0 ? `rgba(255,230,120,${0.5 * a})` : `rgba(255,255,255,${a})`;
      ctx.lineWidth = Math.max(1.5, s * (pass === 0 ? 0.22 : 0.08));
      ctx.beginPath();
      ctx.moveTo(x0, y0);
      for (let i = 1; i < segs; i++) {
        const t = i / segs;
        const jit = Math.sin(i * 12.7 + x0 * 0.13 + y1) * s * 0.35;
        ctx.lineTo(x0 + (x1 - x0) * t + jit, y0 + (y1 - y0) * t);
      }
      ctx.lineTo(x1, y1);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawTarget(x, y, s, k) {
    ctx.save();
    ctx.strokeStyle = `rgba(255,140,60,${0.4 + k * 0.5})`;
    ctx.lineWidth = Math.max(2, s * 0.07);
    ctx.beginPath();
    ctx.ellipse(x, y - 0.05 * s, s * (0.9 - k * 0.35), s * 0.22, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  function drawPrompt(x, y, dir) {
    const s = curScale;
    ctx.save();
    ctx.fillStyle = "rgba(10,24,20,0.75)";
    ctx.beginPath();
    ctx.arc(x, y, s * 0.42, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#bfffe9";
    ctx.lineWidth = Math.max(2, s * 0.08);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    const d = dir === "up" ? -1 : 1;
    ctx.beginPath();
    ctx.moveTo(x - s * 0.18, y - d * s * 0.06 * -1 + d * s * 0.08);
    ctx.lineTo(x, y - d * s * 0.12);
    ctx.lineTo(x + s * 0.18, y + d * s * 0.08);
    ctx.stroke();
    ctx.restore();
  }

  function drawHitboxes(g, X, Y, s) {
    ctx.save();
    ctx.strokeStyle = "#ff3";
    ctx.lineWidth = 1;
    const p = g.player;
    ctx.strokeRect(X(p.x - p.w / 2), Y(p.y - p.h), p.w * s, p.h * s);
    ctx.strokeStyle = "#f55";
    for (const e of g.enemies) ctx.strokeRect(X(e.x - e.w / 2), Y(e.y - e.h), e.w * s, e.h * s);
    ctx.strokeStyle = "#5ff";
    for (const pl of g.platforms) ctx.strokeRect(X(pl.x0), Y(pl.top), (pl.x1 - pl.x0) * s, 2);
    ctx.restore();
  }

  return {
    resize,
    draw,
    get view() {
      return view;
    },
    camBox,
    tileSize: () => view.scale,
  };
}

export { tileAt, TILE };
