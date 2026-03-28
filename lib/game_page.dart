import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map_theme.dart';

// ─────────────────────────────────────────────
// OYUN SABİTLERİ
// ─────────────────────────────────────────────

const int kCap = 4;
const int kNColors = 6;
const int kEmpty = 2;

// Widget boyutları – SVG oranına göre ayarlandı (84.4 x 182 mm → 60 x 130 px)
const double kTW = 60.0;
const double kTH = 130.0;

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
double get kLiquidLeft => kBodyInnerLeft; // duvar iç kenarına tam
double get kLiquidRight => kBodyInnerRight; // duvar iç kenarına tam
double get kLiquidW => kLiquidRight - kLiquidLeft;
double get kLiquidTopY =>
    kBodyTopY + 10.0; // kapaktan 5px boşluk (ağzına kadar dolmasın)
double get kLiquidBotY => kBodyBotY + kTR; // tam daire alt noktasına kadar

// Widget toplam yüksekliği
// Alt U'nun en altı: SVG'de y=18197.8 → kTH
double get kWidgetH => kTH;
double get kWidgetW => kTW;

const double kTubeGap = 18.0;
double get kStageW => (kWidgetW * 4) + (kTubeGap * 3) + 24.0;
double get kStageH => (kWidgetH * 3) + (kTubeGap * 2) + 28.0;
const Duration kPourDuration = Duration(milliseconds: 2200);

const List<Map<String, dynamic>> kColors = [
  {'name': 'Kirmizi', 'fill': Color(0xFFFF1744)},
  {'name': 'Mavi', 'fill': Color(0xFF2196F3)},
  {'name': 'Yesil', 'fill': Color(0xFF17C63A)},
  {'name': 'Pembe', 'fill': Color(0xFFFF4FD8)},
  {'name': 'Turuncu', 'fill': Color(0xFFFF9800)},
  {'name': 'Sari', 'fill': Color(0xFFFFD21F)},
];

// ─────────────────────────────────────────────
// HARİTA TEMASI
// ─────────────────────────────────────────────

class _MapTheme {
  final Color bgTop;
  final Color bgBottom;
  final Color glowA;
  final Color glowB;
  final Color panel;
  final Color panelBorder;
  final Color accent;

  const _MapTheme({
    required this.bgTop,
    required this.bgBottom,
    required this.glowA,
    required this.glowB,
    required this.panel,
    required this.panelBorder,
    required this.accent,
  });
}

_MapTheme _themeForMap(int mapNumber) {
  switch ((mapNumber - 1) % 5) {
    case 0:
      return const _MapTheme(
        bgTop: Color(0xFF201A32),
        bgBottom: Color(0xFF151124),
        glowA: Color(0xFF5E5BFF),
        glowB: Color(0xFF9B5BFF),
        panel: Color(0x12000000),
        panelBorder: Color(0x22FFFFFF),
        accent: Color(0xFFC1B4FF),
      );
    case 1:
      return const _MapTheme(
        bgTop: Color(0xFF102317),
        bgBottom: Color(0xFF0A1711),
        glowA: Color(0xFF19C37D),
        glowB: Color(0xFF7ED957),
        panel: Color(0x12000000),
        panelBorder: Color(0x22FFFFFF),
        accent: Color(0xFF7ED957),
      );
    case 2:
      return const _MapTheme(
        bgTop: Color(0xFF25150E),
        bgBottom: Color(0xFF140D0A),
        glowA: Color(0xFFFFA726),
        glowB: Color(0xFFFF7043),
        panel: Color(0x12000000),
        panelBorder: Color(0x22FFFFFF),
        accent: Color(0xFFFFB74D),
      );
    case 3:
      return const _MapTheme(
        bgTop: Color(0xFF1A1026),
        bgBottom: Color(0xFF0E0A16),
        glowA: Color(0xFF9C6BFF),
        glowB: Color(0xFFFF4FC3),
        panel: Color(0x12000000),
        panelBorder: Color(0x22FFFFFF),
        accent: Color(0xFFD1A6FF),
      );
    default:
      return const _MapTheme(
        bgTop: Color(0xFF0D1E21),
        bgBottom: Color(0xFF091214),
        glowA: Color(0xFF00BCD4),
        glowB: Color(0xFF26A69A),
        panel: Color(0x12000000),
        panelBorder: Color(0x22FFFFFF),
        accent: Color(0xFF7BE7F3),
      );
  }
}

