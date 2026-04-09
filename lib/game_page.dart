import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'map_theme.dart';
import 'map_page.dart';
import 'puzzle_presets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'player_progress.dart';
import 'settings_page.dart';
import 'audio_service.dart';
import 'daily_puzzle_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ─────────────────────────────────────────────
// OYUN SABİTLERİ
// ─────────────────────────────────────────────

const int kCap = 4;
const int kNColors = 18;
const int kEmpty = 2;
const String kTubeSvgAsset = 'assets/likora/test_tube.svg';
const String kTubeLargeSvgAsset = 'assets/likora/test_tube_large.svg';
const String kVolcanoReservoirSvgAsset = 'assets/likora/volkan_hazne.png';

// Widget boyutları – SVG oranına göre ayarlandı (84.4 x 182 mm → 60 x 130 px)
const double kTW = 72.0;
const double kTH = 155.0;
const double kBasinW = 236.0;
const double kBasinH = 128.0;

// ── SVG oranları (viewBox: 8442.66 x 18197.8) ──────────────────────────────
// Normalize faktör:
//   scaleX = kTW / 8442.66 = 60 / 8442.66 ≈ 0.007109
//   scaleY = kTH / 18197.8 = 130 / 18197.8 ≈ 0.007144
//
// SVG bileşenleri:
//  [Kapak/Tıpa] fil3: y=34.19..y=34.19+995.08+262.05 ≈ 0..1257
//               normalized → 0..8.98 px  (kapak yüksekliği ≈ 9 px)
//  [Sol gövde]  fil0: x=814.03, y=995.08, w=611.47, h=14850
//               normalized → x=5.78, y=7.11, w=4.34, h=106.1
//  [Sağ gövde]  fil1: x=7016.09, y=995.08, w=611.47, h=14850
//               normalized → x=49.88, y=7.11, w=4.34, h=106.1
//  [Alt U]      fil2: y=15583..18203  normalized → y=111.3..130.0
//  [Kapak]      fil3 üst bölüm: y=34.19..1257  normalized → y=0.24..8.98
//  [Sol parlama] fil5: x=1905, w=349  normalized → x=13.5, w=2.48
//  [Sol çizgi]  str1: x=945  normalized → x=6.72
//  [Sağ gölge]  fil8: x=6710, w=262  normalized → x=47.7, w=1.86

// ── Türetilmiş sabitler ──────────────────────────────────────────────────────
const double _svgW = 8442.66;
const double _svgH = 18197.8;
double get _sx => kTW / _svgW;
double get _sy => kTH / _svgH;

// Kapak (tıpa) – SVG fil3 üst bölümü
// SVG'de kapak y=34.19'dan başlar, yüksekliği 995.08+262.05 ≈ 1257 svgpx
const double _capTopSvg = 34.19;
const double _capBotSvg = 1257.13; // linearGradient id1 bitiş Y'si
// Flutter:
double get kCapTopY => _capTopSvg * _sy; //  ≈ 0.24
double get kCapBotY => _capBotSvg * _sy; //  ≈ 8.98

// Gövde başlangıcı (kapak altı + biraz boşluk)
// SVG sol rect y=995.08
double get kBodyTopSvg => 995.08;
double get kBodyTopY => kBodyTopSvg * _sy; // ≈ 7.11

// Gövde sol & sağ (SVG rect'ler)
double get kBodyLeftX => 814.03 * _sx; //  ≈ 5.78
double get kBodyRightX => (7016.09 + 611.47) * _sx; // ≈ 54.22
double get kBodyInnerLeft => (814.03 + 611.47) * _sx; // ≈ 10.12
double get kBodyInnerRight => 7016.09 * _sx; //  ≈ 49.88
double get kBodyInnerW => kBodyInnerRight - kBodyInnerLeft; // ≈ 39.76

// Gövde alt (yükseklik)
double get kBodyBotSvg => 995.08 + 14850.0; // = 15845.08
double get kBodyBotY => kBodyBotSvg * _sy; // ≈ 113.1

// Alt U yarıçapı (iç alan genişliğinin yarısı)
double get kTR => kBodyInnerW / 2; // ≈ 19.88

// Alt U merkezi Y
double get kUCenterY => kBodyBotY; // daire merkezi tam gövde altında

// Sıvı için iç alan – duvarlara tam yapışık, üstte küçük boşluk
double get kLiquidLeft => kBodyInnerLeft + 3;
double get kLiquidRight => kBodyInnerRight - 3;
double get kLiquidW => kLiquidRight - kLiquidLeft;
double get kLiquidTopY => kCapBotY + 19.0;
double get kMouthEntryY => kCapBotY + 4.0;
double get kLiquidBotY => kBodyBotY + kTR - 14;

// Widget toplam yüksekliği
// Alt U'nun en altı: SVG'de y=18197.8 → kTH
double get kWidgetH => kTH;
double get kWidgetW => kTW;
const double kTubeGap = 3.0;
const double kRowGap = 18.0;

double get kStageW => (kWidgetW * 5) + (kTubeGap * 4) + 12.0;
double get kStageH => (kWidgetH * 4) + (kRowGap * 3) + 18.0;

class _ResolvedStageLayout {
  final StageLayout modeLayout;
  final List<List<int>> rows;
  final List<double> rowTopPaddings;
  final List<StageTubePosition> positions;
  final double tubeGap;
  final double rowGap;
  final double topOffset;
  final double width;
  final double height;

  const _ResolvedStageLayout({
    required this.modeLayout,
    required this.rows,
    required this.rowTopPaddings,
    required this.positions,
    required this.tubeGap,
    required this.rowGap,
    required this.topOffset,
    required this.width,
    required this.height,
  });
}

_ResolvedStageLayout resolveStageLayout({
  required StageLayout? layout,
  required int tubeCount,
}) {
  final effective = layout ?? StageLayout.standardForTubeCount(tubeCount);

  if (effective.mode == StageLayoutMode.manual &&
      effective.positions.isNotEmpty) {
    final positions = effective.positions
        .where((p) => p.index >= 0 && p.index < tubeCount)
        .toList(growable: false);

    final maxRight = positions.isEmpty
        ? kWidgetW
        : positions.map((p) => p.x + kWidgetW).reduce(max);
    final maxBottom = positions.isEmpty
        ? kWidgetH
        : positions.map((p) => p.y + kWidgetH).reduce(max);

    return _ResolvedStageLayout(
      modeLayout: effective,
      rows: const [],
      rowTopPaddings: const [],
      positions: positions,
      tubeGap: effective.tubeGap,
      rowGap: effective.rowGap,
      topOffset: effective.topOffset,
      width: max((effective.canvasWidth ?? maxRight) + 12.0, kWidgetW + 12.0),
      height: max(
          (effective.canvasHeight ?? maxBottom) +
              effective.topOffset +
              150.0, // 👈 boşluk
          kWidgetH + 150.0),
    );
  }

  var rows = effective.rows
      .map((row) => row
          .where((idx) => idx >= 0 && idx < tubeCount)
          .toList(growable: false))
      .where((row) => row.isNotEmpty)
      .toList(growable: false);

  if (rows.isEmpty) {
    rows = StageLayout.standardForTubeCount(tubeCount).rows;
  }

  final rowTopPaddings = List<double>.generate(
    rows.length,
    (i) =>
        i < effective.rowTopPaddings.length ? effective.rowTopPaddings[i] : 0.0,
    growable: false,
  );

  final maxRowCount = rows.fold<int>(0, (m, row) => max(m, row.length));
  final width = (maxRowCount * kWidgetW) +
      (max(0, maxRowCount - 1) * effective.tubeGap) +
      12.0;
  final totalPads = rowTopPaddings.fold<double>(0.0, (a, b) => a + b);
  final height = effective.topOffset +
      (rows.length * kWidgetH) +
      totalPads +
      (max(0, rows.length - 1) * effective.rowGap) +
      18.0;

  return _ResolvedStageLayout(
    modeLayout: effective,
    rows: rows,
    rowTopPaddings: rowTopPaddings,
    positions: const [],
    tubeGap: effective.tubeGap,
    rowGap: effective.rowGap,
    topOffset: effective.topOffset,
    width: width,
    height: height,
  );
}

const Duration kPourDuration = Duration(milliseconds: 1800);

const List<Map<String, dynamic>> kColors = [
  // 🎯 ANA RENKLER (SAF - TEK) — index 0..4
  {'name': 'Kırmızı', 'fill': Color(0xFFFF0000)},
  {'name': 'Turuncu', 'fill': Color(0xFFFF7A00)},
  {'name': 'Sarı', 'fill': Color(0xFFFFFF00)},
  {'name': 'Yeşil', 'fill': Color(0xFF00C853)},
  {'name': 'Mavi', 'fill': Color(0xFF0000FF)},

  // ⚡ UÇUK / NEON / FARKLI RENKLER — index 5..10
  {'name': 'Fuşya', 'fill': Color(0xFFFF00FF)},
  {'name': 'Neon Yeşil', 'fill': Color.fromARGB(255, 76, 252, 45)},
  {'name': 'Camgöbeği', 'fill': Color(0xFF00FFFF)},
  {'name': 'Elektrik Mavi', 'fill': Color(0xFF2979FF)},
  {'name': 'Pembe', 'fill': Color(0xFFFF1493)},
  {'name': 'Açık Mor (Neon)', 'fill': Color(0xFFB266FF)},

  // ⚫⚪ KONTRAST RENKLER — index 11..12
  {'name': 'Beyaz', 'fill': Color(0xFFFFFFFF)},
  {'name': 'Siyah', 'fill': Color(0xFF000000)},

  // 🆕 YENİ RENKLER — index 13..17
  // Mevcut paletten en uzak: koyu zeytin, altın/amber, derin teal, kızıl kahve, çilek/mercan
  {
    'name': 'Zeytin',
    'fill': Color(0xFF8BC34A)
  }, // sarı-yeşil arası, mevcut hiçbiriyle çakışmıyor
  {
    'name': 'Amber',
    'fill': Color(0xFFFFAB00)
  }, // koyu sarı-turuncu arası; mevcut turuncu ve sarıdan belirgin farklı ton
  {
    'name': 'Teal',
    'fill': Color(0xFF00897B)
  }, // koyu yeşil-mavi; camgöbeği ve yeşilden çok uzak
  {
    'name': 'Kiremit',
    'fill': Color(0xFFBF360C)
  }, // koyu kırmızı-turuncu; kırmızıdan ve turuncudan belirgin farklı
  {
    'name': 'Leylak',
    'fill': Color(0xFF7B1FA2)
  }, // koyu mor; açık mor (neon) ve maviden çok uzak
];

const Color kLavaDark = Color(0xFF4A0B00);
const Color kLavaRed = Color(0xFFC62828);
const Color kLavaOrange = Color(0xFFFF6F00);
const Color kLavaGlow = Color(0xFFFFD54F);
const Color kLavaCore = Color(0xFFFFF59D);

bool _isLavaColorIndex(int colorIdx) => colorIdx == kLavaColorIndex;
Color _solidColorForIndex(int colorIdx) =>
    kColors[colorIdx.clamp(0, kColors.length - 1).toInt()]['fill'] as Color;

// _MapTheme ve _themeForMap kaldırıldı — MapTheme artık map_theme.dart'tan geliyor.

// ─────────────────────────────────────────────
// OYUN MANTIĞI
// ─────────────────────────────────────────────

List<List<int>> legacyGenerateTubes({
  required int level,
  required int difficulty,
}) {
  final patterns = <List<List<int>>>[
    [
      [0, 1, 2, 3],
      [4, 5, 6, 7],
      [1, 2, 3, 4],
      [5, 6, 7, 0],
      [2, 3, 4, 5],
      [6, 7, 0, 1],
      [3, 4, 5, 6],
      [7, 0, 1, 2],
      [],
      [],
      [],
    ],
    [
      [0, 4, 1, 5],
      [2, 6, 3, 7],
      [1, 5, 2, 6],
      [3, 7, 4, 0],
      [2, 6, 5, 1],
      [4, 0, 7, 3],
      [5, 1, 6, 2],
      [7, 3, 0, 4],
      [],
      [],
      [],
    ],
    [
      [0, 2, 4, 6],
      [1, 3, 5, 7],
      [2, 4, 6, 1],
      [3, 5, 7, 0],
      [4, 6, 1, 3],
      [5, 7, 0, 2],
      [6, 1, 3, 5],
      [7, 0, 2, 4],
      [],
      [],
      [],
    ],
    [
      [0, 3, 1, 4],
      [2, 5, 6, 7],
      [1, 4, 2, 5],
      [6, 7, 0, 3],
      [2, 5, 3, 6],
      [7, 0, 4, 1],
      [3, 6, 5, 2],
      [4, 1, 7, 0],
      [],
      [],
      [],
    ],
    [
      [0, 5, 2, 7],
      [1, 6, 3, 4],
      [2, 7, 4, 1],
      [3, 0, 5, 6],
      [4, 1, 6, 3],
      [5, 2, 7, 0],
      [6, 3, 0, 5],
      [7, 4, 1, 2],
      [],
      [],
      [],
    ],
  ];

  final safeDifficulty = difficulty.clamp(1, 5);
  final patternIndex = (level + safeDifficulty - 2) % patterns.length;
  final chosen = patterns[patternIndex];
  return chosen
      .map((tube) => List<int>.of(tube, growable: true))
      .toList(growable: true);
}

bool canPour(List<List<int>> tubes, int from, int to) {
  if (tubes[from].isEmpty) return false;
  if (tubes[to].length >= kCap) return false;
  final top = tubes[from].last;
  if (tubes[to].isNotEmpty && tubes[to].last != top) return false;
  return true;
}

int pourCount(List<List<int>> tubes, int from, int to) {
  if (!canPour(tubes, from, to)) return 0;
  final top = tubes[from].last;
  int count = 0;
  final available = kCap - tubes[to].length;
  for (int i = tubes[from].length - 1; i >= 0; i--) {
    if (tubes[from][i] == top)
      count++;
    else
      break;
  }
  return count.clamp(0, available);
}

void doPour(List<List<int>> tubes, int from, int to) {
  final fromTube = List<int>.from(tubes[from]);
  final toTube = List<int>.from(tubes[to]);

  final top = fromTube.last;
  while (fromTube.isNotEmpty && fromTube.last == top && toTube.length < kCap) {
    toTube.add(fromTube.removeLast());
  }

  tubes[from] = fromTube;
  tubes[to] = toTube;
}

bool isTubeDone(List<int> t) => t.length == kCap && t.every((c) => c == t[0]);
bool isGameDone(List<List<int>> tubes) =>
    tubes.every((t) => t.isEmpty || isTubeDone(t));

// ─────────────────────────────────────────────
// YARDIMCI MODELLER
// ─────────────────────────────────────────────

class _TransferPlan {
  final int fromIdx;
  final int toIdx;
  final List<int> fromSnapshot;
  final List<int> toSnapshot;
  final int colorIdx;
  final int count;
  final bool isMountainTarget;
  final int mountainFillBefore;

  const _TransferPlan({
    required this.fromIdx,
    required this.toIdx,
    required this.fromSnapshot,
    required this.toSnapshot,
    required this.colorIdx,
    required this.count,
    this.isMountainTarget = false,
    this.mountainFillBefore = 0,
  });
}

class _VisualLayer {
  final int colorIdx;
  final double volume;

  const _VisualLayer({required this.colorIdx, required this.volume});

  _VisualLayer copyWith({int? colorIdx, double? volume}) => _VisualLayer(
        colorIdx: colorIdx ?? this.colorIdx,
        volume: volume ?? this.volume,
      );
}

// Solver'ın bir hamleyi simüle ederken taşıdığı tam oyun durumu.
// Map 3 gibi mountain/refill mekanizması olan levellarda da doğru çalışması için
// tubes'un yanı sıra mountain dolum durumu ve refill kuyrukları da taşınır.
class _SolverContext {
  final List<List<int>> tubes;
  final int mountainFillUnits;
  final int mountainCapacity;
  final Map<int, List<List<int>>>
      refillQueues; // kopyalanmış, mutate edilebilir

  _SolverContext({
    required this.tubes,
    required this.mountainFillUnits,
    required this.mountainCapacity,
    required this.refillQueues,
  });

  // Derin kopya — solver her dal için bağımsız context ister
  _SolverContext clone() {
    return _SolverContext(
      tubes: tubes
          .map((t) => List<int>.from(t, growable: true))
          .toList(growable: true),
      mountainFillUnits: mountainFillUnits,
      mountainCapacity: mountainCapacity,
      refillQueues: refillQueues.map(
        (k, v) => MapEntry(
            k,
            v
                .map((p) => List<int>.from(p, growable: true))
                .toList(growable: true)),
      ),
    );
  }

  bool get hasMountainObjective => mountainCapacity > 0;
}

class _JokerDecision {
  final int from;
  final int to;
  final int rewindCount;

  const _JokerDecision({
    required this.from,
    required this.to,
    this.rewindCount = 0,
  });
}

// ─────────────────────────────────────────────
// ORTAK TEMAS HESABI
// ─────────────────────────────────────────────
//
// Akış çizgisinin hedefteki sıvıya (veya boş şişe dibine) değdiği
// streamOpen anını hesaplar.
//
// Tüm koordinatlar LOCAL şişe koordinatındadır.
// Akış ağız noktası: kLiquidTopY + kStreamMouthOffset
// Max iniş mesafesi: kLiquidBotY - (kLiquidTopY + kStreamMouthOffset)
//
// Bu sabit her iki yerde (FlyingTube & TubeStage) aynı olmalı.
const double kStreamMouthOffset = 24.0; // ağız Y = kLiquidTopY + bu değer

double computeContactThreshold(int existingLayerCount) {
  final fillRatio = (existingLayerCount / kCap).clamp(0.0, 1.0);
  // Mevcut sıvı yüzey Y (local, 0 katman=dip, 4 katman=üst)
  final surfaceY = kLiquidBotY - (kLiquidBotY - kLiquidTopY) * fillRatio;
  // Akış çizgisinin başladığı Y (şişe ağzı)
  final mouthY = kLiquidTopY + kStreamMouthOffset;
  // Akışın inmesi gereken mesafe
  final needed = (surfaceY - mouthY).clamp(0.0, double.infinity);
  // Akışın inebileceği maksimum mesafe (ağızdan dibe)
  final maxTravel = (kLiquidBotY - mouthY).clamp(1.0, double.infinity);
  // 0.90 tavanı: boş şişede bile fillProgress'in çalışacak %10 payı olsun
  return (needed / maxTravel).clamp(0.0, 0.10);
}

// ─────────────────────────────────────────────
// GAME PAGE
// ─────────────────────────────────────────────

class GamePageResult {
  final bool completed;
  final int coinsAfterLevel;
  final int earnedCoins;

  const GamePageResult({
    required this.completed,
    required this.coinsAfterLevel,
    this.earnedCoins = 0,
  });
}

class GamePage extends StatefulWidget {
  final int level;
  final int mapNumber;
  final int difficulty;
  final int initialCoins;

  final List<List<int>>? customPuzzleTubes;
  final int? customLockedAdTubeIndex;
  final StageLayout? customStageLayout;

  final bool isDailyPuzzleMode;
  final String? dailyPuzzleDateKey;
  final int? dailyRewardCoins;
  final DailyPuzzleSaveState? restoredDailyState;
  final String? customTitle;
  final List<Color>? customBackground;

