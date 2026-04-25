import 'dart:math';

import 'puzzle_presets.dart';

enum DailyPuzzleMapStyle {
  map1,
  map2,
  map3,
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
  final int? mountainCapacity;
  final List<int>? refillTubeIndexes;
  final Map<int, List<List<int>>>? refillQueues;
  final bool stopRefillWhenMountainFull;

  const DailyPuzzleData({
    required this.dateKey,
    required this.seed,
    required this.mapStyle,
    required this.mapNumber,
    required this.difficulty,
    required this.tubes,
    required this.lockedAdTubeIndex,
    required this.layout,
    this.mountainCapacity,
    this.refillTubeIndexes,
    this.refillQueues,
    this.stopRefillWhenMountainFull = false,
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
    int? mountainCapacity,
    List<int>? refillTubeIndexes,
    Map<int, List<List<int>>>? refillQueues,
    bool? stopRefillWhenMountainFull,
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
      mountainCapacity: mountainCapacity ?? this.mountainCapacity,
      refillTubeIndexes: refillTubeIndexes ?? this.refillTubeIndexes,
      refillQueues: refillQueues ?? this.refillQueues,
      stopRefillWhenMountainFull:
          stopRefillWhenMountainFull ?? this.stopRefillWhenMountainFull,
    );
  }
}

class DailyPuzzleGenerator {
  static DailyPuzzleData generateForDate(DateTime date) {
    final local = date.toLocal();
    final dateKey = _dateKey(local);
    final seed = int.parse(dateKey);
    final rng = Random(seed);

    final mapStyle = _pickMapStyle(seed);
    final mapNumber = _mapNumberOf(mapStyle);
    final levelId = _pickLevelId(
      seed: seed,
      mapNumber: mapNumber,
    );

    final preset = PuzzlePresets.get(
      mapNumber: mapNumber,
      levelId: levelId,
    );

    return _buildFromPreset(
      dateKey: dateKey,
      seed: seed,
      rng: rng,
      mapStyle: mapStyle,
      preset: preset,
    );
  }

  static String dateKeyOf(DateTime date) => _dateKey(date.toLocal());

  static DailyPuzzleMapStyle _pickMapStyle(int seed) {
    if (seed % 5 == 0) return DailyPuzzleMapStyle.map3;
    if (seed % 3 == 0) return DailyPuzzleMapStyle.map2;
    return DailyPuzzleMapStyle.map1;
  }

  static int _mapNumberOf(DailyPuzzleMapStyle style) {
    switch (style) {
      case DailyPuzzleMapStyle.map1:
        return 1;
      case DailyPuzzleMapStyle.map2:
        return 2;
      case DailyPuzzleMapStyle.map3:
        return 3;
    }
  }

  static int _levelCountForMap(int mapNumber) {
    switch (mapNumber) {
      case 1:
        return 10;
      case 2:
        return 12;
      case 3:
        return 14;
      default:
        return 1;
    }
  }

  static int _pickLevelId({
    required int seed,
    required int mapNumber,
  }) {
    final levelCount = _levelCountForMap(mapNumber);
    final mixedSeed = seed + (mapNumber * 9973);
    return (mixedSeed % levelCount) + 1;
  }

