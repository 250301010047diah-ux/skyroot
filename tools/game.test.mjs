import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { ALL_MAPS, WORLD, loadArea } from '../game js/game/world.js';
import { SKINS } from '../game js/game/content.js';
import { TILE_MASKS } from '../game js/offline-terrain.js';
import sharp from 'sharp';
import { createPlayer, updatePlayer, hurtPlayer, ledgeDrawPos } from '../game js/game/player.js';
import { defaultProgress, sanitizeProgress, skinsOwned } from '../game js/game/save.js';

test('all content opens without faking boss victories, including old saves', () => {
  for (const progress of [defaultProgress(), sanitizeProgress({ ...defaultProgress(), unlocked: 0 })]) {
    assert.equal(progress.unlocked, 10);
    assert.equal(skinsOwned(progress), 11);
    assert.ok(progress.areas.every(a => !a.boss));
  }
});

test('ledge completion and damage select a valid animation in the same frame', () => {
  const p = createPlayer(5, 10, { maxHp: 3, maxEnergy: 3 });
  const g = { events: [], platforms: [] };
  p.mode = 'ledge'; p.anim = 'ledge_climb';
  p.ledge = { t: 0.41, sx: 5, sy: 10, fx: 6, fy: 9 };
  updatePlayer(g, p, {}, 1 / 60, {});
  assert.equal(p.ledge, null);
  assert.equal(p.mode, 'normal');
  assert.equal(p.anim, 'land');
  assert.deepEqual(ledgeDrawPos(p), { x: 6, y: 9, e: 1 });
  p.mode = 'ledge'; p.anim = 'ledge_climb';
  p.ledge = { t: 0.2, sx: 6, sy: 9, fx: 7, fy: 8 };
  hurtPlayer(g, p, 1, 0);
  assert.equal(p.ledge, null);
  assert.equal(p.anim, 'hurt');
});

test('vines catch at the lower tip, climb up, and release at the top or on jump', () => {
  loadArea(0);
  const vine = WORLD.vines.find(v => v.x === 19);
  const p = createPlayer(vine.x + 1.1, vine.y1 + 2, { maxHp: 3, maxEnergy: 3 });
  const g = { events: [], platforms: [], progress: defaultProgress() };
  const tune = { skin: SKINS[0], gravity: 1, runSpeed: 7, jumpV: 23 };
  const up = { mx: 0, my: -1, jumpHeld: false };
  updatePlayer(g, p, up, 1 / 60, tune);
  assert.equal(p.mode, 'climb', 'Head can reach the bottom tip from slightly off center');
  assert.equal(p.anim, 'climb');
  const startY = p.y;
  for (let i = 0; i < 60; i++) updatePlayer(g, p, up, 1 / 60, tune);
  assert.ok(p.y < startY - 4, 'Holding up moves upwards');
  const pauseY = p.y;
  for (let i = 0; i < 15; i++) updatePlayer(g, p, { mx: 0, my: 0 }, 1 / 60, tune);
  assert.equal(p.y, pauseY, 'Neutral joystick holds position on the vine');
  for (let i = 0; i < 15; i++) updatePlayer(g, p, { mx: 0, my: 1 }, 1 / 60, tune);
  assert.ok(p.y > pauseY, 'Down descends');
  let clearedTop = false;
  for (let i = 0; i < 300; i++) {
    updatePlayer(g, p, up, 1 / 60, tune);
    if (p.mode === 'normal' && p.y < vine.y0) { clearedTop = true; break; }
  }
  assert.ok(clearedTop, 'Holding up clears the top instead of reattaching every frame');
  Object.assign(p, { x: vine.x + 0.5, y: vine.y0 + 5, mode: 'climb', climbX: vine.x, climbCooldown: 0 });
  const x = p.x;
  updatePlayer(g, p, { ...up, mx: 1, jumpPressed: true, jumpHeld: true }, 1 / 60, tune);
  for (let i = 0; i < 10; i++) updatePlayer(g, p, { ...up, mx: 1, jumpHeld: true }, 1 / 60, tune);
  assert.equal(p.mode, 'normal');
  assert.ok(p.x > x + 0.7, 'Jumping sideways can leave the vine even with up held');
});

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
test('all maps, asset keys and reconstructed frames are bundled', async () => {
  const manifest = JSON.parse(await fs.readFile(path.join(root, 'game js/assets.json')));
  const local = JSON.parse(await fs.readFile(path.join(root, 'assets/game/manifest.json')));
  const audit = JSON.parse(await fs.readFile(path.join(root, 'assets/game/audit.json')));
  assert.deepEqual(Object.keys(local), Object.keys(manifest));
  assert.equal(ALL_MAPS.length, 11);
  for (const rows of ALL_MAPS) {
    assert.ok(rows.some(row => row.includes('P')), 'Each area needs a player spawn');
    assert.ok(rows.some(row => row.includes('O')), 'Each area needs a boss');
  }
  for (const asset of audit.assets) {
    await fs.access(path.join(root, 'assets', local[asset.key]));
    if (!asset.frames) continue;
    const metadata = JSON.parse(await fs.readFile(path.join(root, 'assets/game/frames', `${asset.key}.json`)));
    assert.equal(metadata.frames.length, asset.frames);
    assert.equal(new Set(metadata.frames.map(f => f.name)).size, asset.frames);
    for (const { content: c, source: s } of metadata.frames) {
      assert.ok(c.w > 0 && c.h > 0);
      assert.ok(c.x >= s.x && c.y >= s.y && c.x + c.w <= s.x + s.w && c.y + c.h <= s.y + s.h);
      assert.ok(s.x + s.w <= asset.width && s.y + s.h <= asset.height);
    }
  }
});

