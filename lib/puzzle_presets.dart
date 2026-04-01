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

  /// Ana çözüm yolu + izin verilen alternatif yollar.
  final List<List<PuzzleMove>> solutionBranches;

  /// Kısıtlı sapmalarda jokerin tek hamlede geri bağlanması için özel state -> hamle map'i.
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
        difficulty: 1,
        tubes: [
          [0, 1, 2, 3],
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [4, 5, 6, 7],
          [0, 4, 1, 5],
          [2, 6, 3, 7],
          [1, 5, 0, 4],
          [3, 7, 2, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7],
            [8, 9, 10],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 10,
        solutionBranches: [
          [
            PuzzleMove(2, 8),
            PuzzleMove(7, 2),
            PuzzleMove(3, 8),
            PuzzleMove(5, 8),
            PuzzleMove(0, 5),
            PuzzleMove(7, 0),
            PuzzleMove(7, 8),
            PuzzleMove(1, 7),
            PuzzleMove(5, 7),
            PuzzleMove(5, 3),
            PuzzleMove(0, 5),
            PuzzleMove(1, 5),
            PuzzleMove(0, 1),
            PuzzleMove(2, 9),
            PuzzleMove(3, 9),
            PuzzleMove(2, 3),
            PuzzleMove(4, 3),
            PuzzleMove(4, 1),
            PuzzleMove(2, 4),
            PuzzleMove(6, 4),
            PuzzleMove(0, 6),
            PuzzleMove(3, 0),
            PuzzleMove(4, 3),
            PuzzleMove(6, 4),
            PuzzleMove(6, 0),
            PuzzleMove(1, 6),
            PuzzleMove(1, 4),
          ],
          [
            PuzzleMove(2, 9),
            PuzzleMove(7, 2),
            PuzzleMove(3, 9),
            PuzzleMove(5, 9),
            PuzzleMove(0, 5),
            PuzzleMove(7, 0),
            PuzzleMove(7, 9),
            PuzzleMove(1, 7),
            PuzzleMove(5, 7),
            PuzzleMove(5, 3),
            PuzzleMove(0, 5),
            PuzzleMove(1, 5),
            PuzzleMove(0, 1),
            PuzzleMove(2, 8),
            PuzzleMove(3, 8),
            PuzzleMove(2, 3),
            PuzzleMove(4, 3),
            PuzzleMove(4, 1),
            PuzzleMove(2, 4),
            PuzzleMove(6, 4),
            PuzzleMove(0, 6),
            PuzzleMove(3, 0),
            PuzzleMove(4, 3),
            PuzzleMove(6, 4),
            PuzzleMove(6, 0),
            PuzzleMove(1, 6),
            PuzzleMove(1, 4),
          ],
        ],
        jokerRecoveryMoves: {},
      ),
      2: PuzzlePreset(
        mapNumber: 1,
        levelId: 2,
        difficulty: 1,
        tubes: [
          [0, 1, 2, 3],
          [4, 5, 6, 0],
          [1, 2, 3, 4],
          [5, 6, 0, 1],
          [2, 3, 4, 5],
          [6, 0, 1, 2],
          [3, 4, 5, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 9,
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 1,
        tubes: [
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [1, 2, 3, 4],
          [5, 6, 7, 0],
          [2, 4, 0, 6],
          [3, 7, 1, 5],
          [4, 0, 6, 2],
          [7, 3, 5, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7],
            [8, 9, 10],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 10,
      ),
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 1,
        tubes: [
          [0, 1, 2, 3],
          [4, 5, 0, 1],
          [2, 3, 4, 5],
          [0, 2, 4, 1],
          [3, 5, 1, 4],
          [2, 0, 5, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2],
            [3, 4, 5],
            [6, 7, 8],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 8,
      ),
      5: PuzzlePreset(
        mapNumber: 1,
        levelId: 5,
        difficulty: 2,
        tubes: [
          [0, 2, 4, 6],
          [1, 3, 5, 0],
          [2, 4, 6, 1],
          [3, 5, 0, 2],
          [4, 6, 1, 3],
          [5, 0, 2, 4],
          [6, 1, 3, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6, 7],
            [8, 9],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 9,
      ),
      6: PuzzlePreset(
        mapNumber: 1,
        levelId: 6,
        difficulty: 2,
        tubes: [
          [0, 2, 4, 6],
          [1, 3, 5, 7],
          [2, 5, 0, 3],
          [4, 7, 1, 6],
          [6, 0, 3, 5],
          [1, 4, 7, 2],
          [3, 6, 2, 0],
          [5, 7, 4, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2],
            [3, 4, 5, 6],
            [7, 8, 9, 10],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 10,
      ),
      7: PuzzlePreset(
        mapNumber: 1,
        levelId: 7,
        difficulty: 2,
        tubes: [
          [0, 3, 1, 4],
          [2, 5, 0, 3],
          [1, 4, 2, 5],
          [0, 2, 4, 1],
          [3, 5, 1, 4],
          [2, 0, 5, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5],
            [6, 7, 8],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 8,
      ),
      8: PuzzlePreset(
        mapNumber: 1,
        levelId: 8,
        difficulty: 3,
        tubes: [
          [0, 3, 6, 2],
          [1, 4, 0, 5],
          [2, 5, 1, 6],
          [3, 0, 4, 1],
          [4, 1, 5, 2],
          [5, 2, 6, 3],
          [6, 0, 3, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2],
            [3, 4, 5, 6],
            [7, 8, 9],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 9,
      ),
      9: PuzzlePreset(
        mapNumber: 1,
        levelId: 9,
        difficulty: 3,
        tubes: [
          [0, 3, 6, 1],
          [2, 5, 7, 0],
          [1, 4, 0, 6],
          [3, 7, 2, 5],
          [6, 2, 4, 1],
          [5, 0, 3, 7],
          [4, 1, 6, 2],
          [7, 3, 5, 4],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1, 2, 3],
            [4, 5, 6],
            [7, 8, 9, 10],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 10,
      ),
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 3,
        tubes: [
          [0, 4, 1, 5],
          [2, 0, 3, 1],
          [4, 2, 5, 3],
          [1, 5, 0, 4],
          [3, 1, 4, 2],
          [5, 3, 2, 0],
          [],
          [],
          [],
        ],
        layout: StageLayout.rows(
          rows: [
            [0, 1],
            [2, 3, 4, 5],
            [6, 7, 8],
          ],
          rowTopPaddings: [0, 0, 4],
        ),
        lockedAdTubeIndex: 8,
      ),
    },
  };
}
