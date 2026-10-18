// Scene nodes for the Creator Tools: what is on screen, in viewport CSS px.
import { WORLD } from "./world.js";
import { MONSTERS, BOSSES } from "./content.js";

const OLD = { thorn: ["def:thorn-guard", "Thorn Guard"], beetle: ["def:shield-beetle", "Shield Beetle"], frog: ["def:cannon-frog", "Cannon Frog"] };

export function sceneNodes(state, renderer, hud) {
  if (!renderer || !state.cam || !state.player) return [];
  const rect = hud.el.canvas.getBoundingClientRect();
  const box = renderer.camBox(state.cam);
  const sc = renderer.view.scale * (state.cam.zoom || 1);
  const R = (x0, y0, w, h) => ({ x: rect.left + (x0 - box.left) * sc, y: rect.top + (y0 - box.top) * sc, w: w * sc, h: h * sc });
  const vis = (x, y) => x > box.left - 2 && x < box.left + rect.width / sc + 2 && y > box.top - 2 && y < box.top + rect.height / sc + 2;
  const nodes = [];
  nodes.push({ id: "backdrop", defId: "def:backdrop", kind: "backdrop", label: "Backdrop", rect: { x: rect.left, y: rect.top, w: rect.width, h: rect.height }, instance: { area: state.areaIndex } });
  const p = state.player;
  nodes.push({ id: "archer", defId: "def:archer", kind: "archer", label: "Archer", rect: R(p.x - 0.5, p.y - 1.8, 1, 1.8), instance: { hp: p.hp, energy: Math.floor(p.energy), mode: p.mode, skin: state.progress.skin } });
  for (const e of state.enemies) {
    if (!vis(e.x, e.y)) continue;
    const def = OLD[e.type] || ["def:area-monster", MONSTERS[e.type]?.name || "Monster"];
    nodes.push({ id: `enemy-${e.id}`, defId: def[0], kind: e.type, label: def[1], rect: R(e.x - e.w / 2, e.y - e.h, e.w, e.h), instance: { hp: e.hp } });
  }
  const b = state.boss;
  if (b && b.state !== "gone" && vis(b.x, b.y)) {
    const generic = !!b.generic;
    nodes.push({ id: "boss", defId: generic ? "def:area-boss" : "def:tower-stag", kind: generic ? "area-boss" : "tower-stag", label: generic ? BOSSES[b.area].name : "Tower Stag", rect: R(b.x - 2.5, b.y - 7, 5, 7), instance: { hp: b.hp, state: b.state } });
  }
  for (const l of state.leaves) if (vis(l.x0, l.y)) nodes.push({ id: `leaf-${l.id}`, defId: "def:fold-leaf", kind: "fold-leaf", label: "Folding leaf", rect: R(l.x0, l.y - 0.3, l.x1 - l.x0 + 1, 0.6), instance: { state: l.state } });
  for (const c of state.crumbles) if (vis(c.x0, c.y)) nodes.push({ id: `crumble-${c.id}`, defId: "def:crumble-platform", kind: "crumble-platform", label: "Crumbling slab", rect: R(c.x0, c.y, c.x1 - c.x0 + 1, 0.6), instance: { state: c.state } });
  for (const m of state.movers) if (vis(m.px, m.py)) nodes.push({ id: `mover-${m.id}`, defId: "def:mover", kind: "mover", label: "Moving platform", rect: R(m.px, m.py - 0.2, m.w, 0.5), instance: { axis: m.axis } });
  for (const f of state.flowers) if (vis(f.x, f.y)) nodes.push({ id: `flower-${f.id}`, defId: "def:launch-flower", kind: "launch-flower", label: "Launch flower", rect: R(f.x - 0.2, f.y - 0.5, 1.4, 1.5), instance: {} });
  for (const w of state.winds) if (vis(w.x0, w.y0) || vis(w.x0, w.y1)) nodes.push({ id: `wind-${w.id}`, defId: "def:wind-gust", kind: "wind-gust", label: "Wind gust", rect: R(w.x0, w.y0, w.x1 - w.x0 + 1, w.y1 - w.y0 + 1), instance: { on: w.on } });
  for (const k of state.checkpoints) if (vis(k.x, k.y)) nodes.push({ id: k.id, defId: "def:checkpoint", kind: "checkpoint", label: "Rest shrine", rect: R(k.x - 0.3, k.y - 0.7, 1.6, 1.7), instance: { lit: state.areaProg.cp === k.id } });
  for (const f of state.footings) nodes.push({ id: `footing-${f.id}`, defId: "def:footing", kind: "footing", label: "Footing step", rect: R(f.x0, f.top - 0.1, 2, 0.5), instance: {} });
  for (const it of state.pickups) if (!it.taken && vis(it.x, it.y)) nodes.push({ id: `pickup-${it.id}`, defId: "def:pickup", kind: "pickup", label: "Pickup", rect: R(it.x, it.y, 1, 1), instance: { kind: it.kind } });
  if (state.bell && vis(state.bell.x, state.bell.y)) nodes.push({ id: "bell", defId: "def:bell", kind: "bell", label: "Tower bell", rect: R(state.bell.x - 0.6, state.bell.y - 1, 2.2, 2), instance: {} });
  if (state.gate && vis(state.gate.x, state.gate.y)) nodes.push({ id: "gate", defId: "def:gate", kind: "gate", label: "Area gate", rect: R(state.gate.x - 0.6, state.gate.y - 1.8, 2.2, 2.8), instance: { active: state.gate.active } });
  for (const v of state.villagers) if (vis(v.x, v.y)) nodes.push({ id: `villager-${v.x}`, defId: "def:villager", kind: "villager", label: "Village elder", rect: R(v.x, v.y - 0.8, 1, 1.8), instance: {} });
  for (const s of WORLD.runs["^"] || []) if (vis(s.x0, s.y)) nodes.push({ id: `spikes-${s.x0}-${s.y}`, defId: "def:thorn-spikes", kind: "thorn-spikes", label: "Thorn spikes", rect: R(s.x0, s.y, s.x1 - s.x0 + 1, 1), instance: {} });
  for (const a of state.arrows) nodes.push({ id: `arrow-${a.id}`, defId: "def:bow", kind: "arrow", label: "Arrow", rect: R(a.x - 0.4, a.y - 0.15, 0.8, 0.3), instance: { kind: a.kind } });
  const hudRect = (sel, id, defId, label) => {
    const el = hud.el.root.querySelector(sel);
    if (!el || el.hidden) return;
    const r = el.getBoundingClientRect();
    if (r.width) nodes.push({ id, defId, kind: id, label, rect: { x: r.left, y: r.top, w: r.width, h: r.height }, instance: {} });
  };
  hudRect(".hud-left", "hud-status", "def:hud", "Hearts & energy");
  hudRect(".controls", "touch-controls", "def:controls", "Touch controls");
  return nodes;
}
