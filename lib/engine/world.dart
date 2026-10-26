// Static world: the active area's tile grid + spawn list, parsed from its ASCII map.

//
// Glyphs:
//   #  bark (solid)          S  soft heartwood (solid, Footing Arrows stick)   W  moss wall (wall jump)
//   g  sap (solid, slows)    k  crystal (solid, bounces arrows)                i  ice (solid, slippery)
//   =  branch (one-way)      |  vine (climb)        ^  thorn spikes            w  wind gust zone
//   e  ember vent (hazard that flares on a beat)     v  stalactite (falls on whoever passes under)
//   L  folding leaf   C  crumbling slab   F  launch flower   M/N  moving platform (sideways/up-down)
//   n  root bridge (after the stag)   X  cracked wall / web   G  gate to the next area
//   K  rest shrine   P  start   U/u lift   z  rope anchor   O  area boss   b  bell
//   T  thorn guard   B  shield beetle   Q  cannon frog   *  the area's own monster
//   H  heart   E  energy stone   D  dash relic   A  footing relic   R  heart relic   Y  golden feather
//   V  villager   h treehouse   l lantern   m mushrooms   s sign   (decor)
import 'dart:typed_data';

class Tile {
  static const empty = 0, bark = 1, soft = 2, moss = 3, oneway = 4, vine = 5, spike = 6, wind = 7, sap = 8, crystal = 9, ice = 10, ember = 11;
}

const _solid = {Tile.bark, Tile.soft, Tile.moss, Tile.sap, Tile.crystal, Tile.ice};
const _tileOf = <String, int>{
  '#': Tile.bark, 'S': Tile.soft, 'W': Tile.moss, 'g': Tile.sap, 'k': Tile.crystal, 'i': Tile.ice,
  '=': Tile.oneway, '|': Tile.vine, '^': Tile.spike, 'w': Tile.wind, 'e': Tile.ember,
};
const _singleGlyphs = 'PKTBQOHEDARYVbUuzFhlmsGv*';

class Single {
  const Single(this.g, this.x, this.y);
  final String g;
  final int x, y;
}

/// A horizontal run of one glyph on a row (x1 inclusive).
class Run {
  const Run(this.x0, this.x1, this.y);
  final int x0, x1, y;
}

/// A vertical strip (vine or cracked wall) in column x, rows y0..y1 inclusive.
class Strip {
  const Strip(this.x, this.y0, this.y1);
  final int x, y0, y1;
}

class WindZone {
  const WindZone(this.x0, this.x1, this.y0, this.y1);
  final int x0, x1, y0, y1;
}

/// The rope shortcut in Akar Berkabut hangs from the one-way ledge down to the village.
const ropeStrip = Strip(1, 36, 82);

class World {
  World(this.maps) {
    loadArea(0);
  }

  final List<List<String>> maps;
  int cols = 0, rows = 0, area = -1;
  late List<String> _map;
  Uint8List _tiles = Uint8List(0);
  Uint8List _crackSolid = Uint8List(0);
  Uint8List _ropeVine = Uint8List(0);

  List<Single> singles = [];
  Map<String, List<Run>> runs = {};
  List<Strip> vines = [], cracks = [];
  List<WindZone> winds = [];

  String _glyph(int x, int y) {
    if (y < 0 || y >= _map.length) return '#';
    final row = _map[y];
    if (x < 0 || x >= row.length) return '#';
    return row[x];
  }

  List<Single> single(String g) => singles.where((s) => s.g == g).toList();

  /// Switch the active area. Cheap (a few thousand cells) and synchronous.
  void loadArea(int index) {
    if (area == index) return;
    _map = maps[index >= 0 && index < maps.length ? index : 0];
    rows = _map.length;
    cols = _map[0].length;
    _tiles = Uint8List(cols * rows);
    _crackSolid = Uint8List(cols * rows);
    _ropeVine = Uint8List(cols * rows);
    final newSingles = <Single>[];
    final newRuns = <String, List<Run>>{for (final g in ['L', 'C', 'n', '=', '^', 'M', 'N']) g: <Run>[]};
    final newVines = <Strip>[];
    final newCracks = <Strip>[];
    final newWinds = <WindZone>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final g = _glyph(x, y);
        _tiles[y * cols + x] = _tileOf[g] ?? Tile.empty;
        if (_singleGlyphs.contains(g)) newSingles.add(Single(g, x, y));
      }
    }
    for (final g in newRuns.keys) {
      for (var y = 0; y < rows; y++) {
        var x = 0;
        while (x < cols) {
          if (_glyph(x, y) == g) {
            final x0 = x;
            while (_glyph(x + 1, y) == g) {
              x++;
            }
            newRuns[g]!.add(Run(x0, x, y));
          }
          x++;
        }
      }
    }
    for (var x = 0; x < cols; x++) {
      var y = 0;
      while (y < rows) {
        final g = _glyph(x, y);
        if (g == '|' || g == 'X') {
          final y0 = y;
          while (_glyph(x, y + 1) == g) {
            y++;
          }
          (g == '|' ? newVines : newCracks).add(Strip(x, y0, y));
        }
        y++;
      }
    }
    final seen = Uint8List(cols * rows);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (_glyph(x, y) != 'w' || seen[y * cols + x] == 1) continue;
        var x1 = x;
        while (_glyph(x1 + 1, y) == 'w') {
          x1++;
        }
        var y1 = y;
        bool rowIsWind(int yy) {
          for (var xx = x; xx <= x1; xx++) {
            if (_glyph(xx, yy) != 'w') return false;
          }
          return true;
        }

        while (rowIsWind(y1 + 1)) {
          y1++;
        }
        for (var yy = y; yy <= y1; yy++) {
          for (var xx = x; xx <= x1; xx++) {
            seen[yy * cols + xx] = 1;
          }
        }
        newWinds.add(WindZone(x, x1, y, y1));
      }
    }
    singles = newSingles;
    runs = newRuns;
    vines = newVines;
    cracks = newCracks;
    winds = newWinds;
    area = index;
  }

  int tileAt(int x, int y) {
    if (x < 0 || y < 0 || x >= cols || y >= rows) return Tile.bark;
    return _tiles[y * cols + x];
  }

  bool isSolidTile(int x, int y) {
    if (x < 0 || y < 0 || x >= cols || y >= rows) return true;
    final i = y * cols + x;
    return _solid.contains(_tiles[i]) || _crackSolid[i] == 1;
  }

  bool isVine(int x, int y) {
    if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
    return _tiles[y * cols + x] == Tile.vine || _ropeVine[y * cols + x] == 1;
  }

  void setCrackSolid(Strip crack, bool solid) {
    for (var y = crack.y0; y <= crack.y1; y++) {
      _crackSolid[y * cols + crack.x] = solid ? 1 : 0;
    }
  }

  void setRope(Strip rope, bool open) {
    if (area != 0) return;
    for (var y = rope.y0; y <= rope.y1; y++) {
      _ropeVine[y * cols + rope.x] = open ? 1 : 0;
    }
  }

  bool crackAt(int x, int y) {
    if (x < 0 || y < 0 || x >= cols || y >= rows) return false;
    return _crackSolid[y * cols + x] == 1;
  }
}
