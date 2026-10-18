// Game content tables: the 11 areas, their monsters and bosses, and the 11 archer skins.

// Monster behaviours: diver (hover then swoop), flyer (drifts toward you), archer (lobs shots),
// hopper (leaps at you), dropper (drops on a thread, spits web), walkerLob (patrols, throws fire),
// radial (turret firing a ring of bolts).
export const MONSTERS = {
  bee: { name: "Lebah Kelopak", sheet: "MONSTERS_1", anim: "petal_bee", ai: "diver", hp: 2, w: 1.0, h: 1.0, size: 1.3, fly: true },
  twig: { name: "Pemburu Ranting", sheet: "MONSTERS_1", anim: "twig_hunter", ai: "archer", hp: 3, w: 0.9, h: 1.2, size: 1.45, shot: "twig_arrow" },
  leech: { name: "Lintah Getah", sheet: "MONSTERS_2", anim: "sap_leech", ai: "hopper", hp: 3, w: 1.3, h: 0.7, size: 1.4 },
  bat: { name: "Kelelawar Kristal", sheet: "MONSTERS_2", anim: "crystal_bat", ai: "flyer", hp: 2, w: 1.0, h: 0.8, size: 1.3, fly: true, speed: 3.4 },
  moth: { name: "Ngengat Lentera", sheet: "MONSTERS_3", anim: "lantern_moth", ai: "flyer", hp: 3, w: 1.1, h: 1.0, size: 1.5, fly: true, speed: 2.2, light: true },
  spider: { name: "Laba-laba Sutra", sheet: "MONSTERS_3", anim: "silk_spider", ai: "dropper", hp: 4, w: 1.0, h: 1.0, size: 1.6, fly: true, shot: "web_shot" },
  bird: { name: "Burung Badai", sheet: "MONSTERS_4", anim: "storm_bird", ai: "diver", hp: 3, w: 1.1, h: 1.0, size: 1.5, fly: true },
  salamander: { name: "Kadal Bara", sheet: "MONSTERS_4", anim: "ember_salamander", ai: "walkerLob", hp: 4, w: 1.6, h: 0.7, size: 1.9, shot: "fireball" },
  wisp: { name: "Roh Salju", sheet: "MONSTERS_5", anim: "frost_wisp", ai: "flyer", hp: 4, w: 1.0, h: 1.0, size: 1.4, fly: true, speed: 1.8, freeze: true },
  sentinel: { name: "Penjaga Bintang", sheet: "MONSTERS_5", anim: "star_sentinel", ai: "radial", hp: 6, w: 1.2, h: 1.3, size: 1.6, fly: true, shot: "star_bolt" },
};

// Boss attacks: spray (arcing shots), ring (bolts in every direction), shock (ground wave),
// rain (marked debris from above), charge (rush across the arena), summon (calls monsters),
// dive (flying swoop), beam (marked lightning columns).
export const BOSSES = [
  null, // Akar Berkabut uses the Tower Stag (boss.js)
  { name: "Ratu Anggrek", sheet: "BOSS_1", anim: "orchid_queen", hp: 30, height: 6.5, attacks: ["spray", "rain"], p2: ["summon"], shot: "petal_blade" },
  { name: "Golem Lonceng", sheet: "BOSS_2", anim: "bell_golem", hp: 42, height: 6.5, attacks: ["shock", "charge"], p2: ["ring"], shot: "lightning_orb" },
  { name: "Raja Katak Getah", sheet: "BOSS_3", anim: "sap_toad_king", hp: 52, height: 6, attacks: ["spray", "shock"], p2: ["rain"], shot: "sap_glob" },
  { name: "Ular Kristal", sheet: "BOSS_4", anim: "crystal_serpent", hp: 62, height: 7, attacks: ["ring", "charge"], p2: ["spray"], shot: "crystal_shard" },
  { name: "Induk Jamur", sheet: "BOSS_5", anim: "mother_mushroom", hp: 72, height: 7, attacks: ["spray", "summon"], p2: ["rain"], shot: "spore_ball" },
  { name: "Ratu Laba-laba", sheet: "BOSS_6", anim: "spider_queen", hp: 84, height: 6.5, fly: true, attacks: ["spray", "dive"], p2: ["summon"], shot: "web_shot" },
  { name: "Elang Petir", sheet: "BOSS_7", anim: "thunder_eagle", hp: 96, height: 6, fly: true, attacks: ["beam", "dive"], p2: ["ring"], shot: "lightning_orb" },
  { name: "Penjaga Tungku", sheet: "BOSS_8", anim: "forge_guardian", hp: 112, height: 7, attacks: ["spray", "shock"], p2: ["rain"], shot: "fireball" },
  { name: "Beruang Es Akar", sheet: "BOSS_9", anim: "frost_bear", hp: 130, height: 6, attacks: ["charge", "rain"], p2: ["ring"], shot: "ice_shard" },
  { name: "Jantung Kabut", sheet: "BOSS_10", anim: "mist_heart", hp: 180, height: 7, fly: true, attacks: ["ring", "beam", "summon"], p2: ["rain"], p3: ["spray"], shot: "mist_orb" },
];

