import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'map_page.dart';
import 'daily_puzzle_page.dart';
import 'settings_page.dart';
import 'contact_page.dart';
import 'player_progress.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _buttonAnimations = [];
  late AnimationController _btnController;

  late final List<_Bubble> _bubbles =
      List.generate(20, (i) => _Bubble.random(i));

  @override
  void initState() {
    super.initState();
    _loadProgress();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    for (int i = 0; i < 4; i++) {
      _buttonAnimations.add(
        CurvedAnimation(
          parent: _btnController,
          curve: Interval(
            0.1 * i,
            0.1 * i + 0.6,
            curve: Curves.easeOutBack,
          ),
        ),
      );
    }
  }

  Future<void> _loadProgress() async {
    await PlayerProgress.ensureLoaded();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _btnController.dispose();
    super.dispose();
  }

  Future<void> _navigate(Widget page) async {
    await SettingsPage.vibrateTap();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0415),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              painter: OrbPainter(_controller.value),
              size: Size.infinite,
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final elapsed =
                  _controller.lastElapsedDuration?.inMilliseconds ?? 0;
              final timeSeconds = elapsed / 1000.0;

              return CustomPaint(
                painter: BubblePainter(timeSeconds, _bubbles),
                size: Size.infinite,
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Row(
                    children: [
                      CoinPill(),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/likora/likora_logo.png',
                        height: 52,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDot(const Color(0xFF2979FF), 0),
                          _buildDot(const Color(0xFF00E676), 1),
                          _buildDot(const Color(0xFFFFEA00), 2),
                          _buildDot(const Color(0xFFFF6D00), 3),
                          _buildDot(const Color(0xFFF50057), 4),
                          _buildDot(const Color(0xFFD500F9), 5),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildAnimatedButton(
                        index: 0,
                        child: _buildGradientButton(
                          label: "BAŞLA",
                          colors: [
                            const Color(0xFFF50057),
                            const Color(0xFFE94560),
                          ],
                          glowColor: const Color(0xFFF50057),
                          fontSize: 17,
                          verticalPad: 20,
                          onTap: () async => _navigate(MapPage()),
                        ),
                      ),
                      _buildAnimatedButton(
                        index: 1,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildGradientButton(
                              label: "GÜNLÜK BULMACA",
                              colors: [
                                const Color(0xFFFF6D00),
                                const Color(0xFFF5A623),
                              ],
                              glowColor: const Color(0xFFFF6D00),
                              onTap: () async => _navigate(DailyPuzzlePage()),
                            ),
                            Positioned(
                              top: -8,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFF5A623),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "YENİ",
                                  style: TextStyle(
                                    color: Color(0xFF3A1E00),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildAnimatedButton(
                        index: 2,
                        child: _buildGlassButton(
                          label: "AYARLAR",
                          onTap: () async => _navigate(SettingsPage()),
                        ),
                      ),
                      _buildAnimatedButton(
                        index: 3,
                        child: _buildPurpleButton(
                          label: "BİZE ULAŞIN",
                          onTap: () async => _navigate(ContactPage()),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    "v1.0.0 · Likora",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.18),
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _buttonAnimations[index],
      builder: (_, __) {
        final v = _buttonAnimations[index].value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildGradientButton({
    required String label,
    required List<Color> colors,
    required Color glowColor,
    double fontSize = 15,
    double verticalPad = 17,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 28),
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: verticalPad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.38),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({required String label, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 28),
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurpleButton({required String label, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 28),
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            color: const Color(0xFFD500F9).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: const Color(0xFFD500F9).withOpacity(0.22)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE0AAFF),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(Color color, int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final elapsed = _controller.lastElapsedDuration?.inMilliseconds ?? 0;
        final time = elapsed / 1000.0;

        final phase = (time * 4.0) + (index * pi / 3);
        final scale = 0.7 + 0.3 * sin(phase);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 6 * scale,
          height: 6 * scale,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.6), blurRadius: 6),
            ],
          ),
        );
      },
    );
  }
}

