import 'package:flutter/material.dart';
import '../../puzzle_presets.dart';

const List<Map<String, dynamic>> kColors = [
  // 🎯 ANA RENKLER
  {'name': 'Kırmızı', 'fill': Color(0xFFFF0000)},
  {'name': 'Turuncu', 'fill': Color(0xFFFF7A00)},
  {'name': 'Sarı', 'fill': Color(0xFFFFFF00)},
  {'name': 'Yeşil', 'fill': Color(0xFF00C853)},
  {'name': 'Mavi', 'fill': Color(0xFF0000FF)},

  // 🌈 ANA RENKLERDEN UZAK, BİRBİRİNDEN NET AYRILAN EK RENKLER
  {'name': 'Mor', 'fill': Color(0xFF6A0DAD)},
  {'name': 'Camgöbeği', 'fill': Color(0xFF00E5FF)},
  {'name': 'Lime', 'fill': Color(0xFFB2FF00)},
  {'name': 'Kahverengi', 'fill': Color(0xFF6D4C41)},
  {'name': 'Bordo', 'fill': Color(0xFF8B0000)},
  {'name': 'Pembe', 'fill': Color(0xFFFF4FA3)},
  {'name': 'Zeytin', 'fill': Color(0xFF808000)},
  {'name': 'Gri', 'fill': Color(0xFF9E9E9E)},
  {'name': 'Beyaz', 'fill': Color(0xFFFFFFFF)},
];

const Color kLavaDark = Color(0xFF4A0B00);
const Color kLavaRed = Color(0xFFC62828);
const Color kLavaOrange = Color(0xFFFF6F00);
const Color kLavaGlow = Color(0xFFFFD54F);
const Color kLavaCore = Color(0xFFFFF59D);

bool isLavaColorIndex(int colorIdx) => colorIdx == kLavaColorIndex;

Color solidColorForIndex(int colorIdx) =>
    kColors[colorIdx.clamp(0, kColors.length - 1).toInt()]['fill'] as Color;

double colorLuminanceForIndex(int colorIdx) {
  final c = solidColorForIndex(colorIdx);
  return c.computeLuminance();
}

double liquidHighlightAlphaFor(int colorIdx, {required bool isHidden}) {
  if (isHidden) return 0.0;
  final lum = colorLuminanceForIndex(colorIdx);
  if (lum < 0.10) return 0.03;
  if (lum < 0.20) return 0.04;
  return 0.05;
}

double liquidShadowAlphaFor(int colorIdx, {required bool isHidden}) {
  if (isHidden) return 0.0;
  final lum = colorLuminanceForIndex(colorIdx);
  if (lum < 0.10) return 0.04;
  if (lum < 0.20) return 0.05;
  return 0.05;
}

Color visibleLiquidFillForIndex(int colorIdx) {
  return solidColorForIndex(colorIdx);
}
