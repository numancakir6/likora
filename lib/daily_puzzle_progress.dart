import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DailyPuzzleSaveState {
  final String dateKey;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;
  final bool adTubeUnlocked;
  final List<int>? visibleLayerCounts;

  const DailyPuzzleSaveState({
    required this.dateKey,
    required this.tubes,
    required this.lockedAdTubeIndex,
    required this.adTubeUnlocked,
    this.visibleLayerCounts,
  });
}

class DailyPuzzleProgress {
  static const String _kPuzzleDate = 'daily_puzzle_date';
  static const String _kPuzzleTubes = 'daily_puzzle_tubes';
  static const String _kLockedAdTubeIndex = 'daily_puzzle_locked_ad_tube_index';
  static const String _kAdTubeUnlocked = 'daily_puzzle_ad_tube_unlocked';
  static const String _kCompletedDate = 'daily_puzzle_completed_date';
  static const String _kRewardClaimedDate = 'daily_puzzle_reward_claimed_date';
  static const String _kVisibleLayerCounts =
      'daily_puzzle_visible_layer_counts';

  static Future<void> clearIfDateChanged(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_kPuzzleDate);

    if (savedDate == null || savedDate == dateKey) return;

    await prefs.remove(_kPuzzleDate);
    await prefs.remove(_kPuzzleTubes);
    await prefs.remove(_kLockedAdTubeIndex);
    await prefs.remove(_kAdTubeUnlocked);
    await prefs.remove(_kVisibleLayerCounts);
  }

  static Future<void> saveInProgressState({
    required String dateKey,
    required List<List<int>> tubes,
    required int lockedAdTubeIndex,
    required bool adTubeUnlocked,
    List<int>? visibleLayerCounts,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_kPuzzleDate, dateKey);
    await prefs.setString(_kPuzzleTubes, jsonEncode(tubes));
    await prefs.setInt(_kLockedAdTubeIndex, lockedAdTubeIndex);
    await prefs.setBool(_kAdTubeUnlocked, adTubeUnlocked);

    if (visibleLayerCounts != null) {
      await prefs.setStringList(
        _kVisibleLayerCounts,
        visibleLayerCounts.map((e) => e.toString()).toList(growable: false),
      );
    } else {
      await prefs.remove(_kVisibleLayerCounts);
    }
  }

  static Future<DailyPuzzleSaveState?> getInProgressState(
    String dateKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final savedDate = prefs.getString(_kPuzzleDate);
    if (savedDate != dateKey) return null;

    final rawTubes = prefs.getString(_kPuzzleTubes);
    if (rawTubes == null || rawTubes.isEmpty) return null;

    final decoded = jsonDecode(rawTubes);
    if (decoded is! List) return null;

    final tubes = decoded
        .map<List<int>>(
          (tube) => (tube as List)
              .map<int>((value) => (value as num).toInt())
              .toList(growable: true),
        )
        .toList(growable: true);

    final lockedAdTubeIndex = prefs.getInt(_kLockedAdTubeIndex);
    if (lockedAdTubeIndex == null) return null;

    final adTubeUnlocked = prefs.getBool(_kAdTubeUnlocked) ?? false;

    final rawVisible = prefs.getStringList(_kVisibleLayerCounts);
    final visibleLayerCounts =
        rawVisible?.map((e) => int.tryParse(e) ?? 0).toList(growable: true);

    return DailyPuzzleSaveState(
      dateKey: savedDate!,
      tubes: tubes,
      lockedAdTubeIndex: lockedAdTubeIndex,
      adTubeUnlocked: adTubeUnlocked,
      visibleLayerCounts: visibleLayerCounts,
    );
  }

  static Future<void> clearInProgressState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPuzzleDate);
    await prefs.remove(_kPuzzleTubes);
    await prefs.remove(_kLockedAdTubeIndex);
    await prefs.remove(_kAdTubeUnlocked);
    await prefs.remove(_kVisibleLayerCounts);
  }

  static Future<void> markCompleted(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCompletedDate, dateKey);
  }

  static Future<bool> isCompleted(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCompletedDate) == dateKey;
  }

  static Future<void> clearCompletedIfDateChanged(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kCompletedDate);
    if (saved == null || saved == dateKey) return;
    await prefs.remove(_kCompletedDate);
  }

  static Future<void> markRewardClaimed(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRewardClaimedDate, dateKey);
  }

  static Future<bool> isRewardClaimed(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRewardClaimedDate) == dateKey;
  }

  static Future<void> clearRewardIfDateChanged(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kRewardClaimedDate);
    if (saved == null || saved == dateKey) return;
    await prefs.remove(_kRewardClaimedDate);
  }

  static Future<void> prepareForDate(String dateKey) async {
    await clearIfDateChanged(dateKey);
    await clearCompletedIfDateChanged(dateKey);
    await clearRewardIfDateChanged(dateKey);
  }

  static Future<void> resetAllDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPuzzleDate);
    await prefs.remove(_kPuzzleTubes);
    await prefs.remove(_kLockedAdTubeIndex);
    await prefs.remove(_kAdTubeUnlocked);
    await prefs.remove(_kCompletedDate);
    await prefs.remove(_kRewardClaimedDate);
    await prefs.remove(_kVisibleLayerCounts);
  }
}
