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

class PuzzlePreset {
  final int mapNumber;
  final int levelId;
  final int difficulty;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;
  final StageLayout layout;
  final PuzzleTubeStyle tubeStyle;
  final Map<int, PuzzleTubeStyle> tubeStyles;
  final List<List<PuzzleMove>> solutionBranches;
  final Map<String, PuzzleMove> jokerRecoveryMoves;
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
    this.solutionBranches = const [],
    this.jokerRecoveryMoves = const {},
    this.mountainCapacity,
    this.sourceRefill,
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

  static final Map<int, Map<int, PuzzlePreset>> _presets = {
    1: {
      1: PuzzlePreset(
        mapNumber: 1,
        levelId: 1,
        difficulty: 1,
        tubes: [
          [0, 1, 2, 0],
          [3, 4, 5, 1],
          [2, 6, 6, 7],
          [4, 5, 3, 6],
          [0, 7, 7, 6],
          [2, 1, 4, 7],
          [5, 0, 2, 1],
          [3, 4, 5, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
        solutionBranches: [
          [
            PuzzleMove(3, 8),
            PuzzleMove(4, 8),
            PuzzleMove(5, 9),
            PuzzleMove(2, 9),
            PuzzleMove(0, 8),
            PuzzleMove(6, 8),
          ],
          [
            PuzzleMove(5, 9),
            PuzzleMove(2, 9),
            PuzzleMove(3, 8),
            PuzzleMove(4, 8),
            PuzzleMove(0, 8),
            PuzzleMove(6, 8),
          ],
          [
            PuzzleMove(3, 9),
            PuzzleMove(4, 9),
            PuzzleMove(5, 8),
            PuzzleMove(2, 8),
            PuzzleMove(0, 9),
            PuzzleMove(6, 9),
          ],
          [
            PuzzleMove(5, 8),
            PuzzleMove(2, 8),
            PuzzleMove(3, 9),
            PuzzleMove(4, 9),
            PuzzleMove(0, 8),
            PuzzleMove(6, 8),
          ],
        ],
        jokerRecoveryMoves: {
          '0,1,2,0|3,4,5,1|2,6,6,7|4,5,3,6|0,7,7,6|2,1,4,7|5,0,2,1|3,4,5,3|||':
              PuzzleMove(3, 8),
          '0,1,2,0|3,4,5,1|2,6,6,7|4,5,3|0,7,7,6|2,1,4,7|5,0,2,1|3,4,5,3|6||':
              PuzzleMove(4, 8),
          '0,1,2,0|3,4,5,1|2,6,6,7|4,5,3|0,7,7|2,1,4,7|5,0,2,1|3,4,5,3|6,6||':
              PuzzleMove(5, 9),
          '0,1,2,0|3,4,5,1|2,6,6,7|4,5,3|0,7,7|2,1,4|5,0,2,1|3,4,5,3|6,6|7||':
              PuzzleMove(2, 9),
          '0,1,2,0|3,4,5,1|2,6,6|4,5,3|0,7,7|2,1,4|5,0,2,1|3,4,5,3|6,6|7,7|':
              PuzzleMove(0, 8),
          '0,1,2|3,4,5,1|2,6,6|4,5,3|0,7,7|2,1,4|5,0,2,1|3,4,5,3|6,6,0|7,7|':
              PuzzleMove(6, 8),
        },
      ),
      2: PuzzlePreset(
        mapNumber: 1,
        levelId: 2,
        difficulty: 1,
        tubes: [
          [2, 1, 0, 0],
          [4, 5, 5, 0],
          [6, 1, 3, 1],
          [2, 3, 2, 2],
          [6, 6, 1, 3],
          [4, 4, 3, 4],
          [6, 0, 5, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(10),
        lockedAdTubeIndex: 9,
        solutionBranches: [
          [
            PuzzleMove(0, 7),
            PuzzleMove(1, 7),
            PuzzleMove(2, 0),
            PuzzleMove(4, 2),
            PuzzleMove(4, 0),
            PuzzleMove(0, 8),
            PuzzleMove(3, 0),
            PuzzleMove(2, 3),
            PuzzleMove(2, 8),
            PuzzleMove(3, 9),
            PuzzleMove(0, 3),
            PuzzleMove(1, 0),
            PuzzleMove(6, 0),
            PuzzleMove(6, 7),
            PuzzleMove(5, 1),
            PuzzleMove(5, 9),
            PuzzleMove(1, 5),
            PuzzleMove(4, 2),
            PuzzleMove(2, 6),
          ],
        ],
        jokerRecoveryMoves: {
          '2,1,0,0|4,5,5,0|6,1,3,1|2,3,2,2|6,6,1,3|4,4,3,4|6,0,5,5|||':
              PuzzleMove(0, 7),
          '2,1|4,5,5,0|6,1,3,1|2,3,2,2|6,6,1,3|4,4,3,4|6,0,5,5|0,0||':
              PuzzleMove(1, 7),
          '2,1|4,5,5|6,1,3,1|2,3,2,2|6,6,1,3|4,4,3,4|6,0,5,5|0,0,0||':
              PuzzleMove(2, 0),
          '2,1,1|4,5,5|6,1,3|2,3,2,2|6,6,1,3|4,4,3,4|6,0,5,5|0,0,0||':
              PuzzleMove(4, 2),
          '2,1,1|4,5,5|6,1,3,3|2,3,2,2|6,6,1|4,4,3,4|6,0,5,5|0,0,0||':
              PuzzleMove(4, 0),
          '2,1,1,1|4,5,5|6,1,3,3|2,3,2,2|6,6|4,4,3,4|6,0,5,5|0,0,0||':
              PuzzleMove(0, 8),
          '2|4,5,5|6,1,3,3|2,3,2,2|6,6|4,4,3,4|6,0,5,5|0,0,0|1,1,1|':
              PuzzleMove(3, 0),
          '2,2,2|4,5,5|6,1,3,3|2,3|6,6|4,4,3,4|6,0,5,5|0,0,0|1,1,1|':
              PuzzleMove(2, 3),
          '2,2,2|4,5,5|6,1|2,3,3,3|6,6|4,4,3,4|6,0,5,5|0,0,0|1,1,1|':
              PuzzleMove(2, 8),
          '2,2,2|4,5,5|6|2,3,3,3|6,6|4,4,3,4|6,0,5,5|0,0,0|1,1,1,1|':
              PuzzleMove(3, 9),
          '2,2,2|4,5,5|6|2|6,6|4,4,3,4|6,0,5,5|0,0,0|1,1,1,1|3,3,3':
              PuzzleMove(0, 3),
          '|4,5,5|6|2,2,2,2|6,6|4,4,3,4|6,0,5,5|0,0,0|1,1,1,1|3,3,3':
              PuzzleMove(1, 0),
          '5,5|4|6|2,2,2,2|6,6|4,4,3,4|6,0,5,5|0,0,0|1,1,1,1|3,3,3':
              PuzzleMove(6, 0),
          '5,5,5,5|4|6|2,2,2,2|6,6|4,4,3,4|6,0|0,0,0|1,1,1,1|3,3,3':
              PuzzleMove(6, 7),
          '5,5,5,5|4|6|2,2,2,2|6,6|4,4,3,4|6|0,0,0,0|1,1,1,1|3,3,3':
              PuzzleMove(5, 1),
          '5,5,5,5|4,4|6|2,2,2,2|6,6|4,4,3|6|0,0,0,0|1,1,1,1|3,3,3':
              PuzzleMove(5, 9),
          '5,5,5,5|4,4|6|2,2,2,2|6,6|4,4|6|0,0,0,0|1,1,1,1|3,3,3,3':
              PuzzleMove(1, 5),
          '5,5,5,5||6|2,2,2,2|6,6|4,4,4,4|6|0,0,0,0|1,1,1,1|3,3,3,3':
              PuzzleMove(4, 2),
          '5,5,5,5||6,6,6|2,2,2,2||4,4,4,4|6|0,0,0,0|1,1,1,1|3,3,3,3':
              PuzzleMove(2, 6),
        },
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 2,
        tubes: [
          [2, 4, 4, 0],
          [6, 6, 0, 0],
          [6, 1, 5, 1],
          [6, 7, 1, 1],
          [3, 2, 3, 2],
          [3, 7, 5, 3],
          [7, 0, 4, 4],
          [2, 7, 5, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(11),
        lockedAdTubeIndex: 10,
        solutionBranches: [
          [
            PuzzleMove(1, 8),
            PuzzleMove(0, 8),
            PuzzleMove(0, 9),
            PuzzleMove(6, 9),
            PuzzleMove(6, 8),
            PuzzleMove(4, 0),
            PuzzleMove(5, 4),
            PuzzleMove(3, 10),
            PuzzleMove(2, 10),
            PuzzleMove(2, 5),
            PuzzleMove(2, 10),
            PuzzleMove(3, 6),
            PuzzleMove(1, 2),
            PuzzleMove(2, 3),
            PuzzleMove(4, 1),
            PuzzleMove(4, 0),
            PuzzleMove(5, 2),
            PuzzleMove(7, 2),
            PuzzleMove(5, 6),
            PuzzleMove(7, 6),
            PuzzleMove(0, 7),
            PuzzleMove(1, 4),
            PuzzleMove(4, 5),
          ],
        ],
        jokerRecoveryMoves: {
          '2,4,4,0|6,6,0,0|6,1,5,1|6,7,1,1|3,2,3,2|3,7,5,3|7,0,4,4|2,7,5,5|||':
              PuzzleMove(1, 8),
          '2,4,4,0|6,6|6,1,5,1|6,7,1,1|3,2,3,2|3,7,5,3|7,0,4,4|2,7,5,5|0,0||':
              PuzzleMove(0, 8),
          '2,4,4|6,6|6,1,5,1|6,7,1,1|3,2,3,2|3,7,5,3|7,0,4,4|2,7,5,5|0,0,0||':
              PuzzleMove(0, 9),
          '2|6,6|6,1,5,1|6,7,1,1|3,2,3,2|3,7,5,3|7,0,4,4|2,7,5,5|0,0,0|4,4|':
              PuzzleMove(6, 9),
          '2|6,6|6,1,5,1|6,7,1,1|3,2,3,2|3,7,5,3|7,0|2,7,5,5|0,0,0|4,4,4,4|':
              PuzzleMove(6, 8),
          '2|6,6|6,1,5,1|6,7,1,1|3,2,3,2|3,7,5,3|7|2,7,5,5|0,0,0,0|4,4,4,4|':
              PuzzleMove(4, 0),
          '2,2|6,6|6,1,5,1|6,7,1,1|3,2,3|3,7,5,3|7|2,7,5,5|0,0,0,0|4,4,4,4|':
              PuzzleMove(5, 4),
          '2,2|6,6|6,1,5,1|6,7,1,1|3,2,3,3|3,7,5|7|2,7,5,5|0,0,0,0|4,4,4,4|':
              PuzzleMove(3, 10),
          '2,2|6,6|6,1,5,1|6,7|3,2,3,3|3,7,5|7|2,7,5,5|0,0,0,0|4,4,4,4|1,1':
              PuzzleMove(2, 10),
          '2,2|6,6|6,1,5|6,7|3,2,3,3|3,7,5|7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1':
              PuzzleMove(2, 5),
          '2,2|6,6|6,1|6,7|3,2,3,3|3,7,5,5|7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1':
              PuzzleMove(2, 10),
          '2,2|6,6|6|6,7|3,2,3,3|3,7,5,5|7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(3, 6),
          '2,2|6,6|6|6|3,2,3,3|3,7,5,5|7,7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(1, 2),
          '2,2||6,6,6|6|3,2,3,3|3,7,5,5|7,7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(2, 3),
          '2,2|||6,6,6,6|3,2,3,3|3,7,5,5|7,7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(4, 1),
          '2,2|3,3||6,6,6,6|3,2|3,7,5,5|7,7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(4, 0),
          '2,2,2|3,3||6,6,6,6|3|3,7,5,5|7,7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(5, 2),
          '2,2,2|3,3|5,5|6,6,6,6|3|3,7|7,7|2,7,5,5|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(7, 2),
          '2,2,2|3,3|5,5,5,5|6,6,6,6|3|3,7|7,7|2,7|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(5, 6),
          '2,2,2|3,3|5,5,5,5|6,6,6,6|3|3|7,7,7|2,7|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(7, 6),
          '2,2,2|3,3|5,5,5,5|6,6,6,6|3|3|7,7,7,7|2|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(0, 7),
          '|3,3|5,5,5,5|6,6,6,6|3|3|7,7,7,7|2,2,2,2|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(1, 4),
          '||5,5,5,5|6,6,6,6|3,3,3|3|7,7,7,7|2,2,2,2|0,0,0,0|4,4,4,4|1,1,1,1':
              PuzzleMove(4, 5),
        },
      ),
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 2,
        tubes: [
          [2, 0, 4, 0],
          [7, 6, 6, 0],
          [4, 4, 6, 1],
          [7, 2, 1, 1],
          [5, 0, 2, 2],
          [3, 7, 3, 3],
          [8, 8, 5, 4],
          [5, 3, 7, 5],
          [8, 1, 8, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
        solutionBranches: [
          [
            PuzzleMove(2, 9),
            PuzzleMove(3, 9),
            PuzzleMove(0, 10),
            PuzzleMove(1, 10),
            PuzzleMove(8, 1),
            PuzzleMove(6, 0),
            PuzzleMove(7, 6),
            PuzzleMove(4, 3),
          ],
          [
            PuzzleMove(0, 10),
            PuzzleMove(1, 10),
            PuzzleMove(2, 9),
            PuzzleMove(3, 9),
            PuzzleMove(8, 1),
            PuzzleMove(6, 0),
            PuzzleMove(4, 3),
            PuzzleMove(7, 6),
          ],
        ],
        jokerRecoveryMoves: {
          '2,0,4,0|7,6,6,0|4,4,6,1|7,2,1,1|5,0,2,2|3,7,3,3|8,8,5,4|5,3,7,5|8,1,8,6|||':
              PuzzleMove(2, 9),
          '2,0,4,0|7,6,6,0|4,4,6|7,2,1,1|5,0,2,2|3,7,3,3|8,8,5,4|5,3,7,5|8,1,8,6|1||':
              PuzzleMove(3, 9),
          '2,0,4,0|7,6,6,0|4,4,6|7,2|5,0,2,2|3,7,3,3|8,8,5,4|5,3,7,5|8,1,8,6|1,1,1||':
              PuzzleMove(0, 10),
          '2,0,4|7,6,6,0|4,4,6|7,2|5,0,2,2|3,7,3,3|8,8,5,4|5,3,7,5|8,1,8,6|1,1,1|0|':
              PuzzleMove(1, 10),
          '2,0,4|7,6,6|4,4,6|7,2|5,0,2,2|3,7,3,3|8,8,5,4|5,3,7,5|8,1,8,6|1,1,1|0,0|':
              PuzzleMove(8, 1),
          '2,0,4|7,6,6,6|4,4,6|7,2|5,0,2,2|3,7,3,3|8,8,5,4|5,3,7,5|8,1,8|1,1,1|0,0|':
              PuzzleMove(6, 0),
          '2,0,4,4|7,6,6,6|4,4,6|7,2|5,0,2,2|3,7,3,3|8,8,5|5,3,7,5|8,1,8|1,1,1|0,0|':
              PuzzleMove(7, 6),
          '2,0,4,4|7,6,6,6|4,4,6|7,2|5,0,2,2|3,7,3,3|8,8,5,5|5,3,7|8,1,8|1,1,1|0,0|':
              PuzzleMove(4, 3),
        },
      ),
      5: PuzzlePreset(
        mapNumber: 1,
        levelId: 5,
        difficulty: 3,
        tubes: [
          [7, 0, 8, 0],
          [2, 6, 6, 0],
          [5, 3, 5, 1],
          [8, 3, 8, 1],
          [7, 7, 8, 2],
          [1, 9, 1, 2],
          [2, 4, 4, 3],
          [9, 4, 5, 4],
          [9, 9, 0, 5],
          [7, 6, 3, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(13),
        lockedAdTubeIndex: 12,
        solutionBranches: [
          [
            PuzzleMove(2, 10),
            PuzzleMove(3, 10),
            PuzzleMove(0, 11),
            PuzzleMove(1, 11),
            PuzzleMove(8, 2),
            PuzzleMove(3, 0),
            PuzzleMove(6, 3),
            PuzzleMove(7, 6),
            PuzzleMove(9, 1),
            PuzzleMove(8, 11),
          ],
          [
            PuzzleMove(0, 11),
            PuzzleMove(1, 11),
            PuzzleMove(2, 10),
            PuzzleMove(3, 10),
            PuzzleMove(8, 2),
            PuzzleMove(6, 3),
            PuzzleMove(3, 0),
            PuzzleMove(7, 6),
            PuzzleMove(9, 1),
            PuzzleMove(8, 11),
          ],
        ],
        jokerRecoveryMoves: {
          '7,0,8,0|2,6,6,0|5,3,5,1|8,3,8,1|7,7,8,2|1,9,1,2|2,4,4,3|9,4,5,4|9,9,0,5|7,6,3,6|||':
              PuzzleMove(2, 10),
          '7,0,8,0|2,6,6,0|5,3,5|8,3,8,1|7,7,8,2|1,9,1,2|2,4,4,3|9,4,5,4|9,9,0,5|7,6,3,6|1||':
              PuzzleMove(3, 10),
          '7,0,8,0|2,6,6,0|5,3,5|8,3,8|7,7,8,2|1,9,1,2|2,4,4,3|9,4,5,4|9,9,0,5|7,6,3,6|1,1||':
              PuzzleMove(0, 11),
          '7,0,8|2,6,6,0|5,3,5|8,3,8|7,7,8,2|1,9,1,2|2,4,4,3|9,4,5,4|9,9,0,5|7,6,3,6|1,1|0|':
              PuzzleMove(1, 11),
          '7,0,8|2,6,6|5,3,5|8,3,8|7,7,8,2|1,9,1,2|2,4,4,3|9,4,5,4|9,9,0,5|7,6,3,6|1,1|0,0|':
              PuzzleMove(8, 2),
          '7,0,8|2,6,6|5,3,5,5|8,3,8|7,7,8,2|1,9,1,2|2,4,4,3|9,4,5,4|9,9,0|7,6,3,6|1,1|0,0|':
              PuzzleMove(3, 0),
          '7,0,8,8|2,6,6|5,3,5,5|8,3|7,7,8,2|1,9,1,2|2,4,4,3|9,4,5,4|9,9,0|7,6,3,6|1,1|0,0|':
              PuzzleMove(6, 3),
          '7,0,8,8|2,6,6|5,3,5,5|8,3,3|7,7,8,2|1,9,1,2|2,4,4|9,4,5,4|9,9,0|7,6,3,6|1,1|0,0|':
              PuzzleMove(7, 6),
          '7,0,8,8|2,6,6|5,3,5,5|8,3,3|7,7,8,2|1,9,1,2|2,4,4,4|9,4,5|9,9,0|7,6,3,6|1,1|0,0|':
              PuzzleMove(9, 1),
          '7,0,8,8|2,6,6,6|5,3,5,5|8,3,3|7,7,8,2|1,9,1,2|2,4,4,4|9,4,5|9,9,0|7,6,3|1,1|0,0|':
              PuzzleMove(8, 11),
        },
      ),
      6: PuzzlePreset(
        mapNumber: 1,
        levelId: 6,
        difficulty: 4,
        tubes: [
          [0, 1, 2, 3],
          [4, 5, 6, 3],
          [7, 8, 9, 10],
          [11, 0, 1, 10],
          [2, 4, 5, 6],
          [7, 8, 9, 11],
          [0, 4, 7, 11],
          [1, 5, 8, 3],
          [2, 6, 9, 10],
          [0, 4, 7, 11],
          [1, 5, 8, 3],
          [2, 6, 9, 10],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
        solutionBranches: [
          [
            PuzzleMove(7, 12),
            PuzzleMove(10, 12),
            PuzzleMove(2, 13),
            PuzzleMove(11, 13),
            PuzzleMove(0, 12),
            PuzzleMove(8, 13),
            PuzzleMove(1, 12),
            PuzzleMove(3, 13),
          ],
          [
            PuzzleMove(2, 13),
            PuzzleMove(11, 13),
            PuzzleMove(7, 12),
            PuzzleMove(10, 12),
            PuzzleMove(8, 13),
            PuzzleMove(0, 12),
            PuzzleMove(3, 13),
            PuzzleMove(1, 12),
          ],
          [
            PuzzleMove(7, 12),
            PuzzleMove(2, 13),
            PuzzleMove(10, 12),
            PuzzleMove(11, 13),
            PuzzleMove(0, 12),
            PuzzleMove(8, 13),
            PuzzleMove(1, 12),
            PuzzleMove(3, 13),
          ],
        ],
        jokerRecoveryMoves: {
          '0,1,2,3|4,5,6,3|7,8,9,10|11,0,1,10|2,4,5,6|7,8,9,11|0,4,7,11|1,5,8,3|2,6,9,10|0,4,7,11|1,5,8,3|2,6,9,10|||':
              PuzzleMove(7, 12),
          '0,1,2,3|4,5,6,3|7,8,9,10|11,0,1,10|2,4,5,6|7,8,9,11|0,4,7,11|1,5,8|2,6,9,10|0,4,7,11|1,5,8,3|2,6,9,10|3||':
              PuzzleMove(10, 12),
          '0,1,2,3|4,5,6,3|7,8,9,10|11,0,1,10|2,4,5,6|7,8,9,11|0,4,7,11|1,5,8|2,6,9,10|0,4,7,11|1,5,8|2,6,9,10|3,3||':
              PuzzleMove(2, 13),
          '0,1,2,3|4,5,6,3|7,8,9|11,0,1,10|2,4,5,6|7,8,9,11|0,4,7,11|1,5,8|2,6,9,10|0,4,7,11|1,5,8|2,6,9,10|3,3|10|':
              PuzzleMove(11, 13),
          '0,1,2,3|4,5,6,3|7,8,9|11,0,1,10|2,4,5,6|7,8,9,11|0,4,7,11|1,5,8|2,6,9,10|0,4,7,11|1,5,8|2,6,9|3,3|10,10|':
              PuzzleMove(0, 12),
          '0,1,2|4,5,6,3|7,8,9|11,0,1,10|2,4,5,6|7,8,9,11|0,4,7,11|1,5,8|2,6,9,10|0,4,7,11|1,5,8|2,6,9|3,3,3|10,10|':
              PuzzleMove(8, 13),
        },
      ),
      7: PuzzlePreset(
        mapNumber: 1,
        levelId: 7,
        difficulty: 4,
        tubes: [
          [12, 2, 1, 7],
          [3, 0, 9, 8],
          [3, 10, 6, 10],
          [12, 5, 6, 4],
          [3, 2, 3, 11],
          [8, 9, 10, 7],
          [1, 12, 4, 5],
          [8, 0, 5, 7],
          [9, 5, 11, 0],
          [12, 4, 2, 9],
          [7, 11, 0, 4],
          [2, 6, 11, 1],
          [1, 8, 10, 6],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(16),
        lockedAdTubeIndex: 15,
      ),
      8: PuzzlePreset(
        mapNumber: 1,
        levelId: 8,
        difficulty: 5,
        tubes: [
          [12, 11, 10, 1],
          [7, 8, 4, 5],
          [5, 1, 5, 7],
          [13, 4, 7, 12],
          [3, 2, 10, 3],
          [0, 13, 0, 3],
          [2, 13, 1, 2],
          [10, 7, 13, 9],
          [12, 1, 8, 0],
          [6, 5, 9, 2],
          [9, 12, 9, 11],
          [6, 4, 6, 8],
          [6, 4, 0, 3],
          [11, 8, 11, 10],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(17),
        lockedAdTubeIndex: 16,
      ),
      9: PuzzlePreset(
        mapNumber: 1,
        levelId: 9,
        difficulty: 5,
        tubes: [
          [2, 12, 14, 11],
          [11, 7, 5, 7],
          [14, 7, 0, 2],
          [2, 5, 8, 10],
          [11, 1, 4, 9],
          [12, 10, 4, 8],
          [9, 0, 6, 14],
          [4, 1, 7, 0],
          [12, 9, 6, 8],
          [2, 3, 1, 8],
          [0, 10, 6, 12],
          [14, 13, 11, 13],
          [13, 5, 13, 3],
          [4, 3, 5, 6],
          [10, 1, 9, 3],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
      ),
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 6,
        tubes: [
          [8, 11, 2, 4],
          [0, 1, 9, 5],
          [4, 6, 12, 15],
          [7, 11, 1, 12],
          [7, 2, 14, 12],
          [5, 14, 9, 13],
          [6, 3, 9, 1],
          [13, 2, 8, 10],
          [9, 12, 7, 10],
          [3, 13, 4, 14],
          [14, 6, 0, 11],
          [13, 3, 15, 3],
          [8, 5, 7, 8],
          [4, 15, 0, 10],
          [6, 11, 5, 0],
          [2, 1, 15, 10],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(19),
        lockedAdTubeIndex: 18,
      ),
    },
    2: {
      1: PuzzlePreset(
        mapNumber: 2,
        levelId: 1,
        difficulty: 2,
        tubes: [
          [6, 1, 2, 6],
          [2, 4, 2, 3],
          [6, 7, 5, 3],
          [5, 4, 1, 3],
          [3, 1, 6, 4],
          [7, 0, 5, 0],
          [2, 0, 5, 1],
          [7, 0, 7, 4],
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
          [2, 6, 4, 6],
          [8, 5, 8, 6],
          [5, 3, 6, 1],
          [8, 5, 3, 0],
          [0, 7, 8, 7],
          [2, 3, 4, 2],
          [0, 7, 3, 1],
          [7, 5, 2, 4],
          [1, 0, 4, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
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
          // 0 ve 1 = yenilenen kaynak tüpler
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
          // 🔁 REFILL TÜPLERİ
          [16, 0, 3, 1],
          [2, 16, 4, 5],

          // 🔀 ANA KARIŞIM
          [1, 2, 16, 0],
          [3, 16, 5, 2],
          [4, 1, 16, 3],
          [5, 4, 0, 16],
          [0, 3, 2, 4],
          [16, 5, 1, 16], // lav çiftli (max 2 ✔)

          // 🟢 BOŞ TÜPLER
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
