import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerProgress {
  static const String _coinsKey = 'player_coins';
  static const String _latestUnlockedMapKey = 'latest_unlocked_map';

  static final ValueNotifier<int> coins = ValueNotifier<int>(0);

  static SharedPreferences? _prefs;
  static bool _loaded = false;

  static final Map<int, Set<int>> _completedLevelsCache = {};
  static int _latestUnlockedMap = 1;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;

    _prefs = await SharedPreferences.getInstance();
    coins.value = (_prefs?.getInt(_coinsKey) ?? 0).clamp(0, 1 << 30);
    _latestUnlockedMap =
        (_prefs?.getInt(_latestUnlockedMapKey) ?? 1).clamp(1, 999);

    _loaded = true;
  }

  static void setCoins(int value) {
    final safeValue = value < 0 ? 0 : value;
    if (coins.value == safeValue) return;
    coins.value = safeValue;
    unawaited(_persistCoins());
  }

  static void addCoins(int amount) {
    if (amount <= 0) return;
    setCoins(coins.value + amount);
  }

  static bool spendCoins(int amount) {
    if (amount <= 0) return true;
    if (coins.value < amount) return false;
    setCoins(coins.value - amount);
    return true;
  }

  static Future<void> _persistCoins() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_coinsKey, coins.value);
    _loaded = true;
  }

  static String _mapCompletedKey(int mapNumber) =>
      'map_${mapNumber}_completed_levels';

  static Future<Set<int>> getCompletedLevels(int mapNumber) async {
    await ensureLoaded();

    if (_completedLevelsCache.containsKey(mapNumber)) {
      return Set<int>.from(_completedLevelsCache[mapNumber]!);
    }

    final raw =
        _prefs?.getStringList(_mapCompletedKey(mapNumber)) ?? const <String>[];
    final parsed = raw
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .where((e) => e > 0)
        .toSet();

    _completedLevelsCache[mapNumber] = parsed;
    return Set<int>.from(parsed);
  }

  static Future<void> setCompletedLevels(int mapNumber, Set<int> levels) async {
    await ensureLoaded();

    final safe = levels.where((e) => e > 0).toSet();
    _completedLevelsCache[mapNumber] = safe;

    final sorted = safe.toList()..sort();
    await _prefs!.setStringList(
      _mapCompletedKey(mapNumber),
      sorted.map((e) => e.toString()).toList(),
    );
  }

  static Future<void> markLevelCompleted(int mapNumber, int levelId) async {
    if (levelId <= 0) return;
    final levels = await getCompletedLevels(mapNumber);
    if (levels.contains(levelId)) return;
    levels.add(levelId);
    await setCompletedLevels(mapNumber, levels);
  }

  static Future<void> clearMapProgress(int mapNumber) async {
    await ensureLoaded();
    _completedLevelsCache.remove(mapNumber);
    await _prefs!.remove(_mapCompletedKey(mapNumber));
  }

  static Future<void> resetAllProgress() async {
    await ensureLoaded();

    final keys = _prefs!.getKeys().where((k) =>
        k == _coinsKey ||
        k == _latestUnlockedMapKey ||
        (k.startsWith('map_') && k.endsWith('_completed_levels')));

    for (final key in keys.toList()) {
      await _prefs!.remove(key);
    }

    coins.value = 0;
    _latestUnlockedMap = 1;
    _completedLevelsCache.clear();
  }

  static int get latestUnlockedMap => _latestUnlockedMap;

  static Future<void> unlockMap(int mapNumber) async {
    await ensureLoaded();
    if (mapNumber <= _latestUnlockedMap) return;
    _latestUnlockedMap = mapNumber;
    await _prefs!.setInt(_latestUnlockedMapKey, _latestUnlockedMap);
  }

  static int rewardForDifficultyDots(int dots) {
    switch (dots) {
      case 1:
        return 10;
      case 2:
        return 15;
      case 3:
        return 20;
      case 4:
        return 25;
      case 5:
      default:
        return 30;
    }
  }
}

class CoinPill extends StatelessWidget {
  final int? coinsValue;

  const CoinPill({super.key, this.coinsValue});

  @override
  Widget build(BuildContext context) {
    if (coinsValue != null) {
      return _CoinPillBody(coins: coinsValue!);
    }

    return ValueListenableBuilder<int>(
      valueListenable: PlayerProgress.coins,
      builder: (context, coins, _) => _CoinPillBody(coins: coins),
    );
  }
}

class _CoinPillBody extends StatelessWidget {
  final int coins;

  const _CoinPillBody({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFE082).withOpacity(0.22),
            Colors.white.withOpacity(0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.34)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF176), Color(0xFFFFB300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC107).withOpacity(0.34),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.toll_rounded,
              color: Color(0xFF6A4300),
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$coins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
