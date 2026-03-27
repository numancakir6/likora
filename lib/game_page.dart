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

/// Kaç adet döküleceğini hesapla (dökülmeyi simüle etmeden)
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
  // _displayTubes: animasyon süresince görüntülenen state.
  // Döküm BAŞLAMADAN önce from tüpü boşaltılmış, to tüpü dolmuş hali.
  // Bu sayede hedef tüp animasyon başından itibaren doğru görünür.
  late List<List<int>> _displayTubes;

  int? _selected;
  bool _animating = false;
  int? _flyFrom;
  int? _flyTo;
  // Uçuş animasyonu için: from tüpünün DÖKÜM ÖNCESİ içeriği
  List<int>? _flyFromSnapshot;
  // Hedef tüpe dökülen renk ve adet (canlı akış için)
  int? _pourColor;
  int _pourCount = 0;
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
        _displayTubes = _tubes.map((t) => List<int>.from(t)).toList();
        _selected = null;
        _animating = false;
        _flyFrom = null;
        _flyTo = null;
        _flyFromSnapshot = null;
        _pourColor = null;
        _pourCount = 0;
        _gameWon = false;
      });

  // Animasyon toplam: 1600 ms
  // 0–250ms  : kalk
  // 250–500ms: yatay git
  // 500–750ms: eğil (döküm bu süreçte başlar)
  // 750–1100ms: eğik kal + sıvı akar
  // 1100–1350ms: dik gel
  // 1350–1600ms: geri dön + in
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
    final fromSnapshot = List<int>.from(_tubes[from]);
    final topColor = _tubes[from].last;
    final count = pourCount(_tubes, from, to);

    // Hemen fiziksel dökmeyi yap → _displayTubes'u güncelle
    // Bu sayede hedef tüp animasyon BAŞINDAN itibaren doğru görünür
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

    await Future.delayed(const Duration(milliseconds: 1600));
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
          height: kWidgetH + 100,
          child: _TubeStage(
            // displayTubes: animasyon süresince gösterilen state
            // from tüpü gizli (opacity 0), to tüpü doğru içerikle
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
  void didUpdateWidget(_TubeStage old) {
    super.didUpdateWidget(old);
    if (widget.tubes.length != old.tubes.length) _rebuildKeys();
  }

  void _rebuildKeys() {
    _keys = List.generate(widget.tubes.length, (_) => GlobalKey());
  }

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
        // Statik tüpler
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
                      // Uçan tüp varken from tüpü gizli
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
// UÇAN TÜP — Düzeltilmiş fizik + canlı sıvı akışı
// ─────────────────────────────────────────────
//
// Animasyon fazları (0.0 – 1.0):
//   0.00–0.15 : Kalk (from pozisyonundan yukarı)
//   0.15–0.38 : Yatay git (to tüpünün üstüne)
//   0.38–0.58 : Eğil (~115°)
//   0.58–0.82 : Eğik kal → sıvı bu fazda canlı akar
//   0.82–0.92 : Dik gel
//   0.92–1.00 : Geri dön + in

class _FlyingTube extends StatefulWidget {
  final List<int> fromSnapshot; // from tüpünün DÖKÜM ÖNCESİ içeriği
  final List<int> toTube; // to tüpünün DÖKÜM SONRASI içeriği
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

  static const double _pLiftEnd = 0.15;
  static const double _pMoveEnd = 0.38;
  static const double _pTiltEnd = 0.58;
  static const double _pPourEnd = 0.82;
  static const double _pUprightEnd = 0.92;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static double _easeInOut(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  static double _phase(double v, double start, double end) =>
      ((v - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final fromPos = widget.getPos(widget.fromIdx);
    final toPos = widget.getPos(widget.toIdx);
    if (fromPos == null || toPos == null) return const SizedBox.shrink();

    final goRight = (toPos.dx + kWidgetW / 2) > (fromPos.dx + kWidgetW / 2);
    final tiltSign = goRight ? -1.0 : 1.0;
    final maxTilt = 115.0 * pi / 180.0;

    // Uçuş yüksekliği: her iki tüpün de üstünden yeterince yukarda
    final liftY = min(fromPos.dy, toPos.dy) - 70.0;

    // Hedef tüpün ağız pozisyonu (widget koordinatında)
    // Widget: checkmark(18) + kTTopY(4) = 22px'den sonra boru başlar
    final toMouthY = toPos.dy + 18.0 + kTTopY; // hedef boru ağzının Y'si
    final toMidX = toPos.dx + kWidgetW / 2; // hedef boru merkez X'i

    // Eğik haldeyken from tüpünün boru ağzı tam hedef boru ağzı üstünde olmalı.
    // Transform.bottomCenter dönme merkezi kullanıyoruz.
    // Tüp widget yüksekliği = kWidgetH, dönme merkezi alt-orta.
    // Eğik durumda tüpün ağzının global pozisyonu hesaplaması karmaşık —
    // basit yaklaşım: tüpün sol üst köşesini toMidX - kWidgetW/2, toMouthY - kWidgetH olarak konumlandır
    // ki dönme merkezi (alt-orta) tam toMidX, toMouthY+kWidgetH...
    // Aslında dönme merkezi (alt-orta) = (cx + kWidgetW/2, cy + kWidgetH)
    // Bunu toMidX, toMouthY'ye eşitlersek:
    //   cx = toMidX - kWidgetW/2
    //   cy = toMouthY - kWidgetH  (= toPos.dy + 18 + kTTopY - kWidgetH)
    final tiltedCX = toMidX - kWidgetW / 2;
    final tiltedCY = toMouthY - kWidgetH;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = _ctrl.value;

        // ── X pozisyonu ──────────────────────────────
        double cx;
        if (v < _pLiftEnd) {
          cx = fromPos.dx;
        } else if (v < _pMoveEnd) {
          cx = fromPos.dx +
              (tiltedCX - fromPos.dx) *
                  _easeInOut(_phase(v, _pLiftEnd, _pMoveEnd));
        } else if (v < _pUprightEnd) {
          cx = tiltedCX;
        } else {
          cx = tiltedCX +
              (fromPos.dx - tiltedCX) *
                  _easeInOut(_phase(v, _pUprightEnd, 1.0));
        }

        // ── Y pozisyonu ──────────────────────────────
        double cy;
        if (v < _pLiftEnd) {
          // Kalk: from pozisyonundan liftY'ye
          cy = fromPos.dy +
              (liftY - fromPos.dy) * _easeInOut(_phase(v, 0, _pLiftEnd));
        } else if (v < _pMoveEnd) {
          // Yatay hareket: yüksekliği koru
          cy = liftY +
              (tiltedCY - liftY) * _easeInOut(_phase(v, _pLiftEnd, _pMoveEnd));
        } else if (v < _pUprightEnd) {
          cy = tiltedCY;
        } else {
          // Geri in
          cy = tiltedCY +
              (fromPos.dy - tiltedCY) *
                  _easeInOut(_phase(v, _pUprightEnd, 1.0));
        }

        // ── Eğim açısı ───────────────────────────────
        double angle = 0;
        if (v >= _pMoveEnd && v < _pTiltEnd) {
          angle =
              tiltSign * maxTilt * _easeInOut(_phase(v, _pMoveEnd, _pTiltEnd));
        } else if (v >= _pTiltEnd && v < _pPourEnd) {
          angle = tiltSign * maxTilt;
        } else if (v >= _pPourEnd && v < _pUprightEnd) {
          angle = tiltSign *
              maxTilt *
              (1 - _easeInOut(_phase(v, _pPourEnd, _pUprightEnd)));
        }

        // ── Uçan tüpün içeriği ───────────────────────
        // Eğilme başladıktan sonra sıvı yavaş yavaş "boşalıyor" efekti:
        // pourProgress 0→1 iken from'daki dökülen renkleri sırayla kaldır
        final pourProgress = v >= _pTiltEnd && v < _pPourEnd
            ? _phase(v, _pTiltEnd, _pPourEnd)
            : (v >= _pPourEnd ? 1.0 : 0.0);

        // Kaç segment görünür kalsın (yukarıdan dökülüyor)
        final removedCount = (pourProgress * widget.pourCount).round();
        final flyTube = widget.fromSnapshot.sublist(
            0,
            (widget.fromSnapshot.length - removedCount)
                .clamp(0, widget.fromSnapshot.length));

        // ── Canlı sıvı akışı ─────────────────────────
        // Eğilme + dökme fazında sıvı damlacıkları göster
        final isPouring = v >= _pTiltEnd && v < _pPourEnd;
        final streamProgress =
            isPouring ? _phase(v, _pTiltEnd, _pPourEnd) : 0.0;

        // Sıvı akışının hedef noktası: hedef boru ağzı
        // Akışın başlangıç noktası: uçan tüpün (eğik haldeki) boru ağzı
        // Basit yaklaşım: akış toMidX etrafında, toMouthY'den boru içine iner
        final streamX = toMidX;
        final streamStartY = toMouthY - 8;
        // Akış ne kadar aşağı gitti (pourCount kadar segment dolduruyor)
        final filledHeight = widget.pourCount * kTSegH;
        final streamEndY =
            toMouthY + filledHeight * streamProgress.clamp(0.0, 1.0);

        final pourColor = widget.pourColorIdx != null
            ? (kColors[widget.pourColorIdx!]['fill'] as Color)
            : Colors.transparent;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Canlı sıvı akış çizgisi
            if (isPouring && widget.pourColorIdx != null)
              CustomPaint(
                painter: _LiquidStreamPainter(
                  color: pourColor,
                  startX: streamX,
                  startY: streamStartY,
                  endY: streamEndY,
                  progress: streamProgress,
                ),
                size: Size(MediaQuery.of(context).size.width, kWidgetH + 200),
              ),

            // Uçan tüp
            Positioned(
              left: cx,
              top: cy,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.rotationZ(angle),
                child: _TubeWidget(
                  tube: flyTube,
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
// SIYI AKIŞ ÇİZİCİ — Damlacıklar + akış çizgisi
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

    final paint = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = 5.0 + progress * 3
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.30)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Akış çizgisi
    final path = Path();
    path.moveTo(startX, startY);

    // Hafif dalgalı akış efekti
    final midY = (startY + endY) / 2;
    final wobble = sin(progress * pi * 3) * 2.0;
    path.cubicTo(
      startX + wobble,
      startY + (midY - startY) * 0.3,
      startX - wobble,
      startY + (midY - startY) * 0.7,
      startX,
      endY,
    );

    // Önce glow
    canvas.drawPath(path, glowPaint);
    // Sonra asıl çizgi
    canvas.drawPath(path, paint);

    // Akış ucunda damlacık
    final dropR = 4.0 + progress * 4;
    canvas.drawCircle(
        Offset(startX, endY),
        dropR,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, dropR * 0.5));

    // Küçük ek damlacıklar (fiziksel his)
    if (progress > 0.3) {
      for (int i = 0; i < 3; i++) {
        final t = (progress * 3 + i * 0.7) % 1.0;
        final y = startY + (endY - startY) * t;
        final r = 2.0 + t * 2;
        canvas.drawCircle(
          Offset(startX + sin(t * pi * 4 + i) * 3, y),
          r,
          Paint()..color = color.withOpacity(0.7 - t * 0.3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LiquidStreamPainter old) =>
      old.progress != progress || old.endY != endY;
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
            ? Text('✓',
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
// TÜP PAINTER — Sıvı yüzeyi + renk geçişleri
// ─────────────────────────────────────────────

class _TubePainter extends CustomPainter {
  final List<int> tube;
  final bool isSelected;

  const _TubePainter({required this.tube, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final borderColor =
        isSelected ? const Color(0xFF378ADD) : Colors.white.withOpacity(0.30);

    // Clip path — tüpün iç alanı
    final clip = Path()
      ..moveTo(kTX, kTTopY)
      ..lineTo(kTX, kTBotY)
      ..arcToPoint(Offset(kTX + kTBW, kTBotY),
          radius: const Radius.circular(kTR), clockwise: false)
      ..lineTo(kTX + kTBW, kTTopY)
      ..close();

    canvas.save();
    canvas.clipPath(clip);

    // Renk segmentleri — alt kısımdan yukarı doğru
    for (int i = 0; i < tube.length; i++) {
      final c = kColors[tube[i]]['fill'] as Color;
      final darkC = kColors[tube[i]]['dark'] as Color;
      final slotFromTop = kCap - 1 - i;
      final segY = kTTopY + slotFromTop * kTSegH;
      final h = (i == 0) ? kTSegH + kTR + 4 : kTSegH + 2;

      // Sıvı gradyan efekti (alt biraz koyu, üst biraz açık)
      final rect = Rect.fromLTWH(kTX, segY, kTBW, h);
      canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              colors: [c, darkC.withOpacity(0.85)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(rect));

      // Renk sınırlarında ince karanlık çizgi (sıvı katman ayrımı)
      if (i < tube.length - 1 && tube[i] != tube[i + 1]) {
        canvas.drawLine(
          Offset(kTX, segY),
          Offset(kTX + kTBW, segY),
          Paint()
            ..color = Colors.black.withOpacity(0.25)
            ..strokeWidth = 1.0,
        );
      }
    }

    canvas.restore();

    // Sıvı yüzeyi parlaklığı
    if (tube.isNotEmpty) {
      final surfY = kTTopY + (kCap - tube.length) * kTSegH;

      // Sıvı yüzeyi — hafif konveks görünüm için oval highlight
      final surfaceRect = Rect.fromLTWH(kTX + 2, surfY - 1, kTBW - 4, 5);
      canvas.drawOval(
          surfaceRect,
          Paint()
            ..color = Colors.white.withOpacity(0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));

      // Ana yüzey çizgisi
      canvas.drawLine(
          Offset(kTX + 3, surfY + 1.5),
          Offset(kTX + kTBW - 3, surfY + 1.5),
          Paint()
            ..color = Colors.white.withOpacity(0.50)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round);
    }

    // Seçim glow
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

    // Dış çizgi
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

    // Sol kenar yansıması
    canvas.drawLine(
        Offset(kTX + 5, kTTopY + 8),
        Offset(kTX + 5, kTBotY - 10),
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round);

    // Ağız kenarı
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
