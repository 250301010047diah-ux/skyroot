// Canvas renderer: reads the engine state and draws the world. Never changes
// gameplay state. Port of game js/game/render.js.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../engine/boss.dart';
import '../engine/combat.dart';
import '../engine/content.dart';
import '../engine/engine.dart';
import '../engine/entities.dart';
import '../engine/player.dart';
import '../engine/state.dart';
import '../engine/world.dart';
import 'art.dart';
import 'terrain.dart';

const _archerK = 1.8 / 292;

Color _rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a.clamp(0.0, 1.0));

class WorldRenderer {
  WorldRenderer(this.art, {FilterQuality quality = FilterQuality.medium}) : _img = Paint()..filterQuality = quality;
  final ArtLibrary art;
  final TerrainPainter terrain = TerrainPainter();
  int _terrainArea = -1;

  late Canvas _c;
  late GameState _g;
  late Size _size;
  double _s = 32, _left = 0, _top = 0;
  final Paint _img;
  final Paint _fill = Paint();

  double _sx(double x) => (x - _left) * _s;
  double _sy(double y) => (y - _top) * _s;
  bool _onScreen(num x, num y, [double m = 3]) =>
      x > _left - m && x < _left + _size.width / _s + m && y > _top - m && y < _top + _size.height / _s + m;

  Sheet? _sheet(String key) => art.sheets[key];
  SpriteFrame? _prop(String name) => _sheet('PROPS')?.frames[name];
  SpriteFrame? _aprop(String name) => _sheet('AREA_PROPS')?.frames[name];

  // ---- sprite helpers
  void _drawAnchored(String sheetKey, SpriteFrame? f, double sx, double sy, double k, {bool flip = false, double alpha = 1}) {
    final sh = _sheet(sheetKey);
    if (sh == null || f == null) return;
    final c = f.content;
    _c.save();
    _c.translate(sx.roundToDouble(), sy.roundToDouble());
    if (flip) _c.scale(-1, 1);
    _img.color = _rgba(255, 255, 255, alpha);
    _c.drawImageRect(
      sh.img,
      Rect.fromLTWH(c.x, c.y, c.w, c.h),
      Rect.fromLTWH(-(f.ax - c.x) * k, -(f.ay - c.y) * k, c.w * k, c.h * k),
      _img,
    );
    _c.restore();
  }

  /// Centered draw of a frame's content at (cx, cy).
  void _drawCentered(String sheetKey, SpriteFrame? f, double cx, double cy, double k, {double alpha = 1, double rot = 0, bool flip = false}) {
    final sh = _sheet(sheetKey);
    if (sh == null || f == null) return;
    final c = f.content;
    _c.save();
    _c.translate(cx, cy);
    if (rot != 0) _c.rotate(rot);
    if (flip) _c.scale(-1, 1);
    _img.color = _rgba(255, 255, 255, alpha);
    _c.drawImageRect(sh.img, Rect.fromLTWH(c.x, c.y, c.w, c.h), Rect.fromLTWH(-c.w * k / 2, -c.h * k / 2, c.w * k, c.h * k), _img);
    _c.restore();
  }

  /// Cell-relative draw: keeps each frame's offset inside its source cell (for in-place animations).
  void _drawInCell(String sheetKey, SpriteFrame? f, double ox, double oy, double k, {double? flipAboutX, double alpha = 1}) {
    final sh = _sheet(sheetKey);
    if (sh == null || f == null) return;
    final c = f.content;
    final dx = ox + (c.x - f.source.x) * k;
    final dy = oy + (c.y - f.source.y) * k;
    _c.save();
    if (flipAboutX != null) {
      _c.translate(flipAboutX, 0);
      _c.scale(-1, 1);
      _c.translate(-flipAboutX, 0);
    }
    _img.color = _rgba(255, 255, 255, alpha);
    _c.drawImageRect(sh.img, Rect.fromLTWH(c.x, c.y, c.w, c.h), Rect.fromLTWH(dx, dy, c.w * k, c.h * k), _img);
    _c.restore();
  }

  /// Plain sub-rect draw of a frame's content into [dst].
  void _drawContent(String sheetKey, SpriteFrame? f, Rect dst, {double alpha = 1}) {
    final sh = _sheet(sheetKey);
    if (sh == null || f == null) return;
    final c = f.content;
    _img.color = _rgba(255, 255, 255, alpha);
    _c.drawImageRect(sh.img, Rect.fromLTWH(c.x, c.y, c.w, c.h), dst, _img);
  }

  (String, SpriteFrame?) _shotSprite(String name) {
    final shots = _sheet('AREA_SHOTS')?.frames[name];
    if (shots != null) return ('AREA_SHOTS', shots);
    final props = _sheet('PROPS')?.frames[name];
    if (props != null) return ('PROPS', props);
    final aprops = _sheet('AREA_PROPS')?.frames[name];
    if (aprops != null) return ('AREA_PROPS', aprops);
    return ('PROPS', _sheet('PROPS')?.frames['mud_ball']);
  }

  void _glow(double x, double y, double r, Color color, double a) {
    if (r <= 0 || a <= 0 || x + r < 0 || y + r < 0 || x - r > _size.width || y - r > _size.height) return;
    _fill
      ..shader = ui.Gradient.radial(
        Offset(x, y),
        r,
        [color.withValues(alpha: (0.55 * a).clamp(0.0, 1.0)), color.withValues(alpha: 0)],
      )
      ..blendMode = BlendMode.plus
      ..color = const Color(0xFFFFFFFF);
    _c.drawRect(Rect.fromCircle(center: Offset(x, y), radius: r), _fill);
    _fill
      ..shader = null
      ..blendMode = BlendMode.srcOver;
  }

  void draw(Canvas canvas, Size size, SkyrootEngine engine, {Cam? camOverride}) {
    final g = engine.state;
    final world = engine.world;
    _c = canvas;
    _g = g;
    _size = size;
    final cam = camOverride ?? g.cam;
    _s = engine.view.scale * cam.zoom;
    final s = _s;
    final box = engine.camBox(cam);
    _left = box.left;
    _top = box.top;
    final left = _left, top = _top;
    final w = size.width, h = size.height;
    final time = g.t;
    final atlas = art.atlas;

    _drawBackdrop(engine, left, top);

    // ---- Decor behind gameplay
    for (final d in g.decor) {
      if (!_onScreen(d.x, d.y, 5)) continue;
      final fx = _sx(d.x + 0.5);
      final fy = _sy(d.y + 1.0);
      if (d.g == 'h') {
        final img = art.singles['TREEHOUSE'];
        if (img == null) continue;
        final k = (4.4 * s) / img.width;
        _img.color = const Color(0xFFFFFFFF);
        _c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(fx - (img.width * k) / 2, fy - img.height * k + 0.1 * s, img.width * k, img.height * k),
          _img,
        );
        _glow(fx - 0.6 * s, fy - 1.6 * s, 2.2 * s, _rgba(255, 190, 90, 1), 0.45);
      } else if (d.g == 'l') {
        final sway = math.sin(time * 1.3 + d.x) * 0.04;
        _c.save();
        _c.translate(fx, _sy(d.y.toDouble()));
        _c.rotate(sway);
        _drawAnchored('PROPS', _prop('lantern'), 0, s * 1.0, (1.4 * s) / 344);
        _c.restore();
        _glow(fx, _sy(d.y.toDouble()) + 0.65 * s, 1.9 * s, _rgba(255, 180, 80, 1), 0.7 + math.sin(time * 3 + d.x) * 0.08);
      } else if (d.g == 'm') {
        _drawAnchored('PROPS', _prop('glow_mushrooms'), fx, fy, (1.05 * s) / 282);
        _glow(fx, fy - 0.5 * s, 1.4 * s, _rgba(80, 255, 220, 1), 0.5 + math.sin(time * 2 + d.x) * 0.15);
      } else if (d.g == 's') {
        _drawAnchored('PROPS', _prop('sign'), fx, fy, (1.2 * s) / 310);
      }
    }

