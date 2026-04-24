import 'dart:math';

import 'puzzle_presets.dart';

enum DailyPuzzleMapStyle {
  map1,
  map2,
  map3,
}

class DailyPuzzleData {
  final String dateKey;
  final int seed;
  final DailyPuzzleMapStyle mapStyle;
  final int mapNumber;
  final int difficulty;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;
  final StageLayout layout;
  final int? mountainCapacity;
  final List<int>? refillTubeIndexes;
  final Map<int, List<List<int>>>? refillQueues;
  final bool stopRefillWhenMountainFull;

  const DailyPuzzleData({
    required this.dateKey,
    required this.seed,
    required this.mapStyle,
    required this.mapNumber,
    required this.difficulty,
    required this.tubes,
    required this.lockedAdTubeIndex,
    required this.layout,
    this.mountainCapacity,
    this.refillTubeIndexes,
    this.refillQueues,
    this.stopRefillWhenMountainFull = false,
  });

  DailyPuzzleData copyWith({
    String? dateKey,
    int? seed,
    DailyPuzzleMapStyle? mapStyle,
    int? mapNumber,
    int? difficulty,
    List<List<int>>? tubes,
    int? lockedAdTubeIndex,
    StageLayout? layout,
    int? mountainCapacity,
    List<int>? refillTubeIndexes,
    Map<int, List<List<int>>>? refillQueues,
    bool? stopRefillWhenMountainFull,
  }) {
    return DailyPuzzleData(
      dateKey: dateKey ?? this.dateKey,
      seed: seed ?? this.seed,
      mapStyle: mapStyle ?? this.mapStyle,
      mapNumber: mapNumber ?? this.mapNumber,
      difficulty: difficulty ?? this.difficulty,
      tubes: tubes ?? this.tubes,
      lockedAdTubeIndex: lockedAdTubeIndex ?? this.lockedAdTubeIndex,
      layout: layout ?? this.layout,
      mountainCapacity: mountainCapacity ?? this.mountainCapacity,
      refillTubeIndexes: refillTubeIndexes ?? this.refillTubeIndexes,
      refillQueues: refillQueues ?? this.refillQueues,
      stopRefillWhenMountainFull:
          stopRefillWhenMountainFull ?? this.stopRefillWhenMountainFull,
    );
  }
}

class DailyPuzzleGenerator {
  static const int _tubeCapacity = 4;
  static const int _emptyTubeCount = 2;
  static const int _lockedAdTubeCount = 1;
  static const int _maxNormalColorIndexExclusive = 14;

  static DailyPuzzleData generateForDate(DateTime date) {
    final local = date.toLocal();
    final dateKey = _dateKey(local);
    final seed = int.parse(dateKey);
    final rng = Random(seed);

    final mapStyle = _pickMapStyle(seed);

    switch (mapStyle) {
      case DailyPuzzleMapStyle.map1:
        return _buildMap1Daily(
          dateKey: dateKey,
          seed: seed,
          rng: rng,
        );
      case DailyPuzzleMapStyle.map2:
        return _buildMap2Daily(
          dateKey: dateKey,
          seed: seed,
          rng: rng,
        );
      case DailyPuzzleMapStyle.map3:
        return _buildMap3Daily(
          dateKey: dateKey,
          seed: seed,
          rng: rng,
        );
    }
  }

  static String dateKeyOf(DateTime date) => _dateKey(date.toLocal());

  static DailyPuzzleMapStyle _pickMapStyle(int seed) {
    if (seed % 5 == 0) return DailyPuzzleMapStyle.map3;
    if (seed % 3 == 0) return DailyPuzzleMapStyle.map2;
    return DailyPuzzleMapStyle.map1;
  }

  // ─────────────────────────────────────────────
  // MAP 1
  // Standart günlük bulmaca
  // ─────────────────────────────────────────────

