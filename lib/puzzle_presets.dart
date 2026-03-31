class PuzzlePreset {
  final int mapNumber;
  final int levelId;
  final int difficulty;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;

  const PuzzlePreset({
    required this.mapNumber,
    required this.levelId,
    required this.difficulty,
    required this.tubes,
    this.lockedAdTubeIndex = 10,
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

  static const Map<int, Map<int, PuzzlePreset>> _presets = {
    1: {
      1: PuzzlePreset(
        mapNumber: 1,
        levelId: 1,
        difficulty: 1,
        tubes: [
          [0, 1, 2, 3],
          [4, 5, 6, 7],
          [1, 2, 3, 4],
          [5, 6, 7, 0],
          [2, 3, 4, 5],
          [6, 7, 0, 1],
          [3, 4, 5, 6],
          [7, 0, 1, 2],
          [],
          [],
          [],
        ],
      ),
      2: PuzzlePreset(
        mapNumber: 1,
        levelId: 2,
        difficulty: 1,
        tubes: [
          [0, 2, 4, 6],
          [1, 3, 5, 7],
          [2, 4, 6, 1],
          [3, 5, 7, 0],
          [4, 6, 1, 3],
          [5, 7, 0, 2],
          [6, 1, 3, 5],
          [7, 0, 2, 4],
          [],
          [],
          [],
        ],
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 1,
        tubes: [
          [0, 3, 1, 4],
          [2, 5, 6, 7],
          [1, 4, 2, 5],
          [6, 7, 0, 3],
          [2, 5, 3, 6],
          [7, 0, 4, 1],
          [3, 6, 5, 2],
          [4, 1, 7, 0],
          [],
          [],
          [],
        ],
      ),
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 1,
        tubes: [
          [0, 4, 1, 5],
          [2, 6, 3, 7],
          [1, 5, 2, 6],
          [3, 7, 4, 0],
          [2, 6, 5, 1],
          [4, 0, 7, 3],
          [5, 1, 6, 2],
          [7, 3, 0, 4],
          [],
          [],
          [],
        ],
      ),
      5: PuzzlePreset(
        mapNumber: 1,
        levelId: 5,
        difficulty: 2,
        tubes: [
          [0, 5, 2, 7],
          [1, 6, 3, 4],
          [2, 7, 4, 1],
          [3, 0, 5, 6],
          [4, 1, 6, 3],
          [5, 2, 7, 0],
          [6, 3, 0, 5],
          [7, 4, 1, 2],
          [],
          [],
          [],
        ],
      ),
      6: PuzzlePreset(
        mapNumber: 1,
        levelId: 6,
        difficulty: 2,
        tubes: [
          [0, 2, 5, 7],
          [1, 3, 6, 4],
          [2, 4, 7, 0],
          [3, 5, 0, 1],
          [4, 6, 1, 2],
          [5, 7, 2, 3],
          [6, 0, 3, 4],
          [7, 1, 4, 5],
          [],
          [],
          [],
        ],
      ),
      7: PuzzlePreset(
        mapNumber: 1,
        levelId: 7,
        difficulty: 2,
        tubes: [
          [0, 6, 2, 4],
          [1, 7, 3, 5],
          [2, 4, 0, 6],
          [3, 5, 1, 7],
          [4, 0, 6, 2],
          [5, 1, 7, 3],
          [6, 2, 4, 0],
          [7, 3, 5, 1],
          [],
          [],
          [],
        ],
      ),
      8: PuzzlePreset(
        mapNumber: 1,
        levelId: 8,
        difficulty: 2,
        tubes: [
          [0, 3, 6, 1],
          [2, 5, 7, 4],
          [1, 4, 0, 7],
          [3, 6, 2, 5],
          [4, 7, 1, 6],
          [5, 0, 3, 2],
          [6, 1, 4, 7],
          [7, 2, 5, 0],
          [],
          [],
          [],
        ],
      ),
      9: PuzzlePreset(
        mapNumber: 1,
        levelId: 9,
        difficulty: 2,
        tubes: [
          [0, 4, 7, 2],
          [1, 5, 3, 6],
          [2, 6, 0, 4],
          [3, 7, 1, 5],
          [4, 0, 2, 6],
          [5, 1, 6, 3],
          [6, 2, 4, 7],
          [7, 3, 5, 0],
          [],
          [],
          [],
        ],
      ),
      10: PuzzlePreset(
        mapNumber: 1,
        levelId: 10,
        difficulty: 3,
        tubes: [
          [0, 5, 1, 6],
          [2, 7, 3, 4],
          [1, 6, 4, 0],
          [3, 4, 2, 7],
          [4, 0, 6, 2],
          [5, 1, 7, 3],
          [6, 2, 0, 5],
          [7, 3, 5, 1],
          [],
          [],
          [],
        ],
      ),
      11: PuzzlePreset(
        mapNumber: 1,
        levelId: 11,
        difficulty: 3,
        tubes: [
          [0, 6, 1, 7],
          [2, 4, 3, 5],
          [1, 7, 5, 0],
          [3, 5, 2, 6],
          [4, 0, 6, 2],
          [5, 1, 7, 3],
          [6, 2, 4, 1],
          [7, 3, 0, 4],
          [],
          [],
          [],
        ],
      ),
      12: PuzzlePreset(
        mapNumber: 1,
        levelId: 12,
        difficulty: 3,
        tubes: [
          [0, 7, 2, 5],
          [1, 4, 3, 6],
          [2, 5, 0, 7],
          [3, 6, 1, 4],
          [4, 1, 6, 2],
          [5, 2, 7, 3],
          [6, 3, 4, 0],
          [7, 0, 5, 1],
          [],
          [],
          [],
        ],
      ),
    },
  };
}
