// DOM layer: HUD, touch controls, toasts, speech bubble, boss bar, map and end panels.
import { COLS, ROWS, tileAt, TILE } from "./world.js";
import { EXPLORE_BLOCK, secretsFound, skinOwned, skinsOwned, TOTAL_SECRETS } from "./save.js";
import { AREAS, BOSSES, SKINS, SKILL_NAMES } from "./content.js";

const ICON = {
  heart: '<path d="M12 20.5s-7.5-4.6-7.5-10.4A4.3 4.3 0 0 1 12 7.4a4.3 4.3 0 0 1 7.5 2.7c0 5.8-7.5 10.4-7.5 10.4z"/>',
  energy: '<path d="M12 3.5 18 12l-6 8.5L6 12z"/>',
  map: '<path d="M3.5 6.5 9 4.5l6 2 5.5-2v13l-5.5 2-6-2-5.5 2z"/><path d="M9 4.5v13M15 6.5v13"/>',
  jump: '<path d="M6 13.5 12 7.5l6 6"/><path d="M6 19l6-6 6 6"/>',
  dash: '<path d="M3.5 12H14"/><path d="M10 6.5 15.5 12 10 17.5"/><path d="M19.5 6v12"/>',
  bow: '<path d="M7.5 3.5c6 3.2 6 13.8 0 17"/><path d="M7.5 3.5v17"/><path d="M4 12h15"/><path d="M16 9l3 3-3 3"/>',
  arrow: '<path d="M5 19 17.5 6.5"/><path d="M12.5 6.5h5v5"/><path d="M5 19l-1-3M5 19l3 1"/>',
  leaf: '<path d="M5 19 13 11"/><path d="M13 11c0-4 3-6.5 7-7-.5 4-3 7-7 7z"/><path d="M5 19l-1-3M5 19l3 1"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  wardrobe: '<path d="M9 4.5a3 3 0 0 0 6 0"/><path d="M9 4.5 4 7.5l1.8 4 2.2-1V20h8v-9.5l2.2 1 1.8-4-5-3"/>',
  skill: '<path d="M12 3.5 14.4 9l5.6.5-4.3 3.7 1.3 5.6L12 15.9 7 18.8l1.3-5.6L4 9.5 9.6 9z"/>',
};

function svg(name, cls = "") {
  return `<svg class="ico ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICON[name]}</svg>`;
}

// Tile colours on the map, kept close to the in-world palette.
const MAP_COLOR = {
  [TILE.BARK]: "#7a5232", [TILE.SOFT]: "#c9a06a", [TILE.MOSS]: "#6f9a3c", [TILE.ONEWAY]: "#b5d05e",
  [TILE.VINE]: "#4fa372", [TILE.WIND]: "#4a9c96", [TILE.SPIKE]: "#d0503e", [TILE.SAP]: "#d9a441",
  [TILE.CRYSTAL]: "#8f7ad8", [TILE.ICE]: "#9fd8f0", [TILE.EMBER]: "#e0743a",
};