class OrbPainter extends CustomPainter {
  final double progress;
  OrbPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _Orb(dx: 0.0, dy: 0.05, color: const Color(0xFFFF1744), radius: 280),
      _Orb(dx: 1.0, dy: 0.2, color: const Color(0xFFFF6D00), radius: 260),
      _Orb(dx: 0.1, dy: 0.7, color: const Color(0xFF00E5FF), radius: 270),
      _Orb(dx: 0.95, dy: 0.85, color: const Color(0xFFD500F9), radius: 250),
      _Orb(dx: 0.5, dy: 0.45, color: const Color(0xFF00E676), radius: 220),
      _Orb(dx: 0.3, dy: 0.25, color: const Color(0xFFFFEA00), radius: 200),
    ];

    for (int i = 0; i < orbs.length; i++) {
      final o = orbs[i];
      final phase = progress * 2 * pi + i * 1.3;
      final dx = sin(phase) * 60;
      final dy = cos(phase * 0.7) * 60;
      final cx = o.dx * size.width + dx;
      final cy = o.dy * size.height + dy;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            o.color.withOpacity(0.72),
            o.color.withOpacity(0.18),
            o.color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: o.radius.toDouble()),
        );

      canvas.drawCircle(Offset(cx, cy), o.radius.toDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Orb {
  final double dx, dy;
  final Color color;
  final int radius;

  _Orb({
    required this.dx,
    required this.dy,
    required this.color,
    required this.radius,
  });
}

class BubblePainter extends CustomPainter {
  final double timeSeconds;
  final List<_Bubble> bubbles;

  BubblePainter(this.timeSeconds, this.bubbles);

  static const _colors = [
    Color(0xFF2979FF),
    Color(0xFF00E676),
    Color(0xFFFFEA00),
    Color(0xFFFF6D00),
    Color(0xFFF50057),
    Color(0xFFD500F9),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final localTime = timeSeconds + b.timeOffset;

      final t = (sin(localTime * b.verticalSpeed + b.wobble) + 1) / 2;

      final y = lerpDouble(
        b.maxYFactor * size.height,
        b.minYFactor * size.height,
        t,
      )!;

      final x = b.x * size.width +
          sin(localTime * b.horizontalSpeed + b.wobble) * b.horizontalRange;

      final pulse = 0.92 + 0.08 * sin(localTime * b.pulseSpeed + b.wobble);
      final radius = b.size * pulse;

      final color = _colors[b.colorIndex % _colors.length];

      final fillPaint = Paint()
        ..color = color.withOpacity(0.14)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = color.withOpacity(0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      canvas.drawCircle(Offset(x, y), radius, fillPaint);
      canvas.drawCircle(Offset(x, y), radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) => true;
}

class _Bubble {
  final double x;
  final double size;
  final double wobble;
  final int colorIndex;

  final double minYFactor;
  final double maxYFactor;

  final double verticalSpeed;
  final double horizontalSpeed;
  final double horizontalRange;

  final double timeOffset;
  final double pulseSpeed;

  _Bubble({
    required this.x,
    required this.size,
    required this.wobble,
    required this.colorIndex,
    required this.minYFactor,
    required this.maxYFactor,
    required this.verticalSpeed,
    required this.horizontalSpeed,
    required this.horizontalRange,
    required this.timeOffset,
    required this.pulseSpeed,
  });

  factory _Bubble.random(int seed) {
    final rnd = Random(seed);

    final minY = rnd.nextDouble() * 0.35;
    final maxY = 0.65 + rnd.nextDouble() * 0.30;

    return _Bubble(
      x: rnd.nextDouble(),
      size: rnd.nextDouble() * 14 + 4,
      wobble: rnd.nextDouble() * pi * 2,
      colorIndex: rnd.nextInt(7),
      minYFactor: minY,
      maxYFactor: maxY,
      verticalSpeed: 0.35 + rnd.nextDouble() * 0.45,
      horizontalSpeed: 0.45 + rnd.nextDouble() * 0.55,
      horizontalRange: 6 + rnd.nextDouble() * 10,
      timeOffset: rnd.nextDouble() * 30,
      pulseSpeed: 0.8 + rnd.nextDouble() * 1.0,
    );
  }
}
