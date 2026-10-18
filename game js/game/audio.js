// Sound: every effect and the music bed are loaded as MP3 files from the bundled
// game assets and played on the SDK-managed Web Audio context. Gameplay never waits
// for audio: it starts silent and joins once unlocked. Replace the dummy MP3s in
// assets/game/audio/ with real audio; the filenames must stay the same.

const AUDIO_BASE = "/game/audio/";
const SFX = [
  "relic", "jump", "land", "dash", "hurt", "shoot", "thunk", "sprout",
  "footfail", "noenergy", "crack", "crumble", "leaf", "launch", "spit", "lob",
  "splat", "defeat", "block", "checkpoint", "lift", "rope", "stomp",
  "nodeBreak", "bell", "pickup", "win",
];
const BGM_COUNT = 5;

export function createAudio(sdk, tweaks) {
  let audio = null;
  let ctx = null;
  let master = null;
  let sfxGain = null;
  let musicGain = null;
  let unlocking = false;

  let sfxBuffers = {};        // name -> AudioBuffer
  const bgmPending = {};
  let bgmBuffers = [];        // index -> AudioBuffer
  let bgmSource = null;
  let bgmIndex = 0;
  let wantMusic = false;
  let currentSemi = 0;

  function applyVolumes() {
    if (sfxGain) sfxGain.gain.value = Number(tweaks.get("sfxVolume"));
    if (musicGain) musicGain.gain.value = Number(tweaks.get("musicVolume"));
  }
  const unsubs = ["sfxVolume", "musicVolume"].map((k) => tweaks.subscribe(k, applyVolumes));

  function bgmForArea(semi) {
    return Math.abs(Math.round(semi)) % BGM_COUNT;
  }

  async function unlock() {
    if (ctx || unlocking) return;
    unlocking = true;
    try {
      audio = await sdk.audio.getContext();
      await audio.unlock();
      ctx = audio.context;
      master = ctx.createGain();
      master.gain.value = 0.9;
      master.connect(ctx.destination);
      sfxGain = ctx.createGain();
      sfxGain.connect(master);
      musicGain = ctx.createGain();
      musicGain.connect(master);
      applyVolumes();
      loadEffects();
      // Start the current area's track as soon as it is decoded, not after every sound.
      void ensureBgm(bgmForArea(currentSemi));
      syncMusic();
    } catch (err) {
      console.warn("[skyroot] audio unavailable", err);
    }
    unlocking = false;
  }

  async function decodeUrl(url) {
    try {
      const res = await fetch(url);
      if (!res.ok) return null;
      return await ctx.decodeAudioData(await res.arrayBuffer());
    } catch (err) {
      console.warn("[skyroot] failed to load audio", url, err);
      return null;
    }
  }

  // Effects are short, so they decode in the background without holding up music.
  function loadEffects() {
    SFX.forEach(async (name) => {
      const buf = await decodeUrl(`${AUDIO_BASE}${name}.mp3`);
      if (buf) sfxBuffers[name] = buf;
    });
  }

  // Music decodes one track at a time, and only the playing track stays in memory.
  // A decoded track is tens of MB of PCM, so keeping all five made the first start slow.
  function ensureBgm(index) {
    if (bgmBuffers[index]) return Promise.resolve(bgmBuffers[index]);
    if (!bgmPending[index]) {
      bgmPending[index] = decodeUrl(`${AUDIO_BASE}bgm${index + 1}.mp3`).then((buf) => {
        delete bgmPending[index];
        if (!buf) return null;
        bgmBuffers = [];
        bgmBuffers[index] = buf;
        syncMusic();
        return buf;
      });
    }
    return bgmPending[index];
  }

  function play(name) {
    if (!ctx || !sfxBuffers[name]) return;
    try {
      const src = ctx.createBufferSource();
      src.buffer = sfxBuffers[name];
      src.connect(sfxGain);
      src.start();
    } catch {
      // a failed effect never interrupts play
    }
  }

  function stopBgm() {
    if (!bgmSource) return;
    try {
      bgmSource.stop();
    } catch {
      // already stopped
    }
    bgmSource.disconnect();
    bgmSource = null;
  }

  function syncMusic() {
    if (!ctx) return;
    const target = bgmForArea(currentSemi);
    if (wantMusic) {
      if (bgmSource && bgmIndex === target) return; // already playing the right track
      stopBgm();
      const buf = bgmBuffers[target];
      if (!buf) {
        void ensureBgm(target);
        return;
      }
      bgmIndex = target;
      bgmSource = ctx.createBufferSource();
      bgmSource.buffer = buf;
      bgmSource.loop = true;
      bgmSource.connect(musicGain);
      bgmSource.start();
    } else {
      stopBgm();
    }
  }

  return {
    unlock,
    play,
    // Music now comes from the bundled BGM tracks; recomposition is no longer needed.
    composeMusic() {},
    // Each area maps to one of the BGM tracks; the track switches when the area changes.
    setArea(semi) {
      if (semi === currentSemi) return;
      currentSemi = semi;
      syncMusic();
    },
    setMusic(on) {
      if (wantMusic === on) return;
      wantMusic = on;
      syncMusic();
    },
    get ready() {
      return !!ctx;
    },
    destroy() {
      unsubs.forEach((u) => u());
      wantMusic = false;
      stopBgm();
    },
  };
}
