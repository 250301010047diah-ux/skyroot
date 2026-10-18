import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Plays background music on a dedicated looping player and one-shot SFX on
/// independent players so the music never stops when an effect fires.
class AudioEngine {
  static const _prefix = 'game/audio/';

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final bool _enabledInitially;
  bool _enabled;
  bool _bgmStarted = false;
  int _stage = 0;
  String? _playingBgm;
  bool _endPlayed = false;

  double sfxVolume = 0.25;
  double bgmVolume = 0.35;

  AudioEngine({bool enabled = true})
    : _enabled = enabled,
      _enabledInitially = enabled;

  AudioContext _mixContext() => AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const <AVAudioSessionOptions>{
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
  );

  void unlock() {
    _enabled = _enabledInitially;
    if (!_bgmStarted) unawaited(_startBgm());
  }

  void setStage(int stage) {
    _stage = stage;
    if (_bgmStarted) unawaited(_startBgm());
  }

  void setEnabled(bool value) {
    _enabled = value;
    if (_enabled) {
      unawaited(_startBgm());
    } else {
      unawaited(_bgmPlayer.stop());
    }
  }

  Future<void> _startBgm() async {
    if (!_enabled) return;
    final track = 'bgm${(_stage ~/ 2) + 1}.mp3';
    if (_playingBgm == track) return;
    _bgmStarted = true;
    try {
      await _bgmPlayer.setAudioContext(_mixContext());
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(bgmVolume);
      await _bgmPlayer.play(AssetSource('$_prefix$track'));
      _playingBgm = track;
    } catch (_) {
      _bgmStarted = false;
    }
  }

  Future<void> _play(String filename, {double volumeScale = 1}) async {
    if (!_enabled) return;
    final player = AudioPlayer();
    try {
      await player.setAudioContext(_mixContext());
      await player.setVolume((sfxVolume * volumeScale).clamp(0, 1).toDouble());
      player.onPlayerComplete.listen((_) {
        unawaited(player.dispose());
      });
      await player.play(AssetSource('$_prefix$filename'));
    } catch (_) {
      await player.dispose();
    }
  }

  void jump() => unawaited(_play('jump.mp3'));
  void shoot() => unawaited(_play('shoot.mp3'));
  void hurt() => unawaited(_play('hurt.mp3'));
  void pickup() => unawaited(_play('pickup.mp3'));
  void win() {
    if (_endPlayed) return;
    _endPlayed = true;
    unawaited(_play('win.mp3', volumeScale: 1.2));
    unawaited(_play('relic.mp3'));
    unawaited(_play('sprout.mp3'));
  }

  void gameOver() {
    if (_endPlayed) return;
    _endPlayed = true;
    unawaited(_play('defeat.mp3'));
  }

  // --- SFX pemicu gameplay lainnya ---
  void bell() => unawaited(_play('bell.mp3'));
  void block() => unawaited(_play('block.mp3'));
  void checkpoint() => unawaited(_play('checkpoint.mp3'));
  void crack() => unawaited(_play('crack.mp3'));
  void crumble() => unawaited(_play('crumble.mp3'));
  void dash() => unawaited(_play('dash.mp3'));
  void footfail() => unawaited(_play('footfail.mp3'));
  void land() => unawaited(_play('land.mp3'));
  void launch() => unawaited(_play('launch.mp3'));
  void leaf() => unawaited(_play('leaf.mp3'));
  void lift() => unawaited(_play('lift.mp3'));
  void lob() => unawaited(_play('lob.mp3'));
  void nodeBreak() => unawaited(_play('nodeBreak.mp3'));
  void relic() => unawaited(_play('relic.mp3'));
  void noenergy() => unawaited(_play('noenergy.mp3'));
  void rope() => unawaited(_play('rope.mp3'));
  void spit() => unawaited(_play('spit.mp3'));
  void splat() => unawaited(_play('splat.mp3'));
  void stomp() => unawaited(_play('stomp.mp3'));
  void thunk() => unawaited(_play('thunk.mp3'));

  void resetEnd() {
    _endPlayed = false;
    unawaited(_startBgm());
  }

  Future<void> dispose() async {
    await _bgmPlayer.dispose();
  }
}
