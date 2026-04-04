import 'dart:math';

import 'puzzle_presets.dart';

enum DailyPuzzleMapStyle {
  map1,
  map2,
}

class DailyPuzzleData {
  final String dateKey;
  final int seed;
  final DailyPuzzleMapStyle mapStyle;
  final int mapNumber;
  final int difficulty;
  final List<List<int>> tubes;
  final int lockedAdTubeIndex;
  final StageLayout layout;

  const DailyPuzzleData({
    required this.dateKey,
    required this.seed,
    required this.mapStyle,
    required this.mapNumber,
    required this.difficulty,
    required this.tubes,
    required this.lockedAdTubeIndex,
    required this.layout,
  });

  DailyPuzzleData copyWith({
    String? dateKey,
    int? seed,
    DailyPuzzleMapStyle? mapStyle,
    int? mapNumber,
    int? difficulty,
    List<List<int>>? tubes,
    int? lockedAdTubeIndex,
    StageLayout? layout,
  }) {
    return DailyPuzzleData(
      dateKey: dateKey ?? this.dateKey,
      seed: seed ?? this.seed,
      mapStyle: mapStyle ?? this.mapStyle,
      mapNumber: mapNumber ?? this.mapNumber,
      difficulty: difficulty ?? this.difficulty,
      tubes: tubes ?? this.tubes,
      lockedAdTubeIndex: lockedAdTubeIndex ?? this.lockedAdTubeIndex,
      layout: layout ?? this.layout,
    );
  }
}

class DailyPuzzleGenerator {
  static const int _tubeCapacity = 4;
  static const int _emptyTubeCount = 2;
  static const int _lockedAdTubeCount = 1;
  static const int _maxColorIndexExclusive = 18; // game_page.dart ile uyumlu

  static DailyPuzzleData generateForDate(DateTime date) {
    final local = date.toLocal();
    final dateKey = _dateKey(local);
    final seed = int.parse(dateKey);
    final rng = Random(seed);

    final mapStyle = _pickMapStyle(seed);
    final mapNumber = mapStyle == DailyPuzzleMapStyle.map2 ? 2 : 1;
    final difficulty = _pickDifficulty(seed, mapStyle);

    final colorCount = _pickColorCount(difficulty, mapStyle);
    final filledTubeCount = colorCount;
    final totalTubeCount =
        filledTubeCount + _emptyTubeCount + _lockedAdTubeCount;
    final lockedAdTubeIndex = totalTubeCount - 1;

    final palette = _pickColorPalette(
      rng: rng,
      colorCount: colorCount,
      maxExclusive: _maxColorIndexExclusive,
    );

    List<List<int>> tubes = const [];
    int attempt = 0;

    while (attempt < 2000) {
      attempt++;

      final candidate = _buildCandidateTubes(
        rng: Random(seed + attempt * 97),
        palette: palette,
        filledTubeCount: filledTubeCount,
      );

      candidate.add(<int>[]);
      candidate.add(<int>[]);
      candidate.add(<int>[]);

      if (_isAcceptableStart(candidate, filledTubeCount: filledTubeCount)) {
        tubes = candidate;
        break;
      }
    }

    if (tubes.isEmpty) {
      // Güvenli fallback
      tubes = _buildFallbackTubes(
        palette: palette,
        filledTubeCount: filledTubeCount,
      );
      tubes.add(<int>[]);
      tubes.add(<int>[]);
      tubes.add(<int>[]);
    }

    return DailyPuzzleData(
      dateKey: dateKey,
      seed: seed,
      mapStyle: mapStyle,
      mapNumber: mapNumber,
      difficulty: difficulty,
      tubes: tubes,
      lockedAdTubeIndex: lockedAdTubeIndex,
      layout: _buildLayout(totalTubeCount),
    );
  }

  static String dateKeyOf(DateTime date) => _dateKey(date.toLocal());

