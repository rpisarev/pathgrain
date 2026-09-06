import 'dart:io';

import 'package:pathgrain/map/evidence/evidence_cache.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/map/evidence/osm_evidence_provider.dart';
import 'package:pathgrain/map/evidence/overpass_evidence_provider.dart';

String evidenceFixture() =>
    File('test/fixtures/osm_evidence.json').readAsStringSync();

class MemoryEvidenceCache implements EvidenceCache {
  final entries = <String, CachedEvidence>{};
  int writes = 0;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<CachedEvidence?> read(String namespace, GeographicCell cell) async {
    if (failRead) throw StateError('Synthetic cache read failure');
    return entries['$namespace|${cell.key}'];
  }

  @override
  Future<void> write(
    String namespace,
    GeographicCell cell,
    CachedEvidence entry,
  ) async {
    if (failWrite) throw StateError('Synthetic cache write failure');
    writes++;
    entries['$namespace|${cell.key}'] = entry;
  }
}

class FakeEvidenceProvider implements OsmEvidenceProvider {
  FakeEvidenceProvider(this.fetch, {this.cacheNamespace = 'fixture-v1'});

  final Future<OsmEvidence> Function(GeographicCell cell) fetch;
  final calls = <GeographicCell>[];
  @override
  final String cacheNamespace;

  @override
  Future<OsmEvidence> fetchCell(GeographicCell cell) {
    calls.add(cell);
    return fetch(cell);
  }
}

class FakeOverpassTransport implements OverpassTransport {
  FakeOverpassTransport(this.respond);

  final Future<OverpassResponse> Function(OverpassRequest request) respond;
  final requests = <OverpassRequest>[];

  @override
  Future<OverpassResponse> send(OverpassRequest request) {
    requests.add(request);
    return respond(request);
  }
}