// Terrain colours recolour the Akar Berkabut kits per area.
export const AREAS = [
  { name: "Akar Berkabut", bg: "BACKDROP", monster: null, tint: null, music: 0 },
  { name: "Kebun Gantung", bg: "BG_1", monster: "bee", bark: "#6e4a4f", soft: "#d9a3b4", gim: "petal", music: 2 },
  { name: "Kota Kulit Pohon", bg: "BG_2", monster: "twig", bark: "#6a4a2a", soft: "#d6a663", gim: "gear", music: 5 },
  { name: "Rawa Getah", bg: "BG_3", monster: "leech", bark: "#4b4a26", soft: "#c9a046", gim: "sap", music: -2 },
  { name: "Gua Kristal Akar", bg: "BG_4", monster: "bat", bark: "#3d3352", soft: "#9a8fc6", gim: "crystal", music: 3 },
  { name: "Hutan Jamur Senja", bg: "BG_5", monster: "moth", bark: "#5a3a3e", soft: "#d08a5c", gim: "mushroom", music: -4 },
  { name: "Sarang Sutra", bg: "BG_6", monster: "spider", bark: "#5a5560", soft: "#d4cfd8", gim: "web", music: 1 },
  { name: "Lautan Awan", bg: "BG_7", monster: "bird", bark: "#6b6458", soft: "#e8e2d0", gim: "cloud", music: 7 },
  { name: "Reruntuhan Bara", bg: "BG_8", monster: "salamander", bark: "#4a2c24", soft: "#c4683e", gim: "ember", music: -5 },
  { name: "Puncak Beku", bg: "BG_9", monster: "wisp", bark: "#4f5c6b", soft: "#c8dce8", gim: "ice", music: 4 },
  { name: "Mahkota Bintang", bg: "BG_10", monster: "sentinel", bark: "#2f3550", soft: "#d8c27a", gim: "star", music: 9, gravity: 0.7 },
];

// Every skin keeps all earlier perks and adds its own (cumulative), so a higher tier is always stronger.
const RAW_SKINS = [
  { name: "Ranger", sheets: ["ARCHER_A", "ARCHER_B", "ARCHER_C"], arrow: "arrow", perk: "Pemanah dasar", add: {} },
  { name: "Pemburu Embun", perk: "Lari +15%, tarikan busur lebih cepat", arrow: "arrow", add: { speed: 1.15, draw: 0.75 } },
  { name: "Penjaga Duri", perk: "Panah menembus 1 musuh, +1 nyawa", arrow: "arrow", add: { pierce: 1, hp: 1 } },
  { name: "Pemanah Kembar", perk: "Tembak 2 panah sekaligus", arrow: "arrow", add: { shots: 2 } },
  { name: "Penari Angin", perk: "Lompat ganda, dash udara 2x", arrow: "arrow", add: { doubleJump: true, airDashes: 2 } },
  { name: "Pemanah Bara", perk: "Panah membakar, tarikan penuh +1 damage", arrow: "fire_arrow", add: { burn: true, dmg: 1 } },
  { name: "Pemanah Es", perk: "Panah memperlambat · Skill Hujan Es", arrow: "ice_arrow", add: { slow: true, skill: "icerain" } },
  { name: "Pemanah Badai", perk: "Tembak 3 panah, petir berantai · Skill Panggil Petir", arrow: "storm_arrow", add: { shots: 3, chain: true, skill: "thunder" } },
  { name: "Pemanah Bulan", perk: "Panah mengejar, Fokus Udara 2x · Skill Bayangan Kembar", arrow: "moon_arrow", add: { homing: true, focus: 2, skill: "clone" } },
  { name: "Pemanah Bintang", perk: "3 panah tembus 2, +1 energi · Skill Hujan Bintang", arrow: "star_arrow", add: { pierce: 2, energy: 1, skill: "starrain" } },
  { name: "Mahkota Akar", perk: "5 panah kipas, +2 nyawa · Skill Penjaga Akar", arrow: "star_arrow", add: { shots: 5, hp: 2, dmg: 2, skill: "guardian" } },
];

const BASE = { speed: 1, draw: 1, pierce: 0, hp: 0, shots: 1, doubleJump: false, airDashes: 1, burn: false, dmg: 0, slow: false, chain: false, homing: false, focus: 1, energy: 0, skill: null };

export const SKINS = (() => {
  const out = [];
  let acc = { ...BASE };
  RAW_SKINS.forEach((s, i) => {
    const a = s.add;
    acc = {
      ...acc,
      speed: a.speed ?? acc.speed,
      draw: a.draw ?? acc.draw,
      pierce: a.pierce ?? acc.pierce,
      hp: acc.hp + (a.hp || 0),
      shots: a.shots ?? acc.shots,
      doubleJump: a.doubleJump ?? acc.doubleJump,
      airDashes: a.airDashes ?? acc.airDashes,
      burn: a.burn ?? acc.burn,
      dmg: acc.dmg + (a.dmg || 0),
      slow: a.slow ?? acc.slow,
      chain: a.chain ?? acc.chain,
      homing: a.homing ?? acc.homing,
      focus: a.focus ?? acc.focus,
      energy: acc.energy + (a.energy || 0),
      skill: a.skill ?? acc.skill,
    };
    out.push({
      id: i,
      name: s.name,
      perk: s.perk,
      arrow: s.arrow,
      sheets: s.sheets || [`SKIN${i}_A`, `SKIN${i}_B`, `SKIN${i}_C`],
      icon: `skin_${i}`,
      ...acc,
    });
  });
  return out;
})();

export const SKILL_NAMES = { icerain: "Hujan Es", thunder: "Panggil Petir", clone: "Bayangan Kembar", starrain: "Hujan Bintang", guardian: "Penjaga Akar" };
