import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pathgrain/map/evidence/evidence_cache.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/evidence_fakes.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('separate disposable cache retains raw evidence, timestamps, and namespaces after reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pathgrain_evidence_cache_test.',
    );
    final databasePath = path.join(
      directory.path,
      SqliteEvidenceCache.fileName,
    );
    var cache = SqliteEvidenceCache(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(() async {
      await cache.close();
      await directory.delete(recursive: true);
    });
    const cell = GeographicCell(100, 200);
    final entry = CachedEvidence(
      evidence: OsmEvidence.parse(evidenceFixture()),
      fetchedAt: DateTime.utc(2026, 9, 1),
    );
    await cache.write('provider-v1', cell, entry);
    await cache.close();
    cache = SqliteEvidenceCache(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    final reopened = (await cache.read('provider-v1', cell))!;
    expect(reopened.evidence.raw, entry.evidence.raw);
    expect(reopened.fetchedAt, entry.fetchedAt);
    expect(await cache.read('provider-v2', cell), isNull);
    expect(
      await cache.read('provider-v1', const GeographicCell(101, 200)),
      isNull,
    );
    final refreshed = CachedEvidence(
      evidence: OsmEvidence.parse('{"elements": []}'),
      fetchedAt: entry.fetchedAt.add(const Duration(days: 1)),
    );
    await cache.write('provider-v1', cell, refreshed);
    expect(
      (await cache.read('provider-v1', cell))!.fetchedAt,
      refreshed.fetchedAt,
    );
    expect((await cache.read('provider-v1', cell))!.evidence.features, isEmpty);
    final database = await databaseFactoryFfi.openDatabase(databasePath);
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(tables.map((row) => row['name']), isNot(contains('walks')));
    expect(tables.map((row) => row['name']), isNot(contains('walk_points')));
    await database.close();
  });
}
