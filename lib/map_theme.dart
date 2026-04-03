import 'dart:math';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
//  MAP THEME SYSTEM
// ═══════════════════════════════════════════════════════════════

enum MapBackgroundStyle {
  cosmicNebula,
  deepOcean,
  volcanicForge,
  frozenTundra,
  ancientForest,
  stormClouds,
  desertMirage,
  shadowRealm,
  crystalCaves,
  goldenTemple,
  neonCity,
  bloodMoon,
  arcticAurora,
  sacredLight,
  voidAbyss,
}

class MapTheme {
  final int mapNumber;
  final String name;
  final String subtitle;
  final String lore;

  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color bgDark;
  final Color bgMid;
  final Color bgLight;

  final List<Color> pathGradient;

  final Color nodeCompletedTop;
  final Color nodeCompletedBottom;

  final Color nodeActiveTop;
  final Color nodeActiveBottom;

  final MapBackgroundStyle bgStyle;
  final IconData progressIcon;

  const MapTheme({
    required this.mapNumber,
    required this.name,
    required this.subtitle,
    required this.lore,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.bgDark,
    required this.bgMid,
    required this.bgLight,
    required this.pathGradient,
    required this.nodeCompletedTop,
    required this.nodeCompletedBottom,
    required this.nodeActiveTop,
    required this.nodeActiveBottom,
    required this.bgStyle,
    required this.progressIcon,
  });
}

// ═══════════════════════════════════════════════════════════════
//  NEW MAP LAYOUT SYSTEM
// ═══════════════════════════════════════════════════════════════

class MapNode {
  final int id;
  final double x;
  final double y;

  const MapNode({
    required this.id,
    required this.x,
    required this.y,
  });
}

class MapConnection {
  final int from;
  final int to;

  const MapConnection(this.from, this.to);
}

class MapLayoutData {
  final int mapNumber;
  final int totalLevels;
  final List<MapNode> nodes;
  final List<MapConnection> connections;

  const MapLayoutData({
    required this.mapNumber,
    required this.totalLevels,
    required this.nodes,
    required this.connections,
  });
}

// ═══════════════════════════════════════════════════════════════
//  15 HARİTA TEMASI
// ═══════════════════════════════════════════════════════════════

