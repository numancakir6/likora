import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final int starCount; // 0-3
  final LevelDifficulty difficulty;

  const LevelNodeData({
    required this.id,
    required this.isCompleted,
    required this.isUnlocked,
    this.starCount = 0,
    required this.difficulty,
  });
}

// ─────────────────────────────────────────────
//  DIFFICULTY PER LEVEL (customize freely)
// ─────────────────────────────────────────────

const _levelDifficulties = <int, LevelDifficulty>{
  1: LevelDifficulty.easy,
  2: LevelDifficulty.easy,
  3: LevelDifficulty.medium,
  4: LevelDifficulty.medium,
  5: LevelDifficulty.hard,
  6: LevelDifficulty.hard,
  7: LevelDifficulty.expert,
  8: LevelDifficulty.expert,
  9: LevelDifficulty.legendary,
  10: LevelDifficulty.legendary,
};

// ─────────────────────────────────────────────
//  MAP PAGE
// ─────────────────────────────────────────────

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _entryController;

  final completedLevels = <int>{1};
  // test: final completedLevels = <int>{1,2,3,4,5,6,7,8,9};

  late final Set<int> _unlocked;
  late final List<LevelNodeData> _levels;

  @override
  void initState() {
    super.initState();
    _unlocked = _computeUnlockedLevels(completedLevels);
    _levels = List.generate(10, (i) {
      final id = i + 1;
      return LevelNodeData(
        id: id,
        isCompleted: completedLevels.contains(id),
        isUnlocked: _unlocked.contains(id),
        starCount: completedLevels.contains(id) ? (1 + id % 3) : 0,
        difficulty: _levelDifficulties[id] ?? LevelDifficulty.easy,
      );
    });

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

  static Set<int> _computeUnlockedLevels(Set<int> completed) {
    final unlocked = <int>{1};
    if (completed.contains(1)) unlocked.addAll([2, 3]);
    if (completed.contains(2)) unlocked.addAll([6, 7]);
    if (completed.contains(3)) unlocked.addAll([4, 5]);
    if (completed.contains(4) && completed.contains(5)) unlocked.add(9);
    if (completed.contains(6) && completed.contains(7)) unlocked.add(8);
    if (completed.contains(8) && completed.contains(9)) unlocked.add(10);
    unlocked.addAll(completed);
    return unlocked;
  }

  static Map<int, Offset> _levelPositions(double w, double h) {
    return {
      10: Offset(w * 0.51, h * 0.095),
      9: Offset(w * 0.21, h * 0.28),
      8: Offset(w * 0.79, h * 0.29),
      5: Offset(w * 0.10, h * 0.56),
      4: Offset(w * 0.34, h * 0.525),
      6: Offset(w * 0.66, h * 0.525),
      7: Offset(w * 0.90, h * 0.55),
      3: Offset(w * 0.32, h * 0.735),
      2: Offset(w * 0.71, h * 0.745),
      1: Offset(w * 0.515, h * 0.92),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08050D),
      body: Stack(
        children: [
          // Animated background
          _PremiumMapBackground(controller: _bgController),

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _GlassButton(
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Column(
            children: [
              const Text(
                'HARİTA 1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dallanarak ilerleyen yol',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const Spacer(),
          _CoinBadge(),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: _TopInfoCard(completedCount: completedLevels.length),
    );
  }

  Widget _buildMapArea() {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.32),
                  blurRadius: 32,
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
                      // Stars layer
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _bgController,
                          builder: (_, __) => CustomPaint(
                            painter: _MapStarsPainter(
                              twinkle: _bgController.value,
                            ),
                          ),
                        ),
                      ),

                      // Fog / atmosphere
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _bgController,
                          builder: (_, __) => CustomPaint(
                            painter: _FogPainter(t: _bgController.value),
                          ),
                        ),
                      ),

                      // Path connections
                      Positioned.fill(
                        child: _AnimatedPathLayer(
                          positions: positions,
                          completedLevels: completedLevels,
                          unlockedLevels: _unlocked,
                        ),
                      ),

                      // Glow orbs behind nodes
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _MapGlowDecor(positions: positions),
                        ),
                      ),

                      // Level nodes with staggered entry
                      for (final level in _levels)
                        Positioned(
                          left: positions[level.id]!.dx - 42,
                          top: positions[level.id]!.dy - 42,
                          child: _StaggeredNodeEntry(
                            index: level.id - 1,
                            controller: _entryController,
                            child: PremiumLevelNodeWidget(data: level),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
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
    final start = (index * 0.07).clamp(0.0, 0.8);
    final end = (start + 0.3).clamp(0.0, 1.0);

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
//  ANIMATED PATH LAYER (flowing dash effect)
// ─────────────────────────────────────────────

class _AnimatedPathLayer extends StatefulWidget {
  final Map<int, Offset> positions;
  final Set<int> completedLevels;
  final Set<int> unlockedLevels;

  const _AnimatedPathLayer({
    required this.positions,
    required this.completedLevels,
    required this.unlockedLevels,
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
        painter: PremiumBranchMapPainter(
          positions: widget.positions,
          completedLevels: widget.completedLevels,
          unlockedLevels: widget.unlockedLevels,
          flowOffset: _flowController.value,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PREMIUM LEVEL NODE WIDGET
// ─────────────────────────────────────────────

class PremiumLevelNodeWidget extends StatefulWidget {
  final LevelNodeData data;

  const PremiumLevelNodeWidget({super.key, required this.data});

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
    _tapController.forward().then((_) => _tapController.reverse()).then((_) {
      // Navigate to level
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = !widget.data.isUnlocked;
    final isCompleted = widget.data.isCompleted;
    final isCurrent = widget.data.isUnlocked && !widget.data.isCompleted;

    // Colors per state
    final Color topColor;
    final Color bottomColor;
    final Color rimColor;
    final Color glowColor;

    if (isCompleted) {
      topColor = const Color(0xFF13F08B);
      bottomColor = const Color(0xFF0A8048);
      rimColor = const Color(0xFFB7FFD9).withOpacity(0.50);
      glowColor = const Color(0xFF12E07F);
    } else if (isCurrent) {
      topColor = const Color(0xFFFF2E78);
      bottomColor = const Color(0xFF8B0F40);
      rimColor = const Color(0xFFFFB4CD).withOpacity(0.40);
      glowColor = const Color(0xFFF50057);
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
          return Transform.scale(
            scale: pulse * tapScale,
            child: child,
          );
        },
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring (animated for current)
              if (!isLocked)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) {
                    final glowSize =
                        isCurrent ? 84 + _pulseController.value * 18.0 : 80.0;
                    return Container(
                      width: glowSize,
                      height: glowSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            glowColor.withOpacity(isCompleted ? 0.22 : 0.32),
                            glowColor.withOpacity(0.0),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // Rotating orbit ring for current node
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

              // Hex badge
              CustomPaint(
                size: const Size(72, 72),
                painter: _HexBadgePainter(
                  topColor: topColor,
                  bottomColor: bottomColor,
                  rimColor: rimColor,
                  isLocked: isLocked,
                ),
              ),

              // Fog-of-war blur overlay for locked
              if (isLocked)
                ClipPath(
                  clipper: _HexClipper(),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: Colors.black.withOpacity(0.38),
                  ),
                ),

              // Center content
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

              // Star row (completed only)
              if (isCompleted && widget.data.starCount > 0)
                Positioned(
                  top: 4,
                  child: _StarRow(count: widget.data.starCount),
                ),

              // Difficulty bottles (bottom)
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
//  ORBIT RING PAINTER
// ─────────────────────────────────────────────

class _OrbitRingPainter extends CustomPainter {
  final Color color;
  _OrbitRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    const dotCount = 8;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * pi;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      final opacity = (i / dotCount);
      canvas.drawCircle(
        Offset(x, y),
        i.isEven ? 2.5 : 1.5,
        Paint()..color = color.withOpacity(opacity * 0.9 + 0.1),
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
//  BOTTLE ROW (difficulty indicator)
// ─────────────────────────────────────────────

class _BottleRow extends StatelessWidget {
  final LevelDifficulty difficulty;
  final bool isLocked;

  const _BottleRow({required this.difficulty, required this.isLocked});

  @override
  Widget build(BuildContext context) {
    final count = difficulty.bottleCount;
    final color =
        isLocked ? Colors.white.withOpacity(0.22) : difficulty.bottleColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) => _BottleIcon(color: color)),
    );
  }
}

class _BottleIcon extends StatelessWidget {
  final Color color;
  const _BottleIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: CustomPaint(
        size: const Size(6, 10),
        painter: _BottlePainter(color: color),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  final Color color;
  _BottlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Bottle neck
    final neck = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.3, 0, w * 0.4, h * 0.28),
      const Radius.circular(1),
    );
    canvas.drawRRect(neck, paint);

    // Bottle body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.3, w, h * 0.7),
      Radius.circular(w * 0.32),
    );
    canvas.drawRRect(body, paint);

    // Shine
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
//  HEX CLIPPER (for fog overlay)
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
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
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

  _HexBadgePainter({
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
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final hex = _hexPath(center, radius * 0.92);

    // Drop shadow / 3D depth
    final shadowPath = _hexPath(center.translate(0, 5), radius * 0.92);
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // 3D extrusion — bottom face
    final extrudeHex = _hexPath(center.translate(0, 6), radius * 0.92);
    canvas.drawPath(
      extrudeHex,
      Paint()..color = bottomColor.withOpacity(0.55),
    );

    // Main fill
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          colors: [topColor, bottomColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Inner bevel (dark edge)
    canvas.drawPath(
      hex,
      Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Outer rim glow
    canvas.drawPath(
      hex,
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );

    // Inner hex accent ring
    final innerHex = _hexPath(center, radius * 0.72);
    canvas.drawPath(
      innerHex,
      Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Top-left shine
    final shinePath = Path()
      ..moveTo(size.width * 0.22, size.height * 0.24)
      ..lineTo(size.width * 0.78, size.height * 0.24)
      ..lineTo(size.width * 0.66, size.height * 0.42)
      ..lineTo(size.width * 0.34, size.height * 0.42)
      ..close();

    canvas.drawPath(
      shinePath,
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
//  BRANCH MAP PAINTER (animated flow)
// ─────────────────────────────────────────────

class PremiumBranchMapPainter extends CustomPainter {
  final Map<int, Offset> positions;
  final Set<int> completedLevels;
  final Set<int> unlockedLevels;
  final double flowOffset; // 0..1

  PremiumBranchMapPainter({
    required this.positions,
    required this.completedLevels,
    required this.unlockedLevels,
    required this.flowOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const connections = [
      [1, 2],
      [1, 3],
      [2, 6],
      [2, 7],
      [3, 4],
      [3, 5],
      [4, 9],
      [5, 9],
      [6, 8],
      [7, 8],
      [8, 10],
      [9, 10],
    ];

    for (final conn in connections) {
      _drawConnection(canvas, size, conn[0], conn[1]);
    }
  }

  Path _buildPath(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final c1 = Offset(p1.dx + dx * 0.18, p1.dy + dy * 0.36);
    final c2 = Offset(p1.dx + dx * 0.82, p1.dy + dy * 0.64);
    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }

  void _drawConnection(Canvas canvas, Size size, int a, int b) {
    final p1 = positions[a]!;
    final p2 = positions[b]!;
    final isActive = completedLevels.contains(a) || unlockedLevels.contains(b);
    final path = _buildPath(p1, p2);

    // Shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 12 : 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Base stroke (inactive = faint dashes)
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

    // Active glow
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD500F9).withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Active gradient stroke
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: const [
            Color(0xFF7C4DFF),
            Color(0xFFF50057),
            Color(0xFFFF8A00),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Animated flowing dashes on top
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

    // Arrow dots at midpoints
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
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      final total = metric.length;
      final period = dashLen + gapLen;
      var start = offset * period * -1;
      while (start < total) {
        final end = (start + dashLen).clamp(0.0, total);
        if (start >= 0 && end > start) {
          canvas.drawPath(
            metric.extractPath(start, end),
            paint,
          );
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
  bool shouldRepaint(covariant PremiumBranchMapPainter old) =>
      old.positions != positions ||
      old.completedLevels != completedLevels ||
      old.unlockedLevels != unlockedLevels ||
      old.flowOffset != flowOffset;
}

// ─────────────────────────────────────────────
//  MAP STARS PAINTER (animated twinkle)
// ─────────────────────────────────────────────

class _MapStarsPainter extends CustomPainter {
  final double twinkle;
  _MapStarsPainter({required this.twinkle});

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
      final r = s[2] as double;

      canvas.drawCircle(
        Offset(size.width * s[0], size.height * s[1]),
        r,
        Paint()..color = Colors.white.withOpacity(opacity),
      );
      canvas.drawCircle(
        Offset(size.width * s[0], size.height * s[1]),
        r * 3.5,
        Paint()
          ..color = Colors.white.withOpacity(opacity * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_MapStarsPainter old) => old.twinkle != twinkle;
}

// ─────────────────────────────────────────────
//  FOG PAINTER
// ─────────────────────────────────────────────

class _FogPainter extends CustomPainter {
  final double t;
  _FogPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final drifts = [
      [0.0, 0.72, 0.55, 0.14, 0.0],
      [0.5, 0.85, 0.45, 0.10, 0.3],
      [0.8, 0.60, 0.50, 0.08, 0.6],
    ];

    for (final d in drifts) {
      final phase = d[4];
      final drift = sin((t + phase) * pi) * 12;
      final cx = size.width * d[0] + drift;
      final cy = size.height * d[1];
      final rx = size.width * d[2];
      final ry = size.height * d[3];
      final opacity = 0.04 + sin((t + phase) * pi).abs() * 0.05;

      final rect = Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 2, height: ry * 2);
      canvas.drawOval(
        rect,
        Paint()
          ..color = const Color(0xFF6A3AFF).withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }
  }

  @override
  bool shouldRepaint(_FogPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
//  MAP GLOW DECOR
// ─────────────────────────────────────────────

class _MapGlowDecor extends StatelessWidget {
  final Map<int, Offset> positions;
  const _MapGlowDecor({required this.positions});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _orb(positions[10]!.dx - 100, positions[10]!.dy - 130, 200,
          const Color(0xFFD500F9).withOpacity(0.11)),
      _orb(positions[5]!.dx - 120, positions[5]!.dy - 80, 180,
          const Color(0xFFFF6D00).withOpacity(0.09)),
      _orb(positions[8]!.dx - 80, positions[8]!.dy - 110, 170,
          const Color(0xFF2979FF).withOpacity(0.09)),
      _orb(positions[1]!.dx - 90, positions[1]!.dy - 90, 160,
          const Color(0xFF13F08B).withOpacity(0.07)),
    ]);
  }

  Widget _orb(double l, double t, double sz, Color c) {
    return Positioned(
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
}

// ─────────────────────────────────────────────
//  PREMIUM BACKGROUND
// ─────────────────────────────────────────────

class _PremiumMapBackground extends StatelessWidget {
  final AnimationController controller;
  const _PremiumMapBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF08050D),
              Color(0xFF12091A),
              Color(0xFF1A0B22),
              Color(0xFF08050D),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t = controller.value;
          return Stack(children: [
            _glow(-90 + sin(t * pi) * 20, -120 + cos(t * pi) * 15, 270,
                const Color(0xFFF50057).withOpacity(0.13)),
            _glow(
                MediaQuery.of(context).size.width - 170 + cos(t * pi) * 20,
                120 + sin(t * pi) * 18,
                250,
                const Color(0xFF2979FF).withOpacity(0.10)),
            _glow(
                -80 + sin(t * pi * 1.3) * 16,
                MediaQuery.of(context).size.height - 200 + cos(t * pi) * 20,
                260,
                const Color(0xFF00E676).withOpacity(0.08)),
            _glow(
                MediaQuery.of(context).size.width -
                    140 +
                    cos(t * pi * 1.2) * 18,
                MediaQuery.of(context).size.height - 180 + sin(t * pi) * 22,
                230,
                const Color(0xFFFF6D00).withOpacity(0.08)),
          ]);
        },
      ),
    ]);
  }

  Widget _glow(double l, double t, double sz, Color c) {
    return Positioned(
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
}

// ─────────────────────────────────────────────
//  GLASS BUTTON
// ─────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.11)),
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  COIN BADGE
// ─────────────────────────────────────────────

class _CoinBadge extends StatelessWidget {
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
        border: Border.all(color: Colors.white.withOpacity(0.11)),
      ),
      child: Row(children: const [
        Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD54F), size: 18),
        SizedBox(width: 6),
        Text('1250',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  TOP INFO CARD
// ─────────────────────────────────────────────

class _TopInfoCard extends StatelessWidget {
  final int completedCount;
  const _TopInfoCard({required this.completedCount});

  @override
  Widget build(BuildContext context) {
    final progress = completedCount / 10;

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
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFF50057), Color(0xFFFF6D00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.alt_route_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('İlerleme',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.60),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Dallanan yol haritası',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Stack(children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF50057), Color(0xFFFF8A00)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF50057).withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Text('$completedCount/10',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}
