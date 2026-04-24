import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart';
import 'map_theme.dart';
import 'player_progress.dart';
import 'settings_page.dart';
import 'audio_service.dart';
import 'game/core/game_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_page_completion_scenes.dart';

// ─────────────────────────────────────────────
//  DIFFICULTY
// ─────────────────────────────────────────────

enum LevelDifficulty { easy, medium, hard, expert, legendary }

extension LevelDifficultyExt on LevelDifficulty {
  int get dotCount {
    switch (this) {
      case LevelDifficulty.easy:
        return 1;
      case LevelDifficulty.medium:
        return 2;
      case LevelDifficulty.hard:
        return 3;
      case LevelDifficulty.expert:
        return 4;
      case LevelDifficulty.legendary:
        return 5;
    }
  }
}

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

Color _adaptiveDifficultyRingColor({
  required Color themeColor,
  required Color topColor,
  required Color bottomColor,
  bool brighten = false,
}) {
  final bgColor = Color.lerp(topColor, bottomColor, 0.5) ?? topColor;
  final bgLum = bgColor.computeLuminance();
  final hsl = HSLColor.fromColor(themeColor);

  Color candidate = HSLColor.fromAHSL(
    1,
    hsl.hue,
    (hsl.saturation + 0.12).clamp(0.0, 1.0),
    bgLum > 0.42 ? 0.18 : 0.84,
  ).toColor();

  if (_contrastRatio(candidate, bgColor) < 2.4) {
    candidate = HSLColor.fromAHSL(
      1,
      (hsl.hue + 180) % 360,
      (hsl.saturation + 0.08).clamp(0.0, 1.0),
      bgLum > 0.42 ? 0.22 : 0.78,
    ).toColor();
  }

  if (brighten) {
    candidate = Color.lerp(candidate, Colors.white, 0.10) ?? candidate;
  }

  return candidate;
}

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────

class LevelNodeData {
  final int id;
  final bool isCompleted;
  final bool isUnlocked;
  final int starCount;
  final LevelDifficulty difficulty;

  const LevelNodeData({
    required this.id,
    required this.isCompleted,
    required this.isUnlocked,
    this.starCount = 0,
    required this.difficulty,
  });
}

LevelDifficulty _difficultyFor(int mapNumber, int levelId, int totalLevels) {
  final progress = totalLevels <= 1 ? 1.0 : (levelId - 1) / (totalLevels - 1);

  final int minScore;
  final int maxScore;

  if (mapNumber <= 2) {
    minScore = 1;
    maxScore = 3;
  } else if (mapNumber <= 4) {
    minScore = 1;
    maxScore = 3;
  } else if (mapNumber <= 6) {
    minScore = 1;
    maxScore = 4;
  } else if (mapNumber <= 9) {
    minScore = 2;
    maxScore = 4;
  } else if (mapNumber <= 12) {
    minScore = 2;
    maxScore = 5;
  } else {
    minScore = 3;
    maxScore = 5;
  }

  int score;
  if (mapNumber <= 2) {
    if (progress < 0.34) {
      score = 1;
    } else if (progress < 0.75) {
      score = 2;
    } else {
      score = 3;
    }
  } else if (mapNumber <= 4) {
    if (progress < 0.22) {
      score = 1;
    } else if (progress < 0.60) {
      score = 2;
    } else {
      score = 3;
    }
  } else if (mapNumber <= 6) {
    if (progress < 0.12) {
      score = 1;
    } else if (progress < 0.36) {
      score = 2;
    } else if (progress < 0.78) {
      score = 3;
    } else {
      score = 4;
    }
  } else if (mapNumber <= 9) {
    if (progress < 0.28) {
      score = 2;
    } else if (progress < 0.72) {
      score = 3;
    } else {
      score = 4;
    }
  } else if (mapNumber <= 12) {
    if (progress < 0.18) {
      score = 2;
    } else if (progress < 0.56) {
      score = 3;
    } else if (progress < 0.88) {
      score = 4;
    } else {
      score = 5;
    }
  } else {
    if (progress < 0.20) {
      score = 3;
    } else if (progress < 0.64) {
      score = 4;
    } else {
      score = 5;
    }
  }

  score = score.clamp(minScore, maxScore);

  switch (score) {
    case 1:
      return LevelDifficulty.easy;
    case 2:
      return LevelDifficulty.medium;
    case 3:
      return LevelDifficulty.hard;
    case 4:
      return LevelDifficulty.expert;
    case 5:
    default:
      return LevelDifficulty.legendary;
  }
}

// ═══════════════════════════════════════════════════════════════
//  MAP PAGE
// ═══════════════════════════════════════════════════════════════

class MapPage extends StatefulWidget {
  final int mapNumber;

  const MapPage({super.key, this.mapNumber = 0});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  static const int _maxMapCount = 15;
  static const int _playableMapCount = 3;
  static const double _swipeVelocityThreshold = 250;
  static const double _swipeDistanceThreshold = 24;
  static const double _nodeWidgetSize = 72;
  static const double _nodeHalfSize = _nodeWidgetSize / 2;
  static const double _nodeMinCenterDistance = 80;
  static const bool _showDebugButtons = false;

  static final Map<int, Set<int>> _mapCompletedLevels = {
    for (var i = 1; i <= _maxMapCount; i++) i: <int>{},
  };

  late final AnimationController _bgController;
  late final AnimationController _entryController;