// ─────────────────────────────────────────────
// OYUN MANTIĞI
// ─────────────────────────────────────────────

List<List<int>> generateTubes({
  required int level,
  required int difficulty,
}) {
  final patterns = <int, List<List<List<int>>>>{
    1: [
      [
        [0, 1, 2, 3],
        [1, 2, 0, 3],
        [2, 0, 1, 3],
        [3, 0, 1, 2],
        [0, 1, 2, 3],
        [1, 2, 0, 3],
        [2, 0, 1, 3],
        [3, 2, 1, 0],
        [],
        [],
        [],
      ],
      [
        [0, 1, 2, 3],
        [1, 0, 3, 2],
        [2, 3, 0, 1],
        [3, 2, 1, 0],
        [0, 2, 1, 3],
        [1, 3, 2, 0],
        [2, 1, 3, 0],
        [3, 0, 2, 1],
        [],
        [],
        [],
      ],
    ],
    2: [
      [
        [0, 1, 2, 3],
        [1, 2, 3, 4],
        [2, 3, 4, 0],
        [3, 4, 0, 1],
        [4, 0, 1, 2],
        [0, 2, 4, 1],
        [1, 3, 0, 2],
        [4, 3, 2, 1],
        [],
        [],
        [],
      ],
    ],
    3: [
      [
        [0, 1, 2, 3],
        [1, 2, 3, 4],
        [2, 3, 4, 5],
        [3, 4, 5, 0],
        [4, 5, 0, 1],
        [5, 0, 1, 2],
        [0, 2, 4, 1],
        [3, 5, 2, 4],
        [],
        [],
        [],
      ],
    ],
    4: [
      [
        [0, 1, 2, 3],
        [1, 2, 3, 4],
        [2, 3, 4, 5],
        [3, 4, 5, 0],
        [4, 5, 0, 1],
        [5, 0, 1, 2],
        [0, 4, 2, 5],
        [3, 1, 4, 2],
        [],
        [],
        [],
      ],
    ],
    5: [
      [
        [0, 1, 2, 3],
        [1, 3, 4, 5],
        [2, 4, 5, 0],
        [3, 5, 0, 1],
        [4, 0, 1, 2],
        [5, 2, 3, 4],
        [0, 4, 2, 5],
        [1, 3, 4, 2],
        [],
        [],
        [],
      ],
    ],
  };

  final safeDifficulty = difficulty.clamp(1, 5);
  final bucket = patterns[safeDifficulty] ?? patterns[1]!;
  final chosen = bucket[(level - 1) % bucket.length];
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
  final top = tubes[from].last;
  while (tubes[from].isNotEmpty &&
      tubes[from].last == top &&
      tubes[to].length < kCap) {
    tubes[to].add(tubes[from].removeLast());
  }
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

// ─────────────────────────────────────────────
// GAME PAGE
// ─────────────────────────────────────────────

class GamePage extends StatefulWidget {
  final int level;
  final int mapNumber;
  final int difficulty;

  const GamePage({
    super.key,
    required this.level,
    required this.mapNumber,
    this.difficulty = 1,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final MapTheme _theme;

  static const int _lockedAdTubeIndex = 10;

  late List<List<int>> _tubes;
  late List<List<int>> _displayTubes;

  int? _selected;
  bool _animating = false;
  _TransferPlan? _transferPlan;
  bool _gameWon = false;
  final Set<int> _celebratingDoneTubes = <int>{};

  @override
  void initState() {
    super.initState();
    _theme = getMapTheme(widget.mapNumber);
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _reset();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  bool get _showLockedAdTube => widget.level <= 2;

  bool _isLockedAdTubeIndex(int idx) =>
      _showLockedAdTube && idx == _lockedAdTubeIndex;

  void _reset() {
    _tubes = generateTubes(level: widget.level, difficulty: widget.difficulty)
        .map((t) => List<int>.of(t, growable: true))
        .toList(growable: true);
    _displayTubes = _tubes
        .map((t) => List<int>.of(t, growable: true))
        .toList(growable: true);
    _selected = null;
    _animating = false;
    _transferPlan = null;
    _gameWon = false;
    _celebratingDoneTubes.clear();
    setState(() {});
  }

  Future<void> _handleTap(int idx) async {
    if (_animating) return;
    if (_isLockedAdTubeIndex(idx)) return;

    if (_selected == null) {
      if (_tubes[idx].isEmpty) return;
      setState(() => _selected = idx);
      return;
    }

    if (_selected == idx) {
      setState(() => _selected = null);
      return;
    }

    final from = _selected!;
    final to = idx;

    if (_isLockedAdTubeIndex(from) || _isLockedAdTubeIndex(to)) {
      HapticFeedback.lightImpact();
      setState(() => _selected = null);
      return;
    }

    if (!canPour(_tubes, from, to)) {
      HapticFeedback.lightImpact();
      setState(() => _selected = null);
      return;
    }

    final count = pourCount(_tubes, from, to);
    if (count <= 0) {
      HapticFeedback.lightImpact();
      setState(() => _selected = null);
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

    setState(() {
      _selected = from; // null yapma, seçili kalsın
      _animating = true;
      _transferPlan = plan;
      _displayTubes = _tubes.map((t) => List<int>.from(t)).toList();
    });

    HapticFeedback.mediumImpact();
    await Future.delayed(kPourDuration);

    if (!mounted) return;
    doPour(_tubes, from, to);

    final newlyDone = <int>{};
    for (final idx in [from, to]) {
      if (!_isLockedAdTubeIndex(idx) && isTubeDone(_tubes[idx])) {
        newlyDone.add(idx);
      }
    }
    final didWin = isGameDone(_tubes);

    setState(() {
      _displayTubes = _tubes
          .map((t) => List<int>.of(t, growable: true))
          .toList(growable: true);
      _selected = null;
      _animating = false;
      _transferPlan = null;
      _gameWon = didWin;
    });

    _triggerDoneCelebration(newlyDone);
    if (didWin) {
      await Future.delayed(const Duration(milliseconds: 220));
      if (mounted) {
        await _showWinDialog();
      }
    }
  }

  void _triggerDoneCelebration(Set<int> indices) {
    if (indices.isEmpty || !mounted) return;
    setState(() {
      _celebratingDoneTubes.addAll(indices);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _celebratingDoneTubes.removeAll(indices);
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
                    onTap: _completeLevel,
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
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(28),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: kStageW,
                                    height: kStageH,
                                    child: _TubeStage(
                                      tubes: _displayTubes,
                                      selected: _selected,
                                      transferPlan: _transferPlan,
                                      onTap: _handleTap,
                                      lockedAdTubeIndex: _lockedAdTubeIndex,
                                      showLockedAdTube: _showLockedAdTube,
                                      celebratingDoneTubes:
                                          _celebratingDoneTubes,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _BottomActionBtn(
                                    label: 'Seviyeyi Düşür',
                                    color: Colors.white.withOpacity(0.10),
                                    borderColor: Colors.white.withOpacity(0.18),
                                    textColor: Colors.white,
                                    onTap: _lowerLevel,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _BottomActionBtn(
                                    label: 'Seviyeyi Geç',
                                    color: _theme.accentColor.withOpacity(0.18),
                                    borderColor:
                                        _theme.accentColor.withOpacity(0.45),
                                    textColor: _theme.accentColor,
                                    onTap: _completeLevel,
                                  ),
                                ),
                              ],
                            ),
                            if (_gameWon) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Tebrikler, bölüm tamamlandı!',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.96),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
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
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Text(
                _theme.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _theme.accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
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
// ARKA PLAN
// ─────────────────────────────────────────────

class _AnimatedThemeBg extends StatelessWidget {
  final Animation<double> controller;
  final MapTheme theme;

  const _AnimatedThemeBg({required this.controller, required this.theme});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.bgDark, theme.bgMid, theme.bgLight],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80 + t * 40,
              left: -50,
              child: _GlowBlob(
                  size: 220, color: theme.primaryColor.withOpacity(0.20)),
            ),
            Positioned(
              top: 120,
              right: -70 + t * 50,
              child: _GlowBlob(
                  size: 260, color: theme.secondaryColor.withOpacity(0.16)),
            ),
            Positioned(
              bottom: -80,
              left: 40 - t * 30,
              child: _GlowBlob(
                  size: 240, color: theme.accentColor.withOpacity(0.10)),
            ),
          ],
        );
      },
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.6,
              spreadRadius: size * 0.15,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ALT BUTON
// ─────────────────────────────────────────────

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

class _TubeStage extends StatefulWidget {
  final List<List<int>> tubes;
  final int? selected;
  final _TransferPlan? transferPlan;
  final void Function(int) onTap;
  final int lockedAdTubeIndex;
  final bool showLockedAdTube;
  final Set<int> celebratingDoneTubes;

  const _TubeStage({
    required this.tubes,
    required this.selected,
    required this.transferPlan,
    required this.onTap,
    required this.lockedAdTubeIndex,
    required this.showLockedAdTube,
    required this.celebratingDoneTubes,
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

    Offset pos =
        box.localToGlobal(Offset.zero) - stageBox.localToGlobal(Offset.zero);

    if (widget.selected == idx) {
      pos = pos.translate(0, -15.0);
    }

    return pos;
  }

  Widget _tubeItem(int idx, {double topPadding = 0}) {
    final hiddenSource = widget.transferPlan?.fromIdx;
    final isLockedAdTube =
        widget.showLockedAdTube && idx == widget.lockedAdTubeIndex;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: KeyedSubtree(
        key: _keys[idx],
        child: GestureDetector(
          onTap: () => widget.onTap(idx),
          child: Opacity(
            opacity: idx == hiddenSource ? 0.0 : 1.0,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: isLockedAdTube ? 0.30 : 1.0,
                  child: _TubeWidget(
                    tube: widget.tubes[idx],
                    isSelected: widget.selected == idx,
                  ),
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
                if (widget.celebratingDoneTubes.contains(idx))
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: _TubeDoneBurst(),
                    ),
                  ),
              ],
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
          if (idx != indices.last) const SizedBox(width: kTubeGap),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(const [0, 1, 2, 3]),
                const SizedBox(height: kTubeGap),
                _row(const [4, 5, 6, 7]),
                const SizedBox(height: kTubeGap),
                _row(const [8, 9, 10], topPadding: 4),
              ],
            ),
          ),
        ),
        if (widget.transferPlan != null)
          _FlyingTube(
            plan: widget.transferPlan!,
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

class _TubeDoneBurst extends StatelessWidget {
  const _TubeDoneBurst();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 850),
      builder: (context, value, child) {
        final eased = Curves.easeOutCubic.transform(value);
        final dy = lerpDouble(18.0, -58.0, eased)!;
        final opacity = (1.0 - eased).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Align(
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      child: CustomPaint(
        size: const Size(26, 26),
        painter: const _BurstHexPainter(),
      ),
    );
  }
}

class _BurstHexPainter extends CustomPainter {
  const _BurstHexPainter();

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

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF4FD8), Color(0xFF7C4DFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// UÇAN TÜP

// ─────────────────────────────────────────────

class _FlyingTube extends StatefulWidget {
  final _TransferPlan plan;
  final Offset? Function(int) getPos;

  const _FlyingTube({required this.plan, required this.getPos});

  @override
  State<_FlyingTube> createState() => _FlyingTubeState();
}

class _FlyingTubeState extends State<_FlyingTube>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const double _pLiftEnd = 0.18;
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
    final fill = (remainingUnits / kCap).clamp(0.0, 1.0);
    final emptiness = 1.0 - fill;
    final deg = lerpDouble(58.0, 84.0, emptiness)!;
    return deg * pi / 180.0;
  }

  Offset _mouthEdgeLocal({required double bottleAngle}) {
    final poursFromRight = bottleAngle < 0;

    if (poursFromRight) {
      return Offset(kBodyRightX + 2.0, kCapBotY - 0.5);
    } else {
      return Offset(kBodyLeftX - 2.0, kCapBotY - 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromPos = widget.getPos(widget.plan.fromIdx);
    final toPos = widget.getPos(widget.plan.toIdx);
    if (fromPos == null || toPos == null) return const SizedBox.shrink();

    final fromMidX = fromPos.dx + kWidgetW / 2;
    final toMidX = toPos.dx + kWidgetW / 2;
    final goRight = toMidX > fromMidX;
    final tiltSign = goRight ? -1.0 : 1.0;
    final liftY = min(fromPos.dy, toPos.dy) - 60.0;

    final mouthLocal = Offset(kWidgetW / 2, kCapBotY + 1.0);
    final anchorLocal = Offset(kWidgetW / 2, kBodyBotY + kTR);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = _ctrl.value;

        final rawPourProgress = v >= _pTiltEnd && v < _pPourEnd
            ? _phase(v, _pTiltEnd, _pPourEnd)
            : (v >= _pPourEnd ? 1.0 : 0.0);

        final transferProgress =
            Curves.easeInOutCubic.transform(rawPourProgress.clamp(0.0, 1.0));

        final sourceDrainVolume = widget.plan.count * transferProgress;
        final targetIncomingVolume = widget.plan.count * transferProgress;
        final remainingUnits =
            (widget.plan.fromSnapshot.length - sourceDrainVolume)
                .clamp(0.0, kCap.toDouble());

        final dynamicMaxTilt = _targetTiltForRemaining(remainingUnits);

        const double kPourGapY = 18.0;
        final targetMouth = Offset(toMidX, toPos.dy + kCapBotY - kPourGapY);

        final pourTopLeft = _tubeTopLeftToMatchMouth(
          targetMouth: targetMouth,
          mouthLocal: mouthLocal,
          anchorLocal: anchorLocal,
          angle: tiltSign * dynamicMaxTilt,
        );

        double cx;
        if (v < _pLiftEnd) {
          cx = fromPos.dx;
        } else if (v < _pMoveEnd) {
          cx = fromPos.dx +
              (pourTopLeft.dx - fromPos.dx) *
                  _easeHeavy(_phase(v, _pLiftEnd, _pMoveEnd));
        } else if (v < _pUprightEnd) {
          cx = pourTopLeft.dx;
        } else {
          cx = pourTopLeft.dx +
              (fromPos.dx - pourTopLeft.dx) *
                  _easeHeavy(_phase(v, _pUprightEnd, 1.0));
        }

        double cy;
        if (v < _pLiftEnd) {
          cy = fromPos.dy +
              (liftY - fromPos.dy) * _easeHeavy(_phase(v, 0.0, _pLiftEnd));
        } else if (v < _pMoveEnd) {
          cy = liftY +
              (pourTopLeft.dy - liftY) *
                  _easeHeavy(_phase(v, _pLiftEnd, _pMoveEnd));
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

        final streamOpen =
            Curves.easeInOut.transform(_phase(v, _pMoveEnd, _pPourEnd));
        final easedFlow =
            Curves.easeInOutSine.transform(streamOpen.clamp(0.0, 1.0));

        final isPouring = widget.plan.count > 0 &&
            v >= _pMoveEnd &&
            v < _pPourEnd &&
            streamOpen > 0.005;

        final mouthEdgeLocal = _mouthEdgeLocal(bottleAngle: bottleAngle);
        final pivotInWidget = Offset(kWidgetW / 2, kBodyBotY + kTR);
        final rotatedMouthEdge =
            _rotateAroundAnchor(mouthEdgeLocal, pivotInWidget, bottleAngle);

        final globalStreamStart = Offset(
          cx + rotatedMouthEdge.dx,
          cy + rotatedMouthEdge.dy,
        );

        final targetFillRatio =
            ((widget.plan.toSnapshot.length + targetIncomingVolume) / kCap)
                .clamp(0.0, 1.0);

        final targetLiquidEntry = Offset(
          toMidX,
          _surfaceCenterYForFillRatio(targetFillRatio) + toPos.dy + 24.0,
        );

        final motionEnergy = _motionEnergy(v);
        final sourceSlosh = _sloshing(v, 0.50) + motionEnergy * 0.10;
        final targetSlosh = _sloshing(v + 0.12, 0.38) +
            easedFlow * 0.06 +
            targetIncomingVolume * 0.02;
        final targetSplash = isPouring ? easedFlow * 0.32 : 0.0;
        final sourceBubbleBurst = isPouring
            ? lerpDouble(0.85, 1.0, easedFlow)!
            : (v >= _pPourEnd && v < _pUprightEnd
                ? lerpDouble(0.55, 0.0, _phase(v, _pPourEnd, _pUprightEnd))!
                : 0.0);
        final targetBubbleBurst = isPouring
            ? lerpDouble(0.75, 0.95, easedFlow)!
            : (v >= _pPourEnd && v < _pUprightEnd
                ? lerpDouble(0.45, 0.0, _phase(v, _pPourEnd, _pUprightEnd))!
                : 0.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: toPos.dx,
              top: toPos.dy,
              child: IgnorePointer(
                child: _TubeWidget(
                  tube: widget.plan.toSnapshot,
                  isSelected: false,
                  incomingColorIdx: widget.plan.colorIdx,
                  incomingVolume: targetIncomingVolume,
                  slosh: targetSlosh,
                  splash: targetSplash,
                  pourProgress: streamOpen,
                  bubbleBurst: targetBubbleBurst,
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
                pourProgress: streamOpen,
                bubbleBurst: sourceBubbleBurst,
                streamStartGlobal: isPouring ? globalStreamStart : null,
                tubeCanvasOffset: isPouring ? Offset(cx, cy) : null,
              ),
            ),
            if (isPouring)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _LiquidStreamPainter(
                      color: kColors[widget.plan.colorIdx]['fill'] as Color,
                      start: globalStreamStart,
                      end: targetLiquidEntry,
                      progress: streamOpen,
                      flowRate: easedFlow,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _surfaceCenterYForFillRatio(double fillRatio) {
    final innerBottom = kBodyBotY + kTR;
    return innerBottom - (innerBottom - kLiquidTopY) * fillRatio;
  }

  double _motionEnergy(double v) {
    if (v < _pLiftEnd) return _phase(v, 0.0, _pLiftEnd) * 0.45;
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

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = (end - start).distance;

    final thickness = lerpDouble(3.6, 7.0, flowRate)!;
    final arc = max(10.0, dy.abs() * 0.10 + distance * 0.05);

// Başlangıçta şişe ağzına daha yapışık,
// sonda hedef kaba daha düz giren eğri
    final c1 = Offset(
      start.dx + dx * 0.10,
      start.dy + max(4.0, arc * 0.85),
    );

    final c2 = Offset(
      end.dx - dx * 0.08,
      end.dy - max(3.0, arc * 0.18),
    );

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.24 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness + 4.2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.98)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.24 * flowRate)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, thickness * 0.24)
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
  final Offset? streamStartGlobal;
  final Offset? tubeCanvasOffset;

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
    this.streamStartGlobal,
    this.tubeCanvasOffset,
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
    final frame = Stack(
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
          ),
        ),
        CustomPaint(
          size: Size(kWidgetW, kWidgetH),
          painter: const _TubeBodyPainter(),
        ),
      ],
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

    return SizedBox(
      width: kWidgetW,
      height: kWidgetH,
      child: Transform.translate(
        offset: Offset(0, liftY),
        child: Transform.rotate(
          angle: tilt,
          alignment: _pivotAlignment(),
          child: frame,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TÜP GÖVDE PAINTER  –  SVG birebir replika
// ─────────────────────────────────────────────
//
// SVG yapısı (yukarıdan aşağı):
//  1. [Kapak / tıpa] fil3+str0:  üst yuvarlak köşeli dikdörtgen, degrade gri
//  2. [Sol duvar]    fil0:       koyu gri dikey şerit (sol)
//  3. [Sağ duvar]    fil1:       daha koyu gri dikey şerit (sağ)
//  4. [Alt U]        fil2:       degrade yarım daire
//  5. [Sol parlama]  fil5:       şeffaf beyaz dikey oval (sol içinde)
//  6. [Sol çizgi]    str1:       yarı şeffaf beyaz dikey çizgi (sol kenar)
//  7. [Sağ gölge]    fil8:       çok şeffaf beyaz oval (sağ içinde)
//  8. [Kapak parlaması] fil4:    sol üstte parlak oval

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
              Colors.white.withOpacity(0.10),
              Colors.transparent,
              Colors.black.withOpacity(0.08),
            ],
            stops: const [0.0, 0.35, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(liquidRect),
      );

      // Katman arası çizgi
      if (!isTop) {
        canvas.drawPath(
          _surfaceLine(vTop, tilt, slosh * 0.08),
          Paint()
            ..color = Colors.black.withOpacity(0.18)
            ..strokeWidth = 0.9
            ..style = PaintingStyle.stroke,
        );
      }
      accum = vTop;
    }

    // Akış dili (tongue)
    if (totalVol > 0.0001 && flowBias > 0.001 && layers.isNotEmpty) {
      final topColor = kColors[layers.last.colorIdx]['fill'] as Color;
      canvas.drawPath(
        _tongue(tilt, totalVol, flowBias),
        Paint()..color = topColor,
      );
    }

    // Üst yüzey parlaması
    if (totalVol > 0.0001) {
      canvas.drawPath(
        _surfaceLine(totalVol, tilt, slosh),
        Paint()
          ..color = Colors.white.withOpacity(0.28)
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_il + 2, _it + 3, 4.0, max(0, _ib - _it - 12)),
        const Radius.circular(2.5),
      ),
      Paint()..color = Colors.white.withOpacity(0.07),
    );

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
      old.bubbleBurst != bubbleBurst;
}
