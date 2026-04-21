import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../puzzle_presets.dart';

Map<int, List<List<int>>> cloneRefillQueues(SourceTubeRefillConfig? refill) {
  if (refill == null) return {};

  return refill.refillQueues.map(
    (tubeIndex, queue) => MapEntry(
      tubeIndex,
      queue
          .map((pack) => List<int>.from(pack, growable: true))
          .toList(growable: true),
    ),
  );
}

Map<int, List<List<int>>> cloneRefillQueuesMap(
  Map<int, List<List<int>>> source,
) {
  return source.map(
    (tubeIndex, queue) => MapEntry(
      tubeIndex,
      queue
          .map((pack) => List<int>.from(pack, growable: true))
          .toList(growable: true),
    ),
  );
}

Map<int, List<List<int>>> decodeRuntimeRefillQueues(dynamic raw) {
  final result = <int, List<List<int>>>{};
  if (raw is! Map) return result;

  raw.forEach((key, value) {
    final tubeIndex = int.tryParse(key.toString());
    if (tubeIndex == null || value is! List) return;

    final queue = <List<int>>[];
    for (final packRaw in value) {
      if (packRaw is! List) continue;

      final pack = <int>[];
      var valid = true;
      for (final cell in packRaw) {
        if (cell is int) {
          pack.add(cell);
        } else {
          valid = false;
          break;
        }
      }

      if (valid) {
        queue.add(pack);
      }
    }

    result[tubeIndex] = queue;
  });

  return result;
}

Map<String, dynamic> encodeRuntimeRefillQueues(
  Map<int, List<List<int>>> queues,
) {
  return queues.map(
    (tubeIndex, queue) => MapEntry(
      tubeIndex.toString(),
      queue
          .map((pack) => List<int>.from(pack, growable: false))
          .toList(growable: false),
    ),
  );
}

Future<void> persistRefillState({
  required String? key,
  required bool gameWon,
  required Map<int, List<List<int>>> runtimeRefillQueues,
}) async {
  if (key == null) return;

  final prefs = await SharedPreferences.getInstance();

  if (gameWon || runtimeRefillQueues.isEmpty) {
    await prefs.remove(key);
    return;
  }

  await prefs.setString(
    key,
    jsonEncode(encodeRuntimeRefillQueues(runtimeRefillQueues)),
  );
}

Future<Map<int, List<List<int>>>> restoreRefillState({
  required Map<int, List<List<int>>> initialRefillQueues,
  required String? key,
}) async {
  var result = cloneRefillQueuesMap(initialRefillQueues);

  if (key == null) return result;

  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(key);
  if (raw == null || raw.isEmpty) return result;

  try {
    final decoded = jsonDecode(raw);
    final restored = decodeRuntimeRefillQueues(decoded);

    if (restored.isNotEmpty) {
      result = restored;
    }
  } catch (_) {
    result = cloneRefillQueuesMap(initialRefillQueues);
  }

  return result;
}

Future<void> clearRefillState({
  required String refillStatePrefsKey,
  required String? dailyRefillStatePrefsKey,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(refillStatePrefsKey);

  if (dailyRefillStatePrefsKey != null) {
    await prefs.remove(dailyRefillStatePrefsKey);
  }
}

bool refillStopped({
  required List<int> activeRefillTubeIndexes,
  required bool activeStopRefillWhenMountainFull,
  required bool hasMountainObjective,
  required int mountainFillUnits,
  required int mountainCapacity,
}) {
  if (activeRefillTubeIndexes.isEmpty || !activeStopRefillWhenMountainFull) {
    return false;
  }
  return hasMountainObjective && mountainFillUnits >= mountainCapacity;
}

class RefillApplyResult {
  final Map<int, List<List<int>>> runtimeRefillQueues;
  final List<List<int>> tubes;

  const RefillApplyResult({
    required this.runtimeRefillQueues,
    required this.tubes,
  });
}

RefillApplyResult tryRefillSourceTube({
  required List<int> refillTubeIndexes,
  required Map<int, List<List<int>>> runtimeRefillQueues,
  required List<List<int>> tubes,
  required int tubeIndex,
  required bool stopRefill,
}) {
  final nextQueues = cloneRefillQueuesMap(runtimeRefillQueues);
  final nextTubes = tubes
      .map((tube) => List<int>.from(tube, growable: true))
      .toList(growable: true);

  if (refillTubeIndexes.isEmpty) {
    return RefillApplyResult(runtimeRefillQueues: nextQueues, tubes: nextTubes);
  }
  if (!refillTubeIndexes.contains(tubeIndex)) {
    return RefillApplyResult(runtimeRefillQueues: nextQueues, tubes: nextTubes);
  }
  if (stopRefill) {
    return RefillApplyResult(runtimeRefillQueues: nextQueues, tubes: nextTubes);
  }
  if (tubeIndex < 0 || tubeIndex >= nextTubes.length) {
    return RefillApplyResult(runtimeRefillQueues: nextQueues, tubes: nextTubes);
  }
  if (nextTubes[tubeIndex].isNotEmpty) {
    return RefillApplyResult(runtimeRefillQueues: nextQueues, tubes: nextTubes);
  }

  final queue = nextQueues[tubeIndex];
  if (queue == null || queue.isEmpty) {
    return RefillApplyResult(runtimeRefillQueues: nextQueues, tubes: nextTubes);
  }

  final nextPack = queue.removeAt(0);
  nextTubes[tubeIndex] = List<int>.from(nextPack, growable: true);

  return RefillApplyResult(runtimeRefillQueues: nextQueues, tubes: nextTubes);
}