  const GamePage({
    super.key,
    required this.level,
    required this.mapNumber,
    this.difficulty = 1,
    this.initialCoins = 0,
    this.customPuzzleTubes,
    this.customLockedAdTubeIndex,
    this.customStageLayout,
    this.isDailyPuzzleMode = false,
    this.dailyPuzzleDateKey,
    this.dailyRewardCoins,
    this.restoredDailyState,
    this.customTitle,
    this.customBackground,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  Future<void> _vibrateTap() async {
    await SettingsPage.vibrateTap();
  }

  Future<void> _vibrateLight() async {
    await SettingsPage.vibrateLight();
  }

  Future<void> _playClick() async {
    await SfxService.playClick();
  }

  late final AnimationController _bgCtrl;
  late final MapTheme _theme;
  final GlobalKey _mountainReservoirKey = GlobalKey();
  Offset? getMountainFixedEntry() {
    final ctx = _mountainReservoirKey.currentContext;
    if (ctx == null) return null;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;

    return Offset(
      topLeft.dx + size.width * 0.5,
      topLeft.dy + size.height * 0.22,
    );
  }

  late int _lockedAdTubeIndex;
  PuzzlePreset? _preset;
  Map<int, List<List<int>>> _runtimeRefillQueues = {};

  // Oyun mantık durumu (gerçek veri)
  late List<List<int>> _tubes;

  // Aktif animasyonlar (paralel çalışabilir)
  final List<_TransferPlan> _activePlans = [];

  // Seçim durumu
  int? _selected;

  // Sıralı komut kuyruğu: (from, to) çiftleri
  final Queue<(int, int)> _commandQueue = Queue<(int, int)>();

  bool _gameWon = false;
  final Map<int, int> _celebratingDoneTubes = <int, int>{};

  // Geri alma geçmişi
  final List<
      ({
        List<List<int>> tubes,
        List<int> visibleLayerCounts,
        int fromIdx,
        int toIdx,
        int mountainFillUnits,
        List<_VisualLayer> mountainLayers,
      })> _history = [];

  late List<int> _visibleLayerCounts;
  final Map<int, int> _blindRevealFlashTicks = <int, int>{};
  // Geri alma animasyonu — hangi tüpler sloshing yapıyor
  final Map<int, int> _undoSloshingTubes = {}; // tubeIdx → colorIdx

  static const int _jokerCost = 50;
  static const String _tutorialSeenKey = 'likora_tutorial_seen_v1';

  bool _showTutorial = false;
  int _tutorialStepIndex = 0;
  int? _tutorialFromIdx;
  int? _tutorialToIdx;

  late final List<_TutorialStep> _tutorialSteps = const [
    _TutorialStep(
      title: 'Bir tüp seç',
      message: '',
      bubbleAlignment: Alignment(0.0, -0.88),
    ),
    _TutorialStep(
      title: '',
      message:
          'Seçtiğin tüpün en üst rengini bir boş tüpe veya en üst rengi aynı renge sahip, boş alanı olan bir başka tüpe dök.',
      bubbleAlignment: Alignment(0.0, -0.88),
    ),
    _TutorialStep(
      title: '',
      message: 'Bir tüp ancak tam doluysa ve tek renkse tamamlanmış sayılır.',
      bubbleAlignment: Alignment(0.0, -0.78),
    ),
  ];

  late int _coins;
  bool _jokerBusy = false;
  bool _adTubeUnlocked = false;
  bool _levelRewardGranted = false;
  bool _restoringLevelState = true;
  bool _missingPreset = false;
  int _mountainFillUnits = 0;
  final List<_VisualLayer> _mountainLayers = [];
  bool _loopCompletedVolcano = false;
  final Map<String, List<(int, int)>> _solverSuccessCache = {};

  // Rewarded reklam
  RewardedAd? _jokerAd;
  RewardedAd? _extraTubeAd;
  bool _isJokerAdReady = false;
  bool _isExtraTubeAdReady = false;

  bool get _adsEnabledOnThisPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  bool get _canBuyJoker => _coins >= _jokerCost;
  bool get _isDailyMode =>
      widget.isDailyPuzzleMode && widget.dailyPuzzleDateKey != null;

  int get _mountainCapacity => _preset?.mountainCapacity ?? 0;

  bool get _hasMountainObjective =>
      widget.mapNumber == 3 && _mountainCapacity > 0;

  double get _mountainFillPercent {
    final capacity = _mountainCapacity;
    if (capacity <= 0) return 0.0;
    return (_mountainFillUnits / capacity).clamp(0.0, 1.0);
  }

  void _primeCompletedVolcanoVisuals() {
    if (!_hasMountainObjective) return;

    final capacity = _mountainCapacity;
    if (capacity <= 0) return;

    _mountainFillUnits = capacity;
    _mountainLayers
      ..clear()
      ..add(
        _VisualLayer(
          colorIdx: kLavaColorIndex,
          volume: capacity.toDouble(),
        ),
      );
  }

  _ResolvedStageLayout get _stageLayout {
    final base = resolveStageLayout(
      layout: widget.customStageLayout ?? _preset?.layout,
      tubeCount: _tubes.length,
    );

    if (widget.mapNumber != 3) return base;

    return _ResolvedStageLayout(
      modeLayout: base.modeLayout,
      rows: base.rows,
      rowTopPaddings: base.rowTopPaddings,
      positions: base.positions,
      tubeGap: base.tubeGap,
      rowGap: base.rowGap,
      topOffset: base.topOffset,
      width: base.width,
      height: base.height + 176.0,
    );
  }

  int _tubeCapacityIn(List<List<int>> tubes, int idx) => kCap;

  PuzzleTubeStyle _tubeStyleForIndex(int idx) {
    return _preset?.tubeStyles[idx] ??
        _preset?.tubeStyle ??
        PuzzleTubeStyle.classic;
  }

  bool _canPourIn(List<List<int>> tubes, int from, int to) {
    if (from == to) return false;
    if (from < 0 || from >= tubes.length || to < 0 || to >= tubes.length)
      return false;
    if (tubes[from].isEmpty) return false;
    if (tubes[to].length >= _tubeCapacityIn(tubes, to)) return false;

    final movingColor = tubes[from].last;
    if (tubes[to].isNotEmpty && tubes[to].last != movingColor) return false;
    return true;
  }

  int _pourCountIn(List<List<int>> tubes, int from, int to) {
    if (!_canPourIn(tubes, from, to)) return 0;
    final top = tubes[from].last;
    int count = 0;
    final available = _tubeCapacityIn(tubes, to) - tubes[to].length;
    for (int i = tubes[from].length - 1; i >= 0; i--) {
      if (tubes[from][i] == top) {
        count++;
      } else {
        break;
      }
    }
    return count.clamp(0, available);
  }

  void _doPourIn(List<List<int>> tubes, int from, int to) {
    final fromTube = List<int>.from(tubes[from]);
    final toTube = List<int>.from(tubes[to]);
    final top = fromTube.last;
    final cap = _tubeCapacityIn(tubes, to);
    while (fromTube.isNotEmpty && fromTube.last == top && toTube.length < cap) {
      toTube.add(fromTube.removeLast());
    }
    tubes[from] = fromTube;
    tubes[to] = toTube;
  }

  bool _isTubeDoneIn(List<List<int>> tubes, int idx) {
    final tube = tubes[idx];
    if (tube.isEmpty) return false;
    final cap = _tubeCapacityIn(tubes, idx);
    if (tube.length != cap) return false;
    if (!tube.every((c) => c == tube.first)) return false;
    return true;
  }

  bool _isGameDoneIn(List<List<int>> tubes, {_SolverContext? ctx}) {
    if (ctx != null) {
      if (ctx.hasMountainObjective &&
          ctx.mountainFillUnits < ctx.mountainCapacity) {
        return false;
      }
    } else {
      if (_hasMountainObjective && _mountainFillUnits < _mountainCapacity) {
        return false;
      }
    }
    for (int i = 0; i < tubes.length; i++) {
      if (tubes[i].isEmpty) continue;
      if (!_isTubeDoneIn(tubes, i)) return false;
    }
    return true;
  }

  Map<int, List<List<int>>> _cloneRefillQueues(SourceTubeRefillConfig? refill) {
    if (refill == null) return {};

    return refill.refillQueues.map(
      (tubeIndex, queue) => MapEntry(
        tubeIndex,
        queue
            .map((pack) => List<int>.from(pack, growable: true))
            .toList(growable: true),
      ),
    );
  }

  Map<int, List<List<int>>> _decodeRuntimeRefillQueues(dynamic raw) {
    final result = <int, List<List<int>>>{};
    if (raw is! Map) return result;

    raw.forEach((key, value) {
      final tubeIndex = int.tryParse(key.toString());
      if (tubeIndex == null || value is! List) return;

      final queue = <List<int>>[];
      for (final packRaw in value) {
        if (packRaw is! List) continue;

        final pack = <int>[];
        var valid = true;
        for (final cell in packRaw) {
          if (cell is int) {
            pack.add(cell);
          } else {
            valid = false;
            break;
          }
        }

        if (valid) {
          queue.add(pack);
        }
      }

      result[tubeIndex] = queue;
    });

    return result;
  }

  Map<String, dynamic> _encodeRuntimeRefillQueues(
    Map<int, List<List<int>>> queues,
  ) {
    return queues.map(
      (tubeIndex, queue) => MapEntry(
        tubeIndex.toString(),
        queue.map((pack) => List<int>.from(pack, growable: false)).toList(
              growable: false,
            ),
      ),
    );
  }

  String get _refillStatePrefsKey =>
      'likora_refill_state_${widget.mapNumber}_${widget.level}';

  String? get _dailyRefillStatePrefsKey => widget.dailyPuzzleDateKey == null
      ? null
      : 'likora_daily_refill_state_${widget.dailyPuzzleDateKey}';

  String? get _effectiveRefillStatePrefsKey =>
      _isDailyMode ? _dailyRefillStatePrefsKey : _refillStatePrefsKey;

  Future<void> _persistRefillState() async {
    final key = _effectiveRefillStatePrefsKey;
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();

    if (_gameWon || _runtimeRefillQueues.isEmpty) {
      await prefs.remove(key);
      return;
    }

    await prefs.setString(
      key,
      jsonEncode(_encodeRuntimeRefillQueues(_runtimeRefillQueues)),
    );
  }

  Future<void> _restoreRefillState() async {
    _runtimeRefillQueues = _cloneRefillQueues(_preset?.sourceRefill);

    final key = _effectiveRefillStatePrefsKey;
    if (key == null) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      final restored = _decodeRuntimeRefillQueues(decoded);

      if (restored.isNotEmpty) {
        _runtimeRefillQueues = restored;
      }
    } catch (_) {
      _runtimeRefillQueues = _cloneRefillQueues(_preset?.sourceRefill);
    }
  }

  Future<void> _clearRefillState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refillStatePrefsKey);

