// Loads images, their frame sidecars and the terrain surface kits. Core art loads at start;
// each area's backdrop/monsters/boss and each skin's sheets load on demand.
// Image URLs always come from the SDK assets handle so creator replacements apply;
// slicing sidecars come from the generated originals (a replacement keeps the layout).
import manifest from "../assets.json";
import { AREAS, BOSSES, MONSTERS, SKINS } from "./content.js";

const CORE_SHEETS = [
  "ARCHER_A", "ARCHER_B", "ARCHER_C", "ENEMIES_A", "ENEMIES_B", "BOSS_STAG", "EFFECTS", "WORLD_ANIM",
  "SHRINES", "PROPS", "BRANCH_TILES", "VINE_TILES", "AREA_PROPS", "AREA_SHOTS", "SKIN_ICONS",
];
const CORE_SINGLES = ["BACKDROP", "TREEHOUSE"];
// Returned by the surface-kit generator; both kits ship the same renderer module.
const KIT_RENDERER = "/generated-assets/surface-kits/a1cd99b1-a69c-4ff5-879b-24718addf18a/renderer.mjs";

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.decoding = "async";
    const timer = setTimeout(() => { img.src = ""; finish(new Error("Timed out loading " + url)); }, 15000);
    function finish(error) {
      clearTimeout(timer);
      img.onload = img.onerror = null;
      if (error) reject(error);
      else resolve(img);
    }
    img.onload = () => finish();
    img.onerror = () => finish(new Error("Could not load " + url));
    img.src = url;
  });
}

export function createLoader(assets) {
  const get = (k) => (assets ? assets.get(k) : manifest[k].src);
  const sheets = {};
  const singles = {};
  const kits = {};
  const jobs = new Map();
  const seenSheets = new Set(), seenSingles = new Set();

  // Failed promises must not poison subsequent retry requests.
  function cached(key, work) {
    if (!jobs.has(key)) {
      const job = work().catch(error => {
        if (jobs.get(key) === job) jobs.delete(key);
        throw error;
      });
      jobs.set(key, job);
    }
    return jobs.get(key);
  }

  async function loadFrames(url, key) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetch(url, { signal: controller.signal });
      if (!response.ok) throw new Error("Missing frames for " + key);
      return await response.json();
    } finally { clearTimeout(timer); }
  }

  function loadSheet(key) {
    if (!jobs.has(key)) {
      const framesUrl = assets?.framesUrl?.(key) ?? manifest[key].src.replace(/\.(webp|png|jpg|jpeg)$/i, ".frames.json");
      return cached(key, () => Promise.all([
          loadImage(get(key)),
          loadFrames(framesUrl, key),
        ]).then(([img, frames]) => {
          const byName = {};
          for (const f of frames.frames) byName[f.name] = f;
          const anims = {};
          for (const a of frames.animations || []) anims[a.name] = a.frames;
          // Sheets edited from another keep its layout but may omit the animation index.
          if (!frames.animations) {
            for (const f of frames.frames) {
              const m = /^(.*)_(\d+)$/.exec(f.name);
              if (!m) continue;
              (anims[m[1]] ||= [])[Number(m[2]) - 1] = f;
            }
          }
          sheets[key] = { img, frames: byName, anims };
          seenSheets.add(key);
        })
      );
    }
    return jobs.get(key);
  }

  function loadSingle(key) {
    return cached(key, () => loadImage(get(key)).then(img => { singles[key] = img; seenSingles.add(key); }));
  }

  async function loadCore(onProgress) {
    const list = [...CORE_SHEETS.map(loadSheet), ...CORE_SINGLES.map(loadSingle)];
    let done = 0;
    const tick = () => onProgress?.(++done / (list.length + 2));
    list.forEach((p) => p.then(tick, () => {}));
    const localKits = assets?.loadKits ? await assets.loadKits() : null;
    const kitModule = localKits ? null : import(/* @vite-ignore */ new URL(KIT_RENDERER, document.baseURI).href);
    const kitJobs = ["BARK_KIT", "SOFTWOOD_KIT"].map(async (key) => {
      if (localKits) kits[key] = localKits[key];
      else {
        const { loadSurfaceKit } = await kitModule;
        kits[key] = await loadSurfaceKit(new URL(get(key), document.baseURI).href);
      }
      tick();
    });
    await Promise.all([...list, ...kitJobs]);
    kits.MOSS = kits.BARK_KIT.withColor("#5b7f34");
  }

  // Everything an area needs on screen: backdrop, monster sheet, boss sheet.
  function areaKeys(i) {
    const a = AREAS[i];
    const keys = { sheets: [], singles: [a.bg] };
    if (a.monster) keys.sheets.push(MONSTERS[a.monster].sheet);
    if (BOSSES[i]) keys.sheets.push(BOSSES[i].sheet);
    // Earlier areas' monsters can be summoned by later bosses only from this area's own list.
    return keys;
  }

  function ensureArea(i) {
    const k = areaKeys(i);
    return Promise.all([...k.sheets.map(loadSheet), ...k.singles.map(loadSingle)]);
  }

  function areaReady(i) {
    const k = areaKeys(i);
    return k.sheets.every((s) => sheets[s]) && k.singles.every((s) => singles[s]);
  }

  function ensureSkin(i) {
    return Promise.all(SKINS[i].sheets.map(loadSheet));
  }

  function skinReady(i) {
    return SKINS[i].sheets.every((s) => sheets[s]);
  }

  // Terrain kits recoloured per area.
  const areaKits = {};
  function kitsFor(i) {
    if (!areaKits[i]) {
      for (const key of Object.keys(areaKits)) delete areaKits[key];
      const a = AREAS[i];
      areaKits[i] = a.bark
        ? { BARK_KIT: kits.BARK_KIT.withColor(a.bark), SOFTWOOD_KIT: kits.SOFTWOOD_KIT.withColor(a.soft), MOSS: kits.MOSS }
        : { BARK_KIT: kits.BARK_KIT, SOFTWOOD_KIT: kits.SOFTWOOD_KIT, MOSS: kits.MOSS };
    }
    return areaKits[i];
  }

  function retain(area, skin) {
    const keys = areaKeys(area);
    const keepSheets = new Set([...CORE_SHEETS, ...keys.sheets, ...SKINS[skin].sheets]);
    const keepSingles = new Set([...CORE_SINGLES, ...keys.singles]);
    for (const [items, keep] of [[sheets, keepSheets], [singles, keepSingles]]) {
      for (const key of Object.keys(items)) if (!keep.has(key)) {
        delete items[key];
        jobs.delete(key);
      }
    }
  }

  return { sheets, singles, kits, loadCore, ensureArea, areaReady, ensureSkin, skinReady, kitsFor, retain,
    visited: () => ({ sheets: [...seenSheets], singles: [...seenSingles] }) };
}
