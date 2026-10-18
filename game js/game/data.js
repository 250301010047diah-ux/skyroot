// Game content: heroes, enemies, bosses, stages, upgrades and the wave recipe.
// Pure data + one pure builder — no DOM, no state mutation.

export const WORLD_H = 640; // virtual height the camera fits (world units)

// Every animation row in every sheet is exactly 5 frames.
export const FRAMES_PER_ANIM = 5;

export const HEROES = {
  ranger: {
    name: "Ranger", weapon: "Busur", sheetA: "HERO_RANGER_A", sheetB: "HERO_RANGER_B",
    proj: "arrow", dmg: 10, cd: 0.42, speed: 780, charge: true, gemCost: 0,
    perk: "Tahan lama = panah charge", special: "fire", specialName: "Panah Api",
  },
  gunner: {
    name: "Gunner", weapon: "Pistol", sheetA: "HERO_GUNNER_A", sheetB: "HERO_GUNNER_B",
    proj: "bullet", dmg: 4, cd: 0.11, speed: 920, auto: true, mag: 14, reload: 1.1, gemCost: 5,
    perk: "Tahan = tembak otomatis", special: "ice", specialName: "Peluru Es",
  },
  bomber: {
    name: "Bomber", weapon: "Bazooka", sheetA: "HERO_BOMBER_A", sheetB: "HERO_BOMBER_B",
    proj: "rocket", dmg: 16, cd: 0.25, speed: 440, aoe: 54, mag: 1, reload: 1.15, gemCost: 8,
    perk: "Ledakan area", special: "burn", specialName: "Roket Api",
  },
  hunter: {
    name: "Hunter", weapon: "Crossbow", sheetA: "HERO_HUNTER_A", sheetB: "HERO_HUNTER_B",
    proj: "bolt", dmg: 13, cd: 0.68, speed: 860, pierce: 3, gemCost: 10,
    perk: "Tembus 3 musuh", special: "lightning", specialName: "Baut Petir",
  },
  mage: {
    name: "Mage", weapon: "Tongkat Sihir", sheetA: "HERO_MAGE_A", sheetB: "HERO_MAGE_B",
    proj: "fireball", dmg: 7, cd: 0.52, speed: 540, burn: 5, gemCost: 12,
    perk: "Membakar musuh", special: "bigburn", specialName: "Api Neraka",
  },
  ninja: {
    name: "Ninja", weapon: "Shuriken", sheetA: "HERO_NINJA_A", sheetB: "HERO_NINJA_B",
    proj: "shuriken", dmg: 6, cd: 0.48, speed: 720, shots: 3, spread: 0.22, gemCost: 15,
    perk: "3 shuriken sekaligus", special: "poison", specialName: "Shuriken Racun",
  },
};
export const HERO_ORDER = ["ranger", "gunner", "bomber", "hunter", "mage", "ninja"];
export const WEAPON_LEVEL_COST = [0, 60, 150, 300, 500]; // coins for level 2..5

