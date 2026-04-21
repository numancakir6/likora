import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

import '../../core/game_models.dart';
import '../../core/game_visuals.dart';

class MountainTubeReservoir extends StatefulWidget {
  final double width;
  final double height;
  final double fillPercent;
  final Color liquidColor;
  final bool glow;
  final VoidCallback? onTap;
  final List<VisualLayer> layers;
  final int capacity;
  final bool gameWon;
  final bool loopEruption;

  const MountainTubeReservoir({
    super.key,
    this.width = 250,
    this.height = 120,
    this.fillPercent = 0.0,
    this.liquidColor = const Color(0xFFFF6A00),
    this.glow = false,
    this.onTap,
    this.layers = const [],
    this.capacity = 18,
    this.gameWon = false,
    this.loopEruption = false,
  });

  @override
  State<MountainTubeReservoir> createState() => _MountainTubeReservoirState();
}

// Tek alev huzmesi verisi
class _FlameJet {
  double phase; // 0..1 yaşam döngüsü
  double speed; // faz artış hızı (küçük = yavaş yanma)
  double laneX; // -1..1, ağız merkezine göre
  double lean; // eğim
  double height; // maksimum boy (piksel)
  double maxAlpha;

  _FlameJet({
    required this.phase,
    required this.speed,
    required this.laneX,
    required this.lean,
    required this.height,
    required this.maxAlpha,
  });
}

// Tek duman bulutu verisi
class _SmokeCloud {
  double phase; // 0..1
  double speed;
  double laneX; // -1..1
  double size; // piksel
  double maxAlpha;
  double drift; // yatay sürüklenme

  _SmokeCloud({
    required this.phase,
    required this.speed,
    required this.laneX,
    required this.size,
    required this.maxAlpha,
    required this.drift,
  });
}

// Lav fırlatma tanesi (oyun bitişinde)
class _LavaProjectile {
  double phase; // 0..1
  double speed;
  double angle; // radyan, yukarı-yana açı
  double power; // fırlatma gücü (piksel)
  double size;
  double maxAlpha;
  bool isFlame; // true=alev, false=lav damlası

  _LavaProjectile({
    required this.phase,
    required this.speed,
    required this.angle,
    required this.power,
    required this.size,
    required this.maxAlpha,
    required this.isFlame,
  });
}

