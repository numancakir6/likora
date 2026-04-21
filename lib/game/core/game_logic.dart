const int kTubeCap = 4;

bool canPourBoard(
  List<List<int>> tubes,
  int from,
  int to, {
  int cap = kTubeCap,
}) {
  if (from == to) return false;
  if (from < 0 || from >= tubes.length || to < 0 || to >= tubes.length) {
    return false;
  }
  if (tubes[from].isEmpty) return false;
  if (tubes[to].length >= cap) return false;

  final top = tubes[from].last;
  if (tubes[to].isNotEmpty && tubes[to].last != top) return false;

  return true;
}

int pourCountBoard(
  List<List<int>> tubes,
  int from,
  int to, {
  int cap = kTubeCap,
}) {
  if (!canPourBoard(tubes, from, to, cap: cap)) return 0;

  final top = tubes[from].last;
  int count = 0;
  final available = cap - tubes[to].length;

  for (int i = tubes[from].length - 1; i >= 0; i--) {
    if (tubes[from][i] == top) {
      count++;
    } else {
      break;
    }
  }

  return count.clamp(0, available);
}

void doPourBoard(
  List<List<int>> tubes,
  int from,
  int to, {
  int cap = kTubeCap,
}) {
  final fromTube = List<int>.from(tubes[from]);
  final toTube = List<int>.from(tubes[to]);

  final top = fromTube.last;
  while (fromTube.isNotEmpty && fromTube.last == top && toTube.length < cap) {
    toTube.add(fromTube.removeLast());
  }

  tubes[from] = fromTube;
  tubes[to] = toTube;
}

bool isTubeDoneBoard(
  List<int> tube, {
  int cap = kTubeCap,
}) {
  return tube.length == cap && tube.every((c) => c == tube[0]);
}

bool isGameDoneBoard(
  List<List<int>> tubes, {
  int cap = kTubeCap,
}) {
  return tubes.every((t) => t.isEmpty || isTubeDoneBoard(t, cap: cap));
}

List<List<int>> cloneBoardState(List<List<int>> source) {
  return source
      .map((tube) => List<int>.from(tube, growable: true))
      .toList(growable: true);
}

List<List<int>> buildCompletedTubesFromInitialBoard(
  List<List<int>> initialTubes, {
  int Function(List<List<int>> tubes, int index)? tubeCapacityResolver,
}) {
  final colorCounts = <int, int>{};
  for (final tube in initialTubes) {
    for (final color in tube) {
      colorCounts[color] = (colorCounts[color] ?? 0) + 1;
    }
  }

  final solvedColors = colorCounts.keys.toList()..sort();
  final result = <List<int>>[];
  final usedColors = <int>{};

  int capFor(int index) =>
      tubeCapacityResolver?.call(initialTubes, index) ?? kTubeCap;

  for (int i = 0; i < initialTubes.length; i++) {
    if (initialTubes[i].isEmpty) {
      result.add(<int>[]);
      continue;
    }

    final nextColor = solvedColors.firstWhere(
      (color) =>
          !usedColors.contains(color) && colorCounts[color]! >= capFor(i),
      orElse: () => solvedColors.firstWhere(
        (color) => !usedColors.contains(color),
        orElse: () => solvedColors.first,
      ),
    );

    usedColors.add(nextColor);
    result.add(List<int>.filled(capFor(i), nextColor, growable: true));
  }

  while (result.length < initialTubes.length) {
    result.add(<int>[]);
  }

  return result;
}