// kind: climber walks then climbs; ground stays at the base; flyer flies.
// size: world units for one 320px sheet cell. rows maps role -> sheet row.
export const ENEMIES = {
  goblin: { name: "Goblin", sheet: "ENEMY_GOBLIN", kind: "climber", size: 62, hp: 20, walk: 42, climb: 26, dmg: 8, coin: 2,
    rows: { walk: "walk", climb: "climb", top: "attack", death: "death" } },
  monkey: { name: "Monyet", sheet: "ENEMY_MONKEY", kind: "climber", size: 58, hp: 14, walk: 74, climb: 48, dmg: 6, coin: 2, leap: true,
    rows: { walk: "walk", climb: "climb", top: "leap", leap: "leap", death: "death" } },
  orc: { name: "Orc", sheet: "ENEMY_ORC", kind: "climber", size: 80, hp: 85, walk: 26, climb: 14, dmg: 15, coin: 6,
    rows: { walk: "walk", climb: "climb", top: "attack", death: "death" } },
  shield: { name: "Perisai", sheet: "ENEMY_SHIELD", kind: "climber", size: 66, hp: 40, walk: 30, climb: 19, dmg: 10, coin: 5, shield: true,
    rows: { walk: "walk", climb: "climb", exposed: "exposed", top: "exposed", death: "death" } },
  ladder: { name: "Pembawa Tangga", sheet: "ENEMY_LADDER", kind: "climber", size: 62, hp: 30, walk: 46, climb: 28, dmg: 8, coin: 4, ladder: true,
    rows: { walk: "walk", place: "place", climb: "climb", top: "climb", death: "death" } },
  spider: { name: "Laba-laba", sheet: "ENEMY_SPIDER", kind: "climber", size: 44, hp: 8, walk: 82, climb: 56, dmg: 4, coin: 1, group: 4,
    rows: { walk: "walk", climb: "climb", top: "attack", death: "death" } },
  kamikaze: { name: "Kamikaze", sheet: "ENEMY_KAMIKAZE", kind: "climber", size: 60, hp: 12, walk: 76, climb: 46, dmg: 25, coin: 3, explode: true,
    rows: { walk: "walk", climb: "climb", top: "fuse", death: "death" } },
  lumberjack: { name: "Penebang", sheet: "ENEMY_LUMBERJACK", kind: "ground", size: 70, hp: 45, walk: 36, climb: 0, dmg: 3, coin: 5,
    rows: { walk: "walk", chop: "chop", death: "death" } },
  healer: { name: "Penyembuh", sheet: "ENEMY_HEALER", kind: "climber", size: 64, hp: 35, walk: 26, climb: 15, dmg: 8, coin: 5, healer: true,
    rows: { walk: "walk", climb: "climb", heal: "heal", top: "heal", death: "death" } },
  bat: { name: "Kelelawar", sheet: "ENEMY_BAT", kind: "flyer", size: 50, hp: 10, speed: 72, dmg: 6, coin: 2, ai: "zigzag",
    rows: { fly: "fly", dive: "dive", death: "death" } },
  crow: { name: "Gagak", sheet: "ENEMY_CROW", kind: "flyer", size: 52, hp: 12, speed: 90, dmg: 8, coin: 2, ai: "dive",
    rows: { fly: "fly", dive: "dive", death: "death" } },
  bee: { name: "Tawon", sheet: "ENEMY_BEE", kind: "flyer", size: 36, hp: 4, speed: 96, dmg: 3, coin: 1, ai: "zigzag", group: 4,
    rows: { fly: "fly", dive: "dive", death: "death" } },
  witch: { name: "Penyihir Sapu", sheet: "ENEMY_WITCH", kind: "flyer", size: 64, hp: 30, speed: 60, dmg: 6, coin: 6, ai: "caster", shot: "witch_orb",
    rows: { fly: "fly", cast: "cast", death: "death" } },
  // ---- Dunia 2 & 3 ----
  mushroom: { name: "Jamur Berjalan", sheet: "ENEMY_MUSHROOM", kind: "climber", size: 64, hp: 34, walk: 38, climb: 24, dmg: 8, coin: 3, split: true,
    rows: { walk: "walk", climb: "climb", top: "attack", death: "death" } },
  moth: { name: "Ngengat Spora", sheet: "ENEMY_MOTH", kind: "flyer", size: 50, hp: 14, speed: 70, dmg: 4, coin: 3, ai: "zigzag", spore: true,
    rows: { fly: "fly", dive: "dive", death: "death" } },
  crab: { name: "Kepiting Baja", sheet: "ENEMY_CRAB", kind: "climber", size: 56, hp: 60, walk: 34, climb: 20, dmg: 10, coin: 5, shield: true,
    rows: { walk: "walk", climb: "climb", exposed: "attack", top: "attack", death: "death" } },
  gull: { name: "Camar Pencuri", sheet: "ENEMY_GULL", kind: "flyer", size: 52, hp: 16, speed: 95, dmg: 5, coin: 4, ai: "dive", thief: true,
    rows: { fly: "fly", dive: "dive", death: "death" } },
  magma: { name: "Golem Magma", sheet: "ENEMY_MAGMA", kind: "climber", size: 82, hp: 120, walk: 24, climb: 13, dmg: 16, coin: 8, fireImmune: true,
    rows: { walk: "walk", climb: "climb", top: "attack", death: "death" } },
  firebat: { name: "Kelelawar Api", sheet: "ENEMY_FIREBAT", kind: "flyer", size: 50, hp: 14, speed: 82, dmg: 7, coin: 3, ai: "zigzag", boom: true, fireImmune: true,
    rows: { fly: "fly", dive: "dive", death: "death" } },
  zombie: { name: "Zombi", sheet: "ENEMY_ZOMBIE", kind: "climber", size: 64, hp: 40, walk: 30, climb: 20, dmg: 10, coin: 4, revive: true,
    rows: { walk: "walk", climb: "climb", top: "attack", death: "death" } },
  ghost: { name: "Hantu", sheet: "ENEMY_GHOST", kind: "flyer", size: 62, hp: 26, speed: 55, dmg: 6, coin: 5, ai: "caster", shot: "wisp", phase: true,
    rows: { fly: "fly", cast: "cast", death: "death" } },
  gninja: { name: "Goblin Ninja", sheet: "ENEMY_GNINJA", kind: "climber", size: 60, hp: 32, walk: 80, climb: 46, dmg: 9, coin: 5, dodge: true,
    rows: { walk: "walk", climb: "climb", top: "leap", leap: "leap", death: "death" } },
  kite: { name: "Layang-layang Setan", sheet: "ENEMY_KITE", kind: "flyer", size: 56, hp: 22, speed: 60, dmg: 6, coin: 5, ai: "caster", shot: "clockbomb",
    rows: { fly: "fly", cast: "dive", death: "death" } },
  lizard: { name: "Kadal Kamuflase", sheet: "ENEMY_LIZARD", kind: "climber", size: 58, hp: 36, walk: 60, climb: 34, dmg: 10, coin: 5, camo: true,
    rows: { walk: "walk", climb: "climb", top: "leap", death: "death" } },
  toucan: { name: "Tukan Pelempar", sheet: "ENEMY_TOUCAN", kind: "flyer", size: 54, hp: 24, speed: 65, dmg: 6, coin: 5, ai: "caster", shot: "egg",
    rows: { fly: "fly", cast: "dive", death: "death" } },
  robot: { name: "Robot Pemanjat", sheet: "ENEMY_ROBOT", kind: "climber", size: 64, hp: 55, walk: 32, climb: 20, dmg: 12, coin: 6, shell: 3,
    rows: { walk: "walk", climb: "climb", exposed: "exposed", top: "exposed", death: "death" } },
  drone: { name: "Drone Mata", sheet: "ENEMY_DRONE", kind: "flyer", size: 56, hp: 28, speed: 70, dmg: 6, coin: 6, ai: "caster", shot: "laser", castCd: 2,
    rows: { fly: "fly", cast: "cast", death: "death" } },
  cgolem: { name: "Golem Kristal", sheet: "ENEMY_CGOLEM", kind: "climber", size: 82, hp: 140, walk: 24, climb: 13, dmg: 18, coin: 9, reflect: true,
    rows: { walk: "walk", climb: "climb", top: "attack", death: "death" } },
  cbat: { name: "Kelelawar Kristal", sheet: "ENEMY_CBAT", kind: "flyer", size: 50, hp: 18, speed: 85, dmg: 6, coin: 4, ai: "zigzag", shards: true,
    rows: { fly: "fly", dive: "dive", death: "death" } },
  harpy: { name: "Harpy", sheet: "ENEMY_HARPY", kind: "flyer", size: 60, hp: 30, speed: 110, dmg: 10, coin: 6, ai: "dive", fromTop: true,
    rows: { fly: "fly", dive: "dive", death: "death" } },
  cloud: { name: "Penunggang Awan", sheet: "ENEMY_CLOUD", kind: "flyer", size: 62, hp: 34, speed: 60, dmg: 8, coin: 7, ai: "caster", shot: "spear",
    rows: { fly: "fly", cast: "cast", death: "death" } },
  sknight: { name: "Ksatria Bayangan", sheet: "ENEMY_SKNIGHT", kind: "climber", size: 70, hp: 100, walk: 32, climb: 18, dmg: 16, coin: 9, shield: true, dash: true,
    rows: { walk: "walk", climb: "climb", exposed: "exposed", top: "exposed", death: "death" } },
  imp: { name: "Iblis Kecil", sheet: "ENEMY_IMP", kind: "flyer", size: 54, hp: 30, speed: 80, dmg: 7, coin: 7, ai: "caster", shot: "purplefire", blink: true,
    rows: { fly: "fly", cast: "cast", death: "death" } },
};