const List<MapTheme> kMapThemes = [
  MapTheme(
    mapNumber: 1,
    name: 'KOZMİK BULUT',
    subtitle: 'Yıldızlara açılan yol',
    lore: 'Yıldız tozlarının arasında saklı, kadim bir geçit seni çağırıyor.',
    primaryColor: Color(0xFFF50057),
    secondaryColor: Color(0xFF7C4DFF),
    accentColor: Color(0xFFD500F9),
    bgDark: Color(0xFF08050D),
    bgMid: Color(0xFF12091A),
    bgLight: Color(0xFF1A0B22),
    pathGradient: [Color(0xFF7C4DFF), Color(0xFFF50057), Color(0xFFFF8A00)],
    nodeCompletedTop: Color(0xFF13F08B),
    nodeCompletedBottom: Color(0xFF0A8048),
    nodeActiveTop: Color(0xFFFF2E78),
    nodeActiveBottom: Color(0xFF8B0F40),
    bgStyle: MapBackgroundStyle.cosmicNebula,
    progressIcon: Icons.alt_route_rounded,
  ),
  MapTheme(
    mapNumber: 2,
    name: 'DERİN SULAR',
    subtitle: 'Sessizliğin altındaki akıntı',
    lore: 'Işığın erişemediği diplerde, unutulmuş bir rota parıldıyor.',
    primaryColor: Color(0xFF00B0FF),
    secondaryColor: Color(0xFF0D47A1),
    accentColor: Color(0xFF00E5FF),
    bgDark: Color(0xFF020B18),
    bgMid: Color(0xFF061428),
    bgLight: Color(0xFF0A1F3A),
    pathGradient: [Color(0xFF0D47A1), Color(0xFF00B0FF), Color(0xFF00E5FF)],
    nodeCompletedTop: Color(0xFF00E5FF),
    nodeCompletedBottom: Color(0xFF0077B6),
    nodeActiveTop: Color(0xFF29B6F6),
    nodeActiveBottom: Color(0xFF01579B),
    bgStyle: MapBackgroundStyle.deepOcean,
    progressIcon: Icons.waves_rounded,
  ),
  MapTheme(
    mapNumber: 3,
    name: 'VOLKAN YÜREĞİ',
    subtitle: 'Alevlerin içinden geç',
    lore: 'Kor gibi atan taşların altında, eski bir güç yeniden uyanıyor.',
    primaryColor: Color(0xFFFF6D00),
    secondaryColor: Color(0xFFDD2C00),
    accentColor: Color(0xFFFFD600),
    bgDark: Color(0xFF120400),
    bgMid: Color(0xFF200800),
    bgLight: Color(0xFF2E0D00),
    pathGradient: [Color(0xFFDD2C00), Color(0xFFFF6D00), Color(0xFFFFD600)],
    nodeCompletedTop: Color(0xFFFFD600),
    nodeCompletedBottom: Color(0xFFE65100),
    nodeActiveTop: Color(0xFFFF9100),
    nodeActiveBottom: Color(0xFFBF360C),
    bgStyle: MapBackgroundStyle.volcanicForge,
    progressIcon: Icons.local_fire_department_rounded,
  ),
  MapTheme(
    mapNumber: 4,
    name: 'BUZ TUNDARASI',
    subtitle: 'Sessizliğin donduğu yer',
    lore: 'Asırlardır uyuyan buz, şimdi derinlerden çatırdamaya başlıyor.',
    primaryColor: Color(0xFF80D8FF),
    secondaryColor: Color(0xFF0288D1),
    accentColor: Color(0xFFE1F5FE),
    bgDark: Color(0xFF030C12),
    bgMid: Color(0xFF061520),
    bgLight: Color(0xFF0A1F2E),
    pathGradient: [Color(0xFF0288D1), Color(0xFF80D8FF), Color(0xFFE1F5FE)],
    nodeCompletedTop: Color(0xFFB3E5FC),
    nodeCompletedBottom: Color(0xFF0277BD),
    nodeActiveTop: Color(0xFF81D4FA),
    nodeActiveBottom: Color(0xFF01579B),
    bgStyle: MapBackgroundStyle.frozenTundra,
    progressIcon: Icons.ac_unit_rounded,
  ),
  MapTheme(
    mapNumber: 5,
    name: 'KADIM ORMAN',
    subtitle: 'Köklerin fısıldadığı sır',
    lore: 'Her dal bir anı, her kök gömülü bir hikâye taşıyor.',
    primaryColor: Color(0xFF69F0AE),
    secondaryColor: Color(0xFF1B5E20),
    accentColor: Color(0xFFCCFF90),
    bgDark: Color(0xFF020A04),
    bgMid: Color(0xFF051408),
    bgLight: Color(0xFF081F0C),
    pathGradient: [Color(0xFF1B5E20), Color(0xFF43A047), Color(0xFF69F0AE)],
    nodeCompletedTop: Color(0xFF69F0AE),
    nodeCompletedBottom: Color(0xFF2E7D32),
    nodeActiveTop: Color(0xFFB9F6CA),
    nodeActiveBottom: Color(0xFF1B5E20),
    bgStyle: MapBackgroundStyle.ancientForest,
    progressIcon: Icons.park_rounded,
  ),
  MapTheme(
    mapNumber: 6,
    name: 'FIRTINA GÖĞÜ',
    subtitle: 'Şimşeğin izinde',
    lore: 'Göğün damarlarında dolaşan öfke, yolunu yıldırımlarla çiziyor.',
    primaryColor: Color(0xFFEEFF41),
    secondaryColor: Color(0xFF424242),
    accentColor: Color(0xFFFFFF00),
    bgDark: Color(0xFF0A0A0A),
    bgMid: Color(0xFF141414),
    bgLight: Color(0xFF1E1E1E),
    pathGradient: [Color(0xFF616161), Color(0xFFBDBDBD), Color(0xFFEEFF41)],
    nodeCompletedTop: Color(0xFFEEFF41),
    nodeCompletedBottom: Color(0xFF827717),
    nodeActiveTop: Color(0xFFFFF176),
    nodeActiveBottom: Color(0xFFF9A825),
    bgStyle: MapBackgroundStyle.stormClouds,
    progressIcon: Icons.thunderstorm_rounded,
  ),
  MapTheme(
    mapNumber: 7,
    name: 'SERAP ÇÖLÜ',
    subtitle: 'Kumların sakladığı iz',
    lore: 'Ufukta titreşen görüntüler arasında, gömülü bir çağrı yükseliyor.',
    primaryColor: Color(0xFFFFCA28),
    secondaryColor: Color(0xFFE65100),
    accentColor: Color(0xFFFFF8E1),
    bgDark: Color(0xFF0F0800),
    bgMid: Color(0xFF1A1000),
    bgLight: Color(0xFF261800),
    pathGradient: [Color(0xFFE65100), Color(0xFFFFCA28), Color(0xFFFFF8E1)],
    nodeCompletedTop: Color(0xFFFFCA28),
    nodeCompletedBottom: Color(0xFFE65100),
    nodeActiveTop: Color(0xFFFFE082),
    nodeActiveBottom: Color(0xFFBF360C),
    bgStyle: MapBackgroundStyle.desertMirage,
    progressIcon: Icons.landscape_rounded,
  ),
  MapTheme(
    mapNumber: 8,
    name: 'GÖLGE ÂLEMİ',
    subtitle: 'Karanlığın kırılan geometrisi',
    lore: 'Gerçeklik bükülüyor; gölgelerin içindeki labirent seni bekliyor.',
    primaryColor: Color(0xFFCE93D8),
    secondaryColor: Color(0xFF4A148C),
    accentColor: Color(0xFFEA80FC),
    bgDark: Color(0xFF07020E),
    bgMid: Color(0xFF0D0518),
    bgLight: Color(0xFF130822),
    pathGradient: [Color(0xFF4A148C), Color(0xFF9C27B0), Color(0xFFEA80FC)],
    nodeCompletedTop: Color(0xFFCE93D8),
    nodeCompletedBottom: Color(0xFF6A1B9A),
    nodeActiveTop: Color(0xFFEA80FC),
    nodeActiveBottom: Color(0xFF4A148C),
    bgStyle: MapBackgroundStyle.shadowRealm,
    progressIcon: Icons.hexagon_rounded,
  ),
  MapTheme(
    mapNumber: 9,
    name: 'KRİSTAL MAĞARASI',
    subtitle: 'Işığın yankılandığı derinlik',
    lore: 'Duvarlardaki her kristal, çağların içinden gelen bir anı saklıyor.',
    primaryColor: Color(0xFFE040FB),
    secondaryColor: Color(0xFF1A237E),
    accentColor: Color(0xFF40C4FF),
    bgDark: Color(0xFF04030F),
    bgMid: Color(0xFF080518),
    bgLight: Color(0xFF0D0822),
    pathGradient: [Color(0xFF1A237E), Color(0xFFE040FB), Color(0xFF40C4FF)],
    nodeCompletedTop: Color(0xFF40C4FF),
    nodeCompletedBottom: Color(0xFF1565C0),
    nodeActiveTop: Color(0xFFE040FB),
    nodeActiveBottom: Color(0xFF4A148C),
    bgStyle: MapBackgroundStyle.crystalCaves,
    progressIcon: Icons.diamond_rounded,
  ),
  MapTheme(
    mapNumber: 10,
    name: 'ALTIN TAPINAK',
    subtitle: 'Kadim bilginin eşiği',
    lore: 'Yitik bilgeliğin kapıları burada, sessizce açılmayı bekliyor.',
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFFB8860B),
    accentColor: Color(0xFFFFF8DC),
    bgDark: Color(0xFF0D0900),
    bgMid: Color(0xFF1A1200),
    bgLight: Color(0xFF261B00),
    pathGradient: [Color(0xFFB8860B), Color(0xFFFFD700), Color(0xFFFFF8DC)],
    nodeCompletedTop: Color(0xFFFFD700),
    nodeCompletedBottom: Color(0xFF8B6914),
    nodeActiveTop: Color(0xFFFFF176),
    nodeActiveBottom: Color(0xFFB8860B),
    bgStyle: MapBackgroundStyle.goldenTemple,
    progressIcon: Icons.temple_buddhist_rounded,
  ),
  MapTheme(
    mapNumber: 11,
    name: 'NEON ŞEHİR',
    subtitle: 'Verinin içindeki labirent',
    lore: 'Parlak ekranların altında, sistemin unuttuğu bir sır akıyor.',
    primaryColor: Color(0xFF00FF41),
    secondaryColor: Color(0xFF003B00),
    accentColor: Color(0xFF00FFFF),
    bgDark: Color(0xFF000500),
    bgMid: Color(0xFF010A01),
    bgLight: Color(0xFF020F02),
    pathGradient: [Color(0xFF003B00), Color(0xFF00FF41), Color(0xFF00FFFF)],
    nodeCompletedTop: Color(0xFF00FF41),
    nodeCompletedBottom: Color(0xFF005C00),
    nodeActiveTop: Color(0xFF00FFFF),
    nodeActiveBottom: Color(0xFF006464),
    bgStyle: MapBackgroundStyle.neonCity,
    progressIcon: Icons.blur_on_rounded,
  ),
  MapTheme(
    mapNumber: 12,
    name: 'KANLI AY',
    subtitle: 'Kızıl ufkun ardı',
    lore: 'Ay kana büründüğünde, mühürlü kapılar birer birer aralanıyor.',
    primaryColor: Color(0xFFEF5350),
    secondaryColor: Color(0xFF7F0000),
    accentColor: Color(0xFFFF8A80),
    bgDark: Color(0xFF0D0000),
    bgMid: Color(0xFF180000),
    bgLight: Color(0xFF220000),
    pathGradient: [Color(0xFF7F0000), Color(0xFFEF5350), Color(0xFFFF8A80)],
    nodeCompletedTop: Color(0xFFFF5252),
    nodeCompletedBottom: Color(0xFFB71C1C),
    nodeActiveTop: Color(0xFFFF8A80),
    nodeActiveBottom: Color(0xFF7F0000),
    bgStyle: MapBackgroundStyle.bloodMoon,
    progressIcon: Icons.nightlight_round,
  ),
  MapTheme(
    mapNumber: 13,
    name: 'KUTUP IŞIKLARI',
    subtitle: 'Göğün dans eden perdesi',
    lore: 'Soğuk gecede salınan ışıklar, yolunu usulca önüne seriyor.',
    primaryColor: Color(0xFF69F0AE),
    secondaryColor: Color(0xFF00695C),
    accentColor: Color(0xFFB2EBF2),
    bgDark: Color(0xFF000D0A),
    bgMid: Color(0xFF001A14),
    bgLight: Color(0xFF00261E),
    pathGradient: [Color(0xFF00695C), Color(0xFF26A69A), Color(0xFFB2EBF2)],
    nodeCompletedTop: Color(0xFF80CBC4),
    nodeCompletedBottom: Color(0xFF00695C),
    nodeActiveTop: Color(0xFFB2EBF2),
    nodeActiveBottom: Color(0xFF006064),
    bgStyle: MapBackgroundStyle.arcticAurora,
    progressIcon: Icons.architecture_rounded,
  ),
  MapTheme(
    mapNumber: 14,
    name: 'KUTSAL IŞIK',
    subtitle: 'Yazgının aydınlık izi',
    lore: 'Işığın özü önüne düşerken, inanç yolunu berraklaştırıyor.',
    primaryColor: Color(0xFFFFF9C4),
    secondaryColor: Color(0xFFF9A825),
    accentColor: Color(0xFFFFFFFF),
    bgDark: Color(0xFF0F0C00),
    bgMid: Color(0xFF1A1500),
    bgLight: Color(0xFF261F00),
    pathGradient: [Color(0xFFF9A825), Color(0xFFFFF9C4), Color(0xFFFFFFFF)],
    nodeCompletedTop: Color(0xFFFFF9C4),
    nodeCompletedBottom: Color(0xFFF9A825),
    nodeActiveTop: Color(0xFFFFFFFF),
    nodeActiveBottom: Color(0xFFFFF176),
    bgStyle: MapBackgroundStyle.sacredLight,
    progressIcon: Icons.flare_rounded,
  ),
  MapTheme(
    mapNumber: 15,
    name: 'BOŞLUK UÇURUMU',
    subtitle: 'Son ile başlangıç arasında',
    lore: 'Varlığın sınırında, her şeyin bittiği yerde sonsuz güç bekliyor.',
    primaryColor: Color(0xFFFFFFFF),
    secondaryColor: Color(0xFF212121),
    accentColor: Color(0xFFE0E0E0),
    bgDark: Color(0xFF000000),
    bgMid: Color(0xFF050505),
    bgLight: Color(0xFF0A0A0A),
    pathGradient: [Color(0xFF424242), Color(0xFFBDBDBD), Color(0xFFFFFFFF)],
    nodeCompletedTop: Color(0xFFFFFFFF),
    nodeCompletedBottom: Color(0xFF757575),
    nodeActiveTop: Color(0xFFE0E0E0),
    nodeActiveBottom: Color(0xFF212121),
    bgStyle: MapBackgroundStyle.voidAbyss,
    progressIcon: Icons.all_inclusive_rounded,
  ),
];

