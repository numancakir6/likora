import 'dart:async';

import 'package:flutter/material.dart';

import 'audio_service.dart';
import 'daily_puzzle_generator.dart';
import 'daily_puzzle_progress.dart';
import 'game_page.dart';
import 'player_progress.dart';
import 'settings_page.dart';

class DailyPuzzlePage extends StatefulWidget {
  const DailyPuzzlePage({super.key});

  @override
  State<DailyPuzzlePage> createState() => _DailyPuzzlePageState();
}

class _DailyPuzzlePageState extends State<DailyPuzzlePage> {
  Timer? _countdownTimer;

  bool _loading = true;
  bool _completedToday = false;

  late DailyPuzzleData _dailyPuzzle;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _playClick() async {
    await SfxService.playClick();
  }

  Future<void> _vibrateTap() async {
    await SettingsPage.vibrateTap();
  }

  Future<void> _loadPage() async {
    final now = DateTime.now().toLocal();
    final dailyPuzzle = DailyPuzzleGenerator.generateForDate(now);
    final dateKey = dailyPuzzle.dateKey;

    await PlayerProgress.ensureLoaded();
    await DailyPuzzleProgress.prepareForDate(dateKey);

    final completed = await DailyPuzzleProgress.isCompleted(dateKey);

    _countdownTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _dailyPuzzle = dailyPuzzle;
      _completedToday = completed;
      _timeLeft = _durationUntilNextMidnight();
      _loading = false;
    });

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final left = _durationUntilNextMidnight();

      if (!mounted) return;

      if (left.inSeconds <= 0) {
        await _loadPage();
        return;
      }

      setState(() {
        _timeLeft = left;
      });
    });
  }

  Duration _durationUntilNextMidnight() {
    final now = DateTime.now().toLocal();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    return nextMidnight.difference(now);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 999999);
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  bool get _isBlindPuzzle => _dailyPuzzle.mapStyle == DailyPuzzleMapStyle.map2;

  String _difficultyText(int difficulty) {
    switch (difficulty) {
      case 2:
        return 'KOLAY';
      case 3:
        return 'ORTA';
      case 4:
        return 'ZOR';
      case 5:
        return 'DAHA ZOR';
      case 6:
        return 'EXTREME';
      default:
        return 'ORTA';
    }
  }

  int _rewardForDifficulty(int difficulty) {
    switch (difficulty) {
      case 2:
        return 50;
      case 3:
        return 100;
      case 4:
        return 150;
      case 5:
        return 200;
      case 6:
        return 300;
      default:
        return 100;
    }
  }

  int _syntheticDailyLevelId(String dateKey) {
    if (dateKey.length >= 6) {
      return int.tryParse(dateKey.substring(dateKey.length - 6)) ?? 900001;
    }
    return 900001;
  }

  List<Color> _dailyBackground(String dateKey) {
    final seed = int.tryParse(dateKey) ?? 1;

    const palettes = <List<Color>>[
      [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      [Color(0xFF141E30), Color(0xFF243B55)],
      [Color(0xFF1A2980), Color(0xFF26D0CE)],
      [Color(0xFF000046), Color(0xFF1CB5E0)],
      [Color(0xFF232526), Color(0xFF414345)],
      [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF3A506B)],
      [Color(0xFF0A1931), Color(0xFF185ADB), Color(0xFF00A8CC)],
    ];

    return palettes[seed % palettes.length];
  }

  Color _accentColor() {
    return _isBlindPuzzle ? const Color(0xFF8E63D8) : const Color(0xFFFF8A3D);
  }

  IconData _dailyIcon() {
    if (_isBlindPuzzle) {
      return Icons.visibility_off_outlined;
    }
    return Icons.extension_rounded;
  }

  Future<void> _openDailyGame() async {
    await _playClick();
    await _vibrateTap();

    if (!mounted) return;

    final reward = _rewardForDifficulty(_dailyPuzzle.difficulty);

    DailyPuzzleSaveState? savedState;
    if (!_completedToday) {
      savedState =
          await DailyPuzzleProgress.getInProgressState(_dailyPuzzle.dateKey);
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<GamePageResult>(
      MaterialPageRoute(
        builder: (_) => GamePage(
          level: _syntheticDailyLevelId(_dailyPuzzle.dateKey),
          mapNumber: _dailyPuzzle.mapNumber,
          difficulty: _dailyPuzzle.difficulty,
          initialCoins: PlayerProgress.coins.value,
          customPuzzleTubes: _dailyPuzzle.tubes,
          customLockedAdTubeIndex: _dailyPuzzle.lockedAdTubeIndex,
          customStageLayout: _dailyPuzzle.layout,
          isDailyPuzzleMode: true,
          dailyPuzzleDateKey: _dailyPuzzle.dateKey,
          dailyRewardCoins: reward,
          restoredDailyState: savedState,
          customTitle: 'GÜNLÜK BULMACA',
          customBackground: _dailyBackground(_dailyPuzzle.dateKey),
        ),
      ),
    );

    if (!mounted) return;

    if (result?.completed == true) {
      await DailyPuzzleProgress.markCompleted(_dailyPuzzle.dateKey);

      final rewardClaimed =
          await DailyPuzzleProgress.isRewardClaimed(_dailyPuzzle.dateKey);

      if (!rewardClaimed) {
        PlayerProgress.addCoins(reward);
        await DailyPuzzleProgress.markRewardClaimed(_dailyPuzzle.dateKey);
      }

      await DailyPuzzleProgress.clearInProgressState();
    }

    await _loadPage();

    if (!mounted) return;

    if (result?.completed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Günlük bulmacayı tamamladın. +$reward'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  Widget _rewardCoinIcon() {
    return const Icon(
      Icons.toll_rounded,
      color: Color(0xFFFFC83D),
      size: 18,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0415),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () async {
            await _playClick();
            await _vibrateTap();
            if (!context.mounted) return;
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'GÜNLÜK BULMACA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6D00),
              ),
            )
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _completedToday
                        ? _buildCompletedCard(accent)
                        : _buildAvailableCard(accent),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAvailableCard(Color accent) {
    final reward = _rewardForDifficulty(_dailyPuzzle.difficulty);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border:
                  Border.all(color: accent.withValues(alpha: 0.35), width: 2),
            ),
            child: Icon(
              _dailyIcon(),
              color: accent,
              size: 42,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'BUGÜNÜN BULMACASI HAZIR',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ZORLUK : ${_difficultyText(_dailyPuzzle.difficulty)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+$reward',
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              _rewardCoinIcon(),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'YENİ BULMACAYA KALAN SÜRE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Text(
              _formatDuration(_timeLeft),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Bugünkü ortak bulmacayı tamamla, ödülünü al ve yeni bulmaca için gece 00:00\'ı bekle.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _openDailyGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'OYNA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(Color accent) {
    final reward = _rewardForDifficulty(_dailyPuzzle.difficulty);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00C853).withValues(alpha: 0.12),
              border: Border.all(
                color: const Color(0xFF00C853).withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF00C853),
              size: 48,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'BUGÜNÜN BULMACASINI TAMAMLADIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+$reward',
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              _rewardCoinIcon(),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'YENİ GÜNLÜK BULMACAYA KALAN SÜRE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Text(
              _formatDuration(_timeLeft),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ödülünü aldın. Yeni günlük bulmaca gece 00:00\'da açılacak.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
