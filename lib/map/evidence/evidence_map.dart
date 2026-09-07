import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../l10n/app_localizations.dart';
import '../../walks/walk_models.dart';
import '../../walks/analysis/route_analysis.dart';
import 'analysis_geojson.dart';
import '../development_map_style.dart';
import 'evidence_geojson.dart';
import 'osm_evidence.dart';

class EvidenceMap extends StatefulWidget {
  const EvidenceMap({
    super.key,
    required this.points,
    required this.features,
    required this.showAccuracy,
    required this.onInspect,
    this.analysis,
    this.showAnalysis = false,
    this.selectedSequence,
    this.useBasemap = true,
    this.onUsePlainMap,
  });

  final List<WalkPoint> points;
  final List<OsmFeature> features;
  final bool showAccuracy;
  final RouteAnalysis? analysis;
  final bool showAnalysis;
  final int? selectedSequence;
  final bool useBasemap;
  final VoidCallback? onUsePlainMap;
  final void Function(Set<String> featureKeys, Set<int> sequences) onInspect;

  @override
  State<EvidenceMap> createState() => _EvidenceMapState();
}

class _EvidenceMapState extends State<EvidenceMap> {
  MapLibreMapController? _controller;
  bool _ready = false;
  bool _failed = false;
  Future<void> _updates = Future<void>.value();
  Timer? _styleDeadline;

  static const _hitLayers = [
    'evidence-points',
    'evidence-lines',
    'evidence-areas',
    'gps-samples',
    'analysis-matches',
    'analysis-unknown-edges',
    'analysis-unknown-samples',
    'analysis-focus',
  ];