    final dailyKey = _dailyRefillStatePrefsKey;
    if (dailyKey != null) {
      await prefs.remove(dailyKey);
    }
  }

  bool isRefillStopped() {
    final refill = _preset?.sourceRefill;
    if (refill == null || !refill.stopWhenMountainFull) return false;
    return _hasMountainObjective && _mountainFillUnits >= _mountainCapacity;
  }

  void _tryRefillSourceTube(int tubeIndex) {
    final refill = _preset?.sourceRefill;
    if (refill == null) return;
    if (!refill.tubeIndexes.contains(tubeIndex)) {
      debugPrint(
          '[REFILL] tube $tubeIndex NOT in tubeIndexes: ${refill.tubeIndexes}');
      return;
    }
    if (tubeIndex < 0 || tubeIndex >= _tubes.length) return;
    if (_tubes[tubeIndex].isNotEmpty) {
      debugPrint('[REFILL] tube $tubeIndex not empty, skipping');
      return;
    }

    final queue = _runtimeRefillQueues[tubeIndex];
    if (queue == null || queue.isEmpty) {
      debugPrint(
          '[REFILL] tube $tubeIndex queue is null or empty. keys: ${_runtimeRefillQueues.keys}');
      return;
    }

    debugPrint('[REFILL] tube $tubeIndex refilled successfully');
    final nextPack = queue.removeAt(0);
    _tubes[tubeIndex] = List<int>.from(nextPack, growable: true);
  }

  Future<void> _returnToMapPage() async {
    if (!_missingPreset) {
      await _persistLevelState();
    }
    if (!mounted) return;

    if (_isDailyMode) {
      Navigator.of(context).pop(
        GamePageResult(
          completed: _gameWon,
          coinsAfterLevel: _coins,
          earnedCoins: _gameWon ? _levelReward : 0,
        ),
      );
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MapPage(mapNumber: widget.mapNumber),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _theme = getMapTheme(widget.mapNumber);
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _coins = widget.initialCoins;
    _restoreOrResetLevel();
    if (_adsEnabledOnThisPlatform) {
      _loadJokerAd();
      _loadExtraTubeAd();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowTutorial();
    });
  }

  Future<void> _restoreOrResetLevel() async {
    await PlayerProgress.ensureLoaded();

    final syncedCoins = widget.initialCoins > 0
        ? widget.initialCoins
        : PlayerProgress.coins.value;

    if (widget.customPuzzleTubes == null && !_isDailyMode) {
      _preset = PuzzlePresets.getOrNull(
        mapNumber: widget.mapNumber,
        levelId: widget.level,
      );

      if (_preset == null) {
        if (!mounted) return;
        setState(() {
          _missingPreset = true;
          _restoringLevelState = false;
        });
        return;
      }

      await _restoreRefillState();
    }

    if (_isDailyMode) {
      final isAlreadyCompleted =
          await DailyPuzzleProgress.isCompleted(widget.dailyPuzzleDateKey!);

      if (isAlreadyCompleted) {
        _applyCompletedLevelState(coinsOverride: syncedCoins);
        PlayerProgress.setCoins(_coins);

        if (!mounted) return;
        setState(() {
          _restoringLevelState = false;
        });
        return;
      }

      final saved = widget.restoredDailyState;

      if (!mounted) return;

      final expectedTubeCount = widget.customPuzzleTubes?.length;
      final savedTubeCount = saved?.tubes.length;
      final countMismatch = expectedTubeCount != null &&
          savedTubeCount != null &&
          expectedTubeCount != savedTubeCount;

      if (saved != null && saved.tubes.isNotEmpty && !countMismatch) {
        _applyLevelState(
          tubes: saved.tubes,
          lockedAdTubeIndex: saved.lockedAdTubeIndex,
          adTubeUnlocked: saved.adTubeUnlocked,
          coinsValue: syncedCoins,
        );

        _visibleLayerCounts = _normalizeVisibleLayerCounts(
          saved.visibleLayerCounts,
          _tubes,
        );
        await _restoreUndoHistoryState();
      } else {
        _reset(coinsOverride: syncedCoins);
        _history.clear();
      }

      PlayerProgress.setCoins(_coins);

      if (!mounted) return;
      setState(() {
        _restoringLevelState = false;
      });
      return;
    }

    final completedLevels =
        await PlayerProgress.getCompletedLevels(widget.mapNumber);
    final isAlreadyCompleted = completedLevels.contains(widget.level);

    if (isAlreadyCompleted) {
      _applyCompletedLevelState(coinsOverride: syncedCoins);
      PlayerProgress.setCoins(_coins);

      if (!mounted) return;
      setState(() {
        _restoringLevelState = false;
      });
      return;
    }

    final saved = await PlayerProgress.getInProgressLevelState(
      widget.mapNumber,
      widget.level,
    );

    if (!mounted) return;

    if (saved != null && saved.tubes.isNotEmpty) {
      // Preset ile kayıtlı state tüp sayısı uyuşmuyorsa sıfırla.
      // Bu, lockedAdTubeIndex kayması ve renk index hataları yaratır.
      final presetTubeCount = PuzzlePresets.getOrNull(
        mapNumber: widget.mapNumber,
        levelId: widget.level,
      )?.tubes.length;
      final savedTubeCount = saved.tubes.length;
      final countMismatch =
          presetTubeCount != null && savedTubeCount != presetTubeCount;

      if (countMismatch) {
        _reset(coinsOverride: syncedCoins);
        _history.clear();
      } else {
        _applyLevelState(
          tubes: saved.tubes,
          lockedAdTubeIndex: saved.lockedAdTubeIndex,
          adTubeUnlocked: saved.adTubeUnlocked,
          coinsValue: saved.coins,
        );
        await _restoreBlindVisibilityState();
        await _restoreUndoHistoryState();
      }
    } else {
      _reset(coinsOverride: syncedCoins);
      _history.clear();
    }

    PlayerProgress.setCoins(_coins);

    if (!mounted) return;
    setState(() {
      _restoringLevelState = false;
    });
  }

  @override
  void dispose() {
    SfxService.stopWater();
    _jokerAd?.dispose();
    _extraTubeAd?.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  bool get _showLockedAdTube => !_adTubeUnlocked;

  void _loadJokerAd() {
    if (!_adsEnabledOnThisPlatform) return;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3080345587906246/7193577467',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _jokerAd?.dispose();
          _jokerAd = ad;
          _isJokerAdReady = true;
        },
        onAdFailedToLoad: (error) {
          _jokerAd = null;
          _isJokerAdReady = false;
        },
      ),
    );
  }

  void _loadExtraTubeAd() {
    if (!_adsEnabledOnThisPlatform) return;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3080345587906246/3174441406',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _extraTubeAd?.dispose();
          _extraTubeAd = ad;
          _isExtraTubeAdReady = true;
        },
        onAdFailedToLoad: (error) {
          _extraTubeAd = null;
          _isExtraTubeAdReady = false;
        },
      ),
    );
  }

  bool get _blindModeEnabled => widget.mapNumber == 2;

  String get _blindVisibilityPrefsKey =>
      'likora_blind_visibility_${widget.mapNumber}_${widget.level}';

  String get _undoHistoryPrefsKey =>
      'likora_undo_history_${widget.mapNumber}_${widget.level}';

  String? get _dailyUndoHistoryPrefsKey => widget.dailyPuzzleDateKey == null
      ? null
      : 'likora_daily_undo_history_${widget.dailyPuzzleDateKey}';

  bool _isLockedAdTubeIndex(int idx) =>
      _showLockedAdTube && idx == _lockedAdTubeIndex;

  List<int> _defaultVisibleLayerCountsFor(List<List<int>> tubes) {
    if (!_blindModeEnabled) {
      return List<int>.generate(
        tubes.length,
        (i) => tubes[i].length,
        growable: true,
      );
    }

    return List<int>.generate(
      tubes.length,
      (i) => tubes[i].isEmpty ? 0 : 1,
      growable: true,
    );
  }

  List<int> _normalizeVisibleLayerCounts(
    List<int>? raw,
    List<List<int>> tubes,
  ) {
    final fallback = _defaultVisibleLayerCountsFor(tubes);
    if (raw == null || raw.length != tubes.length) return fallback;

    return List<int>.generate(
      tubes.length,
      (i) => raw[i].clamp(0, tubes[i].length).toInt(),
      growable: true,
    );
  }

  Future<void> _restoreUndoHistoryState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isDailyMode ? _dailyUndoHistoryPrefsKey : _undoHistoryPrefsKey;
    if (key == null) {
      _history.clear();
      return;
    }

    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      _history.clear();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _history.clear();
        return;
      }

      final restored = <({
        List<List<int>> tubes,
        List<int> visibleLayerCounts,
        int fromIdx,
        int toIdx,
        int mountainFillUnits,
        List<_VisualLayer> mountainLayers,
      })>[];

      for (final item in decoded) {
        if (item is! Map) continue;
        final tubesRaw = item['tubes'];
        final fromIdx = item['fromIdx'];
        final toIdx = item['toIdx'];
        if (tubesRaw is! List || fromIdx is! int || toIdx is! int) continue;

        final tubes = <List<int>>[];
        var valid = true;
        for (final tubeRaw in tubesRaw) {
          if (tubeRaw is! List) {
            valid = false;
            break;
          }
          final tube = <int>[];
          for (final cell in tubeRaw) {
            if (cell is int) {
              tube.add(cell);
            } else {
              valid = false;
              break;
            }
          }
          if (!valid) break;
          tubes.add(tube);
        }
        if (!valid || tubes.length != _tubes.length) continue;

        final visibleRaw = item['visibleLayerCounts'];
        final visible = visibleRaw is List
            ? visibleRaw.map((e) => e is int ? e : 0).toList(growable: true)
            : _defaultVisibleLayerCountsFor(tubes);

        final mountainFillUnitsRaw = item['mountainFillUnits'];
        final mountainLayersRaw = item['mountainLayers'];
        final mountainFillUnits = mountainFillUnitsRaw is int
            ? (_mountainCapacity > 0
                ? mountainFillUnitsRaw.clamp(0, _mountainCapacity).toInt()
                : 0)
            : 0;
        final mountainLayers = <_VisualLayer>[];
        if (mountainLayersRaw is List) {
          for (final layerRaw in mountainLayersRaw) {
            if (layerRaw is! Map) continue;
            final colorIdx = layerRaw['colorIdx'];
            final volumeRaw = layerRaw['volume'];
            if (colorIdx is! int) continue;
            final volume = volumeRaw is num ? volumeRaw.toDouble() : 0.0;
            if (volume <= 0) continue;
            mountainLayers.add(
              _VisualLayer(
                colorIdx: colorIdx.clamp(0, kColors.length - 1).toInt(),
                volume: volume,
              ),
            );
          }
        }

        restored.add((
          tubes: tubes,
          visibleLayerCounts: _normalizeVisibleLayerCounts(visible, tubes),
          fromIdx: fromIdx.clamp(0, _tubes.length - 1).toInt(),
          toIdx: toIdx.clamp(0, _tubes.length - 1).toInt(),
          mountainFillUnits: mountainFillUnits,
          mountainLayers: mountainLayers,
        ));
      }

      _history
        ..clear()
        ..addAll(restored);
    } catch (_) {
      _history.clear();
    }
  }

  Future<void> _persistUndoHistoryState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isDailyMode ? _dailyUndoHistoryPrefsKey : _undoHistoryPrefsKey;
    if (key == null) return;

    if (_gameWon || _history.isEmpty) {
      await prefs.remove(key);
      return;
    }

    final payload = _history
        .map((entry) => {
              'tubes': entry.tubes,
              'visibleLayerCounts': entry.visibleLayerCounts,
              'fromIdx': entry.fromIdx,
              'toIdx': entry.toIdx,
              'mountainFillUnits': entry.mountainFillUnits,
              'mountainLayers': entry.mountainLayers
                  .map((layer) => {
                        'colorIdx': layer.colorIdx,
                        'volume': layer.volume,
                      })
                  .toList(growable: false),
            })
        .toList(growable: false);

    await prefs.setString(key, jsonEncode(payload));
  }

  Future<void> clearUndoHistoryState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_undoHistoryPrefsKey);
    final dailyKey = _dailyUndoHistoryPrefsKey;
    if (dailyKey != null) {
      await prefs.remove(dailyKey);
    }
  }

  Future<void> _restoreBlindVisibilityState() async {
    if (!_blindModeEnabled) {
      _visibleLayerCounts = _defaultVisibleLayerCountsFor(_tubes);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_blindVisibilityPrefsKey);
    final parsed =
        saved?.map((e) => int.tryParse(e) ?? 0).toList(growable: true);

    _visibleLayerCounts = _normalizeVisibleLayerCounts(parsed, _tubes);
  }

  Future<void> _persistBlindVisibilityState() async {
    final prefs = await SharedPreferences.getInstance();

    if (!_blindModeEnabled) {
      await prefs.remove(_blindVisibilityPrefsKey);
      return;
    }

    await prefs.setStringList(
      _blindVisibilityPrefsKey,
      _visibleLayerCounts.map((e) => e.toString()).toList(growable: false),
    );
  }

  Future<void> _clearBlindVisibilityState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_blindVisibilityPrefsKey);
  }

  void _triggerBlindRevealFlash(int idx) {
    final nextTick = (_blindRevealFlashTicks[idx] ?? 0) + 1;
    setState(() {
      _blindRevealFlashTicks[idx] = nextTick;
    });
  }

  void _updateBlindVisibilityAfterPour(int from, int to, int pouredCount) {
    if (!_blindModeEnabled) return;

    final oldFromVisible = _visibleLayerCounts[from]
        .clamp(0, _tubes[from].length + pouredCount)
        .toInt();
    final oldToVisible = _visibleLayerCounts[to]
        .clamp(0, max(0, _tubes[to].length - pouredCount))
        .toInt();
    final newFromLen = _tubes[from].length;
    final newToLen = _tubes[to].length;

    final removedVisible = min(oldFromVisible, pouredCount);
    var newFromVisible = max(0, oldFromVisible - removedVisible);

    final removedHiddenAbove = pouredCount > removedVisible;
    final shouldRevealNextTop =
        newFromLen > 0 && (newFromVisible == 0 || removedHiddenAbove);
    if (shouldRevealNextTop) {
      newFromVisible = min(newFromLen, newFromVisible + 1);
    }
    _visibleLayerCounts[from] = newFromVisible.clamp(0, newFromLen).toInt();

    _visibleLayerCounts[to] = min(newToLen, oldToVisible + pouredCount);

    if (shouldRevealNextTop) {
      _triggerBlindRevealFlash(from);
    }
  }

  void _updateBlindVisibilityAfterMountainPour(int from, int pouredCount) {
    if (!_blindModeEnabled) return;

    final oldFromVisible = _visibleLayerCounts[from]
        .clamp(0, _tubes[from].length + pouredCount)
        .toInt();
    final newFromLen = _tubes[from].length;

    final removedVisible = min(oldFromVisible, pouredCount);
    var newFromVisible = max(0, oldFromVisible - removedVisible);

    final removedHiddenAbove = pouredCount > removedVisible;
    final shouldRevealNextTop =
        newFromLen > 0 && (newFromVisible == 0 || removedHiddenAbove);
    if (shouldRevealNextTop) {
      newFromVisible = min(newFromLen, newFromVisible + 1);
    }
    _visibleLayerCounts[from] = newFromVisible.clamp(0, newFromLen).toInt();

    if (shouldRevealNextTop) {
      _triggerBlindRevealFlash(from);
    }
  }

  // Hangi tüpler şu an aktif animasyonda meşgul
  Set<int> get _busyTubes {
    final s = <int>{};
    for (final p in _activePlans) {
      s.add(p.fromIdx);
      if (!p.isMountainTarget) {
        s.add(p.toIdx);
      }
    }
    return s;
  }

  List<List<int>> _buildInitialTubes() {
    if (widget.customPuzzleTubes != null) {
      _preset = null;
      return widget.customPuzzleTubes!
          .map((t) => List<int>.of(t, growable: true))
          .toList(growable: true);
    }

    _preset ??= PuzzlePresets.getOrNull(
      mapNumber: widget.mapNumber,
      levelId: widget.level,
    );

    return (_preset?.tubes ?? const <List<int>>[])
        .map((t) => List<int>.of(t, growable: true))
        .toList(growable: true);
  }

  void _applyLevelState({
    required List<List<int>> tubes,
    required int lockedAdTubeIndex,
    required bool adTubeUnlocked,
    required int coinsValue,
  }) {
    _tubes = tubes
        .map((t) => List<int>.of(t, growable: true))
        .toList(growable: true);
    _visibleLayerCounts = _defaultVisibleLayerCountsFor(_tubes);
    // lockedAdTubeIndex'in geçerli tubes aralığında olduğundan emin ol.
    _lockedAdTubeIndex = lockedAdTubeIndex.clamp(0, _tubes.length - 1).toInt();
    _activePlans.clear();
    _selected = null;
    _gameWon = false;
    _celebratingDoneTubes.clear();
    _commandQueue.clear();
    _history.clear();
    _undoSloshingTubes.clear();
    _adTubeUnlocked = adTubeUnlocked;
    _showTutorial = false;
    _tutorialStepIndex = 0;
    _tutorialFromIdx = null;
    _tutorialToIdx = null;
    _coins = coinsValue;
    _levelRewardGranted = false;
    setState(() {});
  }

  void _reset({int? coinsOverride, bool clearSavedState = true}) {
    final initialTubes = _buildInitialTubes();
    // Preset'ten gelen lockedAdTubeIndex tubes listesi içinde kalmalı.
    // Eğer preset yoksa son tüp reklam tüpü olsun.
    final rawAdIdx = widget.customLockedAdTubeIndex ??
        _preset?.lockedAdTubeIndex ??
        (initialTubes.length - 1);
    final initialLockedAdTubeIndex =
        rawAdIdx.clamp(0, initialTubes.length - 1).toInt();

    _applyLevelState(
      tubes: initialTubes,
      lockedAdTubeIndex: initialLockedAdTubeIndex,
      adTubeUnlocked: false,
      coinsValue: coinsOverride ?? _coins,
    );

    _runtimeRefillQueues = _cloneRefillQueues(_preset?.sourceRefill);

    if (clearSavedState) {
      if (_isDailyMode) {
        DailyPuzzleProgress.clearInProgressState();
      } else {
        PlayerProgress.clearInProgressLevelState(
            widget.mapNumber, widget.level);
      }
      _clearBlindVisibilityState();
    }
  }

  List<List<int>> _buildCompletedTubesFromInitial(
      List<List<int>> initialTubes) {
    final colorCounts = <int, int>{};
    for (final tube in initialTubes) {
      for (final color in tube) {
        colorCounts[color] = (colorCounts[color] ?? 0) + 1;
      }
    }

    final solvedColors = colorCounts.keys.toList()..sort();
    final result = <List<int>>[];
    final usedColors = <int>{};

    for (int i = 0; i < initialTubes.length; i++) {
      if (initialTubes[i].isEmpty) {
        result.add(<int>[]);
        continue;
      }

      final nextColor = solvedColors.firstWhere(
        (color) =>
            !usedColors.contains(color) &&
            colorCounts[color]! >= _tubeCapacityIn(initialTubes, i),
        orElse: () => solvedColors.firstWhere(
          (color) => !usedColors.contains(color),
          orElse: () => solvedColors.first,
        ),
      );
      usedColors.add(nextColor);
      result.add(List<int>.filled(_tubeCapacityIn(initialTubes, i), nextColor,
          growable: true));
    }

    while (result.length < initialTubes.length) {
      result.add(<int>[]);
    }

    return result;
  }

  void _applyCompletedLevelState({int? coinsOverride}) {
    final initialTubes = _buildInitialTubes();
    final rawAdIdx = widget.customLockedAdTubeIndex ??
        _preset?.lockedAdTubeIndex ??
        (initialTubes.length - 1);
    final initialLockedAdTubeIndex =
        rawAdIdx.clamp(0, initialTubes.length - 1).toInt();

    _applyLevelState(
      tubes: _buildCompletedTubesFromInitial(initialTubes),
      lockedAdTubeIndex: initialLockedAdTubeIndex,
      adTubeUnlocked: false,
      coinsValue: coinsOverride ?? _coins,
    );

    if (_hasMountainObjective) {
      _primeCompletedVolcanoVisuals();
    }

    _visibleLayerCounts = List<int>.generate(
      _tubes.length,
      (i) => _tubes[i].length,
      growable: true,
    );
    _gameWon = true;
    _loopCompletedVolcano = widget.mapNumber == 3;
    _levelRewardGranted = true;
    _showTutorial = false;
    _selected = null;
    _activePlans.clear();
    _commandQueue.clear();
    _history.clear();
  }

  Future<void> _persistLevelState() async {
    if (_restoringLevelState) return;
    if (_missingPreset) return;

    if (_isDailyMode) {
      if (_gameWon) {
        await DailyPuzzleProgress.clearInProgressState();
        await _clearBlindVisibilityState();
        return;
      }

      await DailyPuzzleProgress.saveInProgressState(
        dateKey: widget.dailyPuzzleDateKey!,
        tubes: _tubes,
        lockedAdTubeIndex: _lockedAdTubeIndex,
        adTubeUnlocked: _adTubeUnlocked,
        visibleLayerCounts: _blindModeEnabled ? _visibleLayerCounts : null,
      );
      await _persistBlindVisibilityState();
      return;
    }

    if (_gameWon) {
      await PlayerProgress.clearInProgressLevelState(
          widget.mapNumber, widget.level);
      await _clearBlindVisibilityState();
      return;
    }

    await PlayerProgress.saveInProgressLevelState(
      mapNumber: widget.mapNumber,
      levelId: widget.level,
      tubes: _tubes,
      lockedAdTubeIndex: _lockedAdTubeIndex,
      adTubeUnlocked: _adTubeUnlocked,
      coinsValue: _coins,
    );
    await _persistBlindVisibilityState();
    await _persistRefillState();
  }

  String _canonicalBoardSignature(
    List<List<int>> tubes, {
    required bool includeUnlockedAdTube,
  }) {
    final playable = <String>[];
    String? locked;

    for (int i = 0; i < tubes.length; i++) {
      final sig = tubes[i].join(',');

      if (i == _lockedAdTubeIndex && !includeUnlockedAdTube) {
        locked = 'LOCK:$sig';
      } else {
        playable.add(sig);
      }
    }

    playable.sort((a, b) {
      final aEmpty = a.isEmpty;
      final bEmpty = b.isEmpty;

      if (aEmpty && !bEmpty) return 1;
      if (!aEmpty && bEmpty) return -1;
      return a.compareTo(b);
    });

    if (locked != null) {
      playable.add(locked);
    }

    return playable.join('|');
  }

  List<int> _completedTubeColorsOf(List<List<int>> tubes) {
    final colors = <int>[];
    for (int i = 0; i < tubes.length; i++) {
      if (!_adTubeUnlocked && i == _lockedAdTubeIndex) continue;
      final tube = tubes[i];
      if (_isTubeDoneIn(tubes, i)) {
        colors.add(tube.first);
      }
    }
    colors.sort();
    return colors;
  }

  int _doneTubeCountOf(List<List<int>> tubes) {
    int count = 0;
    for (int i = 0; i < tubes.length; i++) {
      if (!_adTubeUnlocked && i == _lockedAdTubeIndex) continue;
      if (_isTubeDoneIn(tubes, i)) count++;
    }
    return count;
  }

  bool preservesCompletedTubes(
    List<List<int>> current,
    List<List<int>> candidate,
  ) {
    if (_doneTubeCountOf(candidate) < _doneTubeCountOf(current)) {
      return false;
    }

    final currentDone = _completedTubeColorsOf(current);
    final candidateDone = _completedTubeColorsOf(candidate);

    for (final color in currentDone) {
      if (!candidateDone.contains(color)) {
        return false;
      }
    }

    return true;
  }

  List<List<int>> _cloneTubes(List<List<int>> tubes) => tubes
      .map((t) => List<int>.from(t, growable: true))
      .toList(growable: true);

  bool _solverCanUseTube(int idx, {bool? includeUnlockedAdTube}) {
    final allowAd = includeUnlockedAdTube ?? _adTubeUnlocked;
    if (idx != _lockedAdTubeIndex) return true;
    return allowAd;
  }

  bool _solverCanPour(
    List<List<int>> tubes,
    int from,
    int to, {
    bool? includeUnlockedAdTube,
  }) {
    if (!_solverCanUseTube(from,
        includeUnlockedAdTube: includeUnlockedAdTube)) {
      return false;
    }
    if (!_solverCanUseTube(to, includeUnlockedAdTube: includeUnlockedAdTube)) {
      return false;
    }
    return _canPourIn(tubes, from, to);
  }

  List<(int, int)> _orderedSolverMoves(
    List<List<int>> tubes, {
    bool? includeUnlockedAdTube,
  }) {
    final moves = <({int from, int to, int score})>[];
    final usable = <int>[];

    for (int i = 0; i < tubes.length; i++) {
      if (_solverCanUseTube(i, includeUnlockedAdTube: includeUnlockedAdTube)) {
        usable.add(i);
      }
    }

    final emptyTargets =
        usable.where((i) => tubes[i].isEmpty).toList(growable: false);

    for (final from in usable) {
      final source = tubes[from];
      if (source.isEmpty) continue;
      if (_isTubeDoneIn(tubes, from)) continue;

      final sourceTop = source.last;
      final sourceUniform = source.every((c) => c == sourceTop);

      for (final to in usable) {
        if (from == to) continue;
        if (!_solverCanPour(
          tubes,
          from,
          to,
          includeUnlockedAdTube: includeUnlockedAdTube,
        )) {
          continue;
        }

        final target = tubes[to];

        if (target.isEmpty &&
            emptyTargets.isNotEmpty &&
            to != emptyTargets.first) {
          continue;
        }

        if (target.isEmpty && sourceUniform) {
          continue;
        }

        int score = 0;

        if (target.isNotEmpty && target.last == sourceTop) {
          score += 120;
          if (target.length + _pourCountIn(tubes, from, to) ==
              _tubeCapacityIn(tubes, to)) {
            score += 80;
          }
        }

        if (target.isEmpty) {
          score += 15;
        }

        final next = _cloneTubes(tubes);
        _doPourIn(next, from, to);

        if (_isTubeDoneIn(next, to)) {
          score += 60;
        }
        if (_isTubeDoneIn(next, from)) {
          score += 8;
        }

        final beforeDone = _doneTubeCountOf(tubes);
        final afterDone = _doneTubeCountOf(next);
        score += (afterDone - beforeDone) * 50;

        moves.add((from: from, to: to, score: score));
      }
    }

    moves.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byFrom = a.from.compareTo(b.from);
      if (byFrom != 0) return byFrom;
      return a.to.compareTo(b.to);
    });

    return moves.map((m) => (m.from, m.to)).toList(growable: false);
  }

  String _solverCacheKey(
    List<List<int>> tubes, {
    required bool includeUnlockedAdTube,
  }) {
    final sig = _canonicalBoardSignature(
      tubes,
      includeUnlockedAdTube: includeUnlockedAdTube,
    );
    return '${includeUnlockedAdTube ? 1 : 0}:$sig';
  }

  List<(int, int)>? _quickSolveFromState(
    List<List<int>> start, {
    required bool includeUnlockedAdTube,
    _SolverContext? solverCtx,
  }) {
    return _solveFromState(
      start,
      includeUnlockedAdTube: includeUnlockedAdTube,
      maxDepth: 48,
      maxNodes: 45000,
      maxMillis: 160,
      solverCtx: solverCtx,
    );
  }

  List<(int, int)>? _mediumSolveFromState(
    List<List<int>> start, {
    required bool includeUnlockedAdTube,
    _SolverContext? solverCtx,
  }) {
    return _solveFromState(
      start,
      includeUnlockedAdTube: includeUnlockedAdTube,
      maxDepth: 90,
      maxNodes: 180000,
      maxMillis: 1400,
      solverCtx: solverCtx,
    );
  }

  List<(int, int)>? _solveFromState(
    List<List<int>> start, {
    required bool includeUnlockedAdTube,
    int maxDepth = 110,
    int maxNodes = 280000,
    int maxMillis = 2600,
    _SolverContext? solverCtx,
  }) {
    final cacheKey = _solverCacheKey(
      start,
      includeUnlockedAdTube: includeUnlockedAdTube,
    );
    // Mountain modunda cache kullanma — mountain durumu farklı olabilir
    if (solverCtx == null || !solverCtx.hasMountainObjective) {
      final cached = _solverSuccessCache[cacheKey];
      if (cached != null) {
        return List<(int, int)>.from(cached, growable: false);
      }
    }

    final stopwatch = Stopwatch()..start();
    final dead = <String>{};
    final path = <(int, int)>[];
    int nodes = 0;

    bool dfs(_SolverContext ctx, int depthLeft) {
      if (_isGameDoneIn(ctx.tubes, ctx: ctx)) {
        return true;
      }
      if (depthLeft <= 0) return false;
      if (nodes >= maxNodes || stopwatch.elapsedMilliseconds >= maxMillis) {
        return false;
      }

      final sig = _canonicalBoardSignature(
        ctx.tubes,
        includeUnlockedAdTube: includeUnlockedAdTube,
      );
      if (dead.contains(sig)) return false;

      nodes++;

      final moves = _orderedSolverMoves(
        ctx.tubes,
        includeUnlockedAdTube: includeUnlockedAdTube,
      );

      // Mountain modu: lav rengi varsa mountain hamlelerini de ekle
      final allMoves = <(int, int)>[...moves];
      if (ctx.hasMountainObjective) {
        for (int i = 0; i < ctx.tubes.length; i++) {
          final tube = ctx.tubes[i];
          if (tube.isNotEmpty && _isLavaColorIndex(tube.last)) {
            final available = ctx.mountainCapacity - ctx.mountainFillUnits;
            if (available > 0) {
              // -1 = mountain hedefi anlamında özel index
              allMoves.add((i, -1));
            }
          }
        }
      }

      for (final move in allMoves) {
        final next = ctx.clone();

        if (move.$2 == -1) {
          // Mountain hamlesi: lav tüpten mountain'a dök
          final fromTube = next.tubes[move.$1];
          final topColor = fromTube.last;
          int count = 0;
          for (int i = fromTube.length - 1; i >= 0; i--) {
            if (fromTube[i] == topColor)
              count++;
            else
              break;
          }
          final available = next.mountainCapacity - next.mountainFillUnits;
          count = count < available ? count : available;
          for (int i = 0; i < count; i++) {
            fromTube.removeLast();
          }
          // refill simülasyonu: kaynak tüp boşaldıysa doldur
          _solverApplyRefill(next, move.$1);
        } else {
          _doPourIn(next.tubes, move.$1, move.$2);
          // refill simülasyonu
          _solverApplyRefill(next, move.$1);
          _solverApplyRefill(next, move.$2);
        }

        path.add(move);
        if (dfs(next, depthLeft - 1)) {
          return true;
        }
        path.removeLast();
      }

      dead.add(sig);
      return false;
    }

    // Başlangıç context'i oluştur
    final rootCtx = solverCtx?.clone() ??
        _SolverContext(
          tubes: _cloneTubes(start),
          mountainFillUnits: 0,
          mountainCapacity: 0,
          refillQueues: {},
        );
    // start tubes'u her zaman kullan (rewind sonrası güncel olabilir)
    rootCtx.tubes.clear();
    rootCtx.tubes.addAll(_cloneTubes(start));

    for (int depth = 1; depth <= maxDepth; depth++) {
      path.clear();
      dead.clear();
      nodes = 0;

      if (dfs(rootCtx.clone(), depth)) {
        final solvedPath = List<(int, int)>.from(path, growable: false);
        if (solverCtx == null || !solverCtx.hasMountainObjective) {
          _solverSuccessCache[cacheKey] = solvedPath;
        }
        return solvedPath;
      }

      if (stopwatch.elapsedMilliseconds >= maxMillis || nodes >= maxNodes) {
        break;
      }
    }

    return null;
  }

  // Solver simülasyonunda refill kuyruktan tüpü doldur
  void _solverApplyRefill(_SolverContext ctx, int tubeIndex) {
    if (ctx.refillQueues.isEmpty) return;
    final queue = ctx.refillQueues[tubeIndex];
    if (queue == null || queue.isEmpty) return;
    if (ctx.tubes[tubeIndex].isNotEmpty) return;
    final nextPack = queue.removeAt(0);
    ctx.tubes[tubeIndex] = List<int>.from(nextPack, growable: true);
  }

  bool _wouldCreateRecentLoop(
    List<List<int>> board,
    int from,
    int to, {
    required bool includeUnlockedAdTube,
  }) {
    final next = _cloneTubes(board);
    _doPourIn(next, from, to);
    final nextSig = _canonicalBoardSignature(
      next,
      includeUnlockedAdTube: includeUnlockedAdTube,
    );

    final start = _history.length > 8 ? _history.length - 8 : 0;
    for (int i = start; i < _history.length; i++) {
      final sig = _canonicalBoardSignature(
        _history[i].tubes,
        includeUnlockedAdTube: includeUnlockedAdTube,
      );
      if (sig == nextSig) {
        return true;
      }
    }

    return false;
  }

  (int, int)? findBestEffortMove(
    List<List<int>> board, {
    required bool includeUnlockedAdTube,
  }) {
    final moves = _orderedSolverMoves(
      board,
      includeUnlockedAdTube: includeUnlockedAdTube,
    );
    if (moves.isEmpty) return null;

    for (final move in moves) {
      if (!_wouldCreateRecentLoop(
        board,
        move.$1,
        move.$2,
        includeUnlockedAdTube: includeUnlockedAdTube,
      )) {
        return move;
      }
    }

    return null;
  }

  // Mevcut oyun durumundan solver context'i oluştur
  _SolverContext _buildCurrentSolverContext() {
    return _SolverContext(
      tubes: _cloneTubes(_tubes),
      mountainFillUnits: _mountainFillUnits,
      mountainCapacity: _mountainCapacity,
      refillQueues: _cloneRefillQueues(_preset?.sourceRefill),
    );
  }

  // Belirli bir history snapshot'ına karşılık gelen solver context'i oluştur.
  // Mountain fill ve refill kuyrukları o anki snapshot'tan alınır.
  _SolverContext _buildSolverContextForSnapshot(int historyIndex) {
    final snap = _history[historyIndex];
    // Refill kuyruğunu o noktaya kadar simüle etmek yerine
    // sıfırdan klonlayıp history'deki mountainFillUnits'i kullanıyoruz.
    // Refill kuyruğu için orijinal preset'ten başlatıp
    // history[0..historyIndex] boyunca refill tetiklenmiş tüpler üzerinden yeniden hesaplıyoruz.
    final refill = _cloneRefillQueues(_preset?.sourceRefill);
    // Snapshot tubes'u üzerinde kuyruğu ilerlet
    // (basit yaklaşım: mevcut _runtimeRefillQueues'u kullan, zaten o ana kadar ilerledi)
    return _SolverContext(
      tubes: _cloneTubes(snap.tubes),
      mountainFillUnits: snap.mountainFillUnits,
      mountainCapacity: _mountainCapacity,
      refillQueues: refill,
    );
  }

  _JokerDecision? _findSmartJokerDecision() {
    List<(int, int)>? solveBoard(List<List<int>> board, _SolverContext ctx) {
      final quick = _quickSolveFromState(
        board,
        includeUnlockedAdTube: _adTubeUnlocked,
        solverCtx: ctx,
      );
      if (quick != null && quick.isNotEmpty) return quick;

      final medium = _mediumSolveFromState(
        board,
        includeUnlockedAdTube: _adTubeUnlocked,
        solverCtx: ctx,
      );
      if (medium != null && medium.isNotEmpty) return medium;

      return null;
    }

    // 1) Mevcut state çözülebilir mi?
    final currentCtx = _buildCurrentSolverContext();
    final directSolution = solveBoard(_tubes, currentCtx);
    if (directSolution != null) {
      return _JokerDecision(
        from: directSolution.first.$1,
        to: directSolution.first.$2,
      );
    }

    // 2) Geçmişte çözülebilen en yakın state'i bul
    for (int rewindCount = 1; rewindCount <= _history.length; rewindCount++) {
      final snapIdx = _history.length - rewindCount;
      final snapshot = _cloneTubes(_history[snapIdx].tubes);
      final snapCtx = _buildSolverContextForSnapshot(snapIdx);
      final solution = solveBoard(snapshot, snapCtx);
      if (solution != null) {
        return _JokerDecision(
          from: solution.first.$1,
          to: solution.first.$2,
          rewindCount: rewindCount,
        );
      }
    }

    // 3) Başlangıç state'i dene
    final initialBoard = _buildInitialTubes();
    final initialCtx = _SolverContext(
      tubes: _cloneTubes(initialBoard),
      mountainFillUnits: 0,
      mountainCapacity: _mountainCapacity,
      refillQueues: _cloneRefillQueues(_preset?.sourceRefill),
    );
    final initialSolution = solveBoard(initialBoard, initialCtx);
    if (initialSolution != null) {
      return _JokerDecision(
        from: initialSolution.first.$1,
        to: initialSolution.first.$2,
        rewindCount: _history.length,
      );
    }

    return null;
  }

  Future<void> _rewindHistoryForJoker(int rewindCount) async {
    if (rewindCount <= 0) return;

    for (int i = 0; i < rewindCount; i++) {
      if (_history.isEmpty || _activePlans.isNotEmpty) break;
      _undo();
      await Future.delayed(const Duration(milliseconds: 760));
    }
  }

  void _spendCoins(int amount) {
    setState(() {
      _coins = max(0, _coins - amount);
    });
    PlayerProgress.setCoins(_coins);
    _persistLevelState();
  }

  void _addCoins(int amount) {
    if (amount <= 0) return;
    setState(() {
      _coins += amount;
    });
    PlayerProgress.setCoins(_coins);
    _persistLevelState();
  }

  int get _levelReward =>
      widget.dailyRewardCoins ??
      PlayerProgress.rewardForDifficultyDots(widget.difficulty);

  void _showBottomHint(String text) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: const Color(0xFF2A223D),
        elevation: 0,
      ),
    );
  }

  Future<bool> _showRewardedJokerAdGate() async {
    if (!_adsEnabledOnThisPlatform) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web testinde reklam kapalı')),
        );
      }
      return false;
    }

    if (_jokerAd == null || !_isJokerAdReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reklam hazır değil')),
        );
      }
      _loadJokerAd();
      return false;
    }

    final completer = Completer<bool>();
    var rewardEarned = false;

    _jokerAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _jokerAd = null;
        _isJokerAdReady = false;
        _loadJokerAd();
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _jokerAd = null;
        _isJokerAdReady = false;
        _loadJokerAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _jokerAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
      },
    );

    return completer.future;
  }

  Future<bool> _tryUnlockAdTube() async {
    if (_adTubeUnlocked) return true;

    if (!_adsEnabledOnThisPlatform) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web testinde reklam kapalı')),
        );
      }
      return false;
    }

    if (_extraTubeAd == null || !_isExtraTubeAdReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reklam hazır değil')),
        );
      }
      _loadExtraTubeAd();
      return false;
    }

    final completer = Completer<bool>();
    var rewardEarned = false;

    _extraTubeAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _extraTubeAd = null;
        _isExtraTubeAdReady = false;
        _loadExtraTubeAd();

        if (rewardEarned && mounted) {
          setState(() {
            _adTubeUnlocked = true;
          });
        }

        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _extraTubeAd = null;
        _isExtraTubeAdReady = false;
        _loadExtraTubeAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _extraTubeAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
      },
    );

    return completer.future;
  }

  Future<void> _useJokerWithEconomy() async {
    if (_jokerBusy || _activePlans.isNotEmpty || _gameWon) return;

    await _playClick();
    await _vibrateTap();

    setState(() {
      _jokerBusy = true;
    });

    try {
      var jokerGranted = false;

      if (_canBuyJoker) {
        _spendCoins(_jokerCost);
        jokerGranted = true;
      } else {
        jokerGranted = await _showRewardedJokerAdGate();
      }

      if (!jokerGranted) {
        return;
      }

      final decision = _findSmartJokerDecision();
      if (decision == null) {
        _vibrateLight();
        _showBottomHint('Joker için uygun hamle bulunamadı');
        return;
      }

      if (decision.rewindCount > 0) {
        await _rewindHistoryForJoker(decision.rewindCount);
        // Rewind sonrası tubes değişti — hamleyi taze state üzerinde yeniden hesapla
        final freshDecision = _findSmartJokerDecision();
        if (freshDecision == null) {
          _vibrateLight();
          _showBottomHint('Joker için uygun hamle bulunamadı');
          return;
        }
        await _startPour(freshDecision.from, freshDecision.to);
      } else {
        await _startPour(decision.from, decision.to);
      }
    } finally {
      if (mounted) {
        setState(() {
          _jokerBusy = false;
        });
      }
    }
  }

  (int, int)? _findTutorialMove() {
    final preferredSources = <int>[];
    for (int i = 4; i < _tubes.length; i++) {
      if (!_isLockedAdTubeIndex(i)) preferredSources.add(i);
    }
    for (int i = 0; i < min(4, _tubes.length); i++) {
      if (!_isLockedAdTubeIndex(i)) preferredSources.add(i);
    }

    final lowerTargets = <int>[
      for (int i = 4; i < _tubes.length; i++)
        if (!_isLockedAdTubeIndex(i)) i,
    ];
    final allTargets = <int>[
      for (int i = 0; i < _tubes.length; i++)
        if (!_isLockedAdTubeIndex(i)) i,
    ];

    for (final from in preferredSources) {
      if (_tubes[from].isEmpty) continue;
      for (final to in lowerTargets) {
        if (from == to) continue;
        if (_canPourIn(_tubes, from, to) && _tubes[to].isEmpty) {
          return (from, to);
        }
      }
    }

    for (final from in preferredSources) {
      if (_tubes[from].isEmpty) continue;
      for (final to in allTargets) {
        if (from == to) continue;
        if (_canPourIn(_tubes, from, to) && _tubes[to].isEmpty) {
          return (from, to);
        }
      }
    }

    for (final from in preferredSources) {
      if (_tubes[from].isEmpty) continue;
      for (final to in lowerTargets) {
        if (from == to) continue;
        if (_canPourIn(_tubes, from, to)) {
          return (from, to);
        }
      }
    }

    for (final from in preferredSources) {
      if (_tubes[from].isEmpty) continue;
      for (final to in allTargets) {
        if (from == to) continue;
        if (_canPourIn(_tubes, from, to)) {
          return (from, to);
        }
      }
    }

    return null;
  }

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_tutorialSeenKey) ?? false;
    final shouldShow =
        !alreadySeen && widget.mapNumber == 1 && widget.level == 1;

    if (!mounted || !shouldShow) return;

    final move = _findTutorialMove();
    if (move == null) return;

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    setState(() {
      _showTutorial = true;
      _tutorialStepIndex = 0;
      _tutorialFromIdx = move.$1;
      _tutorialToIdx = move.$2;
    });
  }

  Future<void> _completeTutorial({bool skipped = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialSeenKey, true);
    if (!mounted) return;

    setState(() {
      _showTutorial = false;
      _tutorialStepIndex = 0;
      _tutorialFromIdx = null;
      _tutorialToIdx = null;
    });

    if (!skipped) {
      _vibrateLight();
    }
  }

  Future<void> _handleTap(int idx) async {
    if (_gameWon) return;

    if (_showTutorial) {
      if (_tutorialStepIndex == 0) {
        if (idx != _tutorialFromIdx) return;
      } else if (_tutorialStepIndex == 1) {
        if (idx != _tutorialToIdx) return;
      } else if (_tutorialStepIndex >= 2) {
        return;
      }
    }

    if (_isLockedAdTubeIndex(idx)) {
      final unlocked = await _tryUnlockAdTube();
      if (!unlocked && mounted) {
        setState(() => _selected = null);
      }
      return;
    }

    final busy = _busyTubes;

    if (_selected == null) {
      if (busy.contains(idx)) return;
      if (_tubes[idx].isEmpty) return;
      _vibrateTap();
      setState(() {
        _selected = idx;
        if (_showTutorial &&
            _tutorialStepIndex == 0 &&
            idx == _tutorialFromIdx) {
          _tutorialStepIndex = 1;
        }
      });
      return;
    }

    if (_selected == idx) {
      _vibrateTap();
      setState(() => _selected = null);
      return;
    }

    final from = _selected!;
    final to = idx;

    _vibrateTap();
    if (!_canPourIn(_tubes, from, to)) {
      setState(() => _selected = null);
      return;
    }

    if (_isLockedAdTubeIndex(from) || _isLockedAdTubeIndex(to)) {
      setState(() => _selected = null);
      _vibrateLight();
      return;
    }

    if (!busy.contains(from) && !busy.contains(to)) {
      await _startPour(from, to);

      if (_showTutorial &&
          _tutorialStepIndex == 1 &&
          from == _tutorialFromIdx &&
          to == _tutorialToIdx) {
        if (mounted) {
          setState(() {
            _tutorialStepIndex = 2;
          });
        }
      }
      return;
    }

    setState(() => _selected = null);
    _commandQueue.addLast((from, to));
  }

  Future<void> _handleMountainTap() async {
    if (_gameWon || widget.mapNumber != 3) return;
    if (_selected == null) return;

    final from = _selected!;
    final busy = _busyTubes;
    if (busy.contains(from)) return;
    if (_isLockedAdTubeIndex(from) || _tubes[from].isEmpty) {
      setState(() => _selected = null);
      return;
    }

    await _startPourToMountain(from);
  }

  Future<void> _startPourToMountain(int from) async {
    if (from < 0 || from >= _tubes.length || _tubes[from].isEmpty) {
      _vibrateLight();
      return;
    }

    final topColor = _tubes[from].last;
    if (!_isLavaColorIndex(topColor)) {
      _vibrateLight();
      setState(() => _selected = null);
      return;
    }

    final capacity = _mountainCapacity;
    if (capacity <= 0) {
      _vibrateLight();
      setState(() => _selected = null);
      return;
    }

    final available = capacity - _mountainFillUnits;
    if (available <= 0) {
      _vibrateLight();
      setState(() => _selected = null);
      return;
    }

    final colorIdx = _tubes[from].last;
    int count = 0;
    for (int i = _tubes[from].length - 1; i >= 0; i--) {
      if (_tubes[from][i] == colorIdx) {
        count++;
      } else {
        break;
      }
    }
    count = min(count, available);
    if (count <= 0) {
      _vibrateLight();
      setState(() => _selected = null);
      return;
    }

    final plan = _TransferPlan(
      fromIdx: from,
      toIdx: -1,
      fromSnapshot: List<int>.from(_tubes[from]),
      toSnapshot: const [],
      colorIdx: colorIdx,
      count: count,
      isMountainTarget: true,
      mountainFillBefore: _mountainFillUnits,
    );

    _history.add((
      tubes: _tubes.map((t) => List<int>.from(t)).toList(),
      visibleLayerCounts: List<int>.from(_visibleLayerCounts),
      fromIdx: from,
      toIdx: from,
      mountainFillUnits: _mountainFillUnits,
      mountainLayers: _mountainLayers.map((l) => l.copyWith()).toList(),
    ));

    setState(() {
      // Yeni liste referansı — shouldRepaint(old.tube != tube) tetiklensin
      final updated = List<int>.from(_tubes[from]);
      for (int i = 0; i < count; i++) {
        updated.removeLast();
      }
      _tubes[from] = updated;

      _selected = null;
      _activePlans.add(plan);
    });

    // Volkan dolumu: akışın sıvıya değdiği anda başlasın (animasyonun %68'i = vHeadEnd)
    // Tüp yola çıkar çıkmaz değil, döküm ortasında başlasın.
    final mountainFillStartMs =
        (kPourDuration.inMilliseconds * 0.68).round(); // vHeadEnd
    Future.delayed(Duration(milliseconds: mountainFillStartMs), () {
      if (!mounted || !_activePlans.contains(plan)) return;
      setState(() {
        if (_mountainLayers.isNotEmpty &&
            _mountainLayers.last.colorIdx == colorIdx) {
          _mountainLayers[_mountainLayers.length - 1] =
              _mountainLayers.last.copyWith(
            volume: _mountainLayers.last.volume + count.toDouble(),
          );
        } else {
          _mountainLayers
              .add(_VisualLayer(colorIdx: colorIdx, volume: count.toDouble()));
        }
        _mountainFillUnits += count;
      });
    });
    _persistLevelState();
    unawaited(_persistUndoHistoryState());

    final waterStartMs = (kPourDuration.inMilliseconds * 0.58).round();
    final waterStopMs = (kPourDuration.inMilliseconds * 0.90).round();

    Future.delayed(Duration(milliseconds: waterStartMs), () {
      if (!mounted || !_activePlans.contains(plan)) return;
      SfxService.startWater();
    });

    Future.delayed(Duration(milliseconds: waterStopMs), () {
      if (!mounted) return;
      if (_activePlans.length <= 1) {
        SfxService.stopWater();
      }
    });

    Future.delayed(kPourDuration, () {
      if (!mounted) return;

      _tryRefillSourceTube(from);

      _updateBlindVisibilityAfterMountainPour(from, count);

      final didWin = _isGameDoneIn(_tubes);

      setState(() {
        _activePlans.remove(plan);
        _gameWon = didWin;
        if (didWin) {
          _loopCompletedVolcano = false;
        }
      });
      _persistLevelState();

      if (_activePlans.isEmpty) {
        SfxService.stopWater();
      }

      if (didWin) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          final allDone = <int, int>{};
          for (int i = 0; i < _tubes.length; i++) {
            if (!_isLockedAdTubeIndex(i) && _isTubeDoneIn(_tubes, i)) {
              allDone[i] = _tubes[i].first;
            }
          }
          _triggerDoneCelebration(allDone, isWin: true);
        });
      }

      _drainQueue();

      if (didWin && _activePlans.isEmpty) {
        // Eruption animasyonunun (~3.5sn) bitmesini bekle
        Future.delayed(const Duration(milliseconds: 4500), () {
          if (mounted) _showWinDialog();
        });
      }
    });
  }

  Future<void> _startPour(int from, int to) async {
    if (!_canPourIn(_tubes, from, to)) {
      _vibrateLight();
      return;
    }

    final count = _pourCountIn(_tubes, from, to);
    if (count <= 0) {
      _vibrateLight();
      return;
    }

    final plan = _TransferPlan(
      fromIdx: from,
      toIdx: to,
      fromSnapshot: List<int>.from(_tubes[from]),
      toSnapshot: List<int>.from(_tubes[to]),
      colorIdx: _tubes[from].last,
      count: count,
    );

    // Hamleyi geçmişe kaydet (doPour öncesi snapshot)
    _history.add((
      tubes: _tubes.map((t) => List<int>.from(t)).toList(),
      visibleLayerCounts: List<int>.from(_visibleLayerCounts),
      fromIdx: from,
      toIdx: to,
      mountainFillUnits: _mountainFillUnits,
      mountainLayers: _mountainLayers.map((l) => l.copyWith()).toList(),
    ));

    // Mantık durumunu hemen güncelle (animasyon gösterimi snapshot tabanlı)
    _doPourIn(_tubes, from, to);

    setState(() {
      _selected = null;
      _activePlans.add(plan);
    });
    _persistLevelState();
    unawaited(_persistUndoHistoryState());

    final waterStartMs = (kPourDuration.inMilliseconds * 0.58).round();
    final waterStopMs = (kPourDuration.inMilliseconds * 0.90).round();

    Future.delayed(Duration(milliseconds: waterStartMs), () {
      if (!mounted || !_activePlans.contains(plan)) return;
      SfxService.startWater();
    });

    Future.delayed(Duration(milliseconds: waterStopMs), () {
      if (!mounted) return;
      if (_activePlans.length <= 1) {
        SfxService.stopWater();
      }
    });

    // Animasyon biter bitmez planı kaldır
    Future.delayed(kPourDuration, () {
      _activePlans.remove(plan);

// 🔥 BURAYA AL
      _tryRefillSourceTube(from);
      _tryRefillSourceTube(to);
      if (!mounted) return;

      _updateBlindVisibilityAfterPour(from, to, count);

      final newlyDone = <int, int>{};
      for (final i in [from, to]) {
        if (!_isLockedAdTubeIndex(i) && _isTubeDoneIn(_tubes, i)) {
          newlyDone[i] = _tubes[i].first;
        }
      }
      final didWin = _isGameDoneIn(_tubes);

      setState(() {
        _activePlans.remove(plan);
        _gameWon = didWin;
        if (didWin) {
          _loopCompletedVolcano = false;
        }
      });
      _persistLevelState();

      if (_activePlans.isEmpty) {
        SfxService.stopWater();
      }

      if (didWin) {
        // Oyun bitti — son döküm görsel olarak tam bitmesini bekle, sonra tüm şişelerden aynı anda burst
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          final allDone = <int, int>{};
          for (int i = 0; i < _tubes.length; i++) {
            if (!_isLockedAdTubeIndex(i) && _isTubeDoneIn(_tubes, i)) {
              allDone[i] = _tubes[i].first;
            }
          }
          _triggerDoneCelebration(allDone, isWin: true);
        });
      } else {
        // Normal tamamlama — sadece yeni dolan şişeler
        _triggerDoneCelebration(newlyDone);
      }

      // Kuyruktaki komutları işle
      _drainQueue();

      if (didWin && _activePlans.isEmpty) {
        // Map 3'te eruption animasyonunu bekle, diğerlerinde kısa gecikme
        final winDelay = widget.mapNumber == 3
            ? const Duration(milliseconds: 4500)
            : const Duration(milliseconds: 2100);
        Future.delayed(winDelay, () {
          if (mounted) _showWinDialog();
        });
      }
    });
  }

  void _undo() {
    // Animasyon devam ediyorsa veya geçmiş yoksa işlem yapma
    if (_activePlans.isNotEmpty || _history.isEmpty) {
      _vibrateLight();
      return;
    }

    final last = _history.removeLast();

    // Sloshing animasyonu için etkilenen tüplerin renklerini al (geri dönmeden önce)
    final fromColor = last.tubes[last.fromIdx].isNotEmpty
        ? last.tubes[last.fromIdx].last
        : (_tubes[last.toIdx].isNotEmpty ? _tubes[last.toIdx].last : 0);
    final toColor = _tubes[last.toIdx].isNotEmpty ? _tubes[last.toIdx].last : 0;

    setState(() {
      _tubes = last.tubes;
      _visibleLayerCounts = List<int>.from(last.visibleLayerCounts);
      _selected = null;
      _gameWon = false;
      _commandQueue.clear();
      _mountainFillUnits = last.mountainFillUnits;
      _mountainLayers
        ..clear()
        ..addAll(last.mountainLayers.map((l) => l.copyWith()));
      _blindRevealFlashTicks.remove(last.fromIdx);
      _blindRevealFlashTicks.remove(last.toIdx);
      // Etkilenen tüplere slosh animasyonu ver
      _undoSloshingTubes[last.fromIdx] = fromColor;
      _undoSloshingTubes[last.toIdx] = toColor;
    });
    _persistLevelState();
    unawaited(_persistUndoHistoryState());

    _playClick();
    _vibrateTap();
    SfxService.startWater();

    // Slosh animasyonu bitince temizle
    Future.delayed(const Duration(milliseconds: 700), () {
      SfxService.stopWater();
      if (!mounted) return;
      setState(() {
        _undoSloshingTubes.remove(last.fromIdx);
        _undoSloshingTubes.remove(last.toIdx);
      });
    });
  }

  void _drainQueue() {
    if (_commandQueue.isEmpty) return;
    final busy = _busyTubes;

    // Kuyruktan işlenebilecekleri bul
    final toProcess = <(int, int)>[];
    final remaining = Queue<(int, int)>();

    for (final cmd in _commandQueue) {
      final (from, to) = cmd;
      // Bu komuttaki tüpler meşgul değil VE daha önce işlenecek listede yok
      final processingTubes = toProcess.fold<Set<int>>(
        <int>{},
        (s, c) => s
          ..add(c.$1)
          ..add(c.$2),
      );
      if (!busy.contains(from) &&
          !busy.contains(to) &&
          !processingTubes.contains(from) &&
          !processingTubes.contains(to)) {
        toProcess.add(cmd);
      } else {
        remaining.add(cmd);
      }
    }

    _commandQueue.clear();
    _commandQueue.addAll(remaining);

    for (final (from, to) in toProcess) {
      _startPour(from, to);
    }
  }

  void _triggerDoneCelebration(Map<int, int> bursts, {bool isWin = false}) {
    if (bursts.isEmpty || !mounted) return;
    if (isWin) {
      SfxService.playLevelComplete();
    } else {
      SfxService.playSmallSuccess();
    }
    setState(() {
      _celebratingDoneTubes.addAll(bursts);
    });
    final clearDelay = isWin
        ? const Duration(milliseconds: 1300)
        : const Duration(milliseconds: 900);
    Future.delayed(clearDelay, () {
      if (!mounted) return;
      setState(() {
        for (final idx in bursts.keys) {
          _celebratingDoneTubes.remove(idx);
        }
      });
    });
  }

  Future<void> _showWinDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Color.lerp(_theme.bgMid, Colors.black, 0.22),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'Tebrikler',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFE082).withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.07),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color:
                              const Color(0xFFFFD54F).withValues(alpha: 0.34),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFFC107).withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFF176),
                                  Color(0xFFFFB300),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFC107)
                                      .withValues(alpha: 0.34),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.toll_rounded,
                              color: Color(0xFF6A4300),
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '+$_levelReward',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _BottomActionBtn(
                    label: 'Harika',
                    color: _theme.accentColor.withValues(alpha: 0.18),
                    borderColor: _theme.accentColor.withValues(alpha: 0.45),
                    textColor: _theme.accentColor,
                    onTap: () {
                      Navigator.of(context).pop();
                      Future.microtask(_completeLevel);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exitLevel({required bool completed}) async {
    if (_isDailyMode) {
      if (completed) {
        await DailyPuzzleProgress.clearInProgressState();
        await _clearRefillState();
      } else {
        await _persistLevelState();
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        GamePageResult(
          completed: completed,
          coinsAfterLevel: _coins,
          earnedCoins: completed ? _levelReward : 0,
        ),
      );
      return;
    }

    if (completed) {
      await PlayerProgress.clearInProgressLevelState(
          widget.mapNumber, widget.level);
      await _clearRefillState();
    } else {
      await _persistLevelState();
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      GamePageResult(
        completed: completed,
        coinsAfterLevel: _coins,
        earnedCoins: completed ? _levelReward : 0,
      ),
    );
  }

  void _completeLevel() {
    if (!_levelRewardGranted) {
      _addCoins(_levelReward);
      _levelRewardGranted = true;
    }

    _playClick();
    _vibrateTap();
    _exitLevel(completed: true);
  }

  void _lowerLevel() {
    _playClick();
    _vibrateLight();
    _exitLevel(completed: false);
  }

  void _debugCompleteLevel() {
    if (_gameWon || _activePlans.isNotEmpty) return;
    _completeLevel();
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringLevelState) {
      return Scaffold(
        backgroundColor: _theme.bgDark,
        body: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    if (_missingPreset) {
      return Scaffold(
        backgroundColor: _theme.bgDark,
        body: Stack(
          children: [
            _AnimatedThemeBg(
              controller: _bgCtrl,
              theme: _theme,
              customBackground: widget.customBackground,
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.construction_rounded,
                              size: 54,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Level hazır değil',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Map ${widget.mapNumber} - Level ${widget.level} hazır değil.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) {
          _returnToMapPage();
        },
        child: Scaffold(
          backgroundColor: _theme.bgDark,
          body: Stack(
            children: [
              _AnimatedThemeBg(
                  controller: _bgCtrl,
                  theme: _theme,
                  customBackground: widget.customBackground),
              if (_gameWon)
                Positioned(
                  top: 20,
                  right: 20,
                  child: SafeArea(
                    child: IgnorePointer(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E676), Color(0xFF00C853)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x6600E676),
                              blurRadius: 14,
                              spreadRadius: 1,
                              offset: Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 0),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.topCenter,
                                        child: SizedBox(
                                          width: _stageLayout.width,
                                          height: _stageLayout.height,
                                          child: _TubeStage(
                                            mapNumber: widget.mapNumber,
                                            stageLayout: _stageLayout,
                                            tubes: _tubes,
                                            selected: _selected,
                                            activePlans: _activePlans,
                                            onTap: _handleTap,
                                            lockedAdTubeIndex:
                                                _lockedAdTubeIndex,
                                            showLockedAdTube: _showLockedAdTube,
                                            celebratingDoneTubes:
                                                _celebratingDoneTubes,
                                            gameWon: _gameWon,
                                            undoSloshingTubes:
                                                _undoSloshingTubes,
                                            tutorialActive: _showTutorial,
                                            tutorialStepIndex:
                                                _tutorialStepIndex,
                                            tutorialFromIdx: _tutorialFromIdx,
                                            tutorialToIdx: _tutorialToIdx,
                                            blindMode: _blindModeEnabled,
                                            visibleLayerCounts:
                                                _visibleLayerCounts,
                                            blindRevealFlashTicks:
                                                _blindRevealFlashTicks,
                                            tubeStyles: {
                                              for (int i = 0;
                                                  i < _tubes.length;
                                                  i++)
                                                i: _tubeStyleForIndex(i),
                                            },
                                            tubeCapacities: {
                                              for (int i = 0;
                                                  i < _tubes.length;
                                                  i++)
                                                i: _tubeCapacityIn(_tubes, i),
                                            },
                                            onMountainTap: _handleMountainTap,
                                            mountainFillPercent:
                                                _mountainFillPercent,
                                            mountainLayers:
                                                List<_VisualLayer>.from(
                                              _mountainLayers
                                                  .map((l) => l.copyWith()),
                                            ),
                                            mountainCapacity: _mountainCapacity,
                                            sourceRefillTubeIndexes: {
                                              ...?_preset
                                                  ?.sourceRefill?.tubeIndexes,
                                            },
                                            mountainReservoirKey:
                                                _mountainReservoirKey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Map 3 için dağ resminin üstüne boşluk bırak
                    SizedBox(height: widget.mapNumber == 3 ? 160 : 8),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                bottom: 175,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showTutorial ? 0.22 : 1.0,
                  child: IgnorePointer(
                    ignoring: _showTutorial,
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _UndoButton(
                            canUndo: _history.isNotEmpty &&
                                _activePlans.isEmpty &&
                                !_gameWon,
                            accentColor: _theme.accentColor,
                            onTap: _undo,
                          ),
                          const SizedBox(height: 8),
                          _JokerButton(
                            enabled: !_gameWon &&
                                _activePlans.isEmpty &&
                                !_jokerBusy,
                            busy: _jokerBusy,
                            canBuy: _canBuyJoker,
                            cost: _jokerCost,
                            accentColor: _theme.accentColor,
                            onTap: _useJokerWithEconomy,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Sıvı animasyonu — PNG'nin arkasında, bottom:0 ile tam alta hizalı
              if (widget.mapNumber == 3)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (ctx, _) {
                      final screenW =
                          MediaQuery.of(ctx).size.width.clamp(280.0, 500.0);
                      final reservoirH = screenW / 1.776;
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0.0,
                          end: _mountainFillPercent,
                        ),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeInOut,
                        builder: (ctx, animatedFill, _) {
                          return MountainTubeReservoir(
                            key: _mountainReservoirKey,
                            width: screenW,
                            height: reservoirH,
                            fillPercent: animatedFill,
                            liquidColor: _mountainLayers.isEmpty
                                ? const Color(0xFFFF6A00)
                                : (kColors[_mountainLayers.last.colorIdx]
                                    ['fill'] as Color),
                            glow: false,
                            onTap: _handleMountainTap,
                            layers: List<_VisualLayer>.from(
                                _mountainLayers.map((l) => l.copyWith())),
                            capacity: _mountainCapacity,
                            gameWon: _gameWon,
                            loopEruption: _loopCompletedVolcano,
                          );
                        },
                      );
                    },
                  ),
                ),
              // Dağ resmi — ekranın tam altına hizalı, tam genişlikte (animasyonun üstünde)
              if (widget.mapNumber == 3)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Image.asset(
                      kVolcanoReservoirSvgAsset,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                ),
              if (_showTutorial) _buildTutorialOverlay(),
            ],
          ),
        ));
  }

  Widget _buildTutorialOverlay() {
    final stepIndex =
        _tutorialStepIndex.clamp(0, _tutorialSteps.length - 1).toInt();
    final step = _tutorialSteps[stepIndex];
    final bool isFinalStep = stepIndex == _tutorialSteps.length - 1;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _showTutorial ? 1 : 0,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: true,
            child: Container(
              color: Colors.black.withValues(alpha: 0.48),
            ),
          ),
          Align(
            alignment: step.bubbleAlignment,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12081F).withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.26),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    _theme.accentColor.withValues(alpha: 0.16),
                              ),
                              child: Icon(
                                isFinalStep
                                    ? Icons.check_circle_rounded
                                    : Icons.touch_app_rounded,
                                color: _theme.accentColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: step.title.isEmpty
                                  ? const SizedBox()
                                  : Text(
                                      step.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                            Text(
                              '${_tutorialStepIndex + 1}/${_tutorialSteps.length}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: 13.5,
                            height: 1.30,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (!isFinalStep)
                              TextButton(
                                onPressed: () async {
                                  await _playClick();
                                  await _vibrateTap();
                                  _completeTutorial(skipped: true);
                                },
                                child: Text(
                                  'Geç',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            if (isFinalStep)
                              GestureDetector(
                                onTap: () async {
                                  await _playClick();
                                  await _vibrateTap();
                                  _completeTutorial();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _theme.accentColor
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _theme.accentColor
                                          .withValues(alpha: 0.42),
                                    ),
                                  ),
                                  child: Text(
                                    'Tamam',
                                    style: TextStyle(
                                      color: _theme.accentColor,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              CoinPill(coinsValue: _coins),
              const Spacer(),
              _TestLevelButton(
                enabled: !_gameWon && _activePlans.isEmpty,
                accentColor: _theme.accentColor,
                onTap: _debugCompleteLevel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _lowerLevel,
                      child: Ink(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    widget.customTitle ?? _theme.name,
                    style: TextStyle(
                      color: _theme.primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                      shadows: [
                        Shadow(
                          color: _theme.primaryColor.withValues(alpha: 0.6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await _playClick();
                        await _vibrateTap();
                        if (!mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                      child: Ink(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
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
}

// ─────────────────────────────────────────────
// ARKA PLAN — map_theme.dart ile aynı stil
// ─────────────────────────────────────────────

class _AnimatedThemeBg extends StatelessWidget {
  final Animation<double> controller;
  final MapTheme theme;
  final List<Color>? customBackground;

  const _AnimatedThemeBg(
      {required this.controller, required this.theme, this.customBackground});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Gradyan taban
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: customBackground ??
                  [theme.bgDark, theme.bgMid, theme.bgLight, theme.bgDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      // Tema'ya özgü painter efekti
      Positioned.fill(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) => CustomPaint(
            painter: buildMapBgPainter(theme, controller.value),
          ),
        ),
      ),
      // Glow blob'lar
      AnimatedBuilder(
        animation: controller,
        builder: (ctx, __) {
          final t = controller.value;
          final size = MediaQuery.of(ctx).size;
          final w = size.width;
          final h = size.height;
          return Stack(children: [
            _glow(-90 + sin(t * pi) * 20, -120 + cos(t * pi) * 15, 270,
                theme.primaryColor.withValues(alpha: 0.18)),
            _glow(w - 170 + cos(t * pi) * 20, 120 + sin(t * pi) * 18, 250,
                theme.secondaryColor.withValues(alpha: 0.14)),
            _glow(-80 + sin(t * pi * 1.3) * 16, h - 200 + cos(t * pi) * 20, 260,
                theme.accentColor.withValues(alpha: 0.12)),
            _glow(w - 140 + cos(t * pi * 1.2) * 18, h - 180 + sin(t * pi) * 22,
                230, theme.primaryColor.withValues(alpha: 0.12)),
          ]);
        },
      ),
    ]);
  }

  Widget _glow(double l, double t, double sz, Color c) => Positioned(
        left: l,
        top: t,
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
// ALT BUTON
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// GERİ ALMA BUTONU
// ─────────────────────────────────────────────

class _JokerButton extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final bool canBuy;
  final int cost;
  final Color accentColor;
  final VoidCallback onTap;

  const _JokerButton({
    required this.enabled,
    required this.busy,
    required this.canBuy,
    required this.cost,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 220),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(14)),
          onTap: enabled ? onTap : null,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              border: Border.all(
                color: canBuy
                    ? accentColor.withValues(alpha: 0.60)
                    : Colors.white.withValues(alpha: 0.24),
                width: 1.5,
              ),
              boxShadow: canBuy
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.22),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: busy
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          canBuy ? accentColor : Colors.white,
                        ),
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        canBuy
                            ? Icons.auto_fix_high_rounded
                            : Icons.ondemand_video_rounded,
                        color: canBuy ? accentColor : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        canBuy ? '$cost' : 'İzle',
                        style: TextStyle(
                          color: canBuy ? accentColor : Colors.white,
                          fontSize: canBuy ? 13 : 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  final bool canUndo;
  final Color accentColor;
  final VoidCallback onTap;

  const _UndoButton({
    required this.canUndo,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: canUndo ? 1.0 : 0.32,
      duration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(14)),
          onTap: canUndo ? onTap : null,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              border: Border.all(
                color: canUndo
                    ? accentColor.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.14),
                width: 1.4,
              ),
              boxShadow: canUndo
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.18),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                Icons.undo_rounded,
                color: canUndo
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.45),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TestLevelButton extends StatelessWidget {
  final bool enabled;
  final Color accentColor;
  final VoidCallback onTap;

  const _TestLevelButton({
    required this.enabled,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.32,
      duration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            height: 34,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled
                    ? accentColor.withValues(alpha: 0.52)
                    : Colors.white.withValues(alpha: 0.14),
                width: 1.4,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.16),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_double_arrow_up_rounded,
                  color: enabled
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.45),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'TEST',
                  style: TextStyle(
                    color: enabled
                        ? accentColor
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  const _BottomActionBtn({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────
// TÜPLER SAHNESİ
// ─────────────────────────────────────────────

class _TutorialStep {
  final String title;
  final String message;
  final Alignment bubbleAlignment;

  const _TutorialStep({
    required this.title,
    required this.message,
    required this.bubbleAlignment,
  });
}

class _TubeStage extends StatefulWidget {
  final int mapNumber;
  final _ResolvedStageLayout stageLayout;
  final List<List<int>> tubes;
  final int? selected;
  final List<_TransferPlan> activePlans;
  final void Function(int) onTap;
  final int lockedAdTubeIndex;
  final bool showLockedAdTube;
  final Map<int, int> celebratingDoneTubes;
  final bool gameWon;
  final Map<int, int> undoSloshingTubes;
  final bool tutorialActive;
  final int tutorialStepIndex;
  final int? tutorialFromIdx;
  final int? tutorialToIdx;
  final bool blindMode;
  final List<int> visibleLayerCounts;
  final Map<int, int> blindRevealFlashTicks;
  final Map<int, PuzzleTubeStyle> tubeStyles;
  final Map<int, int> tubeCapacities;
  final VoidCallback? onMountainTap;
  final double mountainFillPercent;
  final List<_VisualLayer> mountainLayers;
  final int mountainCapacity;
  final Set<int> sourceRefillTubeIndexes;
  final GlobalKey? mountainReservoirKey;

  const _TubeStage({
    required this.mapNumber,
    required this.stageLayout,
    required this.tubes,
    required this.selected,
    required this.activePlans,
    required this.onTap,
    required this.lockedAdTubeIndex,
    required this.showLockedAdTube,
    required this.celebratingDoneTubes,
    this.gameWon = false,
    this.undoSloshingTubes = const {},
    this.tutorialActive = false,
    this.tutorialStepIndex = 0,
    this.tutorialFromIdx,
    this.tutorialToIdx,
    this.blindMode = false,
    this.visibleLayerCounts = const [],
    this.blindRevealFlashTicks = const {},
    this.tubeStyles = const {},
    this.tubeCapacities = const {},
    this.onMountainTap,
    this.mountainFillPercent = 0.0,
    this.mountainLayers = const [],
    this.mountainCapacity = 18,
    this.sourceRefillTubeIndexes = const <int>{},
    this.mountainReservoirKey,
  });

  @override
  State<_TubeStage> createState() => _TubeStageState();
}

class _TubeStageState extends State<_TubeStage> {
  late List<GlobalKey> _keys;
  final GlobalKey _ownMountainKey = GlobalKey();
  GlobalKey get _mountainKey => widget.mountainReservoirKey ?? _ownMountainKey;

  bool get showMountainReservoir =>
      widget.mapNumber == 3 &&
      !widget.tubeStyles.values.contains(PuzzleTubeStyle.largeCollector);

  Offset? mountainAnchorPos(Offset localAnchor) {
    final box = _mountainKey.currentContext?.findRenderObject() as RenderBox?;
    final stageBox = context.findRenderObject() as RenderBox?;
    if (box == null || stageBox == null || !box.hasSize || !stageBox.hasSize) {
      return null;
    }
    return box.localToGlobal(localAnchor) - stageBox.localToGlobal(Offset.zero);
  }

  Offset? _mountainMouthPos() {
    final targetCtx = _mountainKey.currentContext;
    final stageBox = context.findRenderObject() as RenderBox?;
    final mountainBox = targetCtx?.findRenderObject() as RenderBox?;

    if (targetCtx == null || stageBox == null || mountainBox == null)
      return null;
    if (!stageBox.hasSize || !mountainBox.hasSize) return null;

    // Ağız merkezi: clip path ağzıyla hizalı (h * 0.10)
    final localMouth = Offset(
      mountainBox.size.width / 2,
      mountainBox.size.height * 0.10,
    );

    return mountainBox.localToGlobal(localMouth, ancestor: stageBox);
  }

  Offset? _mountainSurfacePos(double units) {
    final targetCtx = _mountainKey.currentContext;
    final stageBox = context.findRenderObject() as RenderBox?;
    final mountainBox = targetCtx?.findRenderObject() as RenderBox?;

    if (targetCtx == null || stageBox == null || mountainBox == null)
      return null;
    if (!stageBox.hasSize || !mountainBox.hasSize) return null;

    final h = mountainBox.size.height;
    final w = mountainBox.size.width;

    final fillRatio = (units / widget.mountainCapacity).clamp(0.0, 1.0);

    // İç dolgu alanı: SVG’ye daha uygun dar bölge
    // İç dolgu alanı: clip path boyun yüksekliğiyle (h*0.30) tutarlı
    // Doldurulabilir alan: agiz (h*0.10) ile dip (h*1.0) arasi
    final topInset = h * 0.10;
    const bottomInset = 0.0;
    final usableHeight = h - topInset - bottomInset;

    final localY = h - bottomInset - usableHeight * fillRatio;
    final localSurface = Offset(w / 2, localY);

    return mountainBox.localToGlobal(localSurface, ancestor: stageBox);
  }

  @override
  void initState() {
    super.initState();
    _rebuildKeys();
  }

  @override
  void didUpdateWidget(_TubeStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tubes.length != widget.tubes.length) _rebuildKeys();
  }

  void _rebuildKeys() {
    _keys = List.generate(widget.tubes.length, (_) => GlobalKey());
  }

  Offset? _localPos(int idx) => _anchorPos(idx, Offset.zero);

  Offset? _anchorPos(int idx, Offset localAnchor) {
    if (idx < 0 || idx >= _keys.length) return null;
    final box = _keys[idx].currentContext?.findRenderObject() as RenderBox?;
    final stageBox = context.findRenderObject() as RenderBox?;
    if (box == null || stageBox == null || !box.hasSize || !stageBox.hasSize) {
      return null;
    }

    return box.localToGlobal(localAnchor) - stageBox.localToGlobal(Offset.zero);
  }

  Offset? _realTargetMouthPos(int idx) {
    if (idx < 0 || idx >= _keys.length) return null;

    final targetCtx = _keys[idx].currentContext;
    final stageBox = context.findRenderObject() as RenderBox?;
    final tubeBox = targetCtx?.findRenderObject() as RenderBox?;

    if (targetCtx == null || stageBox == null || tubeBox == null) return null;
    if (!stageBox.hasSize || !tubeBox.hasSize) return null;

    final style = widget.tubeStyles[idx] ?? PuzzleTubeStyle.classic;
    if (style == PuzzleTubeStyle.largeCollector) {
      final localMouth =
          Offset(tubeBox.size.width / 2, tubeBox.size.height * 0.14);
      return tubeBox.localToGlobal(localMouth, ancestor: stageBox);
    }

    final localMouth = Offset(
      tubeBox.size.width / 2,
      kMouthEntryY,
    );

    return tubeBox.localToGlobal(localMouth, ancestor: stageBox);
  }

  Offset? _realTargetSurfacePos(int idx, double units) {
    if (idx < 0 || idx >= _keys.length) return null;

    final targetCtx = _keys[idx].currentContext;
    final stageBox = context.findRenderObject() as RenderBox?;
    final tubeBox = targetCtx?.findRenderObject() as RenderBox?;

    if (targetCtx == null || stageBox == null || tubeBox == null) return null;
    if (!stageBox.hasSize || !tubeBox.hasSize) return null;

    final capacity = (widget.tubeCapacities[idx] ?? kCap).toDouble();
    final fillRatio = (units / capacity).clamp(0.0, 1.0);
    final style = widget.tubeStyles[idx] ?? PuzzleTubeStyle.classic;

    if (style == PuzzleTubeStyle.largeCollector) {
      final basinBottom = tubeBox.size.height * 0.78;
      final basinTop = tubeBox.size.height * 0.28;
      final localY = basinBottom - (basinBottom - basinTop) * fillRatio;
      final localSurface = Offset(tubeBox.size.width / 2, localY);
      return tubeBox.localToGlobal(localSurface, ancestor: stageBox);
    }

    final localY = kLiquidBotY - (kLiquidBotY - kLiquidTopY) * fillRatio;

    final localSurface = Offset(tubeBox.size.width / 2, localY);
    return tubeBox.localToGlobal(localSurface, ancestor: stageBox);
  }

  Widget _tubeItem(int idx, {double topPadding = 0}) {
    // Aktif animasyonda yalnızca kaynak tüp sahneden gizlenir.
    // Hedef tüp sahnede sabit kalır ve dolum yerinde animasyonlanır.
    final hiddenSources = widget.activePlans.map((p) => p.fromIdx).toSet();
    final isLockedAdTube =
        widget.showLockedAdTube && idx == widget.lockedAdTubeIndex;
    final isSourceRefillTube = widget.sourceRefillTubeIndexes.contains(idx);
    final bool tutorialTarget = widget.tutorialActive &&
        ((widget.tutorialStepIndex == 0 && idx == widget.tutorialFromIdx) ||
            (widget.tutorialStepIndex == 1 && idx == widget.tutorialToIdx));
    final bool dimForTutorial = widget.tutorialActive && !tutorialTarget;

    final activeTargetPlan =
        widget.activePlans.cast<_TransferPlan?>().firstWhere(
              (p) => p != null && !p.isMountainTarget && p.toIdx == idx,
              orElse: () => null,
            );

    final isTargetOfPlan = activeTargetPlan != null;
    final showSelected = widget.selected == idx && !isTargetOfPlan;

    final tubeStyle = widget.tubeStyles[idx] ?? PuzzleTubeStyle.classic;
    final tubeCapacity = widget.tubeCapacities[idx] ?? kCap;

    Widget tubeView;
    if (isTargetOfPlan) {
      final plan = activeTargetPlan;
      tubeView = TweenAnimationBuilder<double>(
        key: ValueKey('target_fill_${plan.fromIdx}_${plan.toIdx}'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: kPourDuration,
        curve: Curves.linear,
        builder: (context, timeline, _) {
          const pPourEnd = 0.90;
          const vHeadEnd =
              0.68; // akışın sıvıya değdiği an (vStreamStart 0.58 + 0.10)

          // Dolum akışın sıvıya değdiği anda başlar, pPourEnd'de tamamlanır.
          final incomingPhase = timeline <= vHeadEnd
              ? 0.0
              : Curves.easeInOutCubic.transform(
                  ((timeline - vHeadEnd) / max(0.0001, pPourEnd - vHeadEnd))
                      .clamp(0.0, 1.0),
                );
          final incoming = plan.count * incomingPhase;
          final receivePhase = incomingPhase;
          final receiveSlosh =
              sin(receivePhase * pi * 3.2) * (1.0 - receivePhase) * 0.30;
          final receiveSplash =
              sin((receivePhase * pi).clamp(0.0, pi)).abs() * 0.90;
          final receiveBubbleBurst =
              sin((receivePhase * pi * 0.9).clamp(0.0, pi)).abs() * 0.95;
          final receiveFlow =
              Curves.easeOut.transform(receivePhase.clamp(0.0, 1.0));
          return _TubeWidget(
            tube: plan.toSnapshot,
            isSelected: false,
            incomingColorIdx: widget.blindMode ? null : plan.colorIdx,
            incomingVolume: widget.blindMode ? 0.0 : incoming,
            slosh: receiveSlosh,
            splash: receiveSplash,
            pourProgress: incomingPhase,
            bubbleBurst: receiveBubbleBurst,
            receiveFlow: receiveFlow,
            blindMode: widget.blindMode,
            visibleLayerCount: widget.visibleLayerCounts[idx],
            revealGlowTick: widget.blindRevealFlashTicks[idx] ?? 0,
            tubeStyle: tubeStyle,
            capacity: tubeCapacity,
          );
        },
      );
    } else if (widget.undoSloshingTubes.containsKey(idx)) {
      // Geri alma animasyonu — sıvı çalkantısı
      tubeView = TweenAnimationBuilder<double>(
        key: ValueKey('undo_slosh_$idx'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, _) {
          // Çalkantı: önce güçlü, sonra sönümleniyor
          final decay = (1.0 - t);
          final slosh = sin(t * pi * 4.5) * decay * 0.55;
          final bubble = sin((t * pi * 1.2).clamp(0.0, pi)).abs() * decay * 0.7;
          return _TubeWidget(
            tube: widget.tubes[idx],
            isSelected: showSelected,
            slosh: slosh,
            bubbleBurst: bubble,
            incomingColorIdx: null,
            incomingVolume: 0.0,
            blindMode: widget.blindMode,
            visibleLayerCount: widget.visibleLayerCounts[idx],
            revealGlowTick: widget.blindRevealFlashTicks[idx] ?? 0,
            tubeStyle: tubeStyle,
            capacity: tubeCapacity,
          );
        },
      );
    } else {
      tubeView = _TubeWidget(
        tube: widget.tubes[idx],
        isSelected: showSelected,
        incomingColorIdx: null,
        incomingVolume: 0.0,
        blindMode: widget.blindMode,
        visibleLayerCount: widget.visibleLayerCounts[idx],
        revealGlowTick: widget.blindRevealFlashTicks[idx] ?? 0,
        tubeStyle: tubeStyle,
        capacity: tubeCapacity,
      );
    }

    final isCollector = tubeStyle == PuzzleTubeStyle.largeCollector;
    final double renderWidth = isCollector ? kBasinW : kWidgetW;
    final double renderHeight = isCollector ? kBasinH : kWidgetH;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: KeyedSubtree(
        key: _keys[idx],
        child: SizedBox(
          width: renderWidth,
          height: renderHeight,
          child: GestureDetector(
            onTap: () => widget.onTap(idx),
            child: Opacity(
              opacity: hiddenSources.contains(idx) ? 0.0 : 1.0,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isLockedAdTube
                        ? 0.20
                        : dimForTutorial
                            ? 0.16
                            : 1.0,
                    child: tubeView,
                  ),
                  if (isLockedAdTube)
                    Positioned(
                      right: -2,
                      bottom: 6,
                      child: IgnorePointer(
                        child: _AdUnlockBadge(
                            color: Colors.white.withValues(alpha: 0.90)),
                      ),
                    ),
                  if (isSourceRefillTube)
                    Positioned(
                      top: -6,
                      right: 8,
                      child: IgnorePointer(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2A1600).withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFC107)
                                  .withValues(alpha: 0.95),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8F00)
                                    .withValues(alpha: 0.28),
                                blurRadius: 6,
                                spreadRadius: 0.4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.autorenew_rounded,
                              size: 12,
                              color: Color(0xFFFFC107),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.celebratingDoneTubes.containsKey(idx))
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _TubeDoneBurst(
                          colorIdx: widget.celebratingDoneTubes[idx]!,
                          isGameWin: widget.gameWon,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(List<int> indices, {double topPadding = 0}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final idx in indices) ...[
          _tubeItem(idx, topPadding: topPadding),
          if (idx != indices.last) SizedBox(width: widget.stageLayout.tubeGap),
        ],
      ],
    );
  }

  Widget _buildRowsLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: widget.stageLayout.topOffset),
        for (int i = 0; i < widget.stageLayout.rows.length; i++) ...[
          _row(
            widget.stageLayout.rows[i],
            topPadding: widget.stageLayout.rowTopPaddings[i],
          ),
          if (i != widget.stageLayout.rows.length - 1)
            SizedBox(height: widget.stageLayout.rowGap),
        ],
      ],
    );
  }

  Widget _buildManualLayout() {
    return SizedBox(
      width: widget.stageLayout.width,
      height: widget.stageLayout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final pos in widget.stageLayout.positions)
            Positioned(
              left: pos.x,
              top: pos.y + widget.stageLayout.topOffset,
              child: _tubeItem(pos.index),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: widget.stageLayout.modeLayout.mode == StageLayoutMode.manual
                ? _buildManualLayout()
                : _buildRowsLayout(),
          ),
        ),
        // Paralel animasyonlar — her aktif plan için ayrı FlyingTube
        for (final plan in widget.activePlans)
          _FlyingTube(
            key: ValueKey('fly_${plan.fromIdx}_${plan.toIdx}'),
            plan: plan,
            getPos: _localPos,
            getAnchor: _anchorPos,
            getRealTargetMouth: _realTargetMouthPos,
            getRealTargetSurface: _realTargetSurfacePos,
            getMountainMouth: _mountainMouthPos,
            getMountainSurface: _mountainSurfacePos,
            blindMode: widget.blindMode,
            visibleLayerCount: plan.fromSnapshot.isEmpty
                ? 0
                : min(1, plan.fromSnapshot.length),
            revealGlowTick: 0,
            tubeStyle:
                widget.tubeStyles[plan.fromIdx] ?? PuzzleTubeStyle.classic,
            capacity: widget.tubeCapacities[plan.fromIdx] ?? kCap,
            targetCapacity: widget.tubeCapacities[plan.toIdx] ?? kCap,
          ),
        // volkan_hazne.png artık GamePage seviyesinde full-width çiziliyor
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VOLKAN REZERVUARI — animasyonlu sıvı + krater ağız efektleri
// ─────────────────────────────────────────────────────────────────────────────

class MountainTubeReservoir extends StatefulWidget {
  final double width;
  final double height;
  final double fillPercent;
  final Color liquidColor;
  final bool glow;
  final VoidCallback? onTap;
  final List<_VisualLayer> layers;
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
        speed: 0.0020 +
            _rng.nextDouble() *
                0.0012, // çok yavaş — 0.002 = ~50 tick = ~5 saniye
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
      speed: 0.0014 + _rng.nextDouble() * 0.0008, // duman alevden daha yavaş
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
            // İç rezervuar
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
            // Krater ağzı efektleri — PNG'nin arkasında, kratere hizalı
            // Ağız y = height * 0.30, efektler oradan yukarı taşar
            Positioned(
              left: -60,
              right: -60,
              top: -widget.height * 0.12, // yukarı kaydırıldı
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
                    // ağız lokal y: container'ın negatif top offset'ini telafi et
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

// ─────────────────────────────────────────────────────────────────────────────
// KRATER AĞZI EFEKTLERİ — alev huzmeleri + duman bulutları
// ─────────────────────────────────────────────────────────────────────────────

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

  // Alev için envelope: yavaş fade-in, parlak yanma, yavaş fade-out
  double _flameA(double phase, double max) {
    if (phase < 0.20) return max * (phase / 0.20);
    if (phase < 0.62) return max;
    return max * (1.0 - (phase - 0.62) / 0.38);
  }

  // Duman için envelope: geç başlar, daha da yavaş solar
  double _smokeA(double phase, double max) {
    if (phase < 0.12) return max * (phase / 0.12);
    if (phase < 0.55) return max;
    return max * (1.0 - (phase - 0.55) / 0.45);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // left:-60 offset ile genişletilmiş canvas'ta ağız x merkezi
    final mouthX = size.width * 0.5;
    final mouthY = mouthLocalY;

    // Krater sürekli hafif parıltı
    if (fillPercent > 0.04) {
      canvas.drawCircle(
        Offset(mouthX, mouthY),
        14 + fillPercent * 18,
        Paint()
          ..color = kLavaOrange.withValues(alpha: 0.04 + fillPercent * 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    // Döküm anında krater parlaması — yavaşça söner
    if (pourGlow > 0.01) {
      canvas.drawCircle(
        Offset(mouthX, mouthY),
        20 + pourGlow * 24,
        Paint()
          ..color = kLavaGlow.withValues(alpha: pourGlow * 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    // ── DUMAN BULUTLARI — alevlerden sonra yavaşça yükselir ─────────────────
    for (final s in smokes) {
      final alpha = _smokeA(s.phase, s.maxAlpha);
      if (alpha < 0.004) continue;

      final rise = s.phase * 120; // daha yüksek yükselme
      final cx = mouthX + s.laneX * 28 + s.drift * rise * 0.5;
      final cy = mouthY - rise;
      final radius = s.size * 1.6 + s.phase * 40; // daha büyük radius

      // Alevden koyu griye renk geçişi
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
      // İkinci daha küçük parlak duman katmanı
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.55,
        Paint()
          ..color = kLavaOrange.withValues(alpha: alpha * 0.45 * (1 - s.phase))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3),
      );
    }

    // ── ALEV HUZMELERİ — kraterin ağzından yavaşça yükselir ─────────────────
    for (final f in flames) {
      final alpha = _flameA(f.phase, f.maxAlpha);
      if (alpha < 0.004) continue;

      // Alev tabanı ağız noktasında, ucu phase ile yükselir
      final baseX = mouthX + f.laneX * 22; // daha geniş yayılım
      final peakH = f.height * 1.45 * min(f.phase * 2.0, 1.0); // %45 daha uzun
      final tipX = baseX + f.lean * peakH;
      final tipY = mouthY - peakH;

      final midY = lerpDouble(mouthY, tipY, 0.52)!;

      // Daha geniş alev gövdesi
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

      // Renk gradyanı: dip parlak → orta turuncu-kırmızı → uç soluk kırmızı
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

      // Daha belirgin alev kenar parlaması
      canvas.drawPath(
        flamePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = kLavaGlow.withValues(alpha: alpha * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );

      // İç parlak çekirdek
      final corePath = Path()
        ..moveTo(baseX - 1, mouthY)
        ..quadraticBezierTo(
            baseX - 4, midY + (tipY - midY) * 0.3, tipX, tipY + peakH * 0.18)
        ..quadraticBezierTo(
            baseX + 4, midY + (tipY - midY) * 0.3, baseX + 1, mouthY)
        ..close();
      canvas.drawPath(
        corePath,
        Paint()
          ..color = kLavaCore.withValues(alpha: alpha * 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );
    }

    // ── ERUPTION: LAV VE ALEV FIRLATIMLARI ───────────────────────────────────
    if (projectiles.isNotEmpty) {
      // Eruption başlangıcında büyük parlama
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
        // Balistik yörünge: yatay sabit hız, dikey yerçekimi var
        final t = p.phase;
        final eased = t; // lineer zaman
        // Yatay: açıya göre
        final dx = cos(p.angle) * p.power * eased;
        // Dikey: önce yukarı, sonra aşağı (yerçekimi)
        final dy = sin(p.angle) * p.power * eased + 0.5 * 380 * eased * eased;
        final px = mouthX + dx;
        final py = mouthY + dy;

        // Alpha: ortada parlak, başta ve sonda solar
        final alpha = p.maxAlpha *
            (t < 0.15
                ? t / 0.15
                : t > 0.65
                    ? (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0)
                    : 1.0);

        if (alpha < 0.01) continue;

        if (p.isFlame) {
          // Alev topu — gradient dolgu
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
          // Parlak çekirdek
          canvas.drawCircle(
            Offset(px, py),
            r * 0.35,
            Paint()..color = kLavaCore.withValues(alpha: alpha * 0.90),
          );
        } else {
          // Lav damlası — oval, düşerken uzar
          final r = p.size;
          final stretchY = 1.0 + t * 1.2; // düşerken aşağı uzar
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

          // Damla izi (kuyruk)
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

// ─────────────────────────────────────────────────────────────────────────────
// VOLKAN İÇ REZERVUAR — sıvı + iç alevler + kor
// ─────────────────────────────────────────────────────────────────────────────

class _VolcanoPainter extends CustomPainter {
  final List<_VisualLayer> layers;
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

  // Dağın iç alanını tanımlayan clip path — PNG ile hizalı
  // Ağız: h*0.18 (daha yukarı), dip: h*1.0 (tam alt), sol taraf daha geniş
  Path _clipPath(Size size) {
    final w = size.width;
    final h = size.height;
    // Ağıza doğru belirgin daralma: alt geniş (w*0.05..0.95),
    // orta kısımda hızla daralır, ağızda sadece w*0.42..0.58 genişliğinde
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
    if (_isLavaColorIndex(colorIdx)) return kLavaRed;
    return _solidColorForIndex(colorIdx);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final clipPath = _clipPath(size);
    final bounds = clipPath.getBounds();
    final sloshShift = slosh * size.width * 0.055; // daha geniş sağa-sola dalga
    final normalizedFill = fillPercent.clamp(0.0, 1.0);

    // Dış glow — kırmızımsı, doluma göre
    canvas.drawPath(
      clipPath,
      Paint()
        ..color = kLavaRed.withValues(
            alpha: 0.07 + normalizedFill * 0.13 + interiorGlow * 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.save();
    canvas.clipPath(clipPath);

    final safeCapacity = max(1, capacity);
    // Lineer doldurma — 16 sıvıdan her biri eşit yükseklik kaplar
    final easedFill = normalizedFill.clamp(0.0, 1.0);
    // Doldurulabilir alan: ağız (h*0.28) ile dip (h*1.0) arası = h*0.72
    // bounds zaten clipPath'in bounding box'ı, ağız bounds.top ~ h*0.28
    final fillableHeight = bounds.bottom - bounds.top;
    final totalFillHeight = fillableHeight * easedFill;
    final liquidTopBase = bounds.bottom - totalFillHeight;

    // Dipte kor parlaması — döküm gelince daha parlak
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

    // Arka lav tabanı — derin kızıl
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

    // İç alevler — kırmızı ağırlıklı, döküm gelince canlanır
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
        final topY = max(flameTopLimit, bounds.bottom - 3 - rawH);

        final path = Path()
          ..moveTo(x, bounds.bottom - 3)
          ..quadraticBezierTo(x - 7 - sin(time * pi * 2 + i) * 2,
              lerpDouble(bounds.bottom - 3, topY, 0.58)!, x, topY)
          ..quadraticBezierTo(x + 7 + cos(time * pi * 2 + i) * 2,
              lerpDouble(bounds.bottom - 3, topY, 0.58)!, x, bounds.bottom - 3)
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

    // Katmanlar
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
              bounds.left - 18, top, bounds.right + 18, currentBottom + 8);
          final base = _layerColor(layer.colorIdx);
          final isLava = _isLavaColorIndex(layer.colorIdx);

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
                        const Color(0xFFBB2200)
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
                bounds.left - 10, edgeY, bounds.right + 10, edgeY + 2.0),
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
                  Rect.fromLTRB(bounds.left, edgeY, bounds.right, edgeY + 2.0)),
          );
          currentBottom = top;
        }
      }
    } else if (normalizedFill > 0.0) {
      final rect = Rect.fromLTRB(bounds.left - 18, liquidTopBase,
          bounds.right + 18, bounds.bottom + 8);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF580000),
              kLavaRed,
              const Color(0xFFBB2200)
            ],
            stops: const [0.0, 0.52, 1.0],
          ).createShader(rect),
      );
    }

    // Üst dalga yüzeyi
    if (normalizedFill > 0.0) {
      final waveY = liquidTopBase;
      // Yavaş, temiz dalga — wavePhase 0..1 döngü (~4 sn)
      final wSlowBase = wavePhase * 2 * pi;
      final waveAmp = 6.0 + slosh.abs() * 6.0;

      // Her kontrol noktası farklı fazda sinüs → gerçekçi yavaş dalga
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
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

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

    // Kabarcıklar — dipten yukarı sürekli yükselme döngüsü
    if (normalizedFill > 0.05) {
      // Her kabarcığın kendi döngü fazı: farklı hızlar ve başlangıç ofsetleri
      // ile dipten yüzeye doğru bağımsız yükseliyor
      const int bubbleCount = 26;
      for (int i = 0; i < bubbleCount; i++) {
        // Her kabarcığın birbirinden farklı yükselme hızı (yavaş)
        final speed = 0.018 + (i % 7) * 0.006; // 0.018..0.054 (çok yavaş)
        // Döngü fazı: 0..1 arası, 1'e ulaşınca dipten yeniden başlar
        final phase = ((time * speed + i * 0.13) % 1.0);
        // Hafif yatay titreme — kabarcık yükselirken sağa-sola sallanır
        final wobble = sin(time * pi * 0.4 + i * 1.7) * 3.5;
        // Yatay konum — her kabarcığın sabit bir "şeridi" var
        final laneRatio = (i % 9) / 8.0;
        final x = lerpDouble(bounds.left + 12, bounds.right - 12, laneRatio)! +
            wobble +
            sloshShift * 0.4;
        // Dikey konum: phase=0 → dip, phase=1 → yüzey
        final y = lerpDouble(bounds.bottom - 4, liquidTopBase + 8, phase)!;
        // Yüzeye yaklaşınca küçülüp solar (patlar)
        final nearSurface = (phase > 0.80) ? ((1.0 - phase) / 0.20) : 1.0;
        final r = lerpDouble(1.5, 4.5, (i % 5) / 4.0)! * nearSurface;
        final alpha = nearSurface;

        if (y < liquidTopBase - 2 || y > bounds.bottom - 1 || r < 0.3) continue;

        canvas.drawCircle(
            Offset(x, y),
            r,
            Paint()
              ..color = kLavaGlow.withValues(alpha: 0.16 * alpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
        canvas.drawCircle(Offset(x, y), r * 0.38,
            Paint()..color = kLavaCore.withValues(alpha: 0.55 * alpha));
      }
    }

    // Sol iç parlama
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
              Colors.white.withValues(alpha: 0.00)
            ],
          ).createShader(shineRect));

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
      if ((oldDelegate.layers[i].volume - layers[i].volume).abs() > 0.0001)
        return true;
    }
    return false;
  }
}
// ─────────────────────────────────────────────
// TEK ŞİŞE TAMAMLANDI — ALTIEGEN PATLAMA
// ─────────────────────────────────────────────

class _TubeDoneBurst extends StatefulWidget {
  final int colorIdx;

  /// Oyun bitişinde true — daha büyük + daha parlak efekt
  final bool isGameWin;

  const _TubeDoneBurst({
    required this.colorIdx,
    this.isGameWin = false,
  });

  @override
  State<_TubeDoneBurst> createState() => _TubeDoneBurstState();
}

class _TubeDoneBurstState extends State<_TubeDoneBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final dur = widget.isGameWin
        ? const Duration(milliseconds: 1200)
        : const Duration(milliseconds: 900);
    _ctrl = AnimationController(vsync: this, duration: dur)..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = kColors[widget.colorIdx]['fill'] as Color;
    final hexSize = widget.isGameWin ? 30.0 : 28.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;

        // ── Ana altıgen: şişeden çıkıp yukarı uçar ──────────────────────────
        final eased = Curves.easeOutCubic.transform(t);
        final dy = lerpDouble(widget.isGameWin ? 10.0 : 14.0,
            widget.isGameWin ? -80.0 : -60.0, eased)!;

        // Önce hızla belirsin, sonra yavaş yavaş kaybolsun
        final opacity = t < 0.15
            ? (t / 0.15).clamp(0.0, 1.0)
            : (1.0 - ((t - 0.15) / 0.85)).clamp(0.0, 1.0);

        // Parlaklık: t=0.25'te zirve yapar
        final glowT = (sin(t * pi)).clamp(0.0, 1.0);

        // Hafif büyüme-küçülme
        final scale = 1.0 + glowT * (widget.isGameWin ? 0.45 : 0.28);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Glow halkası
            Transform.translate(
              offset: Offset(0, dy),
              child: Opacity(
                opacity: (opacity * glowT * 0.65).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale * 1.6,
                  child: Container(
                    width: hexSize,
                    height: hexSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.55),
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Altıgen kendisi
            Transform.translate(
              offset: Offset(0, dy),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: CustomPaint(
                    size: Size(hexSize, hexSize),
                    painter: _BurstHexPainter(
                      color: color,
                      glowIntensity: glowT,
                      isGameWin: widget.isGameWin,
                    ),
                  ),
                ),
              ),
            ),
            // Oyun bitişi: ek mini parçacıklar
            if (widget.isGameWin)
              ...List.generate(6, (i) {
                final angle = (pi / 3) * i - pi / 2;
                final dist = lerpDouble(0, 36.0, eased)!;
                final px = cos(angle) * dist;
                final py = sin(angle) * dist + dy;
                final pOpacity = (opacity * (1.0 - t * 0.7)).clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(px, py),
                  child: Opacity(
                    opacity: pOpacity,
                    child: CustomPaint(
                      size: const Size(6, 6),
                      painter: _BurstHexPainter(
                        color: color,
                        glowIntensity: glowT * 0.6,
                        isGameWin: false,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _BurstHexPainter extends CustomPainter {
  final Color color;
  final double glowIntensity;
  final bool isGameWin;

  const _BurstHexPainter({
    required this.color,
    this.glowIntensity = 0.0,
    this.isGameWin = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final r = size.width / 2;
    final c = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 6; i++) {
      final a = -pi / 2 + (pi / 3) * i;
      final p = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    // Dolgu — rengin kendisi
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.95));

    // İç parlama (glowIntensity ile büyür)
    if (glowIntensity > 0.01) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35 * glowIntensity)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            isGameWin ? 4.0 * glowIntensity : 2.5 * glowIntensity,
          ),
      );
    }

    // Dış çerçeve
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25 + 0.35 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isGameWin ? 1.6 : 1.2,
    );
  }

  @override
  bool shouldRepaint(_BurstHexPainter old) =>
      old.glowIntensity != glowIntensity;
}

// ─────────────────────────────────────────────
// UÇAN TÜP

// ─────────────────────────────────────────────

class _FlyingTube extends StatefulWidget {
  final _TransferPlan plan;
  final Offset? Function(int idx) getPos;
  final Offset? Function(int idx, Offset local) getAnchor;
  final Offset? Function(int idx) getRealTargetMouth;
  final Offset? Function(int idx, double units) getRealTargetSurface;
  final Offset? Function() getMountainMouth;
  final Offset? Function(double units) getMountainSurface;
  final bool blindMode;
  final int visibleLayerCount;
  final int revealGlowTick;
  final PuzzleTubeStyle tubeStyle;
  final int capacity;
  final int targetCapacity;

  const _FlyingTube({
    super.key,
    required this.plan,
    required this.getPos,
    required this.getAnchor,
    required this.getRealTargetMouth,
    required this.getRealTargetSurface,
    required this.getMountainMouth,
    required this.getMountainSurface,
    this.blindMode = false,
    this.visibleLayerCount = kCap,
    this.revealGlowTick = 0,
    this.tubeStyle = PuzzleTubeStyle.classic,
    this.capacity = kCap,
    this.targetCapacity = kCap,
  });

  @override
  State<_FlyingTube> createState() => _FlyingTubeState();
}

class _FlyingTubeState extends State<_FlyingTube>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const double _pMoveEnd = 0.44;
  static const double _pTiltEnd = 0.58;
  static const double _pPourEnd = 0.90;
  static const double _pUprightEnd = 0.97;

  // Uçan şişeyi hedefin üstünde biraz daha yukarıda tut.
  // İstersen 28 → 36 → 44 diye deneyebilirsin.
  static const double _extraHoverLift = 112.0;

  double _liquidTilt = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: kPourDuration)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static double _easeHeavy(double t) =>
      Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));

  static double _easeOutHeavy(double t) =>
      Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

  static double _phase(double v, double start, double end) =>
      ((v - start) / (end - start)).clamp(0.0, 1.0);

  Offset _rotateAroundAnchor(Offset point, Offset anchor, double angle) {
    final dx = point.dx - anchor.dx;
    final dy = point.dy - anchor.dy;
    final c = cos(angle);
    final s = sin(angle);
    return Offset(
      anchor.dx + dx * c - dy * s,
      anchor.dy + dx * s + dy * c,
    );
  }

  Offset _tubeMouthCenterLocal() => Offset(kWidgetW / 2, kCapBotY + 1.0);

  Offset _tubeTopLeftToMatchMouth({
    required Offset targetMouth,
    required Offset mouthLocal,
    required Offset anchorLocal,
    required double angle,
  }) {
    final rotatedMouth = _rotateAroundAnchor(mouthLocal, anchorLocal, angle);
    return Offset(
      targetMouth.dx - rotatedMouth.dx,
      targetMouth.dy - rotatedMouth.dy,
    );
  }

  double _targetTiltForRemaining(double remainingUnits) => pi / 2.8;

  double _motionEnergy(double v) {
    if (v < _pMoveEnd) return 0.25;
    if (v < _pPourEnd) return 0.15;
    return (1.0 - _phase(v, _pPourEnd, 1.0)) * 0.20;
  }

  double _sloshing(double t, double intensity) {
    final x = t.clamp(0.0, 1.0);
    final wave = sin(x * 5.6);
    final damping = exp(-x * 3.4);
    return wave * intensity * damping * 0.45;
  }

  @override
  Widget build(BuildContext context) {
    final fromPos = widget.getPos(widget.plan.fromIdx);

    final targetSurface = widget.plan.isMountainTarget
        ? widget.getMountainMouth()
        : widget.getRealTargetSurface(
            widget.plan.toIdx,
            widget.plan.toSnapshot.length.toDouble(),
          );

    final targetMouthEntry = widget.plan.isMountainTarget
        ? widget.getMountainMouth()
        : widget.getRealTargetMouth(widget.plan.toIdx);

    if (fromPos == null || targetSurface == null || targetMouthEntry == null) {
      return const SizedBox.shrink();
    }

// Seçili tüp zaten sahnede -15 px yukarı kalkmış görünüyor.
// FlyingTube da aynı kalkık pozisyondan başlamalı ki
// önce aşağı inip sonra hedefe gitmeye çalışmasın.
    final liftedFromPos = fromPos.translate(0, -15.0);
    final targetLip = targetMouthEntry.translate(0, -_extraHoverLift);

    final fromMidX = liftedFromPos.dx + (kWidgetW / 2);
    final tiltSign = fromMidX <= targetLip.dx ? 1.0 : -1.0;

    final mouthLocal = _tubeMouthCenterLocal();
    final anchorLocal = Offset(kWidgetW / 2, kBodyBotY + kTR);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = _ctrl.value;

        // KRİTİK DÜZELTME:
        // boşalma artık _pUprightEnd'e kadar değil, _pPourEnd'e kadar tamamlanıyor.
        // Böylece akış bitmeden şişe dikleşmeye başlamıyor.
        final drainProgress = v <= _pTiltEnd
            ? 0.0
            : Curves.easeInOut.transform(
                ((v - _pTiltEnd) / max(0.0001, _pPourEnd - _pTiltEnd))
                    .clamp(0.0, 1.0),
              );

        final sourceDrainVolume = widget.plan.count * drainProgress;
        final sourceUnits = widget.plan.fromSnapshot.length.toDouble();
        final remainingUnits = max(0.0, sourceUnits - sourceDrainVolume)
            .clamp(0.0, kCap.toDouble());

        final dynamicMaxTilt = _targetTiltForRemaining(remainingUnits);

        final pourTopLeft = _tubeTopLeftToMatchMouth(
          targetMouth: targetLip,
          mouthLocal: mouthLocal,
          anchorLocal: anchorLocal,
          angle: tiltSign * dynamicMaxTilt,
        );

        double cx;
        if (v < _pMoveEnd) {
          cx = liftedFromPos.dx +
              (pourTopLeft.dx - liftedFromPos.dx) *
                  _easeHeavy(_phase(v, 0.0, _pMoveEnd));
        } else {
          cx = pourTopLeft.dx;
        }

        double cy;
        if (v < _pMoveEnd) {
          cy = liftedFromPos.dy +
              (pourTopLeft.dy - liftedFromPos.dy) *
                  _easeHeavy(_phase(v, 0.0, _pMoveEnd));
        } else {
          cy = pourTopLeft.dy;
        }

        double bottleAngle = 0.0;
        if (v >= _pMoveEnd && v < _pTiltEnd) {
          bottleAngle = tiltSign *
              dynamicMaxTilt *
              _easeOutHeavy(_phase(v, _pMoveEnd, _pTiltEnd));
        } else if (v >= _pTiltEnd && v < _pPourEnd) {
          // Akış sürerken sabit yatık kalsın
          bottleAngle = tiltSign * dynamicMaxTilt;
        } else if (v >= _pPourEnd && v < _pUprightEnd) {
          // Akış bittikten sonra ayağa kalksın
          bottleAngle = tiltSign *
              dynamicMaxTilt *
              (1.0 - _easeHeavy(_phase(v, _pPourEnd, _pUprightEnd)));
        }

        const inertiaFactor = 0.12;
        _liquidTilt += (bottleAngle - _liquidTilt) * inertiaFactor;

        final easedFlow =
            Curves.easeInOutSine.transform(drainProgress.clamp(0.0, 1.0));

        const vStreamStart = _pTiltEnd;
        // Akış aşamaları:
        // 1) vStreamStart → vHeadEnd : head düz hızda iner (linear)
        // 2) vHeadEnd → vTailStart   : kısa temas
        // 3) vTailStart → vTailEnd   : tail yukarıdan kesilir
        const vHeadEnd = vStreamStart + 0.10; // hızlı iniş
        const vTailStart = vHeadEnd + 0.04; // kısa temas sonrası kesim
        const vTailEnd = vTailStart + 0.06; // kesim tamamlanır

        // Anlık hedef sıvı yüzeyi: döküm ilerledikçe yukarı çıkar
        final currentToVolume =
            (widget.plan.toSnapshot.length + widget.plan.count * drainProgress)
                .clamp(0.0, widget.targetCapacity.toDouble());
        final dynamicTargetSurface = widget.plan.isMountainTarget
            ? (widget.getMountainSurface(
                  widget.plan.mountainFillBefore +
                      (widget.plan.count * drainProgress),
                ) ??
                targetSurface)
            : (widget.getRealTargetSurface(
                  widget.plan.toIdx,
                  currentToVolume,
                ) ??
                targetSurface);

        // Head: sabit hızda düz iner
        final headProgress = v <= vStreamStart
            ? 0.0
            : ((v - vStreamStart) / max(0.0001, vHeadEnd - vStreamStart))
                .clamp(0.0, 1.0);

        // Tail: head indikten sonra yukarıdan kesilir
        final tailProgress = v <= vTailStart
            ? 0.0
            : Curves.easeIn.transform(
                ((v - vTailStart) / max(0.0001, vTailEnd - vTailStart))
                    .clamp(0.0, 1.0),
              );

        final isPouring = widget.plan.count > 0 &&
            v >= vStreamStart &&
            v < vTailEnd &&
            headProgress > 0.005;

        final pivotInWidget = Offset(kWidgetW / 2, kBodyBotY + kTR);
        final rotatedMouth = _rotateAroundAnchor(
          mouthLocal,
          pivotInWidget,
          bottleAngle,
        );

        final globalStreamStart = Offset(
          cx + rotatedMouth.dx,
          cy + rotatedMouth.dy,
        );

        final motionEnergy = _motionEnergy(v);
        final sourceSlosh = _sloshing(v, 0.50) + motionEnergy * 0.10;

        final sourceBubbleBurst = isPouring
            ? lerpDouble(0.85, 1.0, easedFlow)!
            : (v >= _pPourEnd && v < _pUprightEnd
                ? lerpDouble(0.55, 0.0, _phase(v, _pPourEnd, _pUprightEnd))!
                : 0.0);

        final removedWholeLayers = widget.blindMode
            ? min(
                widget.plan.count,
                max(0, (sourceDrainVolume + 0.0001).floor()),
              )
            : 0;
        final visibleDuringPour = widget.blindMode
            ? (widget.visibleLayerCount + removedWholeLayers)
                .clamp(0, widget.plan.fromSnapshot.length)
                .toInt()
            : widget.visibleLayerCount;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (isPouring)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LiquidStreamPainter(
                      color: kColors[widget.plan.colorIdx]['fill'] as Color,
                      start: globalStreamStart,
                      end: dynamicTargetSurface,
                      mouthEntry: targetMouthEntry,
                      headProgress: headProgress,
                      tailProgress: tailProgress,
                      flowRate: easedFlow.clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: cx,
              top: cy,
              child: _TubeWidget(
                tube: widget.plan.fromSnapshot,
                isSelected: false,
                drainedVolume: sourceDrainVolume,
                tilt: bottleAngle,
                slosh: sourceSlosh,
                bubbleBurst: sourceBubbleBurst,
                blindMode: widget.blindMode,
                visibleLayerCount: visibleDuringPour,
                tubeStyle: widget.tubeStyle,
                capacity: widget.capacity,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// SIVI AKIŞI
// ─────────────────────────────────────────────

class _LiquidStreamPainter extends CustomPainter {
  final Color color;
  final Offset start; // Döküm şişesinin ağzı (dönen, global)
  final Offset end; // Hedef şişedeki sıvı yüzeyi (global)
  final Offset mouthEntry; // Hedef şişenin ağzı / giriş noktası (global)
  final double headProgress; // 0→1: akış ucunun ilerlemesi (start→end)
  final double
      tailProgress; // 0→1: akış tepesinin kesilmesi (start'tan aşağı kayar)
  final double flowRate;

  const _LiquidStreamPainter({
    required this.color,
    required this.start,
    required this.end,
    required this.mouthEntry,
    required this.headProgress,
    required this.tailProgress,
    required this.flowRate,
  });

  bool get _isLava => color == _solidColorForIndex(kLavaColorIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (headProgress <= 0.0) return;
    if ((end - start).distance < 1.0) return;

    final totalDy = end.dy - start.dy;

    final headY = start.dy + totalDy * headProgress.clamp(0.0, 1.0);
    final tailY = tailProgress <= 0.0
        ? start.dy
        : (start.dy + totalDy * tailProgress.clamp(0.0, 1.0))
            .clamp(start.dy, headY - 4.0);

    if (headY - tailY < 1.0) return;

    final thickness = lerpDouble(3.6, 7.0, flowRate)!;
    final path = Path()
      ..moveTo(start.dx, tailY)
      ..lineTo(start.dx, headY);

    if (_isLava) {
      final lavaRect = Rect.fromLTRB(
        start.dx - thickness * 1.6,
        tailY,
        start.dx + thickness * 1.6,
        headY,
      );

      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kLavaCore, kLavaGlow, kLavaOrange, kLavaRed, kLavaDark],
            stops: [0.0, 0.14, 0.42, 0.78, 1.0],
          ).createShader(lavaRect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness + 4.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
      );

      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kLavaGlow, kLavaOrange, kLavaRed, kLavaDark],
            stops: [0.0, 0.20, 0.62, 1.0],
          ).createShader(lavaRect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round,
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, thickness * 0.22)
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      return;
    }

    final paint = Paint()
      ..color = color.withValues(alpha: 0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LiquidStreamPainter old) =>
      old.start != start ||
      old.end != end ||
      old.mouthEntry != mouthEntry ||
      old.headProgress != headProgress ||
      old.tailProgress != tailProgress ||
      old.flowRate != flowRate ||
      old.color != color;
}

// ─────────────────────────────────────────────
// TÜP WIDGET
// ─────────────────────────────────────────────

class _AdUnlockBadge extends StatelessWidget {
  final Color color;

  const _AdUnlockBadge({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF2A1600).withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFFC107).withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withValues(alpha: 0.28),
            blurRadius: 6,
            spreadRadius: 0.4,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          size: 13,
          color: color,
        ),
      ),
    );
  }
}

class _TubeWidget extends StatefulWidget {
  final List<int> tube;
  final bool isSelected;
  final double tilt;
  final double slosh;
  final double drainedVolume;
  final int? incomingColorIdx;
  final double incomingVolume;
  final double splash;
  final double pourProgress;
  final double bubbleBurst;
  final double receiveFlow;
  final bool blindMode;
  final int visibleLayerCount;
  final int revealGlowTick;
  final PuzzleTubeStyle tubeStyle;
  final int capacity;

  const _TubeWidget({
    required this.tube,
    required this.isSelected,
    this.tilt = 0.0,
    this.slosh = 0.0,
    this.drainedVolume = 0.0,
    this.incomingColorIdx,
    this.incomingVolume = 0.0,
    this.splash = 0.0,
    this.pourProgress = 0.0,
    this.bubbleBurst = 0.0,
    this.receiveFlow = 0.0,
    this.blindMode = false,
    this.visibleLayerCount = kCap,
    this.revealGlowTick = 0,
    this.tubeStyle = PuzzleTubeStyle.classic,
    this.capacity = kCap,
  });

  @override
  State<_TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<_TubeWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _lavaCtrl;

  bool _hasLava() {
    if (widget.tubeStyle == PuzzleTubeStyle.largeCollector) return true;
    if (_isLavaColorIndex(widget.incomingColorIdx ?? -1)) return true;
    for (final c in widget.tube) {
      if (_isLavaColorIndex(c)) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (_hasLava()) {
      _lavaCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(_TubeWidget old) {
    super.didUpdateWidget(old);
    final nowHasLava = _hasLava();
    if (nowHasLava && _lavaCtrl == null) {
      _lavaCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    } else if (!nowHasLava && _lavaCtrl != null) {
      _lavaCtrl!.dispose();
      _lavaCtrl = null;
    }
  }

  @override
  void dispose() {
    _lavaCtrl?.dispose();
    super.dispose();
  }

  Alignment _pivotAlignment() {
    const pivotX = kTW / 2;
    final pivotY = kBodyBotY + kTR;
    return Alignment(
      (pivotX / (kTW / 2)) - 1,
      (pivotY / (kWidgetH / 2)) - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tubeStyle == PuzzleTubeStyle.largeCollector) {
      // largeCollector da lavaCtrl ile çalışır — her zaman lava var
      final lavaTime = _lavaCtrl?.value ?? 0.0;
      Widget basinWidget(double t) => SizedBox(
            width: kBasinW,
            height: kBasinH,
            child: CustomPaint(
              painter: _VolcanicBasinPainter(
                currentUnits: widget.tube.length + widget.incomingVolume,
                capacity: widget.capacity,
                highlight: widget.isSelected,
                lavaTime: t,
              ),
            ),
          );
      if (_lavaCtrl != null) {
        return AnimatedBuilder(
          animation: _lavaCtrl!,
          builder: (_, __) => basinWidget(_lavaCtrl!.value),
        );
      }
      return basinWidget(0.0);
    }

    Widget buildFrame(double lavaTime) {
      return RepaintBoundary(
        child: SizedBox(
          width: kWidgetW,
          height: kWidgetH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(kWidgetW, kWidgetH),
                painter: _LiquidPainter(
                  tube: widget.tube,
                  tilt: widget.tilt,
                  slosh: widget.slosh,
                  drainedVolume: widget.drainedVolume,
                  incomingColorIdx: widget.incomingColorIdx,
                  incomingVolume: widget.incomingVolume,
                  splash: widget.splash,
                  pourProgress: widget.pourProgress,
                  bubbleBurst: widget.bubbleBurst,
                  receiveFlow: widget.receiveFlow,
                  blindMode: widget.blindMode,
                  visibleLayerCount: widget.visibleLayerCount,
                  revealGlowTick: widget.revealGlowTick,
                  capacity: widget.capacity,
                  lavaTime: lavaTime,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: SvgPicture.asset(
                    kTubeSvgAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget frame;
    if (_lavaCtrl != null) {
      frame = AnimatedBuilder(
        animation: _lavaCtrl!,
        builder: (_, __) => buildFrame(_lavaCtrl!.value),
      );
    } else {
      frame = buildFrame(0.0);
    }

    final liftY = widget.isSelected ? -15.0 : 0.0;

    if (widget.tilt.abs() < 0.0001) {
      return SizedBox(
        width: kWidgetW,
        height: kWidgetH,
        child: Transform.translate(
          offset: Offset(0, liftY),
          child: frame,
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: kWidgetW,
        height: kWidgetH,
        child: Transform.translate(
          offset: Offset(0, liftY),
          child: Transform.rotate(
            angle: widget.tilt,
            alignment: _pivotAlignment(),
            transformHitTests: false,
            child: frame,
          ),
        ),
      ),
    );
  }
}

class _VolcanicBasinPainter extends CustomPainter {
  final double currentUnits;
  final int capacity;
  final bool highlight;
  final double lavaTime; // 0→1 döngüsel

  const _VolcanicBasinPainter({
    required this.currentUnits,
    required this.capacity,
    this.highlight = false,
    this.lavaTime = 0.0,
  });

  Path _outerPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.08, h * 0.24)
      ..quadraticBezierTo(w * 0.16, h * 0.10, w * 0.28, h * 0.24)
      ..lineTo(w * 0.28, h * 0.62)
      ..quadraticBezierTo(w * 0.50, h * 0.92, w * 0.72, h * 0.62)
      ..lineTo(w * 0.72, h * 0.24)
      ..quadraticBezierTo(w * 0.84, h * 0.10, w * 0.92, h * 0.24)
      ..lineTo(w * 0.92, h * 0.88)
      ..lineTo(w * 0.08, h * 0.88)
      ..close();
  }

  Path _innerPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.18, h * 0.30)
      ..quadraticBezierTo(w * 0.27, h * 0.20, w * 0.35, h * 0.32)
      ..lineTo(w * 0.35, h * 0.62)
      ..quadraticBezierTo(w * 0.50, h * 0.76, w * 0.65, h * 0.62)
      ..lineTo(w * 0.65, h * 0.32)
      ..quadraticBezierTo(w * 0.73, h * 0.20, w * 0.82, h * 0.30)
      ..lineTo(w * 0.82, h * 0.80)
      ..lineTo(w * 0.18, h * 0.80)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outer = _outerPath(size);
    final inner = _innerPath(size);

    // ── Kaya gövdesi ──────────────────────────────────────────────────────────
    canvas.drawShadow(outer, Colors.black.withValues(alpha: 0.45), 14, false);

    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A130B), Color(0xFF130605)],
        ).createShader(Offset.zero & size),
    );

    // Kaya kenar çizgisi
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = const Color(0xFF6A3A22).withValues(alpha: 0.95),
    );

    // Seçili parlama / highlight
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlight ? 5.5 : 3.2
        ..color =
            const Color(0xFFFF8A33).withValues(alpha: highlight ? 0.55 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── İç lav alanı ─────────────────────────────────────────────────────────
    canvas.save();
    canvas.clipPath(inner);

    final fillRatio =
        capacity <= 0 ? 0.0 : (currentUnits / capacity).clamp(0.0, 1.0);
    // Boş bile olsa iç alan tamamen kırmızı-siyah kor görünsün
    final baseTop = h * 0.30;
    final baseBot = h * 0.80;
    final baseRect =
        Rect.fromLTWH(w * 0.16, baseTop, w * 0.68, baseBot - baseTop);

    // Arka plan kor — her zaman çizilir
    canvas.drawRect(
      baseRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0A00), Color(0xFF1A0300)],
        ).createShader(baseRect),
    );

    // Dolu lav katmanı
    final fillTop = lerpDouble(baseBot, baseTop, fillRatio)!;
    final fillRect =
        Rect.fromLTWH(w * 0.16, fillTop, w * 0.68, baseBot - fillTop);

    if (fillRatio > 0.001) {
      // Ana lav rengi: kırmızı-turuncu, normal tüplerle aynı palet
      canvas.drawRect(
        fillRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0xFFFF3D00),
              Color(0xFFDD1500),
              Color(0xFF8B0000),
            ],
            stops: const [0.0, 0.50, 1.0],
          ).createShader(fillRect),
      );

      // ── Animasyonlu kor damarları ───────────────────────────────────────
      for (int v = 0; v < 4; v++) {
        final vPhase = ((v / 4.0) + lavaTime * 0.35) % 1.0;
        final vX = fillRect.left + fillRect.width * (0.12 + v * 0.24);
        final vTopY = fillRect.bottom - vPhase * fillRect.height * 1.1 - 4;
        final vBotY = vTopY + fillRect.height * 0.32;
        final vPath = Path()
          ..moveTo(vX, max(fillRect.top, vTopY))
          ..cubicTo(
            vX - fillRect.width * 0.05,
            max(fillRect.top, vTopY) + fillRect.height * 0.10,
            vX + fillRect.width * 0.05,
            max(fillRect.top, vTopY) + fillRect.height * 0.20,
            vX - fillRect.width * 0.03,
            min(fillRect.bottom, vBotY),
          );
        canvas.drawPath(
          vPath,
          Paint()
            ..color = const Color(0xFFFF6D00).withValues(alpha: 0.60)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      }

      // ── Sıcak nokta parlamaları ─────────────────────────────────────────
      for (int h2 = 0; h2 < 3; h2++) {
        final hPhase = ((h2 / 3.0) + lavaTime * 0.65) % 1.0;
        final hPulse = sin(hPhase * pi * 2) * 0.5 + 0.5;
        final hX = fillRect.left + fillRect.width * (0.20 + h2 * 0.30);
        final hY = fillRect.top + fillRect.height * (0.20 + h2 * 0.25);
        if (hY > fillRect.bottom) continue;
        final hR = (8.0 + 6.0 * hPulse);
        final hotRect =
            Rect.fromCircle(center: Offset(hX, hY), radius: hR * 2.5);
        canvas.drawCircle(
          Offset(hX, hY),
          hR * 2.5,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFD54F).withValues(alpha: 0.60 * hPulse),
                const Color(0xFFFF6F00).withValues(alpha: 0.35 * hPulse),
                Colors.transparent,
              ],
            ).createShader(hotRect),
        );
      }

      // ── Yüzen kabarcıklar ───────────────────────────────────────────────
      final bubbles = [
        (0.22, 3.5, 0.00),
        (0.50, 5.0, 0.20),
        (0.72, 4.0, 0.40),
        (0.35, 3.0, 0.60),
        (0.60, 6.0, 0.75),
        (0.15, 4.5, 0.10),
        (0.82, 3.8, 0.85),
        (0.45, 5.5, 0.50),
      ];
      for (final (bxFrac, br, offset) in bubbles) {
        final tPhase = ((lavaTime + offset) % 1.0);
        final bY = fillRect.bottom - tPhase * fillRect.height;
        if (bY < fillRect.top) continue;

        final bX = fillRect.left + fillRect.width * bxFrac;
        final bOp = tPhase < 0.12
            ? tPhase / 0.12
            : tPhase > 0.82
                ? (1.0 - tPhase) / 0.18
                : 1.0;

        canvas.drawCircle(
          Offset(bX, bY),
          br * 1.9,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.16 * bOp)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
        canvas.drawCircle(
          Offset(bX, bY),
          br,
          Paint()
            ..color = const Color(0xFFFF8C00).withValues(alpha: 0.72 * bOp),
        );
        canvas.drawCircle(
          Offset(bX - br * 0.28, bY - br * 0.28),
          br * 0.32,
          Paint()..color = Colors.white.withValues(alpha: 0.65 * bOp),
        );
        canvas.drawCircle(
          Offset(bX, bY),
          br,
          Paint()
            ..color = const Color(0xFFFFD54F).withValues(alpha: 0.45 * bOp)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
      }

      // ── Yüzey patlama noktaları ─────────────────────────────────────────
      for (int p = 0; p < 3; p++) {
        final pPhase = ((lavaTime * 1.2 + p * 0.33) % 1.0);
        if (pPhase > 0.22) continue;
        final pT = pPhase / 0.22;
        final pPulse = sin(pT * pi);
        final pX = fillRect.left + fillRect.width * (0.20 + p * 0.30);
        final pY = fillTop + 2.0;
        final pR = 3.0 + 6.0 * pPulse;
        canvas.drawCircle(
          Offset(pX, pY),
          pR * 2.2,
          Paint()
            ..color = const Color(0xFFFF6D00).withValues(alpha: 0.45 * pPulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
        );
        canvas.drawCircle(
          Offset(pX, pY),
          pR * 0.55,
          Paint()
            ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.85 * pPulse),
        );
      }

      // ── Dalgalı yüzey çizgisi ───────────────────────────────────────────
      final waveAmp = fillRect.width * 0.020;
      final ripple = sin(lavaTime * pi * 2.0) * waveAmp;
      final surface = Path()
        ..moveTo(
            fillRect.left + fillRect.width * 0.04, fillTop + waveAmp + ripple)
        ..cubicTo(
          fillRect.left + fillRect.width * 0.28,
          fillTop + waveAmp * 0.4 + ripple,
          fillRect.left + fillRect.width * 0.50,
          fillTop - waveAmp * 0.4 - ripple,
          fillRect.left + fillRect.width * 0.72,
          fillTop - waveAmp - ripple,
        )
        ..cubicTo(
          fillRect.left + fillRect.width * 0.82,
          fillTop - waveAmp * 0.3 + ripple * 0.5,
          fillRect.left + fillRect.width * 0.90,
          fillTop + waveAmp * 0.2,
          fillRect.right - fillRect.width * 0.04,
          fillTop + waveAmp * 0.5,
        );
      canvas.drawPath(
        surface,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = kLavaCore.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );

      // Sol iç parlaklık şeridi
      final shineRect = Rect.fromLTWH(
          fillRect.left, fillTop, fillRect.width * 0.10, fillRect.height);
      canvas.drawRect(
        shineRect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.0),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(shineRect),
      );
    }

    // ── Sürekli alev efekti — lav yüzeyinden yukarı ─────────────────────────
    // fillRatio ne olursa olsun alev her zaman yanıyor
    {
      final flameBaseY = fillRatio > 0.001 ? fillTop : baseBot;
      final cx = w / 2;
      final innerTopY = baseTop;
      final flameH = ((flameBaseY - innerTopY) * 0.55).clamp(14.0, 52.0);

      // Ana alev — merkez
      final mainFlame = Path()
        ..moveTo(cx - w * 0.12, flameBaseY)
        ..cubicTo(
          cx - w * 0.18,
          flameBaseY - flameH * 0.40,
          cx - w * 0.08,
          flameBaseY - flameH * 0.80,
          cx,
          flameBaseY - flameH,
        )
        ..cubicTo(
          cx + w * 0.08,
          flameBaseY - flameH * 0.80,
          cx + w * 0.18,
          flameBaseY - flameH * 0.40,
          cx + w * 0.12,
          flameBaseY,
        )
        ..close();

      final flameRect = Rect.fromLTWH(
          cx - w * 0.20, flameBaseY - flameH * 1.1, w * 0.40, flameH * 1.2);

      canvas.drawPath(
        mainFlame,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xDDFF3D00),
              const Color(0xAAFF8C00),
              const Color(0x66FFD54F),
              const Color(0x22FFF9C4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.30, 0.60, 0.82, 1.0],
          ).createShader(flameRect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      );

      // Titreyen yan alevler
      for (int f = 0; f < 4; f++) {
        final fSign = (f % 2 == 0) ? -1.0 : 1.0;
        final fXFrac = 0.10 + (f ~/ 2) * 0.22;
        final fPhase = ((lavaTime * 1.4 + f * 0.25) % 1.0);
        final fPulse = sin(fPhase * pi * 2) * 0.5 + 0.5;
        final fH = flameH * (0.35 + 0.30 * fPulse);
        final fX = cx + fSign * w * fXFrac;

        final sideFlame = Path()
          ..moveTo(fX - w * 0.055, flameBaseY)
          ..cubicTo(
            fX - w * 0.09,
            flameBaseY - fH * 0.45,
            fX + w * 0.02,
            flameBaseY - fH * 0.82,
            fX + w * 0.04,
            flameBaseY - fH,
          )
          ..cubicTo(
            fX + w * 0.08,
            flameBaseY - fH * 0.70,
            fX + w * 0.07,
            flameBaseY - fH * 0.28,
            fX + w * 0.055,
            flameBaseY,
          )
          ..close();

        final sfRect = Rect.fromLTWH(
            fX - w * 0.10, flameBaseY - fH * 1.1, w * 0.20, fH * 1.2);
        canvas.drawPath(
          sideFlame,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xBBFF3D00).withValues(alpha: 0.70 * fPulse),
                const Color(0x88FF8C00).withValues(alpha: 0.45 * fPulse),
                Colors.transparent,
              ],
            ).createShader(sfRect)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
      }

      // Kor hattı — yüzey çizgisi parlaması
      canvas.drawLine(
        Offset(cx - w * 0.22, flameBaseY),
        Offset(cx + w * 0.22, flameBaseY),
        Paint()
          ..color = kLavaCore.withValues(alpha: 0.65)
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
    }

    canvas.restore();

    // ── Ağız kenar çizgisi ────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(w * 0.20, h * 0.30),
      Offset(w * 0.80, h * 0.30),
      Paint()
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1E0D08),
    );

    // Ağız parlama — lavdan gelen turuncu ışık
    canvas.drawLine(
      Offset(w * 0.20, h * 0.30),
      Offset(w * 0.80, h * 0.30),
      Paint()
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _VolcanicBasinPainter oldDelegate) {
    return oldDelegate.currentUnits != currentUnits ||
        oldDelegate.capacity != capacity ||
        oldDelegate.highlight != highlight ||
        oldDelegate.lavaTime != lavaTime;
  }
}

