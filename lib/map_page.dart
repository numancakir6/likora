import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_page.dart';
import 'map_theme.dart';

// ─────────────────────────────────────────────
//  DIFFICULTY & BOTTLE ICONS
// ─────────────────────────────────────────────

enum LevelDifficulty { easy, medium, hard, expert, legendary }

extension LevelDifficultyExt on LevelDifficulty {
  int get bottleCount {
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

  Color get bottleColor {
    switch (this) {
      case LevelDifficulty.easy:
        return const Color(0xFF13F08B);
      case LevelDifficulty.medium:
        return const Color(0xFFFFD740);
      case LevelDifficulty.hard:
        return const Color(0xFFFF6D00);
      case LevelDifficulty.expert:
        return const Color(0xFFF50057);
      case LevelDifficulty.legendary:
        return const Color(0xFFD500F9);
    }
  }
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
  final ratio = levelId / totalLevels;

  if (ratio <= 0.20) return LevelDifficulty.easy;
  if (ratio <= 0.45) return LevelDifficulty.medium;
  if (ratio <= 0.68) return LevelDifficulty.hard;
  if (ratio <= 0.88) return LevelDifficulty.expert;
  return LevelDifficulty.legendary;
}

// ═══════════════════════════════════════════════════════════════
//  MAP PAGE
// ═══════════════════════════════════════════════════════════════

class MapPage extends StatefulWidget {
  final int mapNumber;

  const MapPage({super.key, this.mapNumber = 1});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  static const int _maxMapCount = 15;

  late final AnimationController _bgController;
  late final AnimationController _entryController;

  late final MapTheme _theme;
  late final MapLayoutData _layout;

  Set<int> completedLevels = <int>{1};
  late Set<int> _unlocked;
  late List<LevelNodeData> _levels;

  @override
  void initState() {
    super.initState();
    _theme = getMapTheme(widget.mapNumber);
    _layout = getMapLayout(widget.mapNumber);
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
    _unlocked = _computeUnlockedLevels(
      completed: completedLevels,
      connections: _layout.connections,
    );

    _levels = List.generate(_layout.totalLevels, (i) {
      final id = i + 1;
      return LevelNodeData(
        id: id,
        isCompleted: completedLevels.contains(id),
        isUnlocked: _unlocked.contains(id),
        starCount: completedLevels.contains(id) ? (1 + id % 3) : 0,
        difficulty: _difficultyFor(widget.mapNumber, id, _layout.totalLevels),
      );
    });
  }

  static Set<int> _computeUnlockedLevels({
    required Set<int> completed,
    required List<MapConnection> connections,
  }) {
    final unlocked = <int>{1};

    final incomingMap = <int, List<int>>{};

    for (final connection in connections) {
      incomingMap
          .putIfAbsent(connection.to, () => <int>[])
          .add(connection.from);
    }

    for (final entry in incomingMap.entries) {
      final targetLevel = entry.key;
      final requiredParents = entry.value;

      final allParentsCompleted = requiredParents.every(
        (parentLevel) => completed.contains(parentLevel),
      );

      if (allParentsCompleted) {
        unlocked.add(targetLevel);
      }
    }

    unlocked.addAll(completed);
    return unlocked;
  }

  Map<int, Offset> _levelPositions(double w, double h) {
    return {
      for (final node in _layout.nodes) node.id: Offset(w * node.x, h * node.y),
    };
  }

