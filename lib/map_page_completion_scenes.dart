import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class MapCompletionAmbientScene extends StatelessWidget {
  final int mapNumber;
  final bool intense;

  const MapCompletionAmbientScene({
    super.key,
    required this.mapNumber,
    this.intense = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (mapNumber) {
      case 1:
        return Map1CompletionScene(intense: intense);
      case 2:
        return Map2CompletionScene(intense: intense);
      case 3:
        return Map3CompletionScene(intense: intense);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP 1  –  Full-screen realistic storm scene
// Features:
//   • Full-screen dark sky gradient
//   • Multi-layered volumetric storm clouds built from dozens of overlapping
//     circles (dark cores + soft-lit edges + rim highlights)
//   • Realistic branching lightning with sub-branch forks, glow halos and
//     bright white core stroke – triggered by pseudo-random flash timers
//   • Rain streaks covering the whole screen (intense mode)
//   • Ground-level terrain silhouette so the scene fills top-to-bottom
// ─────────────────────────────────────────────────────────────────────────────

class Map1CompletionScene extends StatefulWidget {
  final bool intense;
  const Map1CompletionScene({super.key, required this.intense});

  @override
  State<Map1CompletionScene> createState() => _Map1CompletionSceneState();
}

class _Map1CompletionSceneState extends State<Map1CompletionScene>
    with TickerProviderStateMixin {
  late final AnimationController _loopCtrl;
  late final AnimationController _flashCtrl;
  final Random _rng = Random(42);

  // Pre-seeded cloud puffs so they don't change per frame
  late final List<_CloudPuff> _puffs;
  // Lightning bolt seeds – each bolt has a fixed x-position seed
  late final List<double> _boltSeeds;

  @override
  void initState() {
    super.initState();
    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Build cloud puffs
    _puffs = [];
    final cloudCount = widget.intense ? 38 : 24;
    for (int i = 0; i < cloudCount; i++) {
      _puffs.add(_CloudPuff(
        xFrac: _rng.nextDouble(),
        yFrac: _rng.nextDouble() *
            0.28, // top 28 % of screen (merge with cloud band)
        radiusFrac: 0.07 + _rng.nextDouble() * 0.14,
        layer: i % 3, // 0 = back, 1 = mid, 2 = front
        speedX: ((_rng.nextDouble() - 0.5) * 0.006),
        phaseOffset: _rng.nextDouble() * pi * 2,
      ));
    }

    final boltCount = widget.intense ? 5 : 2;
    _boltSeeds = List.generate(boltCount, (i) => _rng.nextDouble());
  }

  @override
  void dispose() {
    _loopCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_loopCtrl, _flashCtrl]),
      builder: (_, __) => CustomPaint(
        painter: _Map1CompletionPainter(
          t: _loopCtrl.value,
          flash: _flashCtrl.value,
          intense: widget.intense,
          puffs: _puffs,
          boltSeeds: _boltSeeds,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

class _CloudPuff {
  final double xFrac;
  final double yFrac;
  final double radiusFrac;
  final int layer; // 0,1,2
  final double speedX;
  final double phaseOffset;
  const _CloudPuff({
    required this.xFrac,
    required this.yFrac,
    required this.radiusFrac,
    required this.layer,
    required this.speedX,
    required this.phaseOffset,
  });
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _Map1CompletionPainter extends CustomPainter {
  final double t; // 0..1 looping
  final double flash; // 0..1 for lightning flash brightness
  final bool intense;
  final List<_CloudPuff> puffs;
  final List<double> boltSeeds; // x-position fractions for each bolt

  const _Map1CompletionPainter({
    required this.t,
    required this.flash,
    required this.intense,
    required this.puffs,
    required this.boltSeeds,
  });

  // ── helpers ──

  /// Deterministic "random" float from two seeds (no dart:math Random needed)
  double _hash(double a, double b) {
    final v = sin(a * 127.1 + b * 311.7) * 43758.5453123;
    return v - v.floor();
  }

  /// Build a single lightning bolt path with branching.
  /// [seed] controls horizontal position, [phase] controls when it fires.
  (Path main, List<Path> branches) _buildBolt(
    double startX,
    double startY,
    double endY,
    double seed,
    double tLocal, // local time 0..1
  ) {
    const segments = 12;
    final segH = (endY - startY) / segments;
    final main = Path()..moveTo(startX, startY);
    final branches = <Path>[];

    double cx = startX;
    final pts = <Offset>[Offset(startX, startY)];

    for (int s = 0; s < segments; s++) {
      final ny = startY + segH * (s + 1);
      final jitter = (_hash(seed + s * 0.37, tLocal * 3.1) - 0.5) * 40.0;
      final nx = cx + jitter;
      main.lineTo(nx, ny);
      pts.add(Offset(nx, ny));
      cx = nx;

      // Spawn sub-branch roughly every 3 segments
      if (s > 1 && s % 3 == 0 && _hash(seed * 2.1, s.toDouble()) > 0.45) {
        final branchPts = 4;
        final bPath = Path()..moveTo(nx, ny);
        double bx = nx;
        final dir = (_hash(seed, s + 11.0) > 0.5) ? 1 : -1;
        for (int b = 0; b < branchPts; b++) {
          final bny = ny + segH * (b + 1) * 0.55;
          final bnx = bx + dir * (_hash(seed + b * 1.7, s * 0.9) * 18 + 6);
          bPath.lineTo(bnx, bny);
          bx = bnx;
        }
        branches.add(bPath);
      }
    }

    return (main, branches);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final skyRect = Offset.zero & size;

    // ── 1. Lightning flash bloom – very subtle, top-only glow only
    final flashPulse = intense
        ? max(0.0, sin(flash * pi * 3)) * 0.14
        : max(0.0, sin(flash * pi * 1.6)) * 0.05;

    if (flashPulse > 0.01) {
      final topGlowRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.28);
      canvas.drawRect(
        topGlowRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFBB88FF).withValues(alpha: flashPulse * 0.9),
              const Color(0xFF7733BB).withValues(alpha: flashPulse * 0.2),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(topGlowRect),
      );
    }

    // ── 2. Dense storm cloud band at the very top (where lightning originates)
    _drawTopCloudBand(canvas, size, flashPulse);

    // ── 3. Volumetric storm clouds ─────────────────────────────────────────
    // Draw back-layer first, then mid, then front
    for (int layer = 0; layer < 3; layer++) {
      for (final p in puffs) {
        if (p.layer != layer) continue;

        // Animated x drift
        final animX = (p.xFrac + t * p.speedX * 10) % 1.2 - 0.1;
        final animY = p.yFrac + sin(t * pi * 2 + p.phaseOffset) * 0.008;

        final cx = animX * size.width;
        final cy = animY * size.height;
        final r = p.radiusFrac * size.width;

        // Layer-dependent colors
        final double baseAlpha;
        final Color darkColor;
        final Color midColor;
        final Color rimColor;
        switch (layer) {
          case 0: // back – darkest, bluish
            baseAlpha = intense ? 0.38 : 0.26;
            darkColor = const Color(0xFF0C0418);
            midColor = const Color(0xFF1D0A32);
            rimColor = const Color(0xFF3D1A5C);
          case 1: // mid
            baseAlpha = intense ? 0.52 : 0.38;
            darkColor = const Color(0xFF100620);
            midColor = const Color(0xFF251048);
            rimColor = const Color(0xFF5428A0);
          default: // front – largest, purple-lit edges
            baseAlpha = intense ? 0.68 : 0.50;
            darkColor = const Color(0xFF160830);
            midColor = const Color(0xFF2A1355);
            rimColor = const Color(0xFF7B44CC);
        }

        // Dark core
        canvas.drawCircle(
          Offset(cx, cy),
          r,
          Paint()
            ..color = darkColor.withValues(alpha: baseAlpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
        );

        // Mid-tone body
        canvas.drawCircle(
          Offset(cx + r * 0.12, cy - r * 0.08),
          r * 0.78,
          Paint()
            ..color = midColor.withValues(alpha: baseAlpha * 0.85)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
        );

        // Rim / edge highlight (lightning-lit)
        final rimBoost = flashPulse * 1.2;
        canvas.drawCircle(
          Offset(cx - r * 0.25, cy + r * 0.15),
          r * 0.52,
          Paint()
            ..color = rimColor.withValues(
                alpha: (baseAlpha * 0.30 + rimBoost).clamp(0, 1))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.28),
        );

        // Top highlight catch-light
        canvas.drawCircle(
          Offset(cx + r * 0.08, cy - r * 0.38),
          r * 0.24,
          Paint()
            ..color = const Color(0xFF9966DD)
                .withValues(alpha: (0.08 + rimBoost * 0.6).clamp(0, 0.5))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
        );
      }
    }

    // ── 4. Rain streaks – full screen top to bottom ────────────────────────
    {
      final int rainCount = intense ? 110 : 40;
      final double streakLen = intense ? 22.0 : 14.0;
      final double speed = intense ? 1.6 : 1.1;
      final double opacity = intense ? 0.20 : 0.11;

      for (int i = 0; i < rainCount; i++) {
        final rx = _hash(i * 1.37, 99.0) * size.width;
        final ryBase = (_hash(i * 2.71, 5.0) + t * speed) % 1.0;
        // map 0..1 → -streakLen .. size.height+streakLen so drops enter top and exit bottom
        final ry = ryBase * (size.height + streakLen * 2) - streakLen;
        canvas.drawLine(
          Offset(rx - 1.5, ry),
          Offset(rx + 1.5, ry + streakLen),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = intense ? 0.9 : 0.7
            ..color = const Color(0xFFCCBBEE).withValues(alpha: opacity)
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── 5. Lightning bolts ─────────────────────────────────────────────────
    final boltCount = boltSeeds.length;
    for (int i = 0; i < boltCount; i++) {
      final seed = boltSeeds[i];
      // Each bolt fires at a staggered phase
      final phase = (t * (intense ? 2.8 : 1.4) + seed) % 1.0;
      // Active window – bolt is visible for ~20% of its cycle
      final active = phase < 0.22;
      if (!active) continue;

      final lifeProgress = phase / 0.22; // 0..1 within active window
      // Fade in fast, hold, then fade out
      final alpha = lifeProgress < 0.15
          ? (lifeProgress / 0.15)
          : (1.0 - ((lifeProgress - 0.15) / 0.85));
      final boltAlpha = (alpha * (intense ? 0.95 : 0.70)).clamp(0.0, 1.0);

      if (boltAlpha < 0.02) continue;

      final startX = size.width * (0.1 + seed * 0.80);
      final startY = size.height * (0.02 + _hash(seed, i.toDouble()) * 0.18);
      // Some bolts reach the very bottom, some cut short mid-screen
      final cutShort = _hash(seed * 3.7, i * 1.3 + 5.0) > 0.55;
      final endY = cutShort
          ? size.height * (0.38 + _hash(seed * 1.9, i * 2.1) * 0.32)
          : size.height * (0.90 + _hash(seed * 2.3, i.toDouble()) * 0.10);

      final (mainPath, branches) =
          _buildBolt(startX, startY, endY, seed, phase);

      // — Outer glow halo —
      canvas.drawPath(
        mainPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = intense ? 18.0 : 12.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF9955FF).withValues(alpha: boltAlpha * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      // — Mid glow —
      canvas.drawPath(
        mainPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = intense ? 7.0 : 4.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFCC88FF).withValues(alpha: boltAlpha * 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, intense ? 5 : 3),
      );

      // — Bright core —
      canvas.drawPath(
        mainPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = intense ? 2.0 : 1.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFFFFF).withValues(alpha: boltAlpha),
      );

      // — Sub-branches —
      for (final branch in branches) {
        canvas.drawPath(
          branch,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = intense ? 3.5 : 2.2
            ..strokeCap = StrokeCap.round
            ..color =
                const Color(0xFFBB77FF).withValues(alpha: boltAlpha * 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawPath(
          branch,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = intense ? 1.0 : 0.7
            ..strokeCap = StrokeCap.round
            ..color =
                const Color(0xFFFFFFFF).withValues(alpha: boltAlpha * 0.75),
        );
      }

      // — Strike point radial glow at bottom of bolt —
      final strikeCenter = Offset(startX, endY);
      final strikeRadius = intense ? 80.0 : 50.0;
      final strikeRect =
          Rect.fromCircle(center: strikeCenter, radius: strikeRadius);
      canvas.drawOval(
        strikeRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFDD99FF).withValues(alpha: boltAlpha * 0.35),
              const Color(0xFF7733BB).withValues(alpha: boltAlpha * 0.12),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(strikeRect),
      );
    }
  }

  /// Draws a thick, dense storm cloud mass anchored to the very top of the screen.
  /// This is where all lightning bolts originate, giving them a realistic source.
  void _drawTopCloudBand(Canvas canvas, Size size, double flashBoost) {
    // Cloud band occupies roughly top 10% of the screen
    final bandHeight = size.height * 0.10;

    // ── Base dark fill – fills from top edge downward with a soft bottom fade
    final baseFillRect = Rect.fromLTWH(0, 0, size.width, bandHeight * 1.4);
    canvas.drawRect(
      baseFillRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0318).withValues(alpha: 0.97),
            const Color(0xFF130828).withValues(alpha: 0.88),
            const Color(0xFF1A0A30).withValues(alpha: 0.60),
            Colors.transparent,
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(baseFillRect),
    );

    // ── Cloud puff seeds (deterministic, won't change per frame)
    // These are fixed layout seeds – x, y, radius all as fractions of screen
    const cloudSeeds = [
      // [xFrac, yTopFrac, rFrac, layer(0-2)]
      [0.00, 0.00, 0.28, 2],
      [0.18, 0.00, 0.22, 1],
      [0.38, 0.00, 0.30, 2],
      [0.58, 0.00, 0.26, 2],
      [0.78, 0.00, 0.24, 1],
      [0.92, 0.00, 0.20, 2],
      // second sub-row
      [0.08, 0.03, 0.20, 1],
      [0.26, 0.03, 0.22, 0],
      [0.46, 0.03, 0.25, 1],
      [0.66, 0.03, 0.20, 0],
      [0.84, 0.03, 0.22, 1],
      // third sub-row – bottom fringe of cloud mass
      [0.05, 0.05, 0.16, 0],
      [0.20, 0.05, 0.18, 1],
      [0.36, 0.05, 0.15, 0],
      [0.52, 0.05, 0.17, 1],
      [0.68, 0.05, 0.16, 0],
      [0.82, 0.05, 0.14, 1],
      [0.96, 0.05, 0.12, 0],
      // filler blobs to fill any gaps
      [0.50, 0.00, 0.20, 2],
      [0.12, 0.03, 0.18, 1],
      [0.72, 0.03, 0.19, 2],
      [0.32, 0.03, 0.21, 2],
      [0.62, 0.03, 0.18, 1],
      [0.88, 0.03, 0.17, 0],
    ];

    for (final seed in cloudSeeds) {
      final cx = seed[0] * size.width;
      final cyFrac = seed[1]; // y as fraction of bandHeight
      final cy = cyFrac * bandHeight;
      final r = seed[2] * size.width * 0.55; // radius relative to width
      final int layer = seed[3].toInt();

      // Drift animation – slow horizontal drift using t
      final driftedCx = (cx +
                  t *
                      (layer == 2
                          ? 12
                          : layer == 1
                              ? 8
                              : 5)) %
              (size.width + r * 2) -
          r;

      final double baseAlpha;
      final Color darkC;
      final Color midC;
      final Color rimC;

      switch (layer) {
        case 0: // back – darkest, blueish
          baseAlpha = intense ? 0.55 : 0.42;
          darkC = const Color(0xFF060210);
          midC = const Color(0xFF0E0620);
          rimC = const Color(0xFF2A1250);
        case 1: // mid
          baseAlpha = intense ? 0.68 : 0.54;
          darkC = const Color(0xFF0A0418);
          midC = const Color(0xFF180A30);
          rimC = const Color(0xFF3E1A70);
        default: // front – brightest edges, purple lightning-lit
          baseAlpha = intense ? 0.80 : 0.65;
          darkC = const Color(0xFF0E051E);
          midC = const Color(0xFF200C3C);
          rimC = const Color(0xFF5E28A8);
      }

      // Dark core fill
      canvas.drawCircle(
        Offset(driftedCx, cy),
        r,
        Paint()
          ..color = darkC.withValues(alpha: baseAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.30),
      );

      // Mid-tone body
      canvas.drawCircle(
        Offset(driftedCx + r * 0.10, cy - r * 0.07),
        r * 0.76,
        Paint()
          ..color = midC.withValues(alpha: baseAlpha * 0.88)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.20),
      );

      // Rim highlight (brightens during lightning flash)
      final rimAlpha = (baseAlpha * 0.32 + flashBoost * 1.4).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(driftedCx - r * 0.22, cy + r * 0.12),
        r * 0.50,
        Paint()
          ..color = rimC.withValues(alpha: rimAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.26),
      );

      // Top catch-light
      canvas.drawCircle(
        Offset(driftedCx + r * 0.06, cy - r * 0.34),
        r * 0.22,
        Paint()
          ..color = const Color(0xFF8855CC)
              .withValues(alpha: (0.06 + flashBoost * 0.7).clamp(0.0, 0.55))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.14),
      );
    }

    // ── Bottom edge feathering – a gradient that blends the cloud band into
    //    the rest of the scene without a hard edge
    final featherRect =
        Rect.fromLTWH(0, bandHeight * 0.40, size.width, bandHeight * 0.70);
    canvas.drawRect(
      featherRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF08021A).withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(featherRect),
    );
  }

  @override
  bool shouldRepaint(covariant _Map1CompletionPainter old) => true;
}

class Map2CompletionScene extends StatefulWidget {
  final bool intense;

  const Map2CompletionScene({super.key, required this.intense});

  @override
  State<Map2CompletionScene> createState() => _Map2CompletionSceneState();
}

class _Map2CompletionSceneState extends State<Map2CompletionScene>
    with TickerProviderStateMixin {
  // Continuous loop for waves / fish movement
  late final AnimationController _flowCtrl;
  // Fill animation – slow rise like a room filling with liquid
  AnimationController? _introCtrl;

  @override
  void initState() {
    super.initState();
    _flowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Her iki modda da alttan yukarı dolma animasyonu başlat
    // intense = 5.2 sn (aksiyon), normal = 4.0 sn (sabit)
    _introCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.intense ? 5200 : 4000),
    )..forward();
  }

  @override
  void dispose() {
    _flowCtrl.dispose();
    _introCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_flowCtrl, if (_introCtrl != null) _introCtrl!]),
      builder: (_, __) => CustomPaint(
        painter: _Map2CompletionPainter(
          t: _flowCtrl.value,
          intense: widget.intense,
          fillProgress: _introCtrl?.value ?? 0.0,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Map2CompletionPainter extends CustomPainter {
  final double t; // 0..1 looping, for waves & fish
  final bool intense;
  final double fillProgress; // 0..1 intro fill

  const _Map2CompletionPainter({
    required this.t,
    required this.intense,
    required this.fillProgress,
  });

  // ── Surface wave helper ──────────────────────────────────────────────────
  // Returns the Y coordinate of the water surface at horizontal position x,
  // given a base topY, current time t, sloshing amplitude and wave phase.
  double _surfaceY(double x, double w, double topY, double sloshAmp,
      double sloshPhase, double waveAmp) {
    // Primary slosh: full-width tilt – water piles up on one side
    final tilt = sin(sloshPhase) * sloshAmp * ((x / w) * 2 - 1);
    // Secondary ripple waves
    final ripple1 = sin(x / w * pi * 2 + t * pi * 4) * waveAmp * 0.5;
    final ripple2 = sin(x / w * pi * 3.7 - t * pi * 3) * waveAmp * 0.3;
    return topY + tilt + ripple1 + ripple2;
  }

  // Builds a filled water path using many vertical segments for a smooth curve
  Path _buildWaterPath(Size size, double topY, double sloshAmp,
      double sloshPhase, double waveAmp) {
    const steps = 60;
    final path = Path()..moveTo(0, size.height);
    path.lineTo(
        0, _surfaceY(0, size.width, topY, sloshAmp, sloshPhase, waveAmp));
    for (int i = 1; i <= steps; i++) {
      final x = size.width * i / steps;
      path.lineTo(
          x, _surfaceY(x, size.width, topY, sloshAmp, sloshPhase, waveAmp));
    }
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  // Same but stroke-only (surface line)
  Path _buildSurfacePath(Size size, double topY, double sloshAmp,
      double sloshPhase, double waveAmp) {
    const steps = 60;
    final path = Path();
    path.moveTo(
        0, _surfaceY(0, size.width, topY, sloshAmp, sloshPhase, waveAmp));
    for (int i = 1; i <= steps; i++) {
      final x = size.width * i / steps;
      path.lineTo(
          x, _surfaceY(x, size.width, topY, sloshAmp, sloshPhase, waveAmp));
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── Fill level ────────────────────────────────────────────────────────
    // Use a custom easing: slow rise with slight deceleration near top
    final easedFill =
        Curves.easeInOutSine.transform(fillProgress.clamp(0.0, 1.0));
    // Her iki modda da alttan yukarı yavaşça dolar, hedef: tam dolu (1.0)
    const targetLevel = 1.0;
    final waterLevel = lerpDouble(0.0, targetLevel, easedFill)!;
    final topY = size.height * (1.0 - waterLevel);

    // ── Sloshing dynamics ─────────────────────────────────────────────────
    // During fill: large pendulum slosh that damps out as fill completes.
    // After fill: gentle rocking.
    final fillDone = fillProgress >= 0.98;
    // Slosh phase oscillates faster while filling, then slows
    final sloshFreq = fillDone ? 1.2 : 2.4;
    final sloshPhase = t * pi * 2 * sloshFreq;
    // Slosh amplitude: large while filling (water hits walls), tiny when full
    final sloshAmp = intense
        ? lerpDouble(size.width * 0.06, size.width * 0.02,
            Curves.easeOut.transform(fillProgress.clamp(0.0, 1.0)))!
        : size.width * 0.01;
    // Surface ripple amplitude
    final waveAmp = intense
        ? lerpDouble(
            14.0, 4.0, Curves.easeOut.transform(fillProgress.clamp(0.0, 1.0)))!
        : 5.0;

    // ── Clip canvas to prevent water from drawing outside screen top ──────
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // ── Background glow beneath surface ──────────────────────────────────
    if (waterLevel > 0.05) {
      final glowTop = topY;
      final glowRect = Rect.fromLTWH(0, glowTop.clamp(0.0, size.height),
          size.width, size.height - glowTop.clamp(0.0, size.height));
      if (glowRect.height > 0) {
        canvas.drawRect(
          glowRect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                const Color(0xFF1A6EA8).withValues(alpha: 0.08),
                const Color(0xFF083A5D).withValues(alpha: 0.14),
              ],
            ).createShader(glowRect),
        );
      }
    }

    // ── Water body ────────────────────────────────────────────────────────
    final waterPath =
        _buildWaterPath(size, topY, sloshAmp, sloshPhase, waveAmp);
    final waterRect =
        Rect.fromLTRB(0, topY.clamp(0.0, size.height), size.width, size.height);

    canvas.drawPath(
      waterPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF8FD8F8).withValues(alpha: intense ? 0.32 : 0.20),
            const Color(0xFF2CA0E8).withValues(alpha: intense ? 0.42 : 0.30),
            const Color(0xFF0D6BA8).withValues(alpha: intense ? 0.56 : 0.40),
            const Color(0xFF052B4A).withValues(alpha: intense ? 0.72 : 0.52),
          ],
          stops: const [0.0, 0.15, 0.50, 1.0],
        ).createShader(waterRect),
    );

    // ── Subsurface depth layers (gives volumetric look) ───────────────────
    if (intense && waterLevel > 0.15) {
      // A slightly darker mid-depth band
      final midY = topY + (size.height - topY) * 0.35;
      final midRect =
          Rect.fromLTWH(0, midY, size.width, (size.height - midY) * 0.5);
      canvas.drawRect(
        midRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF073858).withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(midRect),
      );
    }

    // ── Surface foam / highlight line ─────────────────────────────────────
    final surfacePath =
        _buildSurfacePath(size, topY, sloshAmp, sloshPhase, waveAmp);
    canvas.drawPath(
      surfacePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = intense ? 2.8 : 2.0
        ..color =
            const Color(0xFFE0F8FF).withValues(alpha: intense ? 0.65 : 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    // Thinner bright core on surface
    canvas.drawPath(
      surfacePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: intense ? 0.50 : 0.30),
    );

    // ── Foam bubbles at walls during sloshing fill ────────────────────────
    if (intense && !fillDone && fillProgress > 0.05) {
      final foamAlpha = (1.0 - fillProgress).clamp(0.0, 1.0) * 0.55;
      for (int side = 0; side < 2; side++) {
        final wallX = side == 0 ? 8.0 : size.width - 8.0;
        for (int b = 0; b < 5; b++) {
          final bx =
              wallX + sin(t * pi * 3 + b * 1.3) * (side == 0 ? 6.0 : -6.0);
          final by = topY + 10 + b * 14.0 + sin(t * pi * 2 + b * 0.7) * 8;
          if (by > size.height) continue;
          canvas.drawCircle(
            Offset(bx, by),
            2.5 + b * 0.8,
            Paint()
              ..color = const Color(0xFFCCEEFF).withValues(alpha: foamAlpha),
          );
        }
      }
    }

    // ── Fish ──────────────────────────────────────────────────────────────
    // intense: 4 fish in the middle zone of the screen (0.30 – 0.65 height)
    // normal : 2 fish near bottom
    if (intense) {
      if (waterLevel > 0.55) {
        // Fish data: [xBase(0..1), yBase(0..1 of screen), speedMult, phase, goRight]
        const fishData = [
          [0.18, 0.42, 1.0, 0.0, 1.0],
          [0.65, 0.52, 0.75, 1.8, 0.0],
          [0.38, 0.60, 1.2, 3.5, 1.0],
          [0.80, 0.37, 0.9, 5.1, 0.0],
        ];
        final fishAlpha = ((waterLevel - 0.55) / 0.15).clamp(0.0, 1.0);
        for (final fd in fishData) {
          final xBase = fd[0] as double;
          final yBase = fd[1] as double;
          final speed = fd[2] as double;
          final phase = fd[3] as double;
          final goRight = (fd[4] as double) > 0.5;

          // Fish swim back and forth within their lane
          final fx = size.width * xBase +
              sin(t * pi * 2 * speed + phase) * size.width * 0.22;
          final fy = size.height * yBase +
              sin(t * pi * 2 * speed * 0.6 + phase + 1.1) * 14;

          // Only draw fish if they are below the water surface
          final surfY =
              _surfaceY(fx, size.width, topY, sloshAmp, sloshPhase, waveAmp);
          if (fy > surfY + 8) {
            _drawFish(canvas, Offset(fx, fy), goRight, fishAlpha);
          }
        }
      }
    } else {
      // Normal (sabit) modda 5 balık — su %70+ dolunca belirmeye başlar
      if (waterLevel > 0.50) {
        final fishAlpha = ((waterLevel - 0.50) / 0.25).clamp(0.0, 1.0);
        const normalFishData = [
          [0.15, 0.30, 1.0, 0.0, 1.0],
          [0.70, 0.45, 0.80, 1.8, 0.0],
          [0.40, 0.60, 1.1, 3.2, 1.0],
          [0.82, 0.25, 0.90, 4.7, 0.0],
          [0.28, 0.75, 0.70, 2.5, 1.0],
        ];
        for (int i = 0; i < normalFishData.length; i++) {
          final fd = normalFishData[i];
          final xBase = fd[0] as double;
          final yBase = fd[1] as double;
          final speed = fd[2] as double;
          final phase = fd[3] as double;
          final goRight = (fd[4] as double) > 0.5;
          final fx = size.width * xBase +
              sin(t * pi * 2 * speed + phase) * size.width * 0.18;
          final fy = size.height * yBase +
              sin(t * pi * 2 * speed * 0.6 + phase + 1.1) * 12;
          _drawFish(canvas, Offset(fx, fy), goRight, fishAlpha);
        }
      }
    }

    canvas.restore();
  }

  void _drawFish(Canvas canvas, Offset c, bool right, double alpha) {
    final body = Path()
      ..moveTo(c.dx - 12, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - 8, c.dx + 14, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + 8, c.dx - 12, c.dy)
      ..close();
    final tail = Path()
      ..moveTo(c.dx - 12, c.dy)
      ..lineTo(c.dx - 21, c.dy - 6)
      ..lineTo(c.dx - 21, c.dy + 6)
      ..close();
    // Fin
    final fin = Path()
      ..moveTo(c.dx - 2, c.dy - 8)
      ..quadraticBezierTo(c.dx + 3, c.dy - 14, c.dx + 8, c.dy - 8);

    canvas.save();
    if (!right) {
      canvas.translate(c.dx, c.dy);
      canvas.scale(-1, 1);
      canvas.translate(-c.dx, -c.dy);
    }
    canvas.drawPath(
        body,
        Paint()
          ..color = const Color(0xFF90D8F8).withValues(alpha: 0.58 * alpha));
    canvas.drawPath(
        tail,
        Paint()
          ..color = const Color(0xFF5CB8E8).withValues(alpha: 0.52 * alpha));
    canvas.drawPath(
        fin,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFB0E8FF).withValues(alpha: 0.45 * alpha));
    // Eye
    canvas.drawCircle(Offset(c.dx + 7, c.dy - 1.5), 1.6,
        Paint()..color = Colors.white.withValues(alpha: 0.75 * alpha));
    canvas.drawCircle(
        Offset(c.dx + 7.4, c.dy - 1.5),
        0.7,
        Paint()
          ..color = const Color(0xFF003355).withValues(alpha: 0.85 * alpha));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Map2CompletionPainter oldDelegate) => true;
}