  static DailyPuzzleData _buildFromPreset({
    required String dateKey,
    required int seed,
    required Random rng,
    required DailyPuzzleMapStyle mapStyle,
    required PuzzlePreset preset,
  }) {
    final colorMap = _buildColorMapFromPreset(
      preset: preset,
      rng: rng,
    );

    var tubes = _cloneAndRecolorTubes(
      preset.tubes,
      colorMap,
    );

    Map<int, List<List<int>>>? refillQueues;
    if (preset.sourceRefill != null) {
      refillQueues = _cloneAndRecolorRefillQueues(
        preset.sourceRefill!.refillQueues,
        colorMap,
      );
    }

    // Map 1 ve Map 2'de sadece dolu tüplerin yerini karıştırıyoruz.
    // Boş tüpler yine sonda kalıyor, reklam tüpü en son index olarak korunuyor.
    // Map 3'te tüp sırası karıştırılmıyor; çünkü sourceRefill.tubeIndexes
    // volkan/lav kaynak tüplerine index üzerinden bağlı.
    if (mapStyle != DailyPuzzleMapStyle.map3) {
      tubes = _shuffleFilledTubesKeepingEmptyAndAdLast(
        tubes: tubes,
        rng: rng,
      );
    }

    return DailyPuzzleData(
      dateKey: dateKey,
      seed: seed,
      mapStyle: mapStyle,
      mapNumber: preset.mapNumber,
      difficulty: preset.difficulty.clamp(1, 5),
      tubes: tubes,
      lockedAdTubeIndex: tubes.length - 1,
      layout: preset.layout,
      mountainCapacity: preset.mountainCapacity,
      refillTubeIndexes: preset.sourceRefill == null
          ? null
          : List<int>.from(preset.sourceRefill!.tubeIndexes),
      refillQueues: refillQueues,
      stopRefillWhenMountainFull:
          preset.sourceRefill?.stopWhenMountainFull ?? false,
    );
  }

  static Map<int, int> _buildColorMapFromPreset({
    required PuzzlePreset preset,
    required Random rng,
  }) {
    final usedColors = <int>{};

    for (final tube in preset.tubes) {
      for (final color in tube) {
        if (color != kLavaColorIndex) {
          usedColors.add(color);
        }
      }
    }

    final sourceRefill = preset.sourceRefill;
    if (sourceRefill != null) {
      for (final queues in sourceRefill.refillQueues.values) {
        for (final refillTube in queues) {
          for (final color in refillTube) {
            if (color != kLavaColorIndex) {
              usedColors.add(color);
            }
          }
        }
      }
    }

    final originalColors = usedColors.toList(growable: false)..sort();
    final shuffledColors = List<int>.from(originalColors)..shuffle(rng);

    // Güvenlik: 16 lav rengidir. Asla normal renk mapping içine girmez.
    shuffledColors.remove(kLavaColorIndex);

    final map = <int, int>{};
    for (int i = 0; i < originalColors.length; i++) {
      final from = originalColors[i];
      if (from == kLavaColorIndex) continue;
      map[from] = shuffledColors[i % shuffledColors.length];
    }

    return map;
  }

  static List<List<int>> _cloneAndRecolorTubes(
    List<List<int>> source,
    Map<int, int> colorMap,
  ) {
    return source.map((tube) {
      return tube.map((color) {
        if (color == kLavaColorIndex) return kLavaColorIndex;
        return colorMap[color] ?? color;
      }).toList(growable: true);
    }).toList(growable: true);
  }

  static Map<int, List<List<int>>> _cloneAndRecolorRefillQueues(
    Map<int, List<List<int>>> source,
    Map<int, int> colorMap,
  ) {
    final result = <int, List<List<int>>>{};

    source.forEach((tubeIndex, queues) {
      result[tubeIndex] = queues.map((refillTube) {
        return refillTube.map((color) {
          if (color == kLavaColorIndex) return kLavaColorIndex;
          return colorMap[color] ?? color;
        }).toList(growable: true);
      }).toList(growable: true);
    });

    return result;
  }

  static List<List<int>> _shuffleFilledTubesKeepingEmptyAndAdLast({
    required List<List<int>> tubes,
    required Random rng,
  }) {
    final cloned = tubes.map((t) => List<int>.from(t)).toList(growable: true);
    if (cloned.isEmpty) return cloned;

    final lockedAdTube = cloned.removeLast();
    final filledTubes = <List<int>>[];
    final emptyTubes = <List<int>>[];

    for (final tube in cloned) {
      if (tube.isEmpty) {
        emptyTubes.add(tube);
      } else {
        filledTubes.add(tube);
      }
    }

    filledTubes.shuffle(rng);

    return <List<int>>[
      ...filledTubes,
      ...emptyTubes,
      lockedAdTube,
    ];
  }

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