  static DailyPuzzleData _buildMap1Daily({
    required String dateKey,
    required int seed,
    required Random rng,
  }) {
    final difficulty = _pickMap1Difficulty(seed);
    final colorCount = _pickMap1ColorCount(difficulty);

    final filledTubeCount = colorCount;
    final totalTubeCount =
        filledTubeCount + _emptyTubeCount + _lockedAdTubeCount;
    final lockedAdTubeIndex = totalTubeCount - 1;

    final palette = _pickColorPalette(
      rng: rng,
      colorCount: colorCount,
      maxExclusive: _maxNormalColorIndexExclusive,
    );

    List<List<int>> tubes = const [];
    int attempt = 0;

    while (attempt < 2500) {
      attempt++;

      final candidate = _buildCandidateTubesMap1(
        rng: Random(seed + attempt * 101),
        palette: palette,
        filledTubeCount: filledTubeCount,
      );

      candidate.add(<int>[]);
      candidate.add(<int>[]);
      candidate.add(<int>[]);

      if (_isAcceptableMap1Start(candidate, filledTubeCount: filledTubeCount)) {
        tubes = candidate;
        break;
      }
    }

    if (tubes.isEmpty) {
      tubes = _buildFallbackTubes(
        palette: palette,
        filledTubeCount: filledTubeCount,
      );
      tubes.add(<int>[]);
      tubes.add(<int>[]);
      tubes.add(<int>[]);
    }

    return DailyPuzzleData(
      dateKey: dateKey,
      seed: seed,
      mapStyle: DailyPuzzleMapStyle.map1,
      mapNumber: 1,
      difficulty: difficulty,
      tubes: tubes,
      lockedAdTubeIndex: lockedAdTubeIndex,
      layout: _buildMap1Layout(totalTubeCount),
    );
  }

  static int _pickMap1Difficulty(int seed) {
    const options = [2, 3, 3, 4, 4];
    return options[seed % options.length];
  }

  static int _pickMap1ColorCount(int difficulty) {
    switch (difficulty) {
      case 2:
        return 8;
      case 3:
        return 9;
      case 4:
        return 10;
      default:
        return 9;
    }
  }

  static List<List<int>> _buildCandidateTubesMap1({
    required Random rng,
    required List<int> palette,
    required int filledTubeCount,
  }) {
    return _buildCandidateTubesGeneric(
      rng: rng,
      palette: palette,
      filledTubeCount: filledTubeCount,
      sameColorAdjacencyLimit: 0,
      favorSpread: true,
    );
  }

  static bool _isAcceptableMap1Start(
    List<List<int>> tubes, {
    required int filledTubeCount,
  }) {
    if (!_validateBasicCountsAndFullness(
      tubes,
      filledTubeCount: filledTubeCount,
    )) {
      return false;
    }

    for (int i = 0; i < filledTubeCount; i++) {
      final t = tubes[i];
      for (int j = 0; j < t.length - 1; j++) {
        if (t[j] == t[j + 1]) return false;
      }
    }

    final legalMoveCount = _countLegalMoves(tubes);
    if (legalMoveCount < 4) return false;

    final doneTubes = _countSolvedTubes(tubes.take(filledTubeCount).toList());
    if (doneTubes > 0) return false;

    return true;
  }

  static StageLayout _buildMap1Layout(int totalTubeCount) {
    final indices = List<int>.generate(totalTubeCount, (i) => i);

    if (totalTubeCount <= 11) {
      return StageLayout.rows(
        rows: [
          indices.take(4).toList(),
          indices.skip(4).take(4).toList(),
          indices.skip(8).toList(),
        ],
        rowTopPaddings: const [0, 0, 4],
        rowGap: 10,
        tubeGap: 6,
      );
    }

    if (totalTubeCount <= 13) {
      return StageLayout.rows(
        rows: [
          indices.take(4).toList(),
          indices.skip(4).take(4).toList(),
          indices.skip(8).take(3).toList(),
          indices.skip(11).toList(),
        ],
        rowTopPaddings: const [0, 0, 4, 4],
        rowGap: 10,
        tubeGap: 6,
      );
    }

    return StageLayout.standardForTubeCount(totalTubeCount);
  }

  // ─────────────────────────────────────────────
  // MAP 2
  // Kör mod günlük bulmaca
  // ─────────────────────────────────────────────

