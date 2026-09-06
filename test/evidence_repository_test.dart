import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/map/evidence/evidence_cache.dart';
import 'package:pathgrain/map/evidence/evidence_repository.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/map/evidence/osm_evidence_provider.dart';

import 'support/evidence_fakes.dart';

void main() {
  const coordinates = [
    GeoCoordinate(1, 2),
    GeoCoordinate(0, 0),
    GeoCoordinate(-1, -2),
    GeoCoordinate(1, 2),
  ];
  final cells = GeographicCell.covering(coordinates);
  late OsmEvidence evidence;
  late MemoryEvidenceCache cache;
  final fetchedAt = DateTime.utc(2026, 9, 1);

  setUp(() {
    evidence = OsmEvidence.parse(evidenceFixture());
    cache = MemoryEvidenceCache();
  });

  test('canonical unique cell fetch, feature dedup, cache reuse, and manual refresh', () async {
    final provider = FakeEvidenceProvider((_) async => evidence);
    final repository = EvidenceRepository(
      provider: provider,
      cache: cache,
      now: () => fetchedAt,
    );
    final states = await repository.inspect(coordinates).toList();
    expect(provider.calls, cells);
    expect(states.first.phase, EvidencePhase.calculatingCells);
    expect(
      states.map((state) => state.phase),
      containsAll([
        EvidencePhase.readingCache,
        EvidencePhase.usingCache,
        EvidencePhase.fetching,
      ]),
    );
    expect(states.last.phase, EvidencePhase.loaded);
    expect(states.last.features, hasLength(evidence.features.length));
    expect(states.last.fetchedCells, cells.length);
    expect(states.last.oldestFetchedAt, fetchedAt);
    final reused = await repository.inspect(coordinates.reversed).last;
    expect(provider.calls, cells);
    expect(reused.cachedCells, cells.length);
    expect(reused.fetchedCells, 0);
    final refreshed = await repository.inspect(coordinates, refresh: true).last;
    expect(refreshed.fetchedCells, cells.length);
    expect(provider.calls, [...cells, ...cells]);
  });

  test('cache namespace prevents provider/query-version collisions', () async {
    final first = FakeEvidenceProvider((_) async => evidence);
    final second = FakeEvidenceProvider(
      (_) async => evidence,
      cacheNamespace: 'fixture-v2',
    );
    await EvidenceRepository(
      provider: first,
      cache: cache,
    ).inspect(coordinates).last;
    await EvidenceRepository(
      provider: second,
      cache: cache,
    ).inspect(coordinates).last;
    expect(second.calls, cells);
  });

  test('OSM identity includes type, and most recently fetched duplicate wins', () async {
    final old = OsmEvidence.parse(
      '{"elements":[{"type":"way","id":1,"tags":{"surface":"gravel"}},'
      '{"type":"node","id":1,"lat":1,"lon":2,"tags":{"highway":"crossing"}}]}',
    );
    final recent = OsmEvidence.parse(
      '{"elements":[{"type":"way","id":1,"tags":{"surface":"paving_stones"}}]}',
    );
    final provider = FakeEvidenceProvider((_) async => evidence);
    await cache.write(
      provider.cacheNamespace,
      cells.first,
      CachedEvidence(evidence: recent, fetchedAt: fetchedAt),
    );
    await cache.write(
      provider.cacheNamespace,
      cells.last,
      CachedEvidence(
        evidence: old,
        fetchedAt: fetchedAt.subtract(const Duration(days: 1)),
      ),
    );
    final result = await EvidenceRepository(
      provider: provider,
      cache: cache,
    ).inspect([coordinates.first, coordinates[2]]).last;
    expect(result.features, hasLength(2));
    expect(
      result.features
          .singleWhere((f) => f.type == OsmElementType.way)
          .tags['surface'],
      'paving_stones',
    );
  });

  test(
    'refresh failure preserves every cached cell, timestamp, and raw response',
    () async {
      final provider = FakeEvidenceProvider(
        (_) async => throw const EvidenceException(EvidenceFailure.offline),
      );
      final entry = CachedEvidence(evidence: evidence, fetchedAt: fetchedAt);
      for (final cell in cells) {
        await cache.write(provider.cacheNamespace, cell, entry);
      }
      final writes = cache.writes;
      final result = await EvidenceRepository(
        provider: provider,
        cache: cache,
      ).inspect(coordinates, refresh: true).last;
      expect(result.phase, EvidencePhase.partialFailure);
      expect(result.failure, EvidenceFailure.offline);
      expect(result.availableCells, cells.length);
      expect(result.failedCells, cells.length);
      expect(result.features, hasLength(evidence.features.length));
      expect(provider.calls, [cells.first]);
      expect(cache.writes, writes);
      for (final cell in cells) {
        expect(await cache.read(provider.cacheNamespace, cell), same(entry));
      }
    },
  );

  test('cache read precedes all fetching, and partial successes survive service failure', () async {
    var calls = 0;
    final provider = FakeEvidenceProvider((_) async {
      if (++calls == 2) {
        throw const EvidenceException(EvidenceFailure.unavailable);
      }
      return evidence;
    });
    final cached = CachedEvidence(evidence: evidence, fetchedAt: fetchedAt);
    await cache.write(provider.cacheNamespace, cells.last, cached);
    final states = await EvidenceRepository(
      provider: provider,
      cache: cache,
    ).inspect(coordinates).toList();
    final beforeNetwork = states.firstWhere(
      (s) => s.phase == EvidencePhase.usingCache,
    );
    expect(beforeNetwork.availableCells, 1);
    expect(states.last.phase, EvidencePhase.partialFailure);
    expect(states.last.availableCells, 2);
    expect(states.last.fetchedCells, 1);
    expect(states.last.cachedCells, 1);
    expect(states.last.failedCells, 1);
  });

  test('total failure stops the batch without retry; empty cells cache successfully', () async {
    final provider = FakeEvidenceProvider(
      (_) async => throw const EvidenceException(EvidenceFailure.rateLimited),
    );
    final failed = await EvidenceRepository(
      provider: provider,
      cache: cache,
    ).inspect(coordinates).last;
    expect(failed.phase, EvidencePhase.totalFailure);
    expect(failed.failedCells, cells.length);
    expect(provider.calls, hasLength(1));
    expect(cache.entries, isEmpty);
    final empty = FakeEvidenceProvider(
      (_) async => OsmEvidence.parse('{"elements": []}'),
    );
    final repository = EvidenceRepository(provider: empty, cache: cache);
    expect(
      (await repository.inspect(coordinates).last).phase,
      EvidencePhase.empty,
    );
    expect(
      (await repository.inspect(coordinates).last).cachedCells,
      cells.length,
    );
    expect(empty.calls, cells);
  });

  test(
    'cache failure does not discard downloaded evidence or affect source data',
    () async {
      cache.failRead = true;
      cache.failWrite = true;
      final provider = FakeEvidenceProvider((_) async => evidence);
      final result = await EvidenceRepository(
        provider: provider,
        cache: cache,
      ).inspect(coordinates).last;
      expect(result.phase, EvidencePhase.loaded);
      expect(result.features, hasLength(evidence.features.length));
      expect(result.cacheFailures, cells.length * 2);
    },
  );

  test(
    'cancelling inspection stops requests after the in-flight cell',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      final provider = FakeEvidenceProvider((_) async {
        started.complete();
        await finish.future;
        return evidence;
      });
      final stream = EvidenceRepository(
        provider: provider,
        cache: cache,
      ).inspect(coordinates);
      final subscription = stream.listen((_) {});
      await started.future;
      final cancelled = subscription.cancel();
      finish.complete();
      await cancelled;
      expect(provider.calls, hasLength(1));
      expect(cache.writes, 1);
    },
  );
}
