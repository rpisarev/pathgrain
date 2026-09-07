import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../walks/walk_models.dart';
import '../../walks/analysis/route_analysis.dart';
import '../../walks/analysis/route_matcher.dart';
import 'evidence_cache.dart';
import 'evidence_inspector.dart';
import 'evidence_map.dart';
import 'evidence_repository.dart';
import 'geographic_cell.dart';
import 'osm_evidence_provider.dart';
import 'overpass_evidence_provider.dart';

class EvidenceDebugScreen extends StatefulWidget {
  const EvidenceDebugScreen({
    super.key,
    required this.loadPoints,
    this.evidenceRepository,
    this.mapBuilder,
  });

  /// A read-only local loader; the evidence repository never receives walk IDs.
  final Future<List<WalkPoint>> Function() loadPoints;
  final EvidenceRepository? evidenceRepository;

  /// Allows UI tests to exercise states without a native map or remote tiles.
  final Widget Function(EvidenceMap map)? mapBuilder;

  @override
  State<EvidenceDebugScreen> createState() => _EvidenceDebugScreenState();
}

class _EvidenceDebugScreenState extends State<EvidenceDebugScreen> {
  List<WalkPoint> _points = const [];
  EvidenceSnapshot _snapshot = const EvidenceSnapshot(
    phase: EvidencePhase.calculatingCells,
  );
  EvidenceRepository? _repository;
  SqliteEvidenceCache? _ownedCache;
  Future<void>? _loading;
  bool _busy = true;
  bool _localFailure = false;
  bool _showAccuracy = false;
  bool _showAnalysis = false;
  int? _selectedSequence;
  RouteAnalysis? _analysis;
  bool _useBasemap = true;

  @override
  void initState() {
    super.initState();
    // Defense beyond the kDebugMode entry point: release/profile never load
    // local points or construct an Overpass provider through this screen.
    if (kDebugMode) _loading = _initialize();
  }

  Future<void> _initialize() async {
    try {
      _points = await widget.loadPoints();
      if (!mounted) return;
      _repository = widget.evidenceRepository;
      if (_repository == null) {
        final cache = await SqliteEvidenceCache.openDefault();
        _ownedCache = cache;
        _repository = EvidenceRepository(
          provider: OverpassEvidenceProvider.development,
          cache: cache,
        );
      }
      if (!mounted) return;
      await _inspect();
    } catch (_) {
      if (mounted) {
        setState(() {
          _localFailure = true;
          _busy = false;
        });
      }
    }
  }

