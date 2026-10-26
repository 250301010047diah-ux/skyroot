// Game content tables: the 11 areas, their monsters and bosses, and the 11 archer skins.
// Port of game js/game/content.js.

/// Monster behaviours: diver (hover then swoop), flyer (drifts toward you), archer (lobs shots),
/// hopper (leaps at you), dropper (drops on a thread, spits web), walkerLob (patrols, throws fire),
/// radial (turret firing a ring of bolts).
class MonsterDef {
  const MonsterDef({
    required this.name,
    required this.sheet,
    required this.anim,
    required this.ai,
    required this.hp,
    required this.w,
    required this.h,
    required this.size,
    this.fly = false,
    this.speed = 0,
    this.light = false,
    this.freeze = false,
    this.shot,
  });
  final String name, sheet, anim, ai;
  final int hp;
  final double w, h, size, speed;
  final bool fly, light, freeze;
  final String? shot;
}

const monsters = <String, MonsterDef>{
  'bee': MonsterDef(name: 'Lebah Kelopak', sheet: 'MONSTERS_1', anim: 'petal_bee', ai: 'diver', hp: 2, w: 1.0, h: 1.0, size: 1.3, fly: true),
  'twig': MonsterDef(name: 'Pemburu Ranting', sheet: 'MONSTERS_1', anim: 'twig_hunter', ai: 'archer', hp: 3, w: 0.9, h: 1.2, size: 1.45, shot: 'twig_arrow'),
  'leech': MonsterDef(name: 'Lintah Getah', sheet: 'MONSTERS_2', anim: 'sap_leech', ai: 'hopper', hp: 3, w: 1.3, h: 0.7, size: 1.4),
  'bat': MonsterDef(name: 'Kelelawar Kristal', sheet: 'MONSTERS_2', anim: 'crystal_bat', ai: 'flyer', hp: 2, w: 1.0, h: 0.8, size: 1.3, fly: true, speed: 3.4),
  'moth': MonsterDef(name: 'Ngengat Lentera', sheet: 'MONSTERS_3', anim: 'lantern_moth', ai: 'flyer', hp: 3, w: 1.1, h: 1.0, size: 1.5, fly: true, speed: 2.2, light: true),
  'spider': MonsterDef(name: 'Laba-laba Sutra', sheet: 'MONSTERS_3', anim: 'silk_spider', ai: 'dropper', hp: 4, w: 1.0, h: 1.0, size: 1.6, fly: true, shot: 'web_shot'),
  'bird': MonsterDef(name: 'Burung Badai', sheet: 'MONSTERS_4', anim: 'storm_bird', ai: 'diver', hp: 3, w: 1.1, h: 1.0, size: 1.5, fly: true),
  'salamander': MonsterDef(name: 'Kadal Bara', sheet: 'MONSTERS_4', anim: 'ember_salamander', ai: 'walkerLob', hp: 4, w: 1.6, h: 0.7, size: 1.9, shot: 'fireball'),
  'wisp': MonsterDef(name: 'Roh Salju', sheet: 'MONSTERS_5', anim: 'frost_wisp', ai: 'flyer', hp: 4, w: 1.0, h: 1.0, size: 1.4, fly: true, speed: 1.8, freeze: true),
  'sentinel': MonsterDef(name: 'Penjaga Bintang', sheet: 'MONSTERS_5', anim: 'star_sentinel', ai: 'radial', hp: 6, w: 1.2, h: 1.3, size: 1.6, fly: true, shot: 'star_bolt'),
};

/// Boss attacks: spray (arcing shots), ring (bolts in every direction), shock (ground wave),
/// rain (marked debris from above), charge (rush across the arena), summon (calls monsters),
/// dive (flying swoop), beam (marked lightning columns).
class BossDef {
  const BossDef({
    required this.name,
    required this.sheet,
    required this.anim,
    required this.hp,
    required this.height,
    required this.attacks,
    required this.p2,
    this.p3 = const [],
    required this.shot,
    this.fly = false,
  });
  final String name, sheet, anim, shot;
  final int hp;
  final double height;
  final bool fly;
  final List<String> attacks, p2, p3;
}

