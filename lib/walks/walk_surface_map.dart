import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../l10n/app_localizations.dart';
import '../map/development_map_style.dart';
import 'analysis/walk_surface_summary.dart';
import 'surface_route_geojson.dart';

/// Read-only rendering of original GPS ranges. Does not display matched ways.
class WalkSurfaceMap extends StatefulWidget {
  const WalkSurfaceMap({super.key, required this.summary});
  final WalkSurfaceSummary summary;

  @override
  State<WalkSurfaceMap> createState() => _WalkSurfaceMapState();
}

class _WalkSurfaceMapState extends State<WalkSurfaceMap> {
  MapLibreMapController? _controller;
  Timer? _deadline;
  bool _plain = false;
  bool _ready = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startDeadline();
  }

  void _startDeadline() {
    _deadline?.cancel();
    _deadline = Timer(const Duration(seconds: 20), () {
      if (mounted && !_ready) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final points = widget.summary.analysis.samples;
    if (points.length < 2) return Center(child: Text(l.routeUnavailable));
    final first = points.first.original;
    final generation = _generation;
    return Stack(
      children: [
        MapLibreMap(
          key: ValueKey(generation),
          styleString: _plain
              ? '{"version":8,"sources":{},"layers":[{"id":"background",'
                    '"type":"background","paint":{"background-color":"#F5F5F0"}}]}'
              : DevelopmentMapStyle.styleUrl,
          initialCameraPosition: CameraPosition(
            target: LatLng(first.latitude, first.longitude),
            zoom: 16,
          ),
          onMapCreated: (controller) {
            if (mounted && generation == _generation) _controller = controller;
          },
          onStyleLoadedCallback: () => _draw(generation),
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          myLocationEnabled: false,
          compassEnabled: true,
          logoEnabled: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
        ),
        if (!_ready && !_failed)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
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
                    Text(l.surfaceMapUnavailable),
                    if (!_plain)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _plain = true;
                            _ready = false;
                            _failed = false;
                            _controller = null;
                            _generation++;
                          });
                          _startDeadline();
                        },
                        child: Text(l.surfacePlainMap),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _draw(int generation) async {
    final controller = _controller;
    if (controller == null || _ready || !mounted || generation != _generation) {
      return;
    }
    try {
      await controller.addGeoJsonSource(
        'walk-surfaces',
        SurfaceRouteGeoJson.build(widget.summary),
      );
      await controller.addLineLayer(
        'walk-surfaces',
        'walk-surface-halo',
        const LineLayerProperties(
          lineColor: '#FFFFFF',
          lineWidth: 9,
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        'walk-surfaces',
        'walk-surface-lines',
        const LineLayerProperties(
          lineColor: ['get', 'color'],
          lineWidth: 6,
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      final points = widget.summary.analysis.samples;
      var south = points.first.original.latitude;
      var north = south;
      var west = points.first.original.longitude;
      var east = west;
      for (final sample in points.skip(1)) {
        south = math.min(south, sample.original.latitude);
        north = math.max(north, sample.original.latitude);
        west = math.min(west, sample.original.longitude);
        east = math.max(east, sample.original.longitude);
      }
      if (!mounted || generation != _generation) return;
      // Avoid degenerate native bounds for a stationary route.
      if (south != north || west != east) {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(south, west),
              northeast: LatLng(north, east),
            ),
            left: 32,
            top: 32,
            right: 32,
            bottom: 32,
          ),
          duration: const Duration(milliseconds: 500),
        );
      }
      if (!mounted || generation != _generation) return;
      _deadline?.cancel();
      setState(() {
        _ready = true;
        _failed = false;
      });
    } catch (_) {
      // SDK errors may contain geometry; never log or display raw exceptions.
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
      }
    }
  }
}
