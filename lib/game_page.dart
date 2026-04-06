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

// ─────────────────────────────────────────────
// OYUN SABİTLERİ
// ─────────────────────────────────────────────

const int kCap = 4;
const int kNColors = 18;
const int kEmpty = 2;
const String kTubeSvgAsset = 'assets/likora/test_tube.svg';
const String kTubeLargeSvgAsset = 'assets/likora/test_tube_large.svg';

// Widget boyutları – SVG oranına göre ayarlandı (84.4 x 182 mm → 60 x 130 px)
const double kTW = 72.0;
const double kTH = 155.0;

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
          (effective.canvasHeight ?? maxBottom) + effective.topOffset + 18.0,
          kWidgetH + 18.0),
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

// _MapTheme ve _themeForMap kaldırıldı — MapTheme artık map_theme.dart'tan geliyor.

// ─────────────────────────────────────────────
// OYUN MANTIĞI
// ─────────────────────────────────────────────

List<List<int>> _legacyGenerateTubes({
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

  const _TransferPlan({
    required this.fromIdx,
    required this.toIdx,
    required this.fromSnapshot,
    required this.toSnapshot,
    required this.colorIdx,
    required this.count,
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

  late int _lockedAdTubeIndex;
  PuzzlePreset? _preset;

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
  final Map<String, List<(int, int)>> _solverSuccessCache = {};

  bool get _canBuyJoker => _coins >= _jokerCost;
  bool get _isDailyMode =>
      widget.isDailyPuzzleMode && widget.dailyPuzzleDateKey != null;

  _ResolvedStageLayout get _stageLayout => resolveStageLayout(
        layout: widget.customStageLayout ?? _preset?.layout,
        tubeCount: _tubes.length,
      );

  bool get _isCenterTubeMode =>
      _preset?.mode == PuzzleMode.centerTubeCollection &&
      _preset?.centerTube != null;

  CenterTubeConfig? get _centerTubeConfig => _preset?.centerTube;

  int _tubeCapacityIn(List<List<int>> tubes, int idx) {
    final center = _centerTubeConfig;
    if (center != null && idx == center.tubeIndex) {
      return center.capacity;
    }
    return kCap;
  }

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
    final center = _centerTubeConfig;
    if (center != null &&
        to == center.tubeIndex &&
        movingColor != center.targetColor) {
      return false;
    }

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
    final center = _centerTubeConfig;
    if (center != null && idx == center.tubeIndex) {
      return tube.first == center.targetColor;
    }
    return true;
  }

  bool _isGameDoneIn(List<List<int>> tubes) {
    for (int i = 0; i < tubes.length; i++) {
      if (tubes[i].isEmpty) continue;
      if (!_isTubeDoneIn(tubes, i)) return false;
    }
    return true;
  }

  void _tryRefillSourceTube(int tubeIndex) {
    final refill = _preset?.sourceRefill;
    final center = _centerTubeConfig;
    if (refill == null || !_isCenterTubeMode) return;
    if (!refill.tubeIndexes.contains(tubeIndex)) return;
    if (tubeIndex < 0 || tubeIndex >= _tubes.length) return;
    if (_tubes[tubeIndex].isNotEmpty) return;

    if (center != null && refill.stopWhenCenterTubeFull) {
      if (_tubes[center.tubeIndex].length >= center.capacity) {
        return;
      }
    }

    final queue = refill.refillQueues[tubeIndex];
    if (queue == null || queue.isEmpty) return;
    _tubes[tubeIndex] = List<int>.from(queue.removeAt(0), growable: true);
  }

  Future<void> _returnToMapPage() async {
    await _persistLevelState();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowTutorial();
    });
  }

  Future<void> _restoreOrResetLevel() async {
    await PlayerProgress.ensureLoaded();

    final syncedCoins = widget.initialCoins > 0
        ? widget.initialCoins
        : PlayerProgress.coins.value;

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
    _bgCtrl.dispose();
    super.dispose();
  }

  bool get _showLockedAdTube => !_adTubeUnlocked;
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

        restored.add((
          tubes: tubes,
          visibleLayerCounts: _normalizeVisibleLayerCounts(visible, tubes),
          fromIdx: fromIdx.clamp(0, _tubes.length - 1).toInt(),
          toIdx: toIdx.clamp(0, _tubes.length - 1).toInt(),
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

  // Hangi tüpler şu an aktif animasyonda meşgul
  Set<int> get _busyTubes {
    final s = <int>{};
    for (final p in _activePlans) {
      s.add(p.fromIdx);
      s.add(p.toIdx);
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

    _preset = PuzzlePresets.getOrNull(
      mapNumber: widget.mapNumber,
      levelId: widget.level,
    );

    return (_preset?.tubes ??
            _legacyGenerateTubes(
              level: widget.level,
              difficulty: widget.difficulty,
            ))
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

    final center = _centerTubeConfig;
    final solvedColors = colorCounts.keys.toList()..sort();
    final result = <List<int>>[];
    final usedColors = <int>{};

    for (int i = 0; i < initialTubes.length; i++) {
      if (initialTubes[i].isEmpty) {
        result.add(<int>[]);
        continue;
      }

      if (center != null && i == center.tubeIndex) {
        result.add(List<int>.filled(center.capacity, center.targetColor,
            growable: true));
        usedColors.add(center.targetColor);
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

    _visibleLayerCounts = List<int>.generate(
      _tubes.length,
      (i) => _tubes[i].length,
      growable: true,
    );
    _gameWon = true;
    _levelRewardGranted = true;
    _showTutorial = false;
    _selected = null;
  }

  Future<void> _persistLevelState() async {
    if (_restoringLevelState) return;

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

  bool _preservesCompletedTubes(
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
  }) {
    return _solveFromState(
      start,
      includeUnlockedAdTube: includeUnlockedAdTube,
      maxDepth: 48,
      maxNodes: 45000,
      maxMillis: 160,
    );
  }

  List<(int, int)>? _mediumSolveFromState(
    List<List<int>> start, {
    required bool includeUnlockedAdTube,
  }) {
    return _solveFromState(
      start,
      includeUnlockedAdTube: includeUnlockedAdTube,
      maxDepth: 90,
      maxNodes: 180000,
      maxMillis: 1400,
    );
  }

  List<(int, int)>? _solveFromState(
    List<List<int>> start, {
    required bool includeUnlockedAdTube,
    int maxDepth = 110,
    int maxNodes = 280000,
    int maxMillis = 2600,
  }) {
    final cacheKey = _solverCacheKey(
      start,
      includeUnlockedAdTube: includeUnlockedAdTube,
    );
    final cached = _solverSuccessCache[cacheKey];
    if (cached != null) {
      return List<(int, int)>.from(cached, growable: false);
    }

    final stopwatch = Stopwatch()..start();
    final dead = <String>{};
    final path = <(int, int)>[];
    int nodes = 0;

    bool dfs(List<List<int>> state, int depthLeft) {
      if (_isGameDoneIn(state)) {
        return true;
      }
      if (depthLeft <= 0) {
        return false;
      }
      if (nodes >= maxNodes || stopwatch.elapsedMilliseconds >= maxMillis) {
        return false;
      }

      final sig = _canonicalBoardSignature(
        state,
        includeUnlockedAdTube: includeUnlockedAdTube,
      );
      if (dead.contains(sig)) {
        return false;
      }

      nodes++;

      final moves = _orderedSolverMoves(
        state,
        includeUnlockedAdTube: includeUnlockedAdTube,
      );

      for (final move in moves) {
        final next = _cloneTubes(state);
        _doPourIn(next, move.$1, move.$2);

        path.add(move);
        if (dfs(next, depthLeft - 1)) {
          return true;
        }
        path.removeLast();
      }

      dead.add(sig);
      return false;
    }

    for (int depth = 1; depth <= maxDepth; depth++) {
      path.clear();
      dead.clear();
      nodes = 0;

      final root = _cloneTubes(start);
      if (dfs(root, depth)) {
        final solvedPath = List<(int, int)>.from(path, growable: false);
        _solverSuccessCache[cacheKey] = solvedPath;
        return solvedPath;
      }

      if (stopwatch.elapsedMilliseconds >= maxMillis || nodes >= maxNodes) {
        break;
      }
    }

    return null;
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

  (int, int)? _findBestEffortMove(
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

  _JokerDecision? _findSmartJokerDecision() {
    // Önce bulunduğumuz noktadan hızlıca çözüm var mı bak.
    final directQuick = _quickSolveFromState(
      _tubes,
      includeUnlockedAdTube: _adTubeUnlocked,
    );
    if (directQuick != null && directQuick.isNotEmpty) {
      return _JokerDecision(
        from: directQuick.first.$1,
        to: directQuick.first.$2,
      );
    }

    // Çıkmaza girilmişse hızlıca geçmişte çözülebilen en yakın noktayı bul.
    // Önce tamamlanmış tüpleri koruyan state'leri, sonra diğerlerini tara.
    for (final keepDone in [true, false]) {
      final maxQuickHistory = _history.length < 10 ? _history.length : 10;

      for (int rewindCount = 1; rewindCount <= maxQuickHistory; rewindCount++) {
        final snapshot =
            _cloneTubes(_history[_history.length - rewindCount].tubes);
        final preservesDone = _preservesCompletedTubes(_tubes, snapshot);

        if (keepDone && !preservesDone) continue;
        if (!keepDone && preservesDone) continue;

        final quick = _quickSolveFromState(
          snapshot,
          includeUnlockedAdTube: _adTubeUnlocked,
        );
        if (quick != null && quick.isNotEmpty) {
          return _JokerDecision(
            from: quick.first.$1,
            to: quick.first.$2,
            rewindCount: rewindCount,
          );
        }
      }
    }

    // Hızlı tarama bulamazsa bulunduğumuz noktada biraz daha derin çözüm dene.
    final directMedium = _mediumSolveFromState(
      _tubes,
      includeUnlockedAdTube: _adTubeUnlocked,
    );
    if (directMedium != null && directMedium.isNotEmpty) {
      return _JokerDecision(
        from: directMedium.first.$1,
        to: directMedium.first.$2,
      );
    }

    // Sonra bütün geçmişte çözülebilen en yakın state'i ara.
    _JokerDecision? fallbackKeepingDone;
    _JokerDecision? fallbackAny;

    for (int rewindCount = 1; rewindCount <= _history.length; rewindCount++) {
      final snapshot =
          _cloneTubes(_history[_history.length - rewindCount].tubes);
      final preservesDone = _preservesCompletedTubes(_tubes, snapshot);

      final solution = _mediumSolveFromState(
        snapshot,
        includeUnlockedAdTube: _adTubeUnlocked,
      );
      if (solution != null && solution.isNotEmpty) {
        final candidate = _JokerDecision(
          from: solution.first.$1,
          to: solution.first.$2,
          rewindCount: rewindCount,
        );

        if (preservesDone) {
          fallbackKeepingDone ??= candidate;
        } else {
          fallbackAny ??= candidate;
        }
      }
    }

    if (fallbackKeepingDone != null) return fallbackKeepingDone;
    if (fallbackAny != null) return fallbackAny;

    // En son çare: loop oluşturmayan mantıklı bir hamle yap.
    final directBestEffort = _findBestEffortMove(
      _tubes,
      includeUnlockedAdTube: _adTubeUnlocked,
    );
    if (directBestEffort != null) {
      return _JokerDecision(
        from: directBestEffort.$1,
        to: directBestEffort.$2,
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
    if (!mounted) return false;

    // TODO: Gerçek rewarded reklam entegrasyonu gelince burayı bağla.
    _vibrateLight();
    _showBottomHint('Reklam şu anda hazır değil');

    // TODO: Gerçek reklam gösterimi
    // final adReady = await _adsService.isRewardedAdReady();
    // if (!adReady) { _showBottomHint('Reklam şu anda hazır değil'); return false; }
    // final rewarded = await _adsService.showRewardedJokerAd();
    // if (rewarded != true) { _showBottomHint('Reklam tamamlanmadı'); return false; }
    // return true;

    return false;
  }

  Future<bool> _tryUnlockAdTube() async {
    if (!mounted) return false;

    // TODO: Gerçek rewarded reklam entegrasyonu gelince burayı bağla.
    _vibrateLight();
    _showBottomHint('Reklam şu anda hazır değil');

    // TODO: Gerçek reklam gösterimi
    // final adReady = await _adsService.isRewardedAdReady();
    // if (!adReady) { _showBottomHint('Reklam şu anda hazır değil'); return false; }
    // final rewarded = await _adsService.showRewardedTubeUnlockAd();
    // if (rewarded != true) { _showBottomHint('Reklam tamamlanmadı'); return false; }
    // setState(() { _adTubeUnlocked = true; });
    // _persistLevelState();
    // return true;

    return false;
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
      }

      await _startPour(decision.from, decision.to);
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
    ));

    // Mantık durumunu hemen güncelle (animasyon gösterimi snapshot tabanlı)
    _doPourIn(_tubes, from, to);
    _tryRefillSourceTube(from);
    _tryRefillSourceTube(to);

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
        Future.delayed(const Duration(milliseconds: 2100), () {
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showTutorial ? 0.22 : 1.0,
                  child: IgnorePointer(
                    ignoring: _showTutorial,
                    child: SafeArea(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _TestLevelButton(
                            enabled: !_gameWon && _activePlans.isEmpty,
                            accentColor: _theme.accentColor,
                            onTap: _debugCompleteLevel,
                          ),
                          const SizedBox(width: 12),
                          _UndoButton(
                            canUndo: _history.isNotEmpty &&
                                _activePlans.isEmpty &&
                                !_gameWon,
                            accentColor: _theme.accentColor,
                            onTap: _undo,
                          ),
                          const SizedBox(width: 12),
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
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Ink(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
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
                        size: 22,
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
          borderRadius: BorderRadius.circular(18),
          onTap: canUndo ? onTap : null,
          child: Ink(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
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
                size: 24,
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
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
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
                  size: 21,
                ),
                const SizedBox(width: 6),
                Text(
                  'TEST',
                  style: TextStyle(
                    color: enabled
                        ? accentColor
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
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

  const _TubeStage({
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
  });

  @override
  State<_TubeStage> createState() => _TubeStageState();
}

class _TubeStageState extends State<_TubeStage> {
  late List<GlobalKey> _keys;

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

    // Hedef tüpün gerçek render edilmiş genişlik merkezini kullan.
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
    final bool tutorialTarget = widget.tutorialActive &&
        ((widget.tutorialStepIndex == 0 && idx == widget.tutorialFromIdx) ||
            (widget.tutorialStepIndex == 1 && idx == widget.tutorialToIdx));
    final bool dimForTutorial = widget.tutorialActive && !tutorialTarget;

    final activeTargetPlan =
        widget.activePlans.cast<_TransferPlan?>().firstWhere(
              (p) => p?.toIdx == idx,
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

    final isLargeCollector = tubeStyle == PuzzleTubeStyle.largeCollector;
    final double renderWidth = isLargeCollector ? 138.0 : kWidgetW;
    final double renderHeight = isLargeCollector ? 348.0 : kWidgetH;

    if (isLargeCollector) {
      tubeView = SizedBox(
        width: renderWidth,
        height: renderHeight,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: kWidgetW,
            height: kWidgetH,
            child: tubeView,
          ),
        ),
      );
    }

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
            blindMode: widget.blindMode,
            visibleLayerCount: plan.fromSnapshot.isEmpty
                ? 0
                : min(1, plan.fromSnapshot.length),
            revealGlowTick: 0,
            tubeStyle:
                widget.tubeStyles[plan.fromIdx] ?? PuzzleTubeStyle.classic,
            capacity: widget.tubeCapacities[plan.fromIdx] ?? kCap,
          ),
      ],
    );
  }
}

class _AdUnlockBadge extends StatelessWidget {
  final Color color;

  const _AdUnlockBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: 15,
        color: color,
      ),
    );
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
  final bool blindMode;
  final int visibleLayerCount;
  final int revealGlowTick;
  final PuzzleTubeStyle tubeStyle;
  final int capacity;

  const _FlyingTube({
    super.key,
    required this.plan,
    required this.getPos,
    required this.getAnchor,
    required this.getRealTargetMouth,
    required this.getRealTargetSurface,
    this.blindMode = false,
    this.visibleLayerCount = kCap,
    this.revealGlowTick = 0,
    this.tubeStyle = PuzzleTubeStyle.classic,
    this.capacity = kCap,
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
  static const double _extraHoverLift = 80.0;

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

    final targetSurface = widget.getRealTargetSurface(
      widget.plan.toIdx,
      widget.plan.toSnapshot.length.toDouble(),
    );

    // Artık sabit local ağız noktası değil,
    // hedef tüpün gerçek render edilmiş ağız merkezi kullanılıyor.
    final targetMouthEntry = widget.getRealTargetMouth(widget.plan.toIdx);

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
                .clamp(0.0, kCap.toDouble());
        final dynamicTargetSurface = widget.getRealTargetSurface(
              widget.plan.toIdx,
              currentToVolume,
            ) ??
            targetSurface;

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

  @override
  void paint(Canvas canvas, Size size) {
    if (headProgress <= 0.0) return;
    if ((end - start).distance < 1.0) return;

    final totalDy = end.dy - start.dy;

    // Akışın ucu: start.dy → end.dy
    final headY = start.dy + totalDy * headProgress.clamp(0.0, 1.0);

    // Akışın tepesi: tailProgress>0 olunca start.dy'den aşağı kayar
    // tail, head'i asla geçemez
    final tailY = tailProgress <= 0.0
        ? start.dy
        : (start.dy + totalDy * tailProgress.clamp(0.0, 1.0))
            .clamp(start.dy, headY - 4.0);

    if (headY - tailY < 1.0) return;

    final thickness = lerpDouble(3.6, 7.0, flowRate)!;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, tailY)
      ..lineTo(start.dx, headY);

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

class _TubeWidget extends StatelessWidget {
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
    final svgAsset = tubeStyle == PuzzleTubeStyle.largeCollector
        ? kTubeLargeSvgAsset
        : kTubeSvgAsset;

    final frame = RepaintBoundary(
      child: SizedBox(
        width: kWidgetW,
        height: kWidgetH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size(kWidgetW, kWidgetH),
              painter: _LiquidPainter(
                tube: tube,
                tilt: tilt,
                slosh: slosh,
                drainedVolume: drainedVolume,
                incomingColorIdx: incomingColorIdx,
                incomingVolume: incomingVolume,
                splash: splash,
                pourProgress: pourProgress,
                bubbleBurst: bubbleBurst,
                receiveFlow: receiveFlow,
                blindMode: blindMode,
                visibleLayerCount: visibleLayerCount,
                revealGlowTick: revealGlowTick,
                capacity: capacity,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: SvgPicture.asset(
                  svgAsset,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final liftY = isSelected ? -15.0 : 0.0;

    if (tilt.abs() < 0.0001) {
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
            angle: tilt,
            alignment: _pivotAlignment(),
            transformHitTests: false,
            child: frame,
          ),
        ),
      ),
    );
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

      final fill = isHidden
          ? const Color(0xFF2A2535)
          : kColors[safeIdx]['fill'] as Color;

      final bandPath = _band(vBot, vTop, tilt, isTop ? slosh : slosh * 0.45);
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
      canvas.drawPath(
        _surfaceLine(totalVol, tilt, slosh),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
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

      final bubbleFill = Paint()
        ..color = Colors.white.withValues(alpha: 0.55 * bubbleBurst)
        ..style = PaintingStyle.fill;

      final bubbleStroke = Paint()
        ..color = Colors.white.withValues(alpha: 0.95 * bubbleBurst)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95 * bubbleBurst)
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
      old.revealGlowTick != revealGlowTick;
}
