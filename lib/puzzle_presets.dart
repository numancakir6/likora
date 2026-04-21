const int kLavaColorIndex = 16;

class PuzzleMove {
  final int from;
  final int to;

  const PuzzleMove(this.from, this.to);
}

enum PuzzleTubeStyle {
  classic,
  largeCollector,
}

enum StageLayoutMode {
  rows,
  manual,
}

class StageTubePosition {
  final int index;
  final double x;
  final double y;
  final PuzzleTubeStyle style;

  const StageTubePosition({
    required this.index,
    required this.x,
    required this.y,
    this.style = PuzzleTubeStyle.classic,
  });
}

class SourceTubeRefillConfig {
  final List<int> tubeIndexes;
  final Map<int, List<List<int>>> refillQueues;
  final bool stopWhenMountainFull;

  const SourceTubeRefillConfig({
    required this.tubeIndexes,
    required this.refillQueues,
    this.stopWhenMountainFull = true,
  });
}

class StageLayout {
  final StageLayoutMode mode;
  final List<List<int>> rows;
  final List<double> rowTopPaddings;
  final List<StageTubePosition> positions;
  final double tubeGap;
  final double rowGap;
  final double topOffset;
  final double? canvasWidth;
  final double? canvasHeight;

  const StageLayout._({
    required this.mode,
    required this.rows,
    required this.rowTopPaddings,
    required this.positions,
    required this.tubeGap,
    required this.rowGap,
    required this.topOffset,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  const StageLayout.rows({
    required List<List<int>> rows,
    List<double> rowTopPaddings = const [],
    double tubeGap = 20.0,
    double rowGap = 20.0,
    double topOffset = 0.0,
  }) : this._(
          mode: StageLayoutMode.rows,
          rows: rows,
          rowTopPaddings: rowTopPaddings,
          positions: const [],
          tubeGap: tubeGap,
          rowGap: rowGap,
          topOffset: topOffset,
          canvasWidth: null,
          canvasHeight: null,
        );

  const StageLayout.manual({
    required List<StageTubePosition> positions,
    required double canvasWidth,
    required double canvasHeight,
    double tubeGap = 20.0,
    double rowGap = 20.0,
    double topOffset = 0.0,
  }) : this._(
          mode: StageLayoutMode.manual,
          rows: const [],
          rowTopPaddings: const [],
          positions: positions,
          tubeGap: tubeGap,
          rowGap: rowGap,
          topOffset: topOffset,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
        );

  factory StageLayout.standardForTubeCount(int tubeCount) {
    final safeCount = tubeCount < 1 ? 1 : tubeCount;

    if (safeCount <= 4) {
      return StageLayout.rows(
        rows: [List<int>.generate(safeCount, (i) => i)],
      );
    }

    final maxPerRow = safeCount <= 16 ? 4 : 5;
    final indices = List<int>.generate(safeCount, (i) => i);
    final rows = <List<int>>[];

    var cursor = 0;
    while (cursor < indices.length) {
      final remaining = indices.length - cursor;
      final take = remaining > maxPerRow ? maxPerRow : remaining;
      rows.add(indices.sublist(cursor, cursor + take));
      cursor += take;
    }

    final paddings = List<double>.filled(rows.length, 0);
    if (paddings.isNotEmpty) {
      paddings[paddings.length - 1] = 4;
    }

    return StageLayout.rows(
      rows: rows,
      rowTopPaddings: paddings,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PUZZLE PRESET
// ─────────────────────────────────────────────────────────────────

class PuzzlePreset {
  final int mapNumber;
  final int levelId;
  final int difficulty;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;
  final StageLayout layout;
  final PuzzleTubeStyle tubeStyle;
  final Map<int, PuzzleTubeStyle> tubeStyles;

  final int? mountainCapacity;
  final SourceTubeRefillConfig? sourceRefill;

  const PuzzlePreset({
    required this.mapNumber,
    required this.levelId,
    required this.difficulty,
    required this.tubes,
    required this.layout,
    this.lockedAdTubeIndex = 10,
    this.tubeStyle = PuzzleTubeStyle.classic,
    this.tubeStyles = const {},
    this.mountainCapacity,
    this.sourceRefill,
  });
}

// ─────────────────────────────────────────────────────────────────
// PUZZLE PRESETS
// ─────────────────────────────────────────────────────────────────

class PuzzlePresets {
  static PuzzlePreset get({
    required int mapNumber,
    required int levelId,
  }) {
    final preset = getOrNull(mapNumber: mapNumber, levelId: levelId);
    if (preset == null) {
      throw StateError('Level bulunamadi: map=$mapNumber level=$levelId');
    }
    return preset;
  }

  static PuzzlePreset? getOrNull({
    required int mapNumber,
    required int levelId,
  }) {
    return _presets[mapNumber]?[levelId];
  }

  static String signatureOf(List<List<int>> tubes) {
    return tubes.map((t) => t.join(',')).join('|');
  }

  static final Map<int, Map<int, PuzzlePreset>> _presets = {
    // ═══════════════════════════════════════════════════════════════
    // MAP 1 — KLASIK MOD (10 Level)
    // ═══════════════════════════════════════════════════════════════
    //
    // Mekanik: Tum sivilar gorunur. Klasik water-sort.
    //
    // Zorluk egrisi:
    //   L1 : 3 renk, 3 tup  — giris, ama az boslukla sikisik
    //   L2 : 4 renk, 4 tup  — her renk her tupte, latin kare
    //   L3 : 4 renk, 4 tup  — bazi renkler ayni tupte 2x, kose sikismasi
    //   L4 : 5 renk, 5 tup  — kritik hamle sirasi var
    //   L5 : 5 renk, 5 tup  — her tupte 1 renk 2x gomulu
    //   L6 : 6 renk, 6 tup  — dongusal bagimlilik
    //   L7 : 6 renk, 6 tup  — joker olmadan cikmaza girebilir
    //   L8 : 7 renk, 7 tup  — derin bulmaca
    //   L9 : 8 renk, 8 tup  — cok sikisik
    //   L10: 8 renk, 8 tup  — neredeyse tek hamle sirasi
    //
    1: {
      1: PuzzlePreset(
        mapNumber: 1,
        levelId: 1,
        difficulty: 1,
        tubes: [
          [0, 1, 2, 1],
          [2, 0, 1, 0],
          [1, 2, 0, 2],
          [1, 2, 0, 2],
          [1, 2, 0, 2],
          [1, 2, 0, 2],
          [1, 2, 0, 2],
          [1, 2, 0, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(6),
        lockedAdTubeIndex: 5,
      ),
      2: PuzzlePreset(
        mapNumber: 1,
        levelId: 2,
        difficulty: 2,
        tubes: [
          [1, 3, 0, 2],
          [0, 2, 3, 1],
          [2, 1, 0, 3],
          [3, 0, 2, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(7),
        lockedAdTubeIndex: 6,
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 2,
        tubes: [
          [2, 0, 3, 0],
          [1, 3, 2, 3],
          [0, 2, 1, 2],
          [3, 1, 0, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(7),
        lockedAdTubeIndex: 6,
      ),
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 3,
        tubes: [
          [0, 4, 2, 1],
          [3, 1, 4, 2],
          [4, 0, 3, 4],
          [2, 3, 0, 3],
          [1, 2, 1, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(8),
        lockedAdTubeIndex: 7,
      ),
      5: PuzzlePreset(
        mapNumber: 1,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [0, 2, 4, 0],
          [1, 3, 2, 1],
          [4, 0, 1, 4],
          [3, 4, 0, 3],
          [2, 1, 3, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(8),
        lockedAdTubeIndex: 7,
      ),
      6: PuzzlePreset(
        mapNumber: 1,
        levelId: 6,
        difficulty: 4,
        tubes: [
          [5, 1, 3, 0],
          [2, 4, 0, 5],
          [3, 2, 5, 4],
          [0, 3, 4, 1],
          [4, 5, 1, 2],
          [1, 0, 2, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
      ),
      7: PuzzlePreset(
        mapNumber: 1,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [3, 5, 1, 4],
          [0, 2, 4, 3],
          [5, 4, 0, 2],
          [1, 3, 5, 0],
          [2, 0, 3, 5],
          [4, 1, 2, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
      ),
      8: PuzzlePreset(
        mapNumber: 1,
        levelId: 8,
        difficulty: 4,
        tubes: [
          [6, 2, 0, 4],
          [1, 5, 3, 6],
          [4, 0, 6, 2],
          [3, 4, 1, 5],
          [5, 6, 4, 0],
          [2, 1, 5, 3],
          [0, 3, 2, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(10),
        lockedAdTubeIndex: 9,
      ),
      9: PuzzlePreset(
        mapNumber: 1,
        levelId: 9,
        difficulty: 5,
        tubes: [
          [7, 3, 1, 5],
          [0, 6, 4, 2],
          [5, 1, 7, 3],
          [2, 4, 0, 6],
          [6, 0, 5, 4],
          [3, 7, 2, 0],
          [4, 2, 6, 7],
          [1, 5, 3, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 5,
        tubes: [
          [5, 2, 7, 0],
          [3, 6, 1, 4],
          [7, 4, 2, 6],
          [0, 1, 5, 3],
          [6, 3, 0, 7],
          [4, 5, 3, 1],
          [1, 7, 4, 5],
          [2, 0, 6, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
    },
    2: {
      1: PuzzlePreset(
        mapNumber: 2,
        levelId: 1,
        difficulty: 1,
        tubes: [
          [2, 0, 3, 1],
          [1, 3, 0, 2],
          [3, 1, 2, 0],
          [0, 2, 1, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(7),
        lockedAdTubeIndex: 6,
      ),
      2: PuzzlePreset(
        mapNumber: 2,
        levelId: 2,
        difficulty: 1,
        tubes: [
          [3, 1, 0, 2],
          [0, 2, 3, 1],
          [1, 0, 2, 3],
          [2, 3, 1, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(7),
        lockedAdTubeIndex: 6,
      ),
      3: PuzzlePreset(
        mapNumber: 2,
        levelId: 3,
        difficulty: 2,
        tubes: [
          [0, 4, 2, 3],
          [3, 1, 4, 0],
          [4, 2, 0, 1],
          [2, 3, 1, 4],
          [1, 0, 3, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(8),
        lockedAdTubeIndex: 7,
      ),
      4: PuzzlePreset(
        mapNumber: 2,
        levelId: 4,
        difficulty: 2,
        tubes: [
          [1, 4, 0, 3],
          [3, 0, 2, 4],
          [4, 3, 1, 0],
          [0, 2, 4, 1],
          [2, 1, 3, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(8),
        lockedAdTubeIndex: 7,
      ),
      5: PuzzlePreset(
        mapNumber: 2,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [5, 2, 0, 4],
          [1, 4, 3, 5],
          [3, 0, 5, 2],
          [4, 1, 2, 3],
          [0, 3, 4, 1],
          [2, 5, 1, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
      ),
      6: PuzzlePreset(
        mapNumber: 2,
        levelId: 6,
        difficulty: 3,
        tubes: [
          [2, 5, 3, 0],
          [4, 0, 2, 5],
          [5, 3, 4, 1],
          [0, 4, 1, 3],
          [3, 1, 0, 4],
          [1, 2, 5, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
      ),
      7: PuzzlePreset(
        mapNumber: 2,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [6, 2, 4, 0],
          [3, 5, 0, 6],
          [0, 4, 3, 5],
          [5, 6, 1, 2],
          [2, 1, 6, 3],
          [4, 3, 2, 1],
          [1, 0, 5, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(10),
        lockedAdTubeIndex: 9,
      ),
      8: PuzzlePreset(
        mapNumber: 2,
        levelId: 8,
        difficulty: 4,
        tubes: [
          [4, 1, 6, 2],
          [0, 5, 3, 4],
          [5, 2, 0, 6],
          [6, 3, 4, 1],
          [2, 6, 5, 3],
          [3, 0, 2, 5],
          [1, 4, 1, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(10),
        lockedAdTubeIndex: 9,
      ),
      9: PuzzlePreset(
        mapNumber: 2,
        levelId: 9,
        difficulty: 4,
        tubes: [
          [7, 2, 5, 0],
          [3, 6, 1, 4],
          [5, 1, 7, 3],
          [0, 4, 6, 2],
          [4, 7, 2, 6],
          [6, 0, 4, 5],
          [2, 5, 3, 7],
          [1, 3, 0, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      10: PuzzlePreset(
        mapNumber: 2,
        levelId: 10,
        difficulty: 5,
        tubes: [
          [6, 1, 5, 3],
          [2, 7, 0, 4],
          [4, 3, 6, 1],
          [0, 5, 2, 7],
          [7, 4, 3, 5],
          [3, 0, 7, 2],
          [5, 2, 4, 0],
          [1, 6, 1, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      11: PuzzlePreset(
        mapNumber: 2,
        levelId: 11,
        difficulty: 5,
        tubes: [
          [8, 3, 1, 5],
          [0, 7, 4, 2],
          [6, 1, 8, 3],
          [4, 5, 0, 7],
          [2, 8, 6, 4],
          [5, 0, 3, 8],
          [7, 4, 2, 6],
          [3, 6, 7, 0],
          [1, 2, 5, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
      ),
      12: PuzzlePreset(
        mapNumber: 2,
        levelId: 12,
        difficulty: 5,
        tubes: [
          [5, 8, 2, 6],
          [1, 4, 7, 0],
          [8, 6, 3, 5],
          [0, 2, 8, 4],
          [6, 1, 0, 7],
          [4, 7, 5, 3],
          [3, 0, 4, 8],
          [7, 5, 1, 2],
          [2, 3, 6, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
      ),
    },
    3: {
      1: PuzzlePreset(
        mapNumber: 3,
        levelId: 1,
        difficulty: 2,
        mountainCapacity: 12,
        tubes: [
          [16, 2, 16, 0], // refill 0
          [16, 1, 3, 16], // refill 1
          [0, 16, 1, 16],
          [3, 16, 0, 2],
          [2, 3, 16, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(8),
        lockedAdTubeIndex: 7,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1],
          refillQueues: {
            0: [
              [16, 3, 16, 2],
            ],
            1: [
              [0, 16, 1, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      2: PuzzlePreset(
        mapNumber: 3,
        levelId: 2,
        difficulty: 2,
        mountainCapacity: 16,
        tubes: [
          [16, 0, 16, 3], // refill 0
          [2, 16, 1, 16], // refill 1
          [16, 0, 16, 1],
          [3, 16, 2, 16],
          [16, 3, 16, 2],
          [1, 16, 0, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1],
          refillQueues: {
            0: [
              [16, 1, 16, 2],
            ],
            1: [
              [0, 16, 3, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      3: PuzzlePreset(
        mapNumber: 3,
        levelId: 3,
        difficulty: 3,
        mountainCapacity: 16,
        tubes: [
          [16, 2, 16, 0], // refill 0
          [0, 16, 2, 1], // refill 1
          [16, 1, 4, 1], // refill 2
          [3, 16, 3, 4],
          [16, 16, 16, 16],
          [16, 16, 16, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2],
          refillQueues: {
            0: [
              [0, 16, 3, 0],
            ],
            1: [
              [16, 4, 1, 2],
            ],
            2: [
              [16, 4, 3, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      4: PuzzlePreset(
        mapNumber: 3,
        levelId: 4,
        difficulty: 3,
        mountainCapacity: 20,
        tubes: [
          [16, 0, 16, 3], // refill 0
          [4, 16, 2, 16], // refill 1
          [16, 1, 16, 4], // refill 2
          [16, 2, 16, 0],
          [3, 16, 1, 16],
          [16, 4, 16, 1],
          [0, 16, 3, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(10),
        lockedAdTubeIndex: 9,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2],
          refillQueues: {
            0: [
              [16, 2, 16, 4],
            ],
            1: [
              [1, 16, 0, 16],
            ],
            2: [
              [16, 3, 16, 2],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      5: PuzzlePreset(
        mapNumber: 3,
        levelId: 5,
        difficulty: 3,
        mountainCapacity: 20,
        tubes: [
          [0, 4, 2, 5], // refill 0
          [16, 3, 16, 16], // refill 1
          [16, 1, 0, 16], // refill 2
          [0, 1, 16, 16],
          [3, 16, 2, 1],
          [2, 3, 5, 16],
          [16, 16, 4, 16],
          [0, 16, 4, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2],
          refillQueues: {
            0: [
              [16, 16, 5, 16],
            ],
            1: [
              [4, 16, 5, 3],
            ],
            2: [
              [16, 1, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      6: PuzzlePreset(
        mapNumber: 3,
        levelId: 6,
        difficulty: 4,
        mountainCapacity: 24,
        tubes: [
          [16, 16, 0, 16], // refill 0 — cok lav yogun!
          [16, 4, 5, 16], // refill 1
          [5, 0, 3, 1], // refill 2
          [5, 3, 16, 1], // refill 3
          [0, 16, 2, 4],
          [3, 16, 16, 16],
          [16, 1, 4, 16],
          [4, 3, 16, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3],
          refillQueues: {
            0: [
              [2, 5, 16, 2],
            ],
            1: [
              [16, 16, 16, 0],
            ],
            2: [
              [1, 16, 2, 16],
            ],
            3: [
              [16, 16, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      7: PuzzlePreset(
        mapNumber: 3,
        levelId: 7,
        difficulty: 4,
        mountainCapacity: 24,
        tubes: [
          [16, 16, 16, 16], // refill 0 — tamamen lav!
          [2, 1, 5, 16], // refill 1
          [0, 16, 2, 6], // refill 2
          [5, 16, 4, 16], // refill 3
          [1, 4, 6, 2],
          [16, 0, 16, 2],
          [3, 16, 16, 16],
          [1, 16, 16, 0],
          [16, 6, 16, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3],
          refillQueues: {
            0: [
              [3, 5, 16, 0],
            ],
            1: [
              [4, 16, 16, 6],
            ],
            2: [
              [16, 5, 1, 3],
            ],
            3: [
              [16, 3, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      8: PuzzlePreset(
        mapNumber: 3,
        levelId: 8,
        difficulty: 4,
        mountainCapacity: 28,
        tubes: [
          [16, 16, 2, 16], // refill 0
          [3, 16, 6, 16], // refill 1
          [3, 16, 6, 0], // refill 2
          [4, 16, 3, 16], // refill 3
          [0, 16, 1, 2],
          [16, 6, 2, 16],
          [4, 6, 16, 16],
          [16, 5, 1, 16],
          [0, 16, 16, 1],
          [16, 0, 4, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3],
          refillQueues: {
            0: [
              [5, 16, 16, 5],
            ],
            1: [
              [16, 16, 16, 16],
            ],
            2: [
              [5, 3, 16, 16],
            ],
            3: [
              [1, 16, 16, 4],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      9: PuzzlePreset(
        mapNumber: 3,
        levelId: 9,
        difficulty: 5,
        mountainCapacity: 28,
        tubes: [
          [16, 2, 7, 1], // refill 0
          [1, 16, 2, 16], // refill 1
          [16, 16, 0, 16], // refill 2
          [16, 3, 16, 4], // refill 3
          [16, 16, 7, 4],
          [16, 1, 16, 4],
          [16, 16, 3, 4],
          [3, 16, 16, 16],
          [16, 0, 1, 0],
          [16, 16, 16, 5],
          [16, 16, 16, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3],
          refillQueues: {
            0: [
              [5, 6, 7, 6],
            ],
            1: [
              [16, 7, 2, 5],
            ],
            2: [
              [16, 2, 16, 5],
            ],
            3: [
              [6, 0, 3, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      10: PuzzlePreset(
        mapNumber: 3,
        levelId: 10,
        difficulty: 5,
        mountainCapacity: 32,
        tubes: [
          [4, 16, 16, 16], // refill 0
          [16, 16, 16, 16], // refill 1 — tamamen lav!
          [16, 7, 3, 5], // refill 2
          [16, 1, 16, 16], // refill 3
          [16, 0, 16, 16], // refill 4
          [5, 16, 6, 16],
          [6, 4, 16, 16],
          [7, 16, 2, 16],
          [0, 6, 4, 3],
          [16, 3, 7, 2],
          [2, 5, 16, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4],
          refillQueues: {
            0: [
              [2, 7, 16, 16],
            ],
            1: [
              [1, 16, 0, 1],
            ],
            2: [
              [16, 16, 4, 1],
            ],
            3: [
              [0, 5, 16, 3],
            ],
            4: [
              [16, 16, 6, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      11: PuzzlePreset(
        mapNumber: 3,
        levelId: 11,
        difficulty: 5,
        mountainCapacity: 32,
        tubes: [
          [16, 6, 16, 16], // refill 0
          [16, 16, 8, 16], // refill 1
          [3, 5, 16, 7], // refill 2
          [1, 5, 4, 16], // refill 3
          [16, 1, 16, 8], // refill 4
          [2, 16, 16, 8],
          [16, 3, 16, 16],
          [3, 16, 2, 16],
          [0, 5, 6, 4],
          [0, 16, 8, 16],
          [1, 16, 2, 16],
          [7, 4, 16, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4],
          refillQueues: {
            0: [
              [4, 16, 16, 16],
            ],
            1: [
              [0, 5, 16, 0],
            ],
            2: [
              [16, 6, 1, 16],
            ],
            3: [
              [16, 16, 3, 2],
            ],
            4: [
              [6, 7, 16, 7],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      12: PuzzlePreset(
        mapNumber: 3,
        levelId: 12,
        difficulty: 5,
        mountainCapacity: 32,
        tubes: [
          [16, 5, 16, 7], // refill 0
          [9, 0, 7, 8], // refill 1
          [16, 1, 16, 16], // refill 2
          [16, 2, 3, 16], // refill 3
          [16, 6, 16, 16], // refill 4
          [0, 16, 1, 16],
          [16, 16, 16, 1],
          [4, 16, 16, 0],
          [8, 3, 6, 16],
          [16, 16, 9, 16],
          [16, 16, 4, 1],
          [16, 8, 16, 7],
          [7, 3, 8, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(16),
        lockedAdTubeIndex: 15,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4],
          refillQueues: {
            0: [
              [6, 4, 2, 5],
            ],
            1: [
              [9, 2, 16, 2],
            ],
            2: [
              [4, 16, 0, 16],
            ],
            3: [
              [16, 3, 6, 5],
            ],
            4: [
              [9, 16, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      13: PuzzlePreset(
        mapNumber: 3,
        levelId: 13,
        difficulty: 5,
        mountainCapacity: 36,
        tubes: [
          [6, 16, 16, 16], // refill 0
          [16, 16, 0, 2], // refill 1
          [16, 1, 9, 16], // refill 2
          [4, 16, 16, 5], // refill 3
          [5, 16, 7, 8], // refill 4
          [1, 3, 5, 8],
          [1, 3, 0, 2],
          [16, 9, 16, 16],
          [4, 5, 16, 16],
          [16, 16, 16, 16],
          [6, 8, 0, 16],
          [16, 6, 16, 16],
          [9, 16, 8, 6],
          [16, 7, 16, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(17),
        lockedAdTubeIndex: 16,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4],
          refillQueues: {
            0: [
              [16, 0, 1, 16],
            ],
            1: [
              [16, 3, 16, 9],
            ],
            2: [
              [16, 2, 4, 7],
            ],
            3: [
              [7, 3, 16, 16],
            ],
            4: [
              [16, 2, 16, 4],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      14: PuzzlePreset(
        mapNumber: 3,
        levelId: 14,
        difficulty: 5,
        mountainCapacity: 36,
        tubes: [
          [9, 16, 16, 0], // refill 0
          [16, 16, 3, 4], // refill 1
          [0, 7, 16, 2], // refill 2
          [1, 7, 16, 7], // refill 3
          [8, 10, 16, 8], // refill 4
          [16, 2, 6, 1], // refill 5
          [2, 16, 16, 16],
          [16, 16, 16, 0],
          [16, 3, 16, 4],
          [1, 16, 10, 16],
          [0, 16, 16, 16],
          [16, 6, 5, 16],
          [9, 16, 16, 8],
          [7, 16, 10, 9],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(17),
        lockedAdTubeIndex: 16,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5],
          refillQueues: {
            0: [
              [9, 8, 4, 16],
            ],
            1: [
              [16, 1, 16, 2],
            ],
            2: [
              [16, 16, 3, 5],
            ],
            3: [
              [16, 4, 6, 16],
            ],
            4: [
              [5, 10, 16, 5],
            ],
            5: [
              [16, 16, 3, 6],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
    },
  };
}
