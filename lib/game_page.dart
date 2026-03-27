import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
// OYUN SABİTLERİ
// ─────────────────────────────────────────────

const int kCap = 4;
const int kNColors = 5;
const int kEmpty = 2;

const double kTW = 48.0;
const double kTH = 140.0;
const double kTX = 6.0;
const double kTBW = 36.0;
const double kTTopY = 4.0;
const double kTBodyH = 110.0;
const double kTR = kTBW / 2;
const double kTBotY = kTTopY + kTBodyH;
const double kTSegH = kTBodyH / kCap;

const double kWidgetH = 18.0 + kTH + 4.0 + 14.0;
const double kWidgetW = kTW;
const double kTubeGap = 14.0;

const List<Map<String, dynamic>> kColors = [
  {'name': 'Kirmizi', 'fill': Color(0xFFE24B4A), 'dark': Color(0xFFA32D2D)},
  {'name': 'Mavi', 'fill': Color(0xFF378ADD), 'dark': Color(0xFF185FA5)},
  {'name': 'Yesil', 'fill': Color(0xFF639922), 'dark': Color(0xFF3B6D11)},
  {'name': 'Mor', 'fill': Color(0xFF7F77DD), 'dark': Color(0xFF534AB7)},
  {'name': 'Turuncu', 'fill': Color(0xFFEF9F27), 'dark': Color(0xFF854F0B)},
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
        bgTop: Color(0xFF0C1021),
        bgBottom: Color(0xFF161126),
        glowA: Color(0xFF2D7CFF),
        glowB: Color(0xFF7B4DFF),
        panel: Color(0x221A2340),
        panelBorder: Color(0x33FFFFFF),
        accent: Color(0xFF86A8FF),
      );
    case 1:
      return const _MapTheme(
        bgTop: Color(0xFF102317),
        bgBottom: Color(0xFF0A1711),
        glowA: Color(0xFF19C37D),
        glowB: Color(0xFF7ED957),
        panel: Color(0x2214261D),
        panelBorder: Color(0x33FFFFFF),
        accent: Color(0xFF7ED957),
      );
    case 2:
      return const _MapTheme(
        bgTop: Color(0xFF25150E),
        bgBottom: Color(0xFF140D0A),
        glowA: Color(0xFFFFA726),
        glowB: Color(0xFFFF7043),
        panel: Color(0x22261912),
        panelBorder: Color(0x33FFFFFF),
        accent: Color(0xFFFFB74D),
      );
    case 3:
      return const _MapTheme(
        bgTop: Color(0xFF1A1026),
        bgBottom: Color(0xFF0E0A16),
        glowA: Color(0xFF9C6BFF),
        glowB: Color(0xFFFF4FC3),
        panel: Color(0x221E1530),
        panelBorder: Color(0x33FFFFFF),
        accent: Color(0xFFD1A6FF),
      );
    default:
      return const _MapTheme(
        bgTop: Color(0xFF0D1E21),
        bgBottom: Color(0xFF091214),
        glowA: Color(0xFF00BCD4),
        glowB: Color(0xFF26A69A),
        panel: Color(0x2213262A),
        panelBorder: Color(0x33FFFFFF),
        accent: Color(0xFF7BE7F3),
      );
  }
}

// ─────────────────────────────────────────────
// OYUN MANTIĞI
// ─────────────────────────────────────────────