  static DailyPuzzleMapStyle _pickMapStyle(int seed) {
    // Bazı günler map1, bazı günler map2.
    // Aynı tarihte herkes aynı sonucu alır.
    // İstersen sonra oranı değiştiririz.
    return (seed % 3 == 0)
        ? DailyPuzzleMapStyle.map2
        : DailyPuzzleMapStyle.map1;
  }

  static int _pickDifficulty(int seed, DailyPuzzleMapStyle style) {
    if (style == DailyPuzzleMapStyle.map2) {
      // kapalı sıvı günleri biraz daha zor
      const options = [3, 4, 4, 5];
      return options[seed % options.length];
    }

    const options = [2, 3, 3, 4, 4];
    return options[seed % options.length];
  }

  static int _pickColorCount(int difficulty, DailyPuzzleMapStyle style) {
    if (style == DailyPuzzleMapStyle.map2) {
      switch (difficulty) {
        case 3:
          return 10;
        case 4:
          return 11;
        case 5:
          return 12;
        default:
          return 11;
      }
    }

    switch (difficulty) {
      case 2:
        return 9;
      case 3:
        return 10;
      case 4:
        return 11;
      case 5:
        return 12;
      default:
        return 10;
    }
  }

  static List<int> _pickColorPalette({
    required Random rng,
    required int colorCount,
    required int maxExclusive,
  }) {
    final all = List<int>.generate(maxExclusive, (i) => i)..shuffle(rng);
    return all.take(colorCount).toList(growable: false);
  }

  static List<List<int>> _buildCandidateTubes({
    required Random rng,
    required List<int> palette,
    required int filledTubeCount,
  }) {
    final pieces = <int>[];
    for (final color in palette) {
      pieces.addAll([color, color, color, color]);
    }

    // Amaç:
    // - her dolu tüp 4 katman olsun
    // - başlangıçta yan yana aynı renk gelmesin
    // - dağılım karışık olsun
    final tubes = List<List<int>>.generate(
      filledTubeCount,
      (_) => <int>[],
      growable: true,
    );

    final shuffled = List<int>.from(pieces)..shuffle(rng);

    bool placedAll = _fillGreedyNoAdjacent(
      rng: rng,
      shuffled: shuffled,
      tubes: tubes,
    );

    if (!placedAll) {
      // Alternatif kurulum
      final counts = <int, int>{for (final c in palette) c: 4};
      for (final t in tubes) {
        t.clear();
      }

      for (int layer = 0; layer < _tubeCapacity; layer++) {
        for (int tubeIndex = 0; tubeIndex < filledTubeCount; tubeIndex++) {
          final candidates = counts.entries
              .where((e) => e.value > 0)
              .map((e) => e.key)
              .where((color) {
            final tube = tubes[tubeIndex];
            if (tube.isEmpty) return true;
            return tube.last != color;
          }).toList();

          if (candidates.isEmpty) {
            return _buildSimpleMixedTubes(
              rng: rng,
              palette: palette,
              filledTubeCount: filledTubeCount,
            );
          }

          candidates.shuffle(rng);
          final chosen = candidates.first;
          tubes[tubeIndex].add(chosen);
          counts[chosen] = counts[chosen]! - 1;
        }
      }
    }

    return tubes;
  }

  static bool _fillGreedyNoAdjacent({
    required Random rng,
    required List<int> shuffled,
    required List<List<int>> tubes,
  }) {
    for (final color in shuffled) {
      final available = <int>[];

      for (int i = 0; i < tubes.length; i++) {
        final tube = tubes[i];
        if (tube.length >= _tubeCapacity) continue;
        if (tube.isNotEmpty && tube.last == color) continue;
        available.add(i);
      }

      if (available.isEmpty) {
        return false;
      }

      // Daha az dolu tüpleri öne al
      available.sort((a, b) => tubes[a].length.compareTo(tubes[b].length));

      final shortestLen = tubes[available.first].length;
      final shortest = available
          .where((i) => tubes[i].length == shortestLen)
          .toList(growable: false)
        ..shuffle(rng);

      tubes[shortest.first].add(color);
    }

    return tubes.every((t) => t.length == _tubeCapacity);
  }

