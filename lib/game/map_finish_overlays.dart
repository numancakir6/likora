import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class MapFinishOverlay extends StatelessWidget {
  final int mapNumber;
  final VoidCallback onCompleted;

  const MapFinishOverlay({
    super.key,
    required this.mapNumber,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    switch (mapNumber) {
      case 3:
        return Map3FinishOverlay(onCompleted: onCompleted);
      case 2:
        return Map2FinishOverlay(onCompleted: onCompleted);
      case 1:
      default:
        return Map1FinishOverlay(onCompleted: onCompleted);
    }
  }
}

// ─────────────────────────────────────────────
// MAP 1 · MOR BULUT + AŞAĞI IŞINLAR
// ─────────────────────────────────────────────

class Map1FinishOverlay extends StatefulWidget {
  final VoidCallback onCompleted;

  const Map1FinishOverlay({
    super.key,
    required this.onCompleted,
  });

  @override
  State<Map1FinishOverlay> createState() => _Map1FinishOverlayState();
}

class _Map1FinishOverlayState extends State<Map1FinishOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final Random _rng = Random();

  final List<_CloudPuff> _clouds = [];
  final List<_BeamRay> _beams = [];

  Timer? _doneTimer;
  bool _completed = false;

  static const Duration _totalDuration = Duration(milliseconds: 2800);

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _ctrl.addListener(_tick);

    _spawnInitialClouds();
    _spawnInitialBeams();

    _doneTimer = Timer(_totalDuration, _complete);
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    widget.onCompleted();
  }

  void _spawnInitialClouds() {
    for (int i = 0; i < 18; i++) {
      _clouds.add(
        _CloudPuff(
          x: _rng.nextDouble(),
          y: _rng.nextDouble() * 0.16,
          radius: 34 + _rng.nextDouble() * 64,
          alpha: 0.10 + _rng.nextDouble() * 0.18,
          drift: (_rng.nextDouble() - 0.5) * 0.0025,
          pulse: 0.5 + _rng.nextDouble() * 1.5,
        ),
      );
    }
  }

  void _spawnInitialBeams() {
    for (int i = 0; i < 16; i++) {
      _beams.add(_randomBeam(strong: true));
    }
  }

  _BeamRay _randomBeam({required bool strong}) {
    return _BeamRay(
      x: _rng.nextDouble(),
      topY: -0.04 - _rng.nextDouble() * 0.08,
      width:
          strong ? (14 + _rng.nextDouble() * 26) : (8 + _rng.nextDouble() * 16),
      length: strong
          ? (0.40 + _rng.nextDouble() * 0.34)
          : (0.22 + _rng.nextDouble() * 0.28),
      alpha: strong
          ? (0.18 + _rng.nextDouble() * 0.22)
          : (0.10 + _rng.nextDouble() * 0.16),
      life: strong ? (42 + _rng.nextInt(26)) : (22 + _rng.nextInt(18)),
      sway: (_rng.nextDouble() - 0.5) * 0.015,
      glow: 0.4 + _rng.nextDouble() * 0.7,
    );
  }

  void _tick() {
    final elapsed = _ctrl.lastElapsedDuration?.inMilliseconds ?? 0;
    final progress = (elapsed / _totalDuration.inMilliseconds).clamp(0.0, 1.0);

    for (final cloud in _clouds) {
      cloud.x += cloud.drift;
      if (cloud.x < -0.10) cloud.x = 1.10;
      if (cloud.x > 1.10) cloud.x = -0.10;
    }

    if (_rng.nextDouble() < 0.42 && progress < 0.78) {
      _beams.add(_randomBeam(strong: progress < 0.32));
    }

    for (int i = _beams.length - 1; i >= 0; i--) {
      final b = _beams[i];
      b.life--;
      b.alpha *= 0.985;
      b.x += b.sway;
      if (b.life <= 0 || b.alpha < 0.015) {
        _beams.removeAt(i);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final elapsed = _ctrl.lastElapsedDuration?.inMilliseconds ?? 0;
          final t = (elapsed / _totalDuration.inMilliseconds).clamp(0.0, 1.0);

          return CustomPaint(
            painter: _Map1FinishPainter(
              progress: t,
              time: elapsed / 1000.0,
              clouds: List<_CloudPuff>.unmodifiable(_clouds),
              beams: List<_BeamRay>.unmodifiable(_beams),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _Map1FinishPainter extends CustomPainter {
  final double progress;
  final double time;
  final List<_CloudPuff> clouds;
  final List<_BeamRay> beams;

  const _Map1FinishPainter({
    required this.progress,
    required this.time,
    required this.clouds,
    required this.beams,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fade = (1.0 - progress * 0.58).clamp(0.0, 1.0);
    final burst =
        progress < 0.22 ? Curves.easeOut.transform(1.0 - progress / 0.22) : 0.0;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0B0415).withValues(alpha: 0.42 * fade),
            const Color(0xFF140726).withValues(alpha: 0.55 * fade),
            const Color(0xFF06030C).withValues(alpha: 0.72 * fade),
          ],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFFD28BFF).withValues(alpha: burst * 0.08),
    );

    final skyGlowRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.55);
    canvas.drawRect(
      skyGlowRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.95),
          radius: 1.12,
          colors: [
            const Color(0xFFDA8CFF).withValues(alpha: 0.14),
            const Color(0xFF9C4DFF).withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(skyGlowRect),
    );

    for (final c in clouds) {
      final cx = c.x * size.width;
      final cy = c.y * size.height + sin(time * c.pulse + c.x * 10) * 4.0;
      final r = c.radius * (0.95 + sin(time * 1.3 + c.pulse) * 0.06);

      final center = Offset(cx, cy);

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = const Color(0xFF7B3EFF).withValues(alpha: c.alpha * 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.34),
      );

      canvas.drawCircle(
        center.translate(-r * 0.22, r * 0.04),
        r * 0.72,
        Paint()
          ..color = const Color(0xFFB765FF).withValues(alpha: c.alpha * 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.24),
      );

      canvas.drawCircle(
        center.translate(r * 0.24, -r * 0.03),
        r * 0.58,
        Paint()
          ..color = const Color(0xFFE3B5FF).withValues(alpha: c.alpha * 0.28)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16),
      );
    }

    for (final b in beams) {
      final x = b.x * size.width;
      final topY = b.topY * size.height;
      final bottomY = topY + b.length * size.height;
      final halfW = b.width * 0.5;

      final beamPath = Path()
        ..moveTo(x - halfW, topY)
        ..lineTo(x + halfW, topY)
        ..lineTo(x + halfW * 0.38, bottomY)
        ..lineTo(x - halfW * 0.38, bottomY)
        ..close();

      final beamRect = Rect.fromLTRB(
        x - halfW,
        topY,
        x + halfW,
        bottomY,
      );

      canvas.drawPath(
        beamPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF3D2FF).withValues(alpha: b.alpha),
              const Color(0xFFD08CFF).withValues(alpha: b.alpha * 0.70),
              const Color(0xFF8E3FFF).withValues(alpha: b.alpha * 0.28),
              Colors.transparent,
            ],
            stops: const [0.0, 0.22, 0.72, 1.0],
          ).createShader(beamRect)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.glow * 7),
      );

      canvas.drawLine(
        Offset(x, topY + 6),
        Offset(x, bottomY),
        Paint()
          ..color = const Color(0xFFF9E7FF).withValues(alpha: b.alpha * 0.78)
          ..strokeWidth = max(1.2, halfW * 0.18)
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Map1FinishPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────
// MAP 2 · ALTTAN YUKARI SU DOLMASI
// ─────────────────────────────────────────────

class Map2FinishOverlay extends StatefulWidget {
  final VoidCallback onCompleted;

  const Map2FinishOverlay({
    super.key,
    required this.onCompleted,
  });

  @override
  State<Map2FinishOverlay> createState() => _Map2FinishOverlayState();
}

class _Map2FinishOverlayState extends State<Map2FinishOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _doneTimer;
  bool _completed = false;

  static const Duration _totalDuration = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: _totalDuration,
    )..forward();

    _doneTimer = Timer(_totalDuration, _complete);
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    widget.onCompleted();
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return CustomPaint(
            painter: _Map2FinishPainter(
              progress: Curves.easeInOut.transform(_ctrl.value),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _Map2FinishPainter extends CustomPainter {
  final double progress;

  const _Map2FinishPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bgFade = (0.10 + progress * 0.32).clamp(0.0, 0.42);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF03131D).withValues(alpha: bgFade * 0.55),
            const Color(0xFF052131).withValues(alpha: bgFade * 0.82),
            const Color(0xFF021019).withValues(alpha: bgFade),
          ],
        ).createShader(rect),
    );

    final waterTop = lerpDouble(size.height + 20, 0, progress)!;
    final waveAmp = 8 + 16 * (1.0 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);
    final waveShift = sin(progress * pi * 7.5) * 18;

    final waterPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, waterTop)
      ..quadraticBezierTo(
        size.width * 0.18 + waveShift * 0.6,
        waterTop - waveAmp,
        size.width * 0.38 + waveShift * 0.2,
        waterTop + waveAmp * 0.25,
      )
      ..quadraticBezierTo(
        size.width * 0.68 - waveShift * 0.3,
        waterTop + waveAmp,
        size.width,
        waterTop - waveAmp * 0.15,
      )
      ..lineTo(size.width, size.height)
      ..close();

    final waterRect = Rect.fromLTRB(0, waterTop - 28, size.width, size.height);

    canvas.drawPath(
      waterPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF76D9FF).withValues(alpha: 0.34),
            const Color(0xFF1CA3EC).withValues(alpha: 0.42),
            const Color(0xFF0C6FAE).withValues(alpha: 0.56),
            const Color(0xFF063C64).withValues(alpha: 0.68),
          ],
          stops: const [0.0, 0.22, 0.62, 1.0],
        ).createShader(waterRect),
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, waterTop)
        ..quadraticBezierTo(
          size.width * 0.18 + waveShift * 0.6,
          waterTop - waveAmp,
          size.width * 0.38 + waveShift * 0.2,
          waterTop + waveAmp * 0.25,
        )
        ..quadraticBezierTo(
          size.width * 0.68 - waveShift * 0.3,
          waterTop + waveAmp,
          size.width,
          waterTop - waveAmp * 0.15,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = const Color(0xFFC4F0FF).withValues(alpha: 0.70)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    final highlightRect =
        Rect.fromLTRB(0, waterTop - 10, size.width, waterTop + 36);
    canvas.drawRect(
      highlightRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE6FBFF).withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ).createShader(highlightRect),
    );

    final deepGlowRect =
        Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45);
    canvas.drawRect(
      deepGlowRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF0E6EA7).withValues(alpha: 0.06),
            const Color(0xFF062B45).withValues(alpha: 0.15),
          ],
        ).createShader(deepGlowRect),
    );

    if (progress > 0.82) {
      final settle = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFFBCEEFF).withValues(alpha: settle * 0.06),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Map2FinishPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────