  @override
  void initState() {
    super.initState();
    _styleDeadline = Timer(const Duration(seconds: 20), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  @override
  void didUpdateWidget(EvidenceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        (oldWidget.features != widget.features ||
            oldWidget.showAccuracy != widget.showAccuracy ||
            oldWidget.analysis != widget.analysis ||
            oldWidget.showAnalysis != widget.showAnalysis ||
            oldWidget.selectedSequence != widget.selectedSequence)) {
      _queueUpdate();
    }
  }

  @override
  void dispose() {
    _styleDeadline?.cancel();
    // MapLibreMap owns/disposes its controller.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.points.first;
    return Stack(
      children: [
        MapLibreMap(
          styleString: widget.useBasemap
              ? DevelopmentMapStyle.styleUrl
              : '{"version":8,"sources":{},"layers":[{"id":"background",'
                    '"type":"background","paint":{"background-color":"#F5F5F0"}}]}',
          initialCameraPosition: CameraPosition(
            target: LatLng(first.latitude, first.longitude),
            zoom: 16,
          ),
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: _initializeStyle,
          onMapClick: (point, _) => _inspectAt(point),
          myLocationEnabled: false,
          logoEnabled: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
        if (_failed)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context).evidenceMapUnavailable),
                    if (widget.useBasemap)
                      TextButton(
                        onPressed: widget.onUsePlainMap,
                        child: Text(
                          AppLocalizations.of(context).evidenceUsePlainMap,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _initializeStyle() async {
    final controller = _controller;
    if (controller == null || !mounted || _ready) return;
    try {
      await controller.addGeoJsonSource(
        'evidence',
        EvidenceGeoJson.osm(widget.features),
      );
      await controller.addGeoJsonSource(
        'gps-route',
        EvidenceGeoJson.route(widget.points),
      );
      await controller.addGeoJsonSource(
        'gps-samples',
        EvidenceGeoJson.samples(widget.points),
      );
      await controller.addGeoJsonSource(
        'gps-accuracy',
        EvidenceGeoJson.collection([]),
      );
      for (final source in [
        'analysis-matches',
        'analysis-unknown',
        'analysis-focus',
      ]) {
        await controller.addGeoJsonSource(
          source,
          EvidenceGeoJson.collection([]),
        );
      }
      await controller.addFillLayer(
        'evidence',
        'evidence-areas',
        const FillLayerProperties(
          fillColor: ['get', 'color'],
          fillOpacity: 0.22,
        ),
        filter: ['==', r'$type', 'Polygon'],
        enableInteraction: false,
      );
      await controller.addLineLayer(
        'evidence',
        'evidence-lines',
        const LineLayerProperties(
          lineColor: ['get', 'color'],
          lineWidth: 3,
          lineOpacity: 0.9,
        ),
        filter: ['!=', r'$type', 'Point'],
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        'evidence',
        'evidence-points',
        const CircleLayerProperties(
          circleColor: ['get', 'color'],
          circleRadius: 6,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 1,
        ),
        filter: ['==', r'$type', 'Point'],
        enableInteraction: false,
      );
      await controller.addFillLayer(
        'gps-accuracy',
        'gps-accuracy-fill',
        const FillLayerProperties(fillColor: '#1565C0', fillOpacity: 0.06),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        'gps-accuracy',
        'gps-accuracy-outline',
        const LineLayerProperties(
          lineColor: '#1565C0',
          lineWidth: 1,
          lineOpacity: 0.35,
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        'analysis-matches',
        'analysis-matches',
        const LineLayerProperties(
          lineColor: ['get', 'color'],
          lineWidth: 9,
          lineOpacity: 0.85,
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        'gps-route',
        'gps-halo',
        const LineLayerProperties(lineColor: '#FFFFFF', lineWidth: 7),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        'gps-route',
        'gps-route-line',
        const LineLayerProperties(lineColor: '#1565C0', lineWidth: 3.5),
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        'gps-samples',
        'gps-samples',
        const CircleLayerProperties(
          circleColor: '#FFFFFF',
          circleRadius: 3.5,
          circleStrokeColor: '#1A237E',
          circleStrokeWidth: 1.5,
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        'analysis-unknown',
        'analysis-unknown-edges',
        const LineLayerProperties(
          lineColor: '#C62828',
          lineWidth: 3,
          lineOffset: 5,
          lineDasharray: [2, 2],
        ),
        filter: ['==', r'$type', 'LineString'],
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        'analysis-unknown',
        'analysis-unknown-samples',
        const CircleLayerProperties(
          circleColor: '#C62828',
          circleOpacity: 0,
          circleRadius: 6,
          circleStrokeColor: '#C62828',
          circleStrokeWidth: 2,
        ),
        filter: ['==', r'$type', 'Point'],
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        'analysis-focus',
        'analysis-focus',
        const CircleLayerProperties(
          circleColor: '#AD1457',
          circleOpacity: 0,
          circleRadius: 10,
          circleStrokeColor: '#AD1457',
          circleStrokeWidth: 3,
        ),
        enableInteraction: false,
      );
      if (!mounted) return;
      _styleDeadline?.cancel();
      setState(() {
        _ready = true;
        _failed = false;
      });
      _queueUpdate();
      await _fitRoute(controller);
    } catch (_) {
      // Never send SDK exception details (which may contain geometry) to logs.
      if (mounted) setState(() => _failed = true);
    }
  }

  void _queueUpdate() {
    _updates = _updates
        .then((_) async {
          if (!mounted) return;
          final controller = _controller!;
          await controller.setGeoJsonSource(
            'evidence',
            EvidenceGeoJson.osm(widget.features),
          );
          if (!mounted) return;
          await controller.setGeoJsonSource(
            'gps-accuracy',
            widget.showAccuracy
                ? EvidenceGeoJson.accuracy(widget.points)
                : EvidenceGeoJson.collection([]),
          );
          if (!mounted) return;
          final analysis = widget.showAnalysis ? widget.analysis : null;
          await controller.setGeoJsonSource(
            'analysis-matches',
            AnalysisGeoJson.matches(analysis, widget.selectedSequence),
          );
          if (!mounted) return;
          await controller.setGeoJsonSource(
            'analysis-unknown',
            AnalysisGeoJson.unknown(analysis),
          );
          if (!mounted) return;
          await controller.setGeoJsonSource(
            'analysis-focus',
            AnalysisGeoJson.focus(analysis, widget.selectedSequence),
          );
        })
        .catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        });
  }

  Future<void> _fitRoute(MapLibreMapController controller) async {
    if (widget.points.length < 2) return;
    var south = widget.points.first.latitude;
    var north = south;
    var west = widget.points.first.longitude;
    var east = west;
    for (final point in widget.points) {
      south = math.min(south, point.latitude);
      north = math.max(north, point.latitude);
      west = math.min(west, point.longitude);
      east = math.max(east, point.longitude);
    }
    if (south == north && west == east) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        left: 28,
        right: 28,
        top: 28,
        bottom: 28,
      ),
    );
  }

  Future<void> _inspectAt(math.Point<double> point) async {
    if (!_ready) return;
    try {
      final hits = await _controller!.queryRenderedFeaturesInRect(
        Rect.fromCenter(
          center: Offset(point.x, point.y),
          width: 24,
          height: 24,
        ),
        _hitLayers,
        null,
      );
      final keys = <String>{};
      final sequences = <int>{};
      for (final hit in hits) {
        final decoded = hit is String ? jsonDecode(hit) : hit;
        if (decoded is! Map || decoded['properties'] is! Map) continue;
        final properties = decoded['properties'] as Map;
        if (properties['evidenceKey'] case final String key) keys.add(key);
        if (properties['fromSequence'] case final num sequence) {
          sequences.add(sequence.toInt());
        }
        if (properties['sequence'] case final num sequence) {
          sequences.add(sequence.toInt());
        }
      }
      if (mounted && (keys.isNotEmpty || sequences.isNotEmpty)) {
        widget.onInspect(keys, sequences);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }
}
