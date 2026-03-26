import 'dart:math';
import 'package:flutter/material.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final completedLevels = <int>{
      1,
      // test:
      // 2, 3, 4, 5, 6, 7, 8, 9,
    };

    final unlocked = _computeUnlockedLevels(completedLevels);

    final levels = List.generate(10, (index) {
      final id = index + 1;
      return LevelNodeData(
        id: id,
        isCompleted: completedLevels.contains(id),
        isUnlocked: unlocked.contains(id),
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFF08050D),
      body: Stack(
        children: [
          const _PremiumMapBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _topButton(
                        icon: Icons.arrow_back_ios_new_rounded,
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
                              color: Colors.white.withOpacity(0.58),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _coinBadge(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                  child: _topInfoCard(completedLevels.length),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.06),
                                Colors.white.withOpacity(0.025),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.09),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.28),
                                blurRadius: 28,
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
                                      child: CustomPaint(
                                        painter: _MapStarsPainter(),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: PremiumBranchMapPainter(
                                          positions: positions,
                                          completedLevels: completedLevels,
                                          unlockedLevels: unlocked,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: _MapGlowDecor(
                                          positions: positions,
                                        ),
                                      ),
                                    ),
                                    for (final level in levels)
                                      Positioned(
                                        left: positions[level.id]!.dx - 39,
                                        top: positions[level.id]!.dy - 39,
                                        child: PremiumLevelNodeWidget(
                                          data: level,
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
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Set<int> _computeUnlockedLevels(Set<int> completed) {
    final unlocked = <int>{1};

    if (completed.contains(1)) {
      unlocked.addAll([2, 3]);
    }
    if (completed.contains(2)) {
      unlocked.addAll([6, 7]);
    }
    if (completed.contains(3)) {
      unlocked.addAll([4, 5]);
    }
    if (completed.contains(4) && completed.contains(5)) {
      unlocked.add(9);
    }
    if (completed.contains(6) && completed.contains(7)) {
      unlocked.add(8);
    }
    if (completed.contains(8) && completed.contains(9)) {
      unlocked.add(10);
    }

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

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.09),
              Colors.white.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _coinBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.09),
            Colors.white.withOpacity(0.04),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: const [
          Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFD54F),
            size: 18,
          ),
          SizedBox(width: 6),
          Text(
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

  Widget _topInfoCard(int completedCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.035),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF50057),
                  Color(0xFFFF6D00),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.alt_route_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlerleme',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Dallanan yol haritası',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: completedCount / 10,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFF50057),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$completedCount/10',
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

class LevelNodeData {
  final int id;
  final bool isCompleted;
  final bool isUnlocked;

  const LevelNodeData({
    required this.id,
    required this.isCompleted,
    required this.isUnlocked,
  });
}

class PremiumLevelNodeWidget extends StatelessWidget {
  final LevelNodeData data;

  const PremiumLevelNodeWidget({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = !data.isUnlocked;
    final isCompleted = data.isCompleted;
    final isCurrent = data.isUnlocked && !data.isCompleted;

    Color topColor;
    Color bottomColor;
    Color rimColor;
    Color glowColor;
    Color textColor = Colors.white;
    IconData? icon;

    if (isCompleted) {
      topColor = const Color(0xFF13F08B);
      bottomColor = const Color(0xFF0E9F5B);
      rimColor = const Color(0xFFB7FFD9).withOpacity(0.42);
      glowColor = const Color(0xFF12E07F);
      icon = Icons.check_rounded;
    } else if (isCurrent) {
      topColor = const Color(0xFFFF2E78);
      bottomColor = const Color(0xFFA11750);
      rimColor = const Color(0xFFFFB4CD).withOpacity(0.32);
      glowColor = const Color(0xFFF50057);
      icon = null;
    } else {
      topColor = const Color(0xFF4B425B);
      bottomColor = const Color(0xFF241F2F);
      rimColor = Colors.white.withOpacity(0.10);
      glowColor = const Color(0xFF433A52);
      textColor = Colors.white.withOpacity(0.78);
      icon = Icons.lock_rounded;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        if (!isLocked)
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glowColor.withOpacity(isCompleted ? 0.24 : 0.30),
                  glowColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        CustomPaint(
          size: const Size(78, 78),
          painter: _HexBadgePainter(
            topColor: topColor,
            bottomColor: bottomColor,
            rimColor: rimColor,
            isLocked: isLocked,
          ),
        ),
        Container(
          width: 78,
          height: 78,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  color: textColor,
                  size: isLocked ? 24 : 30,
                )
              : Text(
                  '${data.id}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
        Positioned(
          top: 15,
          child: Container(
            width: 28,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Positioned(
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF15101D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'SEVİYE ${data.id}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.84),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2;

    final hex = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * pi / 180;
      final x = center.dx + radius * cos(angle) * 0.92;
      final y = center.dy + radius * sin(angle) * 0.92;
      if (i == 0) {
        hex.moveTo(x, y);
      } else {
        hex.lineTo(x, y);
      }
    }
    hex.close();

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(isLocked ? 0.20 : 0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.save();
    canvas.translate(0, 6);
    canvas.drawPath(hex, shadowPaint);
    canvas.restore();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [topColor, bottomColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    final rimPaint = Paint()
      ..color = rimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final innerStroke = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(hex, fillPaint);
    canvas.drawPath(hex, rimPaint);

    final innerHex = Path();
    final innerRadius = radius * 0.74;
    for (int i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * pi / 180;
      final x = center.dx + innerRadius * cos(angle);
      final y = center.dy + innerRadius * sin(angle);
      if (i == 0) {
        innerHex.moveTo(x, y);
      } else {
        innerHex.lineTo(x, y);
      }
    }
    innerHex.close();

    canvas.drawPath(innerHex, innerStroke);

    final shinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.22),
          Colors.white.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.6));

    final shine = Path()
      ..moveTo(size.width * 0.22, size.height * 0.26)
      ..lineTo(size.width * 0.78, size.height * 0.26)
      ..lineTo(size.width * 0.66, size.height * 0.44)
      ..lineTo(size.width * 0.34, size.height * 0.44)
      ..close();

    canvas.drawPath(shine, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _HexBadgePainter oldDelegate) {
    return oldDelegate.topColor != topColor ||
        oldDelegate.bottomColor != bottomColor ||
        oldDelegate.rimColor != rimColor ||
        oldDelegate.isLocked != isLocked;
  }
}

class PremiumBranchMapPainter extends CustomPainter {
  final Map<int, Offset> positions;
  final Set<int> completedLevels;
  final Set<int> unlockedLevels;

  PremiumBranchMapPainter({
    required this.positions,
    required this.completedLevels,
    required this.unlockedLevels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void drawConnection(int a, int b) {
      final p1 = positions[a]!;
      final p2 = positions[b]!;

      final isPathActive =
          completedLevels.contains(a) || unlockedLevels.contains(b);

      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;

      final control1 = Offset(
        p1.dx + dx * 0.18,
        p1.dy + dy * 0.36,
      );
      final control2 = Offset(
        p1.dx + dx * 0.82,
        p1.dy - dy * -0.36,
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(
          control1.dx,
          control1.dy,
          control2.dx,
          control2.dy,
          p2.dx,
          p2.dy,
        );

      final glowPaint = Paint()
        ..color = (isPathActive
                ? const Color(0xFFD500F9)
                : Colors.white.withOpacity(0.08))
            .withOpacity(isPathActive ? 0.18 : 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPathActive ? 16 : 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: isPathActive
              ? [
                  const Color(0xFF7C4DFF),
                  const Color(0xFFF50057),
                  const Color(0xFFFF8A00),
                ]
              : [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.08),
                ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPathActive ? 4.2 : 2.0
        ..strokeCap = StrokeCap.round;

      final innerPaint = Paint()
        ..color = isPathActive
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
      canvas.drawPath(path, innerPaint);
    }

    drawConnection(1, 2);
    drawConnection(1, 3);

    drawConnection(2, 6);
    drawConnection(2, 7);

    drawConnection(3, 4);
    drawConnection(3, 5);

    drawConnection(4, 9);
    drawConnection(5, 9);

    drawConnection(6, 8);
    drawConnection(7, 8);

    drawConnection(8, 10);
    drawConnection(9, 10);

    for (final entry in positions.entries) {
      final p = entry.value;

      canvas.drawCircle(
        p,
        7,
        Paint()..color = Colors.white.withOpacity(0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PremiumBranchMapPainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.completedLevels != completedLevels ||
        oldDelegate.unlockedLevels != unlockedLevels;
  }
}

class _MapGlowDecor extends StatelessWidget {
  final Map<int, Offset> positions;

  const _MapGlowDecor({
    required this.positions,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _orb(
          left: positions[10]!.dx - 90,
          top: positions[10]!.dy - 120,
          size: 180,
          color: const Color(0xFFD500F9).withOpacity(0.10),
        ),
        _orb(
          left: positions[5]!.dx - 110,
          top: positions[5]!.dy - 70,
          size: 160,
          color: const Color(0xFFFF6D00).withOpacity(0.08),
        ),
        _orb(
          left: positions[8]!.dx - 70,
          top: positions[8]!.dy - 100,
          size: 150,
          color: const Color(0xFF2979FF).withOpacity(0.08),
        ),
      ],
    );
  }

  Widget _orb({
    required double left,
    required double top,
    required double size,
    required Color color,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stars = [
      Offset(size.width * 0.12, size.height * 0.14),
      Offset(size.width * 0.26, size.height * 0.18),
      Offset(size.width * 0.84, size.height * 0.17),
      Offset(size.width * 0.73, size.height * 0.40),
      Offset(size.width * 0.19, size.height * 0.46),
      Offset(size.width * 0.87, size.height * 0.62),
      Offset(size.width * 0.58, size.height * 0.79),
      Offset(size.width * 0.10, size.height * 0.82),
    ];

    for (int i = 0; i < stars.length; i++) {
      final r = i.isEven ? 2.2 : 1.5;
      canvas.drawCircle(
        stars[i],
        r,
        Paint()..color = Colors.white.withOpacity(0.20),
      );
      canvas.drawCircle(
        stars[i],
        r * 3.2,
        Paint()
          ..color = Colors.white.withOpacity(0.04)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapStarsPainter oldDelegate) => false;
}

class _PremiumMapBackground extends StatelessWidget {
  const _PremiumMapBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
        Positioned(
          top: -120,
          left: -90,
          child: _bigGlow(
            260,
            const Color(0xFFF50057).withOpacity(0.14),
          ),
        ),
        Positioned(
          top: 120,
          right: -70,
          child: _bigGlow(
            240,
            const Color(0xFF2979FF).withOpacity(0.10),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -80,
          child: _bigGlow(
            250,
            const Color(0xFF00E676).withOpacity(0.08),
          ),
        ),
        Positioned(
          bottom: 50,
          right: -80,
          child: _bigGlow(
            220,
            const Color(0xFFFF6D00).withOpacity(0.08),
          ),
        ),
      ],
    );
  }

  Widget _bigGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}
