import 'dart:math';
import 'game_models.dart';

List<int> jokerSearchLimitsForCurrentState({
  required int mapNumber,
  required int level,
  required int activeTubeCount,
  required bool freshStart,
}) {
  if (mapNumber == 1) {
    if (level <= 3) {
      return freshStart ? [4000, 10000] : [6000, 16000, 40000];
    }
    if (level <= 6) {
      return freshStart ? [7000, 18000] : [10000, 30000, 70000];
    }
    return freshStart ? [10000, 28000, 70000] : [14000, 45000, 100000];
  }

  if (mapNumber == 2) {
    if (level <= 5) {
      return freshStart ? [10000, 30000, 70000] : [16000, 45000, 100000];
    }
    if (level <= 7) {
      return freshStart ? [18000, 60000, 140000] : [25000, 80000, 180000];
    }
    return freshStart ? [30000, 100000, 220000] : [40000, 120000, 300000];
  }

  if (mapNumber == 3) {
    if (level <= 3) {
      return freshStart ? [15000, 50000, 120000] : [20000, 70000, 160000];
    }
    if (level <= 6) {
      return freshStart ? [22000, 80000, 180000] : [30000, 100000, 240000];
    }
    return freshStart ? [40000, 140000, 350000] : [55000, 180000, 400000];
  }

  if (activeTubeCount <= 8) {
    return freshStart ? [7000, 18000] : [10000, 30000, 70000];
  }

  if (activeTubeCount <= 11) {
    return freshStart ? [12000, 40000, 90000] : [18000, 60000, 140000];
  }

  return freshStart ? [25000, 80000, 180000] : [35000, 120000, 300000];
}

List<int> jokerActiveTubeIndexesFor({
  required List<List<int>> tubes,
  required bool showLockedAdTube,
  required int lockedAdTubeIndex,
}) {
  final indexes = <int>[];
  for (int i = 0; i < tubes.length; i++) {
    if (showLockedAdTube && i == lockedAdTubeIndex) continue;
    indexes.add(i);
  }
  return indexes;
}

bool canPourInSimulation({
  required List<List<int>> tubes,
  required int from,
  required int to,
  required bool Function(List<List<int>>, int, int) canPourIn,
}) {
  return canPourIn(tubes, from, to);
}

bool canPourToMountainInSimulation({
  required bool hasMountainObjective,
  required bool showLockedAdTube,
  required int lockedAdTubeIndex,
  required List<List<int>> tubes,
  required int from,
  required bool Function(int) isLavaColorIndexFn,
}) {
  if (!hasMountainObjective) return false;
  if (showLockedAdTube && from == lockedAdTubeIndex) return false;
  if (from < 0 || from >= tubes.length || tubes[from].isEmpty) return false;
  if (!isLavaColorIndexFn(tubes[from].last)) return false;
  return true;
}

int mountainPourCountInSimulation({
  required List<List<int>> tubes,
  required int from,
  required int currentMountainFillUnits,
  required int mountainCapacity,
  required bool Function(List<List<int>>, int) canPourToMountainInSimulationFn,
}) {
  if (!canPourToMountainInSimulationFn(tubes, from)) return 0;

  final available = mountainCapacity - currentMountainFillUnits;
  if (available <= 0) return 0;

  final colorIdx = tubes[from].last;
  int count = 0;
  for (int i = tubes[from].length - 1; i >= 0; i--) {
    if (tubes[from][i] == colorIdx) {
      count++;
    } else {
      break;
    }
  }

  return min(count, available);
}

typedef JokerNodeBuilder = JokerSearchNode Function({
  required List<List<int>> tubes,
  required int mountainFillUnits,
  required List<String> moves,
  required Map<int, List<List<int>>> refillQueues,
  int priority,
});

