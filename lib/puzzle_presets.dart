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
          [0, 3, 6, 1],
          [4, 7, 2, 5],
          [1, 4, 7, 2],
          [5, 0, 3, 6],
          [2, 5, 0, 3],
          [6, 1, 4, 7],
          [3, 6, 1, 4],
          [7, 2, 5, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      2: PuzzlePreset(
        mapNumber: 1,
        levelId: 2,
        difficulty: 2,
        tubes: [
          [0, 4, 7, 2],
          [5, 9, 2, 7],
          [1, 5, 8, 3],
          [6, 0, 3, 8],
          [2, 6, 9, 4],
          [7, 1, 4, 9],
          [3, 7, 0, 5],
          [8, 2, 5, 0],
          [4, 8, 1, 6],
          [9, 3, 6, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 2,
        tubes: [
          [0, 5, 1, 7],
          [3, 8, 4, 0],
          [6, 1, 7, 3],
          [9, 4, 0, 6],
          [2, 7, 3, 9],
          [5, 0, 6, 2],
          [8, 3, 9, 5],
          [1, 6, 2, 8],
          [4, 9, 5, 1],
          [7, 2, 8, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 3,
        tubes: [
          [0, 6, 2, 7],
          [7, 3, 9, 4],
          [4, 0, 6, 1],
          [1, 7, 3, 8],
          [8, 4, 0, 5],
          [5, 1, 7, 2],
          [2, 8, 4, 9],
          [9, 5, 1, 6],
          [6, 2, 8, 3],
          [3, 9, 5, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      5: PuzzlePreset(
        mapNumber: 1,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [0, 5, 2, 8],
          [6, 0, 8, 3],
          [1, 6, 3, 9],
          [7, 1, 9, 4],
          [2, 7, 4, 10],
          [8, 2, 10, 5],
          [3, 8, 5, 0],
          [9, 3, 0, 6],
          [4, 9, 6, 1],
          [10, 4, 1, 7],
          [5, 10, 7, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      6: PuzzlePreset(
        mapNumber: 1,
        levelId: 6,
        difficulty: 4,
        tubes: [
          [0, 6, 3, 9],
          [4, 10, 7, 2],
          [8, 3, 0, 6],
          [1, 7, 4, 10],
          [5, 0, 8, 3],
          [9, 4, 1, 7],
          [2, 8, 5, 0],
          [6, 1, 9, 4],
          [10, 5, 2, 8],
          [3, 9, 6, 1],
          [7, 2, 10, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      7: PuzzlePreset(
        mapNumber: 1,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [0, 5, 9, 2],
          [6, 11, 3, 8],
          [1, 6, 10, 3],
          [7, 0, 4, 9],
          [2, 7, 11, 4],
          [8, 1, 5, 10],
          [3, 8, 0, 5],
          [9, 2, 6, 11],
          [4, 9, 1, 6],
          [10, 3, 7, 0],
          [5, 10, 2, 7],
          [11, 4, 8, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
      8: PuzzlePreset(
        mapNumber: 1,
        levelId: 8,
        difficulty: 4,
        tubes: [
          [0, 7, 3, 10],
          [5, 0, 8, 3],
          [10, 5, 1, 8],
          [3, 10, 6, 1],
          [8, 3, 11, 6],
          [1, 8, 4, 11],
          [6, 1, 9, 4],
          [11, 6, 2, 9],
          [4, 11, 7, 2],
          [9, 4, 0, 7],
          [2, 9, 5, 0],
          [7, 2, 10, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
      9: PuzzlePreset(
        mapNumber: 1,
        levelId: 9,
        difficulty: 5,
        tubes: [
          [0, 6, 2, 9],
          [7, 0, 9, 3],
          [1, 7, 3, 10],
          [8, 1, 10, 4],
          [2, 8, 4, 11],
          [9, 2, 11, 5],
          [3, 9, 5, 12],
          [10, 3, 12, 6],
          [4, 10, 6, 0],
          [11, 4, 0, 7],
          [5, 11, 7, 1],
          [12, 5, 1, 8],
          [6, 12, 8, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(16),
        lockedAdTubeIndex: 15,
      ),
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 5,
        tubes: [
          [0, 7, 3, 10],
          [8, 1, 11, 4],
          [1, 8, 4, 11],
          [9, 2, 12, 5],
          [2, 9, 5, 12],
          [10, 3, 13, 6],
          [3, 10, 6, 13],
          [11, 4, 0, 7],
          [4, 11, 7, 0],
          [12, 5, 1, 8],
          [5, 12, 8, 1],
          [13, 6, 2, 9],
          [6, 13, 9, 2],
          [7, 0, 10, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(17),
        lockedAdTubeIndex: 16,
      ),
    },
    2: {
      1: PuzzlePreset(
        mapNumber: 2,
        levelId: 1,
        difficulty: 1,
        tubes: [
          [0, 3, 6, 1],
          [1, 4, 7, 2],
          [2, 5, 8, 3],
          [3, 6, 9, 4],
          [4, 7, 0, 5],
          [5, 8, 1, 6],
          [6, 9, 2, 7],
          [7, 0, 3, 8],
          [8, 1, 4, 9],
          [9, 2, 5, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      2: PuzzlePreset(
        mapNumber: 2,
        levelId: 2,
        difficulty: 1,
        tubes: [
          [0, 4, 7, 2],
          [1, 5, 8, 3],
          [2, 6, 9, 4],
          [3, 7, 0, 5],
          [4, 8, 1, 6],
          [5, 9, 2, 7],
          [6, 0, 3, 8],
          [7, 1, 4, 9],
          [8, 2, 5, 0],
          [9, 3, 6, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      3: PuzzlePreset(
        mapNumber: 2,
        levelId: 3,
        difficulty: 2,
        tubes: [
          [0, 3, 7, 1],
          [1, 4, 8, 2],
          [2, 5, 9, 3],
          [3, 6, 10, 4],
          [4, 7, 0, 5],
          [5, 8, 1, 6],
          [6, 9, 2, 7],
          [7, 10, 3, 8],
          [8, 0, 4, 9],
          [9, 1, 5, 10],
          [10, 2, 6, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      4: PuzzlePreset(
        mapNumber: 2,
        levelId: 4,
        difficulty: 2,
        tubes: [
          [0, 4, 8, 2],
          [1, 5, 9, 3],
          [2, 6, 10, 4],
          [3, 7, 0, 5],
          [4, 8, 1, 6],
          [5, 9, 2, 7],
          [6, 10, 3, 8],
          [7, 0, 4, 9],
          [8, 1, 5, 10],
          [9, 2, 6, 0],
          [10, 3, 7, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      5: PuzzlePreset(
        mapNumber: 2,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [0, 5, 8, 2],
          [1, 6, 9, 3],
          [2, 7, 10, 4],
          [3, 8, 11, 5],
          [4, 9, 0, 6],
          [5, 10, 1, 7],
          [6, 11, 2, 8],
          [7, 0, 3, 9],
          [8, 1, 4, 10],
          [9, 2, 5, 11],
          [10, 3, 6, 0],
          [11, 4, 7, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
      6: PuzzlePreset(
        mapNumber: 2,
        levelId: 6,
        difficulty: 3,
        tubes: [
          [0, 4, 9, 1],
          [1, 5, 10, 2],
          [2, 6, 11, 3],
          [3, 7, 0, 4],
          [4, 8, 1, 5],
          [5, 9, 2, 6],
          [6, 10, 3, 7],
          [7, 11, 4, 8],
          [8, 0, 5, 9],
          [9, 1, 6, 10],
          [10, 2, 7, 11],
          [11, 3, 8, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
      7: PuzzlePreset(
        mapNumber: 2,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [0, 5, 9, 2],
          [1, 6, 10, 3],
          [2, 7, 11, 4],
          [3, 8, 12, 5],
          [4, 9, 0, 6],
          [5, 10, 1, 7],
          [6, 11, 2, 8],
          [7, 12, 3, 9],
          [8, 0, 4, 10],
          [9, 1, 5, 11],
          [10, 2, 6, 12],
          [11, 3, 7, 0],
          [12, 4, 8, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(16),
        lockedAdTubeIndex: 15,
      ),
      8: PuzzlePreset(
        mapNumber: 2,
        levelId: 8,
        difficulty: 4,
        tubes: [
          [0, 6, 10, 3],
          [1, 7, 11, 4],
          [2, 8, 12, 5],
          [3, 9, 0, 6],
          [4, 10, 1, 7],
          [5, 11, 2, 8],
          [6, 12, 3, 9],
          [7, 0, 4, 10],
          [8, 1, 5, 11],
          [9, 2, 6, 12],
          [10, 3, 7, 0],
          [11, 4, 8, 1],
          [12, 5, 9, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(16),
        lockedAdTubeIndex: 15,
      ),
      9: PuzzlePreset(
        mapNumber: 2,
        levelId: 9,
        difficulty: 4,
        tubes: [
          [0, 5, 9, 1],
          [1, 6, 10, 2],
          [2, 7, 11, 3],
          [3, 8, 12, 4],
          [4, 9, 13, 5],
          [5, 10, 0, 6],
          [6, 11, 1, 7],
          [7, 12, 2, 8],
          [8, 13, 3, 9],
          [9, 0, 4, 10],
          [10, 1, 5, 11],
          [11, 2, 6, 12],
          [12, 3, 7, 13],
          [13, 4, 8, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(17),
        lockedAdTubeIndex: 16,
      ),
      10: PuzzlePreset(
        mapNumber: 2,
        levelId: 10,
        difficulty: 5,
        tubes: [
          [0, 6, 10, 2],
          [1, 7, 11, 3],
          [2, 8, 12, 4],
          [3, 9, 13, 5],
          [4, 10, 0, 6],
          [5, 11, 1, 7],
          [6, 12, 2, 8],
          [7, 13, 3, 9],
          [8, 0, 4, 10],
          [9, 1, 5, 11],
          [10, 2, 6, 12],
          [11, 3, 7, 13],
          [12, 4, 8, 0],
          [13, 5, 9, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(17),
        lockedAdTubeIndex: 16,
      ),
      11: PuzzlePreset(
        mapNumber: 2,
        levelId: 11,
        difficulty: 5,
        tubes: [
          [0, 5, 9, 2],
          [1, 6, 10, 3],
          [2, 7, 11, 4],
          [3, 8, 12, 5],
          [4, 9, 13, 6],
          [5, 10, 14, 7],
          [6, 11, 0, 8],
          [7, 12, 1, 9],
          [8, 13, 2, 10],
          [9, 14, 3, 11],
          [10, 0, 4, 12],
          [11, 1, 5, 13],
          [12, 2, 6, 14],
          [13, 3, 7, 0],
          [14, 4, 8, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
      ),
      12: PuzzlePreset(
        mapNumber: 2,
        levelId: 12,
        difficulty: 5,
        tubes: [
          [0, 6, 11, 3],
          [1, 7, 12, 4],
          [2, 8, 13, 5],
          [3, 9, 14, 6],
          [4, 10, 0, 7],
          [5, 11, 1, 8],
          [6, 12, 2, 9],
          [7, 13, 3, 10],
          [8, 14, 4, 11],
          [9, 0, 5, 12],
          [10, 1, 6, 13],
          [11, 2, 7, 14],
          [12, 3, 8, 0],
          [13, 4, 9, 1],
          [14, 5, 10, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
      ),
    },
    3: {
      1: PuzzlePreset(
        mapNumber: 3,
        levelId: 1,
        difficulty: 3,
        mountainCapacity: 12,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 0], // refill 2
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 0, 1],
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 1, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      2: PuzzlePreset(
        mapNumber: 3,
        levelId: 2,
        difficulty: 4,
        mountainCapacity: 16,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 1, 2, 3], // refill 3
          [5, 6, 7, 8],
          [9, 10, 0, 1],
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
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
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 0, 16, 16],
            ],
            3: [
              [16, 4, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      3: PuzzlePreset(
        mapNumber: 3,
        levelId: 3,
        difficulty: 4,
        mountainCapacity: 20,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 0, 1, 2], // refill 3
          [16, 4, 5, 6], // refill 4
          [8, 9, 10, 11],
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11],
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11],
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
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 3, 16, 16],
            ],
            4: [
              [16, 7, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      4: PuzzlePreset(
        mapNumber: 3,
        levelId: 4,
        difficulty: 5,
        mountainCapacity: 20,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 0, 1, 2], // refill 3
          [16, 4, 5, 6], // refill 4
          [8, 9, 10, 11],
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11],
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11],
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
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 3, 16, 16],
            ],
            4: [
              [16, 7, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      5: PuzzlePreset(
        mapNumber: 3,
        levelId: 5,
        difficulty: 5,
        mountainCapacity: 20,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 0, 1], // refill 3
          [16, 3, 4, 5], // refill 4
          [7, 8, 9, 10],
          [11, 12, 0, 1],
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 0],
          [1, 2, 3, 4],
          [5, 6, 7, 8],
          [9, 10, 11, 12],
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
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 2, 16, 16],
            ],
            4: [
              [16, 6, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      6: PuzzlePreset(
        mapNumber: 3,
        levelId: 6,
        difficulty: 5,
        mountainCapacity: 24,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 0], // refill 3
          [16, 2, 3, 4], // refill 4
          [16, 6, 7, 8], // refill 5
          [10, 11, 12, 13],
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [8, 9, 10, 11],
          [12, 13, 0, 1],
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 13],
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
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 1, 16, 16],
            ],
            4: [
              [16, 5, 16, 16],
            ],
            5: [
              [16, 9, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      7: PuzzlePreset(
        mapNumber: 3,
        levelId: 7,
        difficulty: 5,
        mountainCapacity: 24,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 14], // refill 3
          [16, 1, 2, 3], // refill 4
          [16, 5, 6, 7], // refill 5
          [9, 10, 11, 12],
          [13, 14, 0, 1],
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 13],
          [14, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
          [11, 12, 13, 14],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 0, 16, 16],
            ],
            4: [
              [16, 4, 16, 16],
            ],
            5: [
              [16, 8, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      8: PuzzlePreset(
        mapNumber: 3,
        levelId: 8,
        difficulty: 5,
        mountainCapacity: 28,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 14], // refill 3
          [16, 1, 2, 3], // refill 4
          [16, 5, 6, 7], // refill 5
          [16, 9, 10, 11], // refill 6
          [13, 14, 0, 1],
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 13],
          [14, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
          [11, 12, 13, 14],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 0, 16, 16],
            ],
            4: [
              [16, 4, 16, 16],
            ],
            5: [
              [16, 8, 16, 16],
            ],
            6: [
              [16, 12, 16, 16],
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
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 14], // refill 3
          [16, 1, 2, 3], // refill 4
          [16, 5, 6, 7], // refill 5
          [16, 9, 10, 11], // refill 6
          [13, 14, 0, 1],
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 13],
          [14, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
          [11, 12, 13, 14],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 0, 16, 16],
            ],
            4: [
              [16, 4, 16, 16],
            ],
            5: [
              [16, 8, 16, 16],
            ],
            6: [
              [16, 12, 16, 16],
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
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 14], // refill 3
          [16, 1, 2, 3], // refill 4
          [16, 5, 6, 7], // refill 5
          [16, 9, 10, 11], // refill 6
          [16, 13, 14, 0], // refill 7
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 13],
          [14, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
          [11, 12, 13, 14],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6, 7],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 0, 16, 16],
            ],
            4: [
              [16, 4, 16, 16],
            ],
            5: [
              [16, 8, 16, 16],
            ],
            6: [
              [16, 12, 16, 16],
            ],
            7: [
              [16, 1, 16, 16],
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
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 14], // refill 3
          [16, 1, 2, 3], // refill 4
          [16, 5, 6, 7], // refill 5
          [16, 9, 10, 11], // refill 6
          [16, 13, 14, 0], // refill 7
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 13],
          [14, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
          [11, 12, 13, 14],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6, 7],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 0, 16, 16],
            ],
            4: [
              [16, 4, 16, 16],
            ],
            5: [
              [16, 8, 16, 16],
            ],
            6: [
              [16, 12, 16, 16],
            ],
            7: [
              [16, 1, 16, 16],
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
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 14], // refill 3
          [16, 1, 2, 3], // refill 4
          [16, 5, 6, 7], // refill 5
          [16, 9, 10, 11], // refill 6
          [16, 13, 14, 0], // refill 7
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 13],
          [14, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
          [11, 12, 13, 14],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6, 7],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 0, 16, 16],
            ],
            4: [
              [16, 4, 16, 16],
            ],
            5: [
              [16, 8, 16, 16],
            ],
            6: [
              [16, 12, 16, 16],
            ],
            7: [
              [16, 1, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      13: PuzzlePreset(
        mapNumber: 3,
        levelId: 13,
        difficulty: 5,
        mountainCapacity: 32,
        tubes: [
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 14], // refill 3
          [16, 1, 2, 3], // refill 4
          [16, 5, 6, 7], // refill 5
          [16, 9, 10, 11], // refill 6
          [16, 13, 14, 0], // refill 7
          [2, 3, 4, 5],
          [6, 7, 8, 9],
          [10, 11, 12, 13],
          [14, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
          [11, 12, 13, 14],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6, 7],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 0, 16, 16],
            ],
            4: [
              [16, 4, 16, 16],
            ],
            5: [
              [16, 8, 16, 16],
            ],
            6: [
              [16, 12, 16, 16],
            ],
            7: [
              [16, 1, 16, 16],
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
          [16, 0, 1, 2], // refill 0
          [16, 4, 5, 6], // refill 1
          [16, 8, 9, 10], // refill 2
          [16, 12, 13, 14], // refill 3
          [16, 1, 2, 3], // refill 4
          [16, 5, 6, 7], // refill 5
          [16, 9, 10, 11], // refill 6
          [16, 13, 14, 0], // refill 7
          [16, 2, 3, 4], // refill 8
          [6, 7, 8, 9],
          [10, 11, 12, 13],
          [14, 0, 1, 2],
          [3, 4, 5, 6],
          [7, 8, 9, 10],
          [11, 12, 13, 14],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6, 7, 8],
          refillQueues: {
            0: [
              [16, 3, 16, 16],
            ],
            1: [
              [16, 7, 16, 16],
            ],
            2: [
              [16, 11, 16, 16],
            ],
            3: [
              [16, 0, 16, 16],
            ],
            4: [
              [16, 4, 16, 16],
            ],
            5: [
              [16, 8, 16, 16],
            ],
            6: [
              [16, 12, 16, 16],
            ],
            7: [
              [16, 1, 16, 16],
            ],
            8: [
              [16, 5, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
    },
  };
}
