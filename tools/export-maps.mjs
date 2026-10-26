// Exports the ASCII area maps from the JS source to assets/game/maps.json so the
// Dart engine can load them. Run once: node tools/export-maps.mjs
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ALL_MAPS } from '../game js/game/world.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
await fs.writeFile(path.join(root, 'assets/game/maps.json'), JSON.stringify(ALL_MAPS));
console.log('maps:', ALL_MAPS.length, ALL_MAPS.map((m) => `${m[0].length}x${m.length}`).join(' '));
