// The game's Creator Tools vocabulary: what exists (catalog), what is on
// screen (describeScene), and what the editor may drive. The SDK talks to
// the editor; this file only describes the game. Each of the 11 areas is one
// connected map (worldMap.js, areaMaps.js); the level list jumps between them.

import { AREAS } from "./content.js";

const AREA_NAMES = AREAS.map((a, i) => `${i}. ${a.name}`);

export function createDevtools({ game }) {
  return {
    game: "Skyroot — The Last Archer",

    catalog({ definition, level, keysFor }) {
      const def = (id, label, opts) => definition(id, label, { tweakKeys: keysFor(id), ...opts });
      return {
        levels: AREA_NAMES.map((name, index) => level(`level:area-${index}`, name, { index, tweakKeys: keysFor(`level:area-${index}`) })),
        screens: [],
        definitions: [
          def("def:archer", "Archer", { nodeKinds: ["archer"], sprite: "ARCHER_A", spriteFrame: "idle", category: "characters" }),
          def("def:bow", "Arrows", { nodeKinds: ["arrow"], sprite: "PROPS", spriteFrame: "arrow", singleton: false, category: "effects" }),
          def("def:footing", "Footing steps", { nodeKinds: ["footing"], sprite: "EFFECTS", spriteFrame: "footing_sprout", singleton: false, category: "world" }),
          def("def:thorn-guard", "Thorn Guard", { nodeKinds: ["thorn"], sprite: "ENEMIES_A", singleton: false, category: "characters" }),
          def("def:shield-beetle", "Shield Beetle", { nodeKinds: ["beetle"], sprite: "ENEMIES_A", singleton: false, category: "characters" }),
          def("def:cannon-frog", "Cannon Frog", { nodeKinds: ["frog"], sprite: "ENEMIES_B", singleton: false, category: "characters" }),
          def("def:tower-stag", "Tower Stag", { nodeKinds: ["tower-stag"], sprite: "BOSS_STAG", category: "characters" }),
          def("def:area-monster", "Area monsters", { nodeKinds: ["bee", "twig", "leech", "bat", "moth", "spider", "bird", "salamander", "wisp", "sentinel"], sprite: "MONSTERS_1", spriteFrame: "petal_bee", singleton: false, category: "characters" }),
          def("def:area-boss", "Area bosses", { nodeKinds: ["area-boss"], sprite: "BOSS_1", spriteFrame: "orchid_queen", category: "characters" }),
          def("def:mover", "Moving platform", { nodeKinds: ["mover"], sprite: "AREA_PROPS", spriteFrame: "petal_platform", singleton: false, category: "world" }),
          def("def:gate", "Area gate", { nodeKinds: ["gate"], sprite: "AREA_PROPS", spriteFrame: "gate", category: "world" }),
          def("def:fold-leaf", "Folding leaf", { nodeKinds: ["fold-leaf"], sprite: "WORLD_ANIM", singleton: false, category: "world" }),
          def("def:crumble-platform", "Crumbling slab", { nodeKinds: ["crumble-platform"], sprite: "WORLD_ANIM", singleton: false, category: "world" }),
          def("def:launch-flower", "Launch flower", { nodeKinds: ["launch-flower"], sprite: "WORLD_ANIM", singleton: false, category: "world" }),
          def("def:wind-gust", "Wind gust", { nodeKinds: ["wind-gust"], sprite: "WORLD_ANIM", singleton: false, category: "hazards" }),
          def("def:thorn-spikes", "Thorn spikes", { nodeKinds: ["thorn-spikes"], sprite: "PROPS", singleton: false, category: "hazards" }),
          def("def:checkpoint", "Rest shrine", { nodeKinds: ["checkpoint"], sprite: "SHRINES", singleton: false, category: "world" }),
          def("def:bell", "Tower bell", { nodeKinds: ["bell"], sprite: "SHRINES", category: "world" }),
          def("def:pickup", "Pickups & relics", { nodeKinds: ["pickup"], sprite: "PROPS", spriteFrame: "heart_relic", singleton: false, category: "pickups" }),
          def("def:villager", "Village elder", { nodeKinds: ["villager"], sprite: "PROPS", singleton: false, category: "characters" }),
          def("def:backdrop", "Misty backdrop", { nodeKinds: ["backdrop"], sprite: "BACKDROP", category: "world" }),
          def("def:hud", "Hearts & energy", { nodeKinds: ["hud-status"], category: "interface" }),
          def("def:controls", "Touch controls", { nodeKinds: ["touch-controls"], category: "interface" }),
        ],
      };
    },

    describeScene() {
      return { nodes: game.sceneNodes() };
    },

    getState: () => ({
      started: game.state.phase === "play" || game.state.phase === "ending",
      over: game.state.phase === "ending",
    }),

    // Each area is one connected map; navigating jumps there with the area unlocked.
    gotoLevel: (index) => game.travelTo(index),

    commands: {
      respawn: {
        label: "Respawn at shrine",
        icon: "RotateCcw",
        description: "Rebuild the world and wake the archer at the last lit shrine",
        mutates: true,
        run: () => game.respawn(),
      },
      "unlock-skins": {
        label: "Try the top skin",
        icon: "Shirt",
        description: "Mark every area boss beaten and wear Mahkota Akar",
        mutates: true,
        run: () => {
          game.state.progress.areas.forEach((a) => (a.boss = true));
          game.equipSkin(10);
        },
      },
      "reset-progress": {
        label: "Reset progress",
        icon: "Trash2",
        description: "Forget abilities, shortcuts and secrets, and start from the village",
        mutates: true,
        run: () => game.resetProgress(),
      },
    },
  };
}
