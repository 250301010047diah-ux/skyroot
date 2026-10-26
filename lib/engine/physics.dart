// Tile collision for axis-aligned bodies.
import 'dart:math' as math;

import 'entities.dart';
import 'world.dart';

const _eps = 0.001;

/// Math.round semantics: halves round up, so negative halves match the original.
int jsRound(double v) => (v + 0.5).floor();

extension Physics on World {
  bool overlapsSolid(double x, double y, double w, double h) {
    final x0 = (x - w / 2 + _eps).floor();
    final x1 = (x + w / 2 - _eps).floor();
    final y0 = (y - h + _eps).floor();
    final y1 = (y - _eps).floor();
    for (var ty = y0; ty <= y1; ty++) {
      for (var tx = x0; tx <= x1; tx++) {
        if (isSolidTile(tx, ty)) return true;
      }
    }
    return false;
  }

  /// Moves a body by (dx, dy) against solid tiles and one-way surfaces.
  MoveResult moveBody(Body b, double dx, double dy, List<Platform> platforms, [bool dropThrough = false]) {
    final out = MoveResult();
    final steps = math.max(1, (math.max(dx.abs(), dy.abs()) / 0.35).ceil());
    final sx = dx / steps;
    final sy = dy / steps;
    for (var i = 0; i < steps; i++) {
      if (sx != 0 && out.hitX == 0) {
        final nx = b.x + sx;
        if (overlapsSolid(nx, b.y, b.w, b.h)) {
          if (sx > 0) {
            b.x = (nx + b.w / 2 - _eps).floor() - b.w / 2 - _eps;
          } else {
            b.x = (nx - b.w / 2 + _eps).floor() + 1 + b.w / 2 + _eps;
          }
          out.hitX = sx > 0 ? 1 : -1;
        } else {
          b.x = nx;
        }
      }
      if (sy != 0 && !out.landed && !out.hitUp) {
        final prevFeet = b.y;
        final ny = b.y + sy;
        if (sy > 0) {
          // Falling: solid tiles first.
          if (overlapsSolid(b.x, ny, b.w, b.h)) {
            b.y = (ny - _eps).floor().toDouble();
            out.landed = true;
            continue;
          }
          if (!dropThrough) {
            final surf = _oneWayCross(b, prevFeet, ny, platforms);
            if (surf != null) {
              b.y = surf.top;
              out.landed = true;
              out.platformId = surf.id;
              continue;
            }
          }
          b.y = ny;
        } else {
          if (overlapsSolid(b.x, ny, b.w, b.h)) {
            b.y = (ny - b.h + _eps).floor() + 1 + b.h + _eps;
            out.hitUp = true;
          } else {
            b.y = ny;
          }
        }
      }
    }
    return out;
  }

  Platform? _oneWayCross(Body b, double prevFeet, double newFeet, List<Platform> platforms) {
    final left = b.x - b.w / 2 + 0.05;
    final right = b.x + b.w / 2 - 0.05;
    // Static branch tiles.
    final r0 = (prevFeet - _eps).floor() + 1;
    final r1 = newFeet.floor();
    for (var r = r0; r <= r1; r++) {
      if (r < prevFeet - _eps) continue;
      for (var tx = left.floor(); tx <= right.floor(); tx++) {
        if (tileAt(tx, r) == Tile.oneway) return Platform(0, 0, r.toDouble(), null);
      }
    }
    Platform? best;
    for (final p in platforms) {
      if (right <= p.x0 || left >= p.x1) continue;
      if (prevFeet <= p.top + 0.02 && newFeet >= p.top) {
        if (best == null || p.top < best.top) best = p;
      }
    }
    return best;
  }

  /// Is there ground (solid or one-way) directly under the feet? Returns null when airborne.
  /// [Ground.id] is null for static tiles.
  Ground? groundUnder(Body b, List<Platform> platforms) {
    final left = b.x - b.w / 2 + 0.05;
    final right = b.x + b.w / 2 - 0.05;
    final r = jsRound(b.y);
    if ((b.y - r).abs() > 0.03) {
      for (final p in platforms) {
        if (!(right <= p.x0 || left >= p.x1) && (b.y - p.top).abs() < 0.03) return Ground(p.id, false);
      }
      return null;
    }
    for (var tx = left.floor(); tx <= right.floor(); tx++) {
      if (isSolidTile(tx, r) || tileAt(tx, r) == Tile.oneway) return const Ground(null, true);
    }
    for (final p in platforms) {
      if (!(right <= p.x0 || left >= p.x1) && (b.y - p.top).abs() < 0.03) return Ground(p.id, false);
    }
    return null;
  }

  bool overlapsTile(Body b, int type, {double? w, double? h}) {
    final bw = w ?? b.w, bh = h ?? b.h;
    final x0 = (b.x - bw / 2 + 0.1).floor();
    final x1 = (b.x + bw / 2 - 0.1).floor();
    final y0 = (b.y - bh + 0.1).floor();
    final y1 = (b.y - 0.1).floor();
    for (var ty = y0; ty <= y1; ty++) {
      for (var tx = x0; tx <= x1; tx++) {
        if (tileAt(tx, ty) == type) return true;
      }
    }
    return false;
  }

  /// Line of sight between two points through solid tiles.
  bool clearLine(double x0, double y0, double x1, double y1) {
    final d = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
    final n = (d / 0.25).ceil();
    for (var i = 1; i < n; i++) {
      final t = i / n;
      if (isSolidTile((x0 + (x1 - x0) * t).floor(), (y0 + (y1 - y0) * t).floor())) return false;
    }
    return true;
  }
}

class Ground {
  const Ground(this.id, this.tile);
  final String? id;
  final bool tile;
}

bool rectsOverlap(Aabb a, Aabb b) => a.x0 < b.x1 && a.x1 > b.x0 && a.y0 < b.y1 && a.y1 > b.y0;

Aabb bodyRect(Body b) => Aabb(b.x - b.w / 2, b.x + b.w / 2, b.y - b.h, b.y);

double hypot(double a, double b) => math.sqrt(a * a + b * b);
