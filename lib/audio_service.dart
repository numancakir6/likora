import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SfxService {
  static const String _soundKey = 'settings_sound_on';

  static int _waterSeq = 0;
  static final Map<int, AudioPlayer> _waterPlayers = {};

  static AudioPlayer? _mapCompletionActionPlayer;
  static AudioPlayer? _mapCompletionLoopPlayer;
  static int? _mapCompletionLoopMapNumber;

  static Future<bool> _isSoundOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? true;
  }

  static String _assetKey(String fullPath) => fullPath.startsWith('assets/')
      ? fullPath.substring('assets/'.length)
      : fullPath;

  static Future<void> _playOneShot(
    String assetPath, {
    double volume = 1.0,
    bool ignoreSetting = false,
  }) async {
    if (!ignoreSetting && !await _isSoundOn()) return;

    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.release);
      unawaited(
        player.onPlayerComplete.first
            .then((_) => player.dispose())
            .catchError((_) async {
          await player.dispose();
        }),
      );
      await player.play(AssetSource(_assetKey(assetPath)), volume: volume);
    } catch (_) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  static Future<void> playClick({bool ignoreSetting = false}) => _playOneShot(
        'assets/sfx/click.mp3',
        volume: 0.72,
        ignoreSetting: ignoreSetting,
      );

  static Future<void> playSmallSuccess() =>
      _playOneShot('assets/sfx/small.mp3', volume: 0.90);

  static Future<void> playLevelComplete() =>
      _playOneShot('assets/sfx/complete.mp3', volume: 0.95);

  /// Her akış için ayrı water player açar.
  /// Dönen token o akışın kimliğidir.
  static Future<int?> startWater() async {
    if (!await _isSoundOn()) return null;

    final token = ++_waterSeq;
    final player = AudioPlayer(playerId: 'likora_water_$token');
    _waterPlayers[token] = player;

    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.92);
      await player.play(AssetSource(_assetKey('assets/sfx/water.mp3')));
      return token;
    } catch (_) {
      _waterPlayers.remove(token);
      try {
        await player.dispose();
      } catch (_) {}
      return null;
    }
  }

  /// Sadece ilgili akışın sesini kapatır.
  static Future<void> stopWater([int? token]) async {
    if (token == null) return;

    final player = _waterPlayers.remove(token);
    if (player == null) return;

    try {
      await player.stop();
    } catch (_) {}

    try {
      await player.dispose();
    } catch (_) {}
  }

  /// Sayfadan çıkarken bütün kalan water seslerini temizler.
  static Future<void> stopAllWater() async {
    final players = _waterPlayers.values.toList(growable: false);
    _waterPlayers.clear();

    for (final player in players) {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  static String _mapCompletionActionAsset(int mapNumber) {
    switch (mapNumber) {
      case 1:
        return 'assets/sfx/map1_completion_action.mp3';
      case 2:
        return 'assets/sfx/map2_completion_action.mp3';
      case 3:
        return 'assets/sfx/map3_completion_action.mp3';
      default:
        return 'assets/sfx/map1_completion_action.mp3';
    }
  }

  static String _mapCompletionLoopAsset(int mapNumber) {
    switch (mapNumber) {
      case 1:
        return 'assets/sfx/map1_completion_loop.mp3';
      case 2:
        return 'assets/sfx/map2_completion_loop.mp3';
      case 3:
        return 'assets/sfx/map3_completion_loop.mp3';
      default:
        return 'assets/sfx/map1_completion_loop.mp3';
    }
  }

  static Future<void> startMapCompletionAction(int mapNumber) async {
    if (!await _isSoundOn()) return;

    final player = AudioPlayer(playerId: 'likora_map_completion_action');

    final oldPlayer = _mapCompletionActionPlayer;
    _mapCompletionActionPlayer = player;

    try {
      await oldPlayer?.stop();
      await oldPlayer?.dispose();
    } catch (_) {}

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.92);
      await player
          .play(AssetSource(_assetKey(_mapCompletionActionAsset(mapNumber))));
    } catch (_) {
      if (_mapCompletionActionPlayer == player) {
        _mapCompletionActionPlayer = null;
      }
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  static Future<void> fadeOutMapCompletionAction({
    Duration duration = const Duration(milliseconds: 700),
  }) async {
    final player = _mapCompletionActionPlayer;
    if (player == null) return;

    _mapCompletionActionPlayer = null;
    await _fadeOutAndDispose(player, duration: duration, fromVolume: 0.92);
  }

  static Future<void> startMapCompletionLoop(
    int mapNumber, {
    double volume = 0.46,
    Duration fadeIn = const Duration(milliseconds: 700),
  }) async {
    if (!await _isSoundOn()) return;

    if (_mapCompletionLoopPlayer != null &&
        _mapCompletionLoopMapNumber == mapNumber) {
      return;
    }

    await stopMapCompletionLoop(duration: const Duration(milliseconds: 250));

    final player = AudioPlayer(playerId: 'likora_map_completion_loop');
    _mapCompletionLoopPlayer = player;
    _mapCompletionLoopMapNumber = mapNumber;

    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.0);
      await player
          .play(AssetSource(_assetKey(_mapCompletionLoopAsset(mapNumber))));
      await _fadeVolume(player, from: 0.0, to: volume, duration: fadeIn);
    } catch (_) {
      if (_mapCompletionLoopPlayer == player) {
        _mapCompletionLoopPlayer = null;
        _mapCompletionLoopMapNumber = null;
      }
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  static Future<void> stopMapCompletionLoop({
    Duration duration = const Duration(milliseconds: 600),
  }) async {
    final player = _mapCompletionLoopPlayer;
    if (player == null) return;

    _mapCompletionLoopPlayer = null;
    _mapCompletionLoopMapNumber = null;
    await _fadeOutAndDispose(player, duration: duration, fromVolume: 0.46);
  }

  static Future<void> stopAllMapCompletionSounds() async {
    final actionPlayer = _mapCompletionActionPlayer;
    final loopPlayer = _mapCompletionLoopPlayer;

    _mapCompletionActionPlayer = null;
    _mapCompletionLoopPlayer = null;
    _mapCompletionLoopMapNumber = null;

    for (final player in [actionPlayer, loopPlayer]) {
      if (player == null) continue;
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  static Future<void> _fadeOutAndDispose(
    AudioPlayer player, {
    required Duration duration,
    required double fromVolume,
  }) async {
    await _fadeVolume(player, from: fromVolume, to: 0.0, duration: duration);
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  static Future<void> _fadeVolume(
    AudioPlayer player, {
    required double? from,
    required double to,
    required Duration duration,
  }) async {
    const steps = 12;
    final start = from ?? 1.0;
    final stepMs = max(16, duration.inMilliseconds ~/ steps);

    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final volume = start + (to - start) * t;
      try {
        await player.setVolume(volume.clamp(0.0, 1.0));
      } catch (_) {
        return;
      }
      await Future.delayed(Duration(milliseconds: stepMs));
    }
  }

  static Future<void> dispose() async {
    await stopAllWater();
    await stopAllMapCompletionSounds();
  }
}

class MusicService {
  static const String _musicKey = 'settings_music_on';
  static final Random _random = Random();
  static final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'likora_music');

  static const List<String> _playlist = [
    'assets/sfx/music_1.mp3',
    'assets/sfx/music_2.mp3',
    'assets/sfx/music_3.mp3',
    'assets/sfx/music_4.mp3',
    'assets/sfx/music_5.mp3',
    'assets/sfx/music_6.mp3',
    'assets/sfx/music_7.mp3',
  ];

  static StreamSubscription<void>? _completeSub;
  static bool _initialized = false;
  static bool _starting = false;
  static bool _playing = false;
  static int _currentIndex = -1;

  static String _assetKey(String fullPath) => fullPath.startsWith('assets/')
      ? fullPath.substring('assets/'.length)
      : fullPath;

  static Future<bool> _isMusicOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_musicKey) ?? true;
  }

  static Future<void> _ensureConfigured() async {
    if (_initialized) return;
    _initialized = true;

    await _musicPlayer.setReleaseMode(ReleaseMode.stop);
    await _musicPlayer.setVolume(0.22);

    _completeSub = _musicPlayer.onPlayerComplete.listen((_) {
      unawaited(_playNextTrack());
    });
  }

  static int _pickNextIndex() {
    if (_playlist.length <= 1) return 0;
    int next = _random.nextInt(_playlist.length);
    while (next == _currentIndex) {
      next = _random.nextInt(_playlist.length);
    }
    return next;
  }

  static Future<void> ensureStarted() async {
    if (_starting || _playing) return;
    if (!await _isMusicOn()) {
      await stop();
      return;
    }

    _starting = true;
    try {
      await _ensureConfigured();
      if (_playing) return;
      await _playNextTrack();
    } finally {
      _starting = false;
    }
  }

  static Future<void> _playNextTrack() async {
    if (!await _isMusicOn()) {
      await stop();
      return;
    }

    await _ensureConfigured();

    final nextIndex = _pickNextIndex();
    _currentIndex = nextIndex;
    _playing = true;

    try {
      await _musicPlayer.stop();
      await _musicPlayer.play(AssetSource(_assetKey(_playlist[nextIndex])));
    } catch (_) {
      _playing = false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    if (value) {
      await ensureStarted();
    } else {
      await stop();
    }
  }

  static Future<void> stop() async {
    _playing = false;
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  static Future<void> dispose() async {
    _playing = false;
    await _completeSub?.cancel();
    _completeSub = null;
    try {
      await _musicPlayer.dispose();
    } catch (_) {}
  }
}