// ─────────────────────────────────────────────
// SIVI PAINTER  –  Tüp içi renkli katmanlar
// ─────────────────────────────────────────────

class _LiquidPainter extends CustomPainter {
  final List<int> tube;
  final double tilt;
  final double slosh;
  final double drainedVolume;
  final int? incomingColorIdx;
  final double incomingVolume;
  final double splash;
  final double pourProgress;
  final double bubbleBurst;
  final double receiveFlow;
  final bool blindMode;
  final int visibleLayerCount;
  final int revealGlowTick;
  final int capacity;
  final double lavaTime; // 0→1 döngüsel, AnimationController'dan

  const _LiquidPainter({
    required this.tube,
    required this.tilt,
    required this.slosh,
    required this.drainedVolume,
    required this.incomingColorIdx,
    required this.incomingVolume,
    required this.splash,
    required this.pourProgress,
    required this.bubbleBurst,
    required this.receiveFlow,
    required this.revealGlowTick,
    this.blindMode = false,
    this.visibleLayerCount = kCap,
    this.capacity = kCap,
    this.lavaTime = 0.0,
  });

  // İç alan sınırları
  double get _il => kLiquidLeft;
  double get _ir => kLiquidRight;
  double get _iw => kLiquidW;
  double get _it => kLiquidTopY;
  double get _ib => kLiquidBotY;

