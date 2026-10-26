// The one object that holds everything a run needs.
import 'boss.dart';
import 'content.dart';
import 'entities.dart';
import 'save.dart';
import 'world.dart';

/// Tuning values (formerly tweaks.json), merged with the equipped skin each rebuild.
class Tune {
  Tune({
    required this.runSpeed,
    required this.jumpV,
    required this.gravity,
    required this.skin,
    this.focusSlow = 0.3,
    this.arrowSpeed = 24,
    this.footingMax = 3,
    this.energyRegen = 0.7,
    this.windStrength = 1,
    this.bossHp = 6,
    this.showHitboxes = false,
  });
  final double runSpeed, jumpV, gravity, focusSlow, arrowSpeed, energyRegen, windStrength;
  final int footingMax, bossHp;
  final bool showHitboxes;
  final Skin skin;
}

class GameState {
  GameState(this.world) {
    progress = Progress();
    areaProg = progress.areas[0];
    player = Player(0, 0, 3, 3);
    cam = Cam(0, 0);
    tune = Tune(runSpeed: 7.5, jumpV: 0, gravity: 1, skin: skins[0]);
  }

  final World world;
  double t = 0;
  String phase = 'loading';
  late Progress progress;
  int areaIndex = 0;
  late AreaProgress areaProg;
  late Tune tune;
  int uid = 1000;

  final List<GameEvent> events = [];
  List<Arrow> arrows = [];
  List<Footing> footings = [];
  List<EProj> eproj = [];
  List<Fx> fx = [];
  List<Particle> particles = [];
  List<Warning> warnings = [];
  List<Beam> beams = [];
  List<Bolt> bolts = [];
  List<Platform> platforms = [];
  List<AimTarget> aimTargets = [];

  double slow = 1, shake = 0;
  Toast? toast;
  Speech? speech;
  double bellRing = 0, bridgeT = 0, emberT = 0;
  bool emberOn = false;
  double cloneT = 0, skillCd = 0;
  bool nearShrine = false;
  int maxHp = 3, maxEnergy = 3;
  /// Empty until the first build: Footing Arrows default on once unlocked.
  String arrowType = '';

  /// Movement intent copied from the input each tick.
  double inMx = 0, inMy = 0;
  bool inUpPressed = false;

  List<Enemy> enemies = [];
  BossBase? boss;
  List<Leaf> leaves = [];
  List<Crumble> crumbles = [];
  List<BridgeRun> bridge = [];
  List<Mover> movers = [];
  List<Flower> flowers = [];
  List<Wind> winds = [];
  List<Stalactite> stalactites = [];
  List<Checkpoint> checkpoints = [];
  List<Pickup> pickups = [];
  List<Crack> cracks = [];
  Lift? lift;
  ({int x, int y})? rope;
  Bell? bell;
  Gate? gate;
  List<Villager> villagers = [];
  List<Decor> decor = [];

  late Player player;
  late Cam cam;
  bool gateHold = false;
  bool pendingAnnounce = false;
  String? loadingError;

  int get rows => world.rows;
}