    // ---- Vines and rope
    for (final v in world.vines) {
      _drawVine(v.x, v.y0, v.y1);
    }
    if (g.progress.rope) _drawVine(ropeStrip.x, ropeStrip.y0, ropeStrip.y1);

    // ---- Terrain
    if (_terrainArea != g.areaIndex) {
      _terrainArea = g.areaIndex;
      terrain.setArea(bark: areas[g.areaIndex].bark, soft: areas[g.areaIndex].soft);
    }
    if (atlas != null) terrain.draw(canvas, atlas, world, left, top, w, h, s);

    // Cracked walls
    for (final c in g.cracks) {
      if (c.broken || !_onScreen(c.x, c.y0)) continue;
      final web = g.areaIndex == 6;
      final f = web ? _aprop('web_wall') : _prop('cracked_wall');
      if (f == null) continue;
      final hh = c.y1 - c.y0 + 1;
      final k = (hh * s) / f.content.h;
      _drawCentered(web ? 'AREA_PROPS' : 'PROPS', f, _sx(c.x + 0.5), _sy(c.y0 + hh / 2), k);
    }

    // Crystal, ice, sap and ember tiles of the upper areas
    if (g.areaIndex > 0) {
      final x0 = math.max(0, left.floor() - 1);
      final x1 = math.min(world.cols - 1, (left + w / s).ceil() + 1);
      final y0 = math.max(0, top.floor() - 1);
      final y1 = math.min(world.rows - 1, (top + h / s).ceil() + 1);
      final ember = g.emberOn;
      final ap = _sheet('AREA_PROPS');
      for (var ty = y0; ty <= y1; ty++) {
        for (var tx = x0; tx <= x1; tx++) {
          final t = world.tileAt(tx, ty);
          if (t == Tile.crystal || t == Tile.ice) {
            _drawContent('AREA_PROPS', _aprop(t == Tile.crystal ? 'crystal_block' : 'ice_block'),
                Rect.fromLTWH(_sx(tx.toDouble()) - 0.04 * s, _sy(ty.toDouble()) - 0.04 * s, s * 1.08, s * 1.08));
          } else if (t == Tile.sap && world.tileAt(tx, ty - 1) != Tile.sap) {
            _drawContent('AREA_PROPS', _aprop('sap_pool'),
                Rect.fromLTWH(_sx(tx.toDouble()) - 0.05 * s, _sy(ty.toDouble()) - 0.18 * s, s * 1.1, s * 0.34));
          } else if (t == Tile.ember) {
            final warn = !ember && g.emberT > 1.4;
            final f = _aprop(ember ? 'ember_vent' : 'ember_vent_off');
            if (f != null) {
              _drawAnchored('AREA_PROPS', f, _sx(tx + 0.5), _sy(ty + 1.0) + 0.05 * s, ((ember ? 2.2 : 1.1) * s) / f.content.h,
                  alpha: warn && (time * 10).floor() % 2 == 1 ? 0.6 : 1);
            }
            if (ember) _glow(_sx(tx + 0.5), _sy(ty + 0.3), 1.6 * s, _rgba(255, 140, 40, 1), 0.8);
          }
        }
      }
      if (ap != null) {
        for (final m in g.movers) {
          final name = g.areaIndex == 2 ? 'gear_platform' : (g.areaIndex == 10 ? 'star_platform' : 'petal_platform');
          final f = _aprop(name);
          if (f == null) continue;
          final k = ((m.w + 0.3) * s) / f.content.w;
          _drawContent('AREA_PROPS', f, Rect.fromLTWH(_sx(m.px - 0.15), _sy(m.py) - 0.15 * s, f.content.w * k, f.content.h * k));
        }
        for (final v in g.stalactites) {
          if (v.state == 'gone' || !_onScreen(v.x, v.y)) continue;
          final jx = v.state == 'shake' ? math.sin(v.t * 80) * 0.06 * s : 0.0;
          _drawContent('AREA_PROPS', _aprop('stalactite'), Rect.fromLTWH(_sx(v.x + 0.2) + jx, _sy(v.y.toDouble()), s * 0.6, s * 0.95));
        }
      }
    }
    final gate = g.gate;
    if (gate != null && _onScreen(gate.x, gate.y)) {
      final f = _aprop('gate');
      final alpha = gate.active ? 1.0 : 0.18;
      if (f != null) _drawAnchored('AREA_PROPS', f, _sx(gate.x + 0.5), _sy(gate.y + 1.0) + 0.05 * s, (2.8 * s) / f.content.h, alpha: alpha);
      if (gate.active) _glow(_sx(gate.x + 0.5), _sy(gate.y - 0.3), 2.2 * s, _rgba(90, 255, 220, 1), 0.7 + math.sin(time * 3) * 0.2);
    }

    // Branch platforms
    for (final r in world.runs['=']!) {
      if (_onScreen(r.x0, r.y, 8)) _drawBranch(r.x0, r.x1 + 1, r.y);
    }
    if (g.areaIndex == 0 && g.progress.areas[0].boss) {
      for (final n in g.bridge) {
        _drawBranch(n.x0, n.x1 + 1, n.y, alpha: math.min(1.0, g.bridgeT * 1.5));
      }
    }

    // Spikes
    final sp = _prop('thorn_spikes');
    if (sp != null) {
      for (final r in world.runs['^']!) {
        if (!_onScreen(r.x0, r.y)) continue;
        for (var x = r.x0; x <= r.x1; x++) {
          _drawAnchored('PROPS', sp, _sx(x + 0.5), _sy(r.y + 1.0) + 0.05 * s, (1.3 * s) / sp.content.w);
        }
      }
    }

