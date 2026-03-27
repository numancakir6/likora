import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
// OYUN SABİTLERİ
// ─────────────────────────────────────────────

const int kCap = 4;
const int kNColors = 6;
const int kEmpty = 2;

// Tüp boyutları – resme yakın: geniş gövde, dar boyun, yuvarlak alt
const double kTW = 62.0; // widget genişliği
const double kTH = 160.0; // widget yüksekliği (boyun dahil)
const double kTX = 6.0; // gövde sol kenar X
const double kTBW = 50.0; // gövde genişliği
const double kNeckW = 22.0; // boyun genişliği
const double kNeckH = 22.0; // boyun yüksekliği
const double kTTopY = kNeckH; // gövde başlangıç Y (boyun altı)
const double kTBodyH = 112.0; // gövde yüksekliği (düz kısım)
const double kTR = kTBW / 2; // alt yuvarlak yarıçapı
const double kTBotY = kTTopY + kTBodyH;

const double kLiquidTopInset = 4.0;
const double kLiquidTopY = kTTopY + kLiquidTopInset;

const double kWidgetH = 18.0 + kTH + 4.0 + 14.0;
const double kWidgetW = kTW;
const double kTubeGap = 12.0;

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

List<List<int>> generateTubes() {
  return [
    [3, 4, 1, 2],
    [5, 0, 1, 4],
    [4, 5, 3, 0],
    [1, 2, 4, 5],
    [0, 2, 1, 2],
    [3],
    [],
    [],
  ].map((e) => List<int>.from(e)).toList();
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
    if (tubes[from][i] == top) {
      count++;
    } else {
      break;
    }
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

  const _VisualLayer({
    required this.colorIdx,
    required this.volume,
  });

  _VisualLayer copyWith({
    int? colorIdx,
    double? volume,
  }) {
    return _VisualLayer(
      colorIdx: colorIdx ?? this.colorIdx,
      volume: volume ?? this.volume,
    );
  }
}

// ─────────────────────────────────────────────
// GAME PAGE
// ─────────────────────────────────────────────

class GamePage extends StatefulWidget {
  final int level;
  final int mapNumber;

