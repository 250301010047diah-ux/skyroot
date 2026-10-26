import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Mirrors the SDK asset manifest used by `game js/assets.json`.
/// Maps a logical asset key (e.g. "ARCHER_A") to its local bundled
/// path under `assets/` (e.g. "images/archer_a-transparent.webp").
class AssetManifest {
  const AssetManifest(this.paths);

  final Map<String, String> paths;

  static Future<AssetManifest> load() async {
    final raw = await rootBundle.loadString('assets/json/assets.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return AssetManifest(
      decoded.map((key, value) => MapEntry(key, value as String)),
    );
  }

  /// Local asset path for [key], falling back to a direct images lookup.
  String pathFor(String key) {
    final path = paths[key] ?? key;
    // Flame's Images loader already prefixes `assets/images/`.
    return path.startsWith('images/') ? path.substring('images/'.length) : path;
  }

  List<String> get keys => paths.keys.toList();
}
