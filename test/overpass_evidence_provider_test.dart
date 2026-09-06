import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/map/evidence/evidence_settings.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence_provider.dart';
import 'package:pathgrain/map/evidence/overpass_evidence_provider.dart';

import 'support/evidence_fakes.dart';

void main() {
  const cell = GeographicCell(16384, 16384);

  test('query requests highway nodes/ways/relations and area:highway without surface filtering', () {
    final query = OverpassEvidenceProvider.queryForCell(cell);
    final bounds = cell.paddedBounds().single.overpass;
    expect(
      query,
      '[out:json][timeout:25][maxsize:16777216];\n'
      '(\nnwr["highway"]($bounds);\nway["area:highway"]($bounds);\n'
      'rel["area:highway"]($bounds);\n);\nout body geom;',
    );
    expect(query, isNot(contains('surface')));
    expect(query, isNot(contains('around')));
    expect(query, isNot(contains('poly:')));
    expect(query, isNot(contains('out meta')));
    expect(
      OverpassEvidenceProvider.queryForCell(const GeographicCell(0, 100)),
      contains('nwr["highway"]'),
    );
  });

  test(
    'request has only fixed bbox QL, static identity, and protocol headers',
    () async {
      final transport = FakeOverpassTransport(
        (_) async => const OverpassResponse(200, '{"elements": []}'),
      );
      final provider = OverpassEvidenceProvider(transport: transport);
      await provider.fetchCell(cell);
      final request = transport.requests.single;
      expect(request.endpoint.toString(), EvidenceSettings.endpoint);
      expect(request.endpoint.hasQuery, isFalse);
      expect(request.headers, {
        HttpHeaders.userAgentHeader: EvidenceSettings.userAgent,
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader:
            'application/x-www-form-urlencoded; charset=utf-8',
      });
      expect(Uri.splitQueryString(request.body), {
        'data': OverpassEvidenceProvider.queryForCell(cell),
      });
      for (final forbidden in [
        'walk',
        'timestamp',
        'recorded_at',
        'accuracy',
        'GeoJSON',
        'polyline',
        'user_id',
      ]) {
        expect(request.body, isNot(contains(forbidden)));
      }
      final alternative = OverpassEvidenceProvider(
        endpoint: Uri.parse('https://example.invalid/interpreter'),
      );
      expect(alternative.cacheNamespace, isNot(provider.cacheNamespace));
      expect(provider.cacheNamespace, contains(EvidenceSettings.queryVersion));
    },
  );

  test('requests from concurrent callers are serialized', () async {
    final firstStarted = Completer<void>();
    final finishFirst = Completer<void>();
    var active = 0;
    var maximumActive = 0;
    var calls = 0;
    final transport = FakeOverpassTransport((_) async {
      active++;
      if (active > maximumActive) maximumActive = active;
      calls++;
      if (calls == 1) {
        firstStarted.complete();
        await finishFirst.future;
      }
      active--;
      return const OverpassResponse(200, '{"elements": []}');
    });
    final provider = OverpassEvidenceProvider(
      transport: transport,
      requestInterval: Duration.zero,
    );
    final first = provider.fetchCell(cell);
    final second = provider.fetchCell(const GeographicCell(16385, 16384));
    await firstStarted.future;
    expect(calls, 1);
    finishFirst.complete();
    await Future.wait([first, second]);
    expect(calls, 2);
    expect(maximumActive, 1);
  });

  for (final status in [429, 406, 503, 504]) {
    test(
      'HTTP $status preserves a cooldown across manual attempts and honors Retry-After',
      () async {
        var now = DateTime.utc(2026, 9, 1);
        final transport = FakeOverpassTransport(
          (_) async => OverpassResponse(status, '', retryAfter: '120'),
        );
        final provider = OverpassEvidenceProvider(
          transport: transport,
          now: () => now,
          requestInterval: Duration.zero,
        );
        final failure = status == 429 || status == 406
            ? EvidenceFailure.rateLimited
            : EvidenceFailure.unavailable;
        final matcher = isA<EvidenceException>().having(
          (e) => e.failure,
          'failure',
          failure,
        );
        await expectLater(provider.fetchCell(cell), throwsA(matcher));
        now = now.add(const Duration(seconds: 31));
        await expectLater(provider.fetchCell(cell), throwsA(matcher));
        expect(transport.requests, hasLength(1));
        now = now.add(const Duration(seconds: 90));
        await expectLater(provider.fetchCell(cell), throwsA(matcher));
        expect(transport.requests, hasLength(2));
      },
    );
  }

  test('Retry-After longer than a day is not shortened', () async {
    var now = DateTime.utc(2026, 9, 1);
    final transport = FakeOverpassTransport(
      (_) async => const OverpassResponse(429, '', retryAfter: '259200'),
    );
    final provider = OverpassEvidenceProvider(
      transport: transport,
      now: () => now,
      requestInterval: Duration.zero,
    );
    await expectLater(
      provider.fetchCell(cell),
      throwsA(isA<EvidenceException>()),
    );
    now = now.add(const Duration(days: 2));
    await expectLater(
      provider.fetchCell(cell),
      throwsA(isA<EvidenceException>()),
    );
    expect(transport.requests, hasLength(1));
  });

  test(
    'HTTP-date Retry-After and minimum 30 second pause are supported',
    () async {
      var now = DateTime.utc(2026, 9, 1);
      final initial = now;
      final transport = FakeOverpassTransport(
        (_) async => OverpassResponse(
          429,
          '',
          retryAfter: HttpDate.format(initial.add(const Duration(minutes: 2))),
        ),
      );
      final provider = OverpassEvidenceProvider(
        transport: transport,
        now: () => now,
        requestInterval: Duration.zero,
      );
      await expectLater(
        provider.fetchCell(cell),
        throwsA(isA<EvidenceException>()),
      );
      now = now.add(const Duration(seconds: 119));
      await expectLater(
        provider.fetchCell(cell),
        throwsA(isA<EvidenceException>()),
      );
      expect(transport.requests, hasLength(1));

      final shortTransport = FakeOverpassTransport(
        (_) async => const OverpassResponse(406, '', retryAfter: '1'),
      );
      final shortProvider = OverpassEvidenceProvider(
        transport: shortTransport,
        now: () => now,
        requestInterval: Duration.zero,
      );
      await expectLater(
        shortProvider.fetchCell(cell),
        throwsA(isA<EvidenceException>()),
      );
      now = now.add(const Duration(seconds: 29));
      await expectLater(
        shortProvider.fetchCell(cell),
        throwsA(isA<EvidenceException>()),
      );
      expect(shortTransport.requests, hasLength(1));
    },
  );

  test(
    'HTTP-200 runtime error, invalid JSON, and transport failure are sanitized',
    () async {
      for (final body in [
        '{"elements": [], "remark": "Query timed out"}',
        '<html>unavailable</html>',
      ]) {
        final transport = FakeOverpassTransport(
          (_) async => OverpassResponse(200, body),
        );
        final provider = OverpassEvidenceProvider(transport: transport);
        await expectLater(
          provider.fetchCell(cell),
          throwsA(
            isA<EvidenceException>().having(
              (e) => e.failure,
              'failure',
              EvidenceFailure.invalidResponse,
            ),
          ),
        );
      }
      for (final failure in [
        EvidenceFailure.offline,
        EvidenceFailure.timeout,
        EvidenceFailure.responseTooLarge,
      ]) {
        final transport = FakeOverpassTransport(
          (_) async => throw EvidenceException(failure),
        );
        final provider = OverpassEvidenceProvider(transport: transport);
        await expectLater(
          provider.fetchCell(cell),
          throwsA(
            isA<EvidenceException>().having(
              (e) => e.failure,
              'failure',
              failure,
            ),
          ),
        );
        expect(transport.requests, hasLength(1));
      }
    },
  );
}