  static DailyPuzzleData _buildMap2Daily({
    required String dateKey,
    required int seed,
    required Random rng,
  }) {
    final difficulty = _pickMap2Difficulty(seed);
    final colorCount = _pickMap2ColorCount(difficulty);

    final filledTubeCount = colorCount;
    final totalTubeCount =
        filledTubeCount + _emptyTubeCount + _lockedAdTubeCount;
    final lockedAdTubeIndex = totalTubeCount - 1;

    final palette = _pickColorPalette(
      rng: rng,
      colorCount: colorCount,
      maxExclusive: _maxNormalColorIndexExclusive,
    );

    List<List<int>> tubes = const [];
    int attempt = 0;

    while (attempt < 3200) {
      attempt++;

      final candidate = _buildCandidateTubesMap2(
        rng: Random(seed + attempt * 137),
        palette: palette,
        filledTubeCount: filledTubeCount,
      );

      candidate.add(<int>[]);
      candidate.add(<int>[]);
      candidate.add(<int>[]);

      if (_isAcceptableMap2Start(candidate, filledTubeCount: filledTubeCount)) {
        tubes = candidate;
        break;
      }
    }

    if (tubes.isEmpty) {
      tubes = _buildFallbackTubes(
        palette: palette,
        filledTubeCount: filledTubeCount,
      );
      tubes.add(<int>[]);
      tubes.add(<int>[]);
      tubes.add(<int>[]);
    }

    return DailyPuzzleData(
      dateKey: dateKey,
      seed: seed,
      mapStyle: DailyPuzzleMapStyle.map2,
      mapNumber: 2,
      difficulty: difficulty,
      tubes: tubes,
      lockedAdTubeIndex: lockedAdTubeIndex,
      layout: _buildMap2Layout(totalTubeCount),
    );
  }

  static int _pickMap2Difficulty(int seed) {
    const options = [3, 4, 4, 5];
    return options[seed % options.length];
  }

  static int _pickMap2ColorCount(int difficulty) {
    switch (difficulty) {
      case 3:
        return 9;
      case 4:
        return 10;
      case 5:
        return 11;
      default:
        return 10;
    }
  }

  static List<List<int>> _buildCandidateTubesMap2({
    required Random rng,
    required List<int> palette,
    required int filledTubeCount,
  }) {
    return _buildCandidateTubesGeneric(
      rng: rng,
      palette: palette,
      filledTubeCount: filledTubeCount,
      sameColorAdjacencyLimit: 1,
      favorSpread: false,
    );
  }

  static bool _isAcceptableMap2Start(
    List<List<int>> tubes, {
    required int filledTubeCount,
  }) {
    if (!_validateBasicCountsAndFullness(
      tubes,
      filledTubeCount: filledTubeCount,
    )) {
      return false;
    }

    int repeatedAdjacencyCount = 0;
    for (int i = 0; i < filledTubeCount; i++) {
      final t = tubes[i];
      for (int j = 0; j < t.length - 1; j++) {
        if (t[j] == t[j + 1]) {
          repeatedAdjacencyCount++;
        }
      }
    }

    if (repeatedAdjacencyCount > max(2, filledTubeCount ~/ 4)) {
      return false;
    }

    final legalMoveCount = _countLegalMoves(tubes);
    if (legalMoveCount < 3) return false;
    if (legalMoveCount > 16) return false;

    final doneTubes = _countSolvedTubes(tubes.take(filledTubeCount).toList());
    if (doneTubes > 0) return false;

    return true;
  }

  static StageLayout _buildMap2Layout(int totalTubeCount) {
    final indices = List<int>.generate(totalTubeCount, (i) => i);

    if (totalTubeCount <= 12) {
      return StageLayout.rows(
        rows: [
          indices.take(3).toList(),
          indices.skip(3).take(4).toList(),
          indices.skip(7).take(3).toList(),
          indices.skip(10).toList(),
        ],
        rowTopPaddings: const [0, 4, 0, 4],
        rowGap: 12,
        tubeGap: 8,
      );
    }

    if (totalTubeCount <= 14) {
      return StageLayout.rows(
        rows: [
          indices.take(3).toList(),
          indices.skip(3).take(4).toList(),
          indices.skip(7).take(4).toList(),
          indices.skip(11).toList(),
        ],
        rowTopPaddings: const [0, 4, 0, 4],
        rowGap: 12,
        tubeGap: 8,
      );
    }

    return StageLayout.standardForTubeCount(totalTubeCount);
  }

  // ─────────────────────────────────────────────
  // MAP 3
  // Volkan / lav günlük bulmaca
  // ─────────────────────────────────────────────