// summon: enemies called in the summon row; spit: hostile shots fired in it.
export const BOSSES = {
  king: { name: "Raja Goblin", sheetA: "BOSS_KING_A", sheetB: "BOSS_KING_B", kind: "climber", size: 120, hp: 820, climb: 9, dmg: 18, coin: 40, summon: ["goblin", 2], every: 7 },
  centipede: { name: "Kelabang Raksasa", sheetA: "BOSS_CENTIPEDE_A", sheetB: "BOSS_CENTIPEDE_B", kind: "climber", size: 150, hp: 980, climb: 11, dmg: 15, coin: 45, weakHead: true, spit: ["venom", 1, 8], every: 5 },
  dragon: { name: "Naga Kecil", sheetA: "BOSS_DRAGON_A", sheetB: "BOSS_DRAGON_B", kind: "flyer", size: 128, hp: 860, speed: 60, dmg: 12, coin: 50, breath: ["dragon_fire", 3, 7] },
  shroom: { name: "Ratu Jamur", sheetA: "BOSS_SHROOM_A", sheetB: "BOSS_SHROOM_B", kind: "climber", size: 124, hp: 1100, climb: 9, dmg: 18, coin: 60, summon: ["mushroom", 2], every: 6 },
  kraken: { name: "Kraken", sheetA: "BOSS_KRAKEN_A", sheetB: "BOSS_KRAKEN_B", kind: "climber", size: 132, hp: 1250, climb: 10, dmg: 20, coin: 65, spit: ["ink", 3, 7], every: 5 },
  salamander: { name: "Raja Salamander", sheetA: "BOSS_SALAMANDER_A", sheetB: "BOSS_SALAMANDER_B", kind: "climber", size: 150, hp: 1400, climb: 11, dmg: 22, coin: 70, weakHead: true, spit: ["lava", 2, 10], every: 4.5 },
  necro: { name: "Nekromancer", sheetA: "BOSS_NECRO_A", sheetB: "BOSS_NECRO_B", kind: "climber", size: 124, hp: 1500, climb: 9, dmg: 20, coin: 75, summon: ["zombie", 3], every: 7 },
  oni: { name: "Oni Raksasa", sheetA: "BOSS_ONI_A", sheetB: "BOSS_ONI_B", kind: "climber", size: 134, hp: 1750, climb: 12, dmg: 28, coin: 80, summon: ["gninja", 2], every: 6 },
  serpent: { name: "Ular Raksasa", sheetA: "BOSS_SERPENT_A", sheetB: "BOSS_SERPENT_B", kind: "climber", size: 156, hp: 1900, climb: 12, dmg: 24, coin: 85, weakHead: true, spit: ["venom", 3, 9], every: 4.5 },
  mech: { name: "Golem Mesin", sheetA: "BOSS_MECH_A", sheetB: "BOSS_MECH_B", kind: "climber", size: 136, hp: 2200, climb: 9, dmg: 26, coin: 90, summon: ["robot", 2], spit: ["clockbomb", 2, 10], every: 6 },
  spiderq: { name: "Ratu Laba-laba Kristal", sheetA: "BOSS_SPIDERQ_A", sheetB: "BOSS_SPIDERQ_B", kind: "climber", size: 156, hp: 2400, climb: 12, dmg: 26, coin: 95, weakHead: true, spit: ["web", 1, 6], summon: ["spider", 3], every: 5 },
  thunder: { name: "Burung Guntur", sheetA: "BOSS_THUNDER_A", sheetB: "BOSS_THUNDER_B", kind: "flyer", size: 134, hp: 2500, speed: 75, dmg: 16, coin: 100, breath: ["bolt_l", 4, 9] },
  dark: { name: "Raja Kegelapan", sheetA: "BOSS_DARK_A", sheetB: "BOSS_DARK_B", kind: "flyer", size: 140, hp: 3400, speed: 70, dmg: 20, coin: 150, breath: ["purplefire", 5, 10], summon: ["imp", 2], final: true },
};

