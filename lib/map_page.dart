import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart';
import 'map_theme.dart';

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
  static const double _swipeVelocityThreshold = 250;
  static const double _swipeDistanceThreshold = 24;

  static final Map<int, Set<int>> _mapCompletedLevels = {
    1: <int>{},
  };

  late final AnimationController _bgController;
  late final AnimationController _entryController;

  late final int _mapNumber;
  late final MapTheme _theme;
  late final MapLayoutData _layout;

  late Set<int> completedLevels;
  late Set<int> _unlocked;
  late List<LevelNodeData> _levels;

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

  static bool _isMapFullyCompleted(int mapNumber) {
    final layout = getMapLayout(mapNumber);
    final completed = _mapCompletedLevels[mapNumber] ?? <int>{};
    return completed.length >= layout.totalLevels;
  }

  static bool _isMapPlayableStatic(int mapNumber) {
    if (mapNumber <= 1) return true;
    return _isMapFullyCompleted(mapNumber - 1);
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
    if (mapNumber <= 1) return true;

    final previousLayout = getMapLayout(mapNumber - 1);
    final previousCompleted = _mapCompletedLevels[mapNumber - 1] ?? <int>{};
    return previousCompleted.length >= previousLayout.totalLevels;
  }

  Map<int, Offset> _levelPositions(double w, double h) => {
        for (final node in _layout.nodes)
          node.id: Offset(w * node.x, h * node.y),
      };

  Future<void> _navigateToLevel(int levelId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(level: levelId, mapNumber: widget.mapNumber),
      ),
    );

    if (result == true && mounted) {
      final updatedCompleted = {...completedLevels, levelId};

      setState(() {
        completedLevels = updatedCompleted;
        _rebuildLevels();
      });

      final isMapFullyCompleted =
          updatedCompleted.length >= _layout.totalLevels;

      if (isMapFullyCompleted && widget.mapNumber < _maxMapCount) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          _goToNextMap();
        });
      }
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

  void _goToPreviousMap() {
    if (_mapNumber <= 1) return;
    _switchToMap(_mapNumber - 1);
  }

  void _goToNextMap() {
    if (_mapNumber >= _maxMapCount) return;
    _switchToMap(_mapNumber + 1);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _swipeVelocityThreshold) return;

    if (velocity < 0) {
      _goToNextMap();
    } else {
      _goToPreviousMap();
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
          onTap: () => Navigator.of(context).pop(),
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
                color: _theme.primaryColor.withOpacity(0.6),
                blurRadius: 12,
              )
            ],
          ),
        ),
        const Spacer(),
        const SizedBox(width: 46),
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
                  : Colors.white.withOpacity(0.12),
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
                    Colors.white.withOpacity(0.10),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                border:
                    Border.all(color: _theme.primaryColor.withOpacity(0.28)),
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
                  : Colors.white.withOpacity(0.12),
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
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.025),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _theme.primaryColor.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: _theme.primaryColor.withOpacity(0.12),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.40),
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

              return Stack(children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _bgController,
                    builder: (_, __) => CustomPaint(
                      painter: buildMapBgPainter(_theme, _bgController.value),
                    ),
                  ),
                ),
                Positioned.fill(
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
                Positioned.fill(
                  child: _AnimatedPathLayer(
                    positions: positions,
                    connections: _layout.connections,
                    completedLevels: completedLevels,
                    unlockedLevels: _unlocked,
                    theme: _theme,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _MapGlowDecor(positions: positions, theme: _theme),
                  ),
                ),
                for (final level in _levels)
                  Positioned(
                    left: positions[level.id]!.dx - 42,
                    top: positions[level.id]!.dy - 42,
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

    if (widget.data.isUnlocked && !widget.data.isCompleted) {
      _pulseController.repeat(reverse: true);
      _rotateController.repeat();
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
      HapticFeedback.lightImpact();
      _tapController.forward().then((_) => _tapController.reverse());
      return;
    }
    HapticFeedback.mediumImpact();
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
      rimColor = widget.theme.nodeCompletedTop.withOpacity(0.50);
      glowColor = widget.theme.nodeCompletedTop;
    } else if (isPlayable) {
      topColor = widget.theme.nodeActiveTop;
      bottomColor = widget.theme.nodeActiveBottom;
      rimColor = widget.theme.nodeActiveTop.withOpacity(0.40);
      glowColor = widget.theme.primaryColor;
    } else {
      topColor = const Color(0xFF3A3248);
      bottomColor = const Color(0xFF1A1525);
      rimColor = Colors.white.withOpacity(0.08);
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
          width: 84,
          height: 84,
          child: Stack(alignment: Alignment.center, children: [
            if (!isLocked)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final sz =
                      isPlayable ? 84 + _pulseController.value * 18.0 : 80.0;
                  return Container(
                    width: sz,
                    height: sz,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        glowColor.withOpacity(isCompleted ? 0.22 : 0.32),
                        glowColor.withOpacity(0.0),
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
                    size: const Size(78, 78),
                    painter: _OrbitRingPainter(color: glowColor),
                  ),
                ),
              ),
            CustomPaint(
              size: const Size(72, 72),
              painter: _HexBadgePainter(
                topColor: topColor,
                bottomColor: bottomColor,
                rimColor: rimColor,
                isLocked: isLocked,
                difficultyCount: widget.data.difficulty.dotCount,
                difficultyColor: isLocked
                    ? Colors.white.withOpacity(0.16)
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
                  width: 72,
                  height: 72,
                  color: Colors.black.withOpacity(0.38),
                ),
              ),
            SizedBox(
              width: 72,
              height: 72,
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
        ..color = Colors.black.withOpacity(0.30)
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
          ..color = Colors.white.withOpacity(0.10)
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
        ..color = theme.accentColor.withOpacity(0.20)
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
        ..color = Colors.white.withOpacity(0.28)
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
      Paint()..color = Colors.white.withOpacity(0.45),
    );
    canvas.drawCircle(
      tangent.position,
      6,
      Paint()
        ..color = Colors.white.withOpacity(0.10)
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
              theme.primaryColor.withOpacity(0.14),
            ),
            _glow(
              w - 170 + cos(t * pi) * 20,
              120 + sin(t * pi) * 18,
              250,
              theme.secondaryColor.withOpacity(0.10),
            ),
            _glow(
              -80 + sin(t * pi * 1.3) * 16,
              h - 200 + cos(t * pi) * 20,
              260,
              theme.accentColor.withOpacity(0.08),
            ),
            _glow(
              w - 140 + cos(t * pi * 1.2) * 18,
              h - 180 + sin(t * pi) * 22,
              230,
              theme.primaryColor.withOpacity(0.09),
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
            gradient: RadialGradient(colors: [c, c.withOpacity(0)]),
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
      final phase = s[3] as double;
      final t = sin((twinkle + phase) * pi);
      final opacity = 0.10 + t.abs() * 0.25;
      final r = s[2] as double;
      final pos = Offset(size.width * s[0], size.height * s[1]);
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = color.withOpacity(opacity * 0.8),
      );
      canvas.drawCircle(
        pos,
        r * 3.5,
        Paint()
          ..color = color.withOpacity(opacity * 0.12)
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
          theme.accentColor.withOpacity(0.11)),
      _orb(mid.dx - 120, mid.dy - 80, 180,
          theme.secondaryColor.withOpacity(0.09)),
      _orb(quarter.dx - 80, quarter.dy - 110, 170,
          theme.primaryColor.withOpacity(0.09)),
      _orb(first.dx - 90, first.dy - 90, 160,
          theme.nodeCompletedTop.withOpacity(0.07)),
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
            gradient: RadialGradient(colors: [c, c.withOpacity(0)]),
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
        Paint()..color = color.withOpacity((i / dotCount) * 0.9 + 0.1),
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
          ..color = difficultyColor.withOpacity(opacity.clamp(0.0, 0.95))
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );

      if (!isLocked) {
        canvas.drawPath(
          ring,
          Paint()
            ..color =
                difficultyColor.withOpacity((opacity * 0.18).clamp(0.0, 0.24))
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
        ..color = Colors.black.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawPath(
      _hexPath(center.translate(0, 6), radius * 0.92),
      Paint()..color = bottomColor.withOpacity(0.55),
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
        ..color = Colors.black.withOpacity(0.18)
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
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.04),
            ]),
            border: Border.all(color: accentColor.withOpacity(0.25)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
