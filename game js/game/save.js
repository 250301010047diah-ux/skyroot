// Progress kept between sessions through sdk.gameState (small, versioned JSON).
// v2 adds areas (one record per area), skins and unlocked areas; v1 saves migrate into area 0.
export const AREA_COUNT = 11;
export const EXPLORE_BLOCK = 4;
const AREA0_SECRETS = ["E@36,97", "R@15,61", "Y@37,16"];
const AREA_SECRETS = ["E@19,33", "R@20,42"];

export function secretIdsFor(area) {
  return area === 0 ? AREA0_SECRETS : AREA_SECRETS;
}

export const TOTAL_SECRETS = AREA0_SECRETS.length + AREA_SECRETS.length * (AREA_COUNT - 1);

function blankArea() {
  return { cp: null, boss: false, got: [], broken: [], explored: "" };
}

export function defaultProgress() {
  return {
    v: 2,
    area: 0,
    unlocked: AREA_COUNT - 1,
    skin: 0,
    abilities: { footing: false, dash: false },
    maxHp: 3,
    maxEnergy: 3,
    rope: false,
    lift: false,
    bell: false,
    feather: false,
    time: 0,
    deaths: 0,
    areas: Array.from({ length: AREA_COUNT }, blankArea),
  };
}

const bool = (v) => v === true;
const strs = (a, n) => (Array.isArray(a) ? a.filter((x) => typeof x === "string").slice(0, n) : []);
function clampInt(v, lo, hi, def) {
  if (!Number.isFinite(v)) return def;
  return Math.max(lo, Math.min(hi, Math.round(v)));
}
function cleanArea(raw) {
  const a = blankArea();
  if (!raw || typeof raw !== "object") return a;
  a.cp = typeof raw.cp === "string" ? raw.cp : null;
  a.boss = bool(raw.boss);
  a.got = strs(raw.got, 64);
  a.broken = strs(raw.broken, 16);
  a.explored = typeof raw.explored === "string" ? raw.explored.slice(0, 400) : "";
  return a;
}

export function sanitizeProgress(raw) {
  const d = defaultProgress();
  if (!raw || typeof raw !== "object") return d;
  if (raw.v === 1) {
    // Migrate the single-area save into area 0.
    raw = {
      ...raw,
      v: 2,
      area: 0,
      unlocked: raw.bell ? 1 : 0,
      skin: 0,
      areas: [{ cp: raw.cp, boss: raw.boss, got: raw.got, broken: raw.broken, explored: raw.explored }],
    };
  }
  if (raw.v !== 2) return d;
  const areas = Array.from({ length: AREA_COUNT }, (_, i) => cleanArea(raw.areas?.[i]));
  const unlocked = AREA_COUNT - 1;
  return {
    v: 2,
    area: Math.min(clampInt(raw.area, 0, AREA_COUNT - 1, 0), unlocked),
    unlocked,
    skin: clampInt(raw.skin, 0, AREA_COUNT - 1, 0),
    abilities: { footing: bool(raw.abilities?.footing), dash: bool(raw.abilities?.dash) },
    maxHp: clampInt(raw.maxHp, 3, 14, 3),
    maxEnergy: clampInt(raw.maxEnergy, 3, 13, 3),
    rope: bool(raw.rope),
    lift: bool(raw.lift),
    bell: bool(raw.bell),
    feather: bool(raw.feather),
    time: Number.isFinite(raw.time) ? Math.max(0, raw.time) : 0,
    deaths: clampInt(raw.deaths, 0, 99999, 0),
    areas,
  };
}

export function secretsFound(progress) {
  let n = 0;
  progress.areas.forEach((a, i) => {
    for (const id of secretIdsFor(i)) if (a.got.includes(id)) n++;
  });
  return n;
}

// All existing skins are available; boss/checkpoint progress stays independent.
export function skinOwned(progress, skin) {
  return Number.isInteger(skin) && skin >= 0 && skin < AREA_COUNT;
}

export function skinsOwned(progress) {
  let n = 0;
  for (let i = 0; i < AREA_COUNT; i++) if (skinOwned(progress, i)) n++;
  return n;
}
