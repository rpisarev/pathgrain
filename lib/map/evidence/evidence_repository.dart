import 'evidence_assembly.dart';
import 'evidence_cache.dart';
import 'geographic_cell.dart';
import 'osm_evidence.dart';
import 'osm_evidence_provider.dart';

enum EvidencePhase {
  calculatingCells,
  readingCache,
  usingCache,
  fetching,
  refreshing,
  loaded,
  empty,
  partialFailure,
  totalFailure,
}

class EvidenceSnapshot {
  const EvidenceSnapshot({
    required this.phase,
    this.totalCells = 0,
    this.availableCells = 0,
    this.cachedCells = 0,
    this.fetchedCells = 0,
    this.failedCells = 0,
    this.cacheFailures = 0,
    this.features = const [],
    this.unparsedElements = 0,
    this.oldestFetchedAt,
    this.newestFetchedAt,
    this.failure,
  });

  final EvidencePhase phase;
  final int totalCells;
  final int availableCells;
  final int cachedCells;
  final int fetchedCells;
  final int failedCells;
  final int cacheFailures;
  final List<OsmFeature> features;
  final int unparsedElements;
  final DateTime? oldestFetchedAt;
  final DateTime? newestFetchedAt;
  final EvidenceFailure? failure;

  /// The same conservative all-cell gate for both review and debug analysis.
  bool get hasCompleteCoverage => evidenceCoverageIsComplete(
    isLoading: isLoading,
    totalCells: totalCells,
    availableCells: availableCells,
    unparsedElements: unparsedElements,
  );

  bool get isLoading => switch (phase) {
    EvidencePhase.loaded ||
    EvidencePhase.empty ||
    EvidencePhase.partialFailure ||
    EvidencePhase.totalFailure => false,
    _ => true,
  };
}

class EvidenceRepository {
  EvidenceRepository({
    required this.provider,
    required this.cache,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final OsmEvidenceProvider provider;
  final EvidenceCache cache;
  final DateTime Function() _now;

  /// No walk identity or timestamps cross this boundary. Cancellation of the
  /// stream stops subsequent requests; an in-flight cell may finish and cache.
  Stream<EvidenceSnapshot> inspect(
    Iterable<GeoCoordinate> coordinates, {
    bool refresh = false,
  }) async* {
    yield EvidenceSnapshot(
      phase: refresh
          ? EvidencePhase.refreshing
          : EvidencePhase.calculatingCells,
    );
    final cells = GeographicCell.covering(coordinates);
    final entries = <GeographicCell, CachedEvidence>{};
    final fetched = <GeographicCell>{};
    var failed = 0;
    var cacheFailures = 0;
    EvidenceFailure? failure;

    EvidenceSnapshot snapshot(EvidencePhase phase) {
      final assembly = EvidenceAssembly(entries);
      return EvidenceSnapshot(
        phase: phase,
        totalCells: cells.length,
        availableCells: entries.length,
        cachedCells: entries.length - fetched.length,
        fetchedCells: fetched.length,
        failedCells: failed,
        cacheFailures: cacheFailures,
        features: assembly.features,
        unparsedElements: assembly.unparsedElements,
        oldestFetchedAt: assembly.oldestFetchedAt,
        newestFetchedAt: assembly.newestFetchedAt,
        failure: failure,
      );
    }

    yield snapshot(EvidencePhase.readingCache);
    // Read every cell before networking, so cached evidence remains available
    // even when the first network request fails or is throttled.
    for (final cell in cells) {
      try {
        final entry = await cache.read(provider.cacheNamespace, cell);
        if (entry != null) entries[cell] = entry;
      } catch (_) {
        cacheFailures++;
      }
    }
    yield snapshot(EvidencePhase.usingCache);
    for (final cell in cells) {
      if (!refresh && entries.containsKey(cell)) continue;
      if (failure != null) {
        // Stop the network batch on failure. No retry loop, including for
        // other cells when a public provider is overloaded or offline.
        failed++;
        continue;
      }
      yield snapshot(EvidencePhase.fetching);
      try {
        final evidence = await provider.fetchCell(cell);
        final entry = CachedEvidence(
          evidence: evidence,
          fetchedAt: _now().toUtc(),
        );
        entries[cell] = entry;
        fetched.add(cell);
        try {
          await cache.write(provider.cacheNamespace, cell, entry);
        } catch (_) {
          cacheFailures++;
        }
      } on EvidenceException catch (error) {
        failed++;
        failure = error.failure;
      } catch (_) {
        failed++;
        failure = EvidenceFailure.unavailable;
      }
    }
    final phase = failed > 0
        ? (entries.isEmpty
              ? EvidencePhase.totalFailure
              : EvidencePhase.partialFailure)
        : (entries.values.every((entry) => entry.evidence.features.isEmpty)
              ? EvidencePhase.empty
              : EvidencePhase.loaded);
    yield snapshot(phase);
  }
}
