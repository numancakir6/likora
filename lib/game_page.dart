import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
// OYUN SABİTLERİ
// ─────────────────────────────────────────────

const int kCap = 4;
const int kNColors = 5;
const int kEmpty = 2;

// Tüp çizim ölçüleri — Painter ile FlyingTube'da BİREBİR AYNI olmalı
const double kTW = 48.0; // CustomPaint genişliği
const double kTH = 140.0; // CustomPaint yüksekliği
const double kTX = 6.0; // sol kenar boşluğu
const double kTBW = 36.0; // iç boru genişliği
const double kTTopY = 4.0; // ağız Y
const double kTBodyH = 110.0; // gövde yüksekliği
const double kTR = kTBW / 2;
const double kTBotY = kTTopY + kTBodyH;
const double kTSegH = kTBodyH / kCap;

// _TubeWidget tam yüksekliği: checkmark(18) + paint(140) + gap(4) + label(14)
const double kWidgetH = 18.0 + kTH + 4.0 + 14.0; // 176
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
// OYUN MANTIĞI
// ─────────────────────────────────────────────

List<List<int>> generateTubes() {
  final rng = Random();
  final pool = <int>[];
  for (int i = 0; i < kNColors; i++) {
    for (int j = 0; j < kCap; j++) pool.add(i);
  }
  pool.shuffle(rng);
  final tubes = <List<int>>[];
  for (int i = 0; i < kNColors; i++) {
    tubes.add(pool.sublist(i * kCap, (i + 1) * kCap));
  }
  for (int i = 0; i < kEmpty; i++) tubes.add([]);
  return tubes;
}

