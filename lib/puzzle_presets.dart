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
      // ── MAP 1 ── Tamamen yeniden tasarlandı (v2)
      // Kurallar:
      //   • Her renkten tam 4 adet sıvı
      //   • Başlangıçta aynı renk hiçbir tüpte yan yana gelmiyor
      //   • 2 boş tüp + 1 reklam tüpü (son index)
      //   • BFS doğrulaması: L1=15 hamle, L2=17, L3=20, L4-L10 çok derin (zor)
      1: PuzzlePreset(
        mapNumber: 1,
        levelId: 1,
        difficulty: 1,
        // 4 renk — BFS min 15 hamle
        tubes: [
          [0, 1, 0, 3],
          [2, 0, 3, 2],
          [2, 1, 3, 2],
          [0, 1, 3, 1],
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
        // 5 renk — BFS min 17 hamle
        tubes: [
          [4, 2, 1, 4],
          [1, 3, 0, 3],
          [2, 1, 4, 0],
          [0, 2, 0, 1],
          [2, 3, 4, 3],
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
        // 6 renk — BFS min 20 hamle
        tubes: [
          [4, 1, 0, 4],
          [5, 2, 0, 2],
          [3, 1, 5, 2],
          [3, 1, 0, 1],
          [0, 5, 4, 3],
          [2, 4, 3, 5],
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
        // 7 renk — derin bulmaca
        tubes: [
          [3, 6, 3, 1],
          [0, 3, 4, 0],
          [0, 2, 5, 2],
          [5, 4, 3, 6],
          [1, 5, 6, 1],
          [2, 0, 5, 4],
          [4, 2, 1, 6],
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
        // 8 renk — derin bulmaca
        tubes: [
          [0, 1, 2, 7],
          [5, 4, 0, 4],
          [2, 7, 6, 1],
          [6, 4, 7, 4],
          [5, 3, 1, 0],
          [6, 3, 0, 1],
          [5, 7, 5, 2],
          [3, 6, 2, 3],
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
        // 9 renk — derin bulmaca
        tubes: [
          [6, 3, 0, 5],
          [4, 2, 6, 7],
          [0, 1, 5, 7],
          [4, 6, 8, 4],
          [1, 5, 3, 7],
          [6, 0, 8, 2],
          [1, 2, 5, 2],
          [3, 7, 4, 8],
          [1, 3, 0, 8],
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
        // 10 renk — derin bulmaca
        tubes: [
          [0, 8, 1, 9],
          [5, 7, 4, 0],
          [0, 9, 4, 1],
          [7, 2, 8, 9],
          [6, 2, 3, 5],
          [2, 3, 6, 5],
          [6, 7, 0, 4],
          [1, 6, 3, 8],
          [2, 3, 4, 7],
          [9, 1, 5, 8],
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
        // 10 renk, 3 boş tüp — biraz daha nefes alanı ama farklı dizilim
        tubes: [
          [3, 0, 9, 1],
          [4, 9, 8, 6],
          [8, 9, 4, 2],
          [6, 8, 3, 1],
          [6, 3, 7, 9],
          [0, 5, 2, 1],
          [7, 0, 4, 7],
          [3, 1, 0, 6],
          [5, 7, 2, 5],
          [8, 2, 4, 5],
          [],
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
        difficulty: 9,
        // 11 renk — derin bulmaca
        tubes: [
          [10, 9, 4, 8],
          [1, 8, 0, 7],
          [7, 2, 1, 10],
          [3, 2, 5, 9],
          [5, 0, 5, 4],
          [3, 5, 8, 1],
          [9, 0, 3, 6],
          [2, 4, 9, 7],
          [6, 3, 8, 6],
          [0, 1, 4, 10],
          [10, 7, 2, 6],
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
        // 12 renk — derin bulmaca
        tubes: [
          [1, 10, 9, 0],
          [4, 9, 10, 7],
          [6, 2, 8, 2],
          [8, 10, 5, 8],
          [11, 9, 11, 6],
          [2, 4, 10, 7],
          [5, 7, 6, 1],
          [0, 3, 0, 7],
          [2, 4, 1, 11],
          [3, 5, 3, 11],
          [4, 8, 0, 5],
          [6, 1, 3, 9],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
      ),
    },
    2: {
      1: PuzzlePreset(
        mapNumber: 2,
        levelId: 1,
        difficulty: 2,
        // 6 renk — önceki versiyon 8 renk/6 tüp (24 slot) ile geçersizdi;
        // her renk yalnızca 3 kez görünüyordu. Düzeltildi: 6 renk × 4 = 24 slot ✓
        tubes: [
          [2, 0, 1, 3],
          [1, 4, 5, 4],
          [1, 5, 0, 5],
          [4, 0, 2, 0],
          [3, 2, 3, 5],
          [2, 4, 3, 1],
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
        // 6 renk — önceki versiyon geçersizdi (8 renk/6 tüp). Düzeltildi ✓
        tubes: [
          [4, 3, 4, 1],
          [2, 0, 1, 5],
          [1, 3, 0, 5],
          [2, 3, 0, 1],
          [3, 4, 2, 0],
          [2, 5, 4, 5],
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
        difficulty:
            5, // düzeltildi: 13 renk L7'den (10 renk/diff=4) daha zor olmalı
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
        difficulty: 5, // düzeltildi: L8(diff=5) sonrasında monoton sıra için
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
        difficulty: 5, // düzeltildi: monoton sıra için
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
// ─────────────────────────────────────────────────────────────────
// MAP 3  —  12 Level
// ─────────────────────────────────────────────────────────────────
//
// KURALLAR:
//   • Her renkten tam 4 adet sıvı (lav=16 hariç)
//   • Toplam lav = mountainCapacity (başlangıç tüpleri + refill kuyrukları dahil)
//   • Her tüp tam dolu gelir; sadece 2 boş + 1 reklam tüpü
//   • Refill tüpleri de tam dolu başlar ve 1 kuyruk (4 elemanlık) ile yenilenir
//   • Oyun 2 açık tüple çözülebilir; 3. tüp sadece reklamla açılır
//   • stopWhenMountainFull: true — dağ dolunca refill durur
//
// ZORLUK ARTIŞ MATRİSİ:
//   L1-3  : 5-6 renk  | mc 12-16 | 2-3 refill | difficulty 3
//   L4-6  : 7-8 renk  | mc 16-20 | 3-4 refill | difficulty 4
//   L7-12 : 9-12 renk | mc 20-32 | 3-5 refill | difficulty 5
//
// ─────────────────────────────────────────────────────────────────

    3: {
      // ── L1 ── 5 renk | mountain=12 | 2 refill | diff=3
      // Toplam: 5×4=20 renk + 12 lav = 32 sıvı
      // 6 başlangıç tüpü + 2 refill tüpü = 8 dolu + 3 boş = 11 tüp
      1: PuzzlePreset(
        mapNumber: 3,
        levelId: 1,
        difficulty: 3,
        mountainCapacity: 12,
        tubes: [
          [16, 16, 3, 1], // refill 0
          [16, 0, 1, 0], // refill 1
          [16, 16, 3, 16],
          [16, 0, 16, 1],
          [2, 4, 0, 16],
          [2, 3, 2, 1],
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
              [4, 16, 16, 2],
            ],
            1: [
              [3, 4, 16, 4],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L2 ── 5 renk | mountain=16 | 3 refill | diff=3
      // Toplam: 5×4=20 renk + 16 lav = 36 sıvı
      // 6 başlangıç + 3 refill = 9 dolu + 3 boş = 12 tüp
      2: PuzzlePreset(
        mapNumber: 3,
        levelId: 2,
        difficulty: 3,
        mountainCapacity: 16,
        tubes: [
          [16, 3, 4, 4], // refill 0
          [16, 0, 16, 16], // refill 1 — lav yoğun, kafa karıştırıcı
          [3, 0, 16, 2], // refill 2
          [0, 3, 1, 16],
          [16, 16, 1, 2],
          [16, 0, 4, 16],
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
              [16, 1, 16, 2],
            ],
            1: [
              [1, 16, 2, 3],
            ],
            2: [
              [4, 16, 16, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L3 ── 6 renk | mountain=16 | 2 refill | diff=3
      // Toplam: 6×4=24 renk + 16 lav = 40 sıvı
      // 8 başlangıç + 2 refill = 10 dolu + 3 boş = 13 tüp
      3: PuzzlePreset(
        mapNumber: 3,
        levelId: 3,
        difficulty: 3,
        mountainCapacity: 16,
        tubes: [
          [4, 16, 4, 2], // refill 0
          [1, 3, 16, 16], // refill 1
          [16, 16, 0, 5],
          [1, 16, 3, 2],
          [4, 16, 16, 1],
          [2, 16, 16, 16],
          [5, 5, 16, 0],
          [1, 4, 16, 0],
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
              [0, 16, 16, 3],
            ],
            1: [
              [2, 16, 3, 5],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L4 ── 7 renk | mountain=16 | 3 refill | diff=4
      // Toplam: 7×4=28 renk + 16 lav = 44 sıvı
      // 8 başlangıç + 3 refill = 11 dolu + 3 boş = 14 tüp
      4: PuzzlePreset(
        mapNumber: 3,
        levelId: 4,
        difficulty: 4,
        mountainCapacity: 16,
        tubes: [
          [16, 6, 16, 0], // refill 0
          [1, 16, 4, 3], // refill 1
          [3, 16, 2, 5], // refill 2
          [0, 16, 16, 1],
          [2, 1, 3, 16],
          [5, 4, 16, 16],
          [5, 3, 0, 6],
          [5, 1, 16, 16],
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
              [2, 6, 2, 4],
            ],
            1: [
              [0, 16, 16, 16],
            ],
            2: [
              [16, 4, 16, 6],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L5 ── 7 renk | mountain=20 | 3 refill | diff=4
      // Toplam: 7×4=28 renk + 20 lav = 48 sıvı
      // 9 başlangıç + 3 refill = 12 dolu + 3 boş = 15 tüp
      5: PuzzlePreset(
        mapNumber: 3,
        levelId: 5,
        difficulty: 4,
        mountainCapacity: 20,
        tubes: [
          [16, 6, 6, 2], // refill 0
          [5, 16, 16, 16], // refill 1 — neredeyse tamamen lav
          [16, 16, 2, 4], // refill 2
          [0, 16, 3, 2],
          [6, 16, 2, 16],
          [4, 1, 16, 6],
          [0, 0, 3, 5],
          [5, 3, 16, 16],
          [16, 16, 0, 1],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(12),
        lockedAdTubeIndex: 11,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2],
          refillQueues: {
            0: [
              [16, 16, 16, 16],
            ],
            1: [
              [16, 4, 16, 1],
            ],
            2: [
              [4, 5, 1, 3],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L6 ── 8 renk | mountain=20 | 4 refill | diff=4
      // Toplam: 8×4=32 renk + 20 lav = 52 sıvı
      // 9 başlangıç + 4 refill = 13 dolu + 3 boş = 16 tüp
      6: PuzzlePreset(
        mapNumber: 3,
        levelId: 6,
        difficulty: 4,
        mountainCapacity: 20,
        tubes: [
          [0, 16, 16, 5], // refill 0
          [0, 6, 16, 16], // refill 1
          [1, 5, 16, 1], // refill 2
          [0, 16, 1, 16], // refill 3
          [16, 16, 2, 0],
          [5, 4, 4, 3],
          [6, 3, 16, 1],
          [7, 16, 16, 16],
          [4, 16, 16, 16],
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
              [2, 16, 5, 7],
            ],
            1: [
              [6, 7, 2, 2],
            ],
            2: [
              [7, 16, 16, 6],
            ],
            3: [
              [3, 16, 4, 3],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L7 ── 9 renk | mountain=20 | 3 refill | diff=5
      // Toplam: 9×4=36 renk + 20 lav = 56 sıvı
      // 11 başlangıç + 3 refill = 14 dolu + 3 boş = 17 tüp
      7: PuzzlePreset(
        mapNumber: 3,
        levelId: 7,
        difficulty: 5,
        mountainCapacity: 20,
        tubes: [
          [4, 16, 5, 16], // refill 0
          [16, 0, 16, 5], // refill 1
          [16, 4, 5, 1], // refill 2
          [3, 16, 7, 2],
          [0, 3, 16, 7],
          [16, 0, 16, 16],
          [7, 16, 4, 16],
          [6, 2, 8, 16],
          [7, 8, 16, 6],
          [16, 2, 16, 3],
          [2, 16, 8, 5],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(14),
        lockedAdTubeIndex: 13,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2],
          refillQueues: {
            0: [
              [6, 1, 8, 16],
            ],
            1: [
              [1, 6, 1, 4],
            ],
            2: [
              [16, 0, 3, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L8 ── 9 renk | mountain=24 | 4 refill | diff=5
      // Toplam: 9×4=36 renk + 24 lav = 60 sıvı
      // 11 başlangıç + 4 refill = 15 dolu + 3 boş = 18 tüp
      8: PuzzlePreset(
        mapNumber: 3,
        levelId: 8,
        difficulty: 5,
        mountainCapacity: 24,
        tubes: [
          [5, 0, 4, 5], // refill 0
          [2, 16, 2, 8], // refill 1
          [4, 16, 16, 1], // refill 2
          [6, 3, 16, 16], // refill 3
          [4, 16, 6, 3],
          [0, 16, 16, 16],
          [16, 16, 1, 16],
          [7, 5, 16, 7],
          [3, 16, 16, 16],
          [7, 8, 7, 2],
          [16, 16, 1, 16],
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
              [2, 4, 0, 16],
            ],
            1: [
              [16, 0, 16, 8],
            ],
            2: [
              [6, 16, 3, 5],
            ],
            3: [
              [1, 16, 6, 8],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L9 ── 10 renk | mountain=24 | 4 refill | diff=5
      // Toplam: 10×4=40 renk + 24 lav = 64 sıvı
      // 12 başlangıç + 4 refill = 16 dolu + 3 boş = 19 tüp
      9: PuzzlePreset(
        mapNumber: 3,
        levelId: 9,
        difficulty: 5,
        mountainCapacity: 24,
        tubes: [
          [16, 8, 16, 0], // refill 0
          [9, 7, 16, 16], // refill 1
          [3, 16, 16, 8], // refill 2
          [6, 16, 0, 4], // refill 3
          [1, 8, 6, 9],
          [1, 6, 16, 16],
          [0, 16, 16, 5],
          [1, 16, 4, 2],
          [6, 16, 9, 3],
          [3, 3, 16, 16],
          [5, 5, 2, 8],
          [4, 9, 16, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(15),
        lockedAdTubeIndex: 14,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3],
          refillQueues: {
            0: [
              [7, 2, 1, 16],
            ],
            1: [
              [16, 16, 16, 16],
            ],
            2: [
              [5, 7, 16, 2],
            ],
            3: [
              [7, 16, 0, 4],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L10 ── 10 renk | mountain=28 | 5 refill | diff=5
      // Toplam: 10×4=40 renk + 28 lav = 68 sıvı
      // 12 başlangıç + 5 refill = 17 dolu + 3 boş = 20 tüp
      10: PuzzlePreset(
        mapNumber: 3,
        levelId: 10,
        difficulty: 5,
        mountainCapacity: 28,
        tubes: [
          [8, 9, 0, 16], // refill 0
          [16, 16, 8, 16], // refill 1 — 3 lav
          [6, 16, 16, 16], // refill 2 — 3 lav
          [2, 4, 3, 16], // refill 3
          [5, 16, 6, 3], // refill 4
          [16, 16, 4, 16],
          [6, 8, 1, 1],
          [4, 16, 16, 2],
          [16, 6, 5, 0],
          [7, 7, 5, 2],
          [7, 9, 16, 16],
          [2, 3, 9, 16],
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
              [16, 16, 16, 16],
            ],
            1: [
              [16, 16, 16, 7],
            ],
            2: [
              [16, 16, 8, 4],
            ],
            3: [
              [1, 3, 5, 0],
            ],
            4: [
              [16, 0, 9, 1],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L11 ── 11 renk | mountain=28 | 4 refill | diff=5
      // Toplam: 11×4=44 renk + 28 lav = 72 sıvı
      // 14 başlangıç + 4 refill = 18 dolu + 3 boş = 21 tüp
      11: PuzzlePreset(
        mapNumber: 3,
        levelId: 11,
        difficulty: 5,
        mountainCapacity: 28,
        tubes: [
          [16, 0, 16, 2], // refill 0
          [16, 8, 8, 1], // refill 1
          [3, 6, 7, 9], // refill 2
          [16, 9, 10, 16], // refill 3
          [16, 7, 5, 16],
          [0, 16, 4, 5],
          [6, 4, 16, 16],
          [16, 16, 16, 10],
          [1, 9, 16, 9],
          [4, 6, 16, 16],
          [16, 4, 10, 5],
          [8, 16, 0, 2],
          [10, 8, 2, 16],
          [1, 3, 6, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(17),
        lockedAdTubeIndex: 16,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3],
          refillQueues: {
            0: [
              [16, 16, 16, 16],
            ],
            1: [
              [7, 16, 3, 16],
            ],
            2: [
              [1, 16, 7, 16],
            ],
            3: [
              [5, 3, 2, 0],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),

      // ── L12 ── 12 renk | mountain=32 | 5 refill | diff=5
      // Toplam: 12×4=48 renk + 32 lav = 80 sıvı
      // 15 başlangıç + 5 refill = 20 dolu + 3 boş = 23 tüp
      12: PuzzlePreset(
        mapNumber: 3,
        levelId: 12,
        difficulty: 5,
        mountainCapacity: 32,
        tubes: [
          [16, 16, 4, 10], // refill 0 — 2 lav önde
          [16, 16, 6, 6], // refill 1 — 2 lav önde
          [16, 9, 11, 8], // refill 2
          [16, 4, 6, 0], // refill 3
          [16, 3, 8, 3], // refill 4
          [9, 16, 16, 8],
          [16, 2, 16, 16],
          [16, 3, 10, 16],
          [5, 5, 9, 16],
          [1, 1, 0, 16],
          [16, 16, 9, 16],
          [5, 16, 11, 10],
          [10, 16, 2, 16],
          [0, 0, 16, 1],
          [6, 2, 11, 16],
          [],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(18),
        lockedAdTubeIndex: 17,
        sourceRefill: SourceTubeRefillConfig(
          tubeIndexes: [0, 1, 2, 3, 4],
          refillQueues: {
            0: [
              [7, 4, 4, 16],
            ],
            1: [
              [16, 2, 16, 11],
            ],
            2: [
              [16, 7, 3, 7],
            ],
            3: [
              [1, 7, 8, 16],
            ],
            4: [
              [16, 16, 5, 16],
            ],
          },
          stopWhenMountainFull: true,
        ),
      ),
    },
  };
}
