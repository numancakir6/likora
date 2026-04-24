import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'map_theme.dart';
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
import 'package:collection/collection.dart';
import 'game/core/game_models.dart';
import 'game/core/game_visuals.dart';
import 'game/core/game_logic.dart';
import 'game/core/game_refill.dart';
import 'game/maps/map3/map3_mountain_reservoir.dart';
import 'game/maps/map2/map2_visibility.dart';
import 'game/maps/map2/map2_ui.dart';

// ─────────────────────────────────────────────
// OYUN SABİTLERİ
// ─────────────────────────────────────────────

const int kCap = 4;
const String kTubeSvgAsset = 'assets/likora/test_tube.svg';
const String kTubeLargeSvgAsset = 'assets/likora/test_tube_large.svg';
const String kVolcanoReservoirSvgAsset = 'assets/likora/volkan_hazne.png';

// Widget boyutları – SVG oranına göre ayarlandı (84.4 x 182 mm → 60 x 130 px)
const double kTW = 90.0;
const double kTH = 190.0;
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
double get kLiquidLeft => kBodyInnerLeft + 5;
double get kLiquidRight => kBodyInnerRight - 5;
double get kLiquidW => kLiquidRight - kLiquidLeft;
double get kLiquidTopY => kCapBotY + 25.0;
double get kMouthEntryY => kCapBotY + 4.0;
double get kLiquidBotY => kBodyBotY + kTR - 18;

// Widget toplam yüksekliği
// Alt U'nun en altı: SVG'de y=18197.8 → kTH
double get kWidgetH => kTH;
double get kWidgetW => kTW;
const double kTubeGap = 0.0;
const double kRowGap = 8.0;

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

const Duration kPourDuration = Duration(milliseconds: 1100);

