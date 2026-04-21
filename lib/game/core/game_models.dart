class GamePageResult {
  final bool completed;
  final int coinsAfterLevel;
  final int earnedCoins;

  const GamePageResult({
    required this.completed,
    required this.coinsAfterLevel,
    this.earnedCoins = 0,
  });
}

class TransferPlan {
  final int fromIdx;
  final int toIdx;
  final List<int> fromSnapshot;
  final List<int> toSnapshot;
  final int colorIdx;
  final int count;
  final bool isMountainTarget;
  final int mountainFillBefore;

  const TransferPlan({
    required this.fromIdx,
    required this.toIdx,
    required this.fromSnapshot,
    required this.toSnapshot,
    required this.colorIdx,
    required this.count,
    this.isMountainTarget = false,
    this.mountainFillBefore = 0,
  });
}

class VisualLayer {
  final int colorIdx;
  final double volume;

  const VisualLayer({
    required this.colorIdx,
    required this.volume,
  });

  VisualLayer copyWith({
    int? colorIdx,
    double? volume,
  }) {
    return VisualLayer(
      colorIdx: colorIdx ?? this.colorIdx,
      volume: volume ?? this.volume,
    );
  }
}

class JokerSearchNode {
  final List<List<int>> tubes;
  final int mountainFillUnits;
  final List<String> moves;
  final Map<int, List<List<int>>> refillQueues;
  final int priority;

  const JokerSearchNode({
    required this.tubes,
    required this.mountainFillUnits,
    required this.moves,
    this.refillQueues = const {},
    this.priority = 0,
  });

  String stateId(List<int> activeIndexes) {
    final normalizedTubes = activeIndexes
        .map((i) => tubes[i].join(','))
        .toList(growable: false)
      ..sort();

    final tubesPart = normalizedTubes.join('|');

    final normalizedRefills = refillQueues.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final refillPart = normalizedRefills
        .map(
          (entry) =>
              '${entry.key}:${entry.value.map((pack) => pack.join(',')).join(';')}',
        )
        .join('|');

    return '$tubesPart#$mountainFillUnits#$refillPart';
  }

  bool isSolved({
    required List<int> activeIndexes,
    required int mountainCapacity,
    required int Function(List<List<int>> tubes, int index) tubeCapacityIn,
  }) {
    if (mountainCapacity > 0 && mountainFillUnits < mountainCapacity) {
      return false;
    }

    for (final idx in activeIndexes) {
      final tube = tubes[idx];
      if (tube.isEmpty) continue;
      if (tube.length != tubeCapacityIn(tubes, idx)) return false;

      final first = tube.first;
      if (tube.any((c) => c != first)) return false;
    }

    return true;
  }
}