// Roster entries: an enemy becomes possible from wave `from` of that stage.
export const STAGES = [
  {
    name: "Pohon Hutan", short: "Hutan", bg: "BG_S1", trunk: "TRUNK_S1", platform: "PLATFORM_S1", ground: "GROUND_S1",
    roster: [["goblin", 1, 6], ["bat", 4, 2], ["lumberjack", 6, 1]], mini: "king", boss: "king", flyerBias: 1,
  },
  {
    name: "Pohon Raksasa Rawa", short: "Rawa", bg: "BG_S2", trunk: "TRUNK_S2", platform: "PLATFORM_S2", ground: "GROUND_S2",
    roster: [["goblin", 1, 4], ["bat", 1, 2], ["monkey", 2, 3], ["spider", 4, 2], ["lumberjack", 5, 1], ["bee", 6, 2]], mini: "dragon", boss: "centipede", flyerBias: 1,
  },
  {
    name: "Kastil Batu", short: "Kastil", bg: "BG_S3", trunk: "TRUNK_S3", platform: "PLATFORM_S3", ground: "GROUND_S3",
    roster: [["goblin", 1, 3], ["monkey", 1, 2], ["orc", 2, 2], ["shield", 3, 2], ["ladder", 4, 1], ["bat", 1, 1], ["spider", 1, 1], ["crow", 6, 2]], mini: "centipede", boss: "king", flyerBias: 1,
  },
  {
    name: "Menara Salju", short: "Salju", bg: "BG_S4", trunk: "TRUNK_S4", platform: "PLATFORM_S4", ground: "GROUND_S4",
    roster: [["goblin", 1, 3], ["monkey", 1, 2], ["orc", 1, 1], ["shield", 1, 1], ["kamikaze", 2, 2], ["healer", 4, 1], ["bat", 1, 2], ["crow", 1, 2], ["bee", 1, 2], ["ladder", 3, 1]],
    mini: "dragon", boss: "centipede", flyerBias: 1.8, slippery: true,
  },
  {
    name: "Reruntuhan Gurun", short: "Gurun", bg: "BG_S5", trunk: "TRUNK_S5", platform: "PLATFORM_S5", ground: "GROUND_S5",
    roster: [["goblin", 1, 3], ["monkey", 1, 2], ["orc", 1, 2], ["shield", 1, 1], ["ladder", 1, 1], ["spider", 1, 1], ["kamikaze", 1, 1], ["healer", 1, 1], ["lumberjack", 1, 1], ["bat", 1, 1], ["crow", 1, 1], ["bee", 1, 1], ["witch", 3, 1]],
    mini: "king", boss: "dragon", flyerBias: 1.2,
  },
  {
    name: "Hutan Jamur Raksasa", short: "Jamur", bg: "BG_S6", trunk: "TRUNK_S6", platform: "PLATFORM_S6", ground: "GROUND_S6",
    roster: [["mushroom", 1, 5], ["goblin", 1, 2], ["spider", 1, 1], ["moth", 2, 3], ["bat", 1, 1], ["healer", 6, 1]], mini: "dragon", boss: "shroom", flyerBias: 1,
  },
  {
    name: "Mercusuar Karang", short: "Karang", bg: "BG_S7", trunk: "TRUNK_S7", platform: "PLATFORM_S7", ground: "GROUND_S7",
    roster: [["crab", 1, 4], ["mushroom", 1, 2], ["monkey", 1, 2], ["gull", 2, 3], ["kamikaze", 4, 1], ["crow", 1, 1]], mini: "shroom", boss: "kraken", flyerBias: 1, hazard: "tide",
  },
  {
    name: "Gunung Berapi", short: "Berapi", bg: "BG_S8", trunk: "TRUNK_S8", platform: "PLATFORM_S8", ground: "GROUND_S8",
    roster: [["magma", 1, 3], ["crab", 1, 2], ["orc", 1, 1], ["firebat", 2, 3], ["kamikaze", 1, 1], ["moth", 1, 1]], mini: "kraken", boss: "salamander", flyerBias: 1.2, hazard: "embers",
  },
  {
    name: "Kuburan Berhantu", short: "Kuburan", bg: "BG_S9", trunk: "TRUNK_S9", platform: "PLATFORM_S9", ground: "GROUND_S9",
    roster: [["zombie", 1, 5], ["magma", 1, 1], ["healer", 1, 1], ["ghost", 2, 2], ["bat", 1, 2], ["lumberjack", 3, 1]], mini: "salamander", boss: "necro", flyerBias: 1, hazard: "fog",
  },
  {
    name: "Hutan Bambu", short: "Bambu", bg: "BG_S10", trunk: "TRUNK_S10", platform: "PLATFORM_S10", ground: "GROUND_S10",
    roster: [["gninja", 1, 4], ["zombie", 1, 2], ["monkey", 1, 2], ["kite", 2, 2], ["ghost", 1, 1], ["shield", 4, 1]], mini: "necro", boss: "oni", flyerBias: 1, hazard: "wind",
  },
  {
    name: "Kuil Rimba", short: "Rimba", bg: "BG_S11", trunk: "TRUNK_S11", platform: "PLATFORM_S11", ground: "GROUND_S11",
    roster: [["lizard", 1, 4], ["gninja", 1, 2], ["spider", 1, 2], ["toucan", 2, 2], ["bee", 1, 2], ["ladder", 4, 1]], mini: "oni", boss: "serpent", flyerBias: 1.1, hazard: "vines",
  },
  {
    name: "Kota Jam", short: "Kota Jam", bg: "BG_S12", trunk: "TRUNK_S12", platform: "PLATFORM_S12", ground: "GROUND_S12",
    roster: [["robot", 1, 4], ["lizard", 1, 2], ["shield", 1, 1], ["drone", 2, 3], ["kamikaze", 1, 1], ["ladder", 1, 1]], mini: "serpent", boss: "mech", flyerBias: 1.1, hazard: "clock",
  },
  {
    name: "Gua Kristal", short: "Kristal", bg: "BG_S13", trunk: "TRUNK_S13", platform: "PLATFORM_S13", ground: "GROUND_S13",
    roster: [["cgolem", 1, 3], ["robot", 1, 2], ["spider", 1, 2], ["cbat", 2, 3], ["drone", 1, 1], ["healer", 1, 1]], mini: "mech", boss: "spiderq", flyerBias: 1.2,
  },
  {
    name: "Kastil Langit Badai", short: "Langit", bg: "BG_S14", trunk: "TRUNK_S14", platform: "PLATFORM_S14", ground: "GROUND_S14",
    roster: [["harpy", 1, 3], ["cloud", 2, 2], ["cgolem", 1, 1], ["gninja", 1, 2], ["cbat", 1, 1], ["crow", 1, 1], ["shield", 1, 1]], mini: "spiderq", boss: "thunder", flyerBias: 1.6, hazard: "storm",
  },
  {
    name: "Benteng Kegelapan", short: "Kegelapan", bg: "BG_S15", trunk: "TRUNK_S15", platform: "PLATFORM_S15", ground: "GROUND_S15",
    roster: [["sknight", 1, 4], ["imp", 2, 2], ["zombie", 1, 1], ["cgolem", 1, 1], ["robot", 1, 1], ["harpy", 1, 1], ["lizard", 1, 1], ["kamikaze", 1, 1], ["ghost", 1, 1]], mini: "thunder", boss: "dark", flyerBias: 1.2,
  },
];