  const GamePage({
    super.key,
    required this.level,
    required this.mapNumber,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final _MapTheme _theme;

  late List<List<int>> _tubes;
  late List<List<int>> _displayTubes;

  int? _selected;
  bool _animating = false;
  _TransferPlan? _transferPlan;
  bool _gameWon = false;

  @override
  void initState() {
    super.initState();
    _theme = _themeForMap(widget.mapNumber);
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

  void _reset() {
    _tubes = generateTubes();
    _displayTubes = _tubes.map((t) => List<int>.from(t)).toList();
    _selected = null;
    _animating = false;
    _transferPlan = null;
    _gameWon = false;
    setState(() {});
  }

  Future<void> _handleTap(int idx) async {
    if (_animating) return;

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
      _selected = null;
      _animating = true;
      _transferPlan = plan;
      _displayTubes = _tubes.map((t) => List<int>.from(t)).toList();
    });

    HapticFeedback.mediumImpact();

    await Future.delayed(kPourDuration);

    if (!mounted) return;

    doPour(_tubes, from, to);

    setState(() {
      _displayTubes = _tubes.map((t) => List<int>.from(t)).toList();
      _animating = false;
      _transferPlan = null;
      _gameWon = isGameDone(_tubes);
    });
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
      backgroundColor: _theme.bgBottom,
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
                          color: _theme.panel,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: _theme.panelBorder),
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
                                child: SizedBox(
                                  height: kWidgetH + 110,
                                  child: _TubeStage(
                                    tubes: _displayTubes,
                                    selected: _selected,
                                    transferPlan: _transferPlan,
                                    onTap: _handleTap,
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
                                    color: _theme.accent.withOpacity(0.18),
                                    borderColor:
                                        _theme.accent.withOpacity(0.45),
                                    textColor: _theme.accent,
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: SizedBox(
        height: 46,
        child: Center(
          child: Text(
            'HARITA ${widget.mapNumber}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.96),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
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
  final _MapTheme theme;

  const _AnimatedThemeBg({
    required this.controller,
    required this.theme,
  });

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
                    colors: [theme.bgTop, theme.bgBottom],
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
                size: 220,
                color: theme.glowA.withOpacity(0.20),
              ),
            ),
            Positioned(
              top: 120,
              right: -70 + t * 50,
              child: _GlowBlob(
                size: 260,
                color: theme.glowB.withOpacity(0.16),
              ),
            ),
            Positioned(
              bottom: -80,
              left: 40 - t * 30,
              child: _GlowBlob(
                size: 240,
                color: theme.glowA.withOpacity(0.10),
              ),
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

  const _GlowBlob({
    required this.size,
    required this.color,
  });

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

  const _TubeStage({
    required this.tubes,
    required this.selected,
    required this.transferPlan,
    required this.onTap,
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
    if (oldWidget.tubes.length != widget.tubes.length) {
      _rebuildKeys();
    }
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

  @override
  Widget build(BuildContext context) {
    final hiddenSource = widget.transferPlan?.fromIdx;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Wrap(
              spacing: kTubeGap,
              runSpacing: kTubeGap,
              alignment: WrapAlignment.center,
              children: List.generate(widget.tubes.length, (idx) {
                return KeyedSubtree(
                  key: _keys[idx],
                  child: GestureDetector(
                    onTap: () => widget.onTap(idx),
                    child: Opacity(
                      opacity: idx == hiddenSource ? 0.0 : 1.0,
                      child: _TubeWidget(
                        tube: widget.tubes[idx],
                        isSelected: widget.selected == idx,
                      ),
                    ),
                  ),
                );
              }),
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

// ─────────────────────────────────────────────
// UÇAN TÜP
// ─────────────────────────────────────────────

class _FlyingTube extends StatefulWidget {
  final _TransferPlan plan;
  final Offset? Function(int) getPos;

  const _FlyingTube({
    required this.plan,
    required this.getPos,
  });

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
    _ctrl = AnimationController(
      vsync: this,
      duration: kPourDuration,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static double _easeHeavy(double t) {
    return Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
  }

  static double _easeOutHeavy(double t) {
    return Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
  }

  static double _phase(double v, double start, double end) =>
      ((v - start) / (end - start)).clamp(0.0, 1.0);

  /// Şişenin yerel koordinat sisteminde ağız merkezi (pivot = anchorLocal)
  Offset _tubeMouthLocal() => const Offset(kTW / 2, 18.0 + kTTopY + 3.0);

  Offset _anchorLocal() => const Offset(kTW / 2, kWidgetH);

  /// Şişe döndürülmüş haldeyken ağız kenarından çıkan sıvı noktası.
  /// Bu nokta _tubeOutline() içindeki gerçek ağız kenarına tam eşleşmeli.
  /// Eğim yönüne (goRight) göre sol/sağ ağız kenarını döndürerek global konum.
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

  List<_VisualLayer> _layersFromTube(List<int> tube) {
    final layers = <_VisualLayer>[];
    for (final color in tube) {
      if (layers.isNotEmpty && layers.last.colorIdx == color) {
        final last = layers.removeLast();
        layers.add(last.copyWith(volume: last.volume + 1.0));
      } else {
        layers.add(_VisualLayer(colorIdx: color, volume: 1.0));
      }
    }
    return layers;
  }

  // ── Şişe ağzının canvas üzerindeki global konumunu hesapla ──────────────
  // _TubePainter içindeki _tubeOutline() ile birebir eşleşmeli.
  // _tubeOutline ağız kenarını şu noktadan çiziyor:
  //   sol:  (kTX - _mouthLipOut, lipY)  →  right: (kTX + kTBW + _mouthLipOut, lipY)
  // topPad = 18, lipY = topPad + kTTopY + 2.0 - mouthLipDown = 18+8+2-4.5 = 23.5
  static const double _topPad = 18.0;
  static const double _mouthLipDown = 3.0;
  static const double _mouthLipOut = 2.0;
  // lipY: boyun üst kenarı (akış çıkış noktası)
  // neckTopY = _topPad + 2.0, capY = neckTopY - 3.0 = _topPad - 1.0
  static const double _lipYLocal = _topPad + 2.0;

  /// Şişenin yerel koordinat sisteminde, eğim yönüne göre sıvının döküldüğü
  /// gerçek ağız kenarı noktası.  Bu noktayı döndürerek global stream başlangıcını
  /// hesaplayacağız.
  Offset _mouthEdgeLocal({required bool goRight}) {
    // tilt<0 (goRight) → sağ kenar alçak → sağ ağızdan akar
    // tilt>0 (!goRight) → sol kenar alçak → sol ağızdan akar
    if (goRight) {
      return const Offset(kTX + kTBW + _mouthLipOut, _lipYLocal); // sağ ağız
    } else {
      return const Offset(kTX - _mouthLipOut, _lipYLocal); // sol ağız
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
    final liftY = min(fromPos.dy, toPos.dy) - 96.0;

    final mouthLocal = _tubeMouthLocal();
    final anchorLocal = _anchorLocal();

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

        // Hedef tüpün boyun alt kenarı (gövde başlangıcı) civarı
        final targetMouth = Offset(
          toMidX,
          toPos.dy + _topPad + kNeckH + 6.0,
        );

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

        final streamOpen = Curves.easeInOut.transform(
          _phase(v, _pMoveEnd, _pPourEnd),
        );

        final easedFlow = Curves.easeInOutSine.transform(
          streamOpen.clamp(0.0, 1.0),
        );

        final isPouring = widget.plan.count > 0 &&
            v >= _pMoveEnd &&
            v < _pPourEnd &&
            streamOpen > 0.02;

        final internalFlowBias = Curves.easeInOut.transform(
          (streamOpen * (_liquidTilt.abs() / 1.02)).clamp(0.0, 1.0),
        );

        // ── Gerçek ağız noktasını hesapla (tube koordinatlarından global'e) ──
        // Şişenin yerel koordinat sistemindeki ağız kenarı
        final mouthEdgeLocal = _mouthEdgeLocal(goRight: goRight);
        // Anchor (pivot) yerel koordinatı
        // Döndürme işlemi _TubePainter içindeki pivot ile aynı:
        //   canvas.translate(pivotX, pivotY); rotate(tilt); translate(-pivotX,-pivotY)
        // Burada tube widget (cx,cy)'e yerleştirilmiş. Pivot tube içinde (_pivotX,_pivotY).
        final pivotInWidget = Offset(kTW / 2, _topPad + kTH - 18.0);

        // Ağız kenarını pivot etrafında döndür
        final rotatedMouthEdge =
            _rotateAroundAnchor(mouthEdgeLocal, pivotInWidget, bottleAngle);

        // Global canvas koordinatına çevir
        final globalStreamStart = Offset(
          cx + rotatedMouthEdge.dx,
          cy + rotatedMouthEdge.dy,
        );

        // Hedef şişenin ağız girişi (sıvının düştüğü nokta)
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

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Hedef şişe (arkada)
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
                ),
              ),
            ),
            // Kaynak şişe (akış ile birlikte çizilecek)
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
                // Sıvı stream'in başladığı global noktayı tube painter'a ilet
                // böylece tongue ile stream arasında boşluk kalmaz
                streamStartGlobal: isPouring ? globalStreamStart : null,
                tubeCanvasOffset: isPouring ? Offset(cx, cy) : null,
              ),
            ),
            // Kesintisiz akış çizgisi
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
    final innerBottom = kTBotY + kTR;
    final innerTop = kLiquidTopY;
    return innerBottom - (innerBottom - innerTop) * fillRatio;
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
// SIVI AKIŞI  –  Kesintisiz versiyon
// ─────────────────────────────────────────────

class _LiquidStreamPainter extends CustomPainter {
  final Color color;
  final Offset start; // global (kaynak ağız kenarı)
  final Offset end; // global (hedef sıvı yüzeyi)
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

    // Akışın kalınlığı
    final thickness = lerpDouble(2.2, 5.0, flowRate)!;

    // Bézier kontrol noktaları: başlangıç ve bitiş noktalarına teğet
    // böylece hem tube ağzından hem de hedef yüzeyden pürüzsüz giriş olur.
    final arc = max(6.0, dy.abs() * 0.08 + distance * 0.04);

    final c1 = Offset(
      start.dx + dx * 0.12,
      start.dy + arc,
    );
    final c2 = Offset(
      end.dx - dx * 0.10,
      end.dy - arc * 0.30,
    );

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    // Glow (dış parlaklık)
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.18 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness + 3.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    // Ana akış
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );

    // Beyaz öz (parlaklık)
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.20 * flowRate)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, thickness * 0.22)
        ..strokeCap = StrokeCap.round,
    );

    // (damlalar kaldırıldı)
  }

  @override
  bool shouldRepaint(_LiquidStreamPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.progress != progress ||
        oldDelegate.flowRate != flowRate ||
        oldDelegate.color != color;
  }
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
  // Yeni: stream'in başladığı global nokta (sadece kaynak tüpte kullanılır)
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
    this.streamStartGlobal,
    this.tubeCanvasOffset,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(kTW, kWidgetH),
      painter: _TubePainter(
        tube: tube,
        isSelected: isSelected,
        tilt: tilt,
        slosh: slosh,
        drainedVolume: drainedVolume,
        incomingColorIdx: incomingColorIdx,
        incomingVolume: incomingVolume,
        splash: splash,
        pourProgress: pourProgress,
        streamStartGlobal: streamStartGlobal,
        tubeCanvasOffset: tubeCanvasOffset,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HACİM / YÜZEY
// ─────────────────────────────────────────────

double _volumeUnitsForSurfaceY(double surfaceY) {
  if (surfaceY >= kTBotY + kTR) return 0.0;
  if (surfaceY <= kLiquidTopY) return kCap.toDouble();

  const r = kTR;
  double filledArea;

  if (surfaceY >= kTBotY) {
    final dy = kTBotY - surfaceY;
    final ratio = (dy / r).clamp(-1.0, 1.0);
    final aCap = r * r * acos(ratio) - dy * sqrt(max(0.0, r * r - dy * dy));
    filledArea = pi * r * r / 2.0 - aCap;
  } else {
    final straightFilled = kTBW * (kTBotY - surfaceY);
    filledArea = straightFilled + pi * r * r / 2.0;
  }

  final totalArea = kTBW * (kTBotY - kLiquidTopY) + pi * r * r / 2.0;
  return (filledArea / totalArea * kCap).clamp(0.0, kCap.toDouble());
}

double _surfaceYForVolumeUnits(double volumeUnits) {
  final clamped = volumeUnits.clamp(0.0, kCap.toDouble());
  if (clamped <= 0.0) return kTBotY + kTR;
  if (clamped >= kCap) return kLiquidTopY;

  double lo = kLiquidTopY;
  double hi = kTBotY + kTR;

  for (int i = 0; i < 48; i++) {
    final mid = (lo + hi) / 2;
    if (_volumeUnitsForSurfaceY(mid) < clamped) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return (lo + hi) / 2;
}

// ─────────────────────────────────────────────
// TÜP İÇİ SIVI GEOMETRİSİ  –  Gerçek yerçekimi fiziği
// ─────────────────────────────────────────────
//
// Tüp eğilince sıvı ALÇAK KENARA yığılır (gerçek fizik).
//   tilt < 0  → sola eğim  → sol kenar alçak (canvas'ta büyük Y) → sıvı sola yığılır
//   tilt > 0  → sağa eğim  → sağ kenar alçak (canvas'ta büyük Y) → sıvı sağa yığılır
//
// slope = tan(tilt) * halfW  → canvas'ta Y aşağı artar.
//   tilt<0 → tan<0 → slope<0
//   leftY  = midY - slope  = midY + |slope|  → büyük Y → alçak kenar  ✓
//   rightY = midY + slope  = midY - |slope|  → küçük Y → yüksek kenar ✓

double _surfaceSlope(double tilt, double slosh) {
  final raw = tan(tilt) * (kTBW / 2) + slosh * 5.0;
  return raw.clamp(-kTBodyH * 0.55, kTBodyH * 0.55);
}

({double leftY, double centerY, double rightY}) _surfacePoints({
  required double volume,
  required double tilt,
  required double slosh,
}) {
  final midY = _surfaceYForVolumeUnits(volume);
  final slope = _surfaceSlope(tilt, slosh);
  // tilt<0 → sola eğim (canvas sola döner) → sağ kenar alçak (büyük Y)
  // slope<0 → rightY = midY - slope = midY + |slope| → büyük = alçak ✓
  // leftY  = midY + slope = midY - |slope| → küçük = yüksek ✓
  final leftY = (midY + slope).clamp(kLiquidTopY, kTBotY + kTR);
  final rightY = (midY - slope).clamp(kLiquidTopY, kTBotY + kTR);
  return (leftY: leftY, centerY: (leftY + rightY) / 2.0, rightY: rightY);
}

Path _buildCompactLiquidBand({
  required double volumeBottom,
  required double volumeTop,
  required double tilt,
  required double slosh,
  required double flowBias,
}) {
  if (volumeTop <= volumeBottom + 0.001) return Path();

  final top = _surfacePoints(volume: volumeTop, tilt: tilt, slosh: slosh);
  final bot =
      _surfacePoints(volume: volumeBottom, tilt: tilt, slosh: slosh * 0.4);

  return Path()
    ..moveTo(kTX, top.leftY)
    ..quadraticBezierTo(kTX + kTBW / 2, top.centerY, kTX + kTBW, top.rightY)
    ..lineTo(kTX + kTBW, bot.rightY)
    ..quadraticBezierTo(kTX + kTBW / 2, bot.centerY, kTX, bot.leftY)
    ..close();
}

Path _buildCompactSurfaceLine({
  required double totalVolume,
  required double tilt,
  required double slosh,
  required double flowBias,
}) {
  final s = _surfacePoints(volume: totalVolume, tilt: tilt, slosh: slosh);
  return Path()
    ..moveTo(kTX, s.leftY)
    ..quadraticBezierTo(kTX + kTBW / 2, s.centerY, kTX + kTBW, s.rightY);
}

Offset _internalFlowTipLocal({
  required double tilt,
  required double totalVolume,
  required double flowBias,
}) {
  const mouthY = kTTopY + 0.6;
  final s = _surfacePoints(volume: totalVolume, tilt: tilt, slosh: 0.0);

  // tilt < 0 → sola eğim → sol kenar alçak → sol ağızdan akar
  // tilt > 0 → sağa eğim → sağ kenar alçak → sağ ağızdan akar
  // tilt<0 → sağ kenar alçak → sağ ağızdan akar
  // tilt>0 → sol kenar alçak → sol ağızdan akar
  if (tilt < 0) {
    return Offset(kTX + kTBW + 3.2, lerpDouble(s.rightY, mouthY, flowBias)!);
  } else {
    return Offset(kTX - 3.2, lerpDouble(s.leftY, mouthY, flowBias)!);
  }
}

Path _buildInternalFlowTongue({
  required double tilt,
  required double totalVolume,
  required double flowBias,
}) {
  if (flowBias <= 0.001 || totalVolume <= 0.001) return Path();

  final s = _surfacePoints(volume: totalVolume, tilt: tilt, slosh: 0.0);
  final thickness = lerpDouble(2.0, 5.0, flowBias)!;
  const neckInset = 3.2;
  const mouthY = kTTopY + 0.6;

  final path = Path();

  // tilt<0 → sağ kenar alçak → sağ ağızdan akar
  // tilt>0 → sol kenar alçak → sol ağızdan akar
  if (tilt < 0) {
    // Sağ ağızdan akar
    final rootX = kTX + kTBW - 7.0;
    final rootY = s.rightY;
    final tipX = kTX + kTBW + neckInset;
    final tipY = mouthY;

    path
      ..moveTo(rootX, rootY - thickness * 0.45)
      ..cubicTo(
        kTX + kTBW - 2.0,
        rootY - 2.0,
        kTX + kTBW + 0.5,
        tipY - 1.5,
        tipX,
        tipY - thickness * 0.45,
      )
      ..lineTo(tipX, tipY + thickness * 0.45)
      ..cubicTo(
        kTX + kTBW + 0.5,
        tipY + 1.5,
        kTX + kTBW - 2.0,
        rootY + 2.0,
        rootX,
        rootY + thickness * 0.45,
      )
      ..close();
  } else {
    // Sol ağızdan akar
    final rootX = kTX + 7.0;
    final rootY = s.leftY;
    final tipX = kTX - neckInset;
    final tipY = mouthY;

    path
      ..moveTo(rootX, rootY - thickness * 0.45)
      ..cubicTo(
        kTX + 2.0,
        rootY - 2.0,
        kTX - 0.5,
        tipY - 1.5,
        tipX,
        tipY - thickness * 0.45,
      )
      ..lineTo(tipX, tipY + thickness * 0.45)
      ..cubicTo(
        kTX - 0.5,
        tipY + 1.5,
        kTX + 2.0,
        rootY + 2.0,
        rootX,
        rootY + thickness * 0.45,
      )
      ..close();
  }

  return path;
}

// ─────────────────────────────────────────────
// TÜP PAINTER
// ─────────────────────────────────────────────

class _TubePainter extends CustomPainter {
  final List<int> tube;
  final bool isSelected;
  final double tilt;
  final double slosh;
  final double drainedVolume;
  final int? incomingColorIdx;
  final double incomingVolume;
  final double splash;
  final double pourProgress;
  final Offset? streamStartGlobal;
  final Offset? tubeCanvasOffset;

  const _TubePainter({
    required this.tube,
    required this.isSelected,
    required this.tilt,
    required this.slosh,
    required this.drainedVolume,
    required this.incomingColorIdx,
    required this.incomingVolume,
    required this.splash,
    required this.pourProgress,
    this.streamStartGlobal,
    this.tubeCanvasOffset,
  });

  static const double _topPad = 18.0;
  static const double _botPad = 18.0;
  static const double _pivotX = kTW / 2;
  static const double _pivotY = _topPad + kTH - _botPad;

  static const double _mouthLipOut = 3.6;
  static const double _mouthLipDown = 4.5;

  // Tüpün iç alanı: boyun + geniş gövde + yuvarlak alt
  // Boyun: dar, merkeze hizalı
  // Gövde: geniş, boyundan trapez geçişle açılıyor
  static const double _neckLeft = (kTW - kNeckW) / 2;
  static const double _neckRight = (kTW + kNeckW) / 2;

  Path _tubeClip() {
    final topPadY = _topPad;
    // Boyun üst kenarı
    final neckTopY = topPadY + 2.0;
    // Boyun alt = gövde başlangıcı
    final neckBotY = topPadY + kNeckH;
    // Gövde alt (düz kısım biter)
    final bodyBotY = topPadY + kTTopY + kTBodyH;
    final left = kTX;
    final right = kTX + kTBW;

    return Path()
      // Boyun sol üst → boyun sağ üst
      ..moveTo(_neckLeft, neckTopY)
      ..lineTo(_neckRight, neckTopY)
      // Boyun sağ → gövde sağ (trapez geçiş)
      ..lineTo(right, neckBotY)
      // Gövde sağ kenar düz
      ..lineTo(right, bodyBotY)
      // Yuvarlak alt
      ..arcToPoint(
        Offset(left, bodyBotY),
        radius: const Radius.circular(kTR),
        clockwise: false,
      )
      // Gövde sol kenar düz
      ..lineTo(left, neckBotY)
      // Sol trapez geçiş → boyun sol
      ..lineTo(_neckLeft, neckTopY)
      ..close();
  }

  Path _tubeOutline() {
    final topPadY = _topPad;
    final neckTopY = topPadY + 2.0;
    final neckBotY = topPadY + kNeckH;
    final bodyBotY = topPadY + kTTopY + kTBodyH;
    final left = kTX;
    final right = kTX + kTBW;
    // Kapak dudağı: boyun üstündeki küçük çıkıntı
    final capY = neckTopY - 3.0;
    final capLeft = _neckLeft - 3.0;
    final capRight = _neckRight + 3.0;

    return Path()
      // Kapak çizgisi (üstteki küçük dikdörtgen dudak)
      ..moveTo(_neckLeft, neckTopY)
      ..lineTo(capLeft, neckTopY)
      ..lineTo(capLeft, capY)
      ..lineTo(capRight, capY)
      ..lineTo(capRight, neckTopY)
      ..lineTo(_neckRight, neckTopY)
      // Boyun + gövde dış hattı
      ..moveTo(_neckLeft, neckTopY)
      ..lineTo(left, neckBotY)
      ..lineTo(left, bodyBotY)
      ..arcToPoint(
        Offset(right, bodyBotY),
        radius: const Radius.circular(kTR),
        clockwise: false,
      )
      ..lineTo(right, neckBotY)
      ..lineTo(_neckRight, neckTopY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final borderColor =
        isSelected ? const Color(0xFFD7D3FF) : Colors.white.withOpacity(0.74);

    final innerRect = Rect.fromLTWH(
      kTX,
      _topPad + kNeckH,
      kTBW,
      kTBodyH + kTR,
    );

    canvas.save();
    canvas.translate(_pivotX, _pivotY);
    canvas.rotate(tilt);
    canvas.translate(-_pivotX, -_pivotY);

    final clip = _tubeClip();

    canvas.save();
    canvas.clipPath(clip);

    // Tüp iç arka planı: koyu cam rengi (clip zaten uygulandı)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, kTW + 20, kWidgetH + 20),
      Paint()..color = const Color(0xFF1A1A2E).withOpacity(0.72),
    );
    // İnce sol yansıma
    canvas.drawRect(
      innerRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.transparent,
            Colors.black.withOpacity(0.10),
          ],
          stops: const [0.0, 0.35, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(innerRect),
    );

    canvas.translate(0, _topPad);

    final visualLayers = _buildVisualLayers(
      tube: tube,
      drainedVolume: drainedVolume,
      incomingColorIdx: incomingColorIdx,
      incomingVolume: incomingVolume,
    );

    double accum = 0.0;
    final totalVolume =
        visualLayers.fold<double>(0.0, (sum, e) => sum + e.volume);

    final topFlowBias = Curves.easeInOut.transform(
      (pourProgress.clamp(0.0, 1.0) * (tilt.abs() / 1.02)).clamp(0.0, 1.0),
    );

    for (int i = 0; i < visualLayers.length; i++) {
      final layer = visualLayers[i];
      final volumeBottom = accum;
      final volumeTop = accum + layer.volume;
      final fill = kColors[layer.colorIdx]['fill'] as Color;

      final isTopLayer = i == visualLayers.length - 1;

      final band = _buildCompactLiquidBand(
        volumeBottom: volumeBottom,
        volumeTop: volumeTop,
        tilt: tilt,
        slosh: isTopLayer ? slosh : slosh * 0.55,
        flowBias: 0.0,
      );

      canvas.drawPath(
        band,
        Paint()..color = fill,
      );

      canvas.drawPath(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.transparent,
              Colors.black.withOpacity(0.08),
            ],
            stops: const [0.0, 0.45, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(kTX, kLiquidTopY, kTBW, kTBodyH + kTR),
          ),
      );

      if (!isTopLayer) {
        final separator = _buildCompactSurfaceLine(
          totalVolume: volumeTop,
          tilt: tilt,
          slosh: slosh * 0.12,
          flowBias: 0.0,
        );

        canvas.drawPath(
          separator,
          Paint()
            ..color = Colors.black.withOpacity(0.12)
            ..strokeWidth = 0.9
            ..style = PaintingStyle.stroke,
        );
      }

      accum = volumeTop;
    }

    // Tongue (internal flow) – tam ağız kenarına ulaştırılmış
    if (totalVolume > 0.0001 &&
        topFlowBias > 0.001 &&
        visualLayers.isNotEmpty) {
      final topColor = kColors[visualLayers.last.colorIdx]['fill'] as Color;
      final tongue = _buildInternalFlowTongue(
        tilt: tilt,
        totalVolume: totalVolume,
        flowBias: topFlowBias,
      );

      canvas.drawPath(
        tongue,
        Paint()..color = topColor,
      );

      canvas.drawPath(
        tongue,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.transparent,
              Colors.black.withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(kTX - 10, kLiquidTopY, kTBW + 20, kTBodyH + kTR),
          ),
      );
    }

    if (totalVolume > 0.0001) {
      final topSurface = _buildCompactSurfaceLine(
        totalVolume: totalVolume,
        tilt: tilt,
        slosh: slosh,
        flowBias: topFlowBias,
      );

      canvas.drawPath(
        topSurface,
        Paint()
          ..color = Colors.white.withOpacity(0.26)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      canvas.drawPath(
        topSurface,
        Paint()
          ..color = Colors.white.withOpacity(0.10)
          ..strokeWidth = 3.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );

      if (splash > 0.02) {
        final tip = _internalFlowTipLocal(
          tilt: tilt,
          totalVolume: totalVolume,
          flowBias: topFlowBias,
        );

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(tip.dx, tip.dy - 0.4),
            width: lerpDouble(4.0, 8.0, splash)!,
            height: lerpDouble(0.8, 1.7, splash)!,
          ),
          Paint()..color = Colors.white.withOpacity(0.08 * splash),
        );
      }
    }

    canvas.restore(); // clip restore

    // (stream bağlantı damlası kaldırıldı)

    if (isSelected) {
      canvas.drawPath(
        _tubeOutline(),
        Paint()
          ..color = const Color(0xFFB8B0FF).withOpacity(0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
    }

    canvas.drawPath(
      _tubeOutline(),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.1 : 1.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Sol kenar parlak çizgi (cam yansıması)
    final neckBotY2 = _topPad + kNeckH;
    final bodyBotY2 = _topPad + kTTopY + kTBodyH;
    canvas.drawLine(
      Offset(kTX + 4.0, neckBotY2 + 6),
      Offset(kTX + 4.0, bodyBotY2 - 14),
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // Sağ kenar ince yansıma
    canvas.drawLine(
      Offset(kTX + kTBW - 4.0, neckBotY2 + 8),
      Offset(kTX + kTBW - 4.0, bodyBotY2 - 16),
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    // Kapak üstüne küçük highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_neckLeft + 2, _topPad - 1.0, kNeckW - 4, 3.0),
        const Radius.circular(1.5),
      ),
      Paint()..color = Colors.white.withOpacity(0.22),
    );

    canvas.restore(); // tilt restore
  }

  List<_VisualLayer> _buildVisualLayers({
    required List<int> tube,
    required double drainedVolume,
    required int? incomingColorIdx,
    required double incomingVolume,
  }) {
    final layers = <_VisualLayer>[];

    for (final color in tube) {
      if (layers.isNotEmpty && layers.last.colorIdx == color) {
        final last = layers.removeLast();
        layers.add(last.copyWith(volume: last.volume + 1.0));
      } else {
        layers.add(_VisualLayer(colorIdx: color, volume: 1.0));
      }
    }

    double drainLeft = drainedVolume.clamp(0.0, kCap.toDouble());

    while (drainLeft > 0.0001 && layers.isNotEmpty) {
      final last = layers.removeLast();
      if (last.volume > drainLeft) {
        layers.add(last.copyWith(volume: last.volume - drainLeft));
        drainLeft = 0.0;
      } else {
        drainLeft -= last.volume;
      }
    }

    if (incomingColorIdx != null && incomingVolume > 0.0001) {
      final currentTotal = layers.fold<double>(0.0, (s, e) => s + e.volume);
      final addable = min(incomingVolume, kCap - currentTotal);

      if (addable > 0.0001) {
        if (layers.isNotEmpty && layers.last.colorIdx == incomingColorIdx) {
          final last = layers.removeLast();
          layers.add(last.copyWith(volume: last.volume + addable));
        } else {
          layers.add(_VisualLayer(colorIdx: incomingColorIdx, volume: addable));
        }
      }
    }

    return layers.where((e) => e.volume > 0.0001).toList(growable: false);
  }

  @override
  bool shouldRepaint(_TubePainter oldDelegate) {
    return oldDelegate.tube != tube ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.tilt != tilt ||
        oldDelegate.slosh != slosh ||
        oldDelegate.drainedVolume != drainedVolume ||
        oldDelegate.incomingColorIdx != incomingColorIdx ||
        oldDelegate.incomingVolume != incomingVolume ||
        oldDelegate.splash != splash ||
        oldDelegate.pourProgress != pourProgress ||
        oldDelegate.streamStartGlobal != streamStartGlobal ||
        oldDelegate.tubeCanvasOffset != tubeCanvasOffset;
  }
}