  static List<List<int>> _buildSimpleMixedTubes({
    required Random rng,
    required List<int> palette,
    required int filledTubeCount,
  }) {
    final values = <int>[];
    for (final c in palette) {
      values.addAll([c, c, c, c]);
    }

    while (true) {
      final shuffled = List<int>.from(values)..shuffle(rng);
      final tubes = List<List<int>>.generate(
        filledTubeCount,
        (i) => shuffled.skip(i * 4).take(4).toList(growable: true),
        growable: true,
      );

      bool ok = true;
      for (final t in tubes) {
        for (int i = 0; i < t.length - 1; i++) {
          if (t[i] == t[i + 1]) {
            ok = false;
            break;
          }
        }
        if (!ok) break;
      }

      if (ok) return tubes;
    }
  }

  static List<List<int>> _buildFallbackTubes({
    required List<int> palette,
    required int filledTubeCount,
  }) {
    final values = <int>[];
    for (final c in palette) {
      values.addAll([c, c, c, c]);
    }

    final tubes = List<List<int>>.generate(
      filledTubeCount,
      (_) => <int>[],
      growable: true,
    );

    int cursor = 0;
    for (int layer = 0; layer < _tubeCapacity; layer++) {
      for (int i = 0; i < filledTubeCount; i++) {
        tubes[i].add(values[cursor++]);
      }
    }

    return tubes;
  }

  static bool _isAcceptableStart(
    List<List<int>> tubes, {
    required int filledTubeCount,
  }) {
    // Dolu tüpler gerçekten dolu mu?
    for (int i = 0; i < filledTubeCount; i++) {
      final t = tubes[i];
      if (t.length != _tubeCapacity) return false;

      // Başlangıçta yan yana aynı renk istemiyoruz
      for (int j = 0; j < t.length - 1; j++) {
        if (t[j] == t[j + 1]) return false;
      }
    }

    // Her renk tam 4 adet mi?
    final counts = <int, int>{};
    for (final t in tubes) {
      for (final c in t) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }

    if (counts.values.any((v) => v != 4)) return false;

    // Açılışta en az birkaç legal hamle olsun
    int legalMoveCount = 0;
    for (int from = 0; from < tubes.length; from++) {
      for (int to = 0; to < tubes.length; to++) {
        if (from == to) continue;
        if (_canPour(tubes, from, to)) {
          legalMoveCount++;
        }
      }
    }

    if (legalMoveCount < 3) return false;

    return true;
  }

  static bool _canPour(List<List<int>> tubes, int from, int to) {
    if (tubes[from].isEmpty) return false;
    if (tubes[to].length >= _tubeCapacity) return false;

    final top = tubes[from].last;
    if (tubes[to].isNotEmpty && tubes[to].last != top) return false;

    return true;
  }

  static StageLayout _buildLayout(int totalTubeCount) {
    final indices = List<int>.generate(totalTubeCount, (i) => i);

    if (totalTubeCount <= 12) {
      return StageLayout.rows(
        rows: [
          indices.take(4).toList(),
          indices.skip(4).take(4).toList(),
          indices.skip(8).toList(),
        ],
        rowTopPaddings: const [0, 0, 4],
      );
    }

    if (totalTubeCount <= 15) {
      return StageLayout.rows(
        rows: [
          indices.take(4).toList(),
          indices.skip(4).take(5).toList(),
          indices.skip(9).take(3).toList(),
          indices.skip(12).toList(),
        ],
        rowTopPaddings: const [0, 0, 4, 4],
      );
    }

    if (totalTubeCount <= 18) {
      return StageLayout.rows(
        rows: [
          indices.take(4).toList(),
          indices.skip(4).take(5).toList(),
          indices.skip(9).take(4).toList(),
          indices.skip(13).toList(),
        ],
        rowTopPaddings: const [0, 0, 4, 4],
      );
    }

    return StageLayout.standardForTubeCount(totalTubeCount);
  }

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
