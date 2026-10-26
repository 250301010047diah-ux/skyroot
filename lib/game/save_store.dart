// Persists the run's Progress as one JSON string in SharedPreferences.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/save.dart';

class SaveStore {
  static const key = 'skyroot.v2';

  /// Returns null when nothing has been saved yet.
  static Future<Progress?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return Progress.sanitize(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Progress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(progress.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