  static DailyPuzzleData _buildMap3Daily({
    required String dateKey,
    required int seed,
    required Random rng,
  }) {
    final difficulty = _pickMap3Difficulty(seed);
    final colorCount = _pickMap3ColorCount(difficulty);

    final palette = _pickColorPalette(
      rng: rng,
      colorCount: colorCount,
      maxExclusive: _maxNormalColorIndexExclusive,
    );

    final mixedTubes = _buildCandidateTubesMap3(
      rng: Random(seed * 13 + 7),
      palette: palette,
      filledTubeCount: colorCount,
    );

    final sourceTubeA = colorCount;
    final sourceTubeB = colorCount + 1;

    final tubes = <List<int>>[
      ...mixedTubes,
      <int>[kLavaColorIndex, kLavaColorIndex, kLavaColorIndex, kLavaColorIndex],
      <int>[kLavaColorIndex, kLavaColorIndex, kLavaColorIndex, kLavaColorIndex],
      <int>[],
      <int>[],
      <int>[],
    ];

    final lockedAdTubeIndex = tubes.length - 1;

    final mountainCapacity = difficulty >= 6 ? 10 : 8;

    final refillQueues = <int, List<List<int>>>{
      sourceTubeA: <List<int>>[
        <int>[
          kLavaColorIndex,
          kLavaColorIndex,
          kLavaColorIndex,
          kLavaColorIndex,
        ],
      ],
      sourceTubeB: <List<int>>[
        <int>[
          kLavaColorIndex,
          kLavaColorIndex,
          kLavaColorIndex,
          kLavaColorIndex,
        ],
      ],
    };

    return DailyPuzzleData(
      dateKey: dateKey,
      seed: seed,
      mapStyle: DailyPuzzleMapStyle.map3,
      mapNumber: 3,
      difficulty: difficulty,
      tubes: tubes,
      lockedAdTubeIndex: lockedAdTubeIndex,
      layout: _buildMap3Layout(tubes.length),
      mountainCapacity: mountainCapacity,
      refillTubeIndexes: <int>[sourceTubeA, sourceTubeB],
      refillQueues: refillQueues,
      stopRefillWhenMountainFull: true,
    );
  }

  static int _pickMap3Difficulty(int seed) {
    const options = [5, 5, 6];
    return options[seed % options.length];
  }

  static int _pickMap3ColorCount(int difficulty) {
    switch (difficulty) {
      case 5:
        return 6;
      case 6:
        return 7;
      default:
        return 6;
    }
  }

  static List<List<int>> _buildCandidateTubesMap3({
    required Random rng,
    required List<int> palette,
    required int filledTubeCount,
  }) {
    return _buildCandidateTubesGeneric(
      rng: rng,
      palette: palette,
      filledTubeCount: filledTubeCount,
      sameColorAdjacencyLimit: 1,
      favorSpread: true,
    );
  }

  static StageLayout _buildMap3Layout(int totalTubeCount) {
    final indices = List<int>.generate(totalTubeCount, (i) => i);

    if (totalTubeCount <= 12) {
      return StageLayout.rows(
        rows: [
          indices.take(4).toList(),
          indices.skip(4).take(4).toList(),
          indices.skip(8).toList(),
        ],
        rowTopPaddings: const [0, 0, 18],
        rowGap: 12,
        tubeGap: 8,
      );
    }

    return StageLayout.rows(
      rows: [
        indices.take(4).toList(),
        indices.skip(4).take(4).toList(),
        indices.skip(8).take(3).toList(),
        indices.skip(11).toList(),
      ],
      rowTopPaddings: const [0, 0, 18, 4],
      rowGap: 12,
      tubeGap: 8,
    );
  }

  // ─────────────────────────────────────────────
  // ORTAK YARDIMCILAR
  // ─────────────────────────────────────────────

  static List<int> _pickColorPalette({
    required Random rng,
    required int colorCount,
    required int maxExclusive,
  }) {
    final all = List<int>.generate(maxExclusive, (i) => i)..shuffle(rng);
    return all.take(colorCount).toList(growable: false);
  }