  Future<void> _navigateToLevel(int levelId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(level: levelId, mapNumber: widget.mapNumber),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        completedLevels = {...completedLevels, levelId};
        _rebuildLevels();
      });
    }
  }

  void _goToPreviousMap() {
    if (widget.mapNumber <= 1) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(mapNumber: widget.mapNumber - 1),
      ),
    );
  }

  void _goToNextMap() {
    if (widget.mapNumber >= _maxMapCount) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(mapNumber: widget.mapNumber + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.bgDark,
      body: Stack(
        children: [
          _ThemedFullBackground(controller: _bgController, theme: _theme),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildProgressCard(),
                const SizedBox(height: 6),
                Expanded(child: _buildMapArea()),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final canGoBack = widget.mapNumber > 1;
    final canGoForward = widget.mapNumber < _maxMapCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Row(
            children: [
              _GlassButton(
                accentColor: canGoBack
                    ? _theme.primaryColor
                    : Colors.white.withOpacity(0.12),
                onTap: canGoBack ? _goToPreviousMap : null,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: canGoBack ? Colors.white : Colors.white38,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              _GlassButton(
                accentColor: canGoForward
                    ? _theme.primaryColor
                    : Colors.white.withOpacity(0.12),
                onTap: canGoForward ? _goToNextMap : null,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: canGoForward ? Colors.white : Colors.white38,
                  size: 18,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                _theme.name,
                style: TextStyle(
                  color: _theme.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  shadows: [
                    Shadow(
                      color: _theme.primaryColor.withOpacity(0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_theme.subtitle}  •  ${widget.mapNumber}/$_maxMapCount',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.50),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const Spacer(),
          _CoinBadge(accentColor: _theme.primaryColor),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: _TopInfoCard(
        completedCount: completedLevels.length,
        totalCount: _layout.totalLevels,
        theme: _theme,
      ),
    );
  }

  Widget _buildMapArea() {
    return Padding(
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final positions = _levelPositions(w, h);

              return Stack(
                children: [
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STAGGERED ENTRY ANIMATION
// ─────────────────────────────────────────────

class _StaggeredNodeEntry extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _StaggeredNodeEntry({
    required this.index,
    required this.controller,
    required this.child,
  });

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

  const PremiumLevelNodeWidget({
    super.key,
    required this.data,
    required this.theme,
    this.onTap,
  });

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
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    final isCurrent = widget.data.isUnlocked && !widget.data.isCompleted;
    if (isCurrent) {
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
    final isCurrent = widget.data.isUnlocked && !widget.data.isCompleted;

    final Color topColor;
    final Color bottomColor;
    final Color rimColor;
    final Color glowColor;

    if (isCompleted) {
      topColor = widget.theme.nodeCompletedTop;
      bottomColor = widget.theme.nodeCompletedBottom;
      rimColor = widget.theme.nodeCompletedTop.withOpacity(0.50);
      glowColor = widget.theme.nodeCompletedTop;
    } else if (isCurrent) {
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
          final pulse = isCurrent ? (1.0 + _pulseController.value * 0.06) : 1.0;
          final tapScale = 1.0 - _tapController.value * 0.08;
          return Transform.scale(scale: pulse * tapScale, child: child);
        },
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!isLocked)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) {
                    final sz =
                        isCurrent ? 84 + _pulseController.value * 18.0 : 80.0;
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
              if (isCurrent)
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLocked)
                      const Icon(Icons.lock_rounded,
                          color: Colors.white54, size: 22)
                    else if (isCompleted)
                      const Icon(Icons.check_rounded,
                          color: Colors.white, size: 28)
                    else
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 30),
                  ],
                ),
              ),
              if (isCompleted && widget.data.starCount > 0)
                Positioned(
                  top: 4,
                  child: _StarRow(count: widget.data.starCount),
                ),
              Positioned(
                bottom: 0,
                child: _BottleRow(
                  difficulty: widget.data.difficulty,
                  isLocked: isLocked,
                ),
              ),
            ],
          ),
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

  const _ThemedFullBackground({
    required this.controller,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
            return Stack(
              children: [
                _glow(-90 + sin(t * pi) * 20, -120 + cos(t * pi) * 15, 270,
                    theme.primaryColor.withOpacity(0.14)),
                _glow(w - 170 + cos(t * pi) * 20, 120 + sin(t * pi) * 18, 250,
                    theme.secondaryColor.withOpacity(0.10)),
                _glow(-80 + sin(t * pi * 1.3) * 16, h - 200 + cos(t * pi) * 20,
                    260, theme.accentColor.withOpacity(0.08)),
                _glow(
                  w - 140 + cos(t * pi * 1.2) * 18,
                  h - 180 + sin(t * pi) * 22,
                  230,
                  theme.primaryColor.withOpacity(0.09),
                ),
              ],
            );
          },
        ),
      ],
    );
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

  const _MapStarsPainter({
    required this.twinkle,
    required this.color,
  });

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

      canvas.drawCircle(
        Offset(size.width * s[0], size.height * s[1]),
        r,
        Paint()..color = color.withOpacity(opacity * 0.8),
      );

      canvas.drawCircle(
        Offset(size.width * s[0], size.height * s[1]),
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

  const _MapGlowDecor({
    required this.positions,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final values = positions.values.toList();
    if (values.isEmpty) return const SizedBox.shrink();

    final first = values.first;
    final last = values.last;
    final mid = values[values.length ~/ 2];
    final quarter = values[values.length > 3 ? 3 : values.length - 1];

    return Stack(
      children: [
        _orb(last.dx - 100, last.dy - 130, 200,
            theme.accentColor.withOpacity(0.11)),
        _orb(mid.dx - 120, mid.dy - 80, 180,
            theme.secondaryColor.withOpacity(0.09)),
        _orb(quarter.dx - 80, quarter.dy - 110, 170,
            theme.primaryColor.withOpacity(0.09)),
        _orb(first.dx - 90, first.dy - 90, 160,
            theme.nodeCompletedTop.withOpacity(0.07)),
      ],
    );
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
//  STAR ROW
// ─────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final int count;

  const _StarRow({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 10,
          color:
              filled ? const Color(0xFFFFD740) : Colors.white.withOpacity(0.25),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
//  BOTTLE ROW
// ─────────────────────────────────────────────

class _BottleRow extends StatelessWidget {
  final LevelDifficulty difficulty;
  final bool isLocked;

  const _BottleRow({
    required this.difficulty,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isLocked ? Colors.white.withOpacity(0.22) : difficulty.bottleColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        difficulty.bottleCount,
        (i) => _BottleIcon(color: color),
      ),
    );
  }
}

class _BottleIcon extends StatelessWidget {
  final Color color;

  const _BottleIcon({required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: CustomPaint(
          size: const Size(6, 10),
          painter: _BottlePainter(color: color),
        ),
      );
}

class _BottlePainter extends CustomPainter {
  final Color color;

  const _BottlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, 0, w * 0.4, h * 0.28),
        const Radius.circular(1),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.3, w, h * 0.7),
        Radius.circular(w * 0.32),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.15, h * 0.38, w * 0.2, h * 0.28),
        Radius.circular(w * 0.1),
      ),
      Paint()..color = Colors.white.withOpacity(0.30),
    );
  }

  @override
  bool shouldRepaint(_BottlePainter old) => old.color != color;
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

  const _HexBadgePainter({
    required this.topColor,
    required this.bottomColor,
    required this.rimColor,
    required this.isLocked,
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

    canvas.drawPath(
      _hexPath(center, radius * 0.72),
      Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.22, size.height * 0.24)
        ..lineTo(size.width * 0.78, size.height * 0.24)
        ..lineTo(size.width * 0.66, size.height * 0.42)
        ..lineTo(size.width * 0.34, size.height * 0.42)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.26),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5)),
    );
  }

  @override
  bool shouldRepaint(covariant _HexBadgePainter old) =>
      old.topColor != topColor ||
      old.bottomColor != bottomColor ||
      old.rimColor != rimColor ||
      old.isLocked != isLocked;
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
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.55 : 1,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
            ),
            border: Border.all(color: accentColor.withOpacity(0.25)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  COIN BADGE
// ─────────────────────────────────────────────

class _CoinBadge extends StatelessWidget {
  final Color accentColor;

  const _CoinBadge({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
        ),
        border: Border.all(color: accentColor.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.monetization_on_rounded, color: accentColor, size: 18),
          const SizedBox(width: 6),
          const Text(
            '1250',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOP INFO CARD
// ─────────────────────────────────────────────

class _TopInfoCard extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final MapTheme theme;

  const _TopInfoCard({
    required this.completedCount,
    required this.totalCount,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.09),
            Colors.white.withOpacity(0.035),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.primaryColor.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.35),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(theme.progressIcon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlerleme',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  theme.lore,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [
                                    theme.primaryColor,
                                    theme.secondaryColor,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$completedCount/$totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