export const WORLDS = [
  { name: "Dunia 1", map: "MAP_BG", stages: [0, 1, 2, 3, 4] },
  { name: "Dunia 2", map: "MAP_BG_2", stages: [5, 6, 7, 8, 9] },
  { name: "Dunia 3", map: "MAP_BG_3", stages: [10, 11, 12, 13, 14] },
];

// ---- Skins: 10 per hero, every tier keeps the buffs below it ----
export const SKIN_NAMES = {
  ranger: ["Ranger Merah", "Pemburu Hutan", "Pengintai Salju", "Pemanah Gurun", "Pemanah Api", "Elf Bulan", "Penjaga Kerajaan", "Pemanah Bayangan", "Pemanah Kristal", "Phoenix"],
  gunner: ["Gunner", "Bajak Laut", "Koboi", "Detektif", "Gunner Es", "Agen Rahasia", "Kapten Steampunk", "Mecha", "Pemburu Hantu", "Ratu Galaksi"],
  bomber: ["Bomber", "Penambang", "Prajurit Gurun", "Insinyur", "Roket Api", "Tank Mini", "Badut Kembang Api", "Badai Baja", "Robot Peledak", "Naga Meriam"],
  hunter: ["Hunter", "Penjaga Rawa", "Pemburu Serigala", "Ksatria Malam", "Pemburu Petir", "Penyamun", "Pemburu Vampir", "Paladin", "Pemburu Iblis", "Pemburu Bintang"],
  mage: ["Mage Api", "Druid", "Penyihir Es", "Penyihir Badai", "Ahli Racun", "Penyihir Bulan", "Archmage", "Penyihir Waktu", "Penyihir Bintang", "Avatar Naga"],
  ninja: ["Ninja", "Ninja Daun", "Ninja Salju", "Ninja Racun", "Ninja Api", "Samurai Muda", "Ninja Petir", "Ninja Bayangan", "Ninja Kristal", "Ninja Naga Emas"],
};
export const SKIN_COST = [null, [300, 0], [600, 0], [1000, 0], [1500, 0], [2200, 10], [3000, 15], [4000, 20], [5500, 30], [8000, 50]];
export const SKIN_TIER_BUFF = [
  "Dasar",
  "Tembak 20% lebih cepat",
  "Damage +25%, tembus +1",
  "Tembakan ganda",
  "Elemen di setiap tembakan",
  "Kritikal 20%, proyektil cepat",
  "Tembakan tiga arah",
  "Skill skin khusus",
  "Peluru pelacak + kill memulihkan HP",
  "Legendaris: tembakan ke-5 raksasa",
];
export const HERO_ELEMENT = { ranger: "fire", gunner: "ice", bomber: "fire", hunter: "lightning", mage: "poison", ninja: "fire" };
export const ELEMENT_NAME = { fire: "Api", ice: "Es", poison: "Racun", lightning: "Petir" };
export const SKILL3 = {
  ranger: { id: "phoenix", name: "Panah Phoenix", icon: "up_fire", cd: 20 },
  gunner: { id: "storm", name: "Hujan Peluru", icon: "up_firerate", cd: 22 },
  bomber: { id: "airstrike", name: "Serangan Udara", icon: "skill_bomb", cd: 22 },
  hunter: { id: "net", name: "Jaring Cahaya", icon: "up_lightning", cd: 20 },
  mage: { id: "meteor", name: "Meteor", icon: "up_fire", cd: 22 },
  ninja: { id: "clones", name: "Klon Bayangan", icon: "up_multishot", cd: 22 },
};
export const LEGEND_NAME = { ranger: "Panah raksasa menembus", gunner: "Semburan laser", bomber: "Bom nuklir mini", hunter: "Petir berantai 6 musuh", mage: "Tornado api", ninja: "Shuriken raksasa bumerang" };

