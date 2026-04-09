import 'package:flutter/material.dart';

import 'audio_service.dart';
import 'daily_puzzle_generator.dart';
import 'daily_puzzle_progress.dart';
import 'game_page.dart';
import 'player_progress.dart';
import 'settings_page.dart';

class DailyGamePage extends StatefulWidget {
  final DailyPuzzleData puzzle;

  const DailyGamePage({
    super.key,
    required this.puzzle,
  });

  @override
  State<DailyGamePage> createState() => _DailyGamePageState();
}

class _DailyGamePageState extends State<DailyGamePage> {
  bool _loading = true;
  bool _alreadyCompleted = false;
  DailyPuzzleSaveState? _savedState;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await PlayerProgress.ensureLoaded();
    await DailyPuzzleProgress.prepareForDate(widget.puzzle.dateKey);

    final alreadyCompleted =
        await DailyPuzzleProgress.isCompleted(widget.puzzle.dateKey);

    DailyPuzzleSaveState? saved;
    if (!alreadyCompleted) {
      saved =
          await DailyPuzzleProgress.getInProgressState(widget.puzzle.dateKey);
    }

    if (!mounted) return;
    setState(() {
      _alreadyCompleted = alreadyCompleted;
      _savedState = saved;
      _loading = false;
    });

    if (!_alreadyCompleted && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _alreadyCompleted) return;
        _openGame();
      });
    }
  }

  Future<void> _playClick() async {
    await SfxService.playClick();
  }

  Future<void> _vibrateTap() async {
    await SettingsPage.vibrateTap();
  }

  int _syntheticDailyLevelId(String dateKey) {
    if (dateKey.length >= 6) {
      return int.tryParse(dateKey.substring(dateKey.length - 6)) ?? 900001;
    }
    return 900001;
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

  Future<void> _openGame() async {
    if (!mounted) return;

    final reward = _rewardForDifficulty(widget.puzzle.difficulty);

    final result = await Navigator.of(context).push<GamePageResult>(
      MaterialPageRoute(
        builder: (_) => GamePage(
          level: _syntheticDailyLevelId(widget.puzzle.dateKey),
          mapNumber: widget.puzzle.mapNumber,
          difficulty: widget.puzzle.difficulty,
          initialCoins: PlayerProgress.coins.value,
          customPuzzleTubes: widget.puzzle.tubes,
          customLockedAdTubeIndex: widget.puzzle.lockedAdTubeIndex,
          customStageLayout: widget.puzzle.layout,
          isDailyPuzzleMode: true,
          dailyPuzzleDateKey: widget.puzzle.dateKey,
          dailyRewardCoins: reward,
          restoredDailyState: _savedState,
          customTitle: 'GÜNLÜK BULMACA',
          customBackground: _dailyBackground(widget.puzzle.dateKey),
        ),
      ),
    );

    if (!mounted) return;

    if (result == null) {
      Navigator.of(context).pop(false);
      return;
    }

    if (result.completed) {
      await DailyPuzzleProgress.markCompleted(widget.puzzle.dateKey);

      final rewardClaimed =
          await DailyPuzzleProgress.isRewardClaimed(widget.puzzle.dateKey);

      if (!rewardClaimed) {
        PlayerProgress.addCoins(reward);
        await DailyPuzzleProgress.markRewardClaimed(widget.puzzle.dateKey);
      }

      await DailyPuzzleProgress.clearInProgressState();

      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.of(context).pop(false);
  }

  Future<void> _goBack() async {
    await _playClick();
    await _vibrateTap();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.puzzle.mapStyle == DailyPuzzleMapStyle.map2
        ? const Color(0xFF7E57C2)
        : const Color(0xFFFF8A3D);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0415),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: _goBack,
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
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.14),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: _alreadyCompleted
                        ? _buildAlreadyCompleted(accent)
                        : _buildPreparing(accent),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPreparing(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
            border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
          ),
          child: Icon(
            widget.puzzle.mapStyle == DailyPuzzleMapStyle.map2
                ? Icons.visibility_off_outlined
                : Icons.extension_rounded,
            color: accent,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'GÜNLÜK OYUN AÇILIYOR',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _savedState == null
              ? 'Bugünün ortak bulmacası hazırlanıyor...'
              : 'Kaldığın yerden devam ediliyor...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ],
    );
  }

  Widget _buildAlreadyCompleted(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90,
          height: 90,
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
            size: 44,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'BUGÜNÜN BULMACASI TAMAMLANDI',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ödülünü aldın. Yeni günlük bulmaca gece 00:00\'da açılacak.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _goBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'GERİ DÖN',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