MapTheme getMapTheme(int mapNumber) {
  final idx = (mapNumber - 1).clamp(0, kMapThemes.length - 1);
  return kMapThemes[idx];
}

// ═══════════════════════════════════════════════════════════════
//  15 FARKLI HARİTA LAYOUT'U
// ═══════════════════════════════════════════════════════════════

final List<MapLayoutData> kMapLayouts = [
  MapLayoutData(
    mapNumber: 1,
    totalLevels: 10,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.92),
      MapNode(id: 2, x: 0.30, y: 0.78),
      MapNode(id: 3, x: 0.70, y: 0.78),
      MapNode(id: 4, x: 0.18, y: 0.60),
      MapNode(id: 5, x: 0.42, y: 0.58),
      MapNode(id: 6, x: 0.58, y: 0.58),
      MapNode(id: 7, x: 0.82, y: 0.60),
      MapNode(id: 8, x: 0.32, y: 0.34),
      MapNode(id: 9, x: 0.68, y: 0.34),
      MapNode(id: 10, x: 0.50, y: 0.12),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(2, 4),
      MapConnection(2, 5),
      MapConnection(3, 6),
      MapConnection(3, 7),
      MapConnection(5, 8),
      MapConnection(6, 9),
      MapConnection(8, 10),
      MapConnection(9, 10),
    ],
  ),
  MapLayoutData(
    mapNumber: 2,
    totalLevels: 12,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.93),
      MapNode(id: 2, x: 0.22, y: 0.82),
      MapNode(id: 3, x: 0.50, y: 0.80),
      MapNode(id: 4, x: 0.78, y: 0.82),
      MapNode(id: 5, x: 0.12, y: 0.64),
      MapNode(id: 6, x: 0.32, y: 0.62),
      MapNode(id: 7, x: 0.50, y: 0.58),
      MapNode(id: 8, x: 0.68, y: 0.62),
      MapNode(id: 9, x: 0.88, y: 0.64),
      MapNode(id: 10, x: 0.26, y: 0.36),
      MapNode(id: 11, x: 0.74, y: 0.36),
      MapNode(id: 12, x: 0.50, y: 0.12),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(2, 5),
      MapConnection(2, 6),
      MapConnection(3, 7),
      MapConnection(4, 8),
      MapConnection(4, 9),
      MapConnection(6, 10),
      MapConnection(7, 10),
      MapConnection(7, 11),
      MapConnection(8, 11),
      MapConnection(10, 12),
      MapConnection(11, 12),
    ],
  ),
  MapLayoutData(
    mapNumber: 3,
    totalLevels: 14,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.94),
      MapNode(id: 2, x: 0.28, y: 0.84),
      MapNode(id: 3, x: 0.72, y: 0.84),
      MapNode(id: 4, x: 0.15, y: 0.72),
      MapNode(id: 5, x: 0.40, y: 0.72),
      MapNode(id: 6, x: 0.60, y: 0.72),
      MapNode(id: 7, x: 0.85, y: 0.72),
      MapNode(id: 8, x: 0.18, y: 0.53),
      MapNode(id: 9, x: 0.38, y: 0.52),
      MapNode(id: 10, x: 0.62, y: 0.52),
      MapNode(id: 11, x: 0.82, y: 0.53),
      MapNode(id: 12, x: 0.30, y: 0.28),
      MapNode(id: 13, x: 0.70, y: 0.28),
      MapNode(id: 14, x: 0.50, y: 0.10),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(2, 4),
      MapConnection(2, 5),
      MapConnection(3, 6),
      MapConnection(3, 7),
      MapConnection(5, 8),
      MapConnection(5, 9),
      MapConnection(6, 10),
      MapConnection(6, 11),
      MapConnection(8, 12),
      MapConnection(9, 12),
      MapConnection(10, 13),
      MapConnection(11, 13),
      MapConnection(12, 14),
      MapConnection(13, 14),
    ],
  ),
  MapLayoutData(
    mapNumber: 4,
    totalLevels: 16,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.95),
      MapNode(id: 2, x: 0.20, y: 0.87),
      MapNode(id: 3, x: 0.50, y: 0.85),
      MapNode(id: 4, x: 0.80, y: 0.87),
      MapNode(id: 5, x: 0.10, y: 0.72),
      MapNode(id: 6, x: 0.30, y: 0.70),
      MapNode(id: 7, x: 0.50, y: 0.66),
      MapNode(id: 8, x: 0.70, y: 0.70),
      MapNode(id: 9, x: 0.90, y: 0.72),
      MapNode(id: 10, x: 0.18, y: 0.48),
      MapNode(id: 11, x: 0.38, y: 0.46),
      MapNode(id: 12, x: 0.62, y: 0.46),
      MapNode(id: 13, x: 0.82, y: 0.48),
      MapNode(id: 14, x: 0.30, y: 0.24),
      MapNode(id: 15, x: 0.70, y: 0.24),
      MapNode(id: 16, x: 0.50, y: 0.08),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(2, 5),
      MapConnection(2, 6),
      MapConnection(3, 7),
      MapConnection(4, 8),
      MapConnection(4, 9),
      MapConnection(6, 10),
      MapConnection(6, 11),
      MapConnection(7, 11),
      MapConnection(7, 12),
      MapConnection(8, 12),
      MapConnection(8, 13),
      MapConnection(10, 14),
      MapConnection(11, 14),
      MapConnection(12, 15),
      MapConnection(13, 15),
      MapConnection(14, 16),
      MapConnection(15, 16),
    ],
  ),
  MapLayoutData(
    mapNumber: 5,
    totalLevels: 11,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.92),
      MapNode(id: 2, x: 0.22, y: 0.82),
      MapNode(id: 3, x: 0.50, y: 0.76),
      MapNode(id: 4, x: 0.78, y: 0.82),
      MapNode(id: 5, x: 0.18, y: 0.58),
      MapNode(id: 6, x: 0.38, y: 0.56),
      MapNode(id: 7, x: 0.62, y: 0.56),
      MapNode(id: 8, x: 0.82, y: 0.58),
      MapNode(id: 9, x: 0.32, y: 0.30),
      MapNode(id: 10, x: 0.68, y: 0.30),
      MapNode(id: 11, x: 0.50, y: 0.10),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(2, 5),
      MapConnection(3, 6),
      MapConnection(3, 7),
      MapConnection(4, 8),
      MapConnection(6, 9),
      MapConnection(7, 10),
      MapConnection(9, 11),
      MapConnection(10, 11),
    ],
  ),
  MapLayoutData(
    mapNumber: 6,
    totalLevels: 13,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.93),
      MapNode(id: 2, x: 0.30, y: 0.82),
      MapNode(id: 3, x: 0.70, y: 0.82),
      MapNode(id: 4, x: 0.16, y: 0.68),
      MapNode(id: 5, x: 0.42, y: 0.66),
      MapNode(id: 6, x: 0.58, y: 0.66),
      MapNode(id: 7, x: 0.84, y: 0.68),
      MapNode(id: 8, x: 0.24, y: 0.48),
      MapNode(id: 9, x: 0.50, y: 0.46),
      MapNode(id: 10, x: 0.76, y: 0.48),
      MapNode(id: 11, x: 0.30, y: 0.24),
      MapNode(id: 12, x: 0.70, y: 0.24),
      MapNode(id: 13, x: 0.50, y: 0.08),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(2, 4),
      MapConnection(2, 5),
      MapConnection(3, 6),
      MapConnection(3, 7),
      MapConnection(4, 8),
      MapConnection(5, 9),
      MapConnection(6, 9),
      MapConnection(7, 10),
      MapConnection(8, 11),
      MapConnection(9, 11),
      MapConnection(9, 12),
      MapConnection(10, 12),
      MapConnection(11, 13),
      MapConnection(12, 13),
    ],
  ),
  MapLayoutData(
    mapNumber: 7,
    totalLevels: 15,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.94),
      MapNode(id: 2, x: 0.18, y: 0.84),
      MapNode(id: 3, x: 0.50, y: 0.82),
      MapNode(id: 4, x: 0.82, y: 0.84),
      MapNode(id: 5, x: 0.10, y: 0.68),
      MapNode(id: 6, x: 0.28, y: 0.66),
      MapNode(id: 7, x: 0.50, y: 0.60),
      MapNode(id: 8, x: 0.72, y: 0.66),
      MapNode(id: 9, x: 0.90, y: 0.68),
      MapNode(id: 10, x: 0.18, y: 0.42),
      MapNode(id: 11, x: 0.40, y: 0.40),
      MapNode(id: 12, x: 0.60, y: 0.40),
      MapNode(id: 13, x: 0.82, y: 0.42),
      MapNode(id: 14, x: 0.50, y: 0.20),
      MapNode(id: 15, x: 0.50, y: 0.06),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(2, 5),
      MapConnection(2, 6),
      MapConnection(3, 7),
      MapConnection(4, 8),
      MapConnection(4, 9),
      MapConnection(6, 10),
      MapConnection(7, 11),
      MapConnection(7, 12),
      MapConnection(8, 13),
      MapConnection(10, 14),
      MapConnection(11, 14),
      MapConnection(12, 14),
      MapConnection(13, 14),
      MapConnection(14, 15),
    ],
  ),
  MapLayoutData(
    mapNumber: 8,
    totalLevels: 9,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.92),
      MapNode(id: 2, x: 0.26, y: 0.76),
      MapNode(id: 3, x: 0.74, y: 0.76),
      MapNode(id: 4, x: 0.16, y: 0.54),
      MapNode(id: 5, x: 0.50, y: 0.54),
      MapNode(id: 6, x: 0.84, y: 0.54),
      MapNode(id: 7, x: 0.30, y: 0.28),
      MapNode(id: 8, x: 0.70, y: 0.28),
      MapNode(id: 9, x: 0.50, y: 0.08),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(2, 4),
      MapConnection(2, 5),
      MapConnection(3, 5),
      MapConnection(3, 6),
      MapConnection(4, 7),
      MapConnection(5, 7),
      MapConnection(5, 8),
      MapConnection(6, 8),
      MapConnection(7, 9),
      MapConnection(8, 9),
    ],
  ),
  MapLayoutData(
    mapNumber: 9,
    totalLevels: 12,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.92),
      MapNode(id: 2, x: 0.22, y: 0.80),
      MapNode(id: 3, x: 0.40, y: 0.70),
      MapNode(id: 4, x: 0.60, y: 0.70),
      MapNode(id: 5, x: 0.78, y: 0.80),
      MapNode(id: 6, x: 0.16, y: 0.50),
      MapNode(id: 7, x: 0.36, y: 0.46),
      MapNode(id: 8, x: 0.64, y: 0.46),
      MapNode(id: 9, x: 0.84, y: 0.50),
      MapNode(id: 10, x: 0.30, y: 0.24),
      MapNode(id: 11, x: 0.70, y: 0.24),
      MapNode(id: 12, x: 0.50, y: 0.08),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(1, 5),
      MapConnection(2, 6),
      MapConnection(3, 7),
      MapConnection(4, 8),
      MapConnection(5, 9),
      MapConnection(6, 10),
      MapConnection(7, 10),
      MapConnection(8, 11),
      MapConnection(9, 11),
      MapConnection(10, 12),
      MapConnection(11, 12),
    ],
  ),
  MapLayoutData(
    mapNumber: 10,
    totalLevels: 14,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.94),
      MapNode(id: 2, x: 0.22, y: 0.84),
      MapNode(id: 3, x: 0.78, y: 0.84),
      MapNode(id: 4, x: 0.10, y: 0.68),
      MapNode(id: 5, x: 0.34, y: 0.66),
      MapNode(id: 6, x: 0.50, y: 0.58),
      MapNode(id: 7, x: 0.66, y: 0.66),
      MapNode(id: 8, x: 0.90, y: 0.68),
      MapNode(id: 9, x: 0.20, y: 0.40),
      MapNode(id: 10, x: 0.40, y: 0.36),
      MapNode(id: 11, x: 0.60, y: 0.36),
      MapNode(id: 12, x: 0.80, y: 0.40),
      MapNode(id: 13, x: 0.50, y: 0.18),
      MapNode(id: 14, x: 0.50, y: 0.06),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(2, 4),
      MapConnection(2, 5),
      MapConnection(3, 7),
      MapConnection(3, 8),
      MapConnection(5, 6),
      MapConnection(7, 6),
      MapConnection(4, 9),
      MapConnection(5, 10),
      MapConnection(6, 10),
      MapConnection(6, 11),
      MapConnection(7, 11),
      MapConnection(8, 12),
      MapConnection(9, 13),
      MapConnection(10, 13),
      MapConnection(11, 13),
      MapConnection(12, 13),
      MapConnection(13, 14),
    ],
  ),
  MapLayoutData(
    mapNumber: 11,
    totalLevels: 13,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.93),
      MapNode(id: 2, x: 0.26, y: 0.82),
      MapNode(id: 3, x: 0.50, y: 0.76),
      MapNode(id: 4, x: 0.74, y: 0.82),
      MapNode(id: 5, x: 0.16, y: 0.62),
      MapNode(id: 6, x: 0.36, y: 0.58),
      MapNode(id: 7, x: 0.50, y: 0.50),
      MapNode(id: 8, x: 0.64, y: 0.58),
      MapNode(id: 9, x: 0.84, y: 0.62),
      MapNode(id: 10, x: 0.28, y: 0.30),
      MapNode(id: 11, x: 0.50, y: 0.24),
      MapNode(id: 12, x: 0.72, y: 0.30),
      MapNode(id: 13, x: 0.50, y: 0.08),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(2, 5),
      MapConnection(2, 6),
      MapConnection(3, 7),
      MapConnection(4, 8),
      MapConnection(4, 9),
      MapConnection(6, 10),
      MapConnection(7, 10),
      MapConnection(7, 11),
      MapConnection(8, 12),
      MapConnection(10, 13),
      MapConnection(11, 13),
      MapConnection(12, 13),
    ],
  ),
  MapLayoutData(
    mapNumber: 12,
    totalLevels: 16,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.95),
      MapNode(id: 2, x: 0.18, y: 0.86),
      MapNode(id: 3, x: 0.38, y: 0.80),
      MapNode(id: 4, x: 0.62, y: 0.80),
      MapNode(id: 5, x: 0.82, y: 0.86),
      MapNode(id: 6, x: 0.10, y: 0.66),
      MapNode(id: 7, x: 0.28, y: 0.62),
      MapNode(id: 8, x: 0.46, y: 0.58),
      MapNode(id: 9, x: 0.54, y: 0.58),
      MapNode(id: 10, x: 0.72, y: 0.62),
      MapNode(id: 11, x: 0.90, y: 0.66),
      MapNode(id: 12, x: 0.26, y: 0.36),
      MapNode(id: 13, x: 0.50, y: 0.30),
      MapNode(id: 14, x: 0.74, y: 0.36),
      MapNode(id: 15, x: 0.50, y: 0.16),
      MapNode(id: 16, x: 0.50, y: 0.05),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(1, 5),
      MapConnection(2, 6),
      MapConnection(3, 7),
      MapConnection(3, 8),
      MapConnection(4, 9),
      MapConnection(4, 10),
      MapConnection(5, 11),
      MapConnection(7, 12),
      MapConnection(8, 13),
      MapConnection(9, 13),
      MapConnection(10, 14),
      MapConnection(12, 15),
      MapConnection(13, 15),
      MapConnection(14, 15),
      MapConnection(15, 16),
    ],
  ),
  MapLayoutData(
    mapNumber: 13,
    totalLevels: 10,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.92),
      MapNode(id: 2, x: 0.24, y: 0.78),
      MapNode(id: 3, x: 0.76, y: 0.78),
      MapNode(id: 4, x: 0.14, y: 0.56),
      MapNode(id: 5, x: 0.38, y: 0.54),
      MapNode(id: 6, x: 0.62, y: 0.54),
      MapNode(id: 7, x: 0.86, y: 0.56),
      MapNode(id: 8, x: 0.30, y: 0.28),
      MapNode(id: 9, x: 0.70, y: 0.28),
      MapNode(id: 10, x: 0.50, y: 0.08),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(2, 4),
      MapConnection(2, 5),
      MapConnection(3, 6),
      MapConnection(3, 7),
      MapConnection(5, 8),
      MapConnection(6, 9),
      MapConnection(8, 10),
      MapConnection(9, 10),
    ],
  ),
  MapLayoutData(
    mapNumber: 14,
    totalLevels: 12,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.93),
      MapNode(id: 2, x: 0.20, y: 0.82),
      MapNode(id: 3, x: 0.50, y: 0.75),
      MapNode(id: 4, x: 0.80, y: 0.82),
      MapNode(id: 5, x: 0.14, y: 0.62),
      MapNode(id: 6, x: 0.36, y: 0.56),
      MapNode(id: 7, x: 0.64, y: 0.56),
      MapNode(id: 8, x: 0.86, y: 0.62),
      MapNode(id: 9, x: 0.28, y: 0.32),
      MapNode(id: 10, x: 0.50, y: 0.24),
      MapNode(id: 11, x: 0.72, y: 0.32),
      MapNode(id: 12, x: 0.50, y: 0.08),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(2, 5),
      MapConnection(3, 6),
      MapConnection(3, 7),
      MapConnection(4, 8),
      MapConnection(5, 9),
      MapConnection(6, 10),
      MapConnection(7, 10),
      MapConnection(8, 11),
      MapConnection(9, 12),
      MapConnection(10, 12),
      MapConnection(11, 12),
    ],
  ),
  MapLayoutData(
    mapNumber: 15,
    totalLevels: 18,
    nodes: const [
      MapNode(id: 1, x: 0.50, y: 0.96),
      MapNode(id: 2, x: 0.18, y: 0.88),
      MapNode(id: 3, x: 0.38, y: 0.84),
      MapNode(id: 4, x: 0.62, y: 0.84),
      MapNode(id: 5, x: 0.82, y: 0.88),
      MapNode(id: 6, x: 0.10, y: 0.70),
      MapNode(id: 7, x: 0.26, y: 0.66),
      MapNode(id: 8, x: 0.42, y: 0.62),
      MapNode(id: 9, x: 0.58, y: 0.62),
      MapNode(id: 10, x: 0.74, y: 0.66),
      MapNode(id: 11, x: 0.90, y: 0.70),
      MapNode(id: 12, x: 0.20, y: 0.44),
      MapNode(id: 13, x: 0.38, y: 0.38),
      MapNode(id: 14, x: 0.62, y: 0.38),
      MapNode(id: 15, x: 0.80, y: 0.44),
      MapNode(id: 16, x: 0.32, y: 0.18),
      MapNode(id: 17, x: 0.68, y: 0.18),
      MapNode(id: 18, x: 0.50, y: 0.05),
    ],
    connections: const [
      MapConnection(1, 2),
      MapConnection(1, 3),
      MapConnection(1, 4),
      MapConnection(1, 5),
      MapConnection(2, 6),
      MapConnection(2, 7),
      MapConnection(3, 7),
      MapConnection(3, 8),
      MapConnection(4, 9),
      MapConnection(4, 10),
      MapConnection(5, 10),
      MapConnection(5, 11),
      MapConnection(7, 12),
      MapConnection(8, 13),
      MapConnection(9, 14),
      MapConnection(10, 15),
      MapConnection(12, 16),
      MapConnection(13, 16),
      MapConnection(14, 17),
      MapConnection(15, 17),
      MapConnection(16, 18),
      MapConnection(17, 18),
    ],
  ),
];

