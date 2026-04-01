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
          [0, 6, 2, 9],
          [1, 7, 3, 10],
          [2, 8, 4, 11],
          [3, 9, 5, 0],
          [4, 10, 1, 6],
          [5, 11, 7, 2],
          [6, 0, 8, 3],
          [7, 1, 9, 4],
          [8, 2, 10, 5],
          [9, 3, 11, 0],
          [10, 4, 6, 1],
          [11, 5, 7, 8],
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
          [0, 7, 2, 10],
          [1, 8, 3, 11],
          [2, 9, 4, 6],
          [3, 10, 5, 7],
          [4, 11, 0, 8],
          [5, 6, 1, 9],
          [6, 0, 7, 2],
          [7, 1, 8, 3],
          [8, 2, 9, 4],
          [9, 3, 10, 5],
          [10, 4, 11, 0],
          [11, 5, 6, 1],
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
          [0, 7, 2, 12],
          [1, 8, 3, 0],
          [2, 9, 4, 1],
          [3, 10, 5, 2],
          [4, 11, 6, 3],
          [5, 12, 7, 4],
          [6, 0, 8, 5],
          [7, 1, 9, 6],
          [8, 2, 10, 7],
          [9, 3, 11, 8],
          [10, 4, 12, 9],
          [11, 5, 0, 10],
          [12, 6, 1, 11],
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
          [0, 6, 2, 12],
          [1, 7, 3, 8],
          [2, 8, 4, 9],
          [3, 9, 5, 10],
          [4, 10, 6, 11],
          [5, 11, 7, 12],
          [6, 12, 8, 0],
          [7, 0, 9, 1],
          [8, 1, 10, 2],
          [9, 2, 11, 3],
          [10, 3, 12, 4],
          [11, 4, 0, 5],
          [12, 5, 1, 6],
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
          [0, 8, 2, 13],
          [1, 9, 3, 0],
          [2, 10, 4, 1],
          [3, 11, 5, 2],
          [4, 12, 6, 3],
          [5, 13, 7, 4],
          [6, 0, 8, 5],
          [7, 1, 9, 6],
          [8, 2, 10, 7],
          [9, 3, 11, 8],
          [10, 4, 12, 9],
          [11, 5, 13, 10],
          [12, 6, 0, 11],
          [13, 7, 1, 12],
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
          [0, 7, 2, 12],
          [1, 8, 3, 13],
          [2, 9, 4, 0],
          [3, 10, 5, 1],
          [4, 11, 6, 2],
          [5, 12, 7, 3],
          [6, 13, 8, 4],
          [7, 0, 9, 5],
          [8, 1, 10, 6],
          [9, 2, 11, 7],
          [10, 3, 12, 8],
          [11, 4, 13, 9],
          [12, 5, 0, 10],
          [13, 6, 1, 11],
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
          [0, 8, 2, 14],
          [1, 9, 3, 0],
          [2, 10, 4, 1],
          [3, 11, 5, 2],
          [4, 12, 6, 3],
          [5, 13, 7, 4],
          [6, 14, 8, 5],
          [7, 0, 9, 6],
          [8, 1, 10, 7],
          [9, 2, 11, 8],
          [10, 3, 12, 9],
          [11, 4, 13, 10],
          [12, 5, 14, 11],
          [13, 6, 0, 12],
          [14, 7, 1, 13],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11],
            [12, 13, 14, 15, 16, 17],
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
          [0, 9, 2, 15],
          [1, 10, 3, 0],
          [2, 11, 4, 1],
          [3, 12, 5, 2],
          [4, 13, 6, 3],
          [5, 14, 7, 4],
          [6, 15, 8, 5],
          [7, 0, 9, 6],
          [8, 1, 10, 7],
          [9, 2, 11, 8],
          [10, 3, 12, 9],
          [11, 4, 13, 10],
          [12, 5, 14, 11],
          [13, 6, 15, 12],
          [14, 7, 0, 13],
          [15, 8, 1, 14],
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
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 5,
        tubes: [
          [0, 9, 2, 16],
          [1, 10, 3, 0],
          [2, 11, 4, 1],
          [3, 12, 5, 2],
          [4, 13, 6, 3],
          [5, 14, 7, 4],
          [6, 15, 8, 5],
          [7, 16, 9, 6],
          [8, 0, 10, 7],
          [9, 1, 11, 8],
          [10, 2, 12, 9],
          [11, 3, 13, 10],
          [12, 4, 14, 11],
          [13, 5, 15, 12],
          [14, 6, 16, 13],
          [15, 7, 0, 14],
          [16, 8, 1, 15],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7, 8],
            [9, 10, 11, 12],
            [13, 14, 15, 16, 17, 18, 19],
          ],
          rowTopPaddings: [0, 0, 4, 4],
        ),
        lockedAdTubeIndex: 19,
      ),
    },
  };
}