test('terrain atlas connectivity and platform slicing match the original renderer', async () => {
  assert.equal(TILE_MASKS.length, 47);
  const { data, info } = await sharp(path.join(root, 'assets/images/atlas.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  // The alpha at the midpoint of each atlas edge identifies connected neighbors.
  for (const [index, mask] of TILE_MASKS.entries()) {
    for (const [dx, dy, bit] of [[130, 4, 1], [255, 130, 4], [130, 255, 16], [4, 130, 64]]) {
      const x = (index % 12) * 260 + dx, y = Math.floor(index / 12) * 260 + dy;
      assert.equal(data[(y * info.width + x) * 4 + 3] > 200, !!(mask & bit), `Tile ${index}, edge ${bit}`);
    }
  }
  const branch = JSON.parse(await fs.readFile(path.join(root, 'assets/game/frames/BRANCH_TILES.json')));
  assert.deepEqual(branch.frames.map(f => f.source.w), [224, 672, 224]);
  assert.ok(branch.frames.every(f => Number.isFinite(f.surfaceY)));
  const vine = JSON.parse(await fs.readFile(path.join(root, 'assets/game/frames/VINE_TILES.json')));
  assert.ok(vine.frames[1].content.h > vine.frames[1].content.w * 4, 'Climbing body is vertical');
});

test('original runtime: all areas/skins, input, audio, lifecycle and saves', { timeout: 180_000 }, async () => {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const file = path.resolve(root, 'assets', '.' + decodeURIComponent(url.pathname));
    if (!file.startsWith(path.join(root, 'assets') + path.sep)) { res.writeHead(403).end(); return; }
    try {
      const data = await fs.readFile(file);
      res.setHeader('Content-Type', ({ '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.json': 'application/json', '.webp': 'image/webp', '.png': 'image/png' })[path.extname(file)] || 'application/octet-stream');
      res.end(data);
    } catch { res.writeHead(404).end(); }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ channel: 'msedge', headless: true });
    const page = await browser.newPage({ viewport: { width: 412, height: 860 }, hasTouch: true, deviceScaleFactor: 2 });
    await page.addInitScript(() => {
      const draw = CanvasRenderingContext2D.prototype.drawImage;
      CanvasRenderingContext2D.prototype.drawImage = function(image, ...numbers) {
        if (numbers.some(value => !Number.isFinite(value))) throw new Error('Non-finite sprite coordinates: ' + numbers.join(','));
        return draw.call(this, image, ...numbers);
      };
    });
    const errors = [], failed = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
    page.on('response', r => { if (r.status() >= 400) failed.push(r.url()); });
    const url = `http://127.0.0.1:${server.address().port}/game/index.html?debug=1`;
    await page.goto(url);
    await page.locator('#play').click();
    await page.waitForFunction(() => window.__skyroot?.game.state.phase === 'play');
    await page.waitForFunction(() => document.querySelector('.loading').hidden);
    assert.equal(await page.locator('.game-surface').evaluate(c => c.width), 618, 'Light mode limits render resolution while preserving CSS controls');
    assert.equal(await page.evaluate(() => __skyroot.game.state.progress.unlocked), 10);
    assert.equal(await page.evaluate(() => __skyroot.game.state.progress.abilities.dash), false);
    await fs.mkdir(path.join(root, 'artifacts'), { recursive: true });
    await page.screenshot({ path: path.join(root, 'artifacts/original-game.png') });
    const x = await page.evaluate(() => __skyroot.game.state.player.x);
    await page.keyboard.down('KeyD');
    await page.waitForTimeout(350);
    await page.keyboard.up('KeyD');
    assert.ok(await page.evaluate(x => __skyroot.game.state.player.x > x, x), 'Keyboard moves the player');
    await page.keyboard.down('Space');
    await page.waitForTimeout(100);
    assert.ok(await page.evaluate(() => __skyroot.game.state.player.vy < 0), 'Jump has upward velocity');
    await page.keyboard.up('Space');
    await page.keyboard.down('KeyJ');
    await page.waitForTimeout(350);
    await page.keyboard.up('KeyJ');
    await page.waitForTimeout(50);
    assert.ok(await page.evaluate(() => __skyroot.game.state.arrows.length > 0), 'Bow creates an arrow');
    await page.evaluate(() => skyrootLifecycle.pause());
    const before = await page.evaluate(() => __skyroot.game.state.t);
    await page.waitForTimeout(150);
    assert.equal(await page.evaluate(() => __skyroot.game.state.t), before, 'Pause stops simulation');
    await page.evaluate(() => skyrootLifecycle.resume());
    // Real touch events: hold the floating joystick while another finger jumps.
    await page.evaluate(() => __skyroot.game.respawn());
    await page.waitForTimeout(150);
    const cdp = await page.context().newCDPSession(page);
    const joy = await page.locator('.joy-zone').boundingBox();
    const jump = await page.locator('.act-jump').boundingBox();
    const jx = joy.x + joy.width / 2, jy = joy.y + joy.height / 2;
    const startX = await page.evaluate(() => __skyroot.game.state.player.x);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: jx, y: jy, id: 1 }] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: jx + 48, y: jy, id: 1 }] });
    await page.waitForTimeout(200);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: jx + 48, y: jy, id: 1 }, { x: jump.x + jump.width / 2, y: jump.y + jump.height / 2, id: 2 }] });
    await page.waitForTimeout(100);
    assert.ok(await page.evaluate(x => __skyroot.game.state.player.x > x, startX), 'Touch joystick moves');
    assert.ok(await page.evaluate(() => __skyroot.game.state.player.vy < 0), 'Multitouch jump works');
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
    // Reproduce the actual Android crash at the final ledge-climb update/render.
    await page.evaluate(() => {
      const { game } = __skyroot, s = game.state, p = s.player;
      p.mode = 'ledge'; p.anim = 'ledge_climb';
      p.ledge = { t: 0.41, sx: p.x, sy: p.y, fx: p.x, fy: p.y };
      game.hooks.update(s, 1 / 60);
      game.hooks.render(s);
    });
    await page.evaluate(() => {
      const s = __skyroot.game.state;
      Object.assign(s.player, { x: 19.5, y: 98, vx: 0, vy: 0, mode: 'normal', ledge: null, anim: 'idle', climbCooldown: 0 });
      s.cam.snap = true;
    });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: jx, y: jy, id: 1 }] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: jx, y: jy - 48, id: 1 }] });
    await page.waitForFunction(() => __skyroot.game.state.player.mode === 'climb' && __skyroot.game.state.player.y < 97);
    await page.screenshot({ path: path.join(root, 'artifacts/climbing.png') });
    await page.waitForFunction(() => __skyroot.game.state.player.mode === 'normal' && __skyroot.game.state.player.y < 83, null, { timeout: 15000 });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
    for (let i = 0; i < 11; i++) {
      await page.waitForFunction(() => __skyroot.game.state.phase === 'play');
      await page.locator('.map-btn').click();
      assert.equal(await page.locator('[data-area]').count(), 11);
      await page.locator(`[data-area="${i}"]`).click();
      await page.waitForFunction(() => __skyroot.game.state.phase === 'play');
      await page.locator('.wardrobe-btn').click();
      assert.equal(await page.locator('.skin-card:not(.locked)').count(), 11);
      await page.locator(`[data-skin="${i}"]`).click();
      if (i > 0) await page.locator(`[data-skin="${i}"]`).click();
      else await page.locator('.wardrobe-close').click();
      await page.waitForFunction(i => __skyroot.game.state.areaIndex === i && __skyroot.game.state.phase === 'play' && __skyroot.game.state.progress.skin === i, i);
      await page.waitForFunction(i => {
        const loaded = __skyroot.game.assetStatus().sheets;
        return ['A', 'B', 'C'].every(s => loaded.includes(i === 0 ? `ARCHER_${s}` : `SKIN${i}_${s}`));
      }, i);
      await page.waitForTimeout(150);
      // Draw every vertical part of each original map, including the boss arena.
      // This catches invisible branches (NaN surfaceY) and missing prop frames
      // that a spawn-only smoke test misses.
      await page.evaluate(() => {
        const { game, run } = __skyroot;
        run.frozen = true;
        const s = game.state;
        // Exercise every original character animation, including all three sheets.
        const p = s.player;
        p.invuln = 0;
        p.ledge = { t: 0.2, sx: p.x, sy: p.y, fx: p.x + 0.5, fy: p.y - 1 };
        for (const anim of ['idle', 'run', 'jump', 'fall', 'dash', 'climb', 'aim', 'release', 'hurt', 'ledge_climb', 'wall_slide', 'land', 'defeat']) {
          p.anim = anim;
          for (let f = 0; f < 6; f++) {
            p.animT = f / 7; p.climbT = f / 9; p.aimT = f * 0.12; p.deadT = f / 5;
            game.hooks.render(s);
          }
        }
        for (let y = 8; y < game.state.rows; y += 8) {
          game.state.cam = { x: 20, y, zoom: 1 };
          game.hooks.render(game.state);
        }
        // Explicitly render living boss attack states.
        s.cam = { x: s.boss.x - 2, y: s.boss.y - 2, zoom: 1 };
        for (const state of ['idle', 'shoot', 'stomp', 'stunned', 'spray', 'ring', 'charge', 'rain', 'tired']) {
          s.boss.state = state;
          for (let f = 0; f < 6; f++) {
            s.boss.animT = f / 6; s.boss.t = 0.4;
            game.hooks.render(s);
          }
        }
        game.respawn();
        run.frozen = false;
      });
      assert.equal(await page.locator('#fatal').isVisible(), false, `Area/skin ${i} renders`);
    }
    const loaded = await page.evaluate(() => __skyroot.game.assetStatus());
    assert.equal(loaded.visited.sheets.length, 60);
    assert.equal(loaded.visited.singles.length, 12);
    assert.ok(loaded.sheets.length <= 20, 'Previous area/skin textures are released');
    assert.ok(loaded.singles.length <= 3);
    assert.ok(await page.evaluate(() => __skyroot.game.state.progress.areas.every(a => !a.boss)), 'Unlocking does not defeat bosses');
    await page.evaluate(() => skyrootLifecycle.save());
    const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('skyroot.v2')));
    assert.equal(saved.area, 10);
    assert.equal(saved.skin, 10);
    await page.reload();
    await page.locator('#play').click();
    await page.waitForFunction(() => window.__skyroot?.game.state.phase === 'play');
    assert.equal(await page.evaluate(() => __skyroot.game.state.areaIndex), 10);
    assert.equal(await page.evaluate(() => __skyroot.game.state.progress.skin), 10);
    assert.deepEqual(failed, []);
    assert.deepEqual(errors, []);
    await page.goto(url + '&quality=detail');
    await page.locator('#play').click();
    await page.waitForFunction(() => __skyroot.game.state.phase === 'play');
    assert.equal(await page.locator('.game-surface').evaluate(c => c.width), 824, 'Detail mode restores full device density');

    // Failed and delayed assets must freeze gameplay, keep a useful retry UI,
    // and recover without a reload or a half-loaded fallback character.
    const retryPage = await browser.newPage({ viewport: { width: 412, height: 860 }, hasTouch: true });
    const retryErrors = [];
    retryPage.on('pageerror', error => retryErrors.push(error.message));
    let coreAttempts = 0;
    await retryPage.route('**/frames/EFFECTS.json', route => {
      if (++coreAttempts === 1) return route.fulfill({ status: 503, body: 'QA: missing core frames' });
      return route.continue();
    });
    await retryPage.goto(url);
    await retryPage.locator('#play').click();
    const waitError = () => retryPage.waitForFunction(() => __skyroot.game.state.loadingError);
    const waitPlay = () => retryPage.waitForFunction(() => __skyroot.game.state.phase === 'play');
    await waitError();
    assert.equal(await retryPage.locator('#fatal').isVisible(), false);
    await retryPage.locator('.loading').click();
    await waitPlay();
    assert.equal(coreAttempts, 2, 'Core retry makes a new request');

    let areaAttempts = 0;
    await retryPage.route('**/frames/BOSS_5.json', route => {
      if (++areaAttempts === 1) return route.fulfill({ status: 503, body: 'QA: missing boss frames' });
      return route.continue();
    });
    await retryPage.evaluate(() => __skyroot.game.travelTo(5));
    await waitError();
    await retryPage.waitForTimeout(250);
    assert.match(await retryPage.locator('.loading-msg').textContent(), /Gagal memuat.*coba lagi/);
    assert.equal(await retryPage.evaluate(() => __skyroot.game.state.t), 0, 'Area physics waits for boss frames');
    await retryPage.locator('.loading').click();
    await waitPlay();
    assert.equal(areaAttempts, 2);

    let skinAttempts = 0;
    await retryPage.route('**/frames/SKIN2_C.json', route => {
      if (++skinAttempts === 1) return route.fulfill({ status: 503, body: 'QA: missing skin frames' });
      return route.continue();
    });
    await retryPage.evaluate(() => __skyroot.game.equipSkin(2));
    await waitError();
    assert.equal(await retryPage.evaluate(() => __skyroot.game.state.phase), 'loading');
    await retryPage.locator('.loading').click();
    await waitPlay();
    assert.equal(skinAttempts, 2);

    let releaseSkin;
    const skinGate = new Promise(resolve => { releaseSkin = resolve; });
    await retryPage.route('**/frames/SKIN3_B.json', async route => { await skinGate; await route.continue(); });
    await retryPage.evaluate(() => __skyroot.game.equipSkin(3));
    const loadingTime = await retryPage.evaluate(() => __skyroot.game.state.t);
    await retryPage.waitForTimeout(350);
    assert.equal(await retryPage.evaluate(() => __skyroot.game.state.phase), 'loading');
    assert.equal(await retryPage.evaluate(() => __skyroot.game.state.t), loadingTime);
    releaseSkin();
    await waitPlay();

    let releaseArea, areaRequested;
    const areaGate = new Promise(resolve => { releaseArea = resolve; });
    const requested = new Promise(resolve => { areaRequested = resolve; });
    await retryPage.route('**/frames/BOSS_7.json', async route => { areaRequested(); await areaGate; await route.continue(); });
    await retryPage.evaluate(() => __skyroot.game.travelTo(7));
    await requested;
    await retryPage.evaluate(() => __skyroot.game.travelTo(8));
    await waitPlay();
    releaseArea();
    await retryPage.waitForTimeout(300);
    assert.equal(await retryPage.evaluate(() => __skyroot.game.state.areaIndex), 8, 'An older load cannot replace the latest area');
    assert.equal(await retryPage.locator('#fatal').isVisible(), false);
    assert.deepEqual(retryErrors, []);

    await retryPage.evaluate(() => __skyroot.game.resetProgress());
    await waitPlay();
    assert.equal(await retryPage.evaluate(() => __skyroot.game.state.progress.unlocked), 10);
    await retryPage.goto(url + '&stage=10&skin=10');
    await retryPage.locator('#play').click();
    await waitPlay();
    assert.deepEqual(await retryPage.evaluate(() => ({ area: __skyroot.game.state.areaIndex, skin: __skyroot.game.state.progress.skin, abilities: __skyroot.game.state.progress.abilities })),
      { area: 10, skin: 10, abilities: { footing: true, dash: true } });
    await retryPage.close();
  } finally {
    await browser?.close();
    await new Promise(resolve => server.close(resolve));
  }
});
