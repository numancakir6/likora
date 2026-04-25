import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DailyPuzzleSaveState {
  final String dateKey;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;
  final bool adTubeUnlocked;
  final List<int>? visibleLayerCounts;
  final int mountainFillUnits;

  const DailyPuzzleSaveState({
    required this.dateKey,
    required this.tubes,
    required this.lockedAdTubeIndex,
    required this.adTubeUnlocked,
    this.visibleLayerCounts,
    this.mountainFillUnits = 0,
  });
}

class DailyPuzzleProgress {
  // Bu version günlük puzzle üretim sistemi değiştiğinde artırılır.
  // Version değişince eski bozuk/uyumsuz günlük kayıtlar temizlenir.
  static const int _kDailyPuzzleVersion = 2;

  static const String _kPuzzleVersion = 'daily_puzzle_version';
  static const String _kPuzzleDate = 'daily_puzzle_date';
  static const String _kPuzzleTubes = 'daily_puzzle_tubes';
  static const String _kLockedAdTubeIndex = 'daily_puzzle_locked_ad_tube_index';
  static const String _kAdTubeUnlocked = 'daily_puzzle_ad_tube_unlocked';
  static const String _kCompletedDate = 'daily_puzzle_completed_date';
  static const String _kRewardClaimedDate = 'daily_puzzle_reward_claimed_date';
  static const String _kOpenedDate = 'daily_puzzle_opened_date';
  static const String _kVisibleLayerCounts =
      'daily_puzzle_visible_layer_counts';
  static const String _kMountainFillUnits = 'daily_puzzle_mountain_fill_units';

  static Future<void> _ensureCurrentVersion(SharedPreferences prefs) async {
    final savedVersion = prefs.getInt(_kPuzzleVersion);
    if (savedVersion == _kDailyPuzzleVersion) return;

    await _resetAllDailyDataWithPrefs(prefs);
    await prefs.setInt(_kPuzzleVersion, _kDailyPuzzleVersion);
  }

  static Future<void> clearIfDateChanged(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    final savedDate = prefs.getString(_kPuzzleDate);

    if (savedDate == null || savedDate == dateKey) return;

    await prefs.remove(_kPuzzleDate);
    await prefs.remove(_kPuzzleTubes);
    await prefs.remove(_kLockedAdTubeIndex);
    await prefs.remove(_kAdTubeUnlocked);
    await prefs.remove(_kVisibleLayerCounts);
    await prefs.remove(_kMountainFillUnits);
  }

  static Future<void> saveInProgressState({
    required String dateKey,
    required List<List<int>> tubes,
    required int lockedAdTubeIndex,
    required bool adTubeUnlocked,
    List<int>? visibleLayerCounts,
    int mountainFillUnits = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    await prefs.setString(_kPuzzleDate, dateKey);
    await prefs.setString(_kPuzzleTubes, jsonEncode(tubes));
    await prefs.setInt(_kLockedAdTubeIndex, lockedAdTubeIndex);
    await prefs.setBool(_kAdTubeUnlocked, adTubeUnlocked);
    await prefs.setInt(_kMountainFillUnits, mountainFillUnits);

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
    await _ensureCurrentVersion(prefs);

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
    final mountainFillUnits = prefs.getInt(_kMountainFillUnits) ?? 0;

    final rawVisible = prefs.getStringList(_kVisibleLayerCounts);
    final visibleLayerCounts =
        rawVisible?.map((e) => int.tryParse(e) ?? 0).toList(growable: true);

    return DailyPuzzleSaveState(
      dateKey: savedDate!,
      tubes: tubes,
      lockedAdTubeIndex: lockedAdTubeIndex,
      adTubeUnlocked: adTubeUnlocked,
      visibleLayerCounts: visibleLayerCounts,
      mountainFillUnits: mountainFillUnits,
    );
  }

  static Future<void> clearInProgressState() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    await prefs.remove(_kPuzzleDate);
    await prefs.remove(_kPuzzleTubes);
    await prefs.remove(_kLockedAdTubeIndex);
    await prefs.remove(_kAdTubeUnlocked);
    await prefs.remove(_kVisibleLayerCounts);
    await prefs.remove(_kMountainFillUnits);
  }

  static Future<void> markCompleted(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    await prefs.setString(_kCompletedDate, dateKey);
  }

  static Future<bool> isCompleted(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    return prefs.getString(_kCompletedDate) == dateKey;
  }

  static Future<void> clearCompletedIfDateChanged(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    final saved = prefs.getString(_kCompletedDate);
    if (saved == null || saved == dateKey) return;
    await prefs.remove(_kCompletedDate);
  }

  static Future<void> markRewardClaimed(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    await prefs.setString(_kRewardClaimedDate, dateKey);
  }

  static Future<bool> isRewardClaimed(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    return prefs.getString(_kRewardClaimedDate) == dateKey;
  }

  static Future<void> clearRewardIfDateChanged(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    final saved = prefs.getString(_kRewardClaimedDate);
    if (saved == null || saved == dateKey) return;
    await prefs.remove(_kRewardClaimedDate);
    await prefs.remove(_kOpenedDate);
  }

  static Future<void> markOpened(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    await prefs.setString(_kOpenedDate, dateKey);
  }

  static Future<bool> isOpened(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    return prefs.getString(_kOpenedDate) == dateKey;
  }

  static Future<void> clearOpenedIfDateChanged(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    final saved = prefs.getString(_kOpenedDate);
    if (saved == null || saved == dateKey) return;
    await prefs.remove(_kOpenedDate);
  }

  static Future<void> prepareForDate(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureCurrentVersion(prefs);

    await clearIfDateChanged(dateKey);
    await clearCompletedIfDateChanged(dateKey);
    await clearRewardIfDateChanged(dateKey);
    await clearOpenedIfDateChanged(dateKey);
  }

  static Future<void> resetAllDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetAllDailyDataWithPrefs(prefs);
    await prefs.setInt(_kPuzzleVersion, _kDailyPuzzleVersion);
  }

  static Future<void> _resetAllDailyDataWithPrefs(
    SharedPreferences prefs,
  ) async {
    await prefs.remove(_kPuzzleDate);
    await prefs.remove(_kPuzzleTubes);
    await prefs.remove(_kLockedAdTubeIndex);
    await prefs.remove(_kAdTubeUnlocked);
    await prefs.remove(_kCompletedDate);
    await prefs.remove(_kRewardClaimedDate);
    await prefs.remove(_kOpenedDate);
    await prefs.remove(_kVisibleLayerCounts);
    await prefs.remove(_kMountainFillUnits);
  }
}
