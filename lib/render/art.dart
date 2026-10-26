// Loads sprite sheets, their frame sidecars and single images from the bundled
// assets. Core art loads at start; each area's backdrop/monsters/boss and each
// skin's sheets load on demand. Port of game js/game/loader.js.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../engine/content.dart';

class FrameBox {
  const FrameBox(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
  factory FrameBox.from(Map<String, dynamic> j) => FrameBox(
        (j['x'] as num).toDouble(),
        (j['y'] as num).toDouble(),
        (j['w'] as num).toDouble(),
        (j['h'] as num).toDouble(),
      );
}

class SpriteFrame {
  SpriteFrame({required this.name, required this.source, FrameBox? content, this.anchorX, this.anchorY, this.surfaceY})
      : content = content ?? source;
  final String name;
  final FrameBox source;

  /// Opaque pixel bounds inside the sheet (falls back to the whole cell).
  final FrameBox content;
  final double? anchorX, anchorY;
  final double? surfaceY;

  double get ax => anchorX ?? content.x + content.w / 2;
  double get ay => anchorY ?? content.y + content.h;

  factory SpriteFrame.from(Map<String, dynamic> j) {
    final a = j['anchor'] as Map<String, dynamic>?;
    return SpriteFrame(
      name: j['name'] as String,
      source: FrameBox.from(j['source'] as Map<String, dynamic>),
      content: j['content'] == null ? null : FrameBox.from(j['content'] as Map<String, dynamic>),
      anchorX: (a?['x'] as num?)?.toDouble(),
      anchorY: (a?['y'] as num?)?.toDouble(),
      surfaceY: (j['surfaceY'] as num?)?.toDouble(),
    );
  }
}

class Sheet {
  Sheet(this.img, this.frames, this.anims);
  final ui.Image img;
  final Map<String, SpriteFrame> frames;
  final Map<String, List<SpriteFrame>> anims;

  /// Frame [i] of animation [anim], clamped to the animation's length. Null if the anim is missing.
  SpriteFrame? frameOf(String anim, int i) {
    final list = anims[anim];
    if (list == null || list.isEmpty) return null;
    return list[i.clamp(0, list.length - 1)];
  }
}

const _coreSheets = [
  'ARCHER_A', 'ARCHER_B', 'ARCHER_C', 'ENEMIES_A', 'ENEMIES_B', 'BOSS_STAG', 'EFFECTS', 'WORLD_ANIM',
  'SHRINES', 'PROPS', 'BRANCH_TILES', 'VINE_TILES', 'AREA_PROPS', 'AREA_SHOTS', 'SKIN_ICONS',
];
const _coreSingles = ['BACKDROP', 'TREEHOUSE'];

class ArtLibrary {
  final Map<String, Sheet> sheets = {};
  final Map<String, ui.Image> singles = {};
  ui.Image? atlas;
  Map<String, String> _paths = {};
  final Map<String, Future<void>> _jobs = {};

  Future<ui.Image> _decode(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  String _path(String key) {
    final p = _paths[key];
    if (p == null) throw StateError('Aset tidak terdaftar: $key');
    // The manifest was written for a web root ("/images/x.webp"); Flutter bundles it as assets/images/x.webp.
    return 'assets${p.startsWith('/') ? p : '/$p'}';
  }

  Future<void> _loadSheet(String key) {
    return _jobs.putIfAbsent('sheet:$key', () async {
      try {
        final results = await Future.wait([
          _decode(_path(key)),
          rootBundle.loadString('assets/game/frames/$key.json'),
        ]);
        final img = results[0] as ui.Image;
        final json = jsonDecode(results[1] as String) as Map<String, dynamic>;
        final byName = <String, SpriteFrame>{};
        for (final f in json['frames'] as List) {
          final sf = SpriteFrame.from(f as Map<String, dynamic>);
          byName[sf.name] = sf;
        }
        final anims = <String, List<SpriteFrame>>{};
        final animList = json['animations'] as List?;
        if (animList != null) {
          for (final a in animList) {
            anims[a['name'] as String] = [for (final f in a['frames'] as List) SpriteFrame.from(f as Map<String, dynamic>)];
          }
        } else {
          // Sheets without an animation index group frames by their "name_N" suffix.
          final re = RegExp(r'^(.*)_(\d+)$');
          final tmp = <String, Map<int, SpriteFrame>>{};
          for (final f in byName.values) {
            final m = re.firstMatch(f.name);
            if (m == null) continue;
            (tmp[m.group(1)!] ??= {})[int.parse(m.group(2)!)] = f;
          }
          tmp.forEach((k, v) {
            final keys = v.keys.toList()..sort();
            anims[k] = [for (final i in keys) v[i]!];
          });
        }
        sheets[key] = Sheet(img, byName, anims);
      } catch (e) {
        _jobs.remove('sheet:$key');
        rethrow;
      }
    });
  }

  Future<void> _loadSingle(String key) {
    return _jobs.putIfAbsent('single:$key', () async {
      try {
        singles[key] = await _decode(_path(key));
      } catch (e) {
        _jobs.remove('single:$key');
        rethrow;
      }
    });
  }

  Future<void> loadCore() async {
    if (_paths.isEmpty) {
      final raw = jsonDecode(await rootBundle.loadString('assets/game/manifest.json')) as Map<String, dynamic>;
      _paths = raw.map((k, v) => MapEntry(k, v as String));
    }
    await Future.wait([
      ..._coreSheets.map(_loadSheet),
      ..._coreSingles.map(_loadSingle),
      () async {
        atlas ??= await _decode(_path('BARK_KIT'));
      }(),
    ]);
  }

  ({List<String> sheets, List<String> singles}) _areaKeys(int i) {
    final a = areas[i];
    final sh = <String>[];
    if (a.monster != null) sh.add(monsters[a.monster]!.sheet);
    if (bosses[i] != null) sh.add(bosses[i]!.sheet);
    return (sheets: sh, singles: [a.bg]);
  }

  Future<void> ensureArea(int i) {
    final k = _areaKeys(i);
    return Future.wait([...k.sheets.map(_loadSheet), ...k.singles.map(_loadSingle)]);
  }

  Future<void> ensureSkin(int i) => Future.wait(skins[i].sheets.map(_loadSheet));

  /// Frees sheets that neither the current area nor skin needs.
  void retain(int area, int skin) {
    final keys = _areaKeys(area);
    final keepSheets = {..._coreSheets, ...keys.sheets, ...skins[skin].sheets};
    final keepSingles = {..._coreSingles, ...keys.singles};
    for (final k in sheets.keys.where((k) => !keepSheets.contains(k)).toList()) {
      sheets.remove(k)?.img.dispose();
      _jobs.remove('sheet:$k');
    }
    for (final k in singles.keys.where((k) => !keepSingles.contains(k)).toList()) {
      singles.remove(k)?.dispose();
      _jobs.remove('single:$k');
    }
  }

  void dispose() {
    for (final s in sheets.values) {
      s.img.dispose();
    }
    for (final i in singles.values) {
      i.dispose();
    }
    atlas?.dispose();
    sheets.clear();
    singles.clear();
    atlas = null;
    _jobs.clear();
  }
}