  // Clip path: iç gövde + alt TAM yarım daire (sıvı buraya dolacak)
  Path _clipPath() {
    final r = _iw / 2;
    final centerY = _ib - r;
    return Path()
      ..moveTo(_il, _it)
      ..lineTo(_il, centerY)
      ..arcTo(
        Rect.fromCircle(
          center: Offset((_il + _ir) / 2, centerY),
          radius: r,
        ),
        pi,
        -pi,
        false,
      )
      ..lineTo(_ir, _it)
      ..close();
  }

  double _volumeForY(double y) {
    final r = _iw / 2;
    final bowlTop = _ib - r; // daire merkezi
    if (y >= _ib) return 0.0;
    if (y <= _it) return capacity.toDouble();

    double area;
    if (y >= bowlTop) {
      final dy = bowlTop - y;
      final ratio = (dy / r).clamp(-1.0, 1.0);
      final cap = r * r * acos(ratio) - dy * sqrt(max(0.0, r * r - dy * dy));
      area = pi * r * r / 2.0 - cap;
    } else {
      area = _iw * (bowlTop - y) + pi * r * r / 2.0;
    }
    final total = _iw * (bowlTop - _it) + pi * r * r / 2.0;
    return (area / total * capacity).clamp(0.0, capacity.toDouble());
  }