export function skinSheet(heroId, tier, which) {
  if (tier <= 1) return which === "A" ? HEROES[heroId].sheetA : HEROES[heroId].sheetB;
  return `SKIN_${heroId.toUpperCase()}_${tier}_${which}`;
}

export function skinBuffs(heroId, tier) {
  const ninja = heroId === "ninja";
  return {
    tier,
    rate: tier >= 2 ? 0.8 : 1,
    dmg: tier >= 3 ? 1.25 : 1,
    pierce: tier >= 3 ? 1 : 0,
    shots: tier >= 7 ? (ninja ? 5 : 3) : tier >= 4 ? (ninja ? 4 : 2) : (ninja ? 3 : 1),
    element: tier >= 5 ? HERO_ELEMENT[heroId] : null,
    crit: tier >= 6 ? 0.2 : 0,
    speed: tier >= 6 ? 1.2 : 1,
    skill3: tier >= 8,
    homing: tier >= 9,
    lifesteal: tier >= 9,
    legendary: tier >= 10,
  };
}

export const WAVES_PER_STAGE = 10;

export const UPGRADES = {
  dmg: { name: "Damage +", desc: "+25% damage", icon: "up_damage", max: 6 },
  rate: { name: "Tembak Cepat", desc: "-15% jeda tembak", icon: "up_firerate", max: 5 },
  multi: { name: "Peluru Tambahan", desc: "+1 proyektil", icon: "up_multishot", max: 3 },
  fire: { name: "Api", desc: "Membakar musuh", icon: "up_fire", max: 3 },
  ice: { name: "Es", desc: "Memperlambat musuh", icon: "up_ice", max: 2 },
  poison: { name: "Racun", desc: "Racun terus-menerus", icon: "up_poison", max: 3 },
  lightning: { name: "Petir Berantai", desc: "Menyambar 2 musuh", icon: "up_lightning", max: 3 },
  treehp: { name: "Pohon Kuat", desc: "+30 HP maks & pulih", icon: "up_treehp", max: 5 },
  thorns: { name: "Duri Batang", desc: "Pemanjat terluka", icon: "up_thorns", max: 3 },
  oil: { name: "Minyak Licin", desc: "Panjat -20% lebih lambat", icon: "up_oil", max: 3 },
  turret: { name: "Turret Dahan", desc: "Menembak otomatis", icon: "up_turret", max: 2 },
};