MapLayoutData getMapLayout(int mapNumber) {
  final idx = (mapNumber - 1).clamp(0, kMapLayouts.length - 1);
  return kMapLayouts[idx];
}

// ═══════════════════════════════════════════════════════════════
//  BACKGROUND PAINTERS
// ═══════════════════════════════════════════════════════════════

CustomPainter buildMapBgPainter(MapTheme theme, double t) {
  switch (theme.bgStyle) {
    case MapBackgroundStyle.cosmicNebula:
      return _CosmicNebulaPainter(theme: theme, t: t);
    case MapBackgroundStyle.deepOcean:
      return _DeepOceanPainter(theme: theme, t: t);
    case MapBackgroundStyle.volcanicForge:
      return _VolcanicForgePainter(theme: theme, t: t);
    case MapBackgroundStyle.frozenTundra:
      return _FrozenTundraPainter(theme: theme, t: t);
    case MapBackgroundStyle.ancientForest:
      return _AncientForestPainter(theme: theme, t: t);
    case MapBackgroundStyle.stormClouds:
      return _StormCloudsPainter(theme: theme, t: t);
    case MapBackgroundStyle.desertMirage:
      return _DesertMiragePainter(theme: theme, t: t);
    case MapBackgroundStyle.shadowRealm:
      return _ShadowRealmPainter(theme: theme, t: t);
    case MapBackgroundStyle.crystalCaves:
      return _CrystalCavesPainter(theme: theme, t: t);
    case MapBackgroundStyle.goldenTemple:
      return _GoldenTemplePainter(theme: theme, t: t);
    case MapBackgroundStyle.neonCity:
      return _NeonCityPainter(theme: theme, t: t);
    case MapBackgroundStyle.bloodMoon:
      return _BloodMoonPainter(theme: theme, t: t);
    case MapBackgroundStyle.arcticAurora:
      return _ArcticAuroraPainter(theme: theme, t: t);
    case MapBackgroundStyle.sacredLight:
      return _SacredLightPainter(theme: theme, t: t);
    case MapBackgroundStyle.voidAbyss:
      return _VoidAbyssPainter(theme: theme, t: t);
  }
}

