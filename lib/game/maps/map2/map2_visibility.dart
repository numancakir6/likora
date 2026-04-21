import 'dart:math';

class BlindVisibilityUpdateResult {
  final List<int> visibleLayerCounts;
  final bool shouldRevealFromSource;

  const BlindVisibilityUpdateResult({
    required this.visibleLayerCounts,
    required this.shouldRevealFromSource,
  });
}

bool isBlindModeForMap(int mapNumber) => mapNumber == 2;

List<int> defaultVisibleLayerCountsFor({
  required bool blindModeEnabled,
  required List<List<int>> tubes,
}) {
  if (!blindModeEnabled) {
    return List<int>.generate(
      tubes.length,
      (i) => tubes[i].length,
      growable: true,
    );
  }

  return List<int>.generate(
    tubes.length,
    (i) => tubes[i].isEmpty ? 0 : 1,
    growable: true,
  );
}

List<int> normalizeVisibleLayerCounts(
  List<int>? raw,
  List<List<int>> tubes, {
  required bool blindModeEnabled,
}) {
  final fallback = defaultVisibleLayerCountsFor(
    blindModeEnabled: blindModeEnabled,
    tubes: tubes,
  );

  if (raw == null || raw.length != tubes.length) return fallback;

  return List<int>.generate(
    tubes.length,
    (i) => raw[i].clamp(0, tubes[i].length).toInt(),
    growable: true,
  );
}

BlindVisibilityUpdateResult updateBlindVisibilityAfterPour({
  required bool blindModeEnabled,
  required List<int> visibleLayerCounts,
  required List<List<int>> tubes,
  required int from,
  required int to,
  required int pouredCount,
}) {
  if (!blindModeEnabled) {
    return BlindVisibilityUpdateResult(
      visibleLayerCounts: List<int>.from(visibleLayerCounts, growable: true),
      shouldRevealFromSource: false,
    );
  }

  final nextVisible = List<int>.from(visibleLayerCounts, growable: true);

  final oldFromVisible =
      nextVisible[from].clamp(0, tubes[from].length + pouredCount).toInt();
  final oldToVisible =
      nextVisible[to].clamp(0, max(0, tubes[to].length - pouredCount)).toInt();

  final newFromLen = tubes[from].length;
  final newToLen = tubes[to].length;

  final removedVisible = min(oldFromVisible, pouredCount);
  var newFromVisible = max(0, oldFromVisible - removedVisible);

  final removedHiddenAbove = pouredCount > removedVisible;
  final shouldRevealNextTop =
      newFromLen > 0 && (newFromVisible == 0 || removedHiddenAbove);

  if (shouldRevealNextTop) {
    newFromVisible = min(newFromLen, newFromVisible + 1);
  }

  nextVisible[from] = newFromVisible.clamp(0, newFromLen).toInt();

  // Hedef tüpe dökülen sıvı görünür olarak eklenir.
  // Altındaki eski gizli katmanları açmadan sadece dökülen kadar görünürlük artar.
  nextVisible[to] = (oldToVisible + pouredCount).clamp(0, newToLen);

  return BlindVisibilityUpdateResult(
    visibleLayerCounts: nextVisible,
    shouldRevealFromSource: shouldRevealNextTop,
  );
}

BlindVisibilityUpdateResult updateBlindVisibilityAfterMountainPour({
  required bool blindModeEnabled,
  required List<int> visibleLayerCounts,
  required List<List<int>> tubes,
  required int from,
  required int pouredCount,
}) {
  if (!blindModeEnabled) {
    return BlindVisibilityUpdateResult(
      visibleLayerCounts: List<int>.from(visibleLayerCounts, growable: true),
      shouldRevealFromSource: false,
    );
  }

  final nextVisible = List<int>.from(visibleLayerCounts, growable: true);

  final oldFromVisible =
      nextVisible[from].clamp(0, tubes[from].length + pouredCount).toInt();
  final newFromLen = tubes[from].length;

  final removedVisible = min(oldFromVisible, pouredCount);
  var newFromVisible = max(0, oldFromVisible - removedVisible);

  final removedHiddenAbove = pouredCount > removedVisible;
  final shouldRevealNextTop =
      newFromLen > 0 && (newFromVisible == 0 || removedHiddenAbove);

  if (shouldRevealNextTop) {
    newFromVisible = min(newFromLen, newFromVisible + 1);
  }

  nextVisible[from] = newFromVisible.clamp(0, newFromLen).toInt();

  return BlindVisibilityUpdateResult(
    visibleLayerCounts: nextVisible,
    shouldRevealFromSource: shouldRevealNextTop,
  );
}
