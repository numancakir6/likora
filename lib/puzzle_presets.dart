class PuzzleMove {
  final int from;
  final int to;

  const PuzzleMove(this.from, this.to);
}

enum PuzzleTubeStyle {
  classic,
}

enum StageLayoutMode {
  rows,
  manual,
}

class StageTubePosition {
  final int index;
  final double x;
  final double y;

  const StageTubePosition({
    required this.index,
    required this.x,
    required this.y,
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
    if (safeCount <= 3) {
      return StageLayout.rows(rows: [List<int>.generate(safeCount, (i) => i)]);
    }

    final indices = List<int>.generate(safeCount, (i) => i);
    final rows = <List<int>>[];
    var cursor = 0;

    while (cursor < indices.length) {
      final remaining = indices.length - cursor;
      final take = remaining > 4 ? 4 : remaining;
      rows.add(indices.sublist(cursor, cursor + take));
      cursor += take;
    }

    return StageLayout.rows(rows: rows);
  }
}

class PuzzlePreset {
  final int mapNumber;
  final int levelId;
  final int difficulty;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;
  final StageLayout layout;
  final PuzzleTubeStyle tubeStyle;
  final List<List<PuzzleMove>> solutionBranches;
  final Map<String, PuzzleMove> jokerRecoveryMoves;

  const PuzzlePreset({
    required this.mapNumber,
    required this.levelId,
    required this.difficulty,
    required this.tubes,
    required this.layout,
    this.lockedAdTubeIndex = 10,
    this.tubeStyle = PuzzleTubeStyle.classic,
    this.solutionBranches = const [],
    this.jokerRecoveryMoves = const {},
  });
}

class PuzzlePresets {
  static PuzzlePreset get({
    required int mapNumber,
    required int levelId,
  }) {
    final preset = getOrNull(
      mapNumber: mapNumber,
      levelId: levelId,
    );

    if (preset == null) {
      throw StateError('Level bulunamadı: map=$mapNumber level=$levelId');
    }

    return preset;
  }

  static PuzzlePreset? getOrNull({
    required int mapNumber,
    required int levelId,
  }) {
    final mapPresets = _presets[mapNumber];
    if (mapPresets == null) return null;
    return mapPresets[levelId];
  }

  static String signatureOf(List<List<int>> tubes) {
    return tubes.map((t) => t.join(',')).join('|');
  }