  double _yForVolume(double vol) {
    if (vol <= 0) return _ib;
    if (vol >= capacity) return _it;
    double lo = _it, hi = _ib;
    for (int i = 0; i < 48; i++) {
      final mid = (lo + hi) / 2;
      if (_volumeForY(mid) < vol)
        hi = mid;
      else
        lo = mid;
    }
    return (lo + hi) / 2;
  }

  double _slope(double tilt, double slosh) {
    final raw = tan(tilt) * (_iw / 2) + slosh * 4.0;
    return raw.clamp(-(_ib - _it) * 0.42, (_ib - _it) * 0.42);
  }

  ({double lY, double cY, double rY}) _surface(
      double vol, double tilt, double slosh) {
    final mid = _yForVolume(vol);
    final sl = _slope(tilt, slosh);
    final lY = (mid + sl).clamp(_it, _ib);
    final rY = (mid - sl).clamp(_it, _ib);
    return (lY: lY, cY: (lY + rY) / 2, rY: rY);
  }

  Path _band(double vBot, double vTop, double tilt, double slosh) {
    if (vTop <= vBot + 0.001) return Path();

    final top = _surface(vTop, tilt, slosh);

    // En alttaki katman: alt kapanışı düz eğriyle değil,
    // tüpün yuvarlak dibiyle yap.
    if (vBot <= 0.001) {
      final r = _iw / 2;
      final centerY = _ib - r;

      return Path()
        ..moveTo(_il, top.lY)
        ..quadraticBezierTo(_il + _iw / 2, top.cY, _ir, top.rY)
        ..lineTo(_ir, centerY)
        ..arcTo(
          Rect.fromCircle(
            center: Offset((_il + _ir) / 2, centerY),
            radius: r,
          ),
          0,
          pi,
          false,
        )
        ..close();
    }

    final bot = _surface(vBot, tilt, slosh * 0.35);
    return Path()
      ..moveTo(_il, top.lY)
      ..quadraticBezierTo(_il + _iw / 2, top.cY, _ir, top.rY)
      ..lineTo(_ir, bot.rY)
      ..quadraticBezierTo(_il + _iw / 2, bot.cY, _il, bot.lY)
      ..close();
  }

