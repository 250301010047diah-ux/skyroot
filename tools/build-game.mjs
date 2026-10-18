// Rebuild the offline runtime from the original game, without a Playabl server.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
import sharp from 'sharp';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'assets/game');
await fs.mkdir(path.join(out, 'frames'), { recursive: true });
const manifest = JSON.parse(await fs.readFile(path.join(root, 'game js/assets.json'), 'utf8'));
const local = {};
const report = { source: 'Local recipe + image alpha bounds; original sidecars unavailable', assets: [], modules: [] };
const partColumns = { PROPS: 6, AREA_PROPS: 4, AREA_SHOTS: 4, SKIN_ICONS: 4, BRANCH_TILES: 3, VINE_TILES: 1 };

// Generated art is not a perfectly uniform grid. Find transparent separators so
// a wide arrow, lift or attack frame is not cut in half or mixed with its neighbor.
function partitions(histogram, count, useBands = false) {
  if (useBands) {
    const bands = [];
    let start = -1, last = -1;
    for (let i = 0; i < histogram.length; i++) {
      if (histogram[i] > 3) { if (start < 0) start = i; last = i; }
      else if (start >= 0 && i - last > 24) { bands.push([start, last]); start = -1; }
    }
    if (start >= 0) bands.push([start, last]);
    if (bands.length === count) return [0, ...bands.slice(1).map((b, i) => Math.round((bands[i][1] + b[0]) / 2)), histogram.length];
  }
  const cuts = [0], size = histogram.length / count;
  for (let i = 1; i < count; i++) {
    const target = size * i;
    const lo = Math.max(cuts.at(-1) + 1, Math.round(target - size * 0.4));
    const hi = Math.min(histogram.length - 1, Math.round(target + size * 0.4));
    let best = lo, score = Infinity;
    for (let p = lo; p <= hi; p++) {
      // Prefer empty gaps, and within a gap prefer a cut away from opaque pixels.
      let cost = 0;
      for (let d = -8; d <= 8; d++) cost += histogram[p + d] || 0;
      cost = cost * 1000 + Math.abs(p - target);
      if (cost < score) { score = cost; best = p; }
    }
    cuts.push(best);
  }
  cuts.push(histogram.length);
  return cuts;
}

for (const [key, asset] of Object.entries(manifest)) {
  const file = path.basename(asset.src);
  const input = path.join(root, 'assets/images', file);
  const meta = await sharp(input).metadata(); // Fails the build on missing/corrupt images.
  local[key] = `/images/${file}`;
  const recipe = asset.recipe.playabl;
  let animations = recipe.animations;
  // Recoloured skins intentionally inherit their source archer's layout.
  if (!animations && /^SKIN\d+_[ABC]$/.test(key)) {
    animations = manifest[`ARCHER_${key.at(-1)}`].recipe.playabl.animations;
  }
  const parts = recipe.parts;
  const entry = { key, file, width: meta.width, height: meta.height, frames: 0 };
  if (animations || parts) {
    const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const cols = animations ? Math.max(...animations.map(a => a.frames)) : partColumns[key];
    const rows = animations ? animations.length : Math.ceil(parts.length / cols);
    const rowHistogram = new Uint32Array(info.height);
    for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) {
      if (data[(y * info.width + x) * 4 + 3] > 32) rowHistogram[y]++;
    }
    const yCuts = partitions(rowHistogram, rows, true);
    const xCuts = Array.from({ length: rows }, (_, row) => {
      const histogram = new Uint32Array(info.width);
      for (let y = yCuts[row]; y < yCuts[row + 1]; y++) for (let x = 0; x < info.width; x++) {
        if (data[(y * info.width + x) * 4 + 3] > 32) histogram[x]++;
      }
      return partitions(histogram, animations ? animations[row].frames : Math.min(cols, parts.length - row * cols));
    });
    const frames = [], anims = [];
    const frame = (name, col, row, rect = null) => {
      const x = rect?.x ?? xCuts[row][col], y = rect?.y ?? yCuts[row];
      const w = rect?.w ?? xCuts[row][col + 1] - x, h = rect?.h ?? yCuts[row + 1] - y;
      let x0 = x + w, y0 = y + h, x1 = x, y1 = y;
      for (let py = y; py < y + h; py++) for (let px = x; px < x + w; px++) {
        if (data[(py * info.width + px) * 4 + 3] > 16) {
          x0 = Math.min(x0, px); y0 = Math.min(y0, py);
          x1 = Math.max(x1, px); y1 = Math.max(y1, py);
        }
      }
      if (x0 > x1) throw new Error(`Empty frame: ${key}/${name}`);
      const f = { name, source: { x, y, w, h }, content: { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 }, anchor: { x: (x0 + x1 + 1) / 2, y: y1 + 1 } };
      if (key === 'WORLD_ANIM' && /^(fold_leaf|crumble_platform)_/.test(name)) {
        f.surfaceY = y0;
        for (let py = y0; py <= y1; py++) {
          let opaque = 0;
          for (let px = x0; px <= x1; px++) if (data[(py * info.width + px) * 4 + 3] > 128) opaque++;
          if (opaque >= (x1 - x0 + 1) * 0.55) { f.surfaceY = py; break; }
        }
      }
      frames.push(f);
      return f;
    };
    if (animations) animations.forEach((a, row) => {
      anims.push({ name: a.name, frames: Array.from({ length: a.frames }, (_, col) => frame(`${a.name}_${col + 1}`, col, row)) });
    });
    else if (key === 'BRANCH_TILES') {
      // Renderer contract: 224 px end caps, a 672 px repeating center.
      // These slices come from the existing continuous branch strip.
      const slices = [{ x: 64, w: 224 }, { x: 288, w: 672 }, { x: 960, w: 224 }];
      parts.forEach((name, i) => {
        const f = frame(name, 0, 0, { ...slices[i], y: 0, h: info.height });
        f.surfaceY = 256; // Moss surface; tufts above it are decoration.
      });
    } else if (key === 'VINE_TILES') {
      frame('top_cap', 0, 0, { x: 0, y: 0, w: info.width, h: 160 });
      frame('body', 0, 0, { x: 0, y: 160, w: info.width, h: info.height - 160 });
    } else parts.forEach((name, i) => {
      const row = Math.floor(i / cols);
      frame(name, i % cols, row);
    });
    await fs.writeFile(path.join(out, 'frames', `${key}.json`), JSON.stringify({ provenance: report.source, frames, animations: anims }));
    entry.frames = frames.length;
  }
  report.assets.push(entry);
}
await fs.writeFile(path.join(out, 'manifest.json'), JSON.stringify(local, null, 2));
const result = await build({
  entryPoints: [path.join(root, 'game js/android-main.js')],
  outfile: path.join(out, 'game.js'), bundle: true, format: 'iife',
  target: ['chrome90'], metafile: true, charset: 'utf8',
});
report.modules = Object.keys(result.metafile.inputs).map(p => p.replaceAll('\\', '/')).sort();
report.totalFrames = report.assets.reduce((n, a) => n + a.frames, 0);
await fs.copyFile(path.join(root, 'game js/android.html'), path.join(out, 'index.html'));
await fs.writeFile(path.join(out, 'audit.json'), JSON.stringify(report, null, 2));
console.log(`Bundled ${report.modules.length} modules, ${report.assets.length} asset keys, ${report.totalFrames} frames.`);
