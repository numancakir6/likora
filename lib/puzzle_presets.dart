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

  /// Tüm çözüm yolları (her biri baştan sona hamle listesi).
  /// Yeni workflow: sadece bunları yaz — jokerRecoveryMap otomatik üretilir.
  final List<List<PuzzleMove>> solutionBranches;

  /// Otomatik üretilen imza→hamle haritası.
  /// Level yüklenirken [PuzzlePresets.buildRecoveryMap] ile doldurulur.
  /// Direkt elle yazılmasına gerek yok.
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

  /// solutionBranches'tan otomatik üretilmiş jokerRecoveryMoves ile
  /// yeni bir PuzzlePreset döndürür.
  PuzzlePreset withBuiltRecoveryMap() {
    final built = PuzzlePresets.buildRecoveryMap(tubes, solutionBranches);
    return PuzzlePreset(
      mapNumber: mapNumber,
      levelId: levelId,
      difficulty: difficulty,
      tubes: tubes,
      layout: layout,
      lockedAdTubeIndex: lockedAdTubeIndex,
      tubeStyle: tubeStyle,
      tubeStyles: tubeStyles,
      solutionBranches: solutionBranches,
      jokerRecoveryMoves: built,
      mountainCapacity: mountainCapacity,
      sourceRefill: sourceRefill,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PUZZLE PRESETS  —  yardımcılar + statik tablo
// ─────────────────────────────────────────────────────────────────

class PuzzlePresets {
  // ── Önbelleklenmiş (build edilmiş) preset'ler ──────────────────
  static final Map<int, Map<int, PuzzlePreset>> _builtCache = {};

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

  /// Level'i döndürür; jokerRecoveryMap yoksa solutionBranches'tan üretir.
  /// Sonuç önbelleğe alınır — her level için tek seferlik hesap.
  static PuzzlePreset? getOrNull({
    required int mapNumber,
    required int levelId,
  }) {
    // Önbellekte varsa direkt dön
    final cached = _builtCache[mapNumber]?[levelId];
    if (cached != null) return cached;

    final raw = _presets[mapNumber]?[levelId];
    if (raw == null) return null;

    // jokerRecoveryMoves boşsa otomatik üret
    final preset =
        raw.jokerRecoveryMoves.isEmpty && raw.solutionBranches.isNotEmpty
            ? raw.withBuiltRecoveryMap()
            : raw;

    _builtCache.putIfAbsent(mapNumber, () => {})[levelId] = preset;
    return preset;
  }

  // ── İmza yardımcısı ───────────────────────────────────────────
  static String signatureOf(List<List<int>> tubes) {
    return tubes.map((t) => t.join(',')).join('|');
  }

  // ── Recovery map üreticisi ────────────────────────────────────
  ///
  /// Her branch için baştan sona simülasyon yapar.
  /// Her adımdan ÖNCE board imzasını kaydeder → o adıma ait hamleye map'ler.
  ///
  /// Aynı imzaya birden fazla branch farklı hamle önerirse ilk bulan kazanır
  /// (solutionBranches listesindeki sıra önceliği belirler).
  static Map<String, PuzzleMove> buildRecoveryMap(
    List<List<int>> initialTubes,
    List<List<PuzzleMove>> branches,
  ) {
    final map = <String, PuzzleMove>{};

    for (final branch in branches) {
      // Her branch için baştan klonla
      final sim = _deepClone(initialTubes);

      for (final move in branch) {
        // Bu hamleden ÖNCE board'un imzasını al
        final sig = signatureOf(sim);

        // Henüz kayıtlı değilse ekle (ilk branch önceliklidir)
        map.putIfAbsent(sig, () => move);

        // Simülasyona hamleyi uygula — geçersizse branch'i durdur
        if (!_canPour(sim, move.from, move.to)) break;
        _doPour(sim, move.from, move.to);
      }
    }

    return map;
  }

  // ── İç yardımcılar (sadece buildRecoveryMap için) ─────────────
  static List<List<int>> _deepClone(List<List<int>> tubes) =>
      tubes.map((t) => List<int>.from(t)).toList();

  static const int _kCap = 4;

  static bool _canPour(List<List<int>> tubes, int from, int to) {
    if (from == to) return false;
    if (from < 0 || from >= tubes.length) return false;
    if (to < 0 || to >= tubes.length) return false;
    if (tubes[from].isEmpty) return false;
    if (tubes[to].length >= _kCap) return false;
    final top = tubes[from].last;
    if (tubes[to].isNotEmpty && tubes[to].last != top) return false;
    return true;
  }

  static void _doPour(List<List<int>> tubes, int from, int to) {
    final f = tubes[from];
    final t = tubes[to];
    final top = f.last;
    while (f.isNotEmpty && f.last == top && t.length < _kCap) {
      t.add(f.removeLast());
    }
  }

  // ── Preset tablosu ────────────────────────────────────────────
  //
  // KULLANIM KILAVUZU:
  //   1. Her level için sadece `solutionBranches` yaz.
  //   2. `jokerRecoveryMoves` alanını tamamen boş bırak (ya da hiç yazma).
  //   3. Joker otomatik olarak buildRecoveryMap() ile doğru hamleyi bulur.
  //
  //   Birden fazla çözüm yolu varsa hepsini branches'a ekle —
  //   map her yolun her ara durumunu kapsar.
  //
  static final Map<int, Map<int, PuzzlePreset>> _presets = {
    1: {
      1: PuzzlePreset(
        mapNumber: 1,
        levelId: 1,
        difficulty: 1,
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
          // Ana rota A
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
          // Açılışta boş tüp seçimi ters sırayla
          [
            PuzzleMove(0, 10),
            PuzzleMove(1, 10),
            PuzzleMove(2, 9),
            PuzzleMove(3, 9),
            PuzzleMove(8, 1),
            PuzzleMove(6, 0),
            PuzzleMove(7, 6),
            PuzzleMove(4, 3),
          ],
          // Son iki hamlenin sırası değişse de kabul
          [
            PuzzleMove(2, 9),
            PuzzleMove(3, 9),
            PuzzleMove(0, 10),
            PuzzleMove(1, 10),
            PuzzleMove(8, 1),
            PuzzleMove(6, 0),
            PuzzleMove(4, 3),
            PuzzleMove(7, 6),
          ],
          // Hem açılış hem kapanış sıra farkı
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
        // jokerRecoveryMoves kasıtlı boş — buildRecoveryMap otomatik üretir.
      ),
      2: PuzzlePreset(
        mapNumber: 1,
        levelId: 2,
        difficulty: 2,
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
          // Ana rota A
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
          // Açılışın alternatifi
          [
            PuzzleMove(1, 8),
            PuzzleMove(0, 8),
            PuzzleMove(2, 0),
            PuzzleMove(4, 2),
            PuzzleMove(4, 0),
            PuzzleMove(0, 7),
            PuzzleMove(3, 0),
            PuzzleMove(2, 3),
            PuzzleMove(2, 7),
            PuzzleMove(3, 9),
            PuzzleMove(0, 3),
            PuzzleMove(1, 0),
            PuzzleMove(6, 0),
            PuzzleMove(6, 8),
            PuzzleMove(5, 1),
            PuzzleMove(5, 9),
            PuzzleMove(1, 5),
            PuzzleMove(4, 2),
            PuzzleMove(2, 6),
          ],
          // Geç oyunda 5->1 ile 5->9 yer değişebilir
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
            PuzzleMove(5, 9),
            PuzzleMove(5, 1),
            PuzzleMove(1, 5),
            PuzzleMove(4, 2),
            PuzzleMove(2, 6),
          ],
          // Açılış B + geç oyun varyasyonu
          [
            PuzzleMove(1, 8),
            PuzzleMove(0, 8),
            PuzzleMove(2, 0),
            PuzzleMove(4, 2),
            PuzzleMove(4, 0),
            PuzzleMove(0, 7),
            PuzzleMove(3, 0),
            PuzzleMove(2, 3),
            PuzzleMove(2, 7),
            PuzzleMove(3, 9),
            PuzzleMove(0, 3),
            PuzzleMove(1, 0),
            PuzzleMove(6, 0),
            PuzzleMove(6, 8),
            PuzzleMove(5, 9),
            PuzzleMove(5, 1),
            PuzzleMove(1, 5),
            PuzzleMove(4, 2),
            PuzzleMove(2, 6),
          ],
        ],
        // jokerRecoveryMoves kasıtlı boş — buildRecoveryMap otomatik üretir.
      ),
      3: PuzzlePreset(
        mapNumber: 1,
        levelId: 3,
        difficulty: 3,
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
          // Ana rota
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
          // Açılış varyasyonu
          [
            PuzzleMove(0, 9),
            PuzzleMove(6, 9),
            PuzzleMove(1, 8),
            PuzzleMove(0, 8),
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
          // Geç oyunda toplama sırası varyasyonu
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
            PuzzleMove(7, 2),
            PuzzleMove(5, 2),
            PuzzleMove(7, 6),
            PuzzleMove(5, 6),
            PuzzleMove(0, 7),
            PuzzleMove(1, 4),
            PuzzleMove(4, 5),
          ],
          // Açılış + geç oyun varyasyonu birlikte
          [
            PuzzleMove(0, 9),
            PuzzleMove(6, 9),
            PuzzleMove(1, 8),
            PuzzleMove(0, 8),
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
            PuzzleMove(7, 2),
            PuzzleMove(5, 2),
            PuzzleMove(7, 6),
            PuzzleMove(5, 6),
            PuzzleMove(0, 7),
            PuzzleMove(1, 4),
            PuzzleMove(4, 5),
          ],
        ],
        // jokerRecoveryMoves kasıtlı boş — buildRecoveryMap otomatik üretir.
      ),

      // ── Level 4 ve sonrası: solutionBranches yoksa joker generic moda geçer.
      //    Hazır olduğunda sadece solutionBranches ekle, geri kalan otomatik.
      4: PuzzlePreset(
        mapNumber: 1,
        levelId: 4,
        difficulty: 4,
        tubes: [
          [2, 1, 0, 0],
          [3, 3, 1, 0],
          [4, 2, 2, 1],
          [5, 4, 3, 1],
          [6, 5, 4, 2],
          [6, 6, 5, 3],
          [7, 7, 6, 4],
          [7, 5, 3, 2],
          [],
          [],
        ],
        layout: StageLayout.standardForTubeCount(10),
        lockedAdTubeIndex: 9,
        // solutionBranches eklendiğinde joker recovery otomatik çalışır.
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
