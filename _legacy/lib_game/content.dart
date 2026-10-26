/// Game content constants mirroring `game js/game/data.js`.
///
/// The full data (heroes, enemies, bosses, stages, skins) lives in that file.
/// These are the shared layout constants the Flame port needs to slice sheets
/// and size the virtual camera. The complete port of the data tables is the
/// natural next step once the asset pipeline below is wired in.
class Content {
  /// Virtual height the camera fits (world units), from data.js.
  static const double worldH = 640;

  /// Every animation row in every sheet is exactly this many frames.
  static const int framesPerAnim = 5;
}
