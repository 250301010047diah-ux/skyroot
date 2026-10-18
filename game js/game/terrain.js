// Terrain is drawn by the generated surface kits into cached chunk canvases
// (16x16 cells, one cell of neighbour context so borders join across chunks).
import { COLS, ROWS, tileAt, TILE } from "./world.js";

const CHUNK = 16;
const MAX_CACHED = 14;

export function createTerrain(kits) {
  const cache = new Map();
  let cellPx = 0;
  let layers = [];
  // Sap ledges are bark underneath (the sap pool is drawn on top); crystal and ice are sprites.
  function setKits(k) {
    layers = [
      { kit: k.BARK_KIT, types: [TILE.BARK, TILE.SAP] },
      { kit: k.SOFTWOOD_KIT, types: [TILE.SOFT] },
      { kit: k.MOSS, types: [TILE.MOSS] },
    ];
    cache.clear();
  }
  setKits(kits);

  function build(cx, cy) {
    const canvas = document.createElement("canvas");
    canvas.width = CHUNK * cellPx;
    canvas.height = CHUNK * cellPx;
    const ctx = canvas.getContext("2d");
    let any = false;
    for (const layer of layers) {
      const cells = [];
      let has = false;
      for (let y = -1; y <= CHUNK; y++) {
        const row = [];
        for (let x = -1; x <= CHUNK; x++) {
          const wx = cx * CHUNK + x;
          const wy = cy * CHUNK + y;
          const inside = wx >= 0 && wy >= 0 && wx < COLS && wy < ROWS;
          const on = inside ? layer.types.includes(tileAt(wx, wy)) : false;
          if (on && x >= 0 && y >= 0 && x < CHUNK && y < CHUNK) has = true;
          row.push(on ? 1 : null);
        }
        cells.push(row);
      }
      if (!has) continue;
      any = true;
      layer.kit.draw(ctx, { cells, x: -cellPx, y: -cellPx, cellSize: cellPx, pixelRatio: 1 });
      layer.kit.clearCache();
    }
    return any ? canvas : null;
  }

  return {
    setKits,
    // scale: CSS px per tile; dpr: device pixel ratio. Builds at most `budget` chunks per call.
    // cacheScale: the un-zoomed scale, so a camera zoom only rescales cached chunks.
    draw(ctx, camLeft, camTop, viewW, viewH, scale, dpr, budget = 2, cacheScale = scale) {
      const want = Math.min(64, Math.max(16, Math.round(cacheScale * dpr)));
      if (want !== cellPx) {
        cellPx = want;
        cache.clear();
      }
      const x0 = Math.max(0, Math.floor(camLeft / CHUNK));
      const y0 = Math.max(0, Math.floor(camTop / CHUNK));
      const x1 = Math.min(Math.ceil(COLS / CHUNK) - 1, Math.floor((camLeft + viewW / scale) / CHUNK));
      const y1 = Math.min(Math.ceil(ROWS / CHUNK) - 1, Math.floor((camTop + viewH / scale) / CHUNK));
      for (let cy = y0; cy <= y1; cy++)
        for (let cx = x0; cx <= x1; cx++) {
          const key = cx + "," + cy;
          let entry = cache.get(key);
          if (!entry) {
            if (budget <= 0) continue;
            budget--;
            entry = { canvas: build(cx, cy) };
            cache.set(key, entry);
            if (cache.size > MAX_CACHED) {
              const oldest = cache.keys().next().value;
              if (oldest !== key) cache.delete(oldest);
            }
          } else {
            // Refresh LRU order.
            cache.delete(key);
            cache.set(key, entry);
          }
          if (!entry.canvas) continue;
          const sx = Math.round((cx * CHUNK - camLeft) * scale);
          const sy = Math.round((cy * CHUNK - camTop) * scale);
          const ex = Math.round(((cx + 1) * CHUNK - camLeft) * scale);
          const ey = Math.round(((cy + 1) * CHUNK - camTop) * scale);
          ctx.drawImage(entry.canvas, sx, sy, ex - sx, ey - sy);
        }
    },
    // Pre-build everything around a point (used once after loading).
    warm(camLeft, camTop, viewW, viewH, scale, dpr) {
      this.draw({ drawImage() {} }, camLeft, camTop, viewW, viewH, scale, dpr, 99);
    },
  };
}