class _MountainTubeReservoirState extends State<MountainTubeReservoir>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Sıvı slosh
  double _slosh = 0.0;
  double _sloshVel = 0.0;
  double _prevFill = 0.0;

  // Krater ağız efektleri
  final List<_FlameJet> _flames = [];
  final List<_SmokeCloud> _smokes = [];
  final _rng = Random();

  // Döküm tetikleme
  double _pourGlow = 0.0; // 0..1, döküm gelince 1'e çıkar yavaşça söner
  double _interiorGlow = 0.0; // iç parlaması

  // Oyun bitti eruption
  bool _eruptionStarted = false;
  bool _eruptionLooping = false;
  bool eruptionCycleStarted = false;
  final List<_LavaProjectile> _projectiles = [];
  double _eruptionTimer = 0.0; // eruption süresi sayacı (0..1)

  static const double _sloshDecay = 0.965;
  static const double _sloshSpring = 0.010;
  double _wavePhase = 0.0; // yavaş dalga fazı (0..1 döngü)

  @override
  void initState() {
    super.initState();
    _prevFill = widget.fillPercent;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    _ctrl.addListener(_tick);

    if (widget.gameWon) {
      _startEruption(looping: widget.loopEruption);
    }
  }

  void _startEruption({required bool looping}) {
    _eruptionStarted = true;
    _eruptionLooping = looping;
    eruptionCycleStarted = true;
    _eruptionTimer = 0.0;
    _pourGlow = 1.0;
    _interiorGlow = 1.0;
    _projectiles.clear();
    _spawnEruption();
  }

  void _restartLoopingEruptionIfNeeded() {
    if (!widget.gameWon || !widget.loopEruption) return;
    _startEruption(looping: true);
  }

  @override
  void didUpdateWidget(MountainTubeReservoir old) {
    super.didUpdateWidget(old);
    if (widget.fillPercent > _prevFill + 0.005) {
      final impulse = 0.20 + (widget.fillPercent - _prevFill) * 1.2;
      _sloshVel += impulse * ((_ctrl.value > 0.5) ? 1.0 : -1.0);
      _pourGlow = 1.0;
      _interiorGlow = (_interiorGlow + 0.7).clamp(0.0, 1.0);
      _spawnFlamesForPour();
    }
    _prevFill = widget.fillPercent;

    if (widget.gameWon && !old.gameWon) {
      _startEruption(looping: widget.loopEruption);
      return;
    }

    if (widget.gameWon &&
        old.gameWon &&
        widget.loopEruption != old.loopEruption &&
        widget.loopEruption) {
      _restartLoopingEruptionIfNeeded();
      return;
    }

    if (!widget.gameWon && old.gameWon) {
      _eruptionStarted = false;
      _eruptionLooping = false;
      eruptionCycleStarted = false;
      _eruptionTimer = 0.0;
      _projectiles.clear();
    }
  }

  void _spawnEruption() {
    for (int i = 0; i < 26; i++) {
      final isFlame = i < 14;
      final angle = (-pi * 0.88) + _rng.nextDouble() * pi * 0.76;

      _projectiles.add(
        _LavaProjectile(
          phase: 0.0,
          speed: 0.0032 + _rng.nextDouble() * 0.0020,
          angle: angle,
          power: 48 + _rng.nextDouble() * 105,
          size:
              isFlame ? 8 + _rng.nextDouble() * 18 : 4 + _rng.nextDouble() * 13,
          maxAlpha: 0.62 + _rng.nextDouble() * 0.30,
          isFlame: isFlame,
        ),
      );
    }
    _spawnFlamesForPour();
    _pourGlow = 1.0;
  }

  void _spawnFlamesForPour() {
    final fill = widget.fillPercent;
    final count = 2 + (fill * 3).round(); // 2-5 alev
    for (int i = 0; i < count; i++) {
      _flames.add(_FlameJet(
        phase: 0.0,
        speed: 0.0020 + _rng.nextDouble() * 0.0012,
        laneX: (_rng.nextDouble() * 2 - 1) * 0.65,
        lean: (_rng.nextDouble() - 0.5) * 0.28,
        height: 24 + _rng.nextDouble() * 40 * fill,
        maxAlpha: 0.50 + fill * 0.38,
      ));
    }
  }

  void spawnSmoke(double laneX) {
    if (_smokes.length >= 10) return;
    _smokes.add(_SmokeCloud(
      phase: 0.0,
      speed: 0.0014 + _rng.nextDouble() * 0.0008,
      laneX: laneX + (_rng.nextDouble() - 0.5) * 0.2,
      size: 8 + _rng.nextDouble() * 12 * widget.fillPercent,
      maxAlpha: 0.08 + widget.fillPercent * 0.10,
      drift: (_rng.nextDouble() - 0.5) * 0.35,
    ));
  }

  void _tick() {
    _wavePhase += 0.020;

    final target = 0.0;
    final acc = (target - _slosh) * _sloshSpring;
    _sloshVel = (_sloshVel + acc) * _sloshDecay;
    _slosh += _sloshVel;

    if (_pourGlow > 0.0) {
      _pourGlow = (_pourGlow - 0.020).clamp(0.0, 1.0);
    }

    if (_interiorGlow > 0.0) {
      _interiorGlow = (_interiorGlow - 0.012).clamp(0.0, 1.0);
    }

    for (int i = _flames.length - 1; i >= 0; i--) {
      final f = _flames[i];
      f.phase += f.speed;
      if (f.phase >= 1.0) {
        _flames.removeAt(i);
      }
    }

    for (int i = _smokes.length - 1; i >= 0; i--) {
      final s = _smokes[i];
      s.phase += s.speed;
      if (s.phase >= 1.0) {
        _smokes.removeAt(i);
      }
    }

    if (_eruptionStarted) {
      _eruptionTimer = (_eruptionTimer + 0.0018).clamp(0.0, 1.0);

      if (_eruptionTimer < 0.35 &&
          _rng.nextDouble() < 0.22 &&
          _projectiles.length < 70) {
        final isFlame = _rng.nextBool();
        final angle = (-pi * 0.85) + _rng.nextDouble() * pi * 0.70;

        _projectiles.add(
          _LavaProjectile(
            phase: 0.0,
            speed: 0.0032 + _rng.nextDouble() * 0.0020,
            angle: angle,
            power: 45 + _rng.nextDouble() * 100,
            size: isFlame
                ? 7 + _rng.nextDouble() * 18
                : 4 + _rng.nextDouble() * 12,
            maxAlpha: 0.60 + _rng.nextDouble() * 0.35,
            isFlame: isFlame,
          ),
        );
      }

      for (int i = _projectiles.length - 1; i >= 0; i--) {
        final p = _projectiles[i];
        p.phase += p.speed;
        if (p.phase >= 1.0) {
          _projectiles.removeAt(i);
        }
      }

      if (_eruptionTimer < 0.6) {
        _pourGlow = (_pourGlow + 0.01).clamp(0.0, 1.0);
      }

      if (_eruptionTimer >= 1.0 && _projectiles.isEmpty) {
        if (_eruptionLooping && widget.gameWon && widget.loopEruption) {
          _eruptionTimer = 0.0;
          _projectiles.clear();
          _spawnEruption();
        } else {
          _eruptionStarted = false;
          eruptionCycleStarted = false;
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => CustomPaint(
                  painter: _VolcanoPainter(
                    layers: widget.layers,
                    capacity: widget.capacity,
                    fillPercent: widget.fillPercent,
                    slosh: _slosh,
                    time: _ctrl.value,
                    wavePhase: _wavePhase,
                    interiorGlow: _interiorGlow,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60,
              right: -60,
              top: -widget.height * 0.12,
              height: widget.height * 0.45 + 260,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => CustomPaint(
                  painter: _CraterEffectsPainter(
                    flames: List<_FlameJet>.unmodifiable(_flames),
                    smokes: List<_SmokeCloud>.unmodifiable(_smokes),
                    pourGlow: _pourGlow,
                    fillPercent: widget.fillPercent,
                    time: _ctrl.value,
                    mouthLocalY: widget.height * (0.10 + 0.12),
                    projectiles:
                        List<_LavaProjectile>.unmodifiable(_projectiles),
                    eruptionTimer: _eruptionTimer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CraterEffectsPainter extends CustomPainter {
  final List<_FlameJet> flames;
  final List<_SmokeCloud> smokes;
  final double pourGlow;
  final double fillPercent;
  final double time;
  final double mouthLocalY;
  final List<_LavaProjectile> projectiles;
  final double eruptionTimer;

  const _CraterEffectsPainter({
    required this.flames,
    required this.smokes,
    required this.pourGlow,
    required this.fillPercent,
    required this.time,
    required this.mouthLocalY,
    this.projectiles = const [],
    this.eruptionTimer = 0.0,
  });

  double _flameA(double phase, double max) {
    if (phase < 0.20) return max * (phase / 0.20);
    if (phase < 0.62) return max;
    return max * (1.0 - (phase - 0.62) / 0.38);
  }

  double _smokeA(double phase, double max) {
    if (phase < 0.12) return max * (phase / 0.12);
    if (phase < 0.55) return max;
    return max * (1.0 - (phase - 0.55) / 0.45);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mouthX = size.width * 0.5;
    final mouthY = mouthLocalY;

    if (fillPercent > 0.04) {
      canvas.drawCircle(
        Offset(mouthX, mouthY),
        14 + fillPercent * 18,
        Paint()
          ..color = kLavaOrange.withValues(alpha: 0.04 + fillPercent * 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    if (pourGlow > 0.01) {
      canvas.drawCircle(
        Offset(mouthX, mouthY),
        20 + pourGlow * 24,
        Paint()
          ..color = kLavaGlow.withValues(alpha: pourGlow * 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    for (final s in smokes) {
      final alpha = _smokeA(s.phase, s.maxAlpha);
      if (alpha < 0.004) continue;

      final rise = s.phase * 120;
      final cx = mouthX + s.laneX * 28 + s.drift * rise * 0.5;
      final cy = mouthY - rise;
      final radius = s.size * 1.6 + s.phase * 40;

      final col = Color.lerp(
        kLavaOrange.withValues(alpha: alpha * 1.4),
        const Color(0xFF382828).withValues(alpha: alpha * 0.75),
        s.phase,
      )!;

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = col
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.65),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.55,
        Paint()
          ..color = kLavaOrange.withValues(alpha: alpha * 0.45 * (1 - s.phase))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3),
      );
    }

    for (final f in flames) {
      final alpha = _flameA(f.phase, f.maxAlpha);
      if (alpha < 0.004) continue;

      final baseX = mouthX + f.laneX * 22;
      final peakH = f.height * 1.45 * min(f.phase * 2.0, 1.0);
      final tipX = baseX + f.lean * peakH;
      final tipY = mouthY - peakH;

      final midY = lerpDouble(mouthY, tipY, 0.52)!;

      final flamePath = Path()
        ..moveTo(baseX - 2, mouthY)
        ..quadraticBezierTo(baseX - 10, midY, tipX, tipY)
        ..quadraticBezierTo(baseX + 10, midY, baseX + 2, mouthY)
        ..close();

      final flameRect = Rect.fromLTRB(
        min(baseX - 12, tipX - 4),
        tipY,
        max(baseX + 12, tipX + 4),
        mouthY,
      );

      canvas.drawPath(
        flamePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              kLavaCore.withValues(alpha: alpha * 1.0),
              kLavaGlow.withValues(alpha: alpha * 0.92),
              kLavaOrange.withValues(alpha: alpha * 0.78),
              kLavaRed.withValues(alpha: alpha * 0.35),
            ],
            stops: const [0.0, 0.28, 0.65, 1.0],
          ).createShader(flameRect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
      );

      canvas.drawPath(
        flamePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = kLavaGlow.withValues(alpha: alpha * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );

      final corePath = Path()
        ..moveTo(baseX - 1, mouthY)
        ..quadraticBezierTo(
          baseX - 4,
          midY + (tipY - midY) * 0.3,
          tipX,
          tipY + peakH * 0.18,
        )
        ..quadraticBezierTo(
          baseX + 4,
          midY + (tipY - midY) * 0.3,
          baseX + 1,
          mouthY,
        )
        ..close();

      canvas.drawPath(
        corePath,
        Paint()
          ..color = kLavaCore.withValues(alpha: alpha * 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );
    }

    if (projectiles.isNotEmpty) {
      if (eruptionTimer < 0.35) {
        final burstAlpha = (1.0 - eruptionTimer / 0.35) * 0.55;
        canvas.drawCircle(
          Offset(mouthX, mouthY),
          30 + eruptionTimer * 80,
          Paint()
            ..color = kLavaCore.withValues(alpha: burstAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
        );
        canvas.drawCircle(
          Offset(mouthX, mouthY),
          18 + eruptionTimer * 40,
          Paint()
            ..color = kLavaGlow.withValues(alpha: burstAlpha * 0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
      }

      for (final p in projectiles) {
        final t = p.phase;
        final eased = t;
        final dx = cos(p.angle) * p.power * eased;
        final dy = sin(p.angle) * p.power * eased + 0.5 * 380 * eased * eased;
        final px = mouthX + dx;
        final py = mouthY + dy;

        final alpha = p.maxAlpha *
            (t < 0.15
                ? t / 0.15
                : t > 0.65
                    ? (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0)
                    : 1.0);

        if (alpha < 0.01) continue;

        if (p.isFlame) {
          final r = p.size * (1.0 + t * 0.5);
          final rect = Rect.fromCircle(center: Offset(px, py), radius: r * 1.2);
          canvas.drawCircle(
            Offset(px, py),
            r,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  kLavaCore.withValues(alpha: alpha),
                  kLavaGlow.withValues(alpha: alpha * 0.80),
                  kLavaOrange.withValues(alpha: alpha * 0.55),
                  kLavaRed.withValues(alpha: alpha * 0.15),
                ],
                stops: const [0.0, 0.30, 0.65, 1.0],
              ).createShader(rect)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55),
          );
          canvas.drawCircle(
            Offset(px, py),
            r * 0.35,
            Paint()..color = kLavaCore.withValues(alpha: alpha * 0.90),
          );
        } else {
          final r = p.size;
          final stretchY = 1.0 + t * 1.2;
          canvas.save();
          canvas.translate(px, py);
          canvas.scale(1.0, stretchY);
          canvas.drawCircle(
            Offset.zero,
            r,
            Paint()
              ..color = kLavaRed.withValues(alpha: alpha * 0.92)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
          );
          canvas.drawCircle(
            Offset(0, -r * 0.25),
            r * 0.45,
            Paint()..color = kLavaOrange.withValues(alpha: alpha * 0.75),
          );
          canvas.restore();

          if (t > 0.08) {
            final trailDx = cos(p.angle) * p.power * (t - 0.06);
            final trailDy = sin(p.angle) * p.power * (t - 0.06) +
                0.5 * 380 * (t - 0.06) * (t - 0.06);
            final trailX = mouthX + trailDx;
            final trailY = mouthY + trailDy;
            canvas.drawLine(
              Offset(trailX, trailY),
              Offset(px, py),
              Paint()
                ..color = kLavaOrange.withValues(alpha: alpha * 0.35)
                ..strokeWidth = r * 0.5
                ..strokeCap = StrokeCap.round
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CraterEffectsPainter old) => true;
}

class _VolcanoPainter extends CustomPainter {
  final List<VisualLayer> layers;
  final int capacity;
  final double fillPercent;
  final double slosh;
  final double time;
  final double interiorGlow;
  final double wavePhase;

  const _VolcanoPainter({
    required this.layers,
    required this.capacity,
    required this.fillPercent,
    required this.slosh,
    required this.time,
    this.wavePhase = 0.0,
    this.interiorGlow = 0.0,
  });

  Path _clipPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.05, h * 1.0)
      ..quadraticBezierTo(w * 0.08, h * 0.88, w * 0.13, h * 0.74)
      ..quadraticBezierTo(w * 0.18, h * 0.60, w * 0.26, h * 0.48)
      ..quadraticBezierTo(w * 0.33, h * 0.36, w * 0.40, h * 0.24)
      ..quadraticBezierTo(w * 0.43, h * 0.16, w * 0.44, h * 0.10)
      ..lineTo(w * 0.56, h * 0.10)
      ..quadraticBezierTo(w * 0.57, h * 0.16, w * 0.60, h * 0.24)
      ..quadraticBezierTo(w * 0.67, h * 0.36, w * 0.74, h * 0.48)
      ..quadraticBezierTo(w * 0.82, h * 0.60, w * 0.87, h * 0.74)
      ..quadraticBezierTo(w * 0.92, h * 0.88, w * 0.95, h * 1.0)
      ..close();
  }

  Color _layerColor(int colorIdx) {
    if (isLavaColorIndex(colorIdx)) return kLavaRed;
    return solidColorForIndex(colorIdx);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final clipPath = _clipPath(size);
    final bounds = clipPath.getBounds();
    final sloshShift = slosh * size.width * 0.055;
    final normalizedFill = fillPercent.clamp(0.0, 1.0);

    canvas.drawPath(
      clipPath,
      Paint()
        ..color = kLavaRed.withValues(
          alpha: 0.07 + normalizedFill * 0.13 + interiorGlow * 0.16,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.save();
    canvas.clipPath(clipPath);

    final safeCapacity = max(1, capacity);
    final easedFill = normalizedFill.clamp(0.0, 1.0);
    final fillableHeight = bounds.bottom - bounds.top;
    final totalFillHeight = fillableHeight * easedFill;
    final liquidTopBase = bounds.bottom - totalFillHeight;

    if (normalizedFill > 0.0) {
      final gI = 0.26 + normalizedFill * 0.36 + interiorGlow * 0.32;
      final emberRect = Rect.fromLTRB(
        bounds.left - 10,
        bounds.bottom - 38,
        bounds.right + 10,
        bounds.bottom + 12,
      );
      canvas.drawRect(
        emberRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 1),
            radius: 1.18,
            colors: [
              kLavaCore.withValues(alpha: gI * 0.42),
              kLavaGlow.withValues(alpha: gI * 0.28),
              kLavaRed.withValues(alpha: gI * 0.16),
              Colors.transparent,
            ],
            stops: const [0.0, 0.22, 0.55, 1.0],
          ).createShader(emberRect),
      );
    }

    if (normalizedFill > 0.0) {
      final backRect = Rect.fromLTRB(
        bounds.left - 22,
        liquidTopBase,
        bounds.right + 22,
        bounds.bottom + 22,
      );
      canvas.drawRect(
        backRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF580000).withValues(alpha: 0.98),
              kLavaRed.withValues(alpha: 0.97),
              const Color(0xFFBB2200).withValues(alpha: 0.93),
            ],
            stops: const [0.0, 0.50, 1.0],
          ).createShader(backRect),
      );
    }

    if (normalizedFill > 0.02) {
      final flameBoost = 1.0 + interiorGlow * 0.65;
      final flameTopLimit =
          max(bounds.top + 8, liquidTopBase - bounds.height * 0.18);

      for (int i = 0; i < 9; i++) {
        final lane = i / 8.0;
        final x = lerpDouble(bounds.left + 18, bounds.right - 18, lane)! +
            sin(time * pi * 1.5 + i * 1.0) * 4.5 +
            sloshShift * 0.3;
        final rawH = lerpDouble(
          16,
          55 * flameBoost,
          sin(time * pi * 1.7 + i * 1.2) * 0.5 + 0.5,
        )!;
        final topY = max(bounds.bottom - 3 - rawH, flameTopLimit);

        final path = Path()
          ..moveTo(x, bounds.bottom - 3)
          ..quadraticBezierTo(
            x - 7 - sin(time * pi * 2 + i) * 2,
            lerpDouble(bounds.bottom - 3, topY, 0.58)!,
            x,
            topY,
          )
          ..quadraticBezierTo(
            x + 7 + cos(time * pi * 2 + i) * 2,
            lerpDouble(bounds.bottom - 3, topY, 0.58)!,
            x,
            bounds.bottom - 3,
          )
          ..close();

        final rect = Rect.fromLTRB(x - 12, topY, x + 12, bounds.bottom - 3);

        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFF6A0000).withValues(alpha: 0.22),
                kLavaRed.withValues(alpha: 0.48),
                kLavaOrange.withValues(alpha: 0.55),
                kLavaGlow.withValues(alpha: 0.25),
              ],
              stops: const [0.0, 0.36, 0.70, 1.0],
            ).createShader(rect)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }

    double currentBottom = bounds.bottom;
    if (layers.isNotEmpty) {
      final totalVolume = layers.fold<double>(0.0, (a, b) => a + b.volume);
      if (totalVolume > 0.0001) {
        for (int i = layers.length - 1; i >= 0; i--) {
          final layer = layers[i];
          final ratio = (layer.volume / safeCapacity).clamp(0.0, 1.0);
          final hPart = fillableHeight * ratio;
          final top = currentBottom - hPart;
          final rect = Rect.fromLTRB(
            bounds.left - 18,
            top,
            bounds.right + 18,
            currentBottom + 8,
          );
          final base = _layerColor(layer.colorIdx);
          final isLava = isLavaColorIndex(layer.colorIdx);

          canvas.drawRect(
            rect,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isLava
                    ? [
                        const Color(0xFF580000),
                        kLavaRed,
                        const Color(0xFFBB2200),
                      ]
                    : [
                        base.withValues(alpha: 0.95),
                        Color.lerp(base, Colors.white, 0.10)!
                            .withValues(alpha: 0.96),
                        Color.lerp(base, Colors.black, 0.10)!
                            .withValues(alpha: 0.96),
                      ],
                stops: const [0.0, 0.58, 1.0],
              ).createShader(rect),
          );

          final edgeY = top + sin(time * 2 * pi + i * 0.9) * 1.1;
          canvas.drawRect(
            Rect.fromLTRB(
              bounds.left - 10,
              edgeY,
              bounds.right + 10,
              edgeY + 2.0,
            ),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  (isLava ? kLavaCore : Colors.white).withValues(alpha: 0.26),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromLTRB(bounds.left, edgeY, bounds.right, edgeY + 2.0),
              ),
          );
          currentBottom = top;
        }
      }
    } else if (normalizedFill > 0.0) {
      final rect = Rect.fromLTRB(
        bounds.left - 18,
        liquidTopBase,
        bounds.right + 18,
        bounds.bottom + 8,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF580000),
              kLavaRed,
              const Color(0xFFBB2200),
            ],
            stops: const [0.0, 0.52, 1.0],
          ).createShader(rect),
      );
    }

    if (normalizedFill > 0.0) {
      final waveY = liquidTopBase;
      final wSlowBase = wavePhase * 2 * pi;
      final waveAmp = 6.0 + slosh.abs() * 6.0;

      final wShift1 = sloshShift + sin(wSlowBase) * bounds.width * 0.06;
      final wShift2 =
          sloshShift * 0.5 + sin(wSlowBase + 1.2) * bounds.width * 0.05;
      final wShift3 = sloshShift - sin(wSlowBase + 2.4) * bounds.width * 0.06;

      final wPath = Path()
        ..moveTo(bounds.left - 20, bounds.bottom + 10)
        ..lineTo(bounds.left - 20, waveY)
        ..quadraticBezierTo(
          bounds.left + bounds.width * 0.25 + wShift1,
          waveY - waveAmp,
          bounds.left + bounds.width * 0.50 + wShift2,
          waveY + waveAmp * 0.35,
        )
        ..quadraticBezierTo(
          bounds.left + bounds.width * 0.75 + wShift3,
          waveY + waveAmp,
          bounds.right + 20,
          waveY - waveAmp * 0.15,
        )
        ..lineTo(bounds.right + 20, bounds.bottom + 10)
        ..close();

      canvas.drawPath(
        wPath,
        Paint()
          ..color = kLavaRed.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      canvas.drawPath(
        Path()
          ..moveTo(bounds.left, waveY)
          ..quadraticBezierTo(
            bounds.left + bounds.width * 0.25 + wShift1,
            waveY - waveAmp,
            bounds.left + bounds.width * 0.50 + wShift2,
            waveY + waveAmp * 0.35,
          )
          ..quadraticBezierTo(
            bounds.left + bounds.width * 0.75 + wShift3,
            waveY + waveAmp,
            bounds.right,
            waveY - waveAmp * 0.15,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = kLavaOrange.withValues(alpha: 0.55),
      );
    }

    if (normalizedFill > 0.05) {
      const int bubbleCount = 26;
      for (int i = 0; i < bubbleCount; i++) {
        final speed = 0.018 + (i % 7) * 0.006;
        final phase = ((time * speed + i * 0.13) % 1.0);
        final wobble = sin(time * pi * 0.4 + i * 1.7) * 3.5;
        final laneRatio = (i % 9) / 8.0;
        final x = lerpDouble(bounds.left + 12, bounds.right - 12, laneRatio)! +
            wobble +
            sloshShift * 0.4;
        final y = lerpDouble(bounds.bottom - 4, liquidTopBase + 8, phase)!;
        final nearSurface = (phase > 0.80) ? ((1.0 - phase) / 0.20) : 1.0;
        final r = lerpDouble(1.5, 4.5, (i % 5) / 4.0)! * nearSurface;
        final alpha = nearSurface;

        if (y < liquidTopBase - 2 || y > bounds.bottom - 1 || r < 0.3) {
          continue;
        }

        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = kLavaGlow.withValues(alpha: 0.16 * alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
        canvas.drawCircle(
          Offset(x, y),
          r * 0.38,
          Paint()..color = kLavaCore.withValues(alpha: 0.55 * alpha),
        );
      }
    }

    final shineRect = Rect.fromLTWH(
      bounds.left + bounds.width * 0.08,
      bounds.top,
      bounds.width * 0.14,
      bounds.height,
    );
    canvas.drawRect(
      shineRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.00),
          ],
        ).createShader(shineRect),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VolcanoPainter oldDelegate) {
    if (oldDelegate.capacity != capacity) return true;
    if ((oldDelegate.fillPercent - fillPercent).abs() > 0.0001) return true;
    if ((oldDelegate.slosh - slosh).abs() > 0.0001) return true;
    if ((oldDelegate.time - time).abs() > 0.0001) return true;
    if ((oldDelegate.wavePhase - wavePhase).abs() > 0.0001) return true;
    if ((oldDelegate.interiorGlow - interiorGlow).abs() > 0.0001) return true;
    if (oldDelegate.layers.length != layers.length) return true;
    for (int i = 0; i < layers.length; i++) {
      if (oldDelegate.layers[i].colorIdx != layers[i].colorIdx) return true;
      if ((oldDelegate.layers[i].volume - layers[i].volume).abs() > 0.0001) {
        return true;
      }
    }
    return false;
  }
}
