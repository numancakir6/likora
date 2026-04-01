class PuzzleMove {
  final int from;
  final int to;

  const PuzzleMove(this.from, this.to);
}

class PuzzlePreset {
  final int mapNumber;
  final int levelId;
  final int difficulty;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;

  /// Ana çözüm yolu + izin verilen alternatif yollar.
  final List<List<PuzzleMove>> solutionBranches;

  /// Kısıtlı sapmalarda jokerin tek hamlede geri bağlanması için özel state -> hamle map'i.
  final Map<String, PuzzleMove> jokerRecoveryMoves;

  const PuzzlePreset({
    required this.mapNumber,
    required this.levelId,
    required this.difficulty,
    required this.tubes,
    this.lockedAdTubeIndex = 10,
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
    },
  };
}