  late final int _mapNumber;
  late final MapTheme _theme;
  late final MapLayoutData _layout;

  late Set<int> completedLevels;
  late Set<int> _unlocked;
  late List<LevelNodeData> _levels;

  bool _showFirstCompletionScene = false;
  bool _showPersistentCompletionScene = false;
  bool _completionSceneIntroSeen = false;
  double _firstSceneOpacity = 0.0;
  double _persistentSceneOpacity = 0.0;
  bool _showCompletionCongratsCard = false;

  @override
  void initState() {
    super.initState();
    _mapNumber =
        widget.mapNumber == 0 ? _latestPlayableMapNumber() : widget.mapNumber;
    _theme = getMapTheme(_mapNumber);
    _layout = getMapLayout(_mapNumber);
    completedLevels = Set<int>.from(
      _mapCompletedLevels[_mapNumber] ?? <int>{},
    );
    _rebuildLevels();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _loadProgress();
  }

  String get _completionSceneSeenPrefsKey =>
      'likora_map_completion_scene_seen_$_mapNumber';

  String get _mapRewardClaimedPrefsKey =>
      'likora_map_completion_reward_claimed_$_mapNumber';

  bool _isMapFullyCompleted(Set<int> levels) =>
      levels.length >= _layout.totalLevels;

  int get _mapCompletionReward => 200 + ((_mapNumber - 1) * 100);

  void _showPersistentCompletionOverlay({bool showCard = true}) {
    if (!mounted) return;
    setState(() {
      _showPersistentCompletionScene = true;
      _showFirstCompletionScene = false;
      _completionSceneIntroSeen = true;
      _firstSceneOpacity = 0.0;
      _persistentSceneOpacity = 1.0;
      _showCompletionCongratsCard = showCard;
    });
  }

  Future<bool> _claimMapCompletionRewardIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyClaimed = prefs.getBool(_mapRewardClaimedPrefsKey) ?? false;
    if (alreadyClaimed) return false;