// MAP 3 · TAM EKRAN VOLKAN PATLAMASI
// ─────────────────────────────────────────────

class Map3FinishOverlay extends StatefulWidget {
  final VoidCallback onCompleted;

  const Map3FinishOverlay({
    super.key,
    required this.onCompleted,
  });

  @override
  State<Map3FinishOverlay> createState() => _Map3FinishOverlayState();
}

class _Map3FinishOverlayState extends State<Map3FinishOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final Random _rng = Random();

  final List<_FinishProjectile> _projectiles = [];
  final List<_FinishEmber> _embers = [];
  final List<_FinishSmoke> _smokes = [];

  Timer? _doneTimer;
  bool _completed = false;

  static const Duration _totalDuration = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
    _ctrl.addListener(_tick);
    _spawnInitialBurst();
    _doneTimer = Timer(_totalDuration, _complete);
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    widget.onCompleted();
  }

  void _spawnInitialBurst() {
    for (int i = 0; i < 44; i++) {
      _projectiles.add(_randomProjectile(early: true));
    }
    for (int i = 0; i < 28; i++) {
      _embers.add(_randomEmber(strong: true));
    }
    for (int i = 0; i < 10; i++) {
      _smokes.add(_randomSmoke(initial: true));
    }
  }

  _FinishProjectile _randomProjectile({required bool early}) {
    final spread = early ? 1.10 : 0.98;
    final angle = (-pi * 0.92) + _rng.nextDouble() * pi * spread;
    final flame = _rng.nextDouble() < 0.38;

    return _FinishProjectile(
      x: 0.0,
      y: 0.0,
      vx: cos(angle) *
          (early
              ? (7.5 + _rng.nextDouble() * 10.5)
              : (5.0 + _rng.nextDouble() * 7.0)),
      vy: sin(angle) *
          (early
              ? (15.0 + _rng.nextDouble() * 16.0)
              : (10.0 + _rng.nextDouble() * 10.0)),
      gravity: early
          ? (0.65 + _rng.nextDouble() * 0.18)
          : (0.72 + _rng.nextDouble() * 0.16),
      size: flame ? (8 + _rng.nextDouble() * 16) : (5 + _rng.nextDouble() * 12),
      alpha: 0.72 + _rng.nextDouble() * 0.25,
      life: early ? (68 + _rng.nextInt(22)) : (48 + _rng.nextInt(18)),
      isFlame: flame,
    );
  }

  _FinishEmber _randomEmber({required bool strong}) {
    final angle = (-pi * 0.96) + _rng.nextDouble() * pi * 1.18;
    return _FinishEmber(
      x: 0.0,
      y: 0.0,
      vx: cos(angle) *
          (strong
              ? (4.0 + _rng.nextDouble() * 8.0)
              : (2.5 + _rng.nextDouble() * 4.5)),
      vy: sin(angle) *
          (strong
              ? (8.0 + _rng.nextDouble() * 10.0)
              : (5.0 + _rng.nextDouble() * 6.0)),
      gravity: 0.22 + _rng.nextDouble() * 0.08,
      radius: strong
          ? (2.0 + _rng.nextDouble() * 3.8)
          : (1.5 + _rng.nextDouble() * 2.5),
      alpha: 0.55 + _rng.nextDouble() * 0.35,
      life: strong ? (62 + _rng.nextInt(30)) : (38 + _rng.nextInt(18)),
    );
  }

  _FinishSmoke _randomSmoke({required bool initial}) {
    return _FinishSmoke(
      x: (_rng.nextDouble() - 0.5) * 40,
      y: -10 - _rng.nextDouble() * 30,
      vx: (_rng.nextDouble() - 0.5) * 1.0,
      vy: -(0.6 + _rng.nextDouble() * 1.0),
      growth: initial
          ? (1.0 + _rng.nextDouble() * 1.8)
          : (0.7 + _rng.nextDouble() * 1.1),
      radius: initial
          ? (24 + _rng.nextDouble() * 34)
          : (14 + _rng.nextDouble() * 22),
      alpha: initial
          ? (0.16 + _rng.nextDouble() * 0.12)
          : (0.10 + _rng.nextDouble() * 0.08),
      life: initial ? (90 + _rng.nextInt(34)) : (55 + _rng.nextInt(24)),
    );
  }

  void _tick() {
    final elapsed = _ctrl.lastElapsedDuration?.inMilliseconds ?? 0;
    final progress = (elapsed / _totalDuration.inMilliseconds).clamp(0.0, 1.0);

    if (_rng.nextDouble() < 0.16 && progress < 0.42) {
      _projectiles.add(_randomProjectile(early: false));
    }
    if (_rng.nextDouble() < 0.24 && progress < 0.70) {
      _embers.add(_randomEmber(strong: false));
    }
    if (_rng.nextDouble() < 0.10 && progress < 0.60) {
      _smokes.add(_randomSmoke(initial: false));
    }

    for (int i = _projectiles.length - 1; i >= 0; i--) {
      final p = _projectiles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.vy += p.gravity;
      p.life--;
      p.alpha *= 0.988;
      if (p.life <= 0 || p.alpha < 0.02) {
        _projectiles.removeAt(i);
      }
    }

    for (int i = _embers.length - 1; i >= 0; i--) {
      final e = _embers[i];
      e.x += e.vx;
      e.y += e.vy;
      e.vy += e.gravity;
      e.life--;
      e.alpha *= 0.985;
      if (e.life <= 0 || e.alpha < 0.02) {
        _embers.removeAt(i);
      }
    }

    for (int i = _smokes.length - 1; i >= 0; i--) {
      final s = _smokes[i];
      s.x += s.vx;
      s.y += s.vy;
      s.radius += s.growth;
      s.life--;
      s.alpha *= 0.989;
      if (s.life <= 0 || s.alpha < 0.015) {
        _smokes.removeAt(i);
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final elapsed = _ctrl.lastElapsedDuration?.inMilliseconds ?? 0;
          final t = (elapsed / _totalDuration.inMilliseconds).clamp(0.0, 1.0);
          return CustomPaint(
            painter: _Map3FinishPainter(
              progress: t,
              projectiles: List<_FinishProjectile>.unmodifiable(_projectiles),
              embers: List<_FinishEmber>.unmodifiable(_embers),
              smokes: List<_FinishSmoke>.unmodifiable(_smokes),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _Map3FinishPainter extends CustomPainter {
  final double progress;
  final List<_FinishProjectile> projectiles;
  final List<_FinishEmber> embers;
  final List<_FinishSmoke> smokes;

  static const Color lavaCore = Color(0xFFFFF1A8);
  static const Color lavaGlow = Color(0xFFFFB300);
  static const Color lavaOrange = Color(0xFFFF6A00);
  static const Color lavaRed = Color(0xFFD32F2F);
  static const Color deepSmoke = Color(0xFF1A0F0F);

  const _Map3FinishPainter({
    required this.progress,
    required this.projectiles,
    required this.embers,
    required this.smokes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.5, size.height * 0.76);
    final bgFade = (1.0 - progress * 0.72).clamp(0.0, 1.0);
    final flash = progress < 0.18
        ? Curves.easeOut.transform(1.0 - (progress / 0.18))
        : 0.0;

    final overlayRect = Offset.zero & size;
    canvas.drawRect(
      overlayRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF140605).withValues(alpha: 0.35 * bgFade),
            const Color(0xFF220606).withValues(alpha: 0.52 * bgFade),
            const Color(0xFF070304).withValues(alpha: 0.82 * bgFade),
          ],
        ).createShader(overlayRect),
    );

    canvas.drawRect(
      overlayRect,
      Paint()..color = const Color(0xFFFF7A00).withValues(alpha: flash * 0.18),
    );

    final globalHeatRadius = lerpDouble(120, 420, min(progress * 2.2, 1.0))!;
    canvas.drawCircle(
      origin,
      globalHeatRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            lavaGlow.withValues(alpha: 0.20 + flash * 0.25),
            lavaOrange.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(
          Rect.fromCircle(center: origin, radius: globalHeatRadius),
        ),
    );

    if (progress < 0.26) {
      final burstR = lerpDouble(30, 220, progress / 0.26)!;
      final burstAlpha = (1.0 - (progress / 0.26)).clamp(0.0, 1.0);
      canvas.drawCircle(
        origin,
        burstR,
        Paint()
          ..color = lavaCore.withValues(alpha: burstAlpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
      );
      canvas.drawCircle(
        origin,
        burstR * 0.55,
        Paint()
          ..color = lavaGlow.withValues(alpha: burstAlpha * 0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    for (final s in smokes) {
      final center = Offset(origin.dx + s.x, origin.dy + s.y);
      final r = s.radius;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = deepSmoke.withValues(alpha: s.alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
      );
      canvas.drawCircle(
        center.translate(0, -r * 0.10),
        r * 0.52,
        Paint()
          ..color = lavaOrange.withValues(alpha: s.alpha * 0.20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
      );
    }

    for (final e in embers) {
      final p = Offset(origin.dx + e.x, origin.dy + e.y);
      canvas.drawCircle(
        p,
        e.radius * 1.8,
        Paint()
          ..color = lavaOrange.withValues(alpha: e.alpha * 0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.radius * 1.8),
      );
      canvas.drawCircle(
        p,
        e.radius,
        Paint()..color = lavaGlow.withValues(alpha: e.alpha),
      );
      canvas.drawCircle(
        p.translate(0, -e.radius * 0.15),
        e.radius * 0.42,
        Paint()..color = lavaCore.withValues(alpha: e.alpha * 0.85),
      );
    }

    for (final p in projectiles) {
      final pos = Offset(origin.dx + p.x, origin.dy + p.y);
      if (p.isFlame) {
        final r = p.size;
        final rect = Rect.fromCircle(center: pos, radius: r * 1.35);
        canvas.drawCircle(
          pos,
          r * 1.28,
          Paint()
            ..shader = RadialGradient(
              colors: [
                lavaCore.withValues(alpha: p.alpha),
                lavaGlow.withValues(alpha: p.alpha * 0.88),
                lavaOrange.withValues(alpha: p.alpha * 0.60),
                lavaRed.withValues(alpha: p.alpha * 0.18),
              ],
              stops: const [0.0, 0.28, 0.62, 1.0],
            ).createShader(rect)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.60),
        );
        canvas.drawCircle(
          pos,
          r * 0.32,
          Paint()..color = lavaCore.withValues(alpha: p.alpha * 0.95),
        );
      } else {
        final r = p.size;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.scale(1.0, 1.35);
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..color = lavaRed.withValues(alpha: p.alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
        );
        canvas.drawCircle(
          Offset(0, -r * 0.22),
          r * 0.42,
          Paint()..color = lavaOrange.withValues(alpha: p.alpha * 0.82),
        );
        canvas.restore();
        final trailStart = Offset(pos.dx - p.vx * 1.6, pos.dy - p.vy * 1.2);
        canvas.drawLine(
          trailStart,
          pos,
          Paint()
            ..color = lavaOrange.withValues(alpha: p.alpha * 0.34)
            ..strokeWidth = r * 0.55
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.28),
        );
      }
    }

    _drawGroundGlow(canvas, size, origin);
  }

  void _drawGroundGlow(Canvas canvas, Size size, Offset origin) {
    final rect =
        Rect.fromLTWH(0, size.height * 0.62, size.width, size.height * 0.38);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            lavaOrange.withValues(alpha: 0.08),
            lavaRed.withValues(alpha: 0.12),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
      origin,
      160,
      Paint()
        ..color = lavaOrange.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42),
    );
  }

  @override
  bool shouldRepaint(covariant _Map3FinishPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────
// MODELLER
// ─────────────────────────────────────────────

class _CloudPuff {
  double x;
  double y;
  double radius;
  double alpha;
  double drift;
  double pulse;

  _CloudPuff({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.drift,
    required this.pulse,
  });
}

class _BeamRay {
  double x;
  double topY;
  double width;
  double length;
  double alpha;
  int life;
  double sway;
  double glow;

  _BeamRay({
    required this.x,
    required this.topY,
    required this.width,
    required this.length,
    required this.alpha,
    required this.life,
    required this.sway,
    required this.glow,
  });
}

class _FinishProjectile {
  double x;
  double y;
  final double vx;
  double vy;
  final double gravity;
  final double size;
  double alpha;
  int life;
  final bool isFlame;

  _FinishProjectile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.size,
    required this.alpha,
    required this.life,
    required this.isFlame,
  });
}

class _FinishEmber {
  double x;
  double y;
  final double vx;
  double vy;
  final double gravity;
  final double radius;
  double alpha;
  int life;

  _FinishEmber({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.radius,
    required this.alpha,
    required this.life,
  });
}

class _FinishSmoke {
  double x;
  double y;
  final double vx;
  final double vy;
  final double growth;
  double radius;
  double alpha;
  int life;

  _FinishSmoke({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.growth,
    required this.radius,
    required this.alpha,
    required this.life,
  });
}
