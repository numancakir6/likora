import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'start_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // LEXION - dokunulmadı
  static const int letterDuration = 800;
  static const int letterDelay = 150;
  static const int lexionPauseMs = 600;
  static const int fadeMs = 350;

  // LIKORA / loading
  static const int holdAfterFill = 700;
  static const int minStepMs = 220;

  final List<String> letters = [
    'assets/lexion/lexion_L.svg',
    'assets/lexion/lexion_E.svg',
    'assets/lexion/lexion_X.svg',
    'assets/lexion/lexion_I.svg',
    'assets/lexion/lexion_O.svg',
    'assets/lexion/lexion_N.svg',
  ];

  final List<int> order = [1, 4, 5, 3, 0, 2];

  late final List<AnimationController> _letterCtrls;
  late final List<Animation<double>> _letterAnims;

  late final AnimationController _fadeCtrl;
  late final AnimationController _fillCtrl;

  bool _showLikora = false;

  double _targetProgress = 0.0;
  Timer? _progressSmoother;

  @override
  void initState() {
    super.initState();

    _letterCtrls = List.generate(
      6,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: letterDuration),
      ),
    );

    _letterAnims = List.generate(6, (i) {
      return Tween<double>(begin: -1, end: 0).animate(
        CurvedAnimation(
          parent: _letterCtrls[i],
          curve: i == 2 ? Curves.easeInOut : Curves.bounceOut,
        ),
      );
    });

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: fadeMs),
    );

    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 300));

    for (int i = 0; i < 6; i++) {
      final idx = order[i];
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: letterDelay));
      }
      if (!mounted) return;
      await _letterCtrls[idx].forward().orCancel;
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: lexionPauseMs));

    if (!mounted) return;
    setState(() => _showLikora = true);

    await Future.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;

    unawaited(_fadeCtrl.forward());

    _startProgressSmoother();
    await _runLoadingSequence();
    await _waitUntilDisplayedProgressFinishes();

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: holdAfterFill));

    if (!mounted) return;
    _progressSmoother?.cancel();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const StartPage(),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        opaque: true,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _startProgressSmoother() {
    _progressSmoother?.cancel();

    _progressSmoother = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;

      final current = _fillCtrl.value;
      final target = _targetProgress;
      final diff = target - current;

      if (diff.abs() < 0.001) {
        _fillCtrl.value = target;
        return;
      }

      double step = diff * 0.055;

      if (step.abs() < 0.0012) {
        step = diff.isNegative ? -0.0012 : 0.0012;
      }

      final next = (current + step).clamp(0.0, 1.0);
      _fillCtrl.value = next;
    });
  }

  Future<void> _waitUntilDisplayedProgressFinishes() async {
    while (mounted && (_fillCtrl.value - _targetProgress).abs() > 0.002) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _runLoadingSequence() async {
    await _setProgress(0.0, immediate: true);

    await _runStep(
      targetProgress: 0.18,
      task: _precacheLikoraImages,
    );

    await _runStep(
      targetProgress: 0.34,
      task: _preloadLexionSvgAssets,
    );

    await _runStep(
      targetProgress: 0.52,
      task: _initializeGameServices,
    );

    await _runStep(
      targetProgress: 0.72,
      task: _loadGameData,
    );

    await _runStep(
      targetProgress: 0.88,
      task: _finalizeStartup,
    );

    await _setProgress(1.0);
  }

  Future<void> _runStep({
    required double targetProgress,
    required Future<void> Function() task,
  }) async {
    await Future.wait([
      task(),
      Future.delayed(const Duration(milliseconds: minStepMs)),
    ]);

    if (!mounted) return;
    await _setProgress(targetProgress);
  }

  Future<void> _setProgress(double target, {bool immediate = false}) async {
    final safeTarget = target.clamp(0.0, 1.0);

    if (immediate) {
      _targetProgress = safeTarget;
      _fillCtrl.value = safeTarget;
      return;
    }

    _targetProgress = safeTarget;
  }

  Future<void> _precacheLikoraImages() async {
    await precacheImage(
      const AssetImage('assets/likora/likora_logo.png'),
      context,
    );
    await precacheImage(
      const AssetImage('assets/likora/likora_logo_grey.png'),
      context,
    );
  }

  Future<void> _preloadLexionSvgAssets() async {
    for (final path in letters) {
      await rootBundle.loadString(path);
    }
  }

  Future<void> _initializeGameServices() async {
    await Future<void>.value();
  }

  Future<void> _loadGameData() async {
    await Future<void>.value();
  }

  Future<void> _finalizeStartup() async {
    await Future<void>.value();
  }

  @override
  void dispose() {
    _progressSmoother?.cancel();
    for (final c in _letterCtrls) {
      c.dispose();
    }
    _fadeCtrl.dispose();
    _fillCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final logoWidth = screenW * 0.72;

    return AnimatedBuilder(
      animation: Listenable.merge([
        ..._letterCtrls,
        _fadeCtrl,
        _fillCtrl,
      ]),
      builder: (_, __) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Opacity(
                opacity: 1 - _fadeCtrl.value,
                child: Center(
                  child: SizedBox(
                    width: logoWidth,
                    child: Stack(
                      alignment: Alignment.center,
                      children: List.generate(6, (i) {
                        final y = _letterAnims[i].value * (screenH + 200);

                        return Transform.translate(
                          offset: Offset(0, y),
                          child: SvgPicture.asset(
                            letters[i],
                            width: logoWidth,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              if (_showLikora)
                Opacity(
                  opacity: _fadeCtrl.value,
                  child: Center(
                    child: LikoraRevealLogo(
                      progress: _fillCtrl.value,
                      width: logoWidth,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class LikoraRevealLogo extends StatelessWidget {
  final double progress;
  final double width;

  const LikoraRevealLogo({
    super.key,
    required this.progress,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Image.asset(
            'assets/likora/likora_logo_grey.png',
            width: width,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          ClipRect(
            child: SizedBox(
              width: width * p,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: width,
                maxWidth: width,
                child: Image.asset(
                  'assets/likora/likora_logo.png',
                  width: width,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