  Future<void> _inspect({bool refresh = false}) async {
    setState(() {
      _busy = true;
      _localFailure = false;
      _analysis = null;
    });
    try {
      final coordinates = _points.map(
        (point) => GeoCoordinate(point.latitude, point.longitude),
      );
      await for (final snapshot in _repository!.inspect(
        coordinates,
        refresh: refresh,
      )) {
        if (!mounted) break;
        final analysis = snapshot.isLoading
            ? null
            : RouteMatcher.analyze(
                _points,
                snapshot.features,
                evidenceComplete:
                    snapshot.totalCells > 0 &&
                    snapshot.availableCells == snapshot.totalCells &&
                    snapshot.unparsedElements == 0,
              );
        setState(() {
          _snapshot = snapshot;
          _analysis = analysis;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _localFailure = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    // Let an in-flight cell finish its cache write before closing this screen's
    // cache connection. The async-for breaks before requesting another cell.
    unawaited(_closeAfterLoading());
    super.dispose();
  }

  Future<void> _closeAfterLoading() async {
    try {
      await _loading;
      await _ownedCache?.close();
    } catch (_) {
      // This view is gone; cleanup of disposable cache data must not emit
      // raw database errors or affect the recorder.
    }
  }

  void _showInspector(Set<String>? keys, Set<int>? sequences) {
    if (sequences?.length == 1) {
      setState(() => _selectedSequence = sequences!.single);
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => EvidenceInspector(
        analysis: _analysis,
        onSelectSample: (sequence) => setState(() {
          _selectedSequence = sequence;
          _showAnalysis = true;
        }),
        features: _snapshot.features
            .where((feature) => keys == null || keys.contains(feature.key))
            .toList(),
        points: _points
            .where(
              (point) =>
                  sequences == null || sequences.contains(point.sequence),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!kDebugMode) return const SizedBox.shrink();
    final limitedFeatures = _snapshot.features
        .where((feature) => feature.limitations.isNotEmpty)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.surfaceEvidence),
        actions: [
          IconButton(
            tooltip: l.evidenceRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _busy || _repository == null
                ? null
                : () {
                    _loading = _inspect(refresh: true);
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.30,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_localFailure ? l.evidenceLocalFailure : _status(l)),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: LinearProgressIndicator(),
                      ),
                    Text(
                      l.evidenceCellCounts(
                        _snapshot.availableCells,
                        _snapshot.totalCells,
                        _snapshot.cachedCells,
                        _snapshot.fetchedCells,
                        _snapshot.features.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_snapshot.failure != null)
                      Text(_failure(l, _snapshot.failure!)),
                    if (_snapshot.cacheFailures > 0)
                      Text(l.evidenceCacheFailure),
                    if (_snapshot.oldestFetchedAt case final DateTime fetchedAt)
                      Text(
                        l.evidenceOldestCache(
                          _formatFetchedAt(context, fetchedAt),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (limitedFeatures > 0 || _snapshot.unparsedElements > 0)
                      Text(
                        l.evidenceGeometryWarnings(
                          limitedFeatures,
                          _snapshot.unparsedElements,
                        ),
                      ),
                    Text(
                      l.analysisNotice,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_showAnalysis)
                      Text(
                        l.analysisLegend,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      l.evidenceLegend,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _points.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_busy ? l.mapLoading : l.routeUnavailable),
                      ),
                    )
                  : _buildMap(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: Text(l.evidenceAccuracyToggle),
                    selected: _showAccuracy,
                    onSelected: (value) =>
                        setState(() => _showAccuracy = value),
                  ),
                  FilterChip(
                    label: Text(l.analysisToggle),
                    selected: _showAnalysis,
                    onSelected: _analysis == null
                        ? null
                        : (value) => setState(() => _showAnalysis = value),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.list_alt),
                    label: Text(l.evidenceBrowse),
                    onPressed: _points.isEmpty && _snapshot.features.isEmpty
                        ? null
                        : () => _showInspector(null, null),
                  ),
                  IconButton(
                    tooltip: l.evidenceAbout,
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l.evidenceAbout),
                        content: SingleChildScrollView(
                          child: Text(
                            '${l.evidencePrivacyNotice}\n\n'
                            '${l.evidenceProviderNotice}\n\n${l.evidenceAccuracyNotice}',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l.dismiss),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SelectableText(
                l.evidenceAttribution,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final map = EvidenceMap(
      key: ValueKey(_useBasemap),
      points: _points,
      features: _snapshot.features,
      showAccuracy: _showAccuracy,
      analysis: _analysis,
      showAnalysis: _showAnalysis,
      selectedSequence: _selectedSequence,
      onInspect: _showInspector,
      useBasemap: _useBasemap,
      onUsePlainMap: () => setState(() => _useBasemap = false),
    );
    return widget.mapBuilder?.call(map) ?? map;
  }

  String _formatFetchedAt(BuildContext context, DateTime time) {
    final local = time.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  String _status(AppLocalizations l) => switch (_snapshot.phase) {
    EvidencePhase.calculatingCells => l.evidenceCalculating,
    EvidencePhase.readingCache => l.evidenceReadingCache,
    EvidencePhase.usingCache => l.evidenceUsingCache,
    EvidencePhase.fetching => l.evidenceFetching,
    EvidencePhase.refreshing => l.evidenceRefreshing,
    EvidencePhase.loaded => l.evidenceLoaded,
    EvidencePhase.empty => l.evidenceEmpty,
    EvidencePhase.partialFailure => l.evidencePartialFailure(
      _snapshot.failedCells,
    ),
    EvidencePhase.totalFailure => l.evidenceTotalFailure,
  };

  String _failure(AppLocalizations l, EvidenceFailure failure) =>
      switch (failure) {
        EvidenceFailure.offline => l.evidenceOffline,
        EvidenceFailure.timeout => l.evidenceTimeout,
        EvidenceFailure.rateLimited => l.evidenceRateLimited,
        EvidenceFailure.unavailable => l.evidenceServiceUnavailable,
        EvidenceFailure.invalidResponse => l.evidenceInvalidResponse,
        EvidenceFailure.responseTooLarge => l.evidenceResponseTooLarge,
      };
}