// ─────────────────────────────────────────────
// YARDIMCI MODELLER
// ─────────────────────────────────────────────

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
  final int? customMountainCapacity;
  final List<int>? customRefillTubeIndexes;
  final Map<int, List<List<int>>>? customRefillQueues;
  final bool customStopRefillWhenMountainFull;

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
    this.customMountainCapacity,
    this.customRefillTubeIndexes,
    this.customRefillQueues,
    this.customStopRefillWhenMountainFull = false,
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
      topLeft.dy + size.height * 0.5,
    );
  }

  late int _lockedAdTubeIndex;
  PuzzlePreset? _preset;
  Map<int, List<List<int>>> _runtimeRefillQueues = {};

  // Oyun mantık durumu (gerçek veri)
  late List<List<int>> _tubes;

  // Aktif animasyonlar (paralel çalışabilir)
  final List<TransferPlan> _activePlans = [];

  // Seçim durumu
  int? _selected;

  // Sıralı komut kuyruğu: (from, to) çiftleri
  final Queue<(int, int)> _commandQueue = Queue<(int, int)>();

  bool _gameWon = false;
  bool _isPopping = false; // Çift pop koruması
  final Map<int, int> _celebratingDoneTubes = <int, int>{};

  // Geri alma geçmişi
  final List<
      ({
        List<List<int>> tubes,
        List<int> visibleLayerCounts,
        int fromIdx,
        int toIdx,
        int mountainFillUnits,
        List<VisualLayer> mountainLayers,
        Map<int, List<List<int>>> runtimeRefillQueues,
      })> _history = [];

  late List<int> _visibleLayerCounts;
  final Map<int, int> _blindRevealFlashTicks = <int, int>{};
  // Geri alma animasyonu — hangi tüpler sloshing yapıyor
  final Map<int, int> _undoSloshingTubes = {}; // tubeIdx → colorIdx

  static const String _tutorialSeenKey = 'likora_tutorial_seen_v1';

  bool _showTutorial = false; // tutorial disabled
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
  bool _adTubeUnlocked = false;
  bool _levelRewardGranted = false;
  bool _restoringLevelState = true;
  bool _missingPreset = false;
  int _mountainFillUnits = 0;
  final List<VisualLayer> _mountainLayers = [];
  bool _loopCompletedVolcano = false;
  // Rewarded reklam
  RewardedAd? _extraTubeAd;
  bool _isExtraTubeAdReady = false;
  RewardedAd? _jokerRewardAd;
  bool _isJokerRewardAdReady = false;
  bool _jokerBusy = false;
  static const int _jokerCost = 50;
  List<int> _jokerSearchLimitsForCurrentState() {
    final activeTubeCount = _jokerActiveTubeIndexesFor(_tubes).length;
    final freshStart = _history.isEmpty;

    if (widget.mapNumber == 1) {
      if (widget.level <= 3) {
        return freshStart ? [4000, 10000] : [6000, 16000, 40000];
      }
      if (widget.level <= 6) {
        return freshStart ? [7000, 18000] : [10000, 30000, 70000];
      }
      return freshStart ? [10000, 28000, 70000] : [14000, 45000, 100000];
    }

    if (widget.mapNumber == 2) {
      if (widget.level <= 5) {
        return freshStart ? [10000, 30000, 70000] : [16000, 45000, 100000];
      }
      if (widget.level <= 7) {
        return freshStart ? [18000, 60000, 140000] : [25000, 80000, 180000];
      }
      return freshStart ? [30000, 100000, 220000] : [40000, 120000, 300000];
    }

    if (widget.mapNumber == 3) {
      if (widget.level <= 3) {
        return freshStart ? [15000, 50000, 120000] : [20000, 70000, 160000];
      }
      if (widget.level <= 6) {
        return freshStart ? [22000, 80000, 180000] : [30000, 100000, 240000];
      }
      return freshStart ? [40000, 140000, 350000] : [55000, 180000, 400000];
    }

    if (activeTubeCount <= 8) {
      return freshStart ? [7000, 18000] : [10000, 30000, 70000];
    }

    if (activeTubeCount <= 11) {
      return freshStart ? [12000, 40000, 90000] : [18000, 60000, 140000];
    }

    return freshStart ? [25000, 80000, 180000] : [35000, 120000, 300000];
  }

  bool get _adsEnabledOnThisPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  bool get _isDailyMode =>
      widget.isDailyPuzzleMode && widget.dailyPuzzleDateKey != null;

  int get _mountainCapacity =>
      widget.customMountainCapacity ?? _preset?.mountainCapacity ?? 0;

  List<int> get _activeRefillTubeIndexes =>
      widget.customRefillTubeIndexes ??
      _preset?.sourceRefill?.tubeIndexes ??
      const <int>[];

  bool get _activeStopRefillWhenMountainFull =>
      widget.customStopRefillWhenMountainFull ||
      (_preset?.sourceRefill?.stopWhenMountainFull ?? false);

  Map<int, List<List<int>>> _initialRefillQueuesConfig() {
    if (widget.customRefillQueues != null) {
      return _cloneRefillQueuesMap(widget.customRefillQueues!);
    }
    return _cloneRefillQueues(_preset?.sourceRefill);
  }

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
        VisualLayer(
          colorIdx: kLavaColorIndex,
          volume: capacity.toDouble(),
        ),
      );
  }

  _ResolvedStageLayout _applyMapSpecificStagePadding(
    _ResolvedStageLayout base,
  ) {
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

  StageLayout _rowsLayoutForTubeCount(
    int tubeCount,
    int maxPerRow, {
    double? tubeGap,
    double? rowGap,
  }) {
    final safeCount = tubeCount < 1 ? 1 : tubeCount;
    final perRow = max(1, min(maxPerRow, safeCount));
    final indices = List<int>.generate(safeCount, (i) => i);
    final rows = <List<int>>[];

    var cursor = 0;
    while (cursor < indices.length) {
      final remaining = indices.length - cursor;
      final take = remaining > perRow ? perRow : remaining;
      rows.add(indices.sublist(cursor, cursor + take));
      cursor += take;
    }

    final paddings = List<double>.filled(rows.length, 0);
    if (paddings.isNotEmpty) {
      paddings[paddings.length - 1] = 4;
    }

    return StageLayout.rows(
      rows: rows,
      rowTopPaddings: paddings,
      tubeGap: tubeGap ?? kTubeGap,
      rowGap: rowGap ?? kRowGap,
    );
  }

  _ResolvedStageLayout _adaptiveStageLayoutFor(BoxConstraints constraints) {
    final baseLayout = widget.customStageLayout ?? _preset?.layout;

    if (baseLayout?.mode == StageLayoutMode.manual) {
      return _applyMapSpecificStagePadding(
        resolveStageLayout(layout: baseLayout, tubeCount: _tubes.length),
      );
    }

    if (_tubes.length <= 4) {
      return _applyMapSpecificStagePadding(
        resolveStageLayout(layout: baseLayout, tubeCount: _tubes.length),
      );
    }

    final candidates = <_ResolvedStageLayout>[];
    for (final perRow in const [5, 4]) {
      candidates.add(
        _applyMapSpecificStagePadding(
          resolveStageLayout(
            layout: _rowsLayoutForTubeCount(
              _tubes.length,
              perRow,
              tubeGap: perRow == 5 ? 6.0 : 8.0,
              rowGap: 12.0,
            ),
            tubeCount: _tubes.length,
          ),
        ),
      );
    }

    final availableW = max(1.0, constraints.maxWidth);
    final availableH = max(1.0, constraints.maxHeight);

    _ResolvedStageLayout best = candidates.first;
    double bestScore = -1;

    for (final candidate in candidates) {
      final scale = min(
        availableW / candidate.width,
        availableH / candidate.height,
      );
      final usedArea = (candidate.width * scale) * (candidate.height * scale);
      final rowPenalty = candidate.rows.length * 0.001;
      final score = usedArea - rowPenalty;
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return best;
  }

  int _tubeCapacityIn(List<List<int>> tubes, int idx) => kCap;

  PuzzleTubeStyle _tubeStyleForIndex(int idx) {
    return _preset?.tubeStyles[idx] ??
        _preset?.tubeStyle ??
        PuzzleTubeStyle.classic;
  }

  bool _isTubeDoneIn(List<List<int>> tubes, int idx) {
    return isTubeDoneBoard(
      tubes[idx],
      cap: _tubeCapacityIn(tubes, idx),
    );
  }

  bool _isGameDoneIn(List<List<int>> tubes) {
    if (_hasMountainObjective && _mountainFillUnits < _mountainCapacity) {
      return false;
    }

    for (int i = 0; i < tubes.length; i++) {
      if (tubes[i].isEmpty) continue;
      if (!isTubeDoneBoard(tubes[i], cap: _tubeCapacityIn(tubes, i)))
        return false;
    }
    return true;
  }

  Map<int, List<List<int>>> _cloneRefillQueues(SourceTubeRefillConfig? refill) {
    return cloneRefillQueues(refill);
  }

  Map<int, List<List<int>>> _cloneRefillQueuesMap(
    Map<int, List<List<int>>> source,
  ) {
    return cloneRefillQueuesMap(source);
  }

  Map<int, List<List<int>>> _decodeRuntimeRefillQueues(dynamic raw) {
    return decodeRuntimeRefillQueues(raw);
  }

  Map<String, dynamic> _encodeRuntimeRefillQueues(
    Map<int, List<List<int>>> queues,
  ) {
    return encodeRuntimeRefillQueues(queues);
  }

  String get _refillStatePrefsKey =>
      'likora_refill_state_${widget.mapNumber}_${widget.level}';

  String? get _dailyRefillStatePrefsKey => widget.dailyPuzzleDateKey == null
      ? null
      : 'likora_daily_refill_state_${widget.dailyPuzzleDateKey}';

  String? get _effectiveRefillStatePrefsKey =>
      _isDailyMode ? _dailyRefillStatePrefsKey : _refillStatePrefsKey;

  Future<void> _persistRefillState() async {
    await persistRefillState(
      key: _effectiveRefillStatePrefsKey,
      gameWon: _gameWon,
      runtimeRefillQueues: _runtimeRefillQueues,
    );
  }

  Future<void> _restoreRefillState() async {
    _runtimeRefillQueues = await restoreRefillState(
      initialRefillQueues: _initialRefillQueuesConfig(),
      key: _effectiveRefillStatePrefsKey,
    );
  }

  Future<void> _clearRefillState() async {
    await clearRefillState(
      refillStatePrefsKey: _refillStatePrefsKey,
      dailyRefillStatePrefsKey: _dailyRefillStatePrefsKey,
    );
  }

  bool isRefillStopped() {
    return refillStopped(
      activeRefillTubeIndexes: _activeRefillTubeIndexes,
      activeStopRefillWhenMountainFull: _activeStopRefillWhenMountainFull,
      hasMountainObjective: _hasMountainObjective,
      mountainFillUnits: _mountainFillUnits,
      mountainCapacity: _mountainCapacity,
    );
  }

  void _tryRefillSourceTube(int tubeIndex) {
    final result = tryRefillSourceTube(
      refillTubeIndexes: _activeRefillTubeIndexes,
      runtimeRefillQueues: _runtimeRefillQueues,
      tubes: _tubes,
      tubeIndex: tubeIndex,
      stopRefill: isRefillStopped(),
    );
    _runtimeRefillQueues = result.runtimeRefillQueues;
    _tubes = result.tubes;
  }

  Future<void> _returnToMapPage() async {
    if (_isPopping) return; // Çift pop koruması
    _isPopping = true;

    if (!_missingPreset) {
      await _persistLevelState();
    }
    if (!mounted) return;

    // Her zaman pop ile geri dön — asla yeni MapPage oluşturma.
    Navigator.of(context).pop(
      GamePageResult(
        completed: _gameWon,
        coinsAfterLevel: _coins,
        earnedCoins: _gameWon ? _levelReward : 0,
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
      _loadExtraTubeAd();
      _loadJokerRewardAd();
    }
  }

  Future<void> _restoreOrResetLevel() async {
    try {
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
      } else if (widget.customRefillQueues != null) {
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
          _mountainFillUnits = (_mountainCapacity > 0)
              ? saved.mountainFillUnits.clamp(0, _mountainCapacity).toInt()
              : 0;
          _mountainLayers
            ..clear()
            ..addAll(
              _mountainFillUnits > 0
                  ? <VisualLayer>[
                      VisualLayer(
                        colorIdx: kLavaColorIndex,
                        volume: _mountainFillUnits.toDouble(),
                      ),
                    ]
                  : const <VisualLayer>[],
            );
          await _restoreUndoHistoryState();
          await _restoreRefillState();
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
    } catch (e, stack) {
      debugPrint('_restoreOrResetLevel hatası: $e\n$stack');
      if (!mounted) return;
      _reset();
      setState(() {
        _restoringLevelState = false;
      });
    }
  }

  @override
  void dispose() {
    unawaited(SfxService.stopAllWater());
    _extraTubeAd?.dispose();
    _jokerRewardAd?.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  bool get _showLockedAdTube => !_adTubeUnlocked;

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

  void _loadJokerRewardAd() {
    if (!_adsEnabledOnThisPlatform) return;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3080345587906246/3174441406',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _jokerRewardAd?.dispose();
          _jokerRewardAd = ad;
          _isJokerRewardAdReady = true;
        },
        onAdFailedToLoad: (error) {
          _jokerRewardAd = null;
          _isJokerRewardAdReady = false;
        },
      ),
    );
  }

  bool get _canBuyJoker => _coins >= _jokerCost;

  Future<bool> _showRewardedJokerAdGate() async {
    if (!_adsEnabledOnThisPlatform) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web testinde reklam kapalı')),
        );
      }
      return false;
    }

    if (_jokerRewardAd == null || !_isJokerRewardAdReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reklam hazır değil')),
        );
      }
      _loadJokerRewardAd();
      return false;
    }

    final completer = Completer<bool>();
    var rewardEarned = false;

    _jokerRewardAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _jokerRewardAd = null;
        _isJokerRewardAdReady = false;
        _loadJokerRewardAd();
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _jokerRewardAd = null;
        _isJokerRewardAdReady = false;
        _loadJokerRewardAd();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    _jokerRewardAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
      },
    );

    return completer.future;
  }

  bool get _blindModeEnabled => isBlindModeForMap(widget.mapNumber);

  String get _blindVisibilityPrefsKey =>
      'likora_blind_visibility_${widget.mapNumber}_${widget.level}';

  String get _undoHistoryPrefsKey =>
      'likora_undo_history_${widget.mapNumber}_${widget.level}';

  String? get _dailyUndoHistoryPrefsKey => widget.dailyPuzzleDateKey == null
      ? null
      : 'likora_daily_undo_history_${widget.dailyPuzzleDateKey}';

  bool _isLockedAdTubeIndex(int idx) =>
      _showLockedAdTube && idx == _lockedAdTubeIndex;

  List<int> _normalizeVisibleLayerCounts(
    List<int>? raw,
    List<List<int>> tubes,
  ) {
    return normalizeVisibleLayerCounts(
      raw,
      tubes,
      blindModeEnabled: _blindModeEnabled,
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
        List<VisualLayer> mountainLayers,
        Map<int, List<List<int>>> runtimeRefillQueues,
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
            : defaultVisibleLayerCountsFor(
                blindModeEnabled: _blindModeEnabled,
                tubes: tubes,
              );

        final mountainFillUnitsRaw = item['mountainFillUnits'];
        final mountainLayersRaw = item['mountainLayers'];
        final runtimeRefillQueuesRaw = item['runtimeRefillQueues'];
        final mountainFillUnits = mountainFillUnitsRaw is int
            ? (_mountainCapacity > 0
                ? mountainFillUnitsRaw.clamp(0, _mountainCapacity).toInt()
                : 0)
            : 0;
        final mountainLayers = <VisualLayer>[];
        if (mountainLayersRaw is List) {
          for (final layerRaw in mountainLayersRaw) {
            if (layerRaw is! Map) continue;
            final colorIdx = layerRaw['colorIdx'];
            final volumeRaw = layerRaw['volume'];
            if (colorIdx is! int) continue;
            final volume = volumeRaw is num ? volumeRaw.toDouble() : 0.0;
            if (volume <= 0) continue;
            mountainLayers.add(
              VisualLayer(
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
          runtimeRefillQueues: runtimeRefillQueuesRaw == null
              ? _initialRefillQueuesConfig()
              : _decodeRuntimeRefillQueues(runtimeRefillQueuesRaw),
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
              'runtimeRefillQueues':
                  _encodeRuntimeRefillQueues(entry.runtimeRefillQueues),
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
      _visibleLayerCounts = defaultVisibleLayerCountsFor(
        blindModeEnabled: _blindModeEnabled,
        tubes: _tubes,
      );
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
    final result = updateBlindVisibilityAfterPour(
      blindModeEnabled: _blindModeEnabled,
      visibleLayerCounts: _visibleLayerCounts,
      tubes: _tubes,
      from: from,
      to: to,
      pouredCount: pouredCount,
    );

    _visibleLayerCounts = result.visibleLayerCounts;

    if (result.shouldRevealFromSource) {
      _triggerBlindRevealFlash(from);
    }
  }

  void _updateBlindVisibilityAfterMountainPour(int from, int pouredCount) {
    final result = updateBlindVisibilityAfterMountainPour(
      blindModeEnabled: _blindModeEnabled,
      visibleLayerCounts: _visibleLayerCounts,
      tubes: _tubes,
      from: from,
      pouredCount: pouredCount,
    );

    _visibleLayerCounts = result.visibleLayerCounts;

    if (result.shouldRevealFromSource) {
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
    _visibleLayerCounts = defaultVisibleLayerCountsFor(
      blindModeEnabled: _blindModeEnabled,
      tubes: _tubes,
    );
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
    _mountainFillUnits = 0;
    _mountainLayers.clear();
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

    _runtimeRefillQueues = _initialRefillQueuesConfig();

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
    return buildCompletedTubesFromInitialBoard(
      initialTubes,
      tubeCapacityResolver: _tubeCapacityIn,
    );
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
        await _clearRefillState();
        return;
      }

      await DailyPuzzleProgress.saveInProgressState(
        dateKey: widget.dailyPuzzleDateKey!,
        tubes: _tubes,
        lockedAdTubeIndex: _lockedAdTubeIndex,
        adTubeUnlocked: _adTubeUnlocked,
        visibleLayerCounts: _blindModeEnabled ? _visibleLayerCounts : null,
        mountainFillUnits: _mountainFillUnits,
      );
      await _persistBlindVisibilityState();
      await _persistRefillState();
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

  List<int> _jokerActiveTubeIndexesFor(List<List<int>> tubes) {
    final indexes = <int>[];
    for (int i = 0; i < tubes.length; i++) {
      if (_showLockedAdTube && i == _lockedAdTubeIndex) continue;
      indexes.add(i);
    }
    return indexes;
  }

  bool _canPourInSimulation(List<List<int>> tubes, int from, int to) {
    return canPourBoard(tubes, from, to, cap: _tubeCapacityIn(tubes, to));
  }

  bool _canPourToMountainInSimulation(List<List<int>> tubes, int from) {
    if (!_hasMountainObjective) return false;
    if (_showLockedAdTube && from == _lockedAdTubeIndex) return false;
    if (from < 0 || from >= tubes.length || tubes[from].isEmpty) return false;
    if (!isLavaColorIndex(tubes[from].last)) return false;
    return true;
  }

  int _mountainPourCountInSimulation(
    List<List<int>> tubes,
    int from,
    int currentMountainFillUnits,
  ) {
    if (!_canPourToMountainInSimulation(tubes, from)) return 0;

    final available = _mountainCapacity - currentMountainFillUnits;
    if (available <= 0) return 0;

    final colorIdx = tubes[from].last;
    int count = 0;
    for (int i = tubes[from].length - 1; i >= 0; i--) {
      if (tubes[from][i] == colorIdx) {
        count++;
      } else {
        break;
      }
    }

    return min(count, available);
  }

  List<String>? findSolution({
    List<List<int>>? sourceTubes,
    int? mountainFillUnits,
    int maxIterations = 40000,
  }) {
    final initialTubes = cloneBoardState(sourceTubes ?? _tubes);
    final initialMountainFillUnits = mountainFillUnits ?? _mountainFillUnits;
    final activeIndexes = _jokerActiveTubeIndexesFor(initialTubes);
    final targetMountainCapacity =
        _hasMountainObjective ? _mountainCapacity : 0;
    final initialRefillQueues = _cloneRefillQueuesMap(_runtimeRefillQueues);
    final stopWhenMountainFull = _activeStopRefillWhenMountainFull;

    int heuristic(JokerSearchNode node) {
      var h = 0;

      for (final idx in activeIndexes) {
        final tube = node.tubes[idx];
        if (tube.isEmpty) continue;

        final cap = _tubeCapacityIn(node.tubes, idx);
        final isDone = tube.length == cap && tube.every((c) => c == tube.first);
        if (!isDone) {
          h += 10;
          final uniqueColors = tube.toSet().length;
          h += (uniqueColors - 1) * 4;
        }
      }

      if (targetMountainCapacity > 0) {
        final remaining =
            max(0, targetMountainCapacity - node.mountainFillUnits);
        h += remaining * 2;
      }

      return h;
    }

    int computePriority(JokerSearchNode node) {
      final g = node.moves.length;
      final h = heuristic(node);
      return g + h;
    }

    final startNode = JokerSearchNode(
      tubes: initialTubes,
      mountainFillUnits: initialMountainFillUnits,
      moves: const [],
      refillQueues: initialRefillQueues,
      priority: 0,
    );

    if (startNode.isSolved(
      activeIndexes: activeIndexes,
      mountainCapacity: targetMountainCapacity,
      tubeCapacityIn: _tubeCapacityIn,
    )) {
      return const [];
    }

    final pq = PriorityQueue<JokerSearchNode>(
      (a, b) => a.priority.compareTo(b.priority),
    )..add(startNode);

    final visited = <String>{startNode.stateId(activeIndexes)};
    var iterations = 0;

    while (pq.isNotEmpty && iterations < maxIterations) {
      iterations++;
      final current = pq.removeFirst();

      if (current.isSolved(
        activeIndexes: activeIndexes,
        mountainCapacity: targetMountainCapacity,
        tubeCapacityIn: _tubeCapacityIn,
      )) {
        return current.moves;
      }

      final lastMove = current.moves.isNotEmpty ? current.moves.last : null;

      for (final from in activeIndexes) {
        if (_isTubeDoneIn(current.tubes, from)) continue;
        if (current.tubes[from].isEmpty) continue;

        for (final to in activeIndexes) {
          if (from == to) continue;
          if (lastMove == '$to->$from') continue;
          if (!_canPourInSimulation(current.tubes, from, to)) continue;

          if (current.tubes[to].isEmpty) {
            final earlierEquivalentEmpty = activeIndexes.any(
              (idx) =>
                  idx != to &&
                  idx != from &&
                  current.tubes[idx].isEmpty &&
                  idx < to,
            );
            if (earlierEquivalentEmpty) continue;
          }

          final nextTubes = cloneBoardState(current.tubes);
          doPourBoard(nextTubes, from, to, cap: _tubeCapacityIn(nextTubes, to));

          final nextRefillQueues = _cloneRefillQueuesMap(current.refillQueues);
          if (nextTubes[from].isEmpty) {
            final queue = nextRefillQueues[from];
            final refillStopped = targetMountainCapacity > 0 &&
                stopWhenMountainFull &&
                current.mountainFillUnits >= targetMountainCapacity;
            if (!refillStopped && queue != null && queue.isNotEmpty) {
              nextTubes[from] =
                  List<int>.from(queue.removeAt(0), growable: true);
            }
          }

          final nextNodeBase = JokerSearchNode(
            tubes: nextTubes,
            mountainFillUnits: current.mountainFillUnits,
            moves: [...current.moves, '$from->$to'],
            refillQueues: nextRefillQueues,
          );

          final stateId = nextNodeBase.stateId(activeIndexes);
          if (!visited.add(stateId)) continue;

          pq.add(
            JokerSearchNode(
              tubes: nextNodeBase.tubes,
              mountainFillUnits: nextNodeBase.mountainFillUnits,
              moves: nextNodeBase.moves,
              refillQueues: nextNodeBase.refillQueues,
              priority: computePriority(nextNodeBase),
            ),
          );
        }

        if (!_hasMountainObjective) continue;
        if (current.mountainFillUnits >= targetMountainCapacity) continue;
        if (lastMove == '$from->mountain') continue;

        final mountainCount = _mountainPourCountInSimulation(
          current.tubes,
          from,
          current.mountainFillUnits,
        );

        if (mountainCount <= 0) continue;

        final nextTubes = cloneBoardState(current.tubes);
        for (int i = 0; i < mountainCount; i++) {
          nextTubes[from].removeLast();
        }

        final nextRefillQueues = _cloneRefillQueuesMap(current.refillQueues);
        final nextMountainFillUnits = current.mountainFillUnits + mountainCount;

        if (nextTubes[from].isEmpty) {
          final queue = nextRefillQueues[from];
          final refillStopped = targetMountainCapacity > 0 &&
              stopWhenMountainFull &&
              nextMountainFillUnits >= targetMountainCapacity;
          if (!refillStopped && queue != null && queue.isNotEmpty) {
            nextTubes[from] = List<int>.from(queue.removeAt(0), growable: true);
          }
        }

        final nextNodeBase = JokerSearchNode(
          tubes: nextTubes,
          mountainFillUnits: nextMountainFillUnits,
          moves: [...current.moves, '$from->mountain'],
          refillQueues: nextRefillQueues,
        );

        final stateId = nextNodeBase.stateId(activeIndexes);
        if (!visited.add(stateId)) continue;

        pq.add(
          JokerSearchNode(
            tubes: nextNodeBase.tubes,
            mountainFillUnits: nextNodeBase.mountainFillUnits,
            moves: nextNodeBase.moves,
            refillQueues: nextNodeBase.refillQueues,
            priority: computePriority(nextNodeBase),
          ),
        );
      }
    }

    if (iterations >= maxIterations) {
      debugPrint(
        '[JOKER] limit reached | iterations=$iterations visited=${visited.length} pq=${pq.length}',
      );
    }

    return null;
  }

  Future<List<String>?> _findJokerSolutionWithStages() async {
    final limits = _jokerSearchLimitsForCurrentState();

    for (int i = 0; i < limits.length; i++) {
      final limit = limits[i];
      final solution = await Future<List<String>?>(() {
        return findSolution(maxIterations: limit);
      });

      if (solution != null) {
        return solution;
      }

      if (i < limits.length - 1 && mounted) {
        await Future.delayed(const Duration(milliseconds: 90));
      }
    }

    return null;
  }

  Future<void> _useJokerWithEconomy() async {
    if (_jokerBusy || _activePlans.isNotEmpty || _gameWon) return;

    await _playClick();
    await _vibrateTap();

    if (_showTutorial) {
      showBottomHint('Önce öğreticiyi tamamla');
      return;
    }

    setState(() {
      _jokerBusy = true;
    });

    try {
      var jokerGranted = false;
      if (_canBuyJoker) {
        spendCoins(_jokerCost);
        jokerGranted = true;
      } else {
        jokerGranted = await _showRewardedJokerAdGate();
      }

      if (!jokerGranted) return;

      while (mounted) {
        final solution = await _findJokerSolutionWithStages();

        if (solution != null && solution.isNotEmpty) {
          final firstMove = solution.first;

          if (firstMove.endsWith('->mountain')) {
            final from = int.parse(firstMove.split('->').first);
            if (_selected != from && mounted) {
              setState(() {
                _selected = from;
              });
            }
            await _startPourToMountain(from);
          } else {
            final parts = firstMove.split('->');
            if (parts.length != 2) {
              _vibrateLight();
              return;
            }

            final from = int.parse(parts[0]);
            final to = int.parse(parts[1]);
            await _startPour(from, to);
          }
          return;
        }

        if (_history.isNotEmpty) {
          await _undo();
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        }

        _vibrateLight();
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _jokerBusy = false;
        });
      }
    }
  }

  void spendCoins(int amount) {
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

  void showBottomHint(String text) {
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

  Widget _buildJokerWorkingOverlay() {
    final accent = _theme.accentColor;
    final secondary = Color.lerp(accent, Colors.white, 0.18) ?? accent;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 92,
      right: 92,
      bottom: bottomPad + 30,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.96, end: 1.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                height: 52,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF12081F).withValues(alpha: 0.92),
                      _theme.bgDark.withValues(alpha: 0.84),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.30),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 18,
                      spreadRadius: 1.0,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.26),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(secondary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Joker çalışıyor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: secondary,
                        boxShadow: [
                          BoxShadow(
                            color: secondary.withValues(alpha: 0.65),
                            blurRadius: 8,
                            spreadRadius: 0.4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  (int, int)? findTutorialMove() {
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
        if (canPourBoard(_tubes, from, to, cap: _tubeCapacityIn(_tubes, to)) &&
            _tubes[to].isEmpty) {
          return (from, to);
        }
      }
    }

    for (final from in preferredSources) {
      if (_tubes[from].isEmpty) continue;
      for (final to in allTargets) {
        if (from == to) continue;
        if (canPourBoard(_tubes, from, to, cap: _tubeCapacityIn(_tubes, to)) &&
            _tubes[to].isEmpty) {
          return (from, to);
        }
      }
    }

    for (final from in preferredSources) {
      if (_tubes[from].isEmpty) continue;
      for (final to in lowerTargets) {
        if (from == to) continue;
        if (canPourBoard(_tubes, from, to, cap: _tubeCapacityIn(_tubes, to))) {
          return (from, to);
        }
      }
    }

    for (final from in preferredSources) {
      if (_tubes[from].isEmpty) continue;
      for (final to in allTargets) {
        if (from == to) continue;
        if (canPourBoard(_tubes, from, to, cap: _tubeCapacityIn(_tubes, to))) {
          return (from, to);
        }
      }
    }

    return null;
  }

  Future<void> maybeShowTutorial() async {
    if (!mounted) return;
    if (_showTutorial) {
      setState(() {
        _showTutorial = false;
        _tutorialStepIndex = 0;
        _tutorialFromIdx = null;
        _tutorialToIdx = null;
      });
    }
    return;
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
    if (!canPourBoard(_tubes, from, to, cap: _tubeCapacityIn(_tubes, to))) {
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
    if (!isLavaColorIndex(topColor)) {
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

    final plan = TransferPlan(
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
      runtimeRefillQueues: _cloneRefillQueuesMap(_runtimeRefillQueues),
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
              .add(VisualLayer(colorIdx: colorIdx, volume: count.toDouble()));
        }
        _mountainFillUnits += count;
      });
    });
    _persistLevelState();
    unawaited(_persistUndoHistoryState());

    // Su sesi: tüp hedefe varıp yatmaya başladığı anda başlasın,
    // tamamen ayağa kalktığı anda kesilsin. Böylece ses, görsel döküm
    // animasyonunun tamamına yayılır ve kısa kalmaz.
    final waterStartMs = (kPourDuration.inMilliseconds * 0.320).round();
    final waterStopMs = (kPourDuration.inMilliseconds * 0.978).round();
    int? waterToken;

    Future.delayed(Duration(milliseconds: waterStartMs), () async {
      if (!mounted || !_activePlans.contains(plan)) return;
      waterToken = await SfxService.startWater();
    });

    Future.delayed(Duration(milliseconds: waterStopMs), () async {
      if (!mounted || !_activePlans.contains(plan)) return;
      await SfxService.stopWater(waterToken);
      waterToken = null;
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
          _loopCompletedVolcano = widget.mapNumber == 3;
        }
      });
      _persistLevelState();

      if (didWin && _activePlans.isEmpty) {
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
        // Eruption animasyonunun (~3.5sn) bitmesini bekle
        Future.delayed(const Duration(milliseconds: 4500), () {
          if (mounted) _showWinDialog();
        });
      }

      _drainQueue();
    });
  }

  Future<void> _startPour(int from, int to) async {
    if (!canPourBoard(_tubes, from, to, cap: _tubeCapacityIn(_tubes, to))) {
      _vibrateLight();
      return;
    }

    final count =
        pourCountBoard(_tubes, from, to, cap: _tubeCapacityIn(_tubes, to));
    if (count <= 0) {
      _vibrateLight();
      return;
    }

    final plan = TransferPlan(
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
      runtimeRefillQueues: _cloneRefillQueuesMap(_runtimeRefillQueues),
    ));

    // Mantık durumunu hemen güncelle (animasyon gösterimi snapshot tabanlı)
    doPourBoard(_tubes, from, to, cap: _tubeCapacityIn(_tubes, to));

    setState(() {
      _selected = null;
      _activePlans.add(plan);
    });
    _persistLevelState();
    unawaited(_persistUndoHistoryState());

    // Su sesi: tüp hedefe varıp yatmaya başladığı anda başlasın,
    // tamamen ayağa kalktığı anda kesilsin. Böylece ses, görsel döküm
    // animasyonunun tamamına yayılır ve kısa kalmaz.
    final waterStartMs = (kPourDuration.inMilliseconds * 0.320).round();
    final waterStopMs = (kPourDuration.inMilliseconds * 0.978).round();
    int? waterToken;

    Future.delayed(Duration(milliseconds: waterStartMs), () async {
      if (!mounted || !_activePlans.contains(plan)) return;
      waterToken = await SfxService.startWater();
    });

    Future.delayed(Duration(milliseconds: waterStopMs), () async {
      if (!mounted || !_activePlans.contains(plan)) return;
      await SfxService.stopWater(waterToken);
      waterToken = null;
    });

    // Animasyon biter bitmez planı kaldır
    Future.delayed(kPourDuration, () {
      if (!mounted) return;

      _tryRefillSourceTube(from);
      _tryRefillSourceTube(to);

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
          _loopCompletedVolcano = widget.mapNumber == 3;
        }
      });
      _persistLevelState();

      if (didWin) {
        // Tüm paralel akışlar bitene kadar kutlamayı ve win dialog'u bekle
        if (_activePlans.isEmpty) {
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
          // Map 3'te eruption animasyonunu bekle, diğerlerinde kısa gecikme
          final winDelay = widget.mapNumber == 3
              ? const Duration(milliseconds: 4500)
              : const Duration(milliseconds: 2100);
          Future.delayed(winDelay, () {
            if (mounted) _showWinDialog();
          });
        }
        // Eğer başka aktif plan varsa, o planın kendi future'ı bitince
        // _activePlans.isEmpty kontrolüne girecek ve oradan tetikleyecek.
      } else {
        // Normal tamamlama — sadece yeni dolan şişeler
        _triggerDoneCelebration(newlyDone);
        // Kuyruktaki komutları işle
        _drainQueue();
      }
    });
  }

  Future<void> _undo() async {
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
      _runtimeRefillQueues = _cloneRefillQueuesMap(last.runtimeRefillQueues);
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
    final waterToken = await SfxService.startWater();

    await Future.delayed(const Duration(milliseconds: 700));

    await SfxService.stopWater(waterToken);
    if (!mounted) return;
    setState(() {
      _undoSloshingTubes.remove(last.fromIdx);
      _undoSloshingTubes.remove(last.toIdx);
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
    if (_isPopping) return; // Çift pop koruması
    _isPopping = true;

    // Durumu kaydet / temizle
    if (_isDailyMode) {
      if (completed) {
        await DailyPuzzleProgress.clearInProgressState();
        await _clearRefillState();
      } else {
        await _persistLevelState();
      }
    } else {
      if (completed) {
        await PlayerProgress.clearInProgressLevelState(
            widget.mapNumber, widget.level);
        await _clearRefillState();
      } else {
        await _persistLevelState();
      }
    }

    if (!mounted) return;

    // Her zaman pop ile mevcut MapPage'e dön — asla yeni MapPage oluşturma.
    Navigator.of(context).pop(
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
        onPopInvokedWithResult: (didPop, __) {
          // didPop true ise zaten pop gerçekleşti (Navigator.pop çağrısından),
          // tekrar çağırmaya gerek yok — çift pop önlenir.
          if (didPop) return;
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
              // Sıvı animasyonu — ekranın tam altına hizalı (butonların arkasında)
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
                                : (isLavaColorIndex(
                                        _mountainLayers.last.colorIdx)
                                    ? kLavaOrange
                                    : solidColorForIndex(
                                        _mountainLayers.last.colorIdx)),
                            glow: false,
                            onTap: _handleMountainTap,
                            layers: List<VisualLayer>.from(
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
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: LayoutBuilder(
                          builder: (context, stageConstraints) {
                            final adaptiveStageLayout =
                                _adaptiveStageLayoutFor(stageConstraints);
                            return Align(
                              alignment: Alignment.topCenter,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: adaptiveStageLayout.width,
                                  height: adaptiveStageLayout.height,
                                  child: _TubeStage(
                                    mapNumber: widget.mapNumber,
                                    stageLayout: adaptiveStageLayout,
                                    tubes: _tubes,
                                    selected: _selected,
                                    activePlans: _activePlans,
                                    onTap: _handleTap,
                                    lockedAdTubeIndex: _lockedAdTubeIndex,
                                    showLockedAdTube: _showLockedAdTube,
                                    celebratingDoneTubes: _celebratingDoneTubes,
                                    gameWon: _gameWon,
                                    undoSloshingTubes: _undoSloshingTubes,
                                    tutorialActive: false,
                                    tutorialStepIndex: 0,
                                    tutorialFromIdx: null,
                                    tutorialToIdx: null,
                                    blindMode: _blindModeEnabled,
                                    visibleLayerCounts: _visibleLayerCounts,
                                    blindRevealFlashTicks:
                                        _blindRevealFlashTicks,
                                    tubeStyles: {
                                      for (int i = 0; i < _tubes.length; i++)
                                        i: _tubeStyleForIndex(i),
                                    },
                                    tubeCapacities: {
                                      for (int i = 0; i < _tubes.length; i++)
                                        i: _tubeCapacityIn(_tubes, i),
                                    },
                                    onMountainTap: _handleMountainTap,
                                    mountainFillPercent: _mountainFillPercent,
                                    mountainLayers: List<VisualLayer>.from(
                                      _mountainLayers.map((l) => l.copyWith()),
                                    ),
                                    mountainCapacity: _mountainCapacity,
                                    sourceRefillTubeIndexes: {
                                      ..._activeRefillTubeIndexes,
                                    },
                                    mountainReservoirKey: _mountainReservoirKey,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Alan rezervasyonu — BottomBar yüksekliği kadar boşluk bırakır,
                    // görünmez; asıl butonlar PNG'nin üstündeki Positioned'da.
                    IgnorePointer(
                      child: Opacity(
                        opacity: 0.0,
                        child: _buildBottomBar(),
                      ),
                    ),
                  ],
                ),
              ),
              // Dağ PNG'si — TubeStage ve akış animasyonunun ÜSTÜNDE,
              // böylece akış dağın arkasından geliyor gibi görünür.
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
              // BottomBar PNG'nin ÜSTÜNDE — butonlar her zaman erişilebilir
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: _buildBottomBar(),
                ),
              ),
              if (_jokerBusy) _buildJokerWorkingOverlay(),
            ],
          ),
        ));
  }

  Widget buildTutorialOverlay() {
    final stepIndex =
        _tutorialStepIndex.clamp(0, _tutorialSteps.length - 1).toInt();
    final step = _tutorialSteps[stepIndex];
    final bool isFinalStep = stepIndex == _tutorialSteps.length - 1;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: 0,
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
                                fontSize: 13,
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

  Widget _buildBottomBar() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 110 + bottomPad,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: bottomPad + 12,
        top: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sol — Geri Alma
          _UndoButton(
            canUndo: _history.isNotEmpty && _activePlans.isEmpty && !_gameWon,
            accentColor: _theme.accentColor,
            onTap: _undo,
          ),
          // Sağ — Joker
          _JokerButton(
            enabled: !_jokerBusy && _activePlans.isEmpty && !_gameWon,
            busy: _jokerBusy,
            accentColor: _theme.accentColor,
            canBuy: _canBuyJoker,
            cost: _jokerCost,
            onTap: _useJokerWithEconomy,
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

class _HexagonPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  const _HexagonPainter({
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(_HexagonPainter old) =>
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth;
}

Path _hexPath(Size size) {
  final cx = size.width / 2;
  final cy = size.height / 2;
  final r = min(size.width, size.height) / 2;
  final path = Path();
  for (int i = 0; i < 6; i++) {
    final angle = (pi / 6) + (i * pi / 3);
    final x = cx + r * cos(angle);
    final y = cy + r * sin(angle);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  path.close();
  return path;
}

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
    final text = busy ? '...' : (canBuy ? '$cost' : 'AD');
    const double size = 78.0;
    final color = enabled ? accentColor : Colors.white.withValues(alpha: 0.45);
    final fillColor = enabled
        ? accentColor.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = enabled
        ? accentColor.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.18);

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.38,
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _HexagonPainter(
              fillColor: fillColor,
              borderColor: borderColor,
              borderWidth: 1.6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_fix_high_rounded, size: 24, color: color),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
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
    const double size = 78.0;
    final color = canUndo ? accentColor : Colors.white.withValues(alpha: 0.45);
    final fillColor = canUndo
        ? accentColor.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.06);
    final borderColor = canUndo
        ? accentColor.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.18);

    return AnimatedOpacity(
      opacity: canUndo ? 1.0 : 0.38,
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        onTap: canUndo ? onTap : null,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _HexagonPainter(
              fillColor: fillColor,
              borderColor: borderColor,
              borderWidth: 1.6,
            ),
            child: Center(
              child: Icon(Icons.undo_rounded, color: color, size: 28),
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
  final List<TransferPlan> activePlans;
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
  final List<VisualLayer> mountainLayers;
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
    final globalPos = box.localToGlobal(localAnchor);
    final stageTransform = stageBox.getTransformTo(null);
    stageTransform.invert();
    return MatrixUtils.transformPoint(stageTransform, globalPos);
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
      mountainBox.size.height * 0.10 - 60.0, // yukarı offset (+ = yukari)
    );

    // Mountain widget stageBox'in descendant'i degil (ayri Stack child).
    // Global koordinati alip stageBox'in global transform'unun tersini uygulayarak
    // stage-local koordinata donusturuyoruz. Bu FittedBox scale'ini de hesaba katar.
    final globalMouth = mountainBox.localToGlobal(localMouth);
    final stageTransform = stageBox.getTransformTo(null);
    stageTransform.invert();
    final stageLocal = MatrixUtils.transformPoint(stageTransform, globalMouth);
    return stageLocal;
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

    final globalSurface = mountainBox.localToGlobal(localSurface);
    final stageTransform = stageBox.getTransformTo(null);
    stageTransform.invert();
    final stageLocal =
        MatrixUtils.transformPoint(stageTransform, globalSurface);
    return stageLocal;
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

    // ancestor parametresiyle stage lokal koordinatlarına dönüştür.
    // Eski yöntem (globalToGlobal farkı) FittedBox scale ile uyuşmuyordu.
    return box.localToGlobal(localAnchor, ancestor: stageBox);
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
        widget.activePlans.cast<TransferPlan?>().firstWhere(
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
          const pPourEnd = 0.885;
          const vHeadEnd =
              0.642; // _FlyingTube: _pTiltEnd(0.422) + head inişi(0.22)

          // Dolum, akış çizgisinin ucu gerçekten sıvı yüzeyine ulaştığında başlar ve pPourEnd'de tamamlanır.
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
          // Blind modda rengi gizlemek için -1 sentinel kullanıyoruz.
          // _buildLayers() -1'i gri (gizli) olarak çizer.
          // incomingVolume her iki modda da geçiliyor — smooth sıvı yükselişi için.
          return _TubeWidget(
            tube: plan.toSnapshot,
            isSelected: false,
            incomingColorIdx: plan.colorIdx,
            incomingVolume: incoming,
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
            // Sorun 3b düzeltmesi: Açık tüpün gerçek görünür katman sayısını
            // FlyingTube'a geç. Böylece akış animasyonu sırasında tüp
            // snapshot'a göre doğru sayıda açık katmanla gösterilir.
            visibleLayerCount: widget.blindMode
                ? (plan.fromIdx < widget.visibleLayerCounts.length
                    ? widget.visibleLayerCounts[plan.fromIdx]
                    : (plan.fromSnapshot.isEmpty ? 0 : 1))
                : plan.fromSnapshot.length,
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
    final color = isLavaColorIndex(widget.colorIdx)
        ? kLavaOrange
        : solidColorForIndex(widget.colorIdx);
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
  final TransferPlan plan;
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

  static const double _pMoveEnd = 0.320;
  static const double _pTiltEnd = 0.422;
  static const double _pPourEnd = 0.885;
  static const double _pUprightEnd = 0.978;

  // Uçan şişeyi hedefin üstünde biraz daha yukarıda tut.
  // İstersen 28 → 36 → 44 diye deneyebilirsin.
  static const double _extraHoverLift = 100.0;

  double _liquidTilt = 0.0;

  // fromPos ilk okunduğunda sabitlenir — böylece animasyon boyunca
  // tüpün layout pozisyonu değişse bile (isSelected → false) ışınlanma olmaz.
  Offset? _cachedFromPos;

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
    // fromPos'u ilk geçerli okumada sabitle.
    // _selected = null yapıldıktan sonra tüp layout pozisyonu değişebilir
    // (isSelected: false → liftY=0), bu da her frame'de farklı fromPos
    // okumaya ve "ışınlanma" etkisine yol açar.
    _cachedFromPos ??= widget.getPos(widget.plan.fromIdx);
    final fromPos = _cachedFromPos;

    final targetSurface = widget.plan.isMountainTarget
        ? widget.getMountainSurface(widget.plan.toSnapshot.length.toDouble())
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

// Seçili tüp sahnede -15 px yukarı kalkmış görünüyor.
// FlyingTube da aynı kalkık pozisyondan başlamalı.
    final liftedFromPos = fromPos.translate(0, -15.0);
    // Mountain hedefi için extra hover kaldirmiyoruz — volkan agzi zaten
    // ekranin altinda, tubu aginzin tam ustune getirmek istiyoruz.
    final hoverLift = widget.plan.isMountainTarget ? 0.0 : _extraHoverLift;

    // Mountain widget ekranin tamamini kapliyor ama _TubeStage daha dar ve
    // ortali. Bu yuzden mountain agzinin global-minus-stage x koordinati
    // stage disina tasabiliyor. Mountain icin hedefin x'ini tup merkezine
    // sabitliyoruz; tup sadece asagi inip egilerek dokuyor.
    // Mountain koordinatlari artik getTransformTo ile duzgun hesaplaniyor,
    // ekstra override gerekmiyor.
    final effectiveTargetMouth = targetMouthEntry;

    final targetLip = effectiveTargetMouth.translate(0, -hoverLift);

    final fromMidX = liftedFromPos.dx + (kWidgetW / 2);
    final tiltSign = fromMidX <= targetLip.dx ? 1.0 : -1.0;

    final mouthLocal = _tubeMouthCenterLocal();
    final anchorLocal = Offset(kWidgetW / 2, kBodyBotY + kTR);

    // Şişe hedefe giderken ara bir "snap" noktası üretmesin diye,
    // döküm konumunu builder içinde tekrar tekrar değiştirmiyoruz.
    // Hedef şişenin ağzına, sabit bir tilt ile TEK bir top-left hesaplayıp
    // tüm hareketi o noktaya yapıyoruz.
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
        // 1) vStreamStart → vHeadEnd : akış ucu hedef sıvı yüzeyine iner.
        // 2) vHeadEnd → vTailStart   : hedef sıvı yavaşça yükselirken akış sürer.
        // 3) vTailStart → vTailEnd   : şişe dikleşmeden önce çizgi hızlıca kesilir.
        const vHeadEnd = vStreamStart +
            0.22; // akış ucunun aşağı inişi bilinçli olarak yavaş
        const vTailStart =
            _pPourEnd - 0.035; // çizgi, dönüş başlamadan kesilmeye başlasın
        const vTailEnd =
            _pPourEnd; // tüp dikleşirken ekranda akış çizgisi kalmasın

        // Hedef sıvı yüzeyi, kaynak boşalma hızına değil hedef tüpte görünen
        // dolum hızına bağlı yükselir. Böylece akış çizgisi yukarı kaçmaz.
        final targetFillProgress = v <= vHeadEnd
            ? 0.0
            : Curves.easeInOutCubic.transform(
                ((v - vHeadEnd) / max(0.0001, _pPourEnd - vHeadEnd))
                    .clamp(0.0, 1.0),
              );

        // Anlık hedef sıvı yüzeyi: döküm ilerledikçe, hedef dolumla senkron yükselir.
        final currentToVolume = (widget.plan.toSnapshot.length +
                widget.plan.count * targetFillProgress)
            .clamp(0.0, widget.targetCapacity.toDouble());
        final rawMountainSurface = widget.plan.isMountainTarget
            ? widget.getMountainSurface(
                (widget.plan.mountainFillBefore) +
                    widget.plan.count * targetFillProgress,
              )
            : null;
        // Mountain surface x'ini tup merkeziyle hizala (mountain widget ekrandan
        // genis, stage koordinatlarinda x kayabiliyor).
        final dynamicTargetSurface = widget.plan.isMountainTarget
            ? (rawMountainSurface != null
                ? Offset(effectiveTargetMouth.dx, rawMountainSurface.dy)
                : targetSurface)
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

        final visibleDuringPour = widget.blindMode
            ? widget.visibleLayerCount
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
                      color: isLavaColorIndex(widget.plan.colorIdx)
                          ? kLavaOrange
                          : solidColorForIndex(widget.plan.colorIdx),
                      start: globalStreamStart,
                      end: dynamicTargetSurface,
                      mouthEntry: effectiveTargetMouth,
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

  bool get _isLava =>
      color == kLavaOrange || color == kLavaRed || color == kLavaCore;

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
    if (isLavaColorIndex(widget.incomingColorIdx ?? -1)) return true;
    for (final c in widget.tube) {
      if (isLavaColorIndex(c)) return true;
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
        oldDelegate.highlight != highlight;
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
  final double lavaTime; // 0→1 döngüsel, AnimationController'dan
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
    this.lavaTime = 0.0,
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
  // blindMode=true  → gizli katmanlar ayrı tutulur; açılmış ardışık aynı renk birleşir
  List<VisualLayer> _buildLayers() {
    final layers = <VisualLayer>[];

    if (blindMode) {
      // visibleLayerCount: en üstteki kaç katmanın görünür olduğunu söyler.
      // Alttaki (totalCount - visibleLayerCount) adet katman gizlidir.
      final totalCount = tube.length;
      final hiddenCount = max(0, totalCount - visibleLayerCount);

      for (int i = 0; i < tube.length; i++) {
        final c = tube[i];
        final isVisible = i >= hiddenCount;

        // Görünür bir katman, bir önceki katman da görünür ve aynı renk ise birleştir.
        // Gizli katmanlar hiçbir zaman birleştirilmez (her biri ayrı '?' gösterir).
        if (isVisible &&
            layers.isNotEmpty &&
            layers.last.colorIdx == c &&
            (layers.length - 1) >= hiddenCount) {
          layers[layers.length - 1] =
              layers.last.copyWith(volume: layers.last.volume + 1);
        } else {
          layers.add(VisualLayer(colorIdx: c, volume: 1));
        }
      }
    } else {
      for (final c in tube) {
        if (layers.isNotEmpty && layers.last.colorIdx == c) {
          final l = layers.removeLast();
          layers.add(l.copyWith(volume: l.volume + 1));
        } else {
          layers.add(VisualLayer(colorIdx: c, volume: 1));
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
        // Blind modda da incoming sıvı gerçek rengiyle çizilir.
        // paint() içinde incoming layer her zaman listenin sonuna ekleniyor;
        // i >= hiddenOriginalCount olduğu için isHidden=false → renkli görünür.
        if (layers.isNotEmpty && layers.last.colorIdx == incomingColorIdx) {
          final l = layers.removeLast();
          layers.add(l.copyWith(volume: l.volume + add));
        } else {
          layers.add(VisualLayer(colorIdx: incomingColorIdx!, volume: add));
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
      // blindBaseLayerCount: orijinal tube eleman sayısı (görünürlük hesabı için)
      final blindBaseLayerCount = blindMode ? tube.length : layers.length;
      final safeVisibleCount =
          visibleLayerCount.clamp(0, blindBaseLayerCount).toInt();
      // Gizli orijinal katman sayısı
      final hiddenOriginalCount =
          blindMode ? max(0, blindBaseLayerCount - safeVisibleCount) : 0;
      // _buildLayers() sonrasında: layers dizisinde gizli katmanlar hep başta,
      // görünür katmanlar sonda (birleştirilmiş olabilir). Gizli orijinal katmanlar
      // yoğunlaştırılmadan (1 birim = 1 eleman) oluştuğu için layers'daki
      // ilk `hiddenOriginalCount` kadar layer gizlidir.
      // Ayrıca colorIdx = -1 sentinel, animasyon sırasında eklenen
      // gelen (incoming) sıvı katmanlarını temsil eder — bunlar da gizli/gri çizilir.
      final isHidden =
          blindMode && (i < hiddenOriginalCount || layer.colorIdx < 0);

      final fill = isHidden
          ? BlindLayerUiHelper.hiddenFillColor
          : visibleLiquidFillForIndex(safeIdx);
      final isLavaLayer = !isHidden && isLavaColorIndex(safeIdx);
      final highlightAlpha =
          liquidHighlightAlphaFor(safeIdx, isHidden: isHidden);
      final shadowAlpha = liquidShadowAlphaFor(safeIdx, isHidden: isHidden);

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
                Colors.white.withValues(alpha: highlightAlpha),
                Colors.transparent,
                Colors.black.withValues(alpha: shadowAlpha),
              ],
              stops: const [0.0, 0.35, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(liquidRect),
        );
      }

      final revealLayerIndex = BlindLayerUiHelper.computeRevealLayerIndex(
        blindMode: blindMode,
        safeVisibleCount: safeVisibleCount,
        blindBaseLayerCount: blindBaseLayerCount,
        renderedLayerCount: layers.length,
      );
      final isRevealLayer = blindMode && !isHidden && i == revealLayerIndex;

      if (isRevealLayer) {
        BlindLayerUiHelper.paintRevealGlow(
          canvas: canvas,
          bandPath: bandPath,
          revealGlowTick: revealGlowTick,
        );
      }

      if (isHidden) {
        BlindLayerUiHelper.paintHiddenLayerDecorations(
          canvas: canvas,
          layerIndex: i,
          renderedLayerCount: layers.length,
          vBot: vBot,
          vTop: vTop,
          il: _il,
          iw: _iw,
          ir: _ir,
          tilt: tilt,
          slosh: slosh,
          surface: (volume, tiltValue, sloshValue) {
            final s = _surface(volume, tiltValue, sloshValue);
            return BlindLayerSurfacePoint(
              lY: s.lY,
              cY: s.cY,
              rY: s.rY,
            );
          },
        );
      }

      accum = vTop;
    }

    // Üst yüzey parlaması
    if (totalVol > 0.0001) {
      final topColorIdx = layers.isNotEmpty ? layers.last.colorIdx : -1;
      final topIsLava = isLavaColorIndex(topColorIdx);
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
      final burstIsLava = isLavaColorIndex(topColorIdx) ||
          (incomingColorIdx != null && isLavaColorIndex(incomingColorIdx!));

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