// ── Yardımcı ────────────────────────────────────────────────────

double _s(double t) => sin(t * pi * 2);
double _c(double t) => cos(t * pi * 2);

void _drawGlowOrb(Canvas canvas, Offset center, double radius, Color color,
    {double blur = 30}) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
}

// ── 1 · Cosmic Nebula (yıldız + bulut — mevcut stil) ─────────────

class _CosmicNebulaPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _CosmicNebulaPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawGlowOrb(canvas, Offset(w * 0.2 + _s(t) * 18, h * 0.25 + _c(t) * 12),
        h * 0.25, theme.primaryColor.withValues(alpha: 0.10));
    _drawGlowOrb(canvas, Offset(w * 0.8 + _c(t) * 14, h * 0.6 + _s(t) * 16),
        h * 0.22, theme.secondaryColor.withValues(alpha: 0.12));
    _drawGlowOrb(canvas, Offset(w * 0.5, h * 0.1 + _s(t * 1.3) * 10), h * 0.18,
        theme.accentColor.withValues(alpha: 0.08));
  }

  @override
  bool shouldRepaint(_CosmicNebulaPainter old) => old.t != t;
}

// ── 2 · Deep Ocean (dalgalar) ────────────────────────────────────

class _DeepOceanPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _DeepOceanPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dalga bantları
    for (int i = 0; i < 5; i++) {
      final yBase = h * (0.2 + i * 0.16);
      final path = Path();
      path.moveTo(0, yBase);
      for (double x = 0; x <= w; x += 4) {
        final y = yBase +
            sin((x / w * 2 * pi) + t * pi * 2 + i * 0.8) * h * 0.025 +
            cos((x / w * pi) + t * pi * 1.5) * h * 0.012;
        path.lineTo(x, y);
      }
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = theme.primaryColor.withValues(alpha: 0.03 + i * 0.008)
          ..style = PaintingStyle.fill,
      );
    }

    // Derin glow orbs
    _drawGlowOrb(canvas, Offset(w * 0.3, h * 0.7), h * 0.3,
        theme.accentColor.withValues(alpha: 0.08));
    _drawGlowOrb(canvas, Offset(w * 0.75, h * 0.3), h * 0.2,
        theme.primaryColor.withValues(alpha: 0.07));
  }

  @override
  bool shouldRepaint(_DeepOceanPainter old) => old.t != t;
}

