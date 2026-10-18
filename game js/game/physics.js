// Tile collision for axis-aligned bodies. A body is { x, y, w, h } with x at its
// horizontal centre and y at its feet, all in tile units.
import { isSolidTile, tileAt, TILE } from "./world.js";

const EPS = 0.001;

export function overlapsSolid(x, y, w, h) {
  const x0 = Math.floor(x - w / 2 + EPS);
  const x1 = Math.floor(x + w / 2 - EPS);
  const y0 = Math.floor(y - h + EPS);
  const y1 = Math.floor(y - EPS);
  for (let ty = y0; ty <= y1; ty++) for (let tx = x0; tx <= x1; tx++) if (isSolidTile(tx, ty)) return true;
  return false;
}

// Moves a body by (dx, dy) against solid tiles and one-way surfaces.
// platforms: [{ x0, x1, top, id }] dynamic one-way surfaces (x1 exclusive).
// Returns { hitX: -1|0|1, hitUp, landed, platformId }.
export function moveBody(b, dx, dy, platforms, dropThrough = false) {
  const out = { hitX: 0, hitUp: false, landed: false, platformId: null };
  const steps = Math.max(1, Math.ceil(Math.max(Math.abs(dx), Math.abs(dy)) / 0.35));
  const sx = dx / steps;
  const sy = dy / steps;
  for (let i = 0; i < steps; i++) {
    if (sx !== 0 && out.hitX === 0) {
      const nx = b.x + sx;
      if (overlapsSolid(nx, b.y, b.w, b.h)) {
        if (sx > 0) b.x = Math.floor(nx + b.w / 2 - EPS) - b.w / 2 - EPS;
        else b.x = Math.floor(nx - b.w / 2 + EPS) + 1 + b.w / 2 + EPS;
        out.hitX = sx > 0 ? 1 : -1;
      } else b.x = nx;
    }
    if (sy !== 0 && !out.landed && !out.hitUp) {
      const prevFeet = b.y;
      const ny = b.y + sy;
      if (sy > 0) {
        // Falling: solid tiles first.
        if (overlapsSolid(b.x, ny, b.w, b.h)) {
          b.y = Math.floor(ny - EPS);
          out.landed = true;
          continue;
        }
        if (!dropThrough) {
          const surf = oneWayCross(b, prevFeet, ny, platforms);
          if (surf) {
            b.y = surf.top;
            out.landed = true;
            out.platformId = surf.id;
            continue;
          }
        }
        b.y = ny;
      } else {
        if (overlapsSolid(b.x, ny, b.w, b.h)) {
          b.y = Math.floor(ny - b.h + EPS) + 1 + b.h + EPS;
          out.hitUp = true;
        } else b.y = ny;
      }
    }
  }
  return out;
}

function oneWayCross(b, prevFeet, newFeet, platforms) {
  const left = b.x - b.w / 2 + 0.05;
  const right = b.x + b.w / 2 - 0.05;
  // Static branch tiles.
  const r0 = Math.floor(prevFeet - EPS) + 1;
  const r1 = Math.floor(newFeet);
  for (let r = r0; r <= r1; r++) {
    if (r < prevFeet - EPS) continue;
    for (let tx = Math.floor(left); tx <= Math.floor(right); tx++)
      if (tileAt(tx, r) === TILE.ONEWAY) return { top: r, id: null };
  }
  let best = null;
  for (const p of platforms) {
    if (right <= p.x0 || left >= p.x1) continue;
    if (prevFeet <= p.top + 0.02 && newFeet >= p.top) if (!best || p.top < best.top) best = p;
  }
  return best;
}

// Is there ground (solid or one-way) directly under the feet?
export function groundUnder(b, platforms) {
  const left = b.x - b.w / 2 + 0.05;
  const right = b.x + b.w / 2 - 0.05;
  const r = Math.round(b.y);
  if (Math.abs(b.y - r) > 0.03) {
    for (const p of platforms)
      if (!(right <= p.x0 || left >= p.x1) && Math.abs(b.y - p.top) < 0.03) return { id: p.id };
    return null;
  }
  for (let tx = Math.floor(left); tx <= Math.floor(right); tx++) {
    if (isSolidTile(tx, r) || tileAt(tx, r) === TILE.ONEWAY) return { id: null, tile: true };
  }
  for (const p of platforms)
    if (!(right <= p.x0 || left >= p.x1) && Math.abs(b.y - p.top) < 0.03) return { id: p.id };
  return null;
}

export function overlapsTile(b, type) {
  const x0 = Math.floor(b.x - b.w / 2 + 0.1);
  const x1 = Math.floor(b.x + b.w / 2 - 0.1);
  const y0 = Math.floor(b.y - b.h + 0.1);
  const y1 = Math.floor(b.y - 0.1);
  for (let ty = y0; ty <= y1; ty++) for (let tx = x0; tx <= x1; tx++) if (tileAt(tx, ty) === type) return true;
  return false;
}

// Line of sight between two points through solid tiles.
export function clearLine(x0, y0, x1, y1) {
  const d = Math.hypot(x1 - x0, y1 - y0);
  const n = Math.ceil(d / 0.25);
  for (let i = 1; i < n; i++) {
    const t = i / n;
    if (isSolidTile(Math.floor(x0 + (x1 - x0) * t), Math.floor(y0 + (y1 - y0) * t))) return false;
  }
  return true;
}

export function rectsOverlap(a, b) {
  return a.x0 < b.x1 && a.x1 > b.x0 && a.y0 < b.y1 && a.y1 > b.y0;
}

export function bodyRect(b) {
  return { x0: b.x - b.w / 2, x1: b.x + b.w / 2, y0: b.y - b.h, y1: b.y };
}
