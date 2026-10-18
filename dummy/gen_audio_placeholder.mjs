// Generate valid, silent MP3 placeholders for the Skyroot replaceable audio set.
// No external encoder needed: we emit MPEG-1 Layer III frames (128 kbps, 44.1 kHz,
// mono) whose payload is zeroed, which every browser decodes to silence.
//
// Output: assets/game/audio/
//   <sfx>.mp3        - one file per sound effect used by the game
//   bgm1..bgm5.mp3    - five background music tracks
//
// Replace these dummy files with real audio later; the filenames must stay the same.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const out = path.join(root, "assets", "game", "audio");

// Sound effects actually referenced in game js/game/game.js via audio.play(...).
// Already de-duplicated: the game has no doubled variants like hit_boss / hit_enemy;
// each name below is a single, distinct effect.
const SFX = [
  "relic",
  "jump",
  "land",
  "dash",
  "hurt",
  "shoot",
  "thunk",
  "sprout",
  "footfail",
  "noenergy",
  "crack",
  "crumble",
  "leaf",
  "launch",
  "spit",
  "lob",
  "splat",
  "defeat",
  "block",
  "checkpoint",
  "lift",
  "rope",
  "stomp",
  "bossShoot",
  "nodeBreak",
  "bossHurt",
  "bell",
  "pickup",
];

const BGM_COUNT = 5;
const SAMPLE_RATE = 44100;
const FRAME_SAMPLES = 1152;
const FRAME_SIZE = Math.floor((144 * 128000) / SAMPLE_RATE); // 417 bytes
// MPEG-1 Layer III, 128 kbps, 44.1 kHz, mono, no CRC.
const HEADER = Buffer.from([0xff, 0xfb, 0x60, 0xc0]);

function silentMp3(seconds) {
  const frames = Math.max(1, Math.ceil((seconds * SAMPLE_RATE) / FRAME_SAMPLES));
  const buf = Buffer.alloc(frames * FRAME_SIZE);
  for (let i = 0; i < frames; i++) HEADER.copy(buf, i * FRAME_SIZE);
  return buf;
}

fs.mkdirSync(out, { recursive: true });

for (const name of SFX) {
  fs.writeFileSync(path.join(out, `${name}.mp3`), silentMp3(0.5));
}
for (let i = 1; i <= BGM_COUNT; i++) {
  fs.writeFileSync(path.join(out, `bgm${i}.mp3`), silentMp3(4));
}

console.log(
  `Created ${SFX.length} SFX placeholders + ${BGM_COUNT} BGM tracks in ${out}`,
);