/// Index 0 is null: Akar Berkabut uses the Tower Stag (boss.dart).
const bosses = <BossDef?>[
  null,
  BossDef(name: 'Ratu Anggrek', sheet: 'BOSS_1', anim: 'orchid_queen', hp: 30, height: 6.5, attacks: ['spray', 'rain'], p2: ['summon'], shot: 'petal_blade'),
  BossDef(name: 'Golem Lonceng', sheet: 'BOSS_2', anim: 'bell_golem', hp: 42, height: 6.5, attacks: ['shock', 'charge'], p2: ['ring'], shot: 'lightning_orb'),
  BossDef(name: 'Raja Katak Getah', sheet: 'BOSS_3', anim: 'sap_toad_king', hp: 52, height: 6, attacks: ['spray', 'shock'], p2: ['rain'], shot: 'sap_glob'),
  BossDef(name: 'Ular Kristal', sheet: 'BOSS_4', anim: 'crystal_serpent', hp: 62, height: 7, attacks: ['ring', 'charge'], p2: ['spray'], shot: 'crystal_shard'),
  BossDef(name: 'Induk Jamur', sheet: 'BOSS_5', anim: 'mother_mushroom', hp: 72, height: 7, attacks: ['spray', 'summon'], p2: ['rain'], shot: 'spore_ball'),
  BossDef(name: 'Ratu Laba-laba', sheet: 'BOSS_6', anim: 'spider_queen', hp: 84, height: 6.5, fly: true, attacks: ['spray', 'dive'], p2: ['summon'], shot: 'web_shot'),
  BossDef(name: 'Elang Petir', sheet: 'BOSS_7', anim: 'thunder_eagle', hp: 96, height: 6, fly: true, attacks: ['beam', 'dive'], p2: ['ring'], shot: 'lightning_orb'),
  BossDef(name: 'Penjaga Tungku', sheet: 'BOSS_8', anim: 'forge_guardian', hp: 112, height: 7, attacks: ['spray', 'shock'], p2: ['rain'], shot: 'fireball'),
  BossDef(name: 'Beruang Es Akar', sheet: 'BOSS_9', anim: 'frost_bear', hp: 130, height: 6, attacks: ['charge', 'rain'], p2: ['ring'], shot: 'ice_shard'),
  BossDef(name: 'Jantung Kabut', sheet: 'BOSS_10', anim: 'mist_heart', hp: 180, height: 7, fly: true, attacks: ['ring', 'beam', 'summon'], p2: ['rain'], p3: ['spray'], shot: 'mist_orb'),
];

class AreaDef {
  const AreaDef({
    required this.name,
    required this.bg,
    required this.monster,
    required this.music,
    this.bark,
    this.soft,
    this.gravity = 1,
  });
  final String name, bg;
  final String? monster, bark, soft;
  final int music;
  final double gravity;
}

/// Terrain colours recolour the Akar Berkabut kits per area.
const areas = <AreaDef>[
  AreaDef(name: 'Akar Berkabut', bg: 'BACKDROP', monster: null, music: 0),
  AreaDef(name: 'Kebun Gantung', bg: 'BG_1', monster: 'bee', bark: '#6e4a4f', soft: '#d9a3b4', music: 2),
  AreaDef(name: 'Kota Kulit Pohon', bg: 'BG_2', monster: 'twig', bark: '#6a4a2a', soft: '#d6a663', music: 5),
  AreaDef(name: 'Rawa Getah', bg: 'BG_3', monster: 'leech', bark: '#4b4a26', soft: '#c9a046', music: -2),
  AreaDef(name: 'Gua Kristal Akar', bg: 'BG_4', monster: 'bat', bark: '#3d3352', soft: '#9a8fc6', music: 3),
  AreaDef(name: 'Hutan Jamur Senja', bg: 'BG_5', monster: 'moth', bark: '#5a3a3e', soft: '#d08a5c', music: -4),
  AreaDef(name: 'Sarang Sutra', bg: 'BG_6', monster: 'spider', bark: '#5a5560', soft: '#d4cfd8', music: 1),
  AreaDef(name: 'Lautan Awan', bg: 'BG_7', monster: 'bird', bark: '#6b6458', soft: '#e8e2d0', music: 7),
  AreaDef(name: 'Reruntuhan Bara', bg: 'BG_8', monster: 'salamander', bark: '#4a2c24', soft: '#c4683e', music: -5),
  AreaDef(name: 'Puncak Beku', bg: 'BG_9', monster: 'wisp', bark: '#4f5c6b', soft: '#c8dce8', music: 4),
  AreaDef(name: 'Mahkota Bintang', bg: 'BG_10', monster: 'sentinel', bark: '#2f3550', soft: '#d8c27a', music: 9, gravity: 0.7),
];

class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.perk,
    required this.arrow,
    required this.sheets,
    required this.icon,
    required this.speed,
    required this.draw,
    required this.pierce,
    required this.hp,
    required this.shots,
    required this.doubleJump,
    required this.airDashes,
    required this.burn,
    required this.dmg,
    required this.slow,
    required this.chain,
    required this.homing,
    required this.focus,
    required this.energy,
    required this.skill,
  });
  final int id;
  final String name, perk, arrow, icon;
  final List<String> sheets;
  final double speed, draw, focus;
  final int pierce, hp, shots, airDashes, dmg, energy;
  final bool doubleJump, burn, slow, chain, homing;
  final String? skill;
}

