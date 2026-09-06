import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'evidence_settings.dart';
import 'geographic_cell.dart';
import 'osm_evidence.dart';
import 'osm_evidence_provider.dart';

class OverpassRequest {
  const OverpassRequest(this.endpoint, this.headers, this.body);

  final Uri endpoint;
  final Map<String, String> headers;
  final String body;
}

class OverpassResponse {
  const OverpassResponse(this.statusCode, this.body, {this.retryAfter});

  final int statusCode;
  final String body;
  final String? retryAfter;
}

abstract interface class OverpassTransport {
  Future<OverpassResponse> send(OverpassRequest request);
}

class HttpOverpassTransport implements OverpassTransport {
  const HttpOverpassTransport();

  @override
  Future<OverpassResponse> send(OverpassRequest request) async {
    final client = HttpClient()
      ..connectionTimeout = EvidenceSettings.httpTimeout;
    try {
      return await _send(client, request).timeout(EvidenceSettings.httpTimeout);
    } on TimeoutException {
      throw const EvidenceException(EvidenceFailure.timeout);
    } on SocketException {
      throw const EvidenceException(EvidenceFailure.offline);
    } on IOException {
      throw const EvidenceException(EvidenceFailure.unavailable);
    } finally {
      // A deadline also aborts the actual IO; it does not leave a request
      // running while the next cell starts. No automatic redirects/retries.
      client.close(force: true);
    }
  }

  Future<OverpassResponse> _send(
    HttpClient client,
    OverpassRequest data,
  ) async {
    final request = await client.postUrl(data.endpoint);
    request.followRedirects = false;
    data.headers.forEach(request.headers.set);
    request.add(utf8.encode(data.body));
    final response = await request.close();
    final retryAfter = response.headers.value(HttpHeaders.retryAfterHeader);
    if (response.statusCode != HttpStatus.ok) {
      return OverpassResponse(response.statusCode, '', retryAfter: retryAfter);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > EvidenceSettings.maximumResponseBytes) {
        throw const EvidenceException(EvidenceFailure.responseTooLarge);
      }
      bytes.add(chunk);
    }
    return OverpassResponse(
      response.statusCode,
      utf8.decode(bytes.takeBytes()),
    );
  }
}

class OverpassEvidenceProvider implements OsmEvidenceProvider {
  OverpassEvidenceProvider({
    Uri? endpoint,
    this.transport = const HttpOverpassTransport(),
    DateTime Function()? now,
    this.requestInterval = EvidenceSettings.requestInterval,
  }) : endpoint = endpoint ?? Uri.parse(EvidenceSettings.endpoint),
       _now = now ?? DateTime.now;

  /// Shared by debug sessions, including while a previous screen is closing.
  /// Serialization and cooldown therefore survive navigating away and back.
  static final development = OverpassEvidenceProvider();

  final Uri endpoint;
  final OverpassTransport transport;
  final DateTime Function() _now;
  final Duration requestInterval;
  Future<void> _pending = Future<void>.value();
  DateTime? _lastFinishedAt;
  DateTime? _cooldownUntil;
  EvidenceException? _lastFailure;

  @override
  String get cacheNamespace =>
      '$endpoint|${EvidenceSettings.queryVersion}'
      '|z${EvidenceSettings.cellZoom}|pad${EvidenceSettings.cellPaddingMeters}m';

  static String queryForCell(GeographicCell cell) {
    final statements = <String>[];
    for (final bounds in cell.paddedBounds()) {
      statements.add('nwr["highway"](${bounds.overpass});');
      statements.add('way["area:highway"](${bounds.overpass});');
      statements.add('rel["area:highway"](${bounds.overpass});');
    }
    return '[out:json][timeout:${EvidenceSettings.queryTimeoutSeconds}]'
        '[maxsize:${EvidenceSettings.queryMaxSizeBytes}];\n'
        '(\n${statements.join('\n')}\n);\nout body geom;';
  }

  OverpassRequest requestForCell(GeographicCell cell) =>
      OverpassRequest(endpoint, const {
        HttpHeaders.userAgentHeader: EvidenceSettings.userAgent,
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader:
            'application/x-www-form-urlencoded; charset=utf-8',
      }, 'data=${Uri.encodeQueryComponent(queryForCell(cell))}');

  @override
  Future<OsmEvidence> fetchCell(GeographicCell cell) {
    final result = _pending.then((_) => _fetchSequentially(cell));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<OsmEvidence> _fetchSequentially(GeographicCell cell) async {
    if (_cooldownUntil != null && _now().isBefore(_cooldownUntil!)) {
      throw _lastFailure!;
    }
    final lastFinished = _lastFinishedAt;
    if (lastFinished != null) {
      final remaining = requestInterval - _now().difference(lastFinished);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }
    try {
      final response = await transport.send(requestForCell(cell));
      if (response.statusCode != HttpStatus.ok) {
        throw EvidenceException(
          response.statusCode == 429 || response.statusCode == 406
              ? EvidenceFailure.rateLimited
              : EvidenceFailure.unavailable,
          retryAfter: _retryDelay(response.retryAfter),
        );
      }
      return OsmEvidence.parse(response.body);
    } on EvidenceException catch (failure) {
      _coolDown(failure);
      rethrow;
    } on FormatException {
      const failure = EvidenceException(EvidenceFailure.invalidResponse);
      _coolDown(failure);
      throw failure;
    } catch (_) {
      const failure = EvidenceException(EvidenceFailure.unavailable);
      _coolDown(failure);
      throw failure;
    } finally {
      _lastFinishedAt = _now();
    }
  }

  Duration? _retryDelay(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header);
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
    try {
      return HttpDate.parse(header).difference(_now());
    } on FormatException {
      return null;
    }
  }

  void _coolDown(EvidenceException failure) {
    final requested = failure.retryAfter ?? Duration.zero;
    final duration = requested > EvidenceSettings.failureCooldown
        ? requested
        : EvidenceSettings.failureCooldown;
    _lastFailure = failure;
    _cooldownUntil = _now().add(duration);
  }
}
