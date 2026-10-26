// Runs the ORIGINAL JS player physics through scripted inputs and records the
// trajectory, so the Dart port can be checked frame by frame (test/engine_test.dart).
// Usage: node tools/ref-trajectory.mjs
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadArea, WORLD } from '../game js/game/world.js';
import { createPlayer, updatePlayer } from '../game js/game/player.js';
import { SKINS } from '../game js/game/content.js';
import { defaultProgress } from '../game js/game/save.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const GRAVITY = 75;

// Deterministic pseudo-random input script so the run exercises many branches.
function script(seed) {
  let s = seed;
  // Park-Miller: products stay below 2^53, so JS and Dart produce identical streams.
  const rnd = () => ((s = (s * 48271) % 2147483647) / 2147483647);
  const frames = [];
  let mx = 0, my = 0, jumpHeld = false;
  for (let f = 0; f < 1800; f++) {
    if (f % 30 === 0) {
      const r = rnd();
      mx = r < 0.3 ? -1 : r < 0.7 ? 1 : 0;
      const q = rnd();
      my = q < 0.2 ? -1 : q < 0.3 ? 1 : 0;
    }
    const jumpPressed = f % 47 === 0 || rnd() < 0.01;
    if (jumpPressed) jumpHeld = true;
    else if (rnd() < 0.08) jumpHeld = false;
    frames.push({ mx, my, jumpPressed, jumpHeld, dashPressed: rnd() < 0.01 });
  }
  return frames;
}

const out = [];
for (const [area, seed, skinIdx] of [[0, 1, 0], [0, 7, 4], [3, 3, 0], [5, 11, 4], [9, 5, 0]]) {
  loadArea(area);
  const start = WORLD.singles.find((o) => o.g === 'P');
  const p = createPlayer(start.x + 0.5, start.y + 1, { maxHp: 3, maxEnergy: 3 });
  const progress = defaultProgress();
  progress.abilities = { footing: true, dash: true };
  const g = { events: [], platforms: [], progress };
  const skin = SKINS[skinIdx];
  const tune = { skin, gravity: area === 10 ? 0.7 : 1, runSpeed: 7.5 * skin.speed, jumpV: Math.sqrt(2 * GRAVITY * 3.5) };
  const traj = [];
  for (const inp of script(seed)) {
    g.events.length = 0;
    updatePlayer(g, p, { ...inp, aiming: false }, 1 / 60, tune);
    traj.push([p.x, p.y, p.vx, p.vy, p.mode, p.onGround ? 1 : 0, p.anim]);
  }
  out.push({ area, seed, skin: skinIdx, start: [start.x + 0.5, start.y + 1], traj });
}
await fs.mkdir(path.join(root, 'test/fixtures'), { recursive: true });
await fs.writeFile(path.join(root, 'test/fixtures/player_ref.json'), JSON.stringify(out));
console.log('wrote', out.length, 'runs');
