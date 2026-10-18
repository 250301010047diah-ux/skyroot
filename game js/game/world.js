// Static world: the active area's tile grid + spawn list, parsed from its ASCII map.
// Glyphs:
//   #  bark (solid)          S  soft heartwood (solid, Footing Arrows stick)   W  moss wall (wall jump)
//   g  sap (solid, slows)    k  crystal (solid, bounces arrows)                i  ice (solid, slippery)
//   =  branch (one-way)      |  vine (climb)        ^  thorn spikes            w  wind gust zone
//   e  ember vent (hazard that flares on a beat)     v  stalactite (falls on whoever passes under)
//   L  folding leaf   C  crumbling slab   F  launch flower   M/N  moving platform (sideways/up-down)
//   n  root bridge (after the stag)   X  cracked wall / web   G  gate to the next area
//   K  rest shrine   P  start   U/u lift   z  rope anchor   O  area boss   b  bell
//   T  thorn guard   B  shield beetle   Q  cannon frog   *  the area's own monster
//   H  heart   E  energy stone   D  dash relic   A  footing relic   R  heart relic   Y  golden feather
//   V  villager   h treehouse   l lantern   m mushrooms   s sign   (decor)
import { WORLD_MAP } from "./worldMaps.js";
import { AREA_MAPS } from "./areaMaps.js";

export const TILE = { EMPTY: 0, BARK: 1, SOFT: 2, MOSS: 3, ONEWAY: 4, VINE: 5, SPIKE: 6, WIND: 7, SAP: 8, CRYSTAL: 9, ICE: 10, EMBER: 11 };
export const ALL_MAPS = [WORLD_MAP, ...AREA_MAPS];

export let COLS = 0;
export let ROWS = 0;
let map = WORLD_MAP;
let tiles = new Uint8Array(0);
let crackSolid = new Uint8Array(0);
let ropeVine = new Uint8Array(0);

export const WORLD = { singles: [], runs: {}, vines: [], winds: [], cracks: [], area: -1 };

const SOLID = new Set([TILE.BARK, TILE.SOFT, TILE.MOSS, TILE.SAP, TILE.CRYSTAL, TILE.ICE]);
const TILE_OF = { "#": TILE.BARK, S: TILE.SOFT, W: TILE.MOSS, g: TILE.SAP, k: TILE.CRYSTAL, i: TILE.ICE, "=": TILE.ONEWAY, "|": TILE.VINE, "^": TILE.SPIKE, w: TILE.WIND, e: TILE.EMBER };

function glyphAt(x, y) {
  return map[y]?.[x] ?? "#";
}

// Switch the active area. Cheap (a few thousand cells) and synchronous.
export function loadArea(index) {
  if (WORLD.area === index) return;
  map = ALL_MAPS[index] || WORLD_MAP;
  ROWS = map.length;
  COLS = map[0].length;
  tiles = new Uint8Array(COLS * ROWS);
  crackSolid = new Uint8Array(COLS * ROWS);
  ropeVine = new Uint8Array(COLS * ROWS);
  const singles = [];
  const runs = { L: [], C: [], n: [], "=": [], "^": [], M: [], N: [] };
  const vines = [];
  const winds = [];
  const cracks = [];
  for (let y = 0; y < ROWS; y++)
    for (let x = 0; x < COLS; x++) {
      const g = glyphAt(x, y);
      tiles[y * COLS + x] = TILE_OF[g] ?? TILE.EMPTY;
      if ("PKTBQOHEDARYVbUuzFhlmsGv*".includes(g)) singles.push({ g, x, y });
    }
  for (const g of Object.keys(runs)) {
    for (let y = 0; y < ROWS; y++) {
      let x = 0;
      while (x < COLS) {
        if (glyphAt(x, y) === g) {
          const x0 = x;
          while (glyphAt(x + 1, y) === g) x++;
          runs[g].push({ x0, x1: x, y });
        }
        x++;
      }
    }
  }
  for (let x = 0; x < COLS; x++) {
    let y = 0;
    while (y < ROWS) {
      const g = glyphAt(x, y);
      if (g === "|" || g === "X") {
        const y0 = y;
        while (glyphAt(x, y + 1) === g) y++;
        (g === "|" ? vines : cracks).push({ x, y0, y1: y });
      }
      y++;
    }
  }
  const seen = new Uint8Array(COLS * ROWS);
  for (let y = 0; y < ROWS; y++)
    for (let x = 0; x < COLS; x++) {
      if (glyphAt(x, y) !== "w" || seen[y * COLS + x]) continue;
      let x1 = x;
      while (glyphAt(x1 + 1, y) === "w") x1++;
      let y1 = y;
      const rowIsWind = (yy) => {
        for (let xx = x; xx <= x1; xx++) if (glyphAt(xx, yy) !== "w") return false;
        return true;
      };
      while (rowIsWind(y1 + 1)) y1++;
      for (let yy = y; yy <= y1; yy++) for (let xx = x; xx <= x1; xx++) seen[yy * COLS + xx] = 1;
      winds.push({ x0: x, x1, y0: y, y1 });
    }
  Object.assign(WORLD, { singles, runs, vines, winds, cracks, area: index });
}
loadArea(0);

export function tileAt(x, y) {
  if (x < 0 || y < 0 || x >= COLS || y >= ROWS) return TILE.BARK;
  return tiles[y * COLS + x];
}

export function isSolidTile(x, y) {
  if (x < 0 || y < 0 || x >= COLS || y >= ROWS) return true;
  const i = y * COLS + x;
  return SOLID.has(tiles[i]) || crackSolid[i] === 1;
}

export function isVine(x, y) {
  if (x < 0 || y < 0 || x >= COLS || y >= ROWS) return false;
  return tiles[y * COLS + x] === TILE.VINE || ropeVine[y * COLS + x] === 1;
}

export function setCrackSolid(crack, solid) {
  for (let y = crack.y0; y <= crack.y1; y++) crackSolid[y * COLS + crack.x] = solid ? 1 : 0;
}

export function setRope(rope, open) {
  if (WORLD.area !== 0) return;
  for (let y = rope.y0; y <= rope.y1; y++) ropeVine[y * COLS + rope.x] = open ? 1 : 0;
}

export function crackAt(x, y) {
  return crackSolid[y * COLS + x] === 1;
}

// The rope shortcut in Akar Berkabut hangs from the one-way ledge down to the village.
export const ROPE = { x: 1, y0: 36, y1: 82 };