// ── 3 · Volcanic Forge (lav damarları) ──────────────────────────

class _VolcanicForgePainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _VolcanicForgePainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Lav damarları
    final cracks = [
      [0.3, 1.0, 0.5, 0.5, 0.7, 0.0],
      [0.1, 0.8, 0.4, 0.4, 0.6, 0.1],
      [0.6, 0.9, 0.8, 0.45, 0.95, 0.05],
      [0.0, 0.6, 0.25, 0.3, 0.45, 0.0],
    ];

    for (final crack in cracks) {
      final path = Path()
        ..moveTo(w * crack[0], h * crack[1])
        ..quadraticBezierTo(
            w * crack[2], h * crack[3], w * crack[4], h * crack[5]);
      final pulse = 0.06 + sin(t * pi * 2 + crack[0] * 3) * 0.04;
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.accentColor.withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Alt yanardağ parlaması
    _drawGlowOrb(canvas, Offset(w * 0.5, h * 1.1), h * 0.45,
        theme.primaryColor.withValues(alpha: 0.18));
    _drawGlowOrb(canvas, Offset(w * 0.2, h * 0.8), h * 0.2,
        theme.secondaryColor.withValues(alpha: 0.12));
  }

  @override
  bool shouldRepaint(_VolcanicForgePainter old) => old.t != t;
}

