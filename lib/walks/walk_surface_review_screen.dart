import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../map/evidence/evidence_cache.dart';
import '../map/evidence/evidence_repository.dart';
import '../map/evidence/geographic_cell.dart';
import '../map/evidence/overpass_evidence_provider.dart';
import 'analysis/route_matcher.dart';
import 'analysis/surface_journal.dart';
import 'surface_correction_dialog.dart';
import 'walk_surface_repository.dart';
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
    required this.surfaceRepository,
    this.evidenceRepository,
    this.mapBuilder,
  });

  final Walk walk;
  final WalkSurfaceRepository surfaceRepository;
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
  SurfaceJournal? _journal;
  EffectiveSurfaceSummary? _preview;
  bool _journalInvalid = false;
  bool _localLoadFailed = false;
  bool _saveFailed = false;
  bool _incomplete = false;
  EffectiveSurfaceSummary? get _summary => _journal?.effective ?? _preview;
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
      if (points.length >= 2) {
        try {
          final journal = await widget.surfaceRepository.load(
            widget.walk.id,
            points,
          );
          if (mounted) {
            setState(() {
              _journal = journal;
              _journalInvalid = false;
              _localLoadFailed = false;
            });
          }
        } on FormatException {
          if (mounted) {
            setState(() {
              _journalInvalid = true;
              _localLoadFailed = false;
            });
          }
        } catch (_) {
          if (mounted) setState(() => _localLoadFailed = true);
        }
      }
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
      _saveFailed = false;
      _incomplete = false;
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
      EvidenceSnapshot? terminal;
      await for (final snapshot in _repository!.inspect(
        _points!.map((p) => GeoCoordinate(p.latitude, p.longitude)),
      )) {
        if (!mounted) break;
        if (!snapshot.isLoading) terminal = snapshot;
      }
      if (!mounted) return;
      if (terminal == null) throw const FormatException('No complete analysis');
      final summary = WalkSurfaceSummary.fromAnalysis(
        RouteMatcher.analyze(
          _points!,
          terminal.features,
          evidenceComplete: terminal.hasCompleteCoverage,
        ),
      );
      _snapshot = terminal;
      if (!terminal.hasCompleteCoverage ||
          terminal.failedCells > 0 ||
          terminal.failure != null) {
        setState(() {
          _incomplete = true;
          // C's honest UNKNOWN preview remains available only before a saved
          // snapshot exists. It is explicitly unsaved and cannot be corrected.
          if (_journal == null) {
            _preview = SurfaceJournal(
              AutomaticSurfaceSnapshot.fromSummary(summary),
              const [],
            ).effective;
          }
        });
        return;
      }
      try {
        final journal = await widget.surfaceRepository.saveAnalysis(
          widget.walk.id,
          summary,
          evidenceComplete: true,
        );
        if (mounted) {
          setState(() {
            _journal = journal;
            _preview = null;
            _journalInvalid = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _saveFailed = true);
      }
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
                    ],
                    if (!_busy && (_failed || _localLoadFailed)) ...[
                      Text(l.surfaceReviewFailed),
                      TextButton(
                        onPressed: () =>
                            _loading = _points == null || _localLoadFailed
                            ? _loadPoints()
                            : _analyze(),
                        child: Text(l.surfaceRetry),
                      ),
                    ],
                    if (_journalInvalid) Text(l.surfaceJournalInvalid),
                    if (_saveFailed) ...[
                      Text(l.surfaceAnalysisSaveFailed),
                      TextButton(
                        onPressed: _busy ? null : () => _loading = _analyze(),
                        child: Text(l.surfaceRetry),
                      ),
                    ],
                    if (_incomplete) ...[
                      Text(l.surfaceEvidenceIncomplete),
                      Text(
                        _journal == null
                            ? l.surfacePreviewUnsaved
                            : l.surfacePreviousKept,
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _loading = _analyze(),
                        child: Text(l.surfaceRetry),
                      ),
                    ],
                    if (!_busy &&
                        !_failed &&
                        !_localLoadFailed &&
                        _points != null)
                      if (_points!.length < 2)
                        Text(l.routeUnavailable)
                      else if (!_incomplete && !_saveFailed) ...[
                        Text(l.surfaceAccessNotice),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _loading = _analyze(),
                          child: Text(
                            _journal == null
                                ? l.surfaceAnalyze
                                : l.surfaceReanalyze,
                          ),
                        ),
                      ],
                    if (summary != null) ...[
                      Text(l.surfaceReviewNotice),
                      if (_snapshot != null && _snapshot!.cacheFailures > 0)
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
              if (_journal != null) _buildSegments(_journal!.effective),
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

  Widget _buildSegments(EffectiveSurfaceSummary summary) {
    final l = AppLocalizations.of(context);
    var distance = 0.0;
    final rows = <Widget>[];
    for (var i = 0; i < summary.segments.length; i++) {
      final segment = summary.segments[i];
      final start = distance;
      distance += segment.distanceMeters;
      rows.add(
        ListTile(
          key: ValueKey(
            'segment-${segment.startEdgeIndex}-${segment.endEdgeIndex}',
          ),
          title: Text(
            '${l.surfaceSegment(i + 1)} · ${formatDistance(l, segment.distanceMeters)}',
          ),
          subtitle: Text(
            '${l.analysisSurface(segment.surface.name)} · '
            '${segment.isCorrected ? l.surfaceCorrected : l.surfaceAutomatic}\n'
            '${l.surfaceSegmentPosition(formatDistance(l, start), formatDistance(l, distance))}',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: _busy ? null : () => _editSegment(segment, i + 1),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.surfaceSegments,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(l.surfaceSelectSegment),
          ...rows,
        ],
      ),
    );
  }

  Future<void> _editSegment(EffectiveSurfaceSegment segment, int number) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SurfaceCorrectionDialog(
        segment: segment,
        number: number,
        save: (surface) async {
          final journal = surface == null
              ? await widget.surfaceRepository.restoreAutomatic(
                  widget.walk.id,
                  _points!,
                  segment.correction!,
                )
              : await widget.surfaceRepository.saveCorrection(
                  widget.walk.id,
                  _points!,
                  SurfaceCorrection(
                    startEdgeIndex: segment.startEdgeIndex,
                    endEdgeIndex: segment.endEdgeIndex,
                    surface: surface,
                  ),
                );
          if (mounted) setState(() => _journal = journal);
        },
      ),
    );
  }

  Widget _buildMap(EffectiveSurfaceSummary summary) {
    final map = WalkSurfaceMap(summary: summary);
    return widget.mapBuilder?.call(map) ?? map;
  }
}
