// Terrain is drawn from the 47-tile blob atlas (assets/images/atlas.png).
// Masks use clockwise N, NE, E, SE, S, SW, W, NW bits and sorted valid masks.

import 'dart:ui' as ui;

import '../engine/world.dart';

final List<int> _tileMasks = [
  for (var mask = 0; mask < 256; mask++)
    if ((mask & 2 == 0 || (mask & 5) == 5) &&
        (mask & 8 == 0 || (mask & 20) == 20) &&
        (mask & 32 == 0 || (mask & 80) == 80) &&
        (mask & 128 == 0 || (mask & 65) == 65))
      mask,
];

final List<int> _maskIndex = () {
  final out = List<int>.filled(256, -1);
  for (var i = 0; i < _tileMasks.length; i++) {
    out[_tileMasks[i]] = i;
  }
  return out;
}();

class _Layer {
  _Layer(this.types, int? tint)
      : paint = ui.Paint()..filterQuality = ui.FilterQuality.medium {
    if (tint != null) {
      paint.colorFilter = ui.ColorFilter.mode(ui.Color(tint).withValues(alpha: 0.45), ui.BlendMode.srcATop);
    }
  }
  final Set<int> types;
  final ui.Paint paint;
}

int _hex(String h) => 0xFF000000 | int.parse(h.substring(1), radix: 16);

class TerrainPainter {
  List<_Layer> _layers = [];

  /// Sap ledges are bark underneath (the sap pool is drawn on top); crystal and ice are sprites.
  void setArea({String? bark, String? soft}) {
    _layers = [
      _Layer({Tile.bark, Tile.sap}, bark == null ? null : _hex(bark)),
      _Layer({Tile.soft}, _hex(soft ?? '#b98a52')),
      _Layer({Tile.moss}, _hex('#5b7f34')),
    ];
  }

  /// [scale] is pixels per tile. Draws only the cells that intersect the view.
  void draw(ui.Canvas canvas, ui.Image atlas, World world, double left, double top, double viewW, double viewH, double scale) {
    if (_layers.isEmpty) return;
    final x0 = (left.floor()).clamp(0, world.cols - 1);
    final y0 = (top.floor()).clamp(0, world.rows - 1);
    final x1 = ((left + viewW / scale).ceil()).clamp(0, world.cols - 1);
    final y1 = ((top + viewH / scale).ceil()).clamp(0, world.rows - 1);
    int px(num v) => ((v - left) * scale).round();
    int py(num v) => ((v - top) * scale).round();
    for (final layer in _layers) {
      bool occupied(int x, int y) {
        if (x < 0 || y < 0 || x >= world.cols || y >= world.rows) return false;
        return layer.types.contains(world.tileAt(x, y));
      }

      for (var ty = y0; ty <= y1; ty++) {
        for (var tx = x0; tx <= x1; tx++) {
          if (!occupied(tx, ty)) continue;
          final n = occupied(tx, ty - 1), e = occupied(tx + 1, ty), s = occupied(tx, ty + 1), w = occupied(tx - 1, ty);
          final mask = (n ? 1 : 0) |
              (n && e && occupied(tx + 1, ty - 1) ? 2 : 0) |
              (e ? 4 : 0) |
              (e && s && occupied(tx + 1, ty + 1) ? 8 : 0) |
              (s ? 16 : 0) |
              (s && w && occupied(tx - 1, ty + 1) ? 32 : 0) |
              (w ? 64 : 0) |
              (w && n && occupied(tx - 1, ty - 1) ? 128 : 0);
          final index = _maskIndex[mask];
          if (index < 0) continue;
          // 256 px art with a 2 px extruded border on each side.
          final src = ui.Rect.fromLTWH((index % 12) * 260.0 + 2, (index ~/ 12) * 260.0 + 2, 256, 256);
          final dst = ui.Rect.fromLTRB(px(tx).toDouble(), py(ty).toDouble(), px(tx + 1).toDouble(), py(ty + 1).toDouble());
          canvas.drawImageRect(atlas, src, dst, layer.paint);
        }
      }
    }
  }
}