  static List<List<int>> _buildCandidateTubesGeneric({
    required Random rng,
    required List<int> palette,
    required int filledTubeCount,
    required int sameColorAdjacencyLimit,
    required bool favorSpread,
  }) {
    final pieces = <int>[];
    for (final color in palette) {
      pieces.addAll([color, color, color, color]);
    }

    for (int attempt = 0; attempt < 300; attempt++) {
      final shuffled = List<int>.from(pieces)
        ..shuffle(Random(rng.nextInt(1 << 30) + 1));

      final tubes = List<List<int>>.generate(
        filledTubeCount,
        (_) => <int>[],
        growable: true,
      );

      var ok = true;

      for (final color in shuffled) {
        final candidates = <int>[];

        for (int i = 0; i < tubes.length; i++) {
          final tube = tubes[i];
          if (tube.length >= _tubeCapacity) continue;

          int adjacentCount = 0;
          if (tube.isNotEmpty && tube.last == color) {
            adjacentCount = 1;
            if (adjacentCount > sameColorAdjacencyLimit) continue;
          }

          candidates.add(i);
        }

        if (candidates.isEmpty) {
          ok = false;
          break;
        }

        candidates.sort((a, b) {
          final lenCompare = tubes[a].length.compareTo(tubes[b].length);
          if (lenCompare != 0) {
            return favorSpread ? lenCompare : -lenCompare;
          }
          return a.compareTo(b);
        });

        final bestLength = tubes[candidates.first].length;
        final filtered = candidates.where((i) {
          if (favorSpread) {
            return tubes[i].length == bestLength;
          }
          return true;
        }).toList(growable: false)
          ..shuffle(rng);

        tubes[filtered.first].add(color);
      }

      if (!ok) continue;
      if (tubes.every((t) => t.length == _tubeCapacity)) {
        return tubes;
      }
    }

    return _buildSimpleMixedTubes(
      rng: rng,
      palette: palette,
      filledTubeCount: filledTubeCount,
    );
  }

  static List<List<int>> _buildSimpleMixedTubes({
    required Random rng,
    required List<int> palette,
    required int filledTubeCount,
  }) {
    final values = <int>[];
    for (final c in palette) {
      values.addAll([c, c, c, c]);
    }

    while (true) {
      final shuffled = List<int>.from(values)..shuffle(rng);
      final tubes = List<List<int>>.generate(
        filledTubeCount,
        (i) => shuffled.skip(i * 4).take(4).toList(growable: true),
        growable: true,
      );

      bool ok = true;
      for (final t in tubes) {
        int adjacent = 0;
        for (int i = 0; i < t.length - 1; i++) {
          if (t[i] == t[i + 1]) adjacent++;
        }
        if (adjacent > 1) {
          ok = false;
          break;
        }
      }

      if (ok) return tubes;
    }
  }

  static List<List<int>> _buildFallbackTubes({
    required List<int> palette,
    required int filledTubeCount,
  }) {
    final values = <int>[];
    for (final c in palette) {
      values.addAll([c, c, c, c]);
    }

    final tubes = List<List<int>>.generate(
      filledTubeCount,
      (_) => <int>[],
      growable: true,
    );

    int cursor = 0;
    for (int layer = 0; layer < _tubeCapacity; layer++) {
      for (int i = 0; i < filledTubeCount; i++) {
        tubes[i].add(values[cursor++]);
      }
    }

    return tubes;
  }

  static bool _validateBasicCountsAndFullness(
    List<List<int>> tubes, {
    required int filledTubeCount,
  }) {
    for (int i = 0; i < filledTubeCount; i++) {
      if (tubes[i].length != _tubeCapacity) return false;
    }

    final counts = <int, int>{};
    for (final t in tubes) {
      for (final c in t) {
        if (c == kLavaColorIndex) continue;
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }

    if (counts.values.any((v) => v != 4)) return false;

    return true;
  }

  static int _countLegalMoves(List<List<int>> tubes) {
    int legalMoveCount = 0;
    for (int from = 0; from < tubes.length; from++) {
      for (int to = 0; to < tubes.length; to++) {
        if (from == to) continue;
        if (_canPour(tubes, from, to)) {
          legalMoveCount++;
        }
      }
    }
    return legalMoveCount;
  }

  static int _countSolvedTubes(List<List<int>> tubes) {
    int count = 0;
    for (final t in tubes) {
      if (t.length == _tubeCapacity && t.every((e) => e == t.first)) {
        count++;
      }
    }
    return count;
  }

  static bool _canPour(List<List<int>> tubes, int from, int to) {
    if (tubes[from].isEmpty) return false;
    if (tubes[to].length >= _tubeCapacity) return false;

    final top = tubes[from].last;
    if (tubes[to].isNotEmpty && tubes[to].last != top) return false;

    return true;
  }

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
