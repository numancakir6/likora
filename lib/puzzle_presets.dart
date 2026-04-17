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
// PUZZLE PRESETS  —  yardımcılar + statik tablo
// ─────────────────────────────────────────────────────────────────

class PuzzlePresets {
  static PuzzlePreset get({
    required int mapNumber,
    required int levelId,
  }) {
    final preset = getOrNull(mapNumber: mapNumber, levelId: levelId);
    if (preset == null) {
      throw StateError('Level bulunamadı: map=$mapNumber level=$levelId');
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

  // ── Preset tablosu ────────────────────────────────────────────
  //
  // KULLANIM KILAVUZU:
  //   Her level için sadece oynanışta gereken statik veri tutulur.
  //
  static final Map<int, Map<int, PuzzlePreset>> _presets = {
    1: {
      1: PuzzlePreset(
        mapNumber: 1,
        levelId: 1,
        difficulty: 1,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 0, 2],
          [2, 0, 3, 1],
          [3, 2, 1, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(7),
        lockedAdTubeIndex: 6,
      ),
      2: PuzzlePreset(
        mapNumber: 1,
        levelId: 2,
        difficulty: 2,
        tubes: [
          [0, 1, 2, 3],
          [1, 2, 4, 0],
          [2, 4, 3, 1],
          [3, 0, 1, 4],
          [4, 3, 0, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(8),
        lockedAdTubeIndex: 7,
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 3,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 4, 5],
          [2, 4, 5, 0],
          [3, 5, 0, 1],
          [4, 0, 1, 2],
          [5, 2, 3, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
      ),
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 4,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 4, 5],
          [2, 4, 6, 0],
          [3, 5, 0, 1],
          [4, 6, 1, 2],
          [5, 0, 3, 6],
          [6, 2, 5, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(10),
        lockedAdTubeIndex: 9,
      ),
      5: PuzzlePreset(
        mapNumber: 1,
        levelId: 5,
        difficulty: 5,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 4, 5],
          [2, 4, 6, 7],
          [3, 5, 7, 0],
          [4, 6, 0, 1],
          [5, 7, 1, 2],
          [6, 0, 3, 4],
          [7, 2, 5, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      6: PuzzlePreset(
        mapNumber: 1,
        levelId: 6,
        difficulty: 6,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 4, 5],
          [2, 4, 6, 7],
          [3, 5, 7, 8],
          [4, 6, 8, 0],
          [5, 7, 0, 1],
          [6, 8, 1, 2],
          [7, 0, 3, 4],
          [8, 2, 5, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
      ),
      7: PuzzlePreset(
        mapNumber: 1,
        levelId: 7,
        difficulty: 7,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 4, 5],
          [2, 4, 6, 7],
          [3, 5, 7, 8],
          [4, 6, 8, 9],
          [5, 7, 9, 0],
          [6, 8, 0, 1],
          [7, 9, 1, 2],
          [8, 0, 3, 4],
          [9, 2, 5, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      8: PuzzlePreset(
        mapNumber: 1,
        levelId: 8,
        difficulty: 8,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 4, 5],
          [2, 4, 6, 7],
          [3, 5, 7, 8],
          [4, 6, 8, 9],
          [5, 7, 9, 0],
          [6, 8, 0, 1],
          [7, 9, 1, 2],
          [8, 0, 3, 4],
          [9, 2, 5, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      9: PuzzlePreset(
        mapNumber: 1,
        levelId: 9,
        difficulty: 9,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 4, 5],
          [2, 4, 6, 7],
          [3, 5, 7, 8],
          [4, 6, 8, 9],
          [5, 7, 9, 10],
          [6, 8, 10, 0],
          [7, 9, 0, 1],
          [8, 10, 1, 2],
          [9, 0, 3, 4],
          [10, 2, 5, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 10,
        tubes: [
          [0, 1, 2, 3],
          [1, 3, 4, 5],
          [2, 4, 6, 7],
          [3, 5, 7, 8],
          [4, 6, 8, 9],
          [5, 7, 9, 10],
          [6, 8, 10, 0],
          [7, 9, 0, 1],
          [8, 10, 1, 2],
          [9, 0, 3, 4],
          [10, 2, 5, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
    },
    2: {
      1: PuzzlePreset(
        mapNumber: 2,
        levelId: 1,
        difficulty: 2,
        tubes: [
          [0, 3, 1, 2],
          [6, 5, 7, 4],
          [2, 5, 6, 3],
          [7, 4, 0, 5],
          [1, 6, 4, 3],
          [0, 7, 2, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
      ),
      2: PuzzlePreset(
        mapNumber: 2,
        levelId: 2,
        difficulty: 2,
        tubes: [
          [0, 6, 3, 5],
          [2, 7, 1, 4],
          [5, 3, 7, 6],
          [4, 1, 2, 0],
          [6, 4, 0, 3],
          [7, 2, 5, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(9),
        lockedAdTubeIndex: 8,
      ),
      3: PuzzlePreset(
        mapNumber: 2,
        levelId: 3,
        difficulty: 2,
        tubes: [
          [7, 8, 6, 4],
          [1, 2, 4, 8],
          [3, 4, 5, 4],
          [6, 2, 1, 0],
          [5, 0, 1, 8],
          [7, 5, 8, 6],
          [3, 0, 2, 7],
          [1, 5, 6, 2],
          [3, 7, 3, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
      ),
      4: PuzzlePreset(
        mapNumber: 2,
        levelId: 4,
        difficulty: 3,
        tubes: [
          [0, 1, 6, 4],
          [9, 8, 5, 7],
          [7, 5, 4, 0],
          [7, 3, 1, 2],
          [7, 3, 8, 6],
          [2, 6, 2, 1],
          [3, 5, 0, 4],
          [9, 4, 9, 2],
          [9, 6, 5, 8],
          [3, 0, 8, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      5: PuzzlePreset(
        mapNumber: 2,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [1, 5, 2, 7],
          [4, 1, 0, 6],
          [7, 6, 2, 0],
          [3, 4, 6, 4],
          [7, 4, 5, 3],
          [0, 1, 3, 5],
          [3, 6, 5, 2],
          [0, 1, 2, 7],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      6: PuzzlePreset(
        mapNumber: 2,
        levelId: 6,
        difficulty: 3,
        tubes: [
          [9, 6, 2, 0],
          [3, 2, 9, 4],
          [8, 4, 10, 8],
          [5, 3, 8, 9],
          [5, 9, 0, 7],
          [6, 1, 6, 5],
          [8, 3, 2, 1],
          [0, 7, 3, 10],
          [4, 7, 2, 0],
          [5, 7, 10, 1],
          [4, 1, 10, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      7: PuzzlePreset(
        mapNumber: 2,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [9, 1, 6, 3],
          [1, 5, 2, 6],
          [2, 1, 4, 6],
          [3, 4, 8, 7],
          [5, 7, 3, 9],
          [5, 3, 8, 7],
          [0, 4, 2, 8],
          [8, 0, 4, 1],
          [6, 5, 7, 0],
          [9, 0, 9, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      8: PuzzlePreset(
        mapNumber: 2,
        levelId: 8,
        difficulty: 3,
        tubes: [
          [6, 3, 6, 11],
          [7, 11, 2, 0],
          [12, 4, 12, 5],
          [10, 4, 2, 1],
          [3, 10, 7, 3],
          [5, 11, 2, 9],
          [2, 5, 11, 1],
          [4, 12, 6, 12],
          [7, 5, 0, 10],
          [8, 1, 8, 3],
          [0, 8, 9, 0],
          [4, 1, 10, 7],
          [9, 6, 8, 9],
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
          [3, 1, 10, 3],
          [9, 5, 3, 2],
          [4, 2, 1, 0],
          [4, 8, 7, 0],
          [7, 1, 10, 4],
          [9, 6, 5, 7],
          [6, 4, 9, 10],
          [0, 2, 5, 8],
          [1, 7, 10, 6],
          [8, 3, 2, 9],
          [6, 8, 0, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      10: PuzzlePreset(
        mapNumber: 2,
        levelId: 10,
        difficulty: 4,
        tubes: [
          [10, 6, 1, 3],
          [3, 5, 4, 9],
          [3, 0, 9, 11],
          [5, 8, 11, 2],
          [2, 4, 6, 7],
          [10, 6, 8, 5],
          [2, 4, 8, 10],
          [9, 6, 5, 4],
          [0, 7, 1, 11],
          [2, 11, 7, 0],
          [0, 8, 9, 3],
          [7, 1, 10, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
      11: PuzzlePreset(
        mapNumber: 2,
        levelId: 11,
        difficulty: 5,
        tubes: [
          [9, 6, 8, 2],
          [6, 9, 8, 4],
          [9, 3, 5, 1],
          [8, 6, 2, 3],
          [1, 0, 5, 4],
          [0, 7, 4, 5],
          [3, 2, 1, 0],
          [7, 2, 7, 8],
          [1, 5, 4, 9],
          [0, 6, 3, 7],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      12: PuzzlePreset(
        mapNumber: 2,
        levelId: 12,
        difficulty: 5,
        tubes: [
          [5, 3, 6, 8],
          [7, 0, 4, 0],
          [9, 13, 11, 2],
          [7, 2, 1, 12],
          [13, 8, 5, 1],
          [4, 10, 6, 13],
          [13, 12, 4, 7],
          [5, 12, 3, 4],
          [12, 5, 8, 6],
          [0, 2, 11, 3],
          [8, 10, 6, 11],
          [7, 1, 3, 9],
          [1, 9, 2, 10],
          [11, 9, 0, 10],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(17),
        lockedAdTubeIndex: 16,
      ),
    },
    3: {
      1: PuzzlePreset(
        mapNumber: 3,
        levelId: 1,
        difficulty: 3,
        mountainCapacity: 16,
        tubes: [
          [16, 0, 4, 1],
          [2, 16, 5, 3],
          [16, 4, 16, 3],
          [0, 16, 5, 16],
          [6, 1, 16, 4],
          [16, 2, 6, 16],
          [5, 16, 3, 6],
          [16, 4, 0, 5],
          [6, 16, 1, 2],
          [],
          [],
          [],
        ],
        layout: const StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7],
            [8, 9, 10, 11],
          ],
        ),
        lockedAdTubeIndex: 11,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1],
          refillQueues: {
            0: [
              [16, 0, 16, 1],
            ],
            1: [
              [16, 2, 16, 3],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      2: PuzzlePreset(
        mapNumber: 3,
        levelId: 2,
        difficulty: 3,
        mountainCapacity: 14,
        tubes: [
          [16, 0, 3, 1],
          [2, 16, 4, 5],
          [1, 2, 16, 0],
          [3, 16, 5, 2],
          [4, 1, 16, 3],
          [5, 4, 0, 16],
          [0, 3, 2, 4],
          [16, 5, 1, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1],
          refillQueues: {
            0: [
              [16, 2],
              [1],
            ],
            1: [
              [16, 3],
              [4],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
    },
  };
}
