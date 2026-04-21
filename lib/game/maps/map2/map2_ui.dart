import 'dart:math';
import 'package:flutter/material.dart';

class BlindLayerUiHelper {
  static const Color hiddenFillColor = Color(0xFF2A2535);

  static int computeCurrentHiddenBelow({
    required bool blindMode,
    required int blindBaseLayerCount,
    required int safeVisibleCount,
    required int renderedLayerCount,
  }) {
    if (!blindMode) return 0;
    final hiddenBelow = max(0, blindBaseLayerCount - safeVisibleCount);
    return min(hiddenBelow, max(0, renderedLayerCount - 1));
  }

  static int computeRevealLayerIndex({
    required bool blindMode,
    required int safeVisibleCount,
    required int blindBaseLayerCount,
    required int renderedLayerCount,
  }) {
    if (!blindMode || safeVisibleCount <= 0) return -1;

    return max(
      0,
      renderedLayerCount -
          (safeVisibleCount - max(0, blindBaseLayerCount - renderedLayerCount)),
    );
  }

  static void paintRevealGlow({
    required Canvas canvas,
    required Path bandPath,
    required int revealGlowTick,
  }) {
    // Map 2'de açılan katmanda ekstra parlama istemiyoruz.
    // Siyah gizli katman ve ? işareti kalacak, ama açılan renk düz görünecek.
    return;
  }

  static void paintHiddenLayerDecorations({
    required Canvas canvas,
    required int layerIndex,
    required int renderedLayerCount,
    required double vBot,
    required double vTop,
    required double il,
    required double iw,
    required double ir,
    required double tilt,
    required double slosh,
    required _SurfaceComputer surface,
  }) {
    if (layerIndex < renderedLayerCount - 2) {
      final divSurface = surface(vTop, tilt, slosh * 0.2);
      canvas.drawPath(
        Path()
          ..moveTo(il, divSurface.lY)
          ..quadraticBezierTo(il + iw / 2, divSurface.cY, ir, divSurface.rY),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    final midVol = (vBot + vTop) / 2;
    final midSurface = surface(midVol, 0, 0);
    final midY = midSurface.cY;
    final midX = (il + ir) / 2;

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Color(0xAAFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(midX - textPainter.width / 2, midY - textPainter.height / 2),
    );
  }
}

class BlindLayerSurfacePoint {
  final double lY;
  final double cY;
  final double rY;

  const BlindLayerSurfacePoint({
    required this.lY,
    required this.cY,
    required this.rY,
  });
}

typedef _SurfaceComputer = BlindLayerSurfacePoint Function(
  double volume,
  double tilt,
  double slosh,
);