    // Wind
    final windAnim = _sheet('WORLD_ANIM')?.anims['wind_gust'];
    if (windAnim != null && windAnim.isNotEmpty) {
      for (final wd in g.winds) {
        if (!_onScreen(wd.x0, wd.y0, 20)) continue;
        final warn = !wd.on && wd.t > 1.0;
        final alpha = wd.on ? 0.85 : (warn ? ((time * 12).floor() % 2 == 1 ? 0.45 : 0.2) : 0.1);
        final width = (wd.x1 - wd.x0 + 1) * 1.3;
        final k = (width * s) / 175;
        final segH = 380 * k;
        final cx = _sx((wd.x0 + wd.x1 + 1) / 2);
        _c.save();
        _c.clipRect(Rect.fromLTWH(cx - width * s, _sy(wd.y0.toDouble()) - 0.6 * s, width * 2 * s, _sy(wd.y1 + 1.0) - _sy(wd.y0.toDouble()) + 0.6 * s));
        var i = 0;
        for (var yy = _sy(wd.y1 + 1.0); yy > _sy(wd.y0.toDouble()) - segH; yy -= segH * 0.82) {
          final f = windAnim[((time * 10).floor() + i * 2) % windAnim.length];
          _drawAnchored('WORLD_ANIM', f, cx, yy, k, flip: i % 2 == 1, alpha: alpha);
          i++;
        }
        _c.restore();
      }
    }

    // Leaves
    final wa = _sheet('WORLD_ANIM');
    if (wa != null) {
      final foldLeaf = wa.anims['fold_leaf'];
      for (final l in g.leaves) {
        if (foldLeaf == null || !_onScreen(l.x0, l.y, 6)) continue;
        final n = l.x1 - l.x0 + 1;
        var i = 0;
        if (l.state == 'trem') {
          i = 1 + ((l.t * 14).floor() % 2);
        } else if (l.state == 'fold') {
          i = 3 + math.min(2, ((l.t / 0.25) * 3).floor());
        } else if (l.state == 'closed') {
          i = 5;
        } else if (l.state == 'opening') {
          i = math.max(0, 5 - ((l.t / 0.3) * 6).floor());
        }
        i = i.clamp(0, foldLeaf.length - 1);
        final k = ((n + 0.3) * s) / 382;
        final f = foldLeaf[i];
        if (f.surfaceY != null) {
          final c = f.content;
          _drawContent('WORLD_ANIM', f,
              Rect.fromLTWH(_sx(l.x0 + n / 2) - c.w * k / 2, _sy(l.y.toDouble()) - (f.surfaceY! - c.y) * k, c.w * k, c.h * k));
        } else {
          _drawInCell('WORLD_ANIM', f, _sx(l.x0 - 0.15) + 28 * k, _sy(l.y.toDouble()) - 154 * k, k);
        }
      }

      // Crumbling slabs
      final crumbleAnim = wa.anims['crumble_platform'];
      for (final c in g.crumbles) {
        if (c.state == 'gone' || !_onScreen(c.x0, c.y, 6) || crumbleAnim == null) continue;
        final n = c.x1 - c.x0 + 1;
        var i = 0;
        var jx = 0.0;
        var alpha = 1.0;
        if (c.state == 'shake') {
          i = c.t > 0.3 ? 1 : 0;
          jx = math.sin(c.t * 70) * 0.05 * s;
        } else if (c.state == 'fall') {
          i = 2 + math.min(3, ((c.t / 0.35) * 4).floor());
        } else if (c.state == 'back') {
          alpha = c.t / 0.4;
        }
        if (g.areaIndex == 7) {
          final f = _aprop('cloud_platform');
          if (f == null) continue;
          final k = ((n + 0.4) * s) / f.content.w;
          final a = c.state == 'fall' ? math.max(0.0, 1 - c.t / 0.35) : alpha;
          _drawContent('AREA_PROPS', f, Rect.fromLTWH(_sx(c.x0 - 0.2) + jx, _sy(c.y.toDouble()) - 0.3 * s, f.content.w * k, f.content.h * k), alpha: a);
          continue;
        }
        final k = ((n + 0.25) * s) / 352;
        final f = crumbleAnim[i.clamp(0, crumbleAnim.length - 1)];
        final fall = c.state == 'fall' ? c.t * c.t * 8 * s : 0.0;
        if (f.surfaceY != null) {
          final box = f.content;
          _drawContent('WORLD_ANIM', f,
              Rect.fromLTWH(_sx(c.x0 + n / 2) - box.w * k / 2 + jx, _sy(c.y.toDouble()) - (f.surfaceY! - box.y) * k + fall, box.w * k, box.h * k),
              alpha: alpha);
        } else {
          _drawInCell('WORLD_ANIM', f, _sx(c.x0 - 0.12) + 9 * k + jx, _sy(c.y.toDouble()) - 65 * k + fall, k, alpha: alpha);
        }
      }

      // Launch flowers
      final flowerAnim = wa.anims['launch_flower'];
      for (final f in g.flowers) {
        if (!_onScreen(f.x, f.y)) continue;
        var i = 0;
        if (f.state == 'charge') {
          i = 1 + (f.t > 0.25 ? 1 : 0);
        } else if (f.state == 'launch') {
          i = math.min(5, 3 + (f.t * 6).floor());
        }
        if (g.areaIndex == 5) {
          final fm = _aprop('bounce_mushroom');
          final sq = f.state == 'charge' ? 0.75 : (f.state == 'launch' && f.t < 0.2 ? 1.25 : 1.0);
          _c.save();
          _c.translate(_sx(f.x + 0.5), _sy(f.y + 1.0));
          _c.scale(1 / math.sqrt(sq), sq);
          if (fm != null) _drawAnchored('AREA_PROPS', fm, 0, 0, (1.2 * s) / fm.content.h);
          _c.restore();
        } else if (flowerAnim != null) {
          _drawAnchored('WORLD_ANIM', flowerAnim[i.clamp(0, flowerAnim.length - 1)], _sx(f.x + 0.5), _sy(f.y + 1.0), (1.5 * s) / 224);
        }
        if (f.state == 'charge') _glow(_sx(f.x + 0.5), _sy(f.y + 0.4), 1.4 * s, _rgba(120, 255, 200, 1), f.t * 2);
      }
    }

    // Checkpoints
    final shrines = _sheet('SHRINES');
    if (shrines != null) {
      for (final k in g.checkpoints) {
        if (!_onScreen(k.x, k.y)) continue;
        final lit = g.areaProg.cp == k.id || k.lit;
        final i = lit ? 1 + ((k.animT * 8).floor() % 5) : 0;
        _drawAnchored('SHRINES', shrines.frameOf('checkpoint', i), _sx(k.x + 0.5), _sy(k.y + 1.0), (1.7 * s) / 304);
        if (lit) _glow(_sx(k.x + 0.5), _sy(k.y + 0.3), 2.0 * s, _rgba(90, 255, 220, 1), 0.8);
      }

      // Bell
      final bell = g.bell;
      if (bell != null && _onScreen(bell.x, bell.y)) {
        final ring = g.progress.bell || g.bellRing > 0;
        final i = ring ? (bell.animT * 7).floor() % 6 : 0;
        _drawAnchored('SHRINES', shrines.frameOf('bell', i), _sx(bell.x + 0.5), _sy(bell.y + 1.0), (2.3 * s) / 306);
        if (g.progress.areas[0].boss && !g.progress.bell) {
          _glow(_sx(bell.x + 0.5), _sy(bell.y.toDouble()), 2.4 * s, _rgba(255, 220, 120, 1), 0.6 + math.sin(time * 4) * 0.3);
        }
      }
    }

