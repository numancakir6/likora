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
    // ── MAP 1 ── 10 Level — Standart, giderek zorlaşan
    1: {
      1: PuzzlePreset(
        mapNumber: 1,
        levelId: 1,
        difficulty: 1,
        tubes: [
          [0, 3, 5, 0],
          [4, 1, 4, 3],
          [5, 0, 4, 5],
          [3, 7, 2, 5],
          [6, 2, 3, 6],
          [4, 1, 6, 1],
          [2, 7, 2, 7],
          [6, 1, 0, 7],
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
        difficulty: 1,
        tubes: [
          [1, 4, 0, 3],
          [6, 7, 6, 7],
          [4, 0, 5, 3],
          [5, 2, 5, 7],
          [2, 4, 3, 1],
          [3, 6, 1, 2],
          [1, 7, 0, 5],
          [6, 4, 2, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 2,
        tubes: [
          [3, 4, 3, 4],
          [6, 1, 4, 8],
          [2, 0, 6, 8],
          [2, 0, 1, 7],
          [6, 2, 7, 1],
          [5, 6, 8, 3],
          [5, 1, 7, 8],
          [5, 2, 5, 7],
          [0, 3, 4, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
      ),
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 2,
        tubes: [
          [4, 7, 2, 4],
          [5, 3, 8, 7],
          [0, 1, 2, 0],
          [0, 4, 5, 6],
          [6, 7, 6, 3],
          [2, 8, 5, 6],
          [4, 0, 3, 8],
          [7, 1, 5, 1],
          [1, 3, 2, 8],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
      ),
      5: PuzzlePreset(
        mapNumber: 1,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [6, 1, 3, 9],
          [7, 6, 2, 7],
          [5, 1, 8, 3],
          [4, 0, 7, 2],
          [5, 1, 7, 8],
          [3, 2, 6, 4],
          [5, 8, 4, 0],
          [2, 9, 6, 3],
          [9, 1, 0, 4],
          [8, 9, 0, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      6: PuzzlePreset(
        mapNumber: 1,
        levelId: 6,
        difficulty: 3,
        tubes: [
          [0, 5, 3, 9],
          [1, 9, 3, 8],
          [6, 7, 2, 5],
          [8, 7, 3, 5],
          [6, 1, 0, 4],
          [0, 9, 1, 2],
          [7, 8, 7, 5],
          [9, 6, 1, 6],
          [0, 2, 4, 8],
          [4, 2, 4, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      7: PuzzlePreset(
        mapNumber: 1,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [8, 0, 10, 5],
          [7, 10, 8, 9],
          [1, 10, 7, 3],
          [2, 5, 4, 9],
          [9, 8, 6, 7],
          [4, 3, 1, 5],
          [0, 6, 1, 6],
          [2, 3, 9, 2],
          [3, 7, 5, 0],
          [6, 8, 2, 4],
          [1, 10, 4, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      8: PuzzlePreset(
        mapNumber: 1,
        levelId: 8,
        difficulty: 4,
        tubes: [
          [0, 7, 5, 3],
          [10, 4, 10, 1],
          [2, 10, 9, 6],
          [4, 5, 1, 3],
          [9, 7, 5, 8],
          [5, 6, 8, 3],
          [7, 1, 10, 2],
          [3, 2, 6, 0],
          [0, 4, 9, 2],
          [0, 4, 9, 8],
          [7, 8, 6, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      9: PuzzlePreset(
        mapNumber: 1,
        levelId: 9,
        difficulty: 5,
        tubes: [
          [8, 6, 9, 5],
          [9, 2, 7, 4],
          [11, 0, 4, 6],
          [8, 11, 7, 8],
          [1, 9, 4, 0],
          [0, 3, 5, 2],
          [5, 0, 10, 9],
          [3, 2, 3, 2],
          [5, 10, 4, 7],
          [7, 10, 1, 10],
          [8, 11, 6, 1],
          [3, 11, 1, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 5,
        tubes: [
          [1, 11, 1, 7],
          [6, 11, 3, 0],
          [10, 4, 2, 3],
          [4, 5, 10, 4],
          [2, 11, 6, 9],
          [8, 0, 3, 2],
          [5, 1, 6, 2],
          [4, 7, 8, 9],
          [3, 10, 1, 7],
          [0, 9, 8, 5],
          [7, 11, 10, 9],
          [8, 5, 0, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
    },
    // ── MAP 2 ── 12 Level — Blind Mode
    2: {
      1: PuzzlePreset(
        mapNumber: 2,
        levelId: 1,
        difficulty: 2,
        tubes: [
          [1, 0, 6, 5],
          [0, 5, 0, 1],
          [6, 7, 2, 3],
          [0, 1, 4, 2],
          [1, 4, 7, 2],
          [3, 4, 5, 6],
          [2, 3, 7, 4],
          [7, 3, 5, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      2: PuzzlePreset(
        mapNumber: 2,
        levelId: 2,
        difficulty: 2,
        tubes: [
          [1, 2, 3, 1],
          [1, 3, 2, 5],
          [2, 5, 6, 7],
          [6, 4, 3, 5],
          [6, 0, 6, 4],
          [1, 5, 2, 0],
          [3, 0, 7, 0],
          [4, 7, 4, 7],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
      ),
      3: PuzzlePreset(
        mapNumber: 2,
        levelId: 3,
        difficulty: 3,
        tubes: [
          [2, 3, 5, 2],
          [4, 0, 3, 8],
          [6, 0, 5, 3],
          [1, 6, 4, 8],
          [1, 6, 2, 4],
          [4, 8, 5, 7],
          [7, 0, 2, 0],
          [6, 1, 7, 1],
          [8, 7, 5, 3],
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
          [5, 7, 2, 3],
          [6, 7, 4, 8],
          [2, 7, 6, 4],
          [0, 6, 4, 0],
          [1, 3, 1, 3],
          [8, 5, 0, 5],
          [8, 2, 6, 4],
          [8, 0, 1, 2],
          [3, 7, 1, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
      ),
      5: PuzzlePreset(
        mapNumber: 2,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [4, 1, 9, 0],
          [1, 9, 2, 0],
          [1, 7, 5, 2],
          [1, 3, 2, 7],
          [8, 6, 0, 8],
          [6, 2, 4, 7],
          [6, 4, 6, 3],
          [9, 5, 8, 5],
          [3, 8, 7, 9],
          [5, 4, 0, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      6: PuzzlePreset(
        mapNumber: 2,
        levelId: 6,
        difficulty: 4,
        tubes: [
          [6, 7, 2, 8],
          [5, 3, 8, 6],
          [4, 5, 3, 1],
          [7, 3, 6, 4],
          [4, 2, 1, 9],
          [0, 9, 5, 2],
          [2, 8, 4, 1],
          [9, 0, 9, 5],
          [0, 8, 7, 1],
          [0, 3, 6, 7],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
      ),
      7: PuzzlePreset(
        mapNumber: 2,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [7, 5, 9, 0],
          [7, 6, 8, 5],
          [7, 3, 10, 0],
          [10, 0, 7, 1],
          [4, 9, 5, 1],
          [1, 2, 8, 9],
          [6, 0, 4, 2],
          [1, 8, 6, 10],
          [3, 10, 8, 6],
          [2, 4, 5, 9],
          [3, 2, 3, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      8: PuzzlePreset(
        mapNumber: 2,
        levelId: 8,
        difficulty: 4,
        tubes: [
          [9, 4, 7, 3],
          [8, 10, 2, 8],
          [7, 2, 4, 0],
          [3, 5, 10, 6],
          [10, 1, 6, 1],
          [4, 3, 5, 2],
          [7, 6, 5, 0],
          [5, 3, 9, 8],
          [7, 1, 0, 9],
          [2, 6, 9, 1],
          [0, 10, 8, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
      ),
      9: PuzzlePreset(
        mapNumber: 2,
        levelId: 9,
        difficulty: 5,
        tubes: [
          [3, 10, 7, 11],
          [5, 7, 5, 1],
          [9, 0, 8, 4],
          [10, 9, 4, 6],
          [0, 4, 2, 8],
          [9, 3, 5, 8],
          [7, 11, 1, 4],
          [6, 3, 7, 10],
          [2, 11, 6, 5],
          [0, 1, 2, 3],
          [1, 8, 6, 2],
          [10, 9, 11, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
      10: PuzzlePreset(
        mapNumber: 2,
        levelId: 10,
        difficulty: 5,
        tubes: [
          [7, 1, 9, 3],
          [10, 4, 1, 4],
          [3, 10, 7, 4],
          [6, 8, 0, 2],
          [3, 5, 3, 11],
          [0, 10, 9, 11],
          [6, 5, 9, 2],
          [8, 11, 8, 1],
          [7, 4, 5, 8],
          [0, 7, 2, 9],
          [11, 1, 5, 6],
          [0, 2, 10, 6],
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
          [7, 8, 3, 6],
          [11, 7, 2, 0],
          [6, 3, 5, 8],
          [2, 9, 5, 8],
          [6, 4, 0, 9],
          [10, 7, 5, 2],
          [4, 6, 1, 4],
          [0, 3, 11, 10],
          [3, 10, 7, 4],
          [0, 5, 11, 1],
          [9, 1, 10, 2],
          [1, 8, 9, 11],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
      12: PuzzlePreset(
        mapNumber: 2,
        levelId: 12,
        difficulty: 5,
        tubes: [
          [0, 2, 11, 9],
          [6, 0, 1, 2],
          [11, 7, 10, 3],
          [5, 0, 11, 7],
          [12, 7, 5, 6],
          [8, 1, 6, 12],
          [3, 4, 9, 5],
          [6, 8, 3, 12],
          [2, 3, 9, 5],
          [4, 1, 8, 10],
          [10, 8, 0, 9],
          [11, 12, 4, 1],
          [4, 10, 7, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(16),
        lockedAdTubeIndex: 15,
      ),
    },
    // ── MAP 3 ── 14 Level — Mountain + Refill + Lava
    3: {
      1: PuzzlePreset(
        mapNumber: 3,
        levelId: 1,
        difficulty: 2,
        mountainCapacity: 12,
        tubes: [
          [16, 2, 16, 6],
          [16, 1, 16, 2],
          [16, 3, 16, 0],
          [6, 3, 6, 3],
          [0, 1, 2, 7],
          [5, 0, 4, 5],
          [5, 2, 5, 7],
          [4, 7, 4, 7],
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
              [16, 3, 16, 1]
            ],
            1: [
              [16, 0, 16, 1]
            ],
            2: [
              [16, 6, 16, 4]
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
          [16, 5, 16, 3],
          [16, 2, 16, 1],
          [16, 7, 16, 3],
          [16, 5, 16, 1],
          [0, 7, 3, 6],
          [4, 2, 5, 1],
          [6, 1, 7, 0],
          [7, 0, 4, 2],
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
              [16, 6, 16, 0]
            ],
            1: [
              [16, 4, 16, 2]
            ],
            2: [
              [16, 6, 16, 3]
            ],
            3: [
              [16, 4, 16, 5]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      3: PuzzlePreset(
        mapNumber: 3,
        levelId: 3,
        difficulty: 3,
        mountainCapacity: 20,
        tubes: [
          [16, 1, 16, 2],
          [16, 0, 16, 4],
          [16, 7, 16, 2],
          [16, 6, 16, 3],
          [16, 1, 16, 5],
          [3, 7, 1, 2],
          [1, 5, 0, 3],
          [6, 2, 6, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4],
          refillQueues: {
            0: [
              [16, 6, 16, 4]
            ],
            1: [
              [16, 0, 16, 5]
            ],
            2: [
              [16, 4, 16, 0]
            ],
            3: [
              [16, 7, 16, 5]
            ],
            4: [
              [16, 7, 16, 4]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      4: PuzzlePreset(
        mapNumber: 3,
        levelId: 4,
        difficulty: 3,
        mountainCapacity: 16,
        tubes: [
          [16, 1, 16, 0],
          [16, 5, 16, 0],
          [16, 2, 16, 6],
          [16, 7, 16, 3],
          [1, 6, 7, 6],
          [8, 4, 2, 4],
          [2, 6, 8, 1],
          [0, 1, 5, 3],
          [7, 4, 0, 4],
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
              [16, 2, 16, 3]
            ],
            1: [
              [16, 7, 16, 3]
            ],
            2: [
              [16, 5, 16, 8]
            ],
            3: [
              [16, 5, 16, 8]
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
          [16, 3, 16, 4],
          [16, 7, 16, 1],
          [16, 4, 16, 7],
          [16, 5, 16, 2],
          [16, 1, 16, 6],
          [5, 0, 7, 0],
          [1, 6, 2, 5],
          [4, 1, 6, 5],
          [8, 0, 7, 8],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4],
          refillQueues: {
            0: [
              [16, 3, 16, 0]
            ],
            1: [
              [16, 8, 16, 6]
            ],
            2: [
              [16, 4, 16, 2]
            ],
            3: [
              [16, 3, 16, 8]
            ],
            4: [
              [16, 3, 16, 2]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      6: PuzzlePreset(
        mapNumber: 3,
        levelId: 6,
        difficulty: 4,
        mountainCapacity: 16,
        tubes: [
          [16, 7, 16, 8],
          [16, 8, 16, 2],
          [16, 1, 16, 5],
          [16, 4, 16, 3],
          [6, 7, 9, 3],
          [0, 9, 1, 6],
          [8, 0, 9, 5],
          [4, 5, 3, 7],
          [5, 0, 2, 1],
          [9, 2, 8, 0],
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
              [16, 1, 16, 2]
            ],
            1: [
              [16, 6, 16, 4]
            ],
            2: [
              [16, 6, 16, 4]
            ],
            3: [
              [16, 3, 16, 7]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      7: PuzzlePreset(
        mapNumber: 3,
        levelId: 7,
        difficulty: 4,
        mountainCapacity: 20,
        tubes: [
          [16, 5, 16, 1],
          [16, 5, 16, 3],
          [16, 8, 16, 2],
          [16, 7, 16, 5],
          [16, 9, 16, 3],
          [9, 8, 0, 9],
          [1, 8, 6, 4],
          [8, 3, 6, 2],
          [3, 4, 5, 2],
          [0, 7, 0, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4],
          refillQueues: {
            0: [
              [16, 6, 16, 4]
            ],
            1: [
              [16, 4, 16, 6]
            ],
            2: [
              [16, 7, 16, 1]
            ],
            3: [
              [16, 0, 16, 9]
            ],
            4: [
              [16, 2, 16, 7]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      8: PuzzlePreset(
        mapNumber: 3,
        levelId: 8,
        difficulty: 4,
        mountainCapacity: 24,
        tubes: [
          [16, 4, 16, 6],
          [16, 3, 16, 9],
          [16, 6, 16, 0],
          [16, 9, 16, 2],
          [16, 1, 16, 3],
          [16, 7, 16, 9],
          [6, 8, 5, 4],
          [5, 0, 1, 6],
          [4, 2, 1, 2],
          [1, 3, 7, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5],
          refillQueues: {
            0: [
              [16, 9, 16, 5]
            ],
            1: [
              [16, 8, 16, 7]
            ],
            2: [
              [16, 3, 16, 5]
            ],
            3: [
              [16, 7, 16, 0]
            ],
            4: [
              [16, 2, 16, 8]
            ],
            5: [
              [16, 0, 16, 8]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      9: PuzzlePreset(
        mapNumber: 3,
        levelId: 9,
        difficulty: 5,
        mountainCapacity: 20,
        tubes: [
          [16, 9, 16, 6],
          [16, 8, 16, 3],
          [16, 1, 16, 8],
          [16, 0, 16, 1],
          [16, 9, 16, 10],
          [0, 2, 1, 2],
          [6, 5, 3, 2],
          [10, 4, 5, 9],
          [7, 1, 9, 4],
          [3, 5, 0, 4],
          [7, 8, 7, 5],
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
              [16, 8, 16, 10]
            ],
            1: [
              [16, 6, 16, 0]
            ],
            2: [
              [16, 7, 16, 4]
            ],
            3: [
              [16, 3, 16, 6]
            ],
            4: [
              [16, 2, 16, 10]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      10: PuzzlePreset(
        mapNumber: 3,
        levelId: 10,
        difficulty: 5,
        mountainCapacity: 24,
        tubes: [
          [16, 0, 16, 7],
          [16, 4, 16, 3],
          [16, 9, 16, 8],
          [16, 1, 16, 9],
          [16, 7, 16, 3],
          [16, 6, 16, 5],
          [5, 6, 8, 1],
          [3, 9, 10, 2],
          [10, 0, 1, 7],
          [2, 9, 8, 10],
          [4, 7, 10, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5],
          refillQueues: {
            0: [
              [16, 2, 16, 3]
            ],
            1: [
              [16, 2, 16, 1]
            ],
            2: [
              [16, 4, 16, 6]
            ],
            3: [
              [16, 0, 16, 6]
            ],
            4: [
              [16, 8, 16, 5]
            ],
            5: [
              [16, 5, 16, 0]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      11: PuzzlePreset(
        mapNumber: 3,
        levelId: 11,
        difficulty: 5,
        mountainCapacity: 28,
        tubes: [
          [16, 3, 16, 7],
          [16, 2, 16, 3],
          [16, 8, 16, 0],
          [16, 9, 16, 7],
          [16, 4, 16, 9],
          [16, 4, 16, 5],
          [16, 5, 16, 0],
          [4, 3, 1, 10],
          [5, 6, 9, 6],
          [3, 2, 7, 10],
          [8, 6, 7, 8],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6],
          refillQueues: {
            0: [
              [16, 4, 16, 1]
            ],
            1: [
              [16, 5, 16, 10]
            ],
            2: [
              [16, 6, 16, 9]
            ],
            3: [
              [16, 1, 16, 0]
            ],
            4: [
              [16, 2, 16, 10]
            ],
            5: [
              [16, 8, 16, 2]
            ],
            6: [
              [16, 0, 16, 1]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      12: PuzzlePreset(
        mapNumber: 3,
        levelId: 12,
        difficulty: 5,
        mountainCapacity: 24,
        tubes: [
          [16, 3, 16, 2],
          [16, 6, 16, 11],
          [16, 0, 16, 3],
          [16, 4, 16, 11],
          [16, 7, 16, 9],
          [16, 5, 16, 7],
          [11, 2, 4, 10],
          [8, 10, 8, 1],
          [9, 5, 0, 6],
          [1, 2, 6, 3],
          [3, 4, 8, 6],
          [0, 10, 4, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5],
          refillQueues: {
            0: [
              [16, 11, 16, 0]
            ],
            1: [
              [16, 8, 16, 9]
            ],
            2: [
              [16, 1, 16, 7]
            ],
            3: [
              [16, 5, 16, 1]
            ],
            4: [
              [16, 9, 16, 5]
            ],
            5: [
              [16, 7, 16, 10]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      13: PuzzlePreset(
        mapNumber: 3,
        levelId: 13,
        difficulty: 5,
        mountainCapacity: 28,
        tubes: [
          [16, 7, 16, 5],
          [16, 4, 16, 1],
          [16, 6, 16, 7],
          [16, 0, 16, 11],
          [16, 2, 16, 3],
          [16, 6, 16, 3],
          [16, 4, 16, 9],
          [10, 4, 0, 7],
          [2, 8, 4, 5],
          [3, 10, 8, 0],
          [10, 9, 6, 11],
          [9, 8, 1, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6],
          refillQueues: {
            0: [
              [16, 1, 16, 0]
            ],
            1: [
              [16, 2, 16, 7]
            ],
            2: [
              [16, 10, 16, 1]
            ],
            3: [
              [16, 9, 16, 11]
            ],
            4: [
              [16, 5, 16, 6]
            ],
            5: [
              [16, 11, 16, 8]
            ],
            6: [
              [16, 2, 16, 3]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
      14: PuzzlePreset(
        mapNumber: 3,
        levelId: 14,
        difficulty: 5,
        mountainCapacity: 32,
        tubes: [
          [16, 0, 16, 10],
          [16, 8, 16, 5],
          [16, 11, 16, 9],
          [16, 4, 16, 5],
          [16, 9, 16, 11],
          [16, 5, 16, 10],
          [16, 6, 16, 0],
          [16, 8, 16, 2],
          [11, 1, 4, 0],
          [6, 9, 11, 2],
          [7, 1, 10, 6],
          [4, 8, 3, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4, 5, 6, 7],
          refillQueues: {
            0: [
              [16, 7, 16, 10]
            ],
            1: [
              [16, 4, 16, 8]
            ],
            2: [
              [16, 3, 16, 0]
            ],
            3: [
              [16, 7, 16, 2]
            ],
            4: [
              [16, 3, 16, 9]
            ],
            5: [
              [16, 3, 16, 2]
            ],
            6: [
              [16, 5, 16, 6]
            ],
            7: [
              [16, 7, 16, 1]
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
    },
  };
}