    final currentCoins = PlayerProgress.coins.value;
    PlayerProgress.setCoins(currentCoins + _mapCompletionReward);
    await prefs.setBool(_mapRewardClaimedPrefsKey, true);
    return true;
  }

  Future<bool> _showMapCompletionRewardDialog() async {
    if (!mounted) return false;

    final shouldStartAnimation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: Color.lerp(_theme.bgMid, Colors.black, 0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _theme.primaryColor.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: _theme.primaryColor.withValues(alpha: 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tebrikler',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: _theme.primaryColor.withValues(alpha: 0.30),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '"${_theme.name}" u tamamladınız',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFE082).withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFF176), Color(0xFFFFB300)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFC107)
                                  .withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.toll_rounded,
                          color: Color(0xFF6A4300),
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+$_mapCompletionReward',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () async {
                    await SfxService.playClick();
                    await SettingsPage.vibrateTap();
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.04),
                      ]),
                      border: Border.all(
                        color: _theme.accentColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Tamamla',
                      style: TextStyle(
                        color: _theme.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return shouldStartAnimation ?? false;
  }

  Future<void> _loadProgress() async {
    await PlayerProgress.ensureLoaded();

    final savedCompleted = await PlayerProgress.getCompletedLevels(_mapNumber);
    _mapCompletedLevels[_mapNumber] = Set<int>.from(savedCompleted);
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_completionSceneSeenPrefsKey) ?? false;
    final fullyCompleted = _isMapFullyCompleted(savedCompleted);

    if (!mounted) return;

    setState(() {
      completedLevels = Set<int>.from(savedCompleted);
      _completionSceneIntroSeen = seen;

      // intro görülmeden direkt persistent sahne açılmasın
      _showPersistentCompletionScene = fullyCompleted && seen;
      _showFirstCompletionScene = false;
      _firstSceneOpacity = 0.0;
      _persistentSceneOpacity = (fullyCompleted && seen) ? 1.0 : 0.0;
      _showCompletionCongratsCard = fullyCompleted && seen;

      _rebuildLevels();
    });
  }

  Future<void> _saveProgress() async {
    _mapCompletedLevels[_mapNumber] = Set<int>.from(completedLevels);
    await PlayerProgress.setCompletedLevels(_mapNumber, completedLevels);
  }

  Future<void> _completeAllLevels() async {
    await SfxService.playClick();
    await SettingsPage.vibrateTap();

    for (var map = 1; map <= _playableMapCount; map++) {
      await PlayerProgress.unlockMap(map);
    }

    final allLevelIds =
        List.generate(_layout.totalLevels, (i) => i + 1).toSet();

    final wasMapAlreadyComplete = _isMapFullyCompleted(completedLevels);

    _mapCompletedLevels[_mapNumber] = Set<int>.from(allLevelIds);
    await PlayerProgress.setCompletedLevels(_mapNumber, allLevelIds);

    if (!mounted) return;
    setState(() {
      completedLevels = Set<int>.from(allLevelIds);
      _rebuildLevels();
    });

    if (!wasMapAlreadyComplete) {
      final rewarded = await _claimMapCompletionRewardIfNeeded();
      if (rewarded && mounted) {
        final startAnimation = await _showMapCompletionRewardDialog();
        if (startAnimation && mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_completionSceneSeenPrefsKey);
          await _animateCompletionSceneTransition(markSeen: true);
        }
        return;
      }
    }

    _showPersistentCompletionOverlay(showCard: true);
  }

  Duration _sceneRevealDurationForMap(int mapNumber) {
    switch (mapNumber) {
      case 1:
        return const Duration(milliseconds: 2800);
      case 2:
        return const Duration(milliseconds: 3200);
      case 3:
        return const Duration(milliseconds: 4200);
      default:
        return const Duration(milliseconds: 2800);
    }
  }

  Duration _sceneCrossfadeDurationForMap(int mapNumber) {
    switch (mapNumber) {
      case 1:
        return const Duration(milliseconds: 700);
      case 2:
        return const Duration(milliseconds: 850);
      case 3:
        return const Duration(milliseconds: 1200);
      default:
        return const Duration(milliseconds: 800);
    }
  }

  Future<void> _animateCompletionSceneTransition({
    required bool markSeen,
  }) async {
    final revealDuration = _sceneRevealDurationForMap(_mapNumber);
    final fadeDuration = _sceneCrossfadeDurationForMap(_mapNumber);
    final steadyDuration = revealDuration > fadeDuration
        ? revealDuration - fadeDuration
        : Duration.zero;

    if (!mounted) return;
    setState(() {
      _completionSceneIntroSeen = true;
      _showFirstCompletionScene = true;
      _showPersistentCompletionScene = false;
      _firstSceneOpacity = 1.0;
      _persistentSceneOpacity = 0.0;
      _showCompletionCongratsCard = false;
    });

    if (steadyDuration > Duration.zero) {
      await Future.delayed(steadyDuration);
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() {
      _showPersistentCompletionScene = true;
      _persistentSceneOpacity = 1.0;
      _firstSceneOpacity = 0.0;
      _showCompletionCongratsCard = true;
    });

    await Future.delayed(fadeDuration);
    if (!mounted) return;

    setState(() {
      _showFirstCompletionScene = false;
      _showPersistentCompletionScene = true;
      _firstSceneOpacity = 0.0;
      _persistentSceneOpacity = 1.0;
      _showCompletionCongratsCard = true;
    });

    if (markSeen) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completionSceneSeenPrefsKey, true);
    }
  }

  Future<void> _runCompletionSceneTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completionSceneSeenPrefsKey);
    await _animateCompletionSceneTransition(markSeen: true);
  }

  Future<void> _resetCompletionSceneTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completionSceneSeenPrefsKey);

    if (!mounted) return;
    setState(() {
      _completionSceneIntroSeen = false;
      _showFirstCompletionScene = false;
      _showPersistentCompletionScene = false;
      _firstSceneOpacity = 0.0;
      _persistentSceneOpacity = 0.0;
      _showCompletionCongratsCard = false;
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _rebuildLevels() {
    final isPlayable = _isMapPlayable(_mapNumber);
    _unlocked = _computeUnlocked(
      completed: completedLevels,
      connections: _layout.connections,
    );
    if (!isPlayable) {
      _unlocked = <int>{};
    }
    _levels = List.generate(_layout.totalLevels, (i) {
      final id = i + 1;
      return LevelNodeData(
        id: id,
        isCompleted: completedLevels.contains(id),
        isUnlocked: isPlayable && _unlocked.contains(id),
        starCount: completedLevels.contains(id) ? (1 + id % 3) : 0,
        difficulty: _difficultyFor(_mapNumber, id, _layout.totalLevels),
      );
    });
  }

  static Set<int> _computeUnlocked({
    required Set<int> completed,
    required List<MapConnection> connections,
  }) {
    final unlocked = <int>{1};
    final incomingMap = <int, List<int>>{};
    for (final c in connections) {
      incomingMap.putIfAbsent(c.to, () => []).add(c.from);
    }
    for (final entry in incomingMap.entries) {
      if (entry.value.every((p) => completed.contains(p))) {
        unlocked.add(entry.key);
      }
    }
    unlocked.addAll(completed);
    return unlocked;
  }

  static bool _isMapPlayableStatic(int mapNumber) {
    if (mapNumber > _playableMapCount) return false;
    if (mapNumber <= 1) return true;
    return mapNumber <= PlayerProgress.latestUnlockedMap;
  }

  static int _latestPlayableMapNumber() {
    var latest = 1;
    for (var map = 2; map <= _maxMapCount; map++) {
      if (_isMapPlayableStatic(map)) {
        latest = map;
      } else {
        break;
      }
    }
    return latest;
  }

  bool _isMapPlayable(int mapNumber) {
    if (mapNumber > _playableMapCount) return false;
    if (mapNumber <= 1) return true;
    return mapNumber <= PlayerProgress.latestUnlockedMap;
  }

  bool _isComingSoonMap(int mapNumber) => mapNumber > _playableMapCount;

  Map<int, Offset> _levelPositions(double w, double h) {
    final raw = <int, Offset>{
      for (final node in _layout.nodes) node.id: Offset(w * node.x, h * node.y),
    };

    final adjusted = <int, Offset>{
      for (final entry in raw.entries) entry.key: entry.value
    };

    final rows = <List<int>>[];
    final sortedNodes = _layout.nodes.toList()
      ..sort((a, b) => a.y.compareTo(b.y));
    for (final node in sortedNodes) {
      if (rows.isEmpty) {
        rows.add([node.id]);
        continue;
      }

      final currentRow = rows.last;
      final currentAverageY = currentRow
              .map((id) => _layout.nodes.firstWhere((n) => n.id == id).y)
              .reduce((a, b) => a + b) /
          currentRow.length;

      if ((node.y - currentAverageY).abs() <= 0.07) {
        currentRow.add(node.id);
      } else {
        rows.add([node.id]);
      }
    }

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex]
        ..sort((a, b) => adjusted[a]!.dx.compareTo(adjusted[b]!.dx));

      final horizontalStrength = min(16.0, w * 0.026);
      final verticalStrength = min(8.0, h * 0.013);
      final rowSign = rowIndex.isEven ? 1.0 : -1.0;

      for (var i = 0; i < row.length; i++) {
        final id = row[i];
        final p = adjusted[id]!;
        final normalized =
            row.length == 1 ? 0.0 : (i / (row.length - 1)) * 2 - 1;
        final horizontalOffset = normalized * horizontalStrength * 0.55 +
            rowSign * (i.isEven ? 1 : -1) * horizontalStrength * 0.22;
        final verticalOffset = ((i % 3) - 1) * verticalStrength * 0.65;
        adjusted[id] = Offset(p.dx + horizontalOffset, p.dy + verticalOffset);
      }
    }

    final minX = _nodeHalfSize + 10;
    final maxX = w - _nodeHalfSize - 10;
    final minY = _nodeHalfSize + 10;
    final maxY = h - _nodeHalfSize - 10;

    for (var iteration = 0; iteration < 10; iteration++) {
      for (var i = 0; i < _layout.nodes.length; i++) {
        for (var j = i + 1; j < _layout.nodes.length; j++) {
          final idA = _layout.nodes[i].id;
          final idB = _layout.nodes[j].id;
          final a = adjusted[idA]!;
          final b = adjusted[idB]!;
          final delta = b - a;
          final distance = delta.distance;

          if (distance == 0 || distance >= _nodeMinCenterDistance) continue;

          final push = (_nodeMinCenterDistance - distance) / 2;
          final direction = delta / distance;
          final shift = direction * push;

          adjusted[idA] = Offset(
            (a.dx - shift.dx).clamp(minX, maxX),
            (a.dy - shift.dy).clamp(minY, maxY),
          );
          adjusted[idB] = Offset(
            (b.dx + shift.dx).clamp(minX, maxX),
            (b.dy + shift.dy).clamp(minY, maxY),
          );
        }
      }
    }

    for (final entry in adjusted.entries.toList()) {
      adjusted[entry.key] = Offset(
        entry.value.dx.clamp(minX, maxX),
        entry.value.dy.clamp(minY, maxY),
      );
    }

    return adjusted;
  }

  Future<void> _navigateToLevel(int levelId) async {
    final levelData = _levels.firstWhere((e) => e.id == levelId);

    final result = await Navigator.push<GamePageResult>(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(
          level: levelId,
          mapNumber: _mapNumber,
          difficulty: levelData.difficulty.dotCount,
        ),
      ),
    );

    if (result?.completed == true && mounted) {
      final updatedCompleted = {...completedLevels, levelId};
      final wasMapAlreadyComplete = _isMapFullyCompleted(completedLevels);

      setState(() {
        completedLevels = updatedCompleted;
        _rebuildLevels();
      });

      await _saveProgress();

      final isMapFullyCompleted = _isMapFullyCompleted(updatedCompleted);
      if (isMapFullyCompleted) {
        if (!wasMapAlreadyComplete) {
          await _claimMapCompletionRewardIfNeeded();
          if (!mounted) return;
          final startAnimation = await _showMapCompletionRewardDialog();
          if (startAnimation && mounted) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_completionSceneSeenPrefsKey);
            await _animateCompletionSceneTransition(markSeen: true);
          }
          return;
        }
        await _handleMapCompletionSceneActivation();
      }
    }
  }

  Future<void> _handleMapCompletionSceneActivation() async {
    if (_showPersistentCompletionScene && _completionSceneIntroSeen) return;

    if (_mapNumber < _maxMapCount && _mapNumber < _playableMapCount) {
      await PlayerProgress.unlockMap(_mapNumber + 1);
    }

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_completionSceneSeenPrefsKey) ?? false;

    if (!mounted) return;

    if (seen) {
      _showPersistentCompletionOverlay(showCard: true);
      return;
    }

    await _animateCompletionSceneTransition(markSeen: true);
  }

  Duration sceneRevealDurationForMap(int mapNumber) {
    switch (mapNumber) {
      case 1:
        return const Duration(milliseconds: 2800);
      case 2:
        return const Duration(milliseconds: 3000);
      case 3:
        return const Duration(milliseconds: 3200);
      default:
        return const Duration(milliseconds: 2500);
    }
  }

  void _switchToMap(int targetMapNumber) {
    if (targetMapNumber == _mapNumber) return;
    if (targetMapNumber < 1 || targetMapNumber > _maxMapCount) return;

    final movingForward = targetMapNumber > _mapNumber;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => MapPage(mapNumber: targetMapNumber),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final begin = Offset(movingForward ? 1.0 : -1.0, 0.0);
          final end = Offset.zero;
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(curve),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _goToPreviousMap() async {
    if (_mapNumber <= 1) return;
    await SfxService.playClick();
    await SettingsPage.vibrateTap();
    if (!mounted) return;
    _switchToMap(_mapNumber - 1);
  }

  Future<void> _goToNextMap() async {
    if (_mapNumber >= _maxMapCount) return;
    await SfxService.playClick();
    await SettingsPage.vibrateTap();
    if (!mounted) return;
    _switchToMap(_mapNumber + 1);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _swipeVelocityThreshold) return;

    if (velocity < 0) {
      if (_mapNumber < _maxMapCount) _switchToMap(_mapNumber + 1);
    } else {
      if (_mapNumber > 1) _switchToMap(_mapNumber - 1);
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx <= -_swipeDistanceThreshold) return;
    if (details.delta.dx >= _swipeDistanceThreshold) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.bgDark,
      body: Stack(children: [
        _ThemedFullBackground(controller: _bgController, theme: _theme),
        SafeArea(
          child: Column(children: [
            _buildTitleBar(),
            _buildMapSwitcher(),
            const SizedBox(height: 6),
            Expanded(child: _buildMapArea()),
            const SizedBox(height: 10),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTitleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(children: [
        _GlassButton(
          accentColor: _theme.primaryColor,
          onTap: () async {
            await SfxService.playClick();
            await SettingsPage.vibrateTap();
            if (!mounted) return;
            Navigator.of(context).pop();
          },
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
        const Spacer(),
        Text(
          _theme.name,
          style: TextStyle(
            color: _theme.primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
            shadows: [
              Shadow(
                color: _theme.primaryColor.withValues(alpha: 0.6),
                blurRadius: 12,
              )
            ],
          ),
        ),
        const Spacer(),
        _GlassButton(
          accentColor: _theme.primaryColor,
          onTap: _completeAllLevels,
          child: Icon(
            Icons.done_all_rounded,
            color: _theme.primaryColor,
            size: 20,
          ),
        ),
      ]),
    );
  }

  Widget _buildMapSwitcher() {
    final canBack = _mapNumber > 1;
    final canForward = _mapNumber < _maxMapCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _GlassButton(
              accentColor: canBack
                  ? _theme.primaryColor
                  : Colors.white.withValues(alpha: 0.12),
              onTap: canBack ? _goToPreviousMap : null,
              child: Icon(Icons.chevron_left_rounded,
                  color: canBack ? Colors.white : Colors.white38, size: 22),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(
                    color: _theme.primaryColor.withValues(alpha: 0.28)),
              ),
              child: Text(
                '$_mapNumber / $_maxMapCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _GlassButton(
              accentColor: canForward
                  ? _theme.primaryColor
                  : Colors.white.withValues(alpha: 0.12),
              onTap: canForward ? _goToNextMap : null,
              child: Icon(Icons.chevron_right_rounded,
                  color: canForward ? Colors.white : Colors.white38, size: 22),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.025),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border:
                Border.all(color: _theme.primaryColor.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: _theme.primaryColor.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 24,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final positions = _levelPositions(w, h);

              final isComingSoon = _isComingSoonMap(_mapNumber);

              return Stack(children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: isComingSoon ? 0.42 : 1.0,
                    child: AnimatedBuilder(
                      animation: _bgController,
                      builder: (_, __) => CustomPaint(
                        painter: buildMapBgPainter(_theme, _bgController.value),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: isComingSoon ? 0.35 : 1.0,
                    child: AnimatedBuilder(
                      animation: _bgController,
                      builder: (_, __) => CustomPaint(
                        painter: _MapStarsPainter(
                          twinkle: _bgController.value,
                          color: _theme.accentColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: isComingSoon ? 0.40 : 1.0,
                    child: _AnimatedPathLayer(
                      positions: positions,
                      connections: _layout.connections,
                      completedLevels: completedLevels,
                      unlockedLevels: _unlocked,
                      theme: _theme,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: isComingSoon ? 0.28 : 1.0,
                      child: _MapGlowDecor(positions: positions, theme: _theme),
                    ),
                  ),
                ),
                for (final level in _levels)
                  Positioned(
                    left: positions[level.id]!.dx - _nodeHalfSize,
                    top: positions[level.id]!.dy - _nodeHalfSize,
                    child: _StaggeredNodeEntry(
                      index: level.id - 1,
                      controller: _entryController,
                      child: PremiumLevelNodeWidget(
                        data: level,
                        theme: _theme,
                        onTap: () => _navigateToLevel(level.id),
                      ),
                    ),
                  ),
                if (!isComingSoon && _showPersistentCompletionScene)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _persistentSceneOpacity,
                      duration: _sceneCrossfadeDurationForMap(_mapNumber),
                      curve: Curves.easeOutCubic,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: MapCompletionAmbientScene(
                                mapNumber: _mapNumber,
                                intense: false,
                              ),
                            ),
                          ),
                          if (_showCompletionCongratsCard)
                            Center(
                              child: GestureDetector(
                                onTap: () async {
                                  await SfxService.playClick();
                                  await SettingsPage.vibrateTap();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.52),
                                        Colors.black.withValues(alpha: 0.30),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: _theme.primaryColor
                                          .withValues(alpha: 0.40),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _theme.primaryColor
                                            .withValues(alpha: 0.22),
                                        blurRadius: 28,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.30),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        color: _theme.primaryColor,
                                        size: 32,
                                        shadows: [
                                          Shadow(
                                            color: _theme.primaryColor
                                                .withValues(alpha: 0.7),
                                            blurRadius: 16,
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Tebrikler!',
                                        style: TextStyle(
                                          color: _theme.primaryColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          shadows: [
                                            Shadow(
                                              color: _theme.primaryColor
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 14,
                                            )
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '"${_theme.name}"ı Tamamladınız',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.92),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (!isComingSoon && _showFirstCompletionScene)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _firstSceneOpacity,
                        duration: _sceneCrossfadeDurationForMap(_mapNumber),
                        curve: Curves.easeOutCubic,
                        child: MapCompletionAmbientScene(
                          mapNumber: _mapNumber,
                          intense: true,
                        ),
                      ),
                    ),
                  ),
                if (isComingSoon)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.26),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 72,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STAGGERED ENTRY
// ─────────────────────────────────────────────

class _StaggeredNodeEntry extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _StaggeredNodeEntry(
      {required this.index, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.05).clamp(0.0, 0.82);
    final end = (start + 0.28).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.elasticOut),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) => Transform.scale(
        scale: curved.value,
        child: Opacity(opacity: curved.value.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
//  ANIMATED PATH LAYER
// ─────────────────────────────────────────────

class _AnimatedPathLayer extends StatefulWidget {
  final Map<int, Offset> positions;
  final List<MapConnection> connections;
  final Set<int> completedLevels;
  final Set<int> unlockedLevels;
  final MapTheme theme;

  const _AnimatedPathLayer({
    required this.positions,
    required this.connections,
    required this.completedLevels,
    required this.unlockedLevels,
    required this.theme,
  });

  @override
  State<_AnimatedPathLayer> createState() => _AnimatedPathLayerState();
}

class _AnimatedPathLayerState extends State<_AnimatedPathLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flowController,
      builder: (_, __) => CustomPaint(
        painter: _ThemedBranchMapPainter(
          positions: widget.positions,
          connections: widget.connections,
          completedLevels: widget.completedLevels,
          unlockedLevels: widget.unlockedLevels,
          flowOffset: _flowController.value,
          theme: widget.theme,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PREMIUM LEVEL NODE
// ─────────────────────────────────────────────

class PremiumLevelNodeWidget extends StatefulWidget {
  final LevelNodeData data;
  final MapTheme theme;
  final VoidCallback? onTap;

  const PremiumLevelNodeWidget(
      {super.key, required this.data, required this.theme, this.onTap});

  @override
  State<PremiumLevelNodeWidget> createState() => _PremiumLevelNodeWidgetState();
}

class _PremiumLevelNodeWidgetState extends State<PremiumLevelNodeWidget>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _tapController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _rotateController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6));
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _syncAnimations();
  }

  @override
  void didUpdateWidget(PremiumLevelNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.isUnlocked != widget.data.isUnlocked ||
        oldWidget.data.isCompleted != widget.data.isCompleted) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    final shouldAnimate = widget.data.isUnlocked && !widget.data.isCompleted;
    if (shouldAnimate) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
      if (!_rotateController.isAnimating) _rotateController.repeat();
    } else {
      _pulseController.stop();
      _rotateController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.data.isUnlocked) {
      SettingsPage.vibrateLight();
      _tapController.forward().then((_) => _tapController.reverse());
      return;
    }
    SfxService.playClick();
    SettingsPage.vibrateTap();
    _tapController
        .forward()
        .then((_) => _tapController.reverse())
        .then((_) => widget.onTap?.call());
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = !widget.data.isUnlocked;
    final isCompleted = widget.data.isCompleted;
    final isPlayable = widget.data.isUnlocked && !widget.data.isCompleted;

    final Color topColor;
    final Color bottomColor;
    final Color rimColor;
    final Color glowColor;

    if (isCompleted) {
      topColor = widget.theme.nodeCompletedTop;
      bottomColor = widget.theme.nodeCompletedBottom;
      rimColor = widget.theme.nodeCompletedTop.withValues(alpha: 0.50);
      glowColor = widget.theme.nodeCompletedTop;
    } else if (isPlayable) {
      topColor = widget.theme.nodeActiveTop;
      bottomColor = widget.theme.nodeActiveBottom;
      rimColor = widget.theme.nodeActiveTop.withValues(alpha: 0.40);
      glowColor = widget.theme.primaryColor;
    } else {
      topColor = const Color(0xFF3A3248);
      bottomColor = const Color(0xFF1A1525);
      rimColor = Colors.white.withValues(alpha: 0.08);
      glowColor = const Color(0xFF433A52);
    }

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _tapController]),
        builder: (_, child) {
          final pulse =
              isPlayable ? (1.0 + _pulseController.value * 0.06) : 1.0;
          final tapScale = 1.0 - _tapController.value * 0.08;
          return Transform.scale(scale: pulse * tapScale, child: child);
        },
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(alignment: Alignment.center, children: [
            if (!isLocked)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final sz =
                      isPlayable ? 72 + _pulseController.value * 14.0 : 68.0;
                  return Container(
                    width: sz,
                    height: sz,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        glowColor.withValues(alpha: isCompleted ? 0.22 : 0.32),
                        glowColor.withValues(alpha: 0.0),
                      ]),
                    ),
                  );
                },
              ),
            if (isPlayable)
              AnimatedBuilder(
                animation: _rotateController,
                builder: (_, __) => Transform.rotate(
                  angle: _rotateController.value * 2 * pi,
                  child: CustomPaint(
                    size: const Size(68, 68),
                    painter: _OrbitRingPainter(color: glowColor),
                  ),
                ),
              ),
            CustomPaint(
              size: const Size(62, 62),
              painter: _HexBadgePainter(
                topColor: topColor,
                bottomColor: bottomColor,
                rimColor: rimColor,
                isLocked: isLocked,
                difficultyCount: widget.data.difficulty.dotCount,
                difficultyColor: isLocked
                    ? Colors.white.withValues(alpha: 0.16)
                    : _adaptiveDifficultyRingColor(
                        themeColor: widget.theme.primaryColor,
                        topColor: topColor,
                        bottomColor: bottomColor,
                        brighten: isCompleted,
                      ),
              ),
            ),
            if (isLocked)
              ClipPath(
                clipper: _HexClipper(),
                child: Container(
                  width: 62,
                  height: 62,
                  color: Colors.black.withValues(alpha: 0.38),
                ),
              ),
            SizedBox(
              width: 62,
              height: 62,
              child: Center(
                child: isLocked
                    ? const Icon(Icons.lock_rounded,
                        color: Colors.white54, size: 22)
                    : isCompleted
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 28)
                        : const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 30),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  THEMED BRANCH MAP PAINTER
// ─────────────────────────────────────────────

class _ThemedBranchMapPainter extends CustomPainter {
  final Map<int, Offset> positions;
  final List<MapConnection> connections;
  final Set<int> completedLevels;
  final Set<int> unlockedLevels;
  final double flowOffset;
  final MapTheme theme;

  const _ThemedBranchMapPainter({
    required this.positions,
    required this.connections,
    required this.completedLevels,
    required this.unlockedLevels,
    required this.flowOffset,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in connections) {
      _drawConnection(canvas, size, c.from, c.to);
    }
  }

  Path _buildPath(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..cubicTo(
        p1.dx + dx * 0.18,
        p1.dy + dy * 0.36,
        p1.dx + dx * 0.82,
        p1.dy + dy * 0.64,
        p2.dx,
        p2.dy,
      );
  }

  void _drawConnection(Canvas canvas, Size size, int a, int b) {
    final p1 = positions[a]!;
    final p2 = positions[b]!;
    final isActive = completedLevels.contains(a) || unlockedLevels.contains(b);
    final path = _buildPath(p1, p2);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 12 : 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    if (!isActive) {
      _drawDashedPath(
        canvas,
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
        dashLen: 6,
        gapLen: 5,
        offset: 0,
      );
      return;
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = theme.accentColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: theme.pathGradient,
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    _drawDashedPath(
      canvas,
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
      dashLen: 8,
      gapLen: 10,
      offset: flowOffset,
    );

    _drawDirectionDot(canvas, path, 0.5);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLen,
    required double gapLen,
    required double offset,
  }) {
    for (final metric in path.computeMetrics()) {
      final total = metric.length;
      final period = dashLen + gapLen;
      var start = offset * period * -1;
      while (start < total) {
        final end = (start + dashLen).clamp(0.0, total);
        if (start >= 0 && end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        start += period;
      }
    }
  }

  void _drawDirectionDot(Canvas canvas, Path path, double t) {
    final metric = path.computeMetrics().first;
    final tangent = metric.getTangentForOffset(metric.length * t);
    if (tangent == null) return;
    canvas.drawCircle(
      tangent.position,
      3.5,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      tangent.position,
      6,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _ThemedBranchMapPainter old) =>
      old.flowOffset != flowOffset ||
      old.completedLevels != completedLevels ||
      old.unlockedLevels != unlockedLevels ||
      old.connections != connections;
}

// ─────────────────────────────────────────────
//  THEMED FULL BACKGROUND
// ─────────────────────────────────────────────

class _ThemedFullBackground extends StatelessWidget {
  final AnimationController controller;
  final MapTheme theme;

  const _ThemedFullBackground({required this.controller, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.bgDark, theme.bgMid, theme.bgLight, theme.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t = controller.value;
          final w = MediaQuery.of(context).size.width;
          final h = MediaQuery.of(context).size.height;
          return Stack(children: [
            _glow(
              -90 + sin(t * pi) * 20,
              -120 + cos(t * pi) * 15,
              270,
              theme.primaryColor.withValues(alpha: 0.14),
            ),
            _glow(
              w - 170 + cos(t * pi) * 20,
              120 + sin(t * pi) * 18,
              250,
              theme.secondaryColor.withValues(alpha: 0.10),
            ),
            _glow(
              -80 + sin(t * pi * 1.3) * 16,
              h - 200 + cos(t * pi) * 20,
              260,
              theme.accentColor.withValues(alpha: 0.08),
            ),
            _glow(
              w - 140 + cos(t * pi * 1.2) * 18,
              h - 180 + sin(t * pi) * 22,
              230,
              theme.primaryColor.withValues(alpha: 0.09),
            ),
          ]);
        },
      ),
    ]);
  }

  Widget _glow(double l, double t, double sz, Color c) => Positioned(
        left: l,
        top: t,
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  MAP STARS PAINTER
// ─────────────────────────────────────────────

class _MapStarsPainter extends CustomPainter {
  final double twinkle;
  final Color color;

  const _MapStarsPainter({required this.twinkle, required this.color});

  static const _starDefs = [
    [0.12, 0.14, 2.2, 0.0],
    [0.26, 0.18, 1.5, 0.3],
    [0.84, 0.17, 2.0, 0.6],
    [0.73, 0.40, 1.5, 0.2],
    [0.19, 0.46, 1.8, 0.8],
    [0.87, 0.62, 1.5, 0.4],
    [0.58, 0.79, 2.2, 0.1],
    [0.10, 0.82, 1.5, 0.7],
    [0.45, 0.35, 1.2, 0.5],
    [0.65, 0.22, 1.8, 0.9],
    [0.38, 0.65, 1.4, 0.15],
    [0.92, 0.44, 1.6, 0.55],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _starDefs) {
      final phase = s[3];
      final t = sin((twinkle + phase) * pi);
      final opacity = 0.10 + t.abs() * 0.25;
      final r = s[2];
      final pos = Offset(size.width * s[0], size.height * s[1]);
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = color.withValues(alpha: opacity * 0.8),
      );
      canvas.drawCircle(
        pos,
        r * 3.5,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_MapStarsPainter old) =>
      old.twinkle != twinkle || old.color != color;
}

// ─────────────────────────────────────────────
//  MAP GLOW DECOR
// ─────────────────────────────────────────────

class _MapGlowDecor extends StatelessWidget {
  final Map<int, Offset> positions;
  final MapTheme theme;

  const _MapGlowDecor({required this.positions, required this.theme});

  @override
  Widget build(BuildContext context) {
    final values = positions.values.toList();
    if (values.isEmpty) return const SizedBox.shrink();
    final first = values.first;
    final last = values.last;
    final mid = values[values.length ~/ 2];
    final quarter = values[values.length > 3 ? 3 : values.length - 1];
    return Stack(children: [
      _orb(last.dx - 100, last.dy - 130, 200,
          theme.accentColor.withValues(alpha: 0.11)),
      _orb(mid.dx - 120, mid.dy - 80, 180,
          theme.secondaryColor.withValues(alpha: 0.09)),
      _orb(quarter.dx - 80, quarter.dy - 110, 170,
          theme.primaryColor.withValues(alpha: 0.09)),
      _orb(first.dx - 90, first.dy - 90, 160,
          theme.nodeCompletedTop.withValues(alpha: 0.07)),
    ]);
  }

  Widget _orb(double l, double t, double sz, Color c) => Positioned(
        left: l,
        top: t,
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  ORBIT RING PAINTER
// ─────────────────────────────────────────────

class _OrbitRingPainter extends CustomPainter {
  final Color color;
  const _OrbitRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const dotCount = 8;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * pi;
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle) * radius,
          center.dy + sin(angle) * radius,
        ),
        i.isEven ? 2.5 : 1.5,
        Paint()..color = color.withValues(alpha: (i / dotCount) * 0.9 + 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitRingPainter old) => old.color != color;
}

// ─────────────────────────────────────────────
//  HEX CLIPPER
// ─────────────────────────────────────────────

class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 * 0.92;
    for (int i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * pi / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HexClipper old) => false;
}

// ─────────────────────────────────────────────
//  HEX BADGE PAINTER
// ─────────────────────────────────────────────

class _HexBadgePainter extends CustomPainter {
  final Color topColor;
  final Color bottomColor;
  final Color rimColor;
  final bool isLocked;
  final int difficultyCount;
  final Color difficultyColor;

  const _HexBadgePainter({
    required this.topColor,
    required this.bottomColor,
    required this.rimColor,
    required this.isLocked,
    required this.difficultyCount,
    required this.difficultyColor,
  });

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * pi / 180;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawDifficultyRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final count = difficultyCount.clamp(1, 5);

    const baseOuterInset = 8.0;
    const ringGap = 4.2;
    final maxRadius = (size.width / 2) - baseOuterInset;
    final minRadius = maxRadius - ((count - 1) * ringGap);

    for (int i = 0; i < count; i++) {
      final radius = maxRadius - (i * ringGap);
      final ring = _hexPath(center, radius);

      final normalized = count == 1
          ? 1.0
          : 1.0 - ((radius - minRadius) / (maxRadius - minRadius));
      final opacity =
          isLocked ? 0.11 + (normalized * 0.07) : 0.58 + (normalized * 0.22);
      final strokeWidth = count >= 4 ? 1.15 : 1.35;

      canvas.drawPath(
        ring,
        Paint()
          ..color = difficultyColor.withValues(alpha: opacity.clamp(0.0, 0.95))
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );

      if (!isLocked) {
        canvas.drawPath(
          ring,
          Paint()
            ..color = difficultyColor.withValues(
                alpha: (opacity * 0.18).clamp(0.0, 0.24))
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 1.1
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final hex = _hexPath(center, radius * 0.92);

    canvas.drawPath(
      _hexPath(center.translate(0, 5), radius * 0.92),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawPath(
      _hexPath(center.translate(0, 6), radius * 0.92),
      Paint()..color = bottomColor.withValues(alpha: 0.55),
    );

    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          colors: [topColor, bottomColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    _drawDifficultyRings(canvas, size);

    canvas.drawPath(
      hex,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawPath(
      hex,
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );
  }

  @override
  bool shouldRepaint(covariant _HexBadgePainter old) =>
      old.topColor != topColor ||
      old.bottomColor != bottomColor ||
      old.rimColor != rimColor ||
      old.isLocked != isLocked ||
      old.difficultyCount != difficultyCount ||
      old.difficultyColor != difficultyColor;
}

// ─────────────────────────────────────────────
//  GLASS BUTTON
// ─────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color accentColor;

  const _GlassButton({
    required this.child,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.04),
            ]),
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