    // Lift stations
    final lift = g.lift;
    if (lift != null) {
      for (final st in [lift.top, lift.bottom]) {
        if (!_onScreen(st.x, st.y)) continue;
        final f = _prop('root_lift');
        if (f == null) continue;
        final k = (2.4 * s) / f.content.w;
        _drawAnchored('PROPS', f, _sx(st.x + 0.5), _sy(st.y + 1.0) + 0.12 * s, k, alpha: g.progress.lift ? 1 : 0.55);
        if (g.progress.lift && st.near) _drawPrompt(_sx(st.x + 0.5), _sy(st.y - 1.6), identical(st, lift.bottom) ? 'up' : 'down');
      }
    }

    // Rope anchor
    final rope = g.rope;
    if (rope != null && _onScreen(rope.x, rope.y)) {
      final f = _sheet('VINE_TILES')?.frames['top_cap'];
      if (f != null) {
        _drawCentered('VINE_TILES', f, _sx(rope.x + 0.5), _sy(rope.y + 0.4), (0.9 * s) / f.content.h * 1.2,
            rot: g.progress.rope ? 0 : math.sin(time * 2) * 0.1);
      }
      if (!g.progress.rope) _glow(_sx(rope.x + 0.5), _sy(rope.y + 0.4), 1.4 * s, _rgba(120, 255, 200, 1), 0.5 + math.sin(time * 3) * 0.2);
    }

    // Footings
    final sprout = _sheet('EFFECTS')?.anims['footing_sprout'];
    if (sprout != null && sprout.length >= 6) {
      final last = sprout[5];
      final fk = (2.15 * s) / last.content.w;
      for (final f in g.footings) {
        if (!_onScreen(f.x0, f.top)) continue;
        final i = math.min(5, ((f.t / 0.22) * 6).floor());
        final wallX = f.wallDir > 0 ? _sx(f.x1) : _sx(f.x0);
        final rightRel = last.content.x + last.content.w - last.source.x;
        final ox = wallX - rightRel * fk;
        final oy = _sy(f.top) - (last.content.y + 24 - last.source.y) * fk;
        final blink = f.dying != 0 ? ((f.dying * 16).floor() % 2 == 1 ? 0.25 : 1.0) : 1.0;
        _drawInCell('EFFECTS', sprout[i], ox, oy, fk, flipAboutX: f.wallDir > 0 ? null : wallX, alpha: blink);
        if (f.t < 0.5) _glow(_sx((f.x0 + f.x1) / 2), _sy(f.top), 1.6 * s, _rgba(90, 255, 210, 1), 1 - f.t * 2);
      }
    }

    // Pickups
    const pickupSprite = {'H': 'heart_pickup', 'E': 'energy_stone', 'D': 'dash_relic', 'A': 'footing_relic', 'R': 'heart_relic', 'Y': 'golden_feather'};
    for (final it in g.pickups) {
      if (it.taken || !_onScreen(it.x, it.y)) continue;
      final size = it.kind == 'H' ? 0.75 : 1.15;
      final f = _prop(pickupSprite[it.kind]!);
      final bob = math.sin(it.t * 3 + it.x) * 0.12;
      final col = it.kind == 'H' || it.kind == 'R' ? _rgba(255, 120, 120, 1) : (it.kind == 'Y' ? _rgba(255, 220, 90, 1) : _rgba(90, 255, 220, 1));
      _glow(_sx(it.x + 0.5), _sy(it.y + 0.5 + bob), (size + 0.8) * s, col, 0.7);
      if (f != null) _drawCentered('PROPS', f, _sx(it.x + 0.5), _sy(it.y + 0.5 + bob), (size * s) / math.max(f.content.w, f.content.h));
    }

    // Villagers
    for (final v in g.villagers) {
      if (!_onScreen(v.x, v.y)) continue;
      final px = g.player.x;
      _drawAnchored('PROPS', _prop('villager'), _sx(v.x + 0.5), _sy(v.y + 1.0) + math.sin(time * 2) * 0.02 * s, (1.85 * s) / 328, flip: px < v.x + 0.5);
    }

    // Enemies
    for (final e in g.enemies) {
      if (!_onScreen(e.x, e.y)) continue;
      _drawEnemy(e, time);
    }

    // Boss
    _drawBoss(g, time);

    // Beams (marked lightning columns) and skill bolts
    for (final bm in g.beams) {
      final x = _sx(bm.x);
      if (bm.t < bm.warn) {
        final k = math.max(0.0, bm.t / bm.warn);
        _fill.color = _rgba(255, 240, 120, 0.12 + k * 0.25);
        _c.drawRect(Rect.fromLTRB(x - 0.45 * s, _sy(1), x + 0.45 * s, _sy(12)), _fill);
      } else {
        _drawBolt(x, _sy(0.5), x + math.sin(bm.t * 40) * 6, _sy(12), s, 1 - (bm.t - bm.warn) / bm.life);
      }
    }
    for (final bo in g.bolts) {
      _drawBolt(_sx(bo.x0), _sy(bo.y0), _sx(bo.x1), _sy(bo.y1), s, 1 - bo.t / bo.dur);
    }

    // Arrows
    for (final a in g.arrows) {
      if (!_onScreen(a.x, a.y)) continue;
      final (ash, f) = _shotSprite(a.sprite);
      if (f == null) continue;
      final ang = a.state == 'drop' ? a.spin : math.atan2(a.vy, a.vx);
      final alpha = a.state == 'stuck' ? math.max(0.0, 1 - math.max(0.0, a.t - 1.0) / 0.4) : 1.0;
      final k = (1.15 * s) / f.content.w;
      final back = a.state == 'stuck' ? 0.25 : 0.4;
      _drawCentered(ash, f, _sx(a.x - math.cos(ang) * back), _sy(a.y - math.sin(ang) * back), k, alpha: alpha, rot: ang);
      if (a.state == 'fly' && (a.full || a.kind == 'footing')) {
        _glow(_sx(a.x), _sy(a.y), 0.7 * s, a.kind == 'footing' ? _rgba(90, 255, 210, 1) : _rgba(255, 240, 200, 1), 0.6);
      }
    }

    // Player
    _drawPlayer(g, time);

    // Enemy projectiles
    for (final p in g.eproj) {
      if (!_onScreen(p.x, p.y)) continue;
      _drawEProj(p, time);
    }
    for (final wn in g.warnings) {
      final k = math.min(1.0, wn.t / wn.dur);
      _fill.color = _rgba(20, 10, 5, 0.25 + k * 0.35);
      _c.drawOval(Rect.fromCenter(center: Offset(_sx(wn.x + 0.5), _sy(12) - 0.05 * s), width: 2 * s * (0.3 + k * 0.4), height: 2 * s * 0.12), _fill);
    }

