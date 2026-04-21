import 'dart:math';

typedef TubeCapacityResolver = int Function(List<List<int>> tubes, int index);

bool canPourBasic(
  List<List<int>> tubes,
  int from,
  int to, {
  int cap = 4,
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

int pourCountBasic(
  List<List<int>> tubes,
  int from,
  int to, {
  int cap = 4,
}) {
  if (!canPourBasic(tubes, from, to, cap: cap)) return 0;

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

void doPourBasic(
  List<List<int>> tubes,
  int from,
  int to, {
  int cap = 4,
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

bool isTubeDoneBasic(
  List<int> tube, {
  int cap = 4,
}) {
  return tube.length == cap && tube.every((c) => c == tube[0]);
}

bool isGameDoneBasic(
  List<List<int>> tubes, {
  int cap = 4,
}) {
  return tubes.every((t) => t.isEmpty || isTubeDoneBasic(t, cap: cap));
}

bool canPourIn(
  List<List<int>> tubes,
  int from,
  int to, {
  required TubeCapacityResolver tubeCapacityIn,
}) {
  if (from == to) return false;
  if (from < 0 || from >= tubes.length || to < 0 || to >= tubes.length) {
    return false;
  }
  if (tubes[from].isEmpty) return false;
  if (tubes[to].length >= tubeCapacityIn(tubes, to)) return false;

  final movingColor = tubes[from].last;
  if (tubes[to].isNotEmpty && tubes[to].last != movingColor) return false;

  return true;
}

int pourCountIn(
  List<List<int>> tubes,
  int from,
  int to, {
  required TubeCapacityResolver tubeCapacityIn,
}) {
  if (!canPourIn(tubes, from, to, tubeCapacityIn: tubeCapacityIn)) return 0;

  final top = tubes[from].last;
  int count = 0;
  final available = tubeCapacityIn(tubes, to) - tubes[to].length;

  for (int i = tubes[from].length - 1; i >= 0; i--) {
    if (tubes[from][i] == top) {
      count++;
    } else {
      break;
    }
  }

  return count.clamp(0, available);
}

void doPourIn(
  List<List<int>> tubes,
  int from,
  int to, {
  required TubeCapacityResolver tubeCapacityIn,
}) {
  final fromTube = List<int>.from(tubes[from]);
  final toTube = List<int>.from(tubes[to]);
  final top = fromTube.last;
  final cap = tubeCapacityIn(tubes, to);

  while (fromTube.isNotEmpty && fromTube.last == top && toTube.length < cap) {
    toTube.add(fromTube.removeLast());
  }

  tubes[from] = fromTube;
  tubes[to] = toTube;
}

bool isTubeDoneIn(
  List<List<int>> tubes,
  int idx, {
  required TubeCapacityResolver tubeCapacityIn,
}) {
  final tube = tubes[idx];
  if (tube.isEmpty) return false;

  final cap = tubeCapacityIn(tubes, idx);
  if (tube.length != cap) return false;
  if (!tube.every((c) => c == tube.first)) return false;

  return true;
}

bool isGameDoneIn(
  List<List<int>> tubes, {
  required TubeCapacityResolver tubeCapacityIn,
  required bool hasMountainObjective,
  required int mountainFillUnits,
  required int mountainCapacity,
}) {
  if (hasMountainObjective && mountainFillUnits < mountainCapacity) {
    return false;
  }

  for (int i = 0; i < tubes.length; i++) {
    if (tubes[i].isEmpty) continue;
    if (!isTubeDoneIn(tubes, i, tubeCapacityIn: tubeCapacityIn)) {
      return false;
    }
  }

  return true;
}

List<List<int>> cloneBoard(List<List<int>> source) {
  return source
      .map((tube) => List<int>.from(tube, growable: true))
      .toList(growable: true);
}

bool canPourToMountainIn(
  List<List<int>> tubes,
  int from, {
  required bool hasMountainObjective,
  required bool showLockedAdTube,
  required int lockedAdTubeIndex,
  required bool Function(int colorIdx) isLavaColorIndex,
}) {
  if (!hasMountainObjective) return false;
  if (showLockedAdTube && from == lockedAdTubeIndex) return false;
  if (from < 0 || from >= tubes.length || tubes[from].isEmpty) return false;
  if (!isLavaColorIndex(tubes[from].last)) return false;

  return true;
}

int mountainPourCountIn(
  List<List<int>> tubes,
  int from, {
  required bool hasMountainObjective,
  required bool showLockedAdTube,
  required int lockedAdTubeIndex,
  required int mountainCapacity,
  required int currentMountainFillUnits,
  required bool Function(int colorIdx) isLavaColorIndex,
}) {
  if (!canPourToMountainIn(
    tubes,
    from,
    hasMountainObjective: hasMountainObjective,
    showLockedAdTube: showLockedAdTube,
    lockedAdTubeIndex: lockedAdTubeIndex,
    isLavaColorIndex: isLavaColorIndex,
  )) {
    return 0;
  }

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
