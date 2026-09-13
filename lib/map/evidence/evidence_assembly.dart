import 'geographic_cell.dart';
import 'osm_evidence.dart';

class CachedEvidence {
  const CachedEvidence({required this.evidence, required this.fetchedAt});

  final OsmEvidence evidence;
  final DateTime fetchedAt;
}

/// Shared by cache-backed inspection and fixed-input replay. No I/O.
class EvidenceAssembly {
  EvidenceAssembly(Map<GeographicCell, CachedEvidence> cells) {
    final ordered = cells.entries.toList()
      ..sort((a, b) {
        final order = a.value.fetchedAt.compareTo(b.value.fetchedAt);
        return order != 0 ? order : a.key.compareTo(b.key);
      });
    final byKey = <String, OsmFeature>{};
    var unparsed = 0;
    var occurrences = 0;
    for (final entry in ordered) {
      for (final feature in entry.value.evidence.features) {
        // Newest fetched cell wins; numeric cell order breaks equal-time ties.
        byKey[feature.key] = feature;
        occurrences++;
      }
      unparsed += entry.value.evidence.unparsedElements;
    }
    features = List.unmodifiable(
      byKey.values.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    unparsedElements = unparsed;
    featureOccurrences = occurrences;
    oldestFetchedAt = ordered.firstOrNull?.value.fetchedAt;
    newestFetchedAt = ordered.lastOrNull?.value.fetchedAt;
  }

  late final List<OsmFeature> features;
  late final int unparsedElements;
  late final int featureOccurrences;
  late final DateTime? oldestFetchedAt;
  late final DateTime? newestFetchedAt;
  int get duplicateOccurrences => featureOccurrences - features.length;
}

/// Shared all-cell gate for a terminal replay or an in-flight UI snapshot.
bool evidenceCoverageIsComplete({
  required int totalCells,
  required int availableCells,
  required int unparsedElements,
  bool isLoading = false,
}) =>
    !isLoading &&
    totalCells > 0 &&
    availableCells == totalCells &&
    unparsedElements == 0;