    // Effects
    final fxSheet = _sheet('EFFECTS');
    if (fxSheet != null) {
      for (final f in g.fx) {
        if (!_onScreen(f.x, f.y)) continue;
        final fr = fxSheet.anims[f.kind];
        // Staggered effects start with a negative t; wait until they begin instead of indexing a frame.
        if (fr == null || fr.isEmpty || f.t < 0) continue;
        final i = ((f.t / f.dur) * 6).floor().clamp(0, fr.length - 1);
        final base = f.kind == 'arrow_hit' ? 0.9 : (f.kind == 'dust' ? 1.0 : 1.9);
        _drawAnchored('EFFECTS', fr[i], _sx(f.x), _sy(f.y) + (f.kind == 'arrow_hit' ? 0.45 * s * f.scale : 0), (base * f.scale * s) / 260, flip: f.flip);
      }
    }
    for (final p in g.particles) {
      final a = (p.life / p.max).clamp(0.0, 1.0);
      final sz = math.max(1.5, p.size * s);
      _fill.color = Color(p.color).withValues(alpha: a);
      _c.drawRect(Rect.fromLTWH((_sx(p.x) - sz / 2).roundToDouble(), (_sy(p.y) - sz / 2).roundToDouble(), sz, sz), _fill);
    }

    _drawSpores(g, left, top);

