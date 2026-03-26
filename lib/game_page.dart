import 'package:flutter/material.dart';

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
  late final AnimationController _bgController;
  int _starCount = 3; // Default star count for completion

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _completeLevel() {
    Navigator.pop(context, true); // true = level completed
  }

  void _failLevel() {
    Navigator.pop(context, false); // false = not completed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08050D),
      body: Stack(
        children: [
          // ── Animated background ──────────────────────────
          _AnimatedGameBackground(controller: _bgController),

          SafeArea(
            child: Column(
              children: [
                // ── App bar ──────────────────────────────────
                _buildAppBar(context),

                // ── Main game area ────────────────────────────
                Expanded(child: _buildGameArea()),

                // ── Debug / test control panel ────────────────
                _buildControlPanel(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _GlassBtn(
            onTap: () => Navigator.pop(context, false),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'HARİTA ${widget.mapNumber}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SEVİYE ${widget.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const Spacer(),
          _GlassBtn(
            onTap: () {}, // pause / settings
            child:
                const Icon(Icons.pause_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Game area placeholder ─────────────────────────────────────

  Widget _buildGameArea() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 140,
            height: 140,
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
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.videogame_asset_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Oyun Alanı',
            style: TextStyle(
              color: Colors.white.withOpacity(0.40),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Seviye ${widget.level} içeriği buraya gelecek',
            style: TextStyle(
              color: Colors.white.withOpacity(0.22),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Debug / test control panel ────────────────────────────────

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.09),
              Colors.white.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFFFD740).withOpacity(0.15),
                    border: Border.all(
                        color: const Color(0xFFFFD740).withOpacity(0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.bug_report_rounded,
                          color: Color(0xFFFFD740), size: 13),
                      SizedBox(width: 5),
                      Text(
                        'TEST PANELİ',
                        style: TextStyle(
                          color: Color(0xFFFFD740),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Star selector
            Text(
              'Tamamlama Yıldızı',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
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

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                // Fail / geri dön
                Expanded(
                  child: _ActionButton(
                    label: 'Başarısız',
                    icon: Icons.close_rounded,
                    topColor: const Color(0xFF3A3248),
                    bottomColor: const Color(0xFF1A1525),
                    onTap: _failLevel,
                  ),
                ),
                const SizedBox(width: 12),
                // Complete
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    label: 'Seviye Tamamla!',
                    icon: Icons.check_circle_rounded,
                    topColor: const Color(0xFF13F08B),
                    bottomColor: const Color(0xFF0A6B40),
                    onTap: _completeLevel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ACTION BUTTON
// ─────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
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
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
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
        builder: (_, child) => Transform.scale(
          scale: 1.0 - _tap.value * 0.04,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [widget.topColor, widget.bottomColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.bottomColor.withOpacity(0.40),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GLASS BUTTON
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
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.04),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.11)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ANIMATED BACKGROUND
// ─────────────────────────────────────────────

class _AnimatedGameBackground extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedGameBackground({required this.controller});

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
              Color(0xFF08050D),
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
            _glow(-60 + _sin(t) * 20, -80 + _cos(t) * 15, 220,
                const Color(0xFFF50057).withOpacity(0.10)),
            _glow(w - 140 + _cos(t) * 20, 80 + _sin(t) * 18, 200,
                const Color(0xFF2979FF).withOpacity(0.08)),
            _glow(-60 + _sin(t * 1.3) * 16, h - 160 + _cos(t) * 20, 200,
                const Color(0xFF00E676).withOpacity(0.06)),
          ]);
        },
      ),
    ]);
  }

  double _sin(double t) => (t * 3.14159).toString().length > 0
      ? (t * 3.14159 * 2).abs() % (3.14159 * 2) > 3.14159
          ? -(t * 2 - 1).abs()
          : (t * 2 - 1).abs()
      : 0;
  double _cos(double t) => _sin(t + 0.25);

  Widget _glow(double l, double top, double sz, Color c) {
    return Positioned(
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
}
