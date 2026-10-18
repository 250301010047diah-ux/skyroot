import { createGame } from './game/game.js';
import { sanitizeProgress, skinOwned } from './game/save.js';
import manifest from './assets.json';
import tweaksManifest from './tweaks.json';
import { loadOfflineKits } from './offline-terrain.js';
import './styles.css';
import './android.css';

const bridge = window.SkyrootNative;
let game, audioContext, last = 0, frameId, accumulator = 0;
let suspended = false, tutorial = true, paused = false, muted = false;
const run = { frozen: true };
const changes = new Map();
const values = Object.fromEntries(Object.entries(tweaksManifest).map(([k, v]) => [k, v.value]));
const tweaks = {
  get: key => values[key],
  onChange: () => () => {},
  subscribe(key, fn) { const set = changes.get(key) || new Set(); set.add(fn); changes.set(key, set); return () => set.delete(fn); },
};
function report(error) {
  console.error('[skyroot]', error);
  run.frozen = true;
  document.querySelector('#fatal-message').textContent = error?.message || String(error);
  document.querySelector('#fatal').hidden = false;
}
window.addEventListener('error', e => report(e.error || e.message));
window.addEventListener('unhandledrejection', e => report(e.reason));
document.querySelector('#retry').onclick = () => location.reload();

function readSave() {
  try { return JSON.parse(bridge ? bridge.load() : localStorage.getItem('skyroot.v2')); }
  catch { return null; }
}
function save(progress = game?.state.progress) {
  if (!progress) return;
  const json = JSON.stringify(progress);
  if (bridge) bridge.save(json);
  else localStorage.setItem('skyroot.v2', json);
}
function syncPause() {
  run.frozen = suspended || tutorial || paused;
  last = 0;
  accumulator = 0;
  if (run.frozen) {
    window.dispatchEvent(new Event('blur'));
    if (game?.state.player) game.state.player.aiming = false;
    void audioContext?.suspend();
    save();
  } else if (!muted) void audioContext?.resume();
}
window.skyrootLifecycle = {
  pause() { suspended = true; syncPause(); },
  resume() { suspended = false; syncPause(); },
  save,
};
document.addEventListener('visibilitychange', () => {
  suspended = document.hidden;
  syncPause();
});
window.addEventListener('pagehide', () => { save(); cancelAnimationFrame(frameId); });
// Safe-area insets (CSS px) from the Android host: status bar, cutout and gesture bar.
function setSafeArea(top, right, bottom, left) {
  const root = document.documentElement.style;
  [['t', top], ['r', right], ['b', bottom], ['l', left]].forEach(([side, value]) => {
    const px = Number(value);
    if (value !== null && Number.isFinite(px) && px >= 0) root.setProperty(`--safe-${side}`, `${Math.min(px, 200)}px`);
  });
}
window.skyrootSetSafeArea = setSafeArea;
{
  const q = new URLSearchParams(location.search);
  if (q.has('safeTop')) setSafeArea(q.get('safeTop'), q.get('safeRight'), q.get('safeBottom'), q.get('safeLeft'));
}

const pauseMenu = document.querySelector('#pause-menu');
function setPaused(value) {
  paused = value;
  pauseMenu.hidden = !value;
  syncPause();
}
document.querySelector('#pause').onclick = () => setPaused(true);
document.querySelector('#resume').onclick = () => setPaused(false);
// Map from the pause menu: close the menu, then open the map through the HUD button.
document.querySelector('#map').onclick = () => {
  setPaused(false);
  document.querySelector('.map-btn')?.click();
};
document.querySelector('#home').onclick = () => { save(); bridge?.home(); };
document.querySelector('#respawn').onclick = () => { game?.respawn(); setPaused(false); };
document.querySelector('#help').onclick = () => {
  paused = false;
  pauseMenu.hidden = true;
  tutorial = true;
  document.querySelector('#tutorial').hidden = false;
  syncPause();
};
document.querySelector('#play').onclick = () => { tutorial = false; document.querySelector('#tutorial').hidden = true; syncPause(); };
// Android back button: toggles the pause menu instead of leaving mid-run.
window.skyrootBack = () => {
  if (!game || !document.querySelector('#fatal').hidden) { save(); bridge?.home(); return; }
  if (tutorial) { document.querySelector('#play').click(); return; }
  setPaused(!paused);
};
document.querySelector('#sound').onclick = () => {
  muted = !muted;
  const sound = document.querySelector('#sound');
  sound.textContent = muted ? 'Suara: Mati' : 'Suara: Aktif';
  sound.setAttribute('aria-pressed', String(muted));
  for (const key of ['sfxVolume', 'musicVolume']) {
    values[key] = muted ? 0 : tweaksManifest[key].value;
    changes.get(key)?.forEach(fn => fn());
  }
  if (!muted && !run.frozen) void audioContext?.resume();
};

async function start() {
  const saved = sanitizeProgress(readSave());
  const query = new URLSearchParams(location.search);
  const bounded = (name, fallback) => query.has(name) ? Math.max(0, Math.min(10, Number(query.get(name)) || 0)) : fallback;
  saved.area = Math.min(saved.unlocked, bounded('stage', saved.area));
  const requestedSkin = bounded('skin', saved.skin);
  if (skinOwned(saved, requestedSkin)) saved.skin = requestedSkin;
  const response = await fetch('/game/manifest.json');
  if (!response.ok) throw new Error('Manifest aset lokal tidak ditemukan.');
  const paths = await response.json();
  const assets = {
    pixelRatioLimit: query.get('quality') === 'detail' ? 2 : 1.5,
    get(key) { if (!paths[key]) throw new Error(`Aset tidak terdaftar: ${key}`); return paths[key]; },
    framesUrl: key => `/game/frames/${key}.json`,
    loadKits: () => loadOfflineKits(manifest),
  };
  const sdk = {
    gameState: { async save(progress) { save(progress); } },
    device: { haptics: { isSupported: () => false, vibrate() {} } },
    audio: { async getContext() {
      audioContext ||= new AudioContext();
      return { context: audioContext, unlock: () => run.frozen ? Promise.resolve() : audioContext.resume() };
    } },
  };
  game = createGame({ mount: document.querySelector('#app'), sdk, ready: {}, tweaks, assets, saved });
  game.setRun(run);
  game.hooks.init(game.state);
  document.querySelector('.game-root').classList.add('touch');
  const pauseButton = document.querySelector('#pause');
  document.querySelector('.hud-actions').append(pauseButton);
  pauseButton.hidden = false;
  document.querySelector('#tutorial').hidden = false;
  // Exposed only in debug Android builds or explicitly requested local QA.
  if (query.get('debug') === '1') window.__skyroot = { game, assets, run };
  function tick(time) {
    try {
      const dt = last ? Math.min((time - last) / 1000, 0.1) : 0;
      last = time;
      if (!run.frozen) {
        accumulator += dt;
        while (accumulator >= 1 / 60) {
          game.hooks.update(game.state, 1 / 60);
          accumulator -= 1 / 60;
        }
      }
      game.hooks.render(game.state);
      frameId = requestAnimationFrame(tick);
    } catch (error) { report(error); }
  }
  frameId = requestAnimationFrame(tick);
}
start().catch(report);