    // Aim trajectory
    final pl = g.player;
    if (pl.aiming && pl.mode == 'normal') {
      final power = math.min(1.0, pl.aimT / 0.55);
      final l = arrowLaunch(pl, pl.aimX, pl.aimY, power, g.tune);
      final footing = g.progress.footing && g.arrowType == 'footing';
      var x = l.x, y = l.y, vx = l.vx, vy = l.vy;
      final dotColor = footing ? const Color(0xF278FFDC) : (power >= 1 ? const Color(0xF2FFECAA) : const Color(0xD9FFFFFF));
      for (var i = 0; i < 26; i++) {
        for (var k = 0; k < 3; k++) {
          vy += l.g * 0.012;
          x += vx * 0.012;
          y += vy * 0.012;
        }
        if (world.isSolidTile(x.floor(), y.floor())) break;
        final r = math.max(1.5, s * 0.07 * (1 - i / 34));
        _fill.color = dotColor.withValues(alpha: (dotColor.a * (1 - i / 30)).clamp(0.0, 1.0));
        _c.drawCircle(Offset(_sx(x), _sy(y)), r, _fill);
      }
      // Draw meter ring around the archer.
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, s * 0.07)
        ..color = power >= 1 ? const Color(0xF2FFE68C) : const Color(0x8CFFFFFF);
      _c.drawArc(Rect.fromCircle(center: Offset(_sx(pl.x), _sy(pl.y - 0.8)), radius: s * 1.05), -math.pi / 2, math.pi * 2 * power, false, ring);
    }

    // Bottom fog + vignette
    final fogDepth = ((cam.y - 60) / 30).clamp(0.0, 1.0);
    final fogA = 0.18 + fogDepth * 0.12;
    _fill
      ..shader = ui.Gradient.linear(Offset(0, h * 0.72), Offset(0, h), [_rgba(150, 200, 190, 0), _rgba(150, 200, 190, fogA)])
      ..color = const Color(0xFFFFFFFF);
    _c.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), _fill);
    final minD = math.min(w, h), maxD = math.max(w, h);
    _fill.shader = ui.Gradient.radial(
      Offset(w / 2, h * 0.48),
      maxD * 0.75,
      [_rgba(0, 0, 0, 0), _rgba(3, 12, 10, 0.5)],
      [(minD * 0.35 / (maxD * 0.75)).clamp(0.0, 0.95), 1],
    );
    _c.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    _fill.shader = null;

    if (g.slow < 0.95) {
      _fill.color = _rgba(60, 200, 190, (1 - g.slow) * 0.16);
      _c.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    }
    if (g.lift?.ride != null) {
      final t = g.lift!.ride!.t;
      final a = t < 0.55 ? t / 0.55 : math.max(0.0, 1 - (t - 0.55) / 0.55);
      _fill.color = _rgba(4, 10, 8, a);
      _c.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    }
    if (g.player.mode == 'dead') {
      _fill.color = _rgba(4, 10, 8, math.max(0.0, (g.player.deadT - 0.8) / 0.6));
      _c.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    }
    if (g.tune.showHitboxes) _drawHitboxes(g);
  }

  void _drawBackdrop(SkyrootEngine engine, double left, double top) {
    final g = _g;
    final w = _size.width, h = _size.height;
    final s = _s;
    final img = art.singles[areas[g.areaIndex].bg] ?? art.singles['BACKDROP'];
    if (img == null) {
      _fill.color = const Color(0xFF08151A);
      _c.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
      return;
    }
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    final bw = math.max(w * 1.12, (h * 0.75 * iw) / ih);
    final bh = (bw * ih) / iw;
    var maxLeft = engine.world.cols * s - w;
    if (maxLeft == 0) maxLeft = 1;
    final ox = -((left * s) / math.max(1.0, maxLeft)) * (bw - w);
    final scroll = top * s * 0.22;
    final start = (scroll / bh).floor();
    _img.color = const Color(0xFFFFFFFF);
    final src = Rect.fromLTWH(0, 0, iw, ih);
    for (var i = start; i * bh - scroll < h; i++) {
      final y = i * bh - scroll;
      if (i % 2 != 0) {
        _c.save();
        _c.translate(0, y + bh);
        _c.scale(1, -1);
        _c.drawImageRect(img, src, Rect.fromLTWH(ox, 0, bw, bh), _img);
        _c.restore();
      } else {
        _c.drawImageRect(img, src, Rect.fromLTWH(ox, y, bw, bh), _img);
      }
    }
    // Altitude light: warm high up, deep teal below, dark in the cave.
    final depth = (g.cam.y / engine.world.rows).clamp(0.0, 1.0);
    _fill.color = _rgba(255, 214, 150, 0.16 * math.pow(1 - depth, 2));
    _c.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    _fill.color = _rgba(4, 22, 20, 0.12 + 0.28 * depth * depth);
    _c.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    final caveY = (86 - top) * s;
    if (g.areaIndex == 0 && caveY < h) {
      _fill.color = _rgba(6, 12, 14, 0.62);
      _c.drawRect(Rect.fromLTWH(0, math.max(0.0, caveY), w, h - math.max(0.0, caveY)), _fill);
    }
    // Hollow trunk interior is dimmer.
    final tx0 = (17 - left) * s, tx1 = (23 - left) * s, ty0 = (23 - top) * s, ty1 = (80 - top) * s;
    if (g.areaIndex == 0 && tx1 > 0 && tx0 < w && ty1 > 0 && ty0 < h) {
      _fill.color = _rgba(10, 20, 14, 0.35);
      _c.drawRect(Rect.fromLTRB(tx0, ty0, tx1, ty1), _fill);
    }
    // Drifting fog bands.
    for (var i = 0; i < 3; i++) {
      final y = (((g.t * (6 + i * 3) + i * 230 - top * s * (0.35 + i * 0.1)) % (h + 300)) + h + 300) % (h + 300) - 150;
      _fill.shader = ui.Gradient.linear(Offset(0, y - 60), Offset(0, y + 60),
          [_rgba(170, 230, 215, 0), _rgba(170, 230, 215, 0.07), _rgba(170, 230, 215, 0)], [0, 0.5, 1]);
      _c.drawRect(Rect.fromLTWH(0, y - 60, w, 120), _fill);
      _fill.shader = null;
    }
  }

  void _drawSpores(GameState g, double left, double top) {
    final w = _size.width, h = _size.height, s = _s;
    for (var i = 0; i < 26; i++) {
      final hx = ((i * 7919) % 1000) / 1000;
      final hy = ((i * 104729) % 1000) / 1000;
      final px = ((hx * w + math.sin(g.t * 0.4 + i) * 30 - left * s * 0.6) % w + w) % w;
      final py = ((hy * h - g.t * (8 + (i % 5) * 3) - top * s * 0.6) % h + h) % h;
      final a = 0.25 + 0.25 * math.sin(g.t * 2 + i * 1.7);
      _fill
        ..color = i % 4 == 0 ? _rgba(255, 210, 120, a) : _rgba(120, 255, 220, a)
        ..blendMode = BlendMode.plus;
      final sz = math.max(1.5, s * 0.06);
      _c.drawRect(Rect.fromLTWH(px.roundToDouble(), py.roundToDouble(), sz, sz), _fill);
    }
    _fill.blendMode = BlendMode.srcOver;
  }

  void _drawVine(int x, int y0, int y1) {
    final s = _s;
    final vt = _sheet('VINE_TILES');
    final cap = vt?.frames['top_cap'];
    final body = vt?.frames['body'];
    if (vt == null || cap == null || body == null) return;
    final k = (0.8 * s) / body.content.w;
    final cx = _sx(x + 0.5);
    final segH = body.content.h * k;
    var yy = _sy(y0.toDouble()) + 0.6 * s;
    final end = _sy(y1 + 1.0);
    _img.color = const Color(0xFFFFFFFF);
    while (yy < end) {
      final hpx = math.min(segH, end - yy);
      if (yy + hpx > -10 && yy < _size.height + 10) {
        _c.drawImageRect(
          vt.img,
          Rect.fromLTWH(body.content.x, body.content.y, body.content.w, hpx / k),
          Rect.fromLTWH(cx - (body.content.w * k) / 2, yy, body.content.w * k, hpx),
          _img,
        );
      }
      yy += segH - 1;
    }
    final ck = (0.8 * s) / body.content.w;
    _c.drawImageRect(
      vt.img,
      Rect.fromLTWH(cap.content.x, cap.content.y, cap.content.w, cap.content.h),
      Rect.fromLTWH(cx - (cap.content.w * ck) / 2, _sy(y0.toDouble()) - 0.4 * s, cap.content.w * ck, cap.content.h * ck),
      _img,
    );
  }

  void _drawBranch(int x0, int x1, int y, {double alpha = 1}) {
    final s = _s;
    final bt = _sheet('BRANCH_TILES');
    final L = bt?.frames['left'], C = bt?.frames['center'], R = bt?.frames['right'];
    if (bt == null || L == null || C == null || R == null) return;
    final k = s / 224; // one tile = 224 sheet px
    final surf = L.surfaceY ?? L.content.y;
    final top = _sy(y.toDouble());
    _img.color = _rgba(255, 255, 255, alpha);
    void piece(SpriteFrame f, double dx, double srcX, double srcW) {
      final c = f.content;
      _c.drawImageRect(bt.img, Rect.fromLTWH(srcX, c.y, srcW, c.h), Rect.fromLTWH(dx, top - (surf - c.y) * k, srcW * k + 0.5, c.h * k), _img);
    }

    piece(L, _sx(x0.toDouble()) + (L.content.x - L.source.x) * k, L.content.x, L.content.w);
    var cx = x0 + 1;
    final right = x1 - 1;
    while (cx < right) {
      final tiles = math.min(3, right - cx);
      piece(C, _sx(cx.toDouble()), C.content.x, tiles * 224.0);
      cx += tiles;
    }
    piece(R, _sx(math.max(x0 + 1, x1 - 1).toDouble()) + (R.content.x - R.source.x) * k, R.content.x, R.content.w);
  }

  void _drawEnemy(Enemy e, double time) {
    final s = _s;
    final flash = e.hurtT > 0 && (e.hurtT * 30).floor() % 2 == 0 ? 0.45 : 1.0;
    final flip = e.face < 0;
    if (e.type == 'thorn') {
      var anim = 'thorn_guard';
      var i = (e.animT * 6).floor() % 6;
      if (e.state == 'wind') {
        anim = 'thorn_guard_attack';
        i = math.min(2, ((e.t / 0.62) * 3).floor());
      } else if (e.state == 'fire') {
        anim = 'thorn_guard_attack';
        i = e.t < 0.6 ? 3 + ((e.t * 12).floor() % 2) : 5;
      }
      _drawAnchored('ENEMIES_A', _sheet('ENEMIES_A')?.frameOf(anim, i), _sx(e.x), _sy(e.y) + 0.06 * s, (1.5 * s) / 273, flip: flip, alpha: flash);
      if (e.state == 'wind') _glow(_sx(e.x + e.face * 0.2), _sy(e.y - 0.7), 1.2 * s, _rgba(255, 60, 40, 1), e.t * 1.5);
    } else if (e.type == 'beetle') {
      final i = (e.animT * 9).floor() % 6;
      _drawAnchored('ENEMIES_A', _sheet('ENEMIES_A')?.frameOf('shield_beetle', i), _sx(e.x), _sy(e.y) + 0.04 * s, (1.85 * s) / 290, flip: flip, alpha: flash);
    } else if (e.type == 'frog') {
      var anim = 'cannon_frog';
      var i = (e.animT * 6).floor() % 6;
      if (e.state == 'wind') {
        anim = 'cannon_frog_attack';
        i = math.min(2, ((e.t / 0.72) * 3).floor());
      } else if (e.state == 'recover') {
        anim = 'cannon_frog_attack';
        i = 3 + math.min(2, (e.t * 6).floor());
      }
      _drawAnchored('ENEMIES_B', _sheet('ENEMIES_B')?.frameOf(anim, i), _sx(e.x), _sy(e.y) + 0.04 * s, (1.85 * s) / 304, flip: flip, alpha: flash);
      if (e.state == 'wind') _drawTarget(_sx(e.tx), _sy(e.ty), s, e.t / 0.72);
    } else {
      final m = monsters[e.type];
      final sh = m == null ? null : _sheet(m.sheet);
      if (m == null || sh == null) return;
      final attacking = const {'wind', 'dive', 'attack', 'spit', 'drop', 'recover', 'hop'}.contains(e.state);
      final row = attacking ? '${m.anim}_attack' : m.anim;
      final list = sh.anims[row] ?? sh.anims[m.anim];
      if (list == null || list.isEmpty) return;
      var i = (e.animT * 9).floor() % list.length;
      if (e.state == 'wind') i = math.min(2, ((e.t / 0.6) * 3).floor());
      if (m.ai == 'dropper') {
        final line = Paint()
          ..color = const Color(0xB3F0F0FA)
          ..strokeWidth = math.max(1, s * 0.04)
          ..style = PaintingStyle.stroke;
        _c.drawLine(Offset(_sx(e.x), _sy(e.hy - 3)), Offset(_sx(e.x), _sy(e.y - e.h)), line);
      }
      final f = list[i.clamp(0, list.length - 1)];
      final ch = f.content.h;
      _drawAnchored(m.sheet, f, _sx(e.x), _sy(e.y) + (m.fly ? 0 : 0.04 * s), (m.size * s) / math.max(200, ch), flip: flip, alpha: flash);
      if (e.state == 'wind') _glow(_sx(e.x), _sy(e.y - e.h / 2), 1.2 * s, _rgba(255, 90, 60, 1), e.t * 1.6);
    }
    if (e.burnT > 0) _glow(_sx(e.x), _sy(e.y - e.h / 2), 0.9 * s, _rgba(255, 120, 30, 1), 0.7);
    if (e.slowT > 0) _glow(_sx(e.x), _sy(e.y - e.h / 2), 0.9 * s, _rgba(120, 200, 255, 1), 0.6);
  }

  void _drawBoss(GameState g, double time) {
    final b = g.boss;
    final s = _s;
    if (b is StagBoss && b.state != 'gone' && _onScreen(b.x, b.y, 10)) {
      var anim = 'tower_stag';
      var i = (b.animT * 6).floor() % 6;
      if (b.state == 'shoot') {
        anim = 'tower_stag_shoot';
        const seq = [0, 0, 1, 4, 5, 5];
        final k = b.t < 0.75 ? b.t / 0.75 : (b.t - 0.75) / 0.6;
        final off = b.t < 0.75 ? 0 : 3;
        i = seq[off + math.min(2, (k * 3).floor())];
      } else if (b.state == 'stomp') {
        anim = 'tower_stag_stomp';
        i = b.t < 0.62 ? 0 : math.min(5, 1 + ((b.t - 0.62) * 9).floor());
      } else if (b.state == 'stunned') {
        anim = 'tower_stag_stunned';
      }
      final alpha = b.state == 'dying' ? 1 - b.fade : (b.hurtT > 0 && (b.hurtT * 30).floor() % 2 == 1 ? 0.5 : 1.0);
      _drawAnchored('BOSS_STAG', _sheet('BOSS_STAG')?.frameOf(anim, i), _sx(b.x), _sy(b.y) + 0.05 * s, stagScale * s, alpha: alpha);
      if (b.state != 'stunned' && b.state != 'dying') {
        for (var n = 0; n < 3; n++) {
          if (!b.nodes[n]) continue;
          final np = nodePos(b, n);
          final flare = b.state == 'shoot' && b.t < 0.75 ? 1.3 : 1.0;
          _glow(_sx(np.x), _sy(np.y), 0.9 * s * flare, _rgba(90, 255, 210, 1), 0.9 + math.sin(time * 5 + n) * 0.2);
          final ring = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, s * 0.06)
            ..color = const Color(0xE6DCFFF5);
          _c.drawCircle(Offset(_sx(np.x), _sy(np.y)), s * (0.42 + math.sin(time * 6 + n) * 0.05), ring);
        }
      }
      if (b.state == 'stunned') {
        final wp = weakPos(b);
        _glow(_sx(wp.x), _sy(wp.y), 1.4 * s, _rgba(255, 210, 80, 1), 0.9 + math.sin(time * 8) * 0.2);
      }
      if (b.state == 'stomp' && b.t < 0.62) _glow(_sx(b.x - 1.8), _sy(b.y), 2 * s, _rgba(255, 150, 60, 1), b.t * 1.4);
    }

    if (b is AreaBoss && b.state != 'gone') {
      final cfg = bosses[b.area]!;
      final sh = _sheet(cfg.sheet);
      if (sh == null) return;
      var row = cfg.anim;
      if (b.hurtT > 0.3) {
        row = '${cfg.anim}_hurt';
      } else if (const {'spray', 'ring', 'beam', 'summon'}.contains(b.state)) {
        row = '${cfg.anim}_attack';
      } else if (const {'shock', 'charge', 'dive', 'rain'}.contains(b.state)) {
        row = '${cfg.anim}_special';
      } else if (b.state == 'tired') {
        row = '${cfg.anim}_hurt';
      }
      final base = sh.anims[cfg.anim];
      final list = sh.anims[row] ?? base;
      if (list == null || list.isEmpty || base == null || base.isEmpty) return;
      final i = (b.animT * 7).floor() % list.length;
      var f = list[i];
      // Skip frames whose art came out broken (tiny or wildly oversized).
      if (f.content.h < 120 || f.content.w > 460) f = base[i % base.length];
      final alpha = b.state == 'dying' ? 1 - b.fade : (b.hurtT > 0 && (b.hurtT * 30).floor() % 2 == 1 ? 0.55 : 1.0);
      final k = (cfg.height * s) / 340;
      _drawAnchored(cfg.sheet, f, _sx(b.x), _sy(b.y) + 0.05 * s, k, flip: b.face > 0, alpha: alpha);
      if (b.tired > 0) _glow(_sx(b.x), _sy(b.y - cfg.height * 0.5), 2.4 * s, _rgba(255, 230, 120, 1), 0.5);
      if (b.state == 'charge' && b.t < 0.6) _glow(_sx(b.x), _sy(b.y - 1), 2 * s, _rgba(255, 120, 60, 1), b.t * 1.5);
    }
  }

  void _drawEProj(EProj p, double time) {
    final s = _s;
    switch (p.kind) {
      case 'thorn':
        _drawCentered('PROPS', _prop('thorn_shot'), _sx(p.x), _sy(p.y), (0.85 * s) / 308, flip: p.vx < 0);
      case 'mud':
        _drawCentered('PROPS', _prop('mud_ball'), _sx(p.x), _sy(p.y), (0.6 * s) / 229, rot: p.t * 6);
      case 'seed':
        _glow(_sx(p.x), _sy(p.y), 0.8 * s, _rgba(90, 255, 200, 1), 0.8);
        _drawCentered('PROPS', _prop('stag_seed'), _sx(p.x), _sy(p.y), (0.65 * s) / 304, rot: p.t * 5);
      case 'debris':
        if (p.sprite != null) {
          final (sk, f) = _shotSprite(p.sprite!);
          if (f != null) _drawCentered(sk, f, _sx(p.x), _sy(p.y), (0.85 * s) / math.max(f.content.w, f.content.h), rot: p.t * 4);
        } else {
          _drawCentered('PROPS', _prop('mud_ball'), _sx(p.x), _sy(p.y), (0.8 * s) / 229, rot: p.t * 3);
        }
      case 'shot':
        final String sk;
        final SpriteFrame? f;
        if (p.sheet != null) {
          sk = p.sheet!;
          f = _sheet(sk)?.frames[p.sprite];
        } else {
          (sk, f) = _shotSprite(p.sprite ?? 'mud_ball');
        }
        if (f == null) return;
        final size = p.upright ? 0.95 : 0.7;
        final rot = p.orient ? math.atan2(p.vy, p.vx) : (p.spin ? p.t * 6 : 0.0);
        if (!p.upright) _glow(_sx(p.x), _sy(p.y), 0.7 * s, _rgba(255, 230, 200, 1), 0.35);
        _drawCentered(sk, f, _sx(p.x), _sy(p.y), (size * s) / math.max(f.content.w, f.content.h), rot: rot);
      case 'shock':
        final dust = _sheet('EFFECTS')?.anims['dust'];
        if (dust != null && dust.isNotEmpty) {
          _drawAnchored('EFFECTS', dust[(p.t * 14).floor() % math.min(3, dust.length)], _sx(p.x), _sy(p.y + 0.4), (1.3 * s) / 270);
        }
        _glow(_sx(p.x), _sy(p.y), 1.0 * s, _rgba(255, 170, 90, 1), 0.6);
    }
  }

  void _drawPlayer(GameState g, double time) {
    final p = g.player;
    final s = _s;
    if (p.mode == 'lift' && g.lift?.ride != null && g.lift!.ride!.t > 0.4 && g.lift!.ride!.t < 0.7) return;
    if (p.invuln > 0 && p.mode != 'dead' && (p.invuln * 14).floor() % 2 == 0) return;
    var sheet = 'ARCHER_A';
    var anim = p.anim;
    var i = 0;
    var px = p.x, py = p.y;
    switch (p.anim) {
      case 'idle':
        i = (p.animT * 7).floor() % 6;
      case 'run':
        i = (p.animT * 13).floor() % 6;
      case 'jump':
        i = math.min(3, 1 + (p.animT * 12).floor());
      case 'fall':
        i = (p.animT * 10).floor() % 6;
      case 'dash':
        sheet = 'ARCHER_B';
        i = math.min(5, ((1 - p.dashT / 0.22) * 6).floor());
      case 'climb':
        sheet = 'ARCHER_B';
        i = (p.climbT * 9).floor() % 6;
      case 'aim':
        sheet = 'ARCHER_B';
        i = math.min(3, ((p.aimT / 0.55) * 4).floor());
      case 'release':
        sheet = 'ARCHER_B';
        anim = 'aim';
        i = p.releaseT > 0.08 ? 4 : 5;
      case 'hurt':
        sheet = 'ARCHER_B';
        i = math.min(5, (p.animT * 16).floor());
      case 'ledge_climb':
        if (p.ledge == null) {
          anim = 'idle';
        } else {
          sheet = 'ARCHER_C';
          final pos = ledgeDrawPos(p);
          px = pos.x;
          py = pos.y;
          i = math.min(5, ((p.ledge!.t / 0.42) * 6).floor());
        }
      case 'wall_slide':
        sheet = 'ARCHER_C';
        i = (p.animT * 10).floor() % 6;
      case 'land':
        sheet = 'ARCHER_C';
        i = math.min(2, ((1 - p.landT / 0.16) * 3).floor());
      case 'defeat':
        sheet = 'ARCHER_C';
        i = math.min(5, (p.deadT * 5).floor());
      default:
        anim = 'idle';
    }
    if (p.mode == 'lift' && g.lift?.ride != null) {
      final t = g.lift!.ride!.t;
      py -= (t < 0.55 ? t : 1.1 - t) * 1.2;
    }
    final skin = skins[g.progress.skin.clamp(0, skins.length - 1)];
    final skinSheet = {'ARCHER_A': skin.sheets[0], 'ARCHER_B': skin.sheets[1], 'ARCHER_C': skin.sheets[2]}[sheet];
    if (skinSheet != null && _sheet(skinSheet)?.anims[anim] != null) sheet = skinSheet;
    final f = _sheet(sheet)?.frameOf(anim, i);
    if (g.cloneT > 0) _drawAnchored(sheet, f, _sx(px), _sy(py - 1.6), _archerK * s, flip: p.face < 0, alpha: 0.4);
    if (g.progress.feather) _glow(_sx(px), _sy(py - 0.8), 1.2 * s, _rgba(255, 215, 90, 1), 0.35);
    _drawAnchored(sheet, f, _sx(px), _sy(py) + 0.04 * s, _archerK * s, flip: p.face < 0);
  }

  void _drawBolt(double x0, double y0, double x1, double y1, double s, double a) {
    if (a <= 0) return;
    const segs = 9;
    for (var pass = 0; pass < 2; pass++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.plus
        ..color = pass == 0 ? _rgba(255, 230, 120, 0.5 * a) : _rgba(255, 255, 255, a)
        ..strokeWidth = math.max(1.5, s * (pass == 0 ? 0.22 : 0.08));
      final path = Path()..moveTo(x0, y0);
      for (var i = 1; i < segs; i++) {
        final t = i / segs;
        final jit = math.sin(i * 12.7 + x0 * 0.13 + y1) * s * 0.35;
        path.lineTo(x0 + (x1 - x0) * t + jit, y0 + (y1 - y0) * t);
      }
      path.lineTo(x1, y1);
      _c.drawPath(path, paint);
    }
  }

  void _drawTarget(double x, double y, double s, double k) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, s * 0.07)
      ..color = _rgba(255, 140, 60, 0.4 + k * 0.5);
    _c.drawOval(Rect.fromCenter(center: Offset(x, y - 0.05 * s), width: 2 * s * (0.9 - k * 0.35), height: 2 * s * 0.22), paint);
  }

  void _drawPrompt(double x, double y, String dir) {
    final s = _s;
    _fill.color = const Color(0xBF0A1814);
    _c.drawCircle(Offset(x, y), s * 0.42, _fill);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(2, s * 0.08)
      ..color = const Color(0xFFBFFFE9);
    final d = dir == 'up' ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(x - s * 0.18, y - d * s * 0.06 * -1 + d * s * 0.08)
      ..lineTo(x, y - d * s * 0.12)
      ..lineTo(x + s * 0.18, y + d * s * 0.08);
    _c.drawPath(path, paint);
  }

  void _drawHitboxes(GameState g) {
    final s = _s;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final p = g.player;
    paint.color = const Color(0xFFFFFF33);
    _c.drawRect(Rect.fromLTWH(_sx(p.x - p.w / 2), _sy(p.y - p.h), p.w * s, p.h * s), paint);
    paint.color = const Color(0xFFFF5555);
    for (final e in g.enemies) {
      _c.drawRect(Rect.fromLTWH(_sx(e.x - e.w / 2), _sy(e.y - e.h), e.w * s, e.h * s), paint);
    }
    paint.color = const Color(0xFF55FFFF);
    for (final pl in g.platforms) {
      _c.drawRect(Rect.fromLTWH(_sx(pl.x0), _sy(pl.top), (pl.x1 - pl.x0) * s, 2), paint);
    }
  }
}