  Path _surfaceLine(double vol, double tilt, double slosh) {
    final s = _surface(vol, tilt, slosh);
    return Path()
      ..moveTo(_il, s.lY)
      ..quadraticBezierTo(_il + _iw / 2, s.cY, _ir, s.rY);
  }

  // blindMode=false → normal (ardışık aynı renk birleşir)
  // blindMode=true  → her eleman ayrı katman (alt katmanlar gizlensin diye)
  List<_VisualLayer> _buildLayers() {
    final layers = <_VisualLayer>[];

    if (blindMode) {
      // Blind modda her elemanı ayrı tut — birleştirme
      for (final c in tube) {
        layers.add(_VisualLayer(colorIdx: c, volume: 1));
      }
    } else {
      for (final c in tube) {
        if (layers.isNotEmpty && layers.last.colorIdx == c) {
          final l = layers.removeLast();
          layers.add(l.copyWith(volume: l.volume + 1));
        } else {
          layers.add(_VisualLayer(colorIdx: c, volume: 1));
        }
      }
    }

    double drainLeft = drainedVolume.clamp(0.0, capacity.toDouble());
    while (drainLeft > 0.0001 && layers.isNotEmpty) {
      final l = layers.removeLast();
      if (l.volume > drainLeft) {
        layers.add(l.copyWith(volume: l.volume - drainLeft));
        drainLeft = 0;
      } else {
        drainLeft -= l.volume;
      }
    }

    if (incomingColorIdx != null && incomingVolume > 0.0001) {
      final cur = layers.fold<double>(0, (s, e) => s + e.volume);
      final add = min(incomingVolume, capacity - cur);
      if (add > 0.0001) {
        if (blindMode) {
          double left = add;
          while (left > 0.0001) {
            final piece = min(1.0, left);
            layers
                .add(_VisualLayer(colorIdx: incomingColorIdx!, volume: piece));
            left -= piece;
          }
        } else if (layers.isNotEmpty &&
            layers.last.colorIdx == incomingColorIdx) {
          final l = layers.removeLast();
          layers.add(l.copyWith(volume: l.volume + add));
        } else {
          layers.add(_VisualLayer(colorIdx: incomingColorIdx!, volume: add));
        }
      }
    }

    return layers.where((e) => e.volume > 0.0001).toList(growable: false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final clip = _clipPath();
    canvas.save();
    canvas.clipPath(clip);

    final layers = _buildLayers();
    final totalVol = layers.fold<double>(0, (s, e) => s + e.volume);
    final flowBias = Curves.easeInOut.transform(
      (pourProgress.clamp(0.0, 1.0) * (tilt.abs() / 1.02)).clamp(0.0, 1.0),
    );
    final liquidRect = Rect.fromLTWH(_il, _it, _iw, _ib - _it);

    double accum = 0;
    for (int i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final vBot = accum;
      final vTop = accum + layer.volume;
      final safeIdx = layer.colorIdx.clamp(0, kColors.length - 1).toInt();
      final isTop = i == layers.length - 1;
      final blindBaseLayerCount = blindMode ? tube.length : layers.length;
      final safeVisibleCount =
          visibleLayerCount.clamp(0, blindBaseLayerCount).toInt();
      final hiddenBelow =
          blindMode ? max(0, blindBaseLayerCount - safeVisibleCount) : 0;
      final currentHiddenBelow = min(hiddenBelow, max(0, layers.length - 1));
      final isHidden = blindMode && i < currentHiddenBelow;

      final fill =
          isHidden ? const Color(0xFF2A2535) : _solidColorForIndex(safeIdx);
      final isLavaLayer = !isHidden && _isLavaColorIndex(safeIdx);

      final bandPath = _band(vBot, vTop, tilt, isTop ? slosh : slosh * 0.45);
      if (isLavaLayer) {
        // ── Lav bandı: her katmanda aynı görünüm için kendi rect'i kullan ──
        final topS = _surface(vTop, tilt, isTop ? slosh : slosh * 0.45);
        final botS = _surface(vBot, tilt, slosh * 0.20);
        final bandTopY = min(topS.lY, topS.rY);
        final bandBotY = max(botS.lY, botS.rY);
        final bandRect = Rect.fromLTRB(_il, bandTopY, _ir, bandBotY + 2);

        // Ana lav dolgusu — koyu kırmızıdan parlak kırmızıya, her bantta aynı
        canvas.drawPath(
          bandPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0xFFFF3D00), // üst: canlı kırmızı-turuncu
                Color(0xFFDD1500), // orta: koyu kırmızı
                Color(0xFF8B0000), // alt: derin kızıl
              ],
              stops: const [0.0, 0.50, 1.0],
            ).createShader(bandRect),
        );

        // Damar/parlama dalgası — lavaTime ile kayar
        canvas.save();
        canvas.clipPath(bandPath);

        // Yavaş akan kor damarları
        for (int v = 0; v < 3; v++) {
          final vPhase = (v / 3.0 + lavaTime * 0.4) % 1.0;
          final vX = _il + _iw * (0.18 + v * 0.28);
          final vTopY = bandRect.top + bandRect.height * vPhase - 4;
          final vBotY = vTopY + bandRect.height * 0.35;
          final vPath = Path()
            ..moveTo(vX, vTopY)
            ..cubicTo(
              vX - _iw * 0.06,
              vTopY + bandRect.height * 0.12,
              vX + _iw * 0.06,
              vTopY + bandRect.height * 0.22,
              vX - _iw * 0.04,
              vBotY,
            );
          canvas.drawPath(
            vPath,
            Paint()
              ..color = const Color(0xFFFF6D00).withValues(alpha: 0.55)
              ..strokeWidth = 1.6
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
          );
        }

        // Sıcak nokta parlamaları
        for (int h = 0; h < 2; h++) {
          final hPhase = ((h * 0.5 + lavaTime * 0.7) % 1.0);
          final hPulse = (sin(hPhase * pi * 2) * 0.5 + 0.5);
          final hX = _il + _iw * (0.28 + h * 0.44);
          final hY = bandRect.top + bandRect.height * (0.25 + h * 0.35);
          final hR = 4.0 + 3.0 * hPulse;
          final hotRect =
              Rect.fromCircle(center: Offset(hX, hY), radius: hR * 2.5);
          canvas.drawCircle(
            Offset(hX, hY),
            hR * 2.5,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  const Color(0xFFFFD54F).withValues(alpha: 0.55 * hPulse),
                  const Color(0xFFFF6F00).withValues(alpha: 0.30 * hPulse),
                  Colors.transparent,
                ],
              ).createShader(hotRect),
          );
        }

        // Kabarcıklar — lavaTime ile yukarı tırmanır
        final bubbleRng = [
          (0.22, 0.78, 2.2, 0.0),
          (0.58, 0.42, 1.6, 0.33),
          (0.40, 0.65, 2.8, 0.67),
          (0.72, 0.20, 1.8, 0.15),
          (0.15, 0.50, 2.4, 0.50),
        ];

        for (final (bx, _, br, offset) in bubbleRng) {
          final tPhase = ((lavaTime + offset) % 1.0);
          // Kabarcık bandın tabanından yüzeyine çıkar
          final bY = bandRect.bottom - tPhase * bandRect.height;
          if (bY < bandRect.top || bY > bandRect.bottom) continue;

          final bX = _il + _iw * bx;
          final bOpacity = tPhase < 0.15
              ? tPhase / 0.15
              : tPhase > 0.80
                  ? (1.0 - tPhase) / 0.20
                  : 1.0;

          // Kabarcık gölgesi
          canvas.drawCircle(
            Offset(bX, bY),
            br * 1.8,
            Paint()
              ..color = Colors.black.withValues(alpha: 0.18 * bOpacity)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
          );
          // Kabarcık gövdesi
          canvas.drawCircle(
            Offset(bX, bY),
            br,
            Paint()
              ..color =
                  const Color(0xFFFF8C00).withValues(alpha: 0.70 * bOpacity)
              ..style = PaintingStyle.fill,
          );
          // Kabarcık iç parlaması
          canvas.drawCircle(
            Offset(bX - br * 0.28, bY - br * 0.28),
            br * 0.32,
            Paint()..color = Colors.white.withValues(alpha: 0.60 * bOpacity),
          );
          // Kabarcık dış çerçevesi
          canvas.drawCircle(
            Offset(bX, bY),
            br,
            Paint()
              ..color =
                  const Color(0xFFFFD54F).withValues(alpha: 0.50 * bOpacity)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.6,
          );
        }

        // Patlama noktaları — en üst katmanda yüzeyde patlamalar
        if (isTop) {
          for (int p = 0; p < 2; p++) {
            final pOffset = p * 0.5;
            final pPhase = ((lavaTime * 1.4 + pOffset) % 1.0);
            // Patlama kısa süre içinde gerçekleşir
            if (pPhase > 0.25) continue;
            final pT = pPhase / 0.25;
            final pPulse = sin(pT * pi);
            final pX = _il + _iw * (0.30 + p * 0.40);
            final pY = topS.cY - 1.0;
            final pR = 2.5 + 4.0 * pPulse;
            canvas.drawCircle(
              Offset(pX, pY),
              pR * 2.0,
              Paint()
                ..color =
                    const Color(0xFFFF6D00).withValues(alpha: 0.40 * pPulse)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
            );
            canvas.drawCircle(
              Offset(pX, pY),
              pR * 0.55,
              Paint()
                ..color =
                    const Color(0xFFFFF9C4).withValues(alpha: 0.80 * pPulse),
            );
          }
        }

        canvas.restore();

        // Sol iç parlaklık şeridi (tüpün sol duvarı boyunca)
        final shineW = _iw * 0.14;
        final shineRect =
            Rect.fromLTWH(_il, bandRect.top, shineW, bandRect.height);
        canvas.drawRect(
          shineRect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(shineRect),
        );
      } else {
        canvas.drawPath(bandPath, Paint()..color = fill);

        // Işık gradyanı
        canvas.drawPath(
          bandPath,
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.05),
              ],
              stops: const [0.0, 0.35, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(liquidRect),
        );
      }

      final revealLayerIndex = blindMode && safeVisibleCount > 0
          ? max(
              0,
              layers.length -
                  (safeVisibleCount -
                      max(0, blindBaseLayerCount - layers.length)))
          : -1;
      final isRevealLayer = blindMode && !isHidden && i == revealLayerIndex;

      if (isRevealLayer && revealGlowTick > 0) {
        final revealPulse = 1.0;
        canvas.drawPath(
          bandPath,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18 * revealPulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
        );
        canvas.drawPath(
          bandPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = Colors.white.withValues(alpha: 0.24 * revealPulse),
        );
      }

      // blindMode: gri katmanlar arası ince ayırıcı çizgi + ortasına '?'
      if (isHidden) {
        // Katmanlar arası ince çizgi (üst kenar)
        if (i < layers.length - 2) {
          // üstteki katmanın alt yüzeyi = bu katmanın üst yüzeyi
          final divSurface = _surface(vTop, tilt, slosh * 0.2);
          canvas.drawPath(
            Path()
              ..moveTo(_il, divSurface.lY)
              ..quadraticBezierTo(
                  _il + _iw / 2, divSurface.cY, _ir, divSurface.rY),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.18)
              ..strokeWidth = 0.8
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round,
          );
        }

        // Katmanın ortasına '?' çiz
        final midVol = (vBot + vTop) / 2;
        final midSurface = _surface(midVol, 0, 0);
        final midY = midSurface.cY;
        final midX = (_il + _ir) / 2;

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

      accum = vTop;
    }

    // Üst yüzey parlaması
    if (totalVol > 0.0001) {
      final topColorIdx = layers.isNotEmpty ? layers.last.colorIdx : -1;
      final topIsLava = _isLavaColorIndex(topColorIdx);
      canvas.drawPath(
        _surfaceLine(totalVol, tilt, slosh),
        Paint()
          ..color = (topIsLava ? kLavaCore : Colors.white)
              .withValues(alpha: topIsLava ? 0.34 : 0.18)
          ..strokeWidth = topIsLava ? 1.4 : 1.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter =
              topIsLava ? const MaskFilter.blur(BlurStyle.normal, 1.2) : null,
      );

      // Sıçrama efekti
      if (splash > 0.02) {
        final s = _surface(totalVol, tilt, 0);
        final tipX = tilt < 0 ? _ir : _il;
        final tipY = lerpDouble(tilt < 0 ? s.rY : s.lY, _it + 1.2, flowBias)!;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(tipX, tipY - 0.4),
            width: lerpDouble(3.0, 6.0, splash)!,
            height: lerpDouble(0.8, 1.5, splash)!,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.08 * splash),
        );
      }
    }

    // 🫧 Kabarcık efekti (görünür güçlendirilmiş sürüm)
    if (totalVol > 0.0001 && bubbleBurst > 0.01) {
      final s = _surface(totalVol, tilt, slosh * 0.25);
      final topColorIdx = layers.isNotEmpty ? layers.last.colorIdx : -1;
      final burstIsLava = _isLavaColorIndex(topColorIdx) ||
          (incomingColorIdx != null && _isLavaColorIndex(incomingColorIdx!));

      final bubbleBaseColor =
          burstIsLava ? const Color(0xFFFF8C00) : Colors.white;
      final bubbleHighColor =
          burstIsLava ? const Color(0xFFFFF9C4) : Colors.white;

      final bubbleFill = Paint()
        ..color = bubbleBaseColor.withValues(
            alpha: (burstIsLava ? 0.70 : 0.55) * bubbleBurst)
        ..style = PaintingStyle.fill;

      final bubbleStroke = Paint()
        ..color = bubbleHighColor.withValues(alpha: 0.95 * bubbleBurst)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final highlightPaint = Paint()
        ..color = bubbleHighColor.withValues(alpha: 0.95 * bubbleBurst)
        ..style = PaintingStyle.fill;

      final driftUp = lerpDouble(0.0, 7.0, bubbleBurst)!;
      final sideBias = tilt < 0 ? 0.72 : 0.28;

      final baseX = lerpDouble(_il + 9, _ir - 9, sideBias)!;
      final baseY = s.cY + 16.0 - driftUp;

      final bubbles = <Offset>[
        Offset(baseX, baseY),
        Offset(baseX - 4.5, baseY + 5.5),
        Offset(baseX + 3.5, baseY + 10.0),
        Offset(baseX - 2.0, baseY + 14.5),
        Offset(baseX + 1.5, baseY + 19.0),
        Offset(baseX - 5.5, baseY + 22.5),
      ];

      final radii = <double>[3.0, 2.5, 2.1, 1.8, 1.5, 1.2];

      for (int i = 0; i < bubbles.length; i++) {
        final p = bubbles[i];
        final r = radii[i] * lerpDouble(0.9, 1.15, bubbleBurst)!;

        canvas.drawCircle(p, r, bubbleFill);
        canvas.drawCircle(p, r, bubbleStroke);

        canvas.drawCircle(
          Offset(p.dx - r * 0.28, p.dy - r * 0.28),
          max(0.45, r * 0.18),
          highlightPaint,
        );
      }
    }

    // Sol iç parlaklık şeridi

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiquidPainter old) =>
      old.tube != tube ||
      old.tilt != tilt ||
      old.slosh != slosh ||
      old.drainedVolume != drainedVolume ||
      old.incomingColorIdx != incomingColorIdx ||
      old.incomingVolume != incomingVolume ||
      old.splash != splash ||
      old.pourProgress != pourProgress ||
      old.bubbleBurst != bubbleBurst ||
      old.receiveFlow != receiveFlow ||
      old.blindMode != blindMode ||
      old.visibleLayerCount != visibleLayerCount ||
      old.revealGlowTick != revealGlowTick ||
      old.lavaTime != lavaTime;
}

class BasinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6D4C41)
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(0, size.height * 0.6);

    path.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.2,
      size.width * 0.4,
      size.height * 0.6,
    );

    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.9,
      size.width * 0.8,
      size.height * 0.6,
    );

    path.quadraticBezierTo(
      size.width,
      size.height * 0.2,
      size.width,
      size.height * 0.6,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
