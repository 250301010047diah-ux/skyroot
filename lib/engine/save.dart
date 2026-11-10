// Progress kept between sessions (small, versioned JSON).
import 'dart:math' as math;

const areaCount = 11;
const exploreBlock = 4;
const _area0Secrets = ['E@36,97', 'R@15,61', 'Y@37,16'];
const _areaSecrets = ['E@19,33', 'R@20,42'];

List<String> secretIdsFor(int area) => area == 0 ? _area0Secrets : _areaSecrets;

final int totalSecrets = _area0Secrets.length + _areaSecrets.length * (areaCount - 1);

class AreaProgress {
  AreaProgress({
    this.cp,
    this.boss = false,
    List<String>? got,
    List<String>? broken,
    this.explored = '',
  })  : got = got ?? [],
        broken = broken ?? [];

  String? cp;
  bool boss;
  List<String> got;
  List<String> broken;
  String explored;

  factory AreaProgress.clean(Object? raw) {
    if (raw is! Map) return AreaProgress();
    List<String> strs(Object? a, int n) =>
        a is List ? a.whereType<String>().take(n).toList() : <String>[];
    final ex = raw['explored'];
    return AreaProgress(
      cp: raw['cp'] is String ? raw['cp'] as String : null,
      boss: raw['boss'] == true,
      got: strs(raw['got'], 64),
      broken: strs(raw['broken'], 16),
      explored: ex is String ? (ex.length > 400 ? ex.substring(0, 400) : ex) : '',
    );
  }

  Map<String, Object?> toJson() => {
        'cp': cp,
        'boss': boss,
        'got': got,
        'broken': broken,
        'explored': explored,
      };
}

class Progress {
  Progress({
    this.area = 0,
    this.unlocked = 0,
    this.rich = false,
    this.skin = 0,
    this.footing = false,
    this.dash = false,
    this.maxHp = 3,
    this.maxEnergy = 3,
    this.rope = false,
    this.lift = false,
    this.bell = false,
    this.feather = false,
    this.time = 0,
    this.deaths = 0,
    List<AreaProgress>? areas,
  }) : areas = areas ?? List.generate(areaCount, (_) => AreaProgress());

  int area, unlocked, skin, maxHp, maxEnergy, deaths;
  bool footing, dash, rope, lift, bell, feather;
  /// Set by the main-menu "999+" button: endless coins and everything open.
  bool rich;
  double time;
  final List<AreaProgress> areas;

  static int _clampInt(Object? v, int lo, int hi, int def) {
    if (v is! num || !v.isFinite) return def;
    return math.max(lo, math.min(hi, v.round()));
  }

  /// Parses and validates a saved map; anything malformed falls back to defaults.
  factory Progress.sanitize(Object? raw) {
    if (raw is! Map) return Progress();
    var m = Map<String, Object?>.from(raw);
    if (m['v'] == 1) {
      // Migrate the single-area save into area 0.
      m = {
        ...m,
        'v': 2,
        'area': 0,
        'unlocked': m['bell'] == true ? 1 : 0,
        'skin': 0,
        'areas': [
          {'cp': m['cp'], 'boss': m['boss'], 'got': m['got'], 'broken': m['broken'], 'explored': m['explored']},
        ],
      };
    }
    if (m['v'] != 2) return Progress();
    final rawAreas = m['areas'];
    final abil = m['abilities'];
    final rich = m['rich'] == true;
    final unlocked = rich ? areaCount - 1 : _clampInt(m['unlocked'], 0, areaCount - 1, 0);
    final skin = _clampInt(m['skin'], 0, areaCount - 1, 0);
    return Progress(
      area: math.min(_clampInt(m['area'], 0, areaCount - 1, 0), unlocked),
      unlocked: unlocked,
      rich: rich,
      skin: skin <= unlocked ? skin : 0,
      footing: abil is Map && abil['footing'] == true,
      dash: abil is Map && abil['dash'] == true,
      maxHp: _clampInt(m['maxHp'], 3, 14, 3),
      maxEnergy: _clampInt(m['maxEnergy'], 3, 13, 3),
      rope: m['rope'] == true,
      lift: m['lift'] == true,
      bell: m['bell'] == true,
      feather: m['feather'] == true,
      time: m['time'] is num && (m['time'] as num).isFinite ? math.max(0, (m['time'] as num).toDouble()) : 0,
      deaths: _clampInt(m['deaths'], 0, 99999, 0),
      areas: List.generate(
        areaCount,
        (i) => AreaProgress.clean(rawAreas is List && i < rawAreas.length ? rawAreas[i] : null),
      ),
    );
  }

  Map<String, Object?> toJson() => {
        'v': 2,
        'area': area,
        'unlocked': unlocked,
        'rich': rich,
        'skin': skin,
        'abilities': {'footing': footing, 'dash': dash},
        'maxHp': maxHp,
        'maxEnergy': maxEnergy,
        'rope': rope,
        'lift': lift,
        'bell': bell,
        'feather': feather,
        'time': time,
        'deaths': deaths,
        'areas': areas.map((a) => a.toJson()).toList(),
      };

  int get secretsFound {
    var n = 0;
    for (var i = 0; i < areas.length; i++) {
      for (final id in secretIdsFor(i)) {
        if (areas[i].got.contains(id)) n++;
      }
    }
    return n;
  }

  /// Skin i opens together with area i (or everything once [rich]).
  bool skinOwned(int skin) => skin >= 0 && skin < areaCount && (rich || skin <= unlocked);
  int get skinsOwned => rich ? areaCount : unlocked + 1;

  void unlockAll() {
    rich = true;
    unlocked = areaCount - 1;
  }
}