class Map3CompletionScene extends StatefulWidget {
  final bool intense;

  const Map3CompletionScene({super.key, required this.intense});

  @override
  State<Map3CompletionScene> createState() => _Map3CompletionSceneState();
}

class _Map3CompletionSceneState extends State<Map3CompletionScene>
    with TickerProviderStateMixin {
  late final AnimationController _loopCtrl;
  AnimationController? _introCtrl;

  @override
  void initState() {
    super.initState();
    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    if (widget.intense) {
      _introCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..forward();
    }
  }

  @override
  void dispose() {
    _loopCtrl.dispose();
    _introCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_loopCtrl, if (_introCtrl != null) _introCtrl!]),
      builder: (_, __) => CustomPaint(
        painter: _Map3CompletionPainter(
          t: _loopCtrl.value,
          intense: widget.intense,
          intro: widget.intense ? (_introCtrl?.value ?? 0.0) : 1.0,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Map3CompletionPainter extends CustomPainter {
  final double t;
  final bool intense;
  final double intro;

  const _Map3CompletionPainter(
      {required this.t, required this.intense, required this.intro});

  @override
  void paint(Canvas canvas, Size size) {
    final introCurve = Curves.easeOutBack.transform(intro.clamp(0.0, 1.0));
    final rise = intense ? lerpDouble(size.height * 0.34, 0, introCurve)! : 0.0;
    final shake = intense ? sin(t * pi * 20) * (1 - introCurve) * 6 : 0.0;

    final mountainRect = Rect.fromLTWH(
      size.width * 0.26 + shake,
      size.height * 0.50 + rise,
      size.width * 0.48,
      size.height * 0.38,
    );

    final mountainPath = Path()
      ..moveTo(mountainRect.left, mountainRect.bottom)
      ..quadraticBezierTo(
        mountainRect.left + mountainRect.width * 0.18,
        mountainRect.top + mountainRect.height * 0.42,
        mountainRect.left + mountainRect.width * 0.34,
        mountainRect.top + mountainRect.height * 0.10,
      )
      ..lineTo(mountainRect.left + mountainRect.width * 0.44,
          mountainRect.top + mountainRect.height * 0.18)
      ..lineTo(mountainRect.left + mountainRect.width * 0.56,
          mountainRect.top + mountainRect.height * 0.18)
      ..quadraticBezierTo(
        mountainRect.left + mountainRect.width * 0.72,
        mountainRect.top + mountainRect.height * 0.10,
        mountainRect.right,
        mountainRect.bottom,
      )
      ..close();

    canvas.drawPath(
      mountainPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF5A2317).withValues(alpha: 0.76),
            const Color(0xFF3C150E).withValues(alpha: 0.92),
            const Color(0xFF1A0906).withValues(alpha: 0.98),
          ],
        ).createShader(mountainRect),
    );

    final craterCenter = Offset(
        mountainRect.center.dx, mountainRect.top + mountainRect.height * 0.18);
    canvas.drawCircle(
      craterCenter,
      intense ? 20 : 14,
      Paint()
        ..color =
            const Color(0xFFFF6A00).withValues(alpha: intense ? 0.18 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    if (intense) {
      final burst = max(0.0, sin(t * pi * 6));
      for (int i = 0; i < 10; i++) {
        final x = craterCenter.dx + (i - 4.5) * 8;
        final h = 28 + (i % 3) * 10 + burst * 28;
        final path = Path()
          ..moveTo(x - 3, craterCenter.dy)
          ..quadraticBezierTo(
              x - 8, craterCenter.dy - h * 0.45, x, craterCenter.dy - h)
          ..quadraticBezierTo(
              x + 8, craterCenter.dy - h * 0.45, x + 3, craterCenter.dy)
          ..close();
        final r = Rect.fromLTRB(
            x - 10, craterCenter.dy - h, x + 10, craterCenter.dy + 4);
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFFFF0A6).withValues(alpha: 0.72),
                const Color(0xFFFFB300).withValues(alpha: 0.62),
                const Color(0xFFFF5B00).withValues(alpha: 0.28),
              ],
            ).createShader(r)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    } else {
      final puff = max(0.0, sin(t * pi * 2));
      for (int i = 0; i < 3; i++) {
        final c = Offset(craterCenter.dx + (i - 1) * 12,
            craterCenter.dy - 12 - puff * 10 - i * 8);
        final r = 12 + i * 5 + puff * 3;
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = const Color(0xFF392726).withValues(alpha: 0.12 - i * 0.02)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Map3CompletionPainter oldDelegate) => true;
}