export const SKILLS = [
  { id: "rain", name: "Hujan Panah", icon: "skill_rain", cd: 16 },
  { id: "bomb", name: "Bom", icon: "skill_bomb", cd: 22 },
];

// Small deterministic RNG so a wave recipe is the same every retry.
export function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >>> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}

function pickWeighted(r, list) {
  const total = list.reduce((a, e) => a + e[1], 0);
  let x = r() * total;
  for (const e of list) {
    x -= e[1];
    if (x <= 0) return e[0];
  }
  return list[list.length - 1][0];
}

// Build one wave's spawn list: [{ t, type, side }] plus an optional boss.
// stageIdx 0..4, wave 1..10 (or endless count), opts: { endless, sizeMult, intervalMult }
export function buildWave(stageIdx, wave, opts = {}) {
  const { endless = false, sizeMult = 1, intervalMult = 1 } = opts;
  const stage = STAGES[stageIdx];
  const r = rng(stageIdx * 1000 + wave * 37 + (endless ? 999 : 0));
  // Endless rotates areas every 5 waves; it uses that area's whole roster.
  let roster = endless
    ? stage.roster.map(([type, , w]) => [type, w])
    : stage.roster.filter(([, from]) => wave >= from).map(([type, , w]) => [type, w]);
  roster = roster.map(([t, w]) => [t, ENEMIES[t].kind === "flyer" ? w * stage.flyerBias : w]);

  const isBoss = wave % 5 === 0;
  let count = endless
    ? Math.round((7 + wave * 0.8) * Math.pow(1.15, Math.min(wave - 1, 30)) * 0.55)
    : Math.round(5 + wave * 1.7 + Math.min(stageIdx, 4) * 2 + Math.max(0, stageIdx - 4) * 0.9);
  if (isBoss) count = Math.round(count * 0.45);
  count = Math.max(2, Math.round(count * sizeMult));
  const hpMult = endless ? Math.pow(1.1, wave - 1) : Math.pow(1.1, wave - 1) * (1 + 0.28 * stageIdx);
  const coinMult = 1 + 0.22 * stageIdx;

  const interval = Math.max(0.35, 1.55 - wave * 0.06 - stageIdx * 0.08) * intervalMult;
  const list = [];
  let t = isBoss ? 2.5 : 0.8;
  for (let i = 0; i < count; i++) {
    const type = pickWeighted(r, roster);
    const side = r() < 0.5 ? -1 : 1;
    const group = ENEMIES[type].group || 1;
    for (let g = 0; g < group; g++) list.push({ t: t + g * 0.28, type, side, hpMult, coinMult });
    t += interval * (0.7 + r() * 0.6) * (group > 1 ? 1.6 : 1);
  }
  let boss = null;
  if (isBoss) {
    const bossType = endless || wave === WAVES_PER_STAGE ? stage.boss : stage.mini;
    const mini = !endless && wave !== WAVES_PER_STAGE;
    boss = { type: bossType, mini, coinMult, hpMult: (1 + 0.25 * stageIdx) * (mini ? 0.5 : 1) * (endless ? Math.pow(1.1, wave / 5 - 1) * 0.6 : 1) };
  }
  return { list, boss };
}

// Sheets a stage needs, so the loader can fetch them before play.
export function stageSheets(stageIdx, heroes, endless, skins = {}) {
  const keys = new Set();
  const addBoss = (b) => {
    const d = BOSSES[b];
    keys.add(d.sheetA); keys.add(d.sheetB);
    if (d.summon) keys.add(ENEMIES[d.summon[0]].sheet);
  };
  const stages = [STAGES[stageIdx]];
  for (const s of stages) {
    keys.add(s.bg); keys.add(s.trunk); keys.add(s.platform); keys.add(s.ground);
    s.roster.forEach(([t]) => keys.add(ENEMIES[t].sheet));
    addBoss(s.mini); addBoss(s.boss);
  }
  for (const h of heroes) if (h) { const t = skins[h] || 1; keys.add(skinSheet(h, t, "A")); keys.add(skinSheet(h, t, "B")); }
  keys.add("PROJECTILES_2");
  keys.add("FX_EXTRA");
  return [...keys];
}
