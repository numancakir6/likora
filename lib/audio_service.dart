import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SfxService {
  static const String _soundKey = 'settings_sound_on';

  static final AudioPlayer _waterPlayer = AudioPlayer(playerId: 'likora_water');
  static bool _waterActive = false;

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

  static Future<void> playClick({bool ignoreSetting = false}) =>
      _playOneShot('assets/sfx/click.mp3',
          volume: 0.72, ignoreSetting: ignoreSetting);

  static Future<void> playSmallSuccess() =>
      _playOneShot('assets/sfx/small.mp3', volume: 0.90);

  static Future<void> playLevelComplete() =>
      _playOneShot('assets/sfx/complete.mp3', volume: 0.95);

  static Future<void> startWater() async {
    if (_waterActive) return;
    if (!await _isSoundOn()) return;

    _waterActive = true;
    try {
      await _waterPlayer.stop();
      await _waterPlayer.setReleaseMode(ReleaseMode.loop);
      await _waterPlayer.setVolume(0.78);
      await _waterPlayer.play(AssetSource(_assetKey('assets/sfx/water.mp3')));
    } catch (_) {
      _waterActive = false;
    }
  }

  static Future<void> stopWater() async {
    if (!_waterActive) return;
    _waterActive = false;
    try {
      await _waterPlayer.stop();
    } catch (_) {}
  }

  static Future<void> dispose() async {
    _waterActive = false;
    try {
      await _waterPlayer.dispose();
    } catch (_) {}
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
