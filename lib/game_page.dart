import 'dart:collection';
import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map_theme.dart';
import 'puzzle_presets.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────
// OYUN SABİTLERİ
// ─────────────────────────────────────────────

const int kCap = 4;
const int kNColors = 8;
const int kEmpty = 2;
const String kTubeSvgAsset = 'assets/likora/test_tube.svg';

// Widget boyutları – SVG oranına göre ayarlandı (84.4 x 182 mm → 60 x 130 px)
const double kTW = 72.0;
const double kTH = 150.0;

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
double get kLiquidTopY => kCapBotY + 22.0;
double get kMouthEntryY => kCapBotY + 4.0;
double get kLiquidBotY => kBodyBotY + kTR - 12;

// Widget toplam yüksekliği
// Alt U'nun en altı: SVG'de y=18197.8 → kTH
double get kWidgetH => kTH;
double get kWidgetW => kTW;

const double kTubeGap = 20.0;

class _StageMetrics {
  final double width;
  final double height;

  const _StageMetrics({required this.width, required this.height});
}

_StageMetrics _measureStageLayout(StageLayout layout) {
  switch (layout.mode) {
    case StageLayoutMode.manual:
      return _StageMetrics(
        width: layout.canvasWidth ?? ((kWidgetW * 4) + (kTubeGap * 3) + 24.0),
        height: layout.canvasHeight ?? ((kWidgetH * 3) + (kTubeGap * 2) + 28.0),
      );
    case StageLayoutMode.rows:
      final rowCount = layout.rows.isEmpty ? 1 : layout.rows.length;
      var maxCount = 1;
      for (final row in layout.rows) {
        if (row.length > maxCount) maxCount = row.length;
      }
      final width =
          (maxCount * kWidgetW) + ((maxCount - 1) * layout.tubeGap) + 24.0;
      final height = (rowCount * kWidgetH) +
          ((rowCount - 1) * layout.rowGap) +
          28.0 +
          layout.topOffset.abs();
      return _StageMetrics(width: width, height: height);
  }
}

const Duration kPourDuration = Duration(milliseconds: 1500);