// ── 4 · Frozen Tundra (buz kristalleri) ─────────────────────────

class _FrozenTundraPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _FrozenTundraPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Buz kristali çizgileri
    final crystalCenters = [
      Offset(w * 0.15, h * 0.2),
      Offset(w * 0.75, h * 0.15),
      Offset(w * 0.85, h * 0.7),
      Offset(w * 0.1, h * 0.75),
      Offset(w * 0.5, h * 0.45),
    ];

    for (final center in crystalCenters) {
      final pulse = 0.08 + sin(t * pi * 2 + center.dx) * 0.04;
      for (int i = 0; i < 6; i++) {
        final angle = i * pi / 3;
        final len = w * 0.07 + sin(t * pi + i) * w * 0.02;
        canvas.drawLine(
          center,
          Offset(center.dx + cos(angle) * len, center.dy + sin(angle) * len),
          Paint()
            ..color = theme.accentColor.withValues(alpha: pulse)
            ..strokeWidth = 1.0,
        );
      }
    }

    _drawGlowOrb(canvas, Offset(w * 0.5, h * 0.1), h * 0.35,
        theme.primaryColor.withValues(alpha: 0.07));
    _drawGlowOrb(canvas, Offset(w * 0.8, h * 0.8), h * 0.25,
        theme.accentColor.withValues(alpha: 0.06));
  }

  @override
  bool shouldRepaint(_FrozenTundraPainter old) => old.t != t;
}

// ── 5 · Ancient Forest (yaprak damarları) ───────────────────────

class _AncientForestPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _AncientForestPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Kök damar ağı
    void drawVein(Offset start, double angle, double len, int depth) {
      if (depth == 0 || len < 4) return;
      final end = Offset(
        start.dx + cos(angle) * len,
        start.dy + sin(angle) * len,
      );
      final pulse = 0.05 + sin(t * pi * 2 + depth * 0.5) * 0.03;
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = theme.primaryColor.withValues(alpha: pulse)
          ..strokeWidth = depth * 0.6,
      );
      drawVein(end, angle - 0.45, len * 0.65, depth - 1);
      drawVein(end, angle + 0.45, len * 0.65, depth - 1);
    }

    drawVein(Offset(w * 0.5, h), -pi / 2, h * 0.22, 5);
    drawVein(Offset(w * 0.2, h), -pi / 2.2, h * 0.18, 4);
    drawVein(Offset(w * 0.8, h), -pi / 1.85, h * 0.18, 4);

    _drawGlowOrb(canvas, Offset(w * 0.5, h * 0.5), h * 0.3,
        theme.accentColor.withValues(alpha: 0.07));
  }

  @override
  bool shouldRepaint(_AncientForestPainter old) => old.t != t;
}

// ── 6 · Storm Clouds (şimşek) ───────────────────────────────────

class _StormCloudsPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _StormCloudsPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Şimşek çakmaları (sabit hat, titreyen opaklık)
    final bolts = [
      [0.3, 0.0, 0.25, 0.35, 0.35, 0.6, 0.28, 1.0],
      [0.65, 0.0, 0.72, 0.28, 0.60, 0.55, 0.68, 0.9],
    ];

    for (final bolt in bolts) {
      final flash = (sin(t * pi * 4 + bolt[0] * 5)).abs();
      if (flash < 0.3) continue;
      final path = Path()
        ..moveTo(w * bolt[0], h * bolt[1])
        ..lineTo(w * bolt[2], h * bolt[3])
        ..lineTo(w * bolt[4], h * bolt[5])
        ..lineTo(w * bolt[6], h * bolt[7]);
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.accentColor.withValues(alpha: flash * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Fırtına bulutu kütleleri
    _drawGlowOrb(canvas, Offset(w * 0.3, h * 0.1), h * 0.25,
        theme.secondaryColor.withValues(alpha: 0.14));
    _drawGlowOrb(canvas, Offset(w * 0.7, h * 0.08), h * 0.22,
        theme.secondaryColor.withValues(alpha: 0.12));
  }

  @override
  bool shouldRepaint(_StormCloudsPainter old) => old.t != t;
}

// ── 7 · Desert Mirage (kum dalgaları) ───────────────────────────

class _DesertMiragePainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _DesertMiragePainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Kum tepeleri
    for (int i = 0; i < 4; i++) {
      final yBase = h * (0.4 + i * 0.18);
      final path = Path()..moveTo(0, yBase);
      for (double x = 0; x <= w; x += 3) {
        final y = yBase +
            sin(x / w * pi * 3 + t * pi * 0.8 + i) * h * 0.035 -
            i * h * 0.008;
        path.lineTo(x, y);
      }
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = theme.primaryColor.withValues(alpha: 0.04 + i * 0.006),
      );
    }

    // Sıcak ufuk parlaması
    _drawGlowOrb(canvas, Offset(w * 0.5, h * 1.0), h * 0.5,
        theme.secondaryColor.withValues(alpha: 0.12));
  }

  @override
  bool shouldRepaint(_DesertMiragePainter old) => old.t != t;
}

// ── 8 · Shadow Realm (geometrik ağ) ─────────────────────────────

class _ShadowRealmPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _ShadowRealmPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dönen geometrik çerçeveler
    final center = Offset(w / 2, h / 2);
    for (int i = 0; i < 4; i++) {
      final r = w * (0.15 + i * 0.12);
      final angle = t * pi * 2 * (i.isEven ? 1 : -1) + i * pi / 4;
      final path = Path()
        ..addPolygon(
          List.generate(
            4,
            (j) => Offset(
              center.dx + r * cos(angle + j * pi / 2),
              center.dy + r * sin(angle + j * pi / 2),
            ),
          ),
          true,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.primaryColor.withValues(alpha: 0.04 + i * 0.015)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    _drawGlowOrb(canvas, Offset(w * 0.5, h * 0.5), h * 0.35,
        theme.accentColor.withValues(alpha: 0.06));
  }

  @override
  bool shouldRepaint(_ShadowRealmPainter old) => old.t != t;
}

// ── 9 · Crystal Caves (kırık ışık prizmaları) ───────────────────