  static const Map<int, Map<int, PuzzlePreset>> _presets = {
    1: {
      1: PuzzlePreset(
        mapNumber: 1,
        levelId: 1,
        difficulty: 2,
        tubes: [
          [0, 4, 8, 1],
          [1, 5, 9, 2],
          [2, 6, 10, 3],
          [3, 7, 11, 4],
          [4, 8, 0, 5],
          [5, 9, 1, 6],
          [6, 10, 2, 7],
          [7, 11, 3, 8],
          [8, 0, 4, 9],
          [9, 1, 5, 10],
          [10, 2, 6, 11],
          [11, 3, 7, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11],
            [12, 13, 14],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 14,
      ),
      2: PuzzlePreset(
        mapNumber: 1,
        levelId: 2,
        difficulty: 2,
        tubes: [
          [0, 5, 2, 8],
          [1, 6, 3, 9],
          [2, 7, 4, 10],
          [3, 8, 5, 11],
          [4, 9, 6, 0],
          [5, 10, 7, 1],
          [6, 11, 8, 2],
          [7, 0, 9, 3],
          [8, 1, 10, 4],
          [9, 2, 11, 5],
          [10, 3, 0, 6],
          [11, 4, 1, 7],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11],
            [12, 13, 14],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 14,
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 3,
        tubes: [
          [0, 6, 3, 9],
          [1, 7, 4, 10],
          [2, 8, 5, 11],
          [3, 9, 6, 0],
          [4, 10, 7, 1],
          [5, 11, 8, 2],
          [6, 0, 9, 3],
          [7, 1, 10, 4],
          [8, 2, 11, 5],
          [9, 3, 0, 6],
          [10, 4, 1, 7],
          [11, 5, 2, 8],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11],
            [12, 13, 14],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 14,
      ),
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 3,
        tubes: [
          [0, 5, 10, 2],
          [1, 6, 11, 3],
          [2, 7, 12, 4],
          [3, 8, 0, 5],
          [4, 9, 1, 6],
          [5, 10, 2, 7],
          [6, 11, 3, 8],
          [7, 12, 4, 9],
          [8, 0, 5, 10],
          [9, 1, 6, 11],
          [10, 2, 7, 12],
          [11, 3, 8, 0],
          [12, 4, 9, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11],
            [12, 13, 14, 15],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 15,
      ),
      5: PuzzlePreset(
        mapNumber: 1,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [0, 6, 1, 8],
          [1, 7, 2, 9],
          [2, 8, 3, 10],
          [3, 9, 4, 11],
          [4, 10, 5, 12],
          [5, 11, 6, 0],
          [6, 12, 7, 1],
          [7, 0, 8, 2],
          [8, 1, 9, 3],
          [9, 2, 10, 4],
          [10, 3, 11, 5],
          [11, 4, 12, 6],
          [12, 5, 0, 7],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11],
            [12, 13, 14, 15],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 15,
      ),
      6: PuzzlePreset(
        mapNumber: 1,
        levelId: 6,
        difficulty: 4,
        tubes: [
          [0, 5, 10, 1],
          [1, 6, 11, 2],
          [2, 7, 12, 3],
          [3, 8, 13, 4],
          [4, 9, 0, 5],
          [5, 10, 1, 6],
          [6, 11, 2, 7],
          [7, 12, 3, 8],
          [8, 13, 4, 9],
          [9, 0, 5, 10],
          [10, 1, 6, 11],
          [11, 2, 7, 12],
          [12, 3, 8, 13],
          [13, 4, 9, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11],
            [12, 13, 14, 15, 16],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 16,
      ),
      7: PuzzlePreset(
        mapNumber: 1,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [0, 7, 3, 10],
          [1, 8, 4, 11],
          [2, 9, 5, 12],
          [3, 10, 6, 13],
          [4, 11, 7, 0],
          [5, 12, 8, 1],
          [6, 13, 9, 2],
          [7, 0, 10, 3],
          [8, 1, 11, 4],
          [9, 2, 12, 5],
          [10, 3, 13, 6],
          [11, 4, 0, 7],
          [12, 5, 1, 8],
          [13, 6, 2, 9],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11],
            [12, 13, 14, 15, 16],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 16,
      ),
      8: PuzzlePreset(
        mapNumber: 1,
        levelId: 8,
        difficulty: 5,
        tubes: [
          [0, 6, 12, 3],
          [1, 7, 13, 4],
          [2, 8, 14, 5],
          [3, 9, 0, 6],
          [4, 10, 1, 7],
          [5, 11, 2, 8],
          [6, 12, 3, 9],
          [7, 13, 4, 10],
          [8, 14, 5, 11],
          [9, 0, 6, 12],
          [10, 1, 7, 13],
          [11, 2, 8, 14],
          [12, 3, 9, 0],
          [13, 4, 10, 1],
          [14, 5, 11, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11, 12],
            [13, 14, 15, 16, 17],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 17,
      ),
      9: PuzzlePreset(
        mapNumber: 1,
        levelId: 9,
        difficulty: 5,
        tubes: [
          [0, 7, 2, 11],
          [1, 8, 3, 12],
          [2, 9, 4, 13],
          [3, 10, 5, 14],
          [4, 11, 6, 0],
          [5, 12, 7, 1],
          [6, 13, 8, 2],
          [7, 14, 9, 3],
          [8, 0, 10, 4],
          [9, 1, 11, 5],
          [10, 2, 12, 6],
          [11, 3, 13, 7],
          [12, 4, 14, 8],
          [13, 5, 0, 9],
          [14, 6, 1, 10],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11, 12],
            [13, 14, 15, 16, 17],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 17,
      ),
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 5,
        tubes: [
          [0, 7, 14, 3],
          [1, 8, 15, 4],
          [2, 9, 0, 5],
          [3, 10, 1, 6],
          [4, 11, 2, 7],
          [5, 12, 3, 8],
          [6, 13, 4, 9],
          [7, 14, 5, 10],
          [8, 15, 6, 11],
          [9, 0, 7, 12],
          [10, 1, 8, 13],
          [11, 2, 9, 14],
          [12, 3, 10, 15],
          [13, 4, 11, 0],
          [14, 5, 12, 1],
          [15, 6, 13, 2],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11, 12],
            [13, 14, 15, 16, 17, 18],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 18,
      ),
    },
  };
}
