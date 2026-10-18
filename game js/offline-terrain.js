// Decode the existing 47-tile blob atlas used by the original terrain kit.
// The generated renderer sidecar is missing; no replacement terrain art is made.
// Masks use clockwise N, NE, E, SE, S, SW, W, NW bits and sorted valid masks.
export const TILE_MASKS = Array.from({ length: 256 }, (_, mask) => mask).filter(mask =>
  (!(mask & 2) || (mask & 5) === 5) &&
  (!(mask & 8) || (mask & 20) === 20) &&
  (!(mask & 32) || (mask & 80) === 80) &&
  (!(mask & 128) || (mask & 65) === 65));

export async function loadOfflineKits(manifest) {
  const image = new Image();
  image.src = '/images/atlas.png';
  let timer;
  try {
    await Promise.race([image.decode(), new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('Timed out loading terrain atlas')), 15000);
    })]);
  } finally { clearTimeout(timer); }
  function kit(palette, tint = null) {
    let atlas = image;
    if (tint) {
      atlas = document.createElement('canvas');
      atlas.width = image.naturalWidth;
      atlas.height = image.naturalHeight;
      const ctx = atlas.getContext('2d');
      ctx.drawImage(image, 0, 0);
      ctx.globalCompositeOperation = 'source-atop';
      ctx.globalAlpha = 0.45;
      ctx.fillStyle = tint;
      ctx.fillRect(0, 0, atlas.width, atlas.height);
    }
    return {
      withColor(color) { return kit(palette, color); },
      clearCache() {},
      draw(ctx, { cells, x, y, cellSize: size }) {
        const occupied = (r, c) => cells[r]?.[c] != null;
        for (let r = 0; r < cells.length; r++) for (let c = 0; c < cells[r].length; c++) {
          if (!occupied(r, c)) continue;
          const dx = x + c * size, dy = y + r * size;
          const n = occupied(r - 1, c), e = occupied(r, c + 1), s = occupied(r + 1, c), w = occupied(r, c - 1);
          const mask = (n ? 1 : 0) | (n && e && occupied(r - 1, c + 1) ? 2 : 0) |
            (e ? 4 : 0) | (e && s && occupied(r + 1, c + 1) ? 8 : 0) |
            (s ? 16 : 0) | (s && w && occupied(r + 1, c - 1) ? 32 : 0) |
            (w ? 64 : 0) | (w && n && occupied(r - 1, c - 1) ? 128 : 0);
          const index = TILE_MASKS.indexOf(mask);
          // 256 px art with a 2 px extruded border on each side.
          ctx.drawImage(atlas, (index % 12) * 260 + 2, Math.floor(index / 12) * 260 + 2,
            256, 256, dx, dy, size, size);
        }
      },
    };
  }
  return Object.fromEntries(['BARK_KIT', 'SOFTWOOD_KIT'].map(key => {
    const palette = manifest[key].recipe.playabl.kit.palette;
    return [key, kit(palette, key === 'SOFTWOOD_KIT' ? palette.fill : null)];
  }));
}