bool canPour(List<List<int>> tubes, int from, int to) {
  if (tubes[from].isEmpty) return false;
  if (tubes[to].length >= kCap) return false;
  final top = tubes[from].last;
  if (tubes[to].isNotEmpty && tubes[to].last != top) return false;
  return true;
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

  const GamePage({super.key, required this.level, required this.mapNumber});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _pulseCtrl;

  int _starCount = 3;
  bool _isMuted = false;

  // Oyun state
  late List<List<int>> _tubes;
  int? _selected;
  bool _animating = false;
  int? _flyFrom;
  int? _flyTo;
  bool _gameWon = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _reset();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _tubes = generateTubes();
        _selected = null;
        _animating = false;
        _flyFrom = null;
        _flyTo = null;
        _gameWon = false;
      });

  // Animasyon toplam: 1700 ms
  // 0-300ms  : kalk + yatay git
  // 300-700ms: eğil  (600ms'de fiziksel dökme yapılır)
  // 700-1000ms: dik gel
  // 1000-1700ms: geri dön + in
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

    final from = _selected!, to = idx;
    setState(() {
      _selected = null;
      _animating = true;
      _flyFrom = from;
      _flyTo = to;
    });
    HapticFeedback.mediumImpact();

    // Eğilme pik noktasinda fiziksel dökme — hedef tüp anlık güncellenir
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => doPour(_tubes, from, to));

    await Future.delayed(const Duration(milliseconds: 1100));
    setState(() {
      _animating = false;
      _flyFrom = null;
      _flyTo = null;
      _gameWon = isGameDone(_tubes);
    });
  }

  void _completeLevel() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  void _cancelLevel() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08050D),
      body: Stack(children: [
        _AnimatedBg(controller: _bgCtrl),
        SafeArea(
          child: Column(children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(children: [
                  const SizedBox(height: 8),
                  _buildHeroCard(),
                  const SizedBox(height: 18),
                  _buildGameArea(),
                  const SizedBox(height: 18),
                  _buildTestPanel(),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── APP BAR ─────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        _GlassBtn(
          onTap: _cancelLevel,
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
        const Spacer(),
        Column(children: [
          Text('HARITA ${widget.mapNumber}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4)),
          const SizedBox(height: 2),
          Text('SEVIYE ${widget.level}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6)),
        ]),
        const Spacer(),
        _GlassBtn(
          onTap: () => setState(() => _isMuted = !_isMuted),
          child: Icon(_isMuted ? Icons.volume_off_rounded : Icons.pause_rounded,
              color: Colors.white, size: 20),
        ),
      ]),
    );
  }

  // ── HERO CARD ────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.09),
            Colors.white.withOpacity(0.03)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFF50057).withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Transform.scale(
            scale: 1 + _pulseCtrl.value * 0.06,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2E78), Color(0xFFFF8A00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFF50057).withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 1)
                ],
              ),
              child: const Icon(Icons.science_rounded,
                  color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Test Tupu Oyunu',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
              'Ayni renkleri ayni tuplerde topla! Tupe dokun, sonra dokulecek tupe dokun.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  // ── OYUN ALANI ───────────────────────────────

  Widget _buildGameArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.07),
            Colors.white.withOpacity(0.025)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Column(children: [
        // Başlık + yenile
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_gameWon ? 'Tamamlandi!' : 'Tupleri Sirala',
                    style: TextStyle(
                      color: _gameWon
                          ? const Color(0xFF13F08B)
                          : Colors.white.withOpacity(0.80),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 2),
                Text(
                    _gameWon
                        ? 'Harika! Tum renkler yerli yerinde.'
                        : 'Ayni renk -> ayni tup',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.40), fontSize: 11)),
              ])),
          GestureDetector(
            onTap: _animating ? null : _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded,
                    color: Colors.white.withOpacity(0.75), size: 14),
                const SizedBox(width: 5),
                Text('Yenile',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // SAHNE — uçuş için ekstra yükseklik payı
        SizedBox(
          height: kWidgetH + 80,
          child: _TubeStage(
            tubes: _tubes,
            selected: _selected,
            flyFrom: _flyFrom,
            flyTo: _flyTo,
            onTap: _handleTap,
          ),
        ),

        if (_selected != null) ...[
          const SizedBox(height: 10),
          Text('Simdi dokulecek tupe dokun',
              style: TextStyle(
                  color: const Color(0xFF378ADD).withOpacity(0.80),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }

  // ── TEST PANELİ ──────────────────────────────

  Widget _buildTestPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.09),
            Colors.white.withOpacity(0.03)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFFFFD740).withOpacity(0.15),
            border:
                Border.all(color: const Color(0xFFFFD740).withOpacity(0.30)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.science_rounded, color: Color(0xFFFFD740), size: 13),
            SizedBox(width: 5),
            Text('TEST PANELI',
                style: TextStyle(
                    color: Color(0xFFFFD740),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Tamamlama Yildizi',
            style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final filled = i < _starCount;
            return GestureDetector(
              onTap: () => setState(() => _starCount = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: filled
                      ? const Color(0xFFFFD740)
                      : Colors.white.withOpacity(0.22),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Center(
            child: Text('Secili yildiz: $_starCount',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: _ActionButton(
                  label: 'Iptal Et',
                  icon: Icons.close_rounded,
                  topColor: const Color(0xFF3A3248),
                  bottomColor: const Color(0xFF1A1525),
                  onTap: _cancelLevel)),
          const SizedBox(width: 12),
          Expanded(
              flex: 2,
              child: _ActionButton(
                  label: 'Seviyeyi Gec',
                  icon: Icons.check_circle_rounded,
                  topColor: const Color(0xFF13F08B),
                  bottomColor: const Color(0xFF0A6B40),
                  onTap: _completeLevel)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// TÜPLER SAHNESİ  (GlobalKey ile gerçek pozisyon)
// ─────────────────────────────────────────────

class _TubeStage extends StatefulWidget {
  final List<List<int>> tubes;
  final int? selected;
  final int? flyFrom;
  final int? flyTo;
  final void Function(int) onTap;

  const _TubeStage({
    required this.tubes,
    required this.selected,
    required this.flyFrom,
    required this.flyTo,
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
  void didUpdateWidget(_TubeStage old) {
    super.didUpdateWidget(old);
    if (widget.tubes.length != old.tubes.length) _rebuildKeys();
  }

  void _rebuildKeys() {
    _keys = List.generate(widget.tubes.length, (_) => GlobalKey());
  }

  /// Tüpün bu Stack içindeki yerel sol-üst köşesi
  Offset? _localPos(int idx) {
    final box = _keys[idx].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final stageBox = context.findRenderObject() as RenderBox?;
    if (stageBox == null) return null;
    return box.localToGlobal(Offset.zero) - stageBox.localToGlobal(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Statik tüpler — alta hizali
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
                        isDone: isTubeDone(widget.tubes[idx]),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // Uçan tüp
        if (widget.flyFrom != null && widget.flyTo != null)
          _FlyingTube(
            tubes: widget.tubes,
            fromIdx: widget.flyFrom!,
            toIdx: widget.flyTo!,
            getPos: _localPos,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// UÇAN TÜP — 4 fazlı animasyon + sıvı damlası
// ─────────────────────────────────────────────

class _FlyingTube extends StatefulWidget {
  final List<List<int>> tubes;
  final int fromIdx;
  final int toIdx;
  final Offset? Function(int) getPos;

  const _FlyingTube({
    required this.tubes,
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

  // Faz sinirlari (0.0–1.0 icinde)
  static const double _p1 = 0.18; // kalk+git biter
  static const double _p2 = 0.45; // egilme biter
  static const double _p3 = 0.62; // egik kalma biter
  static const double _p4 = 0.80; // dikilme biter

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static double _ease(double t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  static double _phase(double v, double start, double end) =>
      ((v - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final fromPos = widget.getPos(widget.fromIdx);
    final toPos = widget.getPos(widget.toIdx);
    if (fromPos == null || toPos == null) return const SizedBox.shrink();

    final goRight = (toPos.dx + kWidgetW / 2) > (fromPos.dx + kWidgetW / 2);
    final tiltSign = goRight ? -1.0 : 1.0;

    // Y referansları: checkmark payini (18px) hesaba kat
    final fromBotY = fromPos.dy + kWidgetH; // tup alti
    final liftY = fromPos.dy - 55.0; // ucus yuksekligi
    // Hizalama: ucan tupun alti, hedef tupun agziyla ayni seviyede olmali
    final toTubeTopY = toPos.dy + 18.0 + kTTopY; // hedef boru agzi

    // Dokulen renk
    final pourColor = widget.tubes[widget.fromIdx].isNotEmpty
        ? (kColors[widget.tubes[widget.fromIdx].last]['fill'] as Color)
        : Colors.transparent;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = _ctrl.value;

        // ── X ──────────────────────────────────────
        double cx;
        if (v < _p1) {
          cx = fromPos.dx + (toPos.dx - fromPos.dx) * _ease(_phase(v, 0, _p1));
        } else if (v < _p4) {
          cx = toPos.dx;
        } else {
          cx = toPos.dx + (fromPos.dx - toPos.dx) * _ease(_phase(v, _p4, 1.0));
        }

        // ── Y ──────────────────────────────────────
        // Tup tam egildikten sonra boru agzi hedef agzina denk gelmeli.
        // Egilmeden once yukarida (liftY), egilince asagi iner.
        double cy;
        if (v < _p1) {
          // Kalk
          cy = fromPos.dy + (liftY - fromPos.dy) * _ease(_phase(v, 0, _p1));
        } else if (v < _p2) {
          // Egilirken asagi in (boru agzi = hedef agzi)
          // Egik haldeyken dönme merkezi alt-merkez.
          // Basit yaklasim: tup ust kenarini hedef boru agziyla esitle
          final targetY = toTubeTopY -
              kTTopY -
              18.0; // widget top = boru agi - kTTopY - checkmark
          cy = liftY + (targetY - liftY) * _ease(_phase(v, _p1, _p2));
        } else if (v < _p4) {
          final targetY = toTubeTopY - kTTopY - 18.0;
          cy = targetY;
        } else {
          final targetY = toTubeTopY - kTTopY - 18.0;
          cy = targetY + (fromPos.dy - targetY) * _ease(_phase(v, _p4, 1.0));
        }

        // ── EGİM ───────────────────────────────────
        double angle = 0;
        if (v >= _p1 && v < _p2) {
          angle = tiltSign * 118 * pi / 180 * _ease(_phase(v, _p1, _p2));
        } else if (v >= _p2 && v < _p3) {
          angle = tiltSign * 118 * pi / 180;
        } else if (v >= _p3 && v < _p4) {
          angle = tiltSign * 118 * pi / 180 * (1 - _ease(_phase(v, _p3, _p4)));
        }

        // ── SIYI DAMLASI ───────────────────────────
        // Egik duruyorken (p1–p3) bir damla animasyonu goster
        final dropActive = v >= _p1 && v < _p3;
        final dropProgress = dropActive ? _phase(v, _p1, _p3) : 0.0;

        // Damlanin cikis noktasi: ucan tupun boru agzi
        // Egik haldeyken agiz biraz sola/saga kayar ama basit yaklas: to tupunun merkezi
        final toMidX = toPos.dx + kWidgetW / 2;
        final dropStartY = toTubeTopY - 20;
        final dropEndY = toTubeTopY + 10;
        final dropY = dropStartY + (dropEndY - dropStartY) * dropProgress;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Siyi damlasi
            if (dropActive)
              Positioned(
                left: toMidX - 5,
                top: dropY,
                child: _LiquidDrop(color: pourColor, progress: dropProgress),
              ),

            // Ucan tup
            Positioned(
              left: cx,
              top: cy,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.rotationZ(angle),
                child: _TubeWidget(
                  tube: widget.tubes[widget.fromIdx],
                  isSelected: false,
                  isDone: false,
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
// SIYI DAMLASI
// ─────────────────────────────────────────────

class _LiquidDrop extends StatelessWidget {
  final Color color;
  final double progress;

  const _LiquidDrop({required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    final size = 7.0 + progress * 5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.90),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.55), blurRadius: 8, spreadRadius: 2)
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TÜP WIDGET
// ─────────────────────────────────────────────

class _TubeWidget extends StatelessWidget {
  final List<int> tube;
  final bool isSelected;
  final bool isDone;

  const _TubeWidget(
      {required this.tube, required this.isSelected, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: 18,
        child: (isDone && tube.isNotEmpty)
            ? Text('v',
                style: TextStyle(
                    fontSize: 13,
                    color: kColors[tube[0]]['dark'] as Color,
                    fontWeight: FontWeight.bold))
            : null,
      ),
      CustomPaint(
        size: const Size(kTW, kTH),
        painter: _TubePainter(tube: tube, isSelected: isSelected),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 14,
        child: Text(
          (isDone && tube.isNotEmpty) ? kColors[tube[0]]['name'] as String : '',
          style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.55),
              fontWeight: FontWeight.w600),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// TÜP PAINTER
// ─────────────────────────────────────────────

class _TubePainter extends CustomPainter {
  final List<int> tube;
  final bool isSelected;

  const _TubePainter({required this.tube, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final borderColor =
        isSelected ? const Color(0xFF378ADD) : Colors.white.withOpacity(0.30);

    // Clip path
    final clip = Path()
      ..moveTo(kTX, kTTopY)
      ..lineTo(kTX, kTBotY)
      ..arcToPoint(Offset(kTX + kTBW, kTBotY),
          radius: const Radius.circular(kTR), clockwise: false)
      ..lineTo(kTX + kTBW, kTTopY)
      ..close();

    // Renk segmentleri
    canvas.save();
    canvas.clipPath(clip);
    for (int i = 0; i < tube.length; i++) {
      final c = kColors[tube[i]]['fill'] as Color;
      final slotFromTop = kCap - 1 - i;
      final segY = kTTopY + slotFromTop * kTSegH;
      final h = (i == 0) ? kTSegH + kTR + 2 : kTSegH + 1;
      canvas.drawRect(
        Rect.fromLTWH(kTX, segY, kTBW, h),
        Paint()..color = c,
      );
    }
    canvas.restore();

    // Yuzey parlakligı
    if (tube.isNotEmpty) {
      final surfY = kTTopY + (kCap - tube.length) * kTSegH + 3;
      canvas.drawLine(
          Offset(kTX + 4, surfY),
          Offset(kTX + kTBW - 4, surfY),
          Paint()
            ..color = Colors.white.withOpacity(0.45)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round);
    }

    // Secim glow
    if (isSelected) {
      final glow = Path()
        ..moveTo(kTX - 4, kTTopY)
        ..lineTo(kTX - 4, kTBotY)
        ..arcToPoint(Offset(kTX + kTBW + 4, kTBotY),
            radius: const Radius.circular(kTR + 4), clockwise: false)
        ..lineTo(kTX + kTBW + 4, kTTopY);
      canvas.drawPath(
          glow,
          Paint()
            ..color = const Color(0xFF378ADD).withOpacity(0.40)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round);
    }

    // Dis cizgi
    final outline = Path()
      ..moveTo(kTX, kTTopY)
      ..lineTo(kTX, kTBotY)
      ..arcToPoint(Offset(kTX + kTBW, kTBotY),
          radius: const Radius.circular(kTR), clockwise: false)
      ..lineTo(kTX + kTBW, kTTopY);
    canvas.drawPath(
        outline,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.2 : 1.5
          ..strokeCap = StrokeCap.round);

    // Yansima
    canvas.drawLine(
        Offset(kTX + 5, kTTopY + 8),
        Offset(kTX + 5, kTBotY - 10),
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round);

    // Agiz kenari
    canvas.drawLine(
        Offset(kTX, kTTopY),
        Offset(kTX + kTBW, kTTopY),
        Paint()
          ..color = borderColor
          ..strokeWidth = isSelected ? 2.2 : 2.0
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_TubePainter old) =>
      old.tube != tube || old.isSelected != isSelected;
}

// ─────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color topColor, bottomColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _tap.forward(),
      onTapUp: (_) => _tap.reverse().then((_) => widget.onTap()),
      onTapCancel: () => _tap.reverse(),
      child: AnimatedBuilder(
        animation: _tap,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - _tap.value * 0.04, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [widget.topColor, widget.bottomColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: widget.bottomColor.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, color: Colors.white, size: 18),
            const SizedBox(width: 7),
            Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GLASS BUTTON
// ─────────────────────────────────────────────

class _GlassBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlassBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ]),
          border: Border.all(color: Colors.white.withOpacity(0.11)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ANİMASYONLU ARKA PLAN
// ─────────────────────────────────────────────

class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF08050D),
              Color(0xFF12091A),
              Color(0xFF1A0B22),
              Color(0xFF08050D)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t = controller.value;
          final w = MediaQuery.of(context).size.width;
          final h = MediaQuery.of(context).size.height;
          return Stack(children: [
            _glow(-70 + sin(t * pi) * 20, -90 + cos(t * pi) * 18, 220,
                const Color(0xFFF50057).withOpacity(0.10)),
            _glow(w - 160 + cos(t * pi) * 20, 90 + sin(t * pi) * 18, 210,
                const Color(0xFF2979FF).withOpacity(0.08)),
            _glow(-60 + sin(t * pi * 1.3) * 14, h - 180 + cos(t * pi) * 18, 200,
                const Color(0xFF00E676).withOpacity(0.06)),
            _glow(w * 0.35, h * 0.30 + sin(t * pi * 2) * 12, 160,
                const Color(0xFFFFD740).withOpacity(0.05)),
          ]);
        },
      ),
    ]);
  }

  Widget _glow(double l, double top, double sz, Color c) => Positioned(
        left: l,
        top: top,
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
