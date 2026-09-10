import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../map/evidence/evidence_cache.dart';
import '../map/evidence/evidence_repository.dart';
import '../map/evidence/geographic_cell.dart';
import '../map/evidence/overpass_evidence_provider.dart';
import 'analysis/route_matcher.dart';
import 'analysis/walk_surface_summary.dart';
import 'surface_route_geojson.dart';
import 'walk_formatters.dart';
import 'walk_models.dart';
import 'walk_surface_map.dart';

class WalkSurfaceReviewScreen extends StatefulWidget {
  const WalkSurfaceReviewScreen({
    super.key,
    required this.walk,
    required this.loadPoints,
    this.evidenceRepository,
    this.mapBuilder,
  });

  final Walk walk;
  final Future<List<WalkPoint>> Function() loadPoints;
  final EvidenceRepository? evidenceRepository;
  final Widget Function(WalkSurfaceMap map)? mapBuilder;

  @override
  State<WalkSurfaceReviewScreen> createState() =>
      _WalkSurfaceReviewScreenState();
}

class _WalkSurfaceReviewScreenState extends State<WalkSurfaceReviewScreen> {
  List<WalkPoint>? _points;
  EvidenceRepository? _repository;
  SqliteEvidenceCache? _ownedCache;
  EvidenceSnapshot? _snapshot;
  WalkSurfaceSummary? _summary;
  Future<void>? _loading;
  bool _busy = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loading = _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final points = await widget.loadPoints();
      if (!mounted) return;
      // Reject corrupt coordinates before evidence access or native rendering.
      if (points.any((p) => !GeoCoordinate(p.latitude, p.longitude).isValid)) {
        throw const FormatException('Invalid saved route');
      }
      setState(() => _points = List.unmodifiable(points));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze() async {
    setState(() {
      _busy = true;
      _failed = false;
      _summary = null;
      _snapshot = null;
    });
    try {
      _repository ??= widget.evidenceRepository;
      if (_repository == null) {
        final cache = await SqliteEvidenceCache.openDefault();
        _ownedCache = cache;
        _repository = EvidenceRepository(
          provider: OverpassEvidenceProvider.development,
          cache: cache,
        );
      }
      if (!mounted) return;
      await for (final snapshot in _repository!.inspect(
        _points!.map((p) => GeoCoordinate(p.latitude, p.longitude)),
      )) {
        if (!mounted) break;
        if (!snapshot.isLoading) {
          final summary = WalkSurfaceSummary.fromAnalysis(
            RouteMatcher.analyze(
              _points!,
              snapshot.features,
              evidenceComplete: snapshot.hasCompleteCoverage,
            ),
          );
          setState(() {
            _snapshot = snapshot;
            _summary = summary;
          });
        }
      }
      if (mounted && _summary == null) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_closeAfterLoading());
    super.dispose();
  }

  Future<void> _closeAfterLoading() async {
    try {
      await _loading;
      await _ownedCache?.close();
    } catch (_) {
      // Disposable cache cleanup must not affect the walk or emit raw errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final walk = widget.walk;
    final localStart = walk.startedAt.toLocal();
    final material = MaterialLocalizations.of(context);
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(title: Text(l.surfaceReview)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${material.formatMediumDate(localStart)} · '
                      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(localStart))}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      walk.status == WalkStatus.interrupted
                          ? l.interruptedWalk
                          : l.completedWalk,
                    ),
                    Text(
                      '${l.distanceLabel}: ${formatDistance(l, walk.distanceMeters)}'
                      ' · ${l.durationLabel}: ${formatDuration(walk.duration)}',
                    ),
                    Text(l.pointCount(walk.pointCount)),
                    const SizedBox(height: 12),
                    if (_busy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(_points == null ? l.mapLoading : l.surfaceAnalyzing),
                    ] else if (_failed) ...[
                      Text(l.surfaceReviewFailed),
                      TextButton(
                        onPressed: () => _loading = _points == null
                            ? _loadPoints()
                            : _analyze(),
                        child: Text(l.surfaceRetry),
                      ),
                    ] else if (_points!.length < 2)
                      Text(l.routeUnavailable)
                    else if (summary == null) ...[
                      Text(l.surfaceAccessNotice),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _loading = _analyze(),
                        child: Text(l.surfaceAnalyze),
                      ),
                    ],
                    if (summary != null) ...[
                      Text(l.surfaceReviewNotice),
                      if (!_snapshot!.hasCompleteCoverage) ...[
                        const SizedBox(height: 8),
                        Text(l.surfaceEvidenceIncomplete),
                        TextButton(
                          onPressed: _busy ? null : () => _loading = _analyze(),
                          child: Text(l.surfaceRetry),
                        ),
                      ],
                      if (_snapshot!.cacheFailures > 0)
                        Text(l.surfaceCacheUnavailable),
                      const SizedBox(height: 16),
                      Text(
                        l.surfaceBreakdown,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final entry in summary.distanceBySurface.entries)
                        Padding(
                          key: ValueKey('surface-${entry.key.name}'),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: Container(
                                  width: 24,
                                  height: 6,
                                  color: Color(
                                    int.parse(
                                          SurfaceRouteGeoJson.color(entry.key)
                                              .substring(1),
                                          radix: 16,
                                        ) |
                                        0xFF000000,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(l.analysisSurface(entry.key.name)),
                              ),
                              Text(formatDistance(l, entry.value)),
                            ],
                          ),
                        ),
                      const Divider(),
                      Text(
                        l.surfaceTotal(
                          formatDistance(l, summary.totalDistanceMeters),
                        ),
                      ),
                      if (!summary.reconcilesWith(walk.distanceMeters))
                        Text(l.surfaceDistanceMismatch),
                      Text(
                        l.surfaceRoundingNotice,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(l.surfaceRouteLegend),
                    ],
                  ],
                ),
              ),
              if (summary != null && summary.segments.isNotEmpty)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.55,
                  child: _buildMap(summary),
                ),
              if (summary != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    l.evidenceAttribution,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(WalkSurfaceSummary summary) {
    final map = WalkSurfaceMap(key: ObjectKey(summary), summary: summary);
    return widget.mapBuilder?.call(map) ?? map;
  }
}