List<String>? findJokerSolution({
  required List<List<int>> sourceTubes,
  required int mountainFillUnits,
  required Map<int, List<List<int>>> runtimeRefillQueues,
  required bool hasMountainObjective,
  required int mountainCapacity,
  required bool activeStopRefillWhenMountainFull,
  required bool showLockedAdTube,
  required int lockedAdTubeIndex,
  required bool Function(List<List<int>>, int, int) canPourInFn,
  required void Function(List<List<int>>, int, int) doPourInFn,
  required bool Function(List<List<int>>, int) isTubeDoneInFn,
  required int Function(List<List<int>>, int) tubeCapacityInFn,
  required bool Function(int) isLavaColorIndexFn,
  required List<List<int>> Function(List<List<int>>) cloneBoardFn,
  required Map<int, List<List<int>>> Function(Map<int, List<List<int>>>)
      cloneRefillQueuesMapFn,
  required JokerNodeBuilder jokerNodeBuilder,
  int maxIterations = 40000,
}) {
  final initialTubes = cloneBoardFn(sourceTubes);
  final initialMountainFillUnits = mountainFillUnits;
  final activeIndexes = jokerActiveTubeIndexesFor(
    tubes: initialTubes,
    showLockedAdTube: showLockedAdTube,
    lockedAdTubeIndex: lockedAdTubeIndex,
  );
  final targetMountainCapacity = hasMountainObjective ? mountainCapacity : 0;
  final initialRefillQueues = cloneRefillQueuesMapFn(runtimeRefillQueues);
  final stopWhenMountainFull = activeStopRefillWhenMountainFull;

  int heuristic(JokerSearchNode node) {
    var h = 0;

    for (final idx in activeIndexes) {
      final tube = node.tubes[idx];
      if (tube.isEmpty) continue;

      final cap = tubeCapacityInFn(node.tubes, idx);
      final isDone = tube.length == cap && tube.every((c) => c == tube.first);
      if (!isDone) {
        h += 10;
        final uniqueColors = tube.toSet().length;
        h += (uniqueColors - 1) * 4;
      }
    }

    if (targetMountainCapacity > 0) {
      final remaining = max(0, targetMountainCapacity - node.mountainFillUnits);
      h += remaining * 2;
    }

    return h;
  }

  int computePriority(JokerSearchNode node) {
    final g = node.moves.length;
    final h = heuristic(node);
    return g + h;
  }

  final startNode = jokerNodeBuilder(
    tubes: initialTubes,
    mountainFillUnits: initialMountainFillUnits,
    moves: const [],
    refillQueues: initialRefillQueues,
    priority: 0,
  );

  if (startNode.isSolved(
    activeIndexes: activeIndexes,
    mountainCapacity: targetMountainCapacity,
    tubeCapacityIn: tubeCapacityInFn,
  )) {
    return const [];
  }

  final queue = <JokerSearchNode>[startNode];
  final visited = <String>{startNode.stateId(activeIndexes)};
  var iterations = 0;

  void addNode(JokerSearchNode node) {
    queue.add(node);
    queue.sort((a, b) => a.priority.compareTo(b.priority));
  }

  while (queue.isNotEmpty && iterations < maxIterations) {
    iterations++;
    final current = queue.removeAt(0);

    if (current.isSolved(
      activeIndexes: activeIndexes,
      mountainCapacity: targetMountainCapacity,
      tubeCapacityIn: tubeCapacityInFn,
    )) {
      return current.moves;
    }

    final lastMove = current.moves.isNotEmpty ? current.moves.last : null;

    for (final from in activeIndexes) {
      if (isTubeDoneInFn(current.tubes, from)) continue;
      if (current.tubes[from].isEmpty) continue;

      for (final to in activeIndexes) {
        if (from == to) continue;
        if (lastMove == '$to->$from') continue;
        if (!canPourInFn(current.tubes, from, to)) continue;

        if (current.tubes[to].isEmpty) {
          final earlierEquivalentEmpty = activeIndexes.any(
            (idx) =>
                idx != to &&
                idx != from &&
                current.tubes[idx].isEmpty &&
                idx < to,
          );
          if (earlierEquivalentEmpty) continue;
        }

        final nextTubes = cloneBoardFn(current.tubes);
        doPourInFn(nextTubes, from, to);

        final nextRefillQueues = cloneRefillQueuesMapFn(current.refillQueues);
        if (nextTubes[from].isEmpty) {
          final queueRefill = nextRefillQueues[from];
          final refillStopped = targetMountainCapacity > 0 &&
              stopWhenMountainFull &&
              current.mountainFillUnits >= targetMountainCapacity;
          if (!refillStopped && queueRefill != null && queueRefill.isNotEmpty) {
            nextTubes[from] =
                List<int>.from(queueRefill.removeAt(0), growable: true);
          }
        }

        final nextNodeBase = jokerNodeBuilder(
          tubes: nextTubes,
          mountainFillUnits: current.mountainFillUnits,
          moves: [...current.moves, '$from->$to'],
          refillQueues: nextRefillQueues,
          priority: 0,
        );

        final stateId = nextNodeBase.stateId(activeIndexes);
        if (!visited.add(stateId)) continue;

        addNode(jokerNodeBuilder(
          tubes: nextNodeBase.tubes,
          mountainFillUnits: nextNodeBase.mountainFillUnits,
          moves: nextNodeBase.moves,
          refillQueues: nextNodeBase.refillQueues,
          priority: computePriority(nextNodeBase),
        ));
      }

      if (!hasMountainObjective) continue;
      if (current.mountainFillUnits >= targetMountainCapacity) continue;
      if (lastMove == '$from->mountain') continue;

      final canMountain = canPourToMountainInSimulation(
        hasMountainObjective: hasMountainObjective,
        showLockedAdTube: showLockedAdTube,
        lockedAdTubeIndex: lockedAdTubeIndex,
        tubes: current.tubes,
        from: from,
        isLavaColorIndexFn: isLavaColorIndexFn,
      );
      if (!canMountain) continue;

      final mountainCount = mountainPourCountInSimulation(
        tubes: current.tubes,
        from: from,
        currentMountainFillUnits: current.mountainFillUnits,
        mountainCapacity: mountainCapacity,
        canPourToMountainInSimulationFn: (t, f) =>
            canPourToMountainInSimulation(
          hasMountainObjective: hasMountainObjective,
          showLockedAdTube: showLockedAdTube,
          lockedAdTubeIndex: lockedAdTubeIndex,
          tubes: t,
          from: f,
          isLavaColorIndexFn: isLavaColorIndexFn,
        ),
      );

      if (mountainCount <= 0) continue;

      final nextTubes = cloneBoardFn(current.tubes);
      for (int i = 0; i < mountainCount; i++) {
        nextTubes[from].removeLast();
      }

      final nextRefillQueues = cloneRefillQueuesMapFn(current.refillQueues);
      final nextMountainFillUnits = current.mountainFillUnits + mountainCount;

      if (nextTubes[from].isEmpty) {
        final queueRefill = nextRefillQueues[from];
        final refillStopped = targetMountainCapacity > 0 &&
            stopWhenMountainFull &&
            nextMountainFillUnits >= targetMountainCapacity;
        if (!refillStopped && queueRefill != null && queueRefill.isNotEmpty) {
          nextTubes[from] =
              List<int>.from(queueRefill.removeAt(0), growable: true);
        }
      }

      final nextNodeBase = jokerNodeBuilder(
        tubes: nextTubes,
        mountainFillUnits: nextMountainFillUnits,
        moves: [...current.moves, '$from->mountain'],
        refillQueues: nextRefillQueues,
        priority: 0,
      );

      final stateId = nextNodeBase.stateId(activeIndexes);
      if (!visited.add(stateId)) continue;

      addNode(jokerNodeBuilder(
        tubes: nextNodeBase.tubes,
        mountainFillUnits: nextNodeBase.mountainFillUnits,
        moves: nextNodeBase.moves,
        refillQueues: nextNodeBase.refillQueues,
        priority: computePriority(nextNodeBase),
      ));
    }
  }

  return null;
}

Future<List<String>?> findJokerSolutionWithStages({
  required List<int> limits,
  required Future<List<String>?> Function(int limit) solveAtLimit,
  required Future<void> Function(int fromLimit, int toLimit) onStageAdvance,
}) async {
  for (int i = 0; i < limits.length; i++) {
    final limit = limits[i];
    final solution = await solveAtLimit(limit);

    if (solution != null) {
      return solution;
    }

    if (i < limits.length - 1) {
      await onStageAdvance(limit, limits[i + 1]);
    }
  }

  return null;
}
