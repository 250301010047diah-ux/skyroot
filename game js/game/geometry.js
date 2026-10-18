// World geometry: one function owns where the platform, trunk lanes and ground
// sit. Rendering, spawning, collision and input all read from this.
import { WORLD_H } from "./data.js";

// Camera fit: the world is at least 640 units tall and 300 wide; extra frame
// height lengthens the trunk, extra width widens the ground.
export function computeView(cssW, cssH) {
  const scale = Math.max(0.1, Math.min(cssH / WORLD_H, cssW / 300));
  return { scale, W: cssW / scale, H: cssH / scale, cssW, cssH };
}

export function computeGeo(view) {
  const { W, H } = view;
  const cx = W / 2;
  const platformY = 132; // hero feet / platform walk surface
  const groundY = H - 118; // enemy walk line
  const trunkW = 176;
  const laneGap = 42;
  return {
    W, H, cx, platformY, groundY, trunkW,
    platformW: Math.min(340, W * 0.98),
    lanes: [cx - laneGap, cx, cx + laneGap],
    climbTopY: platformY + 62, // climbers stop under the canopy and attack
    heroX: cx,
    heroY: platformY,
    heroHit: { x: cx, y: platformY - 32, r: 26 },
    coinTarget: { x: W - 64, y: 22 },
  };
}

export function bowPoint(geo, flip) {
  return { x: geo.heroX + (flip ? -16 : 16), y: geo.platformY - 36 };
}