List<List<int>> generateTubes() {
  final rng = Random();
  final pool = <int>[];
  for (int i = 0; i < kNColors; i++) {
    for (int j = 0; j < kCap; j++) {
      pool.add(i);
    }
  }
  pool.shuffle(rng);

  final tubes = <List<int>>[];
  for (int i = 0; i < kNColors; i++) {
    tubes.add(pool.sublist(i * kCap, (i + 1) * kCap));
  }
  for (int i = 0; i < kEmpty; i++) {
    tubes.add([]);
  }
  return tubes;
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

  int? _flyFrom;
  int? _flyTo;
  List<int>? _flyFromSnapshot;
  int? _pourColor;
  int _pourCount = 0;
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
    _flyFrom = null;
    _flyTo = null;
    _flyFromSnapshot = null;
    _pourColor = null;
    _pourCount = 0;
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

    if (!canPour(_tubes, _selected!, idx)) {
      HapticFeedback.lightImpact();
      setState(() => _selected = null);
      return;
    }

    final from = _selected!;
    final to = idx;
    final fromSnapshot = List<int>.from(_tubes[from]);
    final topColor = _tubes[from].last;
    final count = pourCount(_tubes, from, to);

    doPour(_tubes, from, to);
    final displayTubes = _tubes.map((t) => List<int>.from(t)).toList();

    setState(() {
      _selected = null;
      _animating = true;
      _flyFrom = from;
      _flyTo = to;
      _flyFromSnapshot = fromSnapshot;
      _pourColor = topColor;
      _pourCount = count;
      _displayTubes = displayTubes;
    });

    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 1650));

    setState(() {
      _animating = false;
      _flyFrom = null;
      _flyTo = null;
      _flyFromSnapshot = null;
      _pourColor = null;
      _pourCount = 0;
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
                                  height: kWidgetH + 100,
                                  child: _TubeStage(
                                    tubes: _displayTubes,
                                    selected: _selected,
                                    flyFrom: _flyFrom,
                                    flyTo: _flyTo,
                                    flyFromSnapshot: _flyFromSnapshot,
                                    pourColor: _pourColor,
                                    pourCount: _pourCount,
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
                color: theme.glowA.withOpacity(0.22),
              ),
            ),
            Positioned(
              top: 120,
              right: -70 + t * 50,
              child: _GlowBlob(
                size: 260,
                color: theme.glowB.withOpacity(0.18),
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
  final int? flyFrom;
  final int? flyTo;
  final List<int>? flyFromSnapshot;
  final int? pourColor;
  final int pourCount;
  final void Function(int) onTap;

  const _TubeStage({
    required this.tubes,
    required this.selected,
    required this.flyFrom,
    required this.flyTo,
    required this.flyFromSnapshot,
    required this.pourColor,
    required this.pourCount,
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
                      opacity: idx == widget.flyFrom ? 0.0 : 1.0,
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
        if (widget.flyFrom != null &&
            widget.flyTo != null &&
            widget.flyFromSnapshot != null)
          _FlyingTube(
            fromSnapshot: widget.flyFromSnapshot!,
            toTube: widget.tubes[widget.flyTo!],
            pourColorIdx: widget.pourColor,
            pourCount: widget.pourCount,
            fromIdx: widget.flyFrom!,
            toIdx: widget.flyTo!,
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
  final List<int> fromSnapshot;
  final List<int> toTube;
  final int? pourColorIdx;
  final int pourCount;
  final int fromIdx;
  final int toIdx;
  final Offset? Function(int) getPos;

  const _FlyingTube({
    required this.fromSnapshot,
    required this.toTube,
    required this.pourColorIdx,
    required this.pourCount,
    required this.fromIdx,
    required this.toIdx,
    required this.getPos,
  });

  @override
  State<_FlyingTube> createState() => _FlyingTubeState();
}

class _FlyingTubeState extends State<_FlyingTube>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const double _pLiftEnd = 0.16;
  static const double _pMoveEnd = 0.40;
  static const double _pTiltEnd = 0.56;
  static const double _pPourEnd = 0.84;
  static const double _pUprightEnd = 0.93;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static double _easeInOut(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  static double _easeOut(double t) => 1 - pow(1 - t, 3).toDouble();

  static double _phase(double v, double start, double end) =>
      ((v - start) / (end - start)).clamp(0.0, 1.0);

  Offset _tubeMouthLocal() {
    return Offset(kTW / 2, 18.0 + kTTopY + 1.5);
  }

  Offset _anchorLocal() {
    return Offset(kTW / 2, kWidgetH);
  }

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

  @override
  Widget build(BuildContext context) {
    final fromPos = widget.getPos(widget.fromIdx);
    final toPos = widget.getPos(widget.toIdx);
    if (fromPos == null || toPos == null) return const SizedBox.shrink();

    final fromMidX = fromPos.dx + kWidgetW / 2;
    final toMidX = toPos.dx + kWidgetW / 2;
    final goRight = toMidX > fromMidX;

    final tiltSign = goRight ? -1.0 : 1.0;
    final maxTilt = 82.0 * pi / 180.0;
    final liftY = min(fromPos.dy, toPos.dy) - 78.0;

    final targetMouth = Offset(
      toMidX,
      toPos.dy + 18.0 + kTTopY + 3.0,
    );

    final mouthLocal = _tubeMouthLocal();
    final anchorLocal = _anchorLocal();

    Offset topLeftForAngle(double angle) {
      final rotatedMouth = _rotateAroundAnchor(mouthLocal, anchorLocal, angle);
      return Offset(
        targetMouth.dx - rotatedMouth.dx,
        targetMouth.dy - rotatedMouth.dy - 4.0,
      );
    }

    final pourTopLeft = topLeftForAngle(tiltSign * maxTilt);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = _ctrl.value;

        double cx;
        if (v < _pLiftEnd) {
          cx = fromPos.dx;
        } else if (v < _pMoveEnd) {
          cx = fromPos.dx +
              (pourTopLeft.dx - fromPos.dx) *
                  _easeInOut(_phase(v, _pLiftEnd, _pMoveEnd));
        } else if (v < _pUprightEnd) {
          cx = pourTopLeft.dx;
        } else {
          cx = pourTopLeft.dx +
              (fromPos.dx - pourTopLeft.dx) *
                  _easeInOut(_phase(v, _pUprightEnd, 1.0));
        }

        double cy;
        if (v < _pLiftEnd) {
          cy = fromPos.dy +
              (liftY - fromPos.dy) * _easeInOut(_phase(v, 0, _pLiftEnd));
        } else if (v < _pMoveEnd) {
          cy = liftY +
              (pourTopLeft.dy - liftY) *
                  _easeInOut(_phase(v, _pLiftEnd, _pMoveEnd));
        } else if (v < _pUprightEnd) {
          cy = pourTopLeft.dy;
        } else {
          cy = pourTopLeft.dy +
              (fromPos.dy - pourTopLeft.dy) *
                  _easeInOut(_phase(v, _pUprightEnd, 1.0));
        }

        double angle = 0.0;
        if (v >= _pMoveEnd && v < _pTiltEnd) {
          angle =
              tiltSign * maxTilt * _easeOut(_phase(v, _pMoveEnd, _pTiltEnd));
        } else if (v >= _pTiltEnd && v < _pPourEnd) {
          angle = tiltSign * maxTilt;
        } else if (v >= _pPourEnd && v < _pUprightEnd) {
          angle = tiltSign *
              maxTilt *
              (1.0 - _easeInOut(_phase(v, _pPourEnd, _pUprightEnd)));
        }

        final pourProgress = v >= _pTiltEnd && v < _pPourEnd
            ? _phase(v, _pTiltEnd, _pPourEnd)
            : (v >= _pPourEnd ? 1.0 : 0.0);

        final removedCount = (pourProgress * widget.pourCount).floor();
        final flyTube = widget.fromSnapshot.sublist(
          0,
          (widget.fromSnapshot.length - removedCount)
              .clamp(0, widget.fromSnapshot.length),
        );

        final isPouring = v >= _pTiltEnd &&
            v < _pPourEnd &&
            widget.pourColorIdx != null &&
            widget.pourCount > 0;

        final rotatedMouth =
            _rotateAroundAnchor(mouthLocal, anchorLocal, angle);

        final globalMouth = Offset(
          cx + rotatedMouth.dx,
          cy + rotatedMouth.dy,
        );

        final filledHeight = widget.pourCount * kTSegH;
        final streamProgress =
            isPouring ? _phase(v, _pTiltEnd, _pPourEnd) : 0.0;

        final streamEndY =
            targetMouth.dy + filledHeight * streamProgress.clamp(0.0, 1.0);

        final pourColor = widget.pourColorIdx != null
            ? (kColors[widget.pourColorIdx!]['fill'] as Color)
            : Colors.transparent;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (isPouring)
              CustomPaint(
                painter: _LiquidStreamPainter(
                  color: pourColor,
                  startX: globalMouth.dx,
                  startY: globalMouth.dy,
                  endY: streamEndY,
                  progress: streamProgress,
                ),
                size: Size(
                  MediaQuery.of(context).size.width,
                  kWidgetH + 220,
                ),
              ),
            Positioned(
              left: cx,
              top: cy,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.rotationZ(angle),
                child: _TubeWidget(
                  tube: flyTube,
                  isSelected: false,
                ),
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
  final double startX;
  final double startY;
  final double endY;
  final double progress;

  const _LiquidStreamPainter({
    required this.color,
    required this.startX,
    required this.startY,
    required this.endY,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    if (endY <= startY) return;

    final end = Offset(startX, endY);
    final h = endY - startY;

    final path = Path()..moveTo(startX, startY);
    path.cubicTo(
      startX + 1.5,
      startY + h * 0.18,
      startX - 2.0,
      startY + h * 0.62,
      end.dx,
      end.dy,
    );

    final glowPaint = Paint()
      ..color = color.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    final streamPaint = Paint()
      ..color = color.withOpacity(0.96)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, streamPaint);

    canvas.drawCircle(
      end,
      2.8,
      Paint()..color = color.withOpacity(0.95),
    );
  }

  @override
  bool shouldRepaint(_LiquidStreamPainter oldDelegate) {
    return oldDelegate.startX != startX ||
        oldDelegate.startY != startY ||
        oldDelegate.endY != endY ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────
// TÜP WIDGET
// ─────────────────────────────────────────────

class _TubeWidget extends StatelessWidget {
  final List<int> tube;
  final bool isSelected;

  const _TubeWidget({
    required this.tube,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 18),
        CustomPaint(
          size: const Size(kTW, kTH),
          painter: _TubePainter(
            tube: tube,
            isSelected: isSelected,
          ),
        ),
        const SizedBox(height: 4),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TÜP PAINTER
// ─────────────────────────────────────────────

class _TubePainter extends CustomPainter {
  final List<int> tube;
  final bool isSelected;

  const _TubePainter({
    required this.tube,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderColor =
        isSelected ? const Color(0xFF86A8FF) : Colors.white.withOpacity(0.32);

    final clip = Path()
      ..moveTo(kTX, kTTopY)
      ..lineTo(kTX, kTBotY)
      ..arcToPoint(
        Offset(kTX + kTBW, kTBotY),
        radius: const Radius.circular(kTR),
        clockwise: false,
      )
      ..lineTo(kTX + kTBW, kTTopY)
      ..close();

    canvas.save();
    canvas.clipPath(clip);

    for (int i = 0; i < tube.length; i++) {
      final c = kColors[tube[i]]['fill'] as Color;
      final darkC = kColors[tube[i]]['dark'] as Color;
      final slotFromTop = kCap - 1 - i;
      final segY = kTTopY + slotFromTop * kTSegH;
      final h = (i == 0) ? kTSegH + kTR + 4 : kTSegH + 2;

      final rect = Rect.fromLTWH(kTX, segY, kTBW, h);

      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [c, darkC.withOpacity(0.90)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );

      if (i < tube.length - 1 && tube[i] != tube[i + 1]) {
        canvas.drawLine(
          Offset(kTX, segY),
          Offset(kTX + kTBW, segY),
          Paint()
            ..color = Colors.black.withOpacity(0.24)
            ..strokeWidth = 1.0,
        );
      }
    }

    canvas.restore();

    if (tube.isNotEmpty) {
      final surfY = kTTopY + (kCap - tube.length) * kTSegH;
      final surfaceRect = Rect.fromLTWH(kTX + 2, surfY - 1, kTBW - 4, 5);

      canvas.drawOval(
        surfaceRect,
        Paint()
          ..color = Colors.white.withOpacity(0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );

      canvas.drawLine(
        Offset(kTX + 3, surfY + 1.5),
        Offset(kTX + kTBW - 3, surfY + 1.5),
        Paint()
          ..color = Colors.white.withOpacity(0.42)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }

    if (isSelected) {
      final glow = Path()
        ..moveTo(kTX - 4, kTTopY)
        ..lineTo(kTX - 4, kTBotY)
        ..arcToPoint(
          Offset(kTX + kTBW + 4, kTBotY),
          radius: const Radius.circular(kTR + 4),
          clockwise: false,
        )
        ..lineTo(kTX + kTBW + 4, kTTopY);

      canvas.drawPath(
        glow,
        Paint()
          ..color = const Color(0xFF86A8FF).withOpacity(0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );
    }

    final outline = Path()
      ..moveTo(kTX, kTTopY)
      ..lineTo(kTX, kTBotY)
      ..arcToPoint(
        Offset(kTX + kTBW, kTBotY),
        radius: const Radius.circular(kTR),
        clockwise: false,
      )
      ..lineTo(kTX + kTBW, kTTopY);

    canvas.drawPath(
      outline,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.1 : 1.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      Offset(kTX + 5, kTTopY + 8),
      Offset(kTX + 5, kTBotY - 10),
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      Offset(kTX, kTTopY),
      Offset(kTX + kTBW, kTTopY),
      Paint()
        ..color = borderColor
        ..strokeWidth = isSelected ? 2.1 : 1.9
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TubePainter oldDelegate) {
    return oldDelegate.tube != tube || oldDelegate.isSelected != isSelected;
  }
}