const List<Map<String, dynamic>> kColors = [
  {'name': 'Gül Kırmızısı', 'fill': Color(0xFFE83060)},
  {'name': 'Elektrik Mavisi', 'fill': Color(0xFF2E7FFF)},
  {'name': 'Zümrüt Yeşili', 'fill': Color(0xFF26C26A)},
  {'name': 'Mor', 'fill': Color(0xFFAB47FF)},
  {'name': 'Ateş Turuncusu', 'fill': Color(0xFFFF6B1A)},
  {'name': 'Altın Sarısı', 'fill': Color(0xFFFFCC00)},
  {'name': 'Turkuaz', 'fill': Color(0xFF00C8D7)},
  {'name': 'Şeker Pembesi', 'fill': Color(0xFFFF4FA8)},
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

class GamePage extends StatefulWidget {
  final int level;
  final int mapNumber;
  final int difficulty;
  final int initialCoins;

  const GamePage({
    super.key,
    required this.level,
    required this.mapNumber,
    this.difficulty = 1,
    this.initialCoins = 0,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
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
  final List<({List<List<int>> tubes, int fromIdx, int toIdx})> _history = [];
  // Geri alma animasyonu — hangi tüpler sloshing yapıyor
  final Map<int, int> _undoSloshingTubes = {}; // tubeIdx → colorIdx

  static const int _jokerCost = 50;

  late int _coins;
  bool _jokerBusy = false;
  bool _adTubeUnlocked = false;
  final Map<String, List<(int, int)>> _solverSuccessCache = {};

  bool get _canBuyJoker => _coins >= _jokerCost;

  StageLayout get _stageLayout =>
      _preset?.layout ?? StageLayout.standardForTubeCount(_tubes.length);

  _StageMetrics get _stageMetrics => _measureStageLayout(_stageLayout);

  @override
  void initState() {
    super.initState();
    _theme = getMapTheme(widget.mapNumber);
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _coins = widget.initialCoins;
    _reset();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  bool get _showLockedAdTube => !_adTubeUnlocked;
  bool _isLockedAdTubeIndex(int idx) =>
      _showLockedAdTube && idx == _lockedAdTubeIndex;

  // Hangi tüpler şu an aktif animasyonda meşgul
  Set<int> get _busyTubes {
    final s = <int>{};
    for (final p in _activePlans) {
      s.add(p.fromIdx);
      s.add(p.toIdx);
    }
    return s;
  }

  void _reset() {
    _preset = PuzzlePresets.getOrNull(
      mapNumber: widget.mapNumber,
      levelId: widget.level,
    );

    final initialTubes = (_preset?.tubes ??
            _legacyGenerateTubes(
              level: widget.level,
              difficulty: widget.difficulty,
            ))
        .map((t) => List<int>.of(t, growable: true))
        .toList(growable: true);

    _tubes = initialTubes;
    _lockedAdTubeIndex = (_preset?.lockedAdTubeIndex ?? (_tubes.length - 1))
        .clamp(0, _tubes.length - 1);
    _activePlans.clear();
    _selected = null;
    _gameWon = false;
    _celebratingDoneTubes.clear();
    _commandQueue.clear();
    _history.clear();
    _undoSloshingTubes.clear();
    _adTubeUnlocked = false;
    setState(() {});
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
      playable.add(locked!);
    }

    return playable.join('|');
  }

  String _boardSignature(List<List<int>> tubes) {
    return _canonicalBoardSignature(
      tubes,
      includeUnlockedAdTube: _adTubeUnlocked,
    );
  }

  String _currentBoardSignature() {
    return _boardSignature(_tubes);
  }

  List<int> _completedTubeColorsOf(List<List<int>> tubes) {
    final colors = <int>[];
    for (int i = 0; i < tubes.length; i++) {
      if (!_adTubeUnlocked && i == _lockedAdTubeIndex) continue;
      final tube = tubes[i];
      if (isTubeDone(tube)) {
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
      if (isTubeDone(tubes[i])) count++;
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
    return canPour(tubes, from, to);
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
      if (isTubeDone(source)) continue;

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
          if (target.length + pourCount(tubes, from, to) == kCap) {
            score += 80;
          }
        }

        if (target.isEmpty) {
          score += 15;
        }

        final next = _cloneTubes(tubes);
        doPour(next, from, to);

        if (isTubeDone(next[to])) {
          score += 60;
        }
        if (isTubeDone(next[from])) {
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
      if (isGameDone(state)) {
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
        doPour(next, move.$1, move.$2);

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
    doPour(next, from, to);
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

    // TODO: Coin bilgisini kalıcı kayda yaz.
  }

  Future<bool> _showRewardedAdForJoker() async {
    // TODO: Gerçek rewarded reklam entegrasyonunu burada bağla.
    await Future.delayed(const Duration(milliseconds: 1200));
    return true;
  }

  Future<void> _useJokerWithEconomy() async {
    if (_jokerBusy || _activePlans.isNotEmpty || _gameWon) return;

    final decision = _findSmartJokerDecision();
    if (decision == null) {
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _jokerBusy = true;
    });

    try {
      bool allowed = false;

      if (_canBuyJoker) {
        _spendCoins(_jokerCost);
        allowed = true;
      } else {
        allowed = await _showRewardedAdForJoker();
      }

      if (!allowed) {
        HapticFeedback.lightImpact();
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

  Future<void> _handleTap(int idx) async {
    if (_isLockedAdTubeIndex(idx)) return;

    final busy = _busyTubes;

    // Seçim yok — kaynak seç
    if (_selected == null) {
      // Meşgul tüpü seçme
      if (busy.contains(idx)) return;
      if (_tubes[idx].isEmpty) return;
      setState(() => _selected = idx);
      return;
    }

    // Aynı tüpe tekrar dokunduysa seçimi kaldır
    if (_selected == idx) {
      setState(() => _selected = null);
      return;
    }

    final from = _selected!;
    final to = idx;
    setState(() => _selected = null);

    if (_isLockedAdTubeIndex(from) || _isLockedAdTubeIndex(to)) {
      HapticFeedback.lightImpact();
      return;
    }

    // İki tüp de serbest — hemen başlat
    if (!busy.contains(from) && !busy.contains(to)) {
      await _startPour(from, to);
      return;
    }

    // Herhangi biri meşgulse kuyruğa ekle
    _commandQueue.addLast((from, to));
  }

  Future<void> _startPour(int from, int to) async {
    if (!canPour(_tubes, from, to)) {
      HapticFeedback.lightImpact();
      return;
    }

    final count = pourCount(_tubes, from, to);
    if (count <= 0) {
      HapticFeedback.lightImpact();
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
      fromIdx: from,
      toIdx: to,
    ));

    // Mantık durumunu hemen güncelle (animasyon gösterimi snapshot tabanlı)
    doPour(_tubes, from, to);

    setState(() {
      _activePlans.add(plan);
    });

    HapticFeedback.mediumImpact();

    // Animasyon biter bitmez planı kaldır
    Future.delayed(kPourDuration, () {
      if (!mounted) return;

      final newlyDone = <int, int>{};
      for (final i in [from, to]) {
        if (!_isLockedAdTubeIndex(i) && isTubeDone(_tubes[i])) {
          newlyDone[i] = _tubes[i].first;
        }
      }
      final didWin = isGameDone(_tubes);

      setState(() {
        _activePlans.remove(plan);
        _gameWon = didWin;
      });

      if (didWin) {
        // Oyun bitti — son döküm görsel olarak tam bitmesini bekle, sonra tüm şişelerden aynı anda burst
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          final allDone = <int, int>{};
          for (int i = 0; i < _tubes.length; i++) {
            if (!_isLockedAdTubeIndex(i) && isTubeDone(_tubes[i])) {
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
      HapticFeedback.lightImpact();
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
      _selected = null;
      _gameWon = false;
      _commandQueue.clear();
      // Etkilenen tüplere slosh animasyonu ver
      _undoSloshingTubes[last.fromIdx] = fromColor;
      _undoSloshingTubes[last.toIdx] = toColor;
    });

    HapticFeedback.mediumImpact();

    // Slosh animasyonu bitince temizle
    Future.delayed(const Duration(milliseconds: 700), () {
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: Color.lerp(_theme.bgMid, Colors.black, 0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _theme.accentColor.withOpacity(0.28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tebrikler!',
                  style: TextStyle(
                    color: _theme.accentColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Seviyeyi geçtiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: _BottomActionBtn(
                    label: 'Harika',
                    color: _theme.accentColor.withOpacity(0.18),
                    borderColor: _theme.accentColor.withOpacity(0.45),
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

  void _completeLevel() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  void _lowerLevel() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.bgDark,
      body: Stack(
        children: [
          _AnimatedThemeBg(controller: _bgCtrl, theme: _theme),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: _stageMetrics.width,
                                    height: _stageMetrics.height,
                                    child: _TubeStage(
                                      tubes: _tubes,
                                      selected: _selected,
                                      activePlans: _activePlans,
                                      onTap: _handleTap,
                                      lockedAdTubeIndex: _lockedAdTubeIndex,
                                      showLockedAdTube: _showLockedAdTube,
                                      celebratingDoneTubes:
                                          _celebratingDoneTubes,
                                      gameWon: _gameWon,
                                      undoSloshingTubes: _undoSloshingTubes,
                                      layout: _stageLayout,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _LevelIconBtn(
                                  icon:
                                      Icons.keyboard_double_arrow_down_rounded,
                                  tooltip: 'Seviyeyi Düşür',
                                  color: Colors.white.withOpacity(0.10),
                                  borderColor: Colors.white.withOpacity(0.18),
                                  iconColor: Colors.white,
                                  onTap: _lowerLevel,
                                ),
                                const SizedBox(width: 20),
                                _LevelIconBtn(
                                  icon: Icons.keyboard_double_arrow_up_rounded,
                                  tooltip: 'Seviyeyi Geç',
                                  color: _theme.accentColor.withOpacity(0.18),
                                  borderColor:
                                      _theme.accentColor.withOpacity(0.45),
                                  iconColor: _theme.accentColor,
                                  onTap: _completeLevel,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 132,
            child: SafeArea(
              child: _JokerButton(
                enabled: !_gameWon && _activePlans.isEmpty && !_jokerBusy,
                busy: _jokerBusy,
                canBuy: _canBuyJoker,
                cost: _jokerCost,
                accentColor: _theme.accentColor,
                onTap: _useJokerWithEconomy,
              ),
            ),
          ),
          // Geri alma butonu — sağ alt köşe
          Positioned(
            right: 20,
            bottom: 62,
            child: SafeArea(
              child: _UndoButton(
                canUndo:
                    _history.isNotEmpty && _activePlans.isEmpty && !_gameWon,
                accentColor: _theme.accentColor,
                onTap: _undo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: SizedBox(
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
                  onTap: () => Navigator.pop(context),
                  child: Ink(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.14),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 92),
              child: Text(
                _theme.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _theme.primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  shadows: [
                    Shadow(
                      color: _theme.primaryColor.withOpacity(0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.toll_rounded,
                      color: _theme.accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  const _AnimatedThemeBg({required this.controller, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Gradyan taban
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.bgDark, theme.bgMid, theme.bgLight, theme.bgDark],
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
                theme.primaryColor.withOpacity(0.18)),
            _glow(w - 170 + cos(t * pi) * 20, 120 + sin(t * pi) * 18, 250,
                theme.secondaryColor.withOpacity(0.14)),
            _glow(-80 + sin(t * pi * 1.3) * 16, h - 200 + cos(t * pi) * 20, 260,
                theme.accentColor.withOpacity(0.12)),
            _glow(w - 140 + cos(t * pi * 1.2) * 18, h - 180 + sin(t * pi) * 22,
                230, theme.primaryColor.withOpacity(0.12)),
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
            gradient: RadialGradient(colors: [c, c.withOpacity(0)]),
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
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: canBuy
                    ? accentColor.withOpacity(0.60)
                    : Colors.white.withOpacity(0.24),
                width: 1.5,
              ),
              boxShadow: canBuy
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.22),
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
                        canBuy ? '$cost' : 'Reklam',
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
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: canUndo
                    ? accentColor.withOpacity(0.45)
                    : Colors.white.withOpacity(0.14),
                width: 1.4,
              ),
              boxShadow: canUndo
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.18),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                Icons.undo_rounded,
                color: canUndo ? accentColor : Colors.white.withOpacity(0.45),
                size: 24,
              ),
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
// SEVİYE İKON BUTONU
// ─────────────────────────────────────────────

class _LevelIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _LevelIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 26),
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

class _TubeStage extends StatefulWidget {
  final List<List<int>> tubes;
  final int? selected;
  final List<_TransferPlan> activePlans;
  final void Function(int) onTap;
  final int lockedAdTubeIndex;
  final bool showLockedAdTube;
  final Map<int, int> celebratingDoneTubes;
  final bool gameWon;
  final Map<int, int> undoSloshingTubes;
  final StageLayout layout;

  const _TubeStage({
    required this.tubes,
    required this.selected,
    required this.activePlans,
    required this.onTap,
    required this.lockedAdTubeIndex,
    required this.showLockedAdTube,
    required this.celebratingDoneTubes,
    required this.layout,
    this.gameWon = false,
    this.undoSloshingTubes = const {},
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

  Offset? _localPos(int idx) {
    final box = _keys[idx].currentContext?.findRenderObject() as RenderBox?;
    final stageBox = context.findRenderObject() as RenderBox?;
    if (box == null || stageBox == null) return null;

    return box.localToGlobal(Offset.zero) - stageBox.localToGlobal(Offset.zero);
  }

  Widget _tubeItem(int idx, {double topPadding = 0}) {
    final hiddenSources = widget.activePlans.map((p) => p.fromIdx).toSet();
    final isLockedAdTube =
        widget.showLockedAdTube && idx == widget.lockedAdTubeIndex;

    final activeTargetPlan =
        widget.activePlans.cast<_TransferPlan?>().firstWhere(
              (p) => p?.toIdx == idx,
              orElse: () => null,
            );

    final isTargetOfPlan = activeTargetPlan != null;
    final showSelected = widget.selected == idx && !isTargetOfPlan;

    Widget tubeView;
    if (isTargetOfPlan) {
      final plan = activeTargetPlan!;
      tubeView = TweenAnimationBuilder<double>(
        key: ValueKey('target_fill_${plan.fromIdx}_${plan.toIdx}'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: kPourDuration,
        curve: Curves.linear,
        builder: (context, timeline, _) {
          final contactThreshold =
              computeContactThreshold(plan.toSnapshot.length);

          const pMoveEnd = 0.44;
          const pTiltEnd = 0.58;
          const pPourEnd = 0.90;
          const pUprightEnd = 0.97;
          final vStreamStart = pMoveEnd + 0.93 * (pTiltEnd - pMoveEnd);
          final vContact =
              vStreamStart + contactThreshold * (pPourEnd - vStreamStart);

          final incomingPhase = timeline <= vContact
              ? 0.0
              : Curves.easeInOutCubic.transform(
                  ((timeline - vContact) / max(0.0001, pUprightEnd - vContact))
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
            incomingColorIdx: plan.colorIdx,
            incomingVolume: incoming,
            slosh: receiveSlosh,
            splash: receiveSplash,
            pourProgress: incomingPhase,
            bubbleBurst: receiveBubbleBurst,
            receiveFlow: receiveFlow,
          );
        },
      );
    } else if (widget.undoSloshingTubes.containsKey(idx)) {
      tubeView = TweenAnimationBuilder<double>(
        key: ValueKey('undo_slosh_$idx'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, _) {
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
          );
        },
      );
    } else {
      tubeView = _TubeWidget(
        tube: widget.tubes[idx],
        isSelected: showSelected,
        incomingColorIdx: null,
        incomingVolume: 0.0,
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: KeyedSubtree(
        key: _keys[idx],
        child: GestureDetector(
          onTap: () => widget.onTap(idx),
          child: Opacity(
            opacity: hiddenSources.contains(idx) ? 0.0 : 1.0,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: isLockedAdTube ? 0.30 : 1.0,
                  child: tubeView,
                ),
                if (isLockedAdTube)
                  Positioned(
                    right: -2,
                    bottom: 6,
                    child: IgnorePointer(
                      child:
                          _AdUnlockBadge(color: Colors.white.withOpacity(0.90)),
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
    );
  }

  Widget _row(List<int> indices,
      {double topPadding = 0, double tubeGap = kTubeGap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final idx in indices) ...[
          _tubeItem(idx, topPadding: topPadding),
          if (idx != indices.last) SizedBox(width: tubeGap),
        ],
      ],
    );
  }

  Widget _buildRowsLayout() {
    final effectiveLayout = widget.layout.mode == StageLayoutMode.rows
        ? widget.layout
        : StageLayout.standardForTubeCount(widget.tubes.length);
    final rows = effectiveLayout.rows
        .map((row) =>
            row.where((idx) => idx >= 0 && idx < widget.tubes.length).toList())
        .where((row) => row.isNotEmpty)
        .toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(top: max(0.0, effectiveLayout.topOffset)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              _row(
                rows[i],
                topPadding: i < effectiveLayout.rowTopPaddings.length
                    ? effectiveLayout.rowTopPaddings[i]
                    : 0,
                tubeGap: effectiveLayout.tubeGap,
              ),
              if (i != rows.length - 1)
                SizedBox(height: effectiveLayout.rowGap),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualLayout() {
    final width = widget.layout.canvasWidth ?? context.size?.width ?? 0;
    final height = widget.layout.canvasHeight ?? context.size?.height ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final pos in widget.layout.positions)
          if (pos.index >= 0 && pos.index < widget.tubes.length)
            Positioned(
              left: pos.x * max(0.0, width - kWidgetW),
              top: pos.y * max(0.0, height - kWidgetH),
              child: _tubeItem(pos.index),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: widget.layout.mode == StageLayoutMode.manual
              ? _buildManualLayout()
              : _buildRowsLayout(),
        ),
        for (final plan in widget.activePlans)
          _FlyingTube(
            plan: plan,
            getPos: _localPos,
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
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
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
                          color.withOpacity(0.55),
                          color.withOpacity(0.0),
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
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.95));

    // İç parlama (glowIntensity ile büyür)
    if (glowIntensity > 0.01) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.35 * glowIntensity)
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
        ..color = Colors.white.withOpacity(0.25 + 0.35 * glowIntensity)
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
  final Offset? Function(int) getPos;

  const _FlyingTube({super.key, required this.plan, required this.getPos});

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

  double _targetTiltForRemaining(double remainingUnits) {
    // 90 dereceye yakın sabit döküm: şişe hedef tüpün tam üstüne gelir
    // ve akış mümkün olduğunca dik aşağı iner.
    return pi / 2;
  }

  Offset _mouthEdgeLocal({
    required double fromMidX,
  }) {
    // 90 derecelik dökümde akışı hedef tüpün tam üstüne hizalamak için
    // akış başlangıcını şişe ağzının merkezine yakın tutuyoruz.
    return Offset(kWidgetW / 2, kCapBotY + 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final rawFromPos = widget.getPos(widget.plan.fromIdx);
    final toPos = widget.getPos(widget.plan.toIdx);
    if (rawFromPos == null || toPos == null) return const SizedBox.shrink();

    final fromPos = rawFromPos.translate(0, -15.0);
    final fromMidX = fromPos.dx + kWidgetW / 2;
    final toMidX = toPos.dx + kWidgetW / 2;
    final tiltSign = fromMidX <= toMidX ? 1.0 : -1.0;

    final mouthLocal = Offset(kWidgetW / 2, kCapBotY + 1.0);
    final anchorLocal = Offset(kWidgetW / 2, kBodyBotY + kTR);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = _ctrl.value;

        final rawPourProgress = v >= _pTiltEnd && v < _pPourEnd
            ? _phase(v, _pTiltEnd, _pPourEnd)
            : (v >= _pPourEnd ? 1.0 : 0.0);

        // Döküm çok erken başlamasın: şişe neredeyse 90° konuma geldiğinde,
        // yaklaşık 70-75° bandını geçince akış açılsın.
        final angleProgress = v < _pMoveEnd
            ? 0.0
            : (v < _pTiltEnd
                ? _phase(v, _pMoveEnd, _pTiltEnd)
                : (v < _pPourEnd ? 1.0 : 1.0));
        const double pourStartAngleThreshold = 0.93;
        final delayedStreamOpen = angleProgress <= pourStartAngleThreshold
            ? 0.0
            : Curves.easeInOut.transform(
                ((angleProgress - pourStartAngleThreshold) /
                        (1.0 - pourStartAngleThreshold))
                    .clamp(0.0, 1.0),
              );
        final streamOpen = v >= _pPourEnd ? 1.0 : delayedStreamOpen;

        // Ortak helper — TubeStage ile tamamen senkron
        final contactThreshold =
            computeContactThreshold(widget.plan.toSnapshot.length);

        // streamOpen'ın başladığı v noktası (angle threshold geçilince)
        // _pMoveEnd → _pTiltEnd arası angle 0→1, threshold=0.93 → v_streamStart
        final vStreamStart =
            _pMoveEnd + 0.93 * (_pTiltEnd - _pMoveEnd); // ≈ 0.57
        // streamOpen=1 olduğu v noktası = _pPourEnd
        // Temas v'si: vStreamStart + contactThreshold*(pPourEnd - vStreamStart)
        final vContact =
            vStreamStart + contactThreshold * (_pPourEnd - vStreamStart);

// Akış çizgisi: v < vContact → uzar, v >= vContact → tam görünür.
        final lineProgress = v <= vStreamStart
            ? 0.0
            : (v >= vContact
                ? 1.0
                : Curves.easeOut.transform(
                    ((v - vStreamStart) / max(0.0001, vContact - vStreamStart))
                        .clamp(0.0, 1.0)));

// Dolum: temas anından (_vContact) akış bitişine (_pUprightEnd) kadar lineer.
        final fillProgress = v <= vContact
            ? 0.0
            : Curves.easeInOutCubic.transform(
                ((v - vContact) / max(0.0001, _pUprightEnd - vContact))
                    .clamp(0.0, 1.0),
              );

// Drain: akış başından (_pTiltEnd) bitimine (_pUprightEnd) kadar.
        final drainProgress = v <= _pTiltEnd
            ? 0.0
            : Curves.easeInOut.transform(
                ((v - _pTiltEnd) / max(0.0001, _pUprightEnd - _pTiltEnd))
                    .clamp(0.0, 1.0));

        final sourceDrainVolume = widget.plan.count * drainProgress;
        final remainingUnits =
            (widget.plan.fromSnapshot.length - sourceDrainVolume)
                .clamp(0.0, kCap.toDouble());

        final dynamicMaxTilt = _targetTiltForRemaining(remainingUnits);

        const double kPourGapY = 34.0;
        final targetMouth = Offset(toMidX, toPos.dy + kCapTopY - kPourGapY);

        final pourTopLeft = _tubeTopLeftToMatchMouth(
          targetMouth: targetMouth,
          mouthLocal: mouthLocal,
          anchorLocal: anchorLocal,
          angle: tiltSign * dynamicMaxTilt,
        );

        double cx;
        if (v < _pMoveEnd) {
          cx = fromPos.dx +
              (pourTopLeft.dx - fromPos.dx) *
                  _easeHeavy(_phase(v, 0.0, _pMoveEnd));
        } else if (v < _pUprightEnd) {
          cx = pourTopLeft.dx;
        } else {
          cx = pourTopLeft.dx +
              (fromPos.dx - pourTopLeft.dx) *
                  _easeHeavy(_phase(v, _pUprightEnd, 1.0));
        }

        double cy;
        if (v < _pMoveEnd) {
          cy = fromPos.dy +
              (pourTopLeft.dy - fromPos.dy) *
                  _easeHeavy(_phase(v, 0.0, _pMoveEnd));
        } else if (v < _pUprightEnd) {
          cy = pourTopLeft.dy;
        } else {
          cy = pourTopLeft.dy +
              (fromPos.dy - pourTopLeft.dy) *
                  _easeHeavy(_phase(v, _pUprightEnd, 1.0));
        }

        double bottleAngle = 0.0;
        if (v >= _pMoveEnd && v < _pTiltEnd) {
          bottleAngle = tiltSign *
              dynamicMaxTilt *
              _easeOutHeavy(_phase(v, _pMoveEnd, _pTiltEnd));
        } else if (v >= _pTiltEnd && v < _pPourEnd) {
          bottleAngle = tiltSign * dynamicMaxTilt;
        } else if (v >= _pPourEnd && v < _pUprightEnd) {
          bottleAngle = tiltSign *
              dynamicMaxTilt *
              (1.0 - _easeHeavy(_phase(v, _pPourEnd, _pUprightEnd)));
        }

        const inertiaFactor = 0.07;
        _liquidTilt += (bottleAngle - _liquidTilt) * inertiaFactor;

        final easedFlow =
            Curves.easeInOutSine.transform(drainProgress.clamp(0.0, 1.0));

        final isPouring = widget.plan.count > 0 &&
            v >= _pMoveEnd &&
            v < _pUprightEnd &&
            streamOpen > 0.005;

        final visibleTubeAngle = _liquidTilt;

        final mouthEdgeLocal = _mouthEdgeLocal(
          fromMidX: fromMidX,
        );

        final pivotInWidget = Offset(kWidgetW / 2, kBodyBotY + kTR);
        final rotatedMouthEdge = _rotateAroundAnchor(
            mouthEdgeLocal, pivotInWidget, visibleTubeAngle);

        final globalStreamStart = Offset(
          cx + rotatedMouthEdge.dx,
          cy + rotatedMouthEdge.dy,
        );

        final targetBaseUnits = widget.plan.toSnapshot.length.toDouble();

        // Akış çizgisinin ucu: dolmadan ÖNCEKİ sıvı seviyesi (sabit).
        // Dolum ilerledikçe yukarı kaçmaması için currentTargetUnits kullanmıyoruz.
        final initialTargetSurfaceY = _surfaceCenterYForFillRatio(
          (targetBaseUnits / kCap).clamp(0.0, 1.0),
        );

        final targetMouthEntry = Offset(
          toMidX,
          toPos.dy + initialTargetSurfaceY,
        );

        final motionEnergy = _motionEnergy(v);
        final sourceSlosh = _sloshing(v, 0.50) + motionEnergy * 0.10;
        final sourceBubbleBurst = isPouring
            ? lerpDouble(0.85, 1.0, easedFlow)!
            : (v >= _pPourEnd && v < _pUprightEnd
                ? lerpDouble(0.55, 0.0, _phase(v, _pPourEnd, _pUprightEnd))!
                : 0.0);

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
                      end: targetMouthEntry,
                      progress: streamOpen,
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
                tilt: _liquidTilt,
                slosh: sourceSlosh,
                bubbleBurst: sourceBubbleBurst,
              ),
            ),
          ],
        );
      },
    );
  }

  double _surfaceCenterYForFillRatio(double fillRatio) {
    final innerBottom = kLiquidBotY - 20.0;
    return innerBottom - (innerBottom - kLiquidTopY) * fillRatio;
  }

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
}

// ─────────────────────────────────────────────
// SIVI AKIŞI
// ─────────────────────────────────────────────

class _LiquidStreamPainter extends CustomPainter {
  final Color color;
  final Offset start;
  final Offset end;
  final double progress;
  final double flowRate;

  const _LiquidStreamPainter({
    required this.color,
    required this.start,
    required this.end,
    required this.progress,
    required this.flowRate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    if ((end - start).distance < 1.0) return;

    final t = progress.clamp(0.0, 1.0);

    final visibleEnd = Offset(
      lerpDouble(start.dx, end.dx, t)!,
      lerpDouble(start.dy, end.dy, t)!,
    );

    final dx = visibleEnd.dx - start.dx;
    final dy = visibleEnd.dy - start.dy;
    final distance = (visibleEnd - start).distance;

    final thickness = lerpDouble(3.6, 7.0, flowRate)!;
    final arc = max(10.0, dy.abs() * 0.10 + distance * 0.05);

    final c1 = Offset(
      start.dx + dx * 0.06,
      start.dy + max(2.0, arc * 0.55),
    );

    final c2 = Offset(
      visibleEnd.dx - dx * 0.06,
      visibleEnd.dy - max(2.0, arc * 0.14),
    );

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, visibleEnd.dx, visibleEnd.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.98)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LiquidStreamPainter old) =>
      old.start != start ||
      old.end != end ||
      old.progress != progress ||
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

  const _TubeWidget({
    super.key,
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
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: SvgPicture.asset(
                  kTubeSvgAsset,
                  fit: BoxFit.fill,
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

class _TubeBodyPainter extends CustomPainter {
  const _TubeBodyPainter();

  // ── Renk sabitleri (SVG'den) ──────────────────────────────────────────────
  static const Color _clrWallLeft = Color(0xFF5A5E7A); // fil0
  static const Color _clrWallRight = Color(0xFF3E4258); // fil1
  static const Color _clrCapTop = Color(0xFFA0A4C0); // id1 stop 0
  static const Color _clrCapMid = Color(0xFF6E728E); // id1 stop 0.6
  static const Color _clrCapBot = Color(0xFF4E5270); // id1 stop 1
  static const Color _clrCapBorder = Color(0xFF9A9EBC); // str0
  static const Color _clrUBot = Color(0xFF3A3E58); // id0 stop 1
  static const Color _clrUTop = Color(0xFF7A7E9A); // id0 stop 0

  @override
  void paint(Canvas canvas, Size size) {
    // Koordinatlar – kWidgetW x kWidgetH canvas'ına ölçeklendi
    // Tüm değerler SVG'den türetildi (getter'lar kullanılıyor)

    final lx = kBodyLeftX; // sol duvar sol X  ≈ 5.78
    final rx = kBodyRightX; // sağ duvar sağ X  ≈ 54.22
    final il = kBodyInnerLeft; // iç alan sol X  ≈ 10.12
    final ir = kBodyInnerRight; // iç alan sağ X  ≈ 49.88
    final topY = kBodyTopY; // gövde üst Y    ≈ 7.11
    final botY = kBodyBotY; // gövde alt Y    ≈ 113.1
    final r = kTR; // alt daire r    ≈ 19.88
    final capTop = kCapTopY; // kapak üst Y    ≈ 0.24
    final capBot = kCapBotY; // kapak alt Y    ≈ 8.98
    final capH = capBot - capTop;

    // ── 1. Sol duvar ──────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(lx, topY, il - lx, botY - topY),
      Paint()..color = _clrWallLeft,
    );

    // ── 2. Sağ duvar ──────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(ir, topY, rx - ir, botY - topY),
      Paint()..color = _clrWallRight,
    );

    // ── 3. Alt U (dış duvar halkası – iç boşluk sıvıya açık) ────────────────
    // SVG fil2: tüpün alt yuvarlak kısmı, dış duvarlar degrade gri
    final outerR = (rx - lx) / 2;
    final innerR = kBodyInnerW / 2; // iç boşluk yarıçapı
    final uCx = (lx + rx) / 2; // merkez X
    final uOuterRect = Rect.fromLTWH(lx, botY - outerR, rx - lx, outerR * 2);
    final uInnerRect = Rect.fromLTWH(
      uCx - innerR,
      botY - innerR,
      innerR * 2,
      innerR * 2,
    );
    final uGrad = LinearGradient(
      colors: [_clrUTop, _clrUBot],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(uOuterRect);

    // saveLayer ile BlendMode.clear çalışsın (transparan arka plan gerekir)
    canvas.saveLayer(null, Paint());
    canvas.clipRect(Rect.fromLTWH(0, botY - 1, size.width, outerR + 4));
    canvas.drawOval(uOuterRect, Paint()..shader = uGrad);
    canvas.drawOval(uInnerRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // ── 4. Kapak (tıpa) ──────────────────────────────────────────────────
    // SVG fil3: yuvarlak köşeli dikdörtgen + kenarlık (str0)
    final capW = rx - lx;
    final capRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(lx, capTop, capW, capH),
      Radius.circular(capH * 0.52),
    );

    final capGrad = LinearGradient(
      colors: [_clrCapTop, _clrCapMid, _clrCapBot],
      stops: const [0.0, 0.6, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(lx, capTop, capW, capH));

    canvas.drawRRect(capRect, Paint()..shader = capGrad);

    // Kapak kenarlığı (str0: #9A9EBC, thin)
    canvas.drawRRect(
      capRect,
      Paint()
        ..color = _clrCapBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.45,
    );

    // ── 5. Kapak parlama oval (fil4: sol üst, %22 beyaz) ─────────────────
    // SVG'de: x=486.46..2451.9, y=121.55..340.95 (sol kapakta)
    // Normalize: x≈3.45..17.44, y≈0.87..2.43 → kapak içi sol üst oval
    final capGlowLeft = kBodyLeftX + capW * 0.059; // ≈ 3.45
    final capGlowRight = kBodyLeftX + capW * 0.30; // ≈ 17.4
    final capGlowTop = capTop + capH * 0.14;
    final capGlowBot = capTop + capH * 0.62;

    canvas.drawOval(
      Rect.fromLTWH(
        capGlowLeft,
        capGlowTop,
        capGlowRight - capGlowLeft,
        capGlowBot - capGlowTop,
      ),
      Paint()..color = Colors.white.withOpacity(0.22),
    );

    // ── 6. Sol içi parlama dikey oval (fil5: %5.9 beyaz) ─────────────────
    // SVG: x=1905.95, y=1169.78, w=349.42, h=14063.28
    // Normalize: x≈13.55, y≈8.35, w≈2.48, h≈100.4
    final shineLeft = 1905.95 * _sx;
    final shineTop = 1169.78 * _sy;
    final shineW = (1949.62 + 305.75 - 1905.95) * _sx; // ≈ center+halfW
    final shineH = (1169.78 + 13452.34 + 305.72) * _sy - shineTop;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(shineLeft, shineTop, shineW.clamp(1.5, 3.5),
            shineH.clamp(1, kWidgetH - shineTop - 2)),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withOpacity(0.059),
    );

    // ── 7. Sol kenar çizgisi (str1: beyaz, %13 opaklık) ──────────────────
    // SVG: x=945.06, y=1169.78..15495.66
    // Normalize: x≈6.72, y≈8.35..110.6
    final lineX = 945.06 * _sx;
    final lineTopY = 1169.78 * _sy;
    final lineBotY = 15495.66 * _sy;

    canvas.drawLine(
      Offset(lineX, lineTopY),
      Offset(lineX, lineBotY),
      Paint()
        ..color = Colors.white.withOpacity(0.129)
        ..strokeWidth = 78.62 * _sx
        ..strokeCap = StrokeCap.round,
    );

    // ── 8. Sağ içi gölge oval (fil8: %3.1 beyaz) ─────────────────────────
    // SVG: x=6710.36, w=262.04, y=1169.78..14933.54
    final shadowX = 6710.36 * _sx;
    final shadowW = 262.04 * _sx;
    final shadowTopY = 1169.78 * _sy;
    final shadowH = (13801.76 + 131.01 + 131.04) * _sy;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(shadowX, shadowTopY, shadowW.clamp(1, 2.5),
            shadowH.clamp(1, kWidgetH - shadowTopY - 2)),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withOpacity(0.031),
    );
  }

  @override
  bool shouldRepaint(covariant _TubeBodyPainter oldDelegate) => false;
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
    if (y <= _it) return kCap.toDouble();

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
    return (area / total * kCap).clamp(0.0, kCap.toDouble());
  }

  double _yForVolume(double vol) {
    if (vol <= 0) return _ib;
    if (vol >= kCap) return _it;
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

  Path _tongue(double tilt, double vol, double bias) {
    if (bias <= 0.001 || vol <= 0.001) return Path();
    final s = _surface(vol, tilt, 0);
    final thick = lerpDouble(1.8, 4.3, bias)!;
    const ni = 1.8;
    final mY = _it + 1.2;
    final path = Path();

    if (tilt < 0) {
      final rX = _ir - 6, rY = s.rY, tX = _ir + ni, tY = mY;
      path
        ..moveTo(rX, rY - thick * 0.45)
        ..cubicTo(_ir - 2, rY - 2, _ir + 0.4, tY - 1.3, tX, tY - thick * 0.45)
        ..lineTo(tX, tY + thick * 0.45)
        ..cubicTo(_ir + 0.4, tY + 1.3, _ir - 2, rY + 2, rX, rY + thick * 0.45)
        ..close();
    } else {
      final rX = _il + 6, rY = s.lY, tX = _il - ni, tY = mY;
      path
        ..moveTo(rX, rY - thick * 0.45)
        ..cubicTo(_il + 2, rY - 2, _il - 0.4, tY - 1.3, tX, tY - thick * 0.45)
        ..lineTo(tX, tY + thick * 0.45)
        ..cubicTo(_il - 0.4, tY + 1.3, _il + 2, rY + 2, rX, rY + thick * 0.45)
        ..close();
    }
    return path;
  }

  List<_VisualLayer> _buildLayers() {
    final layers = <_VisualLayer>[];
    for (final c in tube) {
      if (layers.isNotEmpty && layers.last.colorIdx == c) {
        final l = layers.removeLast();
        layers.add(l.copyWith(volume: l.volume + 1));
      } else {
        layers.add(_VisualLayer(colorIdx: c, volume: 1));
      }
    }

    double drainLeft = drainedVolume.clamp(0.0, kCap.toDouble());
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
      final add = min(incomingVolume, kCap - cur);
      if (add > 0.0001) {
        if (layers.isNotEmpty && layers.last.colorIdx == incomingColorIdx) {
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
      final fill = kColors[layer.colorIdx]['fill'] as Color;
      final isTop = i == layers.length - 1;

      final bandPath = _band(vBot, vTop, tilt, isTop ? slosh : slosh * 0.45);
      canvas.drawPath(bandPath, Paint()..color = fill);

      // Işık gradyanı
      canvas.drawPath(
        bandPath,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.transparent,
              Colors.black.withOpacity(0.05),
            ],
            stops: const [0.0, 0.35, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(liquidRect),
      );
      accum = vTop;
    }

    // Üst yüzey parlaması
    if (totalVol > 0.0001) {
      canvas.drawPath(
        _surfaceLine(totalVol, tilt, slosh),
        Paint()
          ..color = Colors.white.withOpacity(0.18)
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
          Paint()..color = Colors.white.withOpacity(0.08 * splash),
        );
      }
    }

    // 🫧 Kabarcık efekti (görünür güçlendirilmiş sürüm)
    if (totalVol > 0.0001 && bubbleBurst > 0.01) {
      final s = _surface(totalVol, tilt, slosh * 0.25);

      final bubbleFill = Paint()
        ..color = Colors.white.withOpacity(0.55 * bubbleBurst)
        ..style = PaintingStyle.fill;

      final bubbleStroke = Paint()
        ..color = Colors.white.withOpacity(0.95 * bubbleBurst)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.95 * bubbleBurst)
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
      old.receiveFlow != receiveFlow;
}