class _CrystalCavesPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _CrystalCavesPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Prizma üçgenleri
    final triangles = [
      [0.1, 0.2, 0.25, 0.05, 0.4, 0.25],
      [0.6, 0.1, 0.78, 0.0, 0.9, 0.2],
      [0.0, 0.55, 0.18, 0.4, 0.22, 0.65],
      [0.7, 0.5, 0.88, 0.35, 0.95, 0.6],
      [0.35, 0.75, 0.5, 0.6, 0.62, 0.8],
    ];

    for (int i = 0; i < triangles.length; i++) {
      final tri = triangles[i];
      final pulse = 0.06 + sin(t * pi * 2 + i * 1.2) * 0.04;
      final path = Path()
        ..moveTo(w * tri[0], h * tri[1])
        ..lineTo(w * tri[2], h * tri[3])
        ..lineTo(w * tri[4], h * tri[5])
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = (i.isEven ? theme.primaryColor : theme.accentColor)
              .withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = (i.isEven ? theme.primaryColor : theme.accentColor)
              .withValues(alpha: pulse * 0.3)
          ..style = PaintingStyle.fill,
      );
    }

    _drawGlowOrb(canvas, Offset(w * 0.5, h * 0.5), h * 0.4,
        theme.primaryColor.withValues(alpha: 0.06));
  }

  @override
  bool shouldRepaint(_CrystalCavesPainter old) => old.t != t;
}

// ── 10 · Golden Temple (spiral motifler) ────────────────────────

class _GoldenTemplePainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _GoldenTemplePainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Altın spiral
    final center = Offset(w * 0.5, h * 0.5);
    final path = Path();
    bool started = false;
    for (double a = 0; a < pi * 12; a += 0.05) {
      final r = a * w * 0.012;
      final x = center.dx + cos(a + t * pi * 2) * r;
      final y = center.dy + sin(a + t * pi * 2) * r;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.primaryColor.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Köşe süslemeler
    final corners = [
      Offset(w * 0.1, h * 0.1),
      Offset(w * 0.9, h * 0.1),
      Offset(w * 0.1, h * 0.9),
      Offset(w * 0.9, h * 0.9),
    ];
    for (final corner in corners) {
      _drawGlowOrb(
          canvas, corner, w * 0.06, theme.accentColor.withValues(alpha: 0.12),
          blur: 15);
    }

    _drawGlowOrb(
        canvas, center, h * 0.3, theme.primaryColor.withValues(alpha: 0.08));
  }

  @override
  bool shouldRepaint(_GoldenTemplePainter old) => old.t != t;
}

// ── 11 · Neon City (izgara) ──────────────────────────────────────

class _NeonCityPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _NeonCityPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Perspektif ızgara
    final vanish = Offset(w * 0.5, h * 0.45);
    const cols = 8;
    for (int i = 0; i <= cols; i++) {
      final x = w * i / cols;
      final pulse = 0.04 + sin(t * pi * 2 + i * 0.8) * 0.025;
      canvas.drawLine(
        Offset(x, h),
        vanish,
        Paint()
          ..color = theme.primaryColor.withValues(alpha: pulse)
          ..strokeWidth = 0.8,
      );
    }
    // Yatay ızgara çizgileri
    for (int j = 1; j <= 6; j++) {
      final y = h * (0.45 + j * 0.09);
      final xLeft = w * 0.5 - (w * 0.5) * (j / 6.0);
      final xRight = w * 0.5 + (w * 0.5) * (j / 6.0);
      final pulse = 0.04 + sin(t * pi * 2 + j * 1.1) * 0.02;
      canvas.drawLine(
        Offset(xLeft, y),
        Offset(xRight, y),
        Paint()
          ..color = theme.primaryColor.withValues(alpha: pulse)
          ..strokeWidth = 0.7,
      );
    }

    _drawGlowOrb(canvas, Offset(w * 0.5, h * 0.0), h * 0.3,
        theme.accentColor.withValues(alpha: 0.08));
  }

  @override
  bool shouldRepaint(_NeonCityPainter old) => old.t != t;
}

// ── 12 · Blood Moon (kırmızı sis + dolunay) ─────────────────────

class _BloodMoonPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _BloodMoonPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dolunay
    final moonPulse = 0.12 + sin(t * pi * 2) * 0.04;
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.1 + sin(t * pi) * h * 0.03),
      w * 0.14,
      Paint()..color = theme.primaryColor.withValues(alpha: moonPulse),
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.1 + sin(t * pi) * h * 0.03),
      w * 0.22,
      Paint()
        ..color = theme.primaryColor.withValues(alpha: moonPulse * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );

    // Kırmızı sis bantları
    for (int i = 0; i < 3; i++) {
      final drift = sin(t * pi * 1.5 + i * 1.2) * w * 0.08;
      _drawGlowOrb(
        canvas,
        Offset(w * (0.2 + i * 0.3) + drift, h * (0.5 + i * 0.15)),
        h * 0.18,
        theme.secondaryColor.withValues(alpha: 0.10),
      );
    }
  }

  @override
  bool shouldRepaint(_BloodMoonPainter old) => old.t != t;
}

// ── 13 · Arctic Aurora (kutup ışıkları) ─────────────────────────

class _ArcticAuroraPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _ArcticAuroraPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Aurora şeritleri
    for (int i = 0; i < 4; i++) {
      final path = Path();
      final baseY = h * (0.05 + i * 0.1);
      path.moveTo(0, baseY);
      for (double x = 0; x <= w; x += 3) {
        final y =
            baseY + sin(x / w * pi * 2.5 + t * pi * 1.8 + i * 0.7) * h * 0.06;
        path.lineTo(x, y);
      }
      final opacity = 0.06 + sin(t * pi * 2 + i * 1.3) * 0.04;
      canvas.drawPath(
        path,
        Paint()
          ..color = (i.isEven ? theme.primaryColor : theme.accentColor)
              .withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcticAuroraPainter old) => old.t != t;
}

// ── 14 · Sacred Light (hale ışınları) ───────────────────────────

class _SacredLightPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _SacredLightPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.08);

    // Işın demetleri
    const rayCount = 12;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * pi * 2 + t * pi * 0.5;
      final len = h * (0.45 + sin(t * pi * 2 + i * 0.5) * 0.1);
      final opacity = 0.04 + sin(t * pi + i * 0.8).abs() * 0.04;
      canvas.drawLine(
        center,
        Offset(center.dx + cos(angle) * len, center.dy + sin(angle) * len),
        Paint()
          ..color = theme.primaryColor.withValues(alpha: opacity)
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    _drawGlowOrb(
        canvas, center, h * 0.18, theme.primaryColor.withValues(alpha: 0.12));
    _drawGlowOrb(canvas, Offset(w * 0.5, h * 0.5), h * 0.4,
        theme.primaryColor.withValues(alpha: 0.04));
  }

  @override
  bool shouldRepaint(_SacredLightPainter old) => old.t != t;
}

// ── 15 · Void Abyss (beyaz enerji darbesi) ──────────────────────

class _VoidAbyssPainter extends CustomPainter {
  final MapTheme theme;
  final double t;
  const _VoidAbyssPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);

    // Yayılan halkalar
    for (int i = 0; i < 5; i++) {
      final phase = (t + i * 0.2) % 1.0;
      final radius = phase * w * 0.7;
      final opacity = (1.0 - phase) * 0.08;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = theme.primaryColor.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Merkez parlama
    _drawGlowOrb(canvas, center, h * 0.08,
        theme.primaryColor.withValues(alpha: 0.18 + sin(t * pi * 2) * 0.08));
    _drawGlowOrb(
        canvas, center, h * 0.25, theme.primaryColor.withValues(alpha: 0.05));
  }

  @override
  bool shouldRepaint(_VoidAbyssPainter old) => old.t != t;
}