export function createHud(mount) {
  const root = document.createElement("div");
  root.className = "game-root";
  root.innerHTML = `
    <canvas class="game-surface"></canvas>
    <div class="hud">
      <div class="hud-cluster hud-left">
        <div class="pip-row hearts"></div>
        <div class="pip-row energy" hidden></div>
      </div>
      <div class="hud-actions">
        <button class="icon-btn wardrobe-btn" aria-label="Lemari Skin" hidden>${svg("wardrobe")}</button>
        <button class="icon-btn map-btn" aria-label="Peta">${svg("map")}</button>
      </div>
    </div>
    <div class="boss-bar" hidden><span class="boss-name">Rusa Menara</span><div class="boss-track"><div class="boss-fill"></div></div></div>
    <div class="toast" hidden></div>
    <div class="speech" hidden></div>
    <div class="controls">
      <div class="joy-zone"><div class="joy"><div class="joy-knob"></div></div></div>
      <div class="action-cluster">
        <button class="act act-swap" aria-label="Ganti panah" hidden>${svg("arrow", "i-arrow")}${svg("leaf", "i-leaf")}</button>
        <button class="act act-dash" aria-label="Dash" hidden>${svg("dash")}</button>
        <button class="act act-jump" aria-label="Lompat">${svg("jump")}</button>
        <button class="act act-bow" aria-label="Busur">${svg("bow")}</button>
        <button class="act act-skill" aria-label="Skill" hidden>${svg("skill")}<span class="skill-cd"></span></button>
      </div>
    </div>
    <div class="overlay map-panel" hidden>
      <div class="panel map-sheet">
        <div class="panel-head"><span class="panel-title">Akar Berkabut</span><button class="icon-btn map-close" aria-label="Tutup">${svg("close")}</button></div>
        <div class="area-chips"></div>
        <div class="map-frame"><canvas class="map-canvas"></canvas></div>
        <div class="map-legend">
          <span><i class="lg lg-you"></i>Kamu</span>
          <span><i class="lg lg-cp"></i>Checkpoint</span>
          <span><i class="lg lg-gate"></i>Gerbang</span>
          <span><i class="lg lg-bell"></i>Lonceng</span>
        </div>
        <div class="panel-stats"></div>
        <button class="text-btn control-btn reset-btn"><span class="control-label">Mulai dari awal</span></button>
      </div>
    </div>
    <div class="overlay wardrobe-panel" hidden>
      <div class="panel wide">
        <div class="panel-head"><span class="panel-title">Lemari Skin</span><button class="icon-btn wardrobe-close" aria-label="Tutup">${svg("close")}</button></div>
        <div class="skin-grid"></div>
        <div class="skin-detail"></div>
      </div>
    </div>
    <div class="overlay end-panel" hidden>
      <div class="panel">
        <div class="end-title">Kabut Sirna</div>
        <div class="end-sub">Mahkota Langit kembali bersinar di atas pohon.</div>
        <div class="end-stats"></div>
        <button class="text-btn control-btn primary end-continue"><span class="control-label">Jelajah lagi</span></button>
        <button class="text-btn control-btn end-reset"><span class="control-label">Main dari awal</span></button>
      </div>
    </div>
    <div class="overlay loading">
      <div class="loading-box"><div class="loading-title">Skyroot</div><div class="loading-track"><div class="loading-fill"></div></div><div class="loading-msg">Menyiapkan hutan…</div></div>
    </div>
  `;
  mount.replaceChildren(root);
  const $ = (s) => root.querySelector(s);
  const el = {
    root,
    canvas: $(".game-surface"),
    hearts: $(".hearts"),
    energy: $(".energy"),
    mapBtn: $(".map-btn"),
    bossBar: $(".boss-bar"),
    bossName: $(".boss-name"),
    wardrobeBtn: $(".wardrobe-btn"),
    skill: $(".act-skill"),
    skillCd: $(".skill-cd"),
    areaChips: $(".area-chips"),
    wardrobePanel: $(".wardrobe-panel"),
    wardrobeClose: $(".wardrobe-close"),
    skinGrid: $(".skin-grid"),
    skinDetail: $(".skin-detail"),
    bossFill: $(".boss-fill"),
    toast: $(".toast"),
    speech: $(".speech"),
    joyZone: $(".joy-zone"),
    joy: $(".joy"),
    knob: $(".joy-knob"),
    swap: $(".act-swap"),
    dash: $(".act-dash"),
    jump: $(".act-jump"),
    bow: $(".act-bow"),
    mapPanel: $(".map-panel"),
    mapCanvas: $(".map-canvas"),
    mapClose: $(".map-close"),
    mapStats: $(".panel-stats"),
    resetBtn: $(".reset-btn"),
    endPanel: $(".end-panel"),
    endStats: $(".end-stats"),
    endContinue: $(".end-continue"),
    endReset: $(".end-reset"),
    loading: $(".loading"),
    loadingFill: $(".loading-fill"),
    loadingMsg: $(".loading-msg"),
  };

  let last = {};
  function setPips(container, count, filled, cls, icon) {
    const key = cls + count + ":" + filled;
    if (last[cls] === key) return;
    last[cls] = key;
    let html = "";
    if (count > 8) {
      // Long rows collapse into one pip and a counter so the HUD never overflows.
      html = `<span class="pip ${cls} on">${svg(icon)}</span><span class="pip-count">${filled}/${count}</span>`;
    } else for (let i = 0; i < count; i++) html += `<span class="pip ${cls} ${i < filled ? "on" : "off"}">${svg(icon)}</span>`;
    container.innerHTML = html;
  }

  function update(g, screen) {
    const p = g.player;
    setPips(el.hearts, g.maxHp, Math.ceil(p.hp), "heart", "heart");
    el.energy.hidden = !g.progress.abilities.footing;
    if (g.progress.abilities.footing) setPips(el.energy, g.maxEnergy, Math.floor(p.energy + 0.001), "energy", "energy");
    el.swap.hidden = !g.progress.abilities.footing;
    el.dash.hidden = !g.progress.abilities.dash;
    el.swap.classList.toggle("footing", g.arrowType === "footing");
    el.bow.classList.toggle("footing", g.arrowType === "footing" && g.progress.abilities.footing);
    el.bow.classList.toggle("held", p.aiming);

    const skin = SKINS[g.progress.skin] || SKINS[0];
    el.skill.hidden = !skin.skill;
    if (skin.skill) {
      const k = Math.max(0, g.skillCd / 10);
      el.skill.classList.toggle("ready", g.skillCd <= 0);
      el.skillCd.style.transform = `scaleY(${k})`;
    }
    el.wardrobeBtn.hidden = false;
    const boss = g.boss;
    const showBoss = !!boss && boss.state !== "sleep" && boss.state !== "gone";
    if (showBoss) {
      const nm = boss.generic ? BOSSES[boss.area].name : "Rusa Menara";
      if (el.bossName.textContent !== nm) el.bossName.textContent = nm;
    }
    el.bossBar.hidden = !showBoss;
    el.root.classList.toggle("boss-on", showBoss);
    if (showBoss) el.bossFill.style.transform = `scaleX(${Math.max(0, boss.hp / boss.maxHp)})`;

    if (g.toast && g.toast.t < g.toast.dur) {
      if (el.toast.textContent !== g.toast.text) el.toast.textContent = g.toast.text;
      el.toast.hidden = false;
      el.toast.style.opacity = String(Math.min(1, (g.toast.dur - g.toast.t) / 0.4, g.toast.t / 0.15));
    } else el.toast.hidden = true;

    const v = g.speech;
    if (v && screen) {
      el.speech.hidden = false;
      if (el.speech.textContent !== v.text) el.speech.textContent = v.text;
      const w = el.root.clientWidth;
      const half = Math.min(135, w / 2);
      el.speech.style.left = `${Math.max(half, Math.min(w - half, screen.x))}px`;
      el.speech.style.top = `${screen.y}px`;
    } else el.speech.hidden = true;

    el.endPanel.hidden = g.phase !== "ending";
    if (g.phase === "ending") {
      const t = Math.floor(g.progress.time);
      const hh = Math.floor(t / 3600);
      const mm = Math.floor((t % 3600) / 60);
      const time = hh ? `${hh}:${String(mm).padStart(2, "0")}` : `${mm}:${String(t % 60).padStart(2, "0")}`;
      const html = `<div><b>${time}</b><span>Waktu</span></div><div><b>${secretsFound(g.progress)}/${TOTAL_SECRETS}</b><span>Rahasia</span></div><div><b>${skinsOwned(g.progress)}/11</b><span>Skin</span></div><div><b>${g.progress.deaths}</b><span>Tumbang</span></div>`;
      if (el.endStats.innerHTML !== html) el.endStats.innerHTML = html;
    }
  }

  function setLoading(frac, msg) {
    el.loadingFill.style.transform = `scaleX(${frac})`;
    if (msg) el.loadingMsg.textContent = msg;
  }

  let lastMap = "";
  function drawMap(g) {
    el.mapPanel.querySelector(".panel-title").textContent = AREAS[g.areaIndex].name;
    const c = el.mapCanvas;
    const rect = c.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const ex = g.areaProg.explored;
    const mapKey = [g.areaIndex, ex, g.areaProg.cp, g.gate?.active,
      g.player.x, g.player.y, rect.width, rect.height, dpr, secretsFound(g.progress), skinsOwned(g.progress)].join(":");
    if (mapKey === lastMap) return;
    lastMap = mapKey;
    c.width = Math.round(rect.width * dpr);
    c.height = Math.round(rect.height * dpr);
    const ctx = c.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    // Fit the whole world in the frame, square tiles, centred.
    const cell = Math.min(rect.width / COLS, rect.height / ROWS);
    const ox = (rect.width - cell * COLS) / 2;
    const oy = (rect.height - cell * ROWS) / 2;
    const bg = ctx.createLinearGradient(0, 0, 0, rect.height);
    bg.addColorStop(0, "#14332b");
    bg.addColorStop(1, "#07140f");
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, rect.width, rect.height);

    const bw = Math.ceil(COLS / EXPLORE_BLOCK);
    const bh = Math.ceil(ROWS / EXPLORE_BLOCK);
    const block = EXPLORE_BLOCK * cell;
    // Unexplored blocks are veiled in fog, so the explored shape reads at a glance.
    ctx.fillStyle = "rgba(190, 240, 220, 0.06)";
    for (let by = 0; by < bh; by++)
      for (let bx = 0; bx < bw; bx++) {
        if (ex[by * bw + bx] === "1") continue;
        ctx.fillRect(ox + bx * block, oy + by * block, Math.min(block, ox + COLS * cell - (ox + bx * block)), Math.min(block, oy + ROWS * cell - (oy + by * block)));
      }
    const gap = cell >= 5 ? 1 : 0;
    for (let y = 0; y < ROWS; y++)
      for (let x = 0; x < COLS; x++) {
        const bi = Math.floor(y / EXPLORE_BLOCK) * bw + Math.floor(x / EXPLORE_BLOCK);
        if (ex[bi] !== "1") continue;
        const t = tileAt(x, y);
        ctx.fillStyle = MAP_COLOR[t] || (t === TILE.EMPTY ? "rgba(150, 230, 200, 0.07)" : "#2e5a50");
        ctx.fillRect(ox + x * cell, oy + y * cell, cell - gap, cell - gap);
      }

    // Markers only show inside explored blocks, so unexplored parts stay a surprise.
    const seen = (x, y) => ex[Math.floor(y / EXPLORE_BLOCK) * bw + Math.floor(x / EXPLORE_BLOCK)] === "1";
    const dot = (x, y, col, r, ring) => {
      const px = ox + (x + 0.5) * cell;
      const py = oy + (y + 0.5) * cell;
      ctx.beginPath();
      ctx.arc(px, py, r, 0, Math.PI * 2);
      ctx.fillStyle = col;
      ctx.fill();
      if (ring) {
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = ring;
        ctx.stroke();
      }
    };
    for (const k of g.checkpoints) {
      if (!seen(k.x, k.y)) continue;
      const current = g.areaProg.cp === k.id;
      dot(k.x, k.y, current ? "#7fffe0" : "#3c8f80", Math.max(3, cell * 0.7), current ? "#eafff6" : null);
    }
    if (g.gate && seen(g.gate.x, g.gate.y)) dot(g.gate.x, g.gate.y, g.gate.active ? "#7fffe0" : "#4b5a58", Math.max(3.5, cell * 0.8), "#0b1714");
    if (g.bell && seen(g.bell.x, g.bell.y)) dot(g.bell.x, g.bell.y, "#ffd36a", Math.max(3.5, cell * 0.9), "#7a4f12");
    // The archer: a soft halo, then a bright marker with a dark rim.
    const px = ox + (g.player.x + 0.5) * cell;
    const py = oy + (g.player.y - 0.2) * cell;
    ctx.beginPath();
    ctx.arc(px, py, Math.max(7, cell * 1.8), 0, Math.PI * 2);
    ctx.fillStyle = "rgba(255, 231, 173, 0.28)";
    ctx.fill();
    dot(g.player.x, g.player.y - 0.7, "#fff6dc", Math.max(4, cell * 0.95), "#0b1714");

    const sf = secretsFound(g.progress);
    el.mapStats.innerHTML = `<span>Rahasia <b>${sf}/${TOTAL_SECRETS}</b></span><span>Skin <b>${skinsOwned(g.progress)}/11</b></span>`;
  }

  // Area chips in the map panel: every existing area is available.
  let chipsKey = "";
  function updateChips(g, onTravel) {
    const key = g.progress.unlocked + ":" + g.areaIndex;
    if (key === chipsKey) return;
    chipsKey = key;
    el.areaChips.innerHTML = AREAS.map((a, i) => (i <= g.progress.unlocked ? `<button class="chip ${i === g.areaIndex ? "on" : ""}" data-area="${i}"><span class="chip-no">${String(i + 1).padStart(2, "0")}</span>${a.name}</button>` : "")).join("");
    el.areaChips.onclick = (e) => {
      const b = e.target.closest("[data-area]");
      if (b) onTravel(Number(b.dataset.area));
    };
  }

  // Wardrobe: one card per skin, portrait drawn from the portrait atlas.
  function buildWardrobe(g, iconSheet, onPick) {
    el.skinGrid.innerHTML = SKINS.map(
      (sk, i) => `<button class="skin-card ${skinOwned(g.progress, i) ? "" : "locked"} ${g.progress.skin === i ? "on" : ""}" data-skin="${i}"><canvas width="96" height="96"></canvas><span class="control-label">${sk.name}</span></button>`
    ).join("");
    el.skinGrid.querySelectorAll(".skin-card").forEach((card) => {
      const i = Number(card.dataset.skin);
      const c = card.querySelector("canvas");
      const f = iconSheet?.frames[SKINS[i].icon];
      if (f) {
        const ctx = c.getContext("2d");
        const cr = f.content || f.source;
        const k = Math.min(96 / cr.w, 96 / cr.h);
        ctx.drawImage(iconSheet.img, cr.x, cr.y, cr.w, cr.h, (96 - cr.w * k) / 2, (96 - cr.h * k) / 2, cr.w * k, cr.h * k);
      }
    });
    const showDetail = (i) => {
      const sk = SKINS[i];
      const owned = skinOwned(g.progress, i);
      const how = owned ? (g.progress.skin === i ? "Sedang dipakai" : "Ketuk lagi untuk memakai") : `Kalahkan ${BOSSES[i]?.name || ""} di ${AREAS[i].name}`;
      el.skinDetail.innerHTML = `<b>${i}. ${sk.name}</b><span>${sk.perk}${i > 1 ? " + semua buff sebelumnya" : ""}</span><em>${how}</em>`;
    };
    showDetail(g.progress.skin);
    let picked = g.progress.skin;
    el.skinGrid.onclick = (e) => {
      const card = e.target.closest("[data-skin]");
      if (!card) return;
      const i = Number(card.dataset.skin);
      if (picked === i && skinOwned(g.progress, i)) {
        onPick(i);
        el.skinGrid.querySelectorAll(".skin-card").forEach((c) => c.classList.toggle("on", Number(c.dataset.skin) === i));
      }
      picked = i;
      showDetail(i);
      el.skinGrid.querySelectorAll(".skin-card").forEach((c) => c.classList.toggle("sel", Number(c.dataset.skin) === i));
    };
  }

  return { el, update, setLoading, drawMap, updateChips, buildWardrobe, skillName: (k) => SKILL_NAMES[k] };
}
