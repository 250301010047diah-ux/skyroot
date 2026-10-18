// Android check: touch input, pause/resume and save. --all-areas also exercises
// every real map/wardrobe choice, restoring the original save afterwards.
// Requires the debug APK to be open on its game screen.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';

const adb = (...args) => execFileSync('adb', args, { encoding: 'utf8' }).trim();
const pid = adb('shell', 'pidof', 'com.example.skyroot');
if (!pid) throw new Error('Buka Skyroot debug dan masuk ke game terlebih dahulu.');
const port = adb('forward', 'tcp:0', `localabstract:webview_devtools_remote_${pid}`);
let ws;
try {
  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  const target = targets.find(t => t.url.includes('appassets.androidplatform.net/game/'));
  if (!target) throw new Error('Layar game belum terbuka.');
  ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  let id = 0;
  const pending = new Map(), errors = [];
  ws.onmessage = ({ data }) => {
    const msg = JSON.parse(data);
    if (msg.method === 'Runtime.exceptionThrown') errors.push(msg.params.exceptionDetails.text);
    const job = pending.get(msg.id);
    if (job) { pending.delete(msg.id); clearTimeout(job.timer); msg.error ? job.reject(msg.error) : job.resolve(msg.result); }
  };
  function command(method, params = {}) {
    return new Promise((resolve, reject) => {
      const key = ++id;
      const timer = setTimeout(() => { pending.delete(key); reject(new Error(`Timed out: ${method}`)); }, 10000);
      pending.set(key, { resolve, reject, timer });
      ws.send(JSON.stringify({ id: key, method, params }));
    });
  }
  const evaluate = async expression => {
    const result = await command('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
  const touch = (type, touchPoints) => command('Input.dispatchTouchEvent', { type, touchPoints });
  await command('Runtime.enable');
  assert.equal(await evaluate('document.hidden'), false, 'Skyroot must be in the foreground');
  const play = await evaluate(`(() => { const r=document.querySelector('#play').getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2,visible:!document.querySelector('#tutorial').hidden}; })()`);
  if (play.visible) {
    await touch('touchStart', [{ x: play.x, y: play.y, id: 1 }]);
    await touch('touchEnd', []);
  }
  const until = Date.now() + 25000;
  while (await evaluate('window.__skyroot?.game.state.phase') !== 'play') {
    if (Date.now() > until) throw new Error(await evaluate(`document.querySelector('#fatal-message').textContent || document.querySelector('.loading-msg').textContent`));
    await delay(200);
  }
  const before = await evaluate('({x:__skyroot.game.state.player.x,y:__skyroot.game.state.player.y})');
  const controls = await evaluate(`(() => { const center=s=>{const r=document.querySelector(s).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}};return {joy:center('.joy-zone'),jump:center('.act-jump'),bow:center('.act-bow')}; })()`);
  await touch('touchStart', [{ ...controls.joy, id: 1 }]);
  const moving = { x: controls.joy.x + 60, y: controls.joy.y, id: 1 };
  await touch('touchMove', [moving]);
  await delay(350);
  await touch('touchStart', [moving, { ...controls.jump, id: 2 }]);
  let after;
  const jumpDeadline = Date.now() + 1200;
  do {
    await delay(40);
    after = await evaluate('({x:__skyroot.game.state.player.x,y:__skyroot.game.state.player.y,vy:__skyroot.game.state.player.vy,mode:__skyroot.game.state.player.mode})');
  } while (after.vy >= 0 && Date.now() < jumpDeadline);
  await touch('touchEnd', []);
  assert.ok(after.x > before.x, 'Android touch joystick moves the player');
  assert.ok(after.vy < 0, 'Android multitouch jump works');
  await delay(500);
  await touch('touchStart', [{ ...controls.bow, id: 3 }]);
  await delay(250);
  await touch('touchEnd', []);
  await delay(40);
  assert.ok(await evaluate('__skyroot.game.state.arrows.length > 0'), 'Android bow creates an arrow');
  await evaluate('skyrootLifecycle.pause()');
  const time = await evaluate('__skyroot.game.state.t');
  await delay(200);
  assert.equal(await evaluate('__skyroot.game.state.t'), time, 'Pause freezes physics');
  await evaluate('skyrootLifecycle.resume()');
  const stats = await evaluate(`({ phase:__skyroot.game.state.phase, area:__skyroot.game.state.areaIndex, skin:__skyroot.game.state.progress.skin, assets:__skyroot.game.assetStatus(), error:document.querySelector('#fatal-message').textContent })`);
  assert.equal(stats.error, '');
  assert.deepEqual(errors, []);
  await fs.mkdir('artifacts', { recursive: true });
  // Capture before the optional tour restores and reloads the original save.
  await fs.writeFile('artifacts/android-gameplay.png', execFileSync('adb', ['exec-out', 'screencap', '-p'], { maxBuffer: 16 * 1024 * 1024 }));
  await fs.writeFile('artifacts/android-smoke.json', JSON.stringify({ before, after, ...stats, checks: ['touch-move', 'multitouch-jump', 'bow', 'pause-resume', 'no-runtime-errors'] }, null, 2));
  const areaChecks = [];
  if (process.argv.includes('--all-areas')) {
    const originalSave = await evaluate('SkyrootNative.load()');
    const waitPlay = async () => {
      const deadline = Date.now() + 25000;
      while (await evaluate('__skyroot.game.state.phase') !== 'play') {
        if (Date.now() > deadline) throw new Error('Area loading timed out');
        await delay(100);
      }
      await delay(100);
    };
    const tap = async selector => {
      const point = await evaluate(`(() => { const el=document.querySelector(${JSON.stringify(selector)}); el.scrollIntoView({block:'nearest'}); const r=el.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2,id:1}; })()`);
      await touch('touchStart', [point]);
      await touch('touchEnd', []);
      await delay(100);
    };
    try {
      await evaluate(`(() => { const {game}=__skyroot,s=game.state,p=s.player; p.mode='ledge';p.anim='ledge_climb';p.ledge={t:.41,sx:p.x,sy:p.y,fx:p.x,fy:p.y};game.hooks.update(s,1/60);game.hooks.render(s); })()`);
      for (let i = 0; i < 11; i++) {
        const start = Date.now();
        await tap('.map-btn');
        assert.equal(await evaluate('document.querySelectorAll("[data-area]").length'), 11);
        await tap(`[data-area="${i}"]`);
        await waitPlay();
        await tap('.wardrobe-btn');
        assert.equal(await evaluate('document.querySelectorAll(".skin-card:not(.locked)").length'), 11);
        const previous = await evaluate('__skyroot.game.state.progress.skin');
        await tap(`[data-skin="${i}"]`);
        if (previous !== i) await tap(`[data-skin="${i}"]`);
        else await tap('.wardrobe-close');
        await waitPlay();
        const current = await evaluate(`({area:__skyroot.game.state.areaIndex,skin:__skyroot.game.state.progress.skin,phase:__skyroot.game.state.phase,frames:__skyroot.game.assetStatus().sheets.length,fatal:document.querySelector('#fatal-message').textContent})`);
        assert.equal(current.area, i);
        assert.equal(current.skin, i);
        assert.equal(current.fatal, '');
        assert.ok(current.frames <= 20);
        areaChecks.push({ ...current, elapsedMs: Date.now() - start });
        console.log(JSON.stringify(areaChecks.at(-1)));
      }
      assert.deepEqual(errors, []);
    } finally {
      await evaluate(`skyrootLifecycle.pause();SkyrootNative.save(${JSON.stringify(originalSave)})`);
      await command('Page.reload');
    }
    await fs.writeFile('artifacts/android-all-areas.json', JSON.stringify(areaChecks, null, 2));
    console.log('All 11 areas and skins passed; original save restored.');
  }
  console.log(JSON.stringify({ before, after, ...stats }));
} finally {
  ws?.close();
  adb('forward', '--remove', `tcp:${port}`);
}