class _RawSkin {
  const _RawSkin(this.name, this.perk, this.arrow, this.add, [this.sheets]);
  final String name, perk, arrow;
  final Map<String, Object> add;
  final List<String>? sheets;
}

const _rawSkins = <_RawSkin>[
  _RawSkin('Ranger', 'Pemanah dasar', 'arrow', {}, ['ARCHER_A', 'ARCHER_B', 'ARCHER_C']),
  _RawSkin('Pemburu Embun', 'Lari +15%, tarikan busur lebih cepat', 'arrow', {'speed': 1.15, 'draw': 0.75}),
  _RawSkin('Penjaga Duri', 'Panah menembus 1 musuh, +1 nyawa', 'arrow', {'pierce': 1, 'hp': 1}),
  _RawSkin('Pemanah Kembar', 'Tembak 2 panah sekaligus', 'arrow', {'shots': 2}),
  _RawSkin('Penari Angin', 'Lompat ganda, dash udara 2x', 'arrow', {'doubleJump': true, 'airDashes': 2}),
  _RawSkin('Pemanah Bara', 'Panah membakar, tarikan penuh +1 damage', 'fire_arrow', {'burn': true, 'dmg': 1}),
  _RawSkin('Pemanah Es', 'Panah memperlambat · Skill Hujan Es', 'ice_arrow', {'slow': true, 'skill': 'icerain'}),
  _RawSkin('Pemanah Badai', 'Tembak 3 panah, petir berantai · Skill Panggil Petir', 'storm_arrow', {'shots': 3, 'chain': true, 'skill': 'thunder'}),
  _RawSkin('Pemanah Bulan', 'Panah mengejar, Fokus Udara 2x · Skill Bayangan Kembar', 'moon_arrow', {'homing': true, 'focus': 2.0, 'skill': 'clone'}),
  _RawSkin('Pemanah Bintang', '3 panah tembus 2, +1 energi · Skill Hujan Bintang', 'star_arrow', {'pierce': 2, 'energy': 1, 'skill': 'starrain'}),
  _RawSkin('Mahkota Akar', '5 panah kipas, +2 nyawa · Skill Penjaga Akar', 'star_arrow', {'shots': 5, 'hp': 2, 'dmg': 2, 'skill': 'guardian'}),
];

/// Every skin keeps all earlier perks and adds its own (cumulative), so a higher tier is always stronger.
final List<Skin> skins = () {
  final out = <Skin>[];
  double speed = 1, draw = 1, focus = 1;
  int pierce = 0, hp = 0, shots = 1, airDashes = 1, dmg = 0, energy = 0;
  bool doubleJump = false, burn = false, slow = false, chain = false, homing = false;
  String? skill;
  for (var i = 0; i < _rawSkins.length; i++) {
    final s = _rawSkins[i];
    final a = s.add;
    speed = (a['speed'] as double?) ?? speed;
    draw = (a['draw'] as double?) ?? draw;
    pierce = (a['pierce'] as int?) ?? pierce;
    hp += (a['hp'] as int?) ?? 0;
    shots = (a['shots'] as int?) ?? shots;
    doubleJump = (a['doubleJump'] as bool?) ?? doubleJump;
    airDashes = (a['airDashes'] as int?) ?? airDashes;
    burn = (a['burn'] as bool?) ?? burn;
    dmg += (a['dmg'] as int?) ?? 0;
    slow = (a['slow'] as bool?) ?? slow;
    chain = (a['chain'] as bool?) ?? chain;
    homing = (a['homing'] as bool?) ?? homing;
    focus = (a['focus'] as double?) ?? focus;
    energy += (a['energy'] as int?) ?? 0;
    skill = (a['skill'] as String?) ?? skill;
    out.add(Skin(
      id: i,
      name: s.name,
      perk: s.perk,
      arrow: s.arrow,
      sheets: s.sheets ?? ['SKIN${i}_A', 'SKIN${i}_B', 'SKIN${i}_C'],
      icon: 'skin_$i',
      speed: speed,
      draw: draw,
      pierce: pierce,
      hp: hp,
      shots: shots,
      doubleJump: doubleJump,
      airDashes: airDashes,
      burn: burn,
      dmg: dmg,
      slow: slow,
      chain: chain,
      homing: homing,
      focus: focus,
      energy: energy,
      skill: skill,
    ));
  }
  return out;
}();

const skillNames = <String, String>{
  'icerain': 'Hujan Es',
  'thunder': 'Panggil Petir',
  'clone': 'Bayangan Kembar',
  'starrain': 'Hujan Bintang',
  'guardian': 'Penjaga Akar',
};
