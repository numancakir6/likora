import 'package:flutter/material.dart';
import '../../puzzle_presets.dart';

const List<Map<String, dynamic>> kColors = [
  // 🎯 ANA RENKLER
  {'name': 'Kırmızı', 'fill': Color(0xFFFF0000)}, // 0
  {'name': 'Turuncu', 'fill': Color(0xFFFF7A00)}, // 1
  {'name': 'Sarı', 'fill': Color(0xFFFFFF00)}, // 2
  {'name': 'Yeşil', 'fill': Color(0xFF00C853)}, // 3
  {'name': 'Mavi', 'fill': Color(0xFF0000FF)}, // 4

  // 🌈 ANA RENKLERDEN UZAK, BİRBİRİNDEN NET AYRILAN EK RENKLER
  {'name': 'Mor', 'fill': Color(0xFF6A0DAD)}, // 5
  {'name': 'Camgöbeği', 'fill': Color(0xFF00E5FF)}, // 6
  {'name': 'Lime', 'fill': Color(0xFFB2FF00)}, // 7
  {'name': 'Kahverengi', 'fill': Color(0xFF6D4C41)}, // 8
  {'name': 'Bordo', 'fill': Color(0xFF8B0000)}, // 9
  {'name': 'Pembe', 'fill': Color(0xFFFF4FA3)}, // 10
  {'name': 'Zeytin', 'fill': Color(0xFF808000)}, // 11
  {'name': 'Gri', 'fill': Color(0xFF9E9E9E)}, // 12
  {'name': 'Beyaz', 'fill': Color(0xFFFFFFFF)}, // 13

  // ➕ 16. indexte lavı korumak için ek renkler
  {'name': 'Lacivert', 'fill': Color(0xFF001F54)}, // 14
  {'name': 'Mint', 'fill': Color(0xFF00C2A8)}, // 15

  // 🔥 SADECE MAP 3 LAV RENGİ
  {'name': 'Lav', 'fill': Color(0xFFFF3B00)}, // 16
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
