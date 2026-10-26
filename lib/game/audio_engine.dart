import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// App-wide audio: looping background music (from the main menu onward) plus a
/// small round-robin pool for one-shot effects, so the music never stops when
/// an effect fires.
class AudioEngine {
  AudioEngine._();

  /// One engine for the whole app, so the music keeps playing from menu to game.
  static final AudioEngine instance = AudioEngine._();

  static const _prefix = 'game/audio/';
  static const _poolSize = 8;

  /// Every effect the engine can ask for; each maps to `assets/game/audio/NAME.mp3`.
  static const sfxNames = {
    'relic', 'jump', 'land', 'dash', 'hurt', 'shoot', 'thunk', 'sprout', 'footfail', 'noenergy', 'crack', 'crumble',
    'leaf', 'launch', 'spit', 'lob', 'splat', 'defeat', 'block', 'checkpoint', 'lift', 'rope', 'stomp', 'nodeBreak',
    'bell', 'pickup', 'win',
  };

  final AudioPlayer _bgm = AudioPlayer();
  final List<AudioPlayer> _pool = [];
  final Map<String, int> _lastPlayed = {};
  final Stopwatch _clock = Stopwatch()..start();
  int _next = 0;
  bool _muted = false;
  bool _suspended = false;
  bool _started = false;
  int _area = 0;

  /// Track currently loaded in the music player and whether it is playing.
  String? _loaded;
  bool _playing = false;

  /// Music commands run one after another, so start/pause/resume never race.
  Future<void> _queue = Future.value();

  double sfxVolume = 0.6;
  double bgmVolume = 0.35;

  AudioContext _mixContext() => AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const <AVAudioSessionOptions>{AVAudioSessionOptions.mixWithOthers},
        ),
      );

  bool get muted => _muted;

  /// Starts the music; safe to call repeatedly (main menu and game both do).
  void start() {
    _started = true;
    _apply();
  }

  /// Five tracks cover the eleven areas; the menu uses the first.
  void setArea(int area) {
    _area = area;
    _apply();
  }

  void setMuted(bool value) {
    _muted = value;
    _apply();
  }

  /// The app went to the background.
  void suspend() {
    _suspended = true;
    _apply();
  }

  void resume() {
    _suspended = false;
    _apply();
  }

  void _apply() {
    _queue = _queue.then((_) => _sync()).catchError((Object e) {
      debugPrint('[bgm] failed: $e');
      // Audio is best-effort; a failed command must not block the next one.
      _loaded = null;
      _playing = false;
    });
  }

  Future<void> _sync() async {
    final want = _started && !_muted && !_suspended;
    final track = 'bgm${math.min(5, (_area ~/ 2) + 1)}.mp3';
    if (!want) {
      if (_playing) {
        await _bgm.pause();
        _playing = false;
      }
      return;
    }
    if (_loaded != track) {
      // play() swaps the source itself; stop()/context juggling first left MediaPlayer idle.
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.play(AssetSource('$_prefix$track'), volume: bgmVolume);
      _loaded = track;
      _playing = true;
    } else if (!_playing) {
      await _bgm.resume();
      _playing = true;
    }
  }

  AudioPlayer _nextPlayer() {
    if (_pool.length < _poolSize) {
      final p = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      unawaited(p.setAudioContext(_mixContext()));
      _pool.add(p);
      return p;
    }
    final p = _pool[_next];
    _next = (_next + 1) % _poolSize;
    return p;
  }

  /// Plays effect [name]; [loud] raises the volume a little (hard landing, full draw).
  void play(String name, {bool loud = false}) {
    if (_muted || _suspended || !sfxNames.contains(name)) return;
    // The same effect firing every frame (burning, rain) would just be noise.
    final now = _clock.elapsedMilliseconds;
    if (now - (_lastPlayed[name] ?? -1000) < 45) return;
    _lastPlayed[name] = now;
    final volume = (sfxVolume * (loud ? 1.25 : 1)).clamp(0.0, 1.0);
    final player = _nextPlayer();
    unawaited(() async {
      try {
        await player.stop();
        await player.play(AssetSource('$_prefix$name.mp3'), volume: volume, mode: PlayerMode.lowLatency);
      } catch (_) {
        // Audio is best-effort; gameplay never waits for it.
      }
    }());
  }
}
