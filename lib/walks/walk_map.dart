import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../map/development_map_style.dart';
import 'walk_models.dart';

class WalkRouteMap extends StatefulWidget {
  const WalkRouteMap({super.key, required this.points});

  final List<WalkPoint> points;

  @override
  State<WalkRouteMap> createState() => _WalkRouteMapState();
}

class _WalkRouteMapState extends State<WalkRouteMap> {
  MapLibreMapController? _controller;

  List<LatLng> get _geometry => widget.points
      .map((point) => LatLng(point.latitude, point.longitude))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final geometry = _geometry;
    return MapLibreMap(
      styleString: DevelopmentMapStyle.styleUrl,
      initialCameraPosition: CameraPosition(target: geometry.first, zoom: 15),
      onMapCreated: (controller) {
        _controller = controller;
      },
      onStyleLoadedCallback: _drawPersistedRoute,
      myLocationEnabled: false,
      compassEnabled: true,
      logoEnabled: true,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
    );
  }

  Future<void> _drawPersistedRoute() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final geometry = _geometry;
    await controller.addLine(
      LineOptions(
        geometry: geometry,
        lineColor: '#1565C0',
        lineWidth: 5,
        lineOpacity: 0.9,
        lineJoin: 'round',
      ),
    );

    var minimumLatitude = geometry.first.latitude;
    var maximumLatitude = geometry.first.latitude;
    var minimumLongitude = geometry.first.longitude;
    var maximumLongitude = geometry.first.longitude;
    for (final coordinate in geometry.skip(1)) {
      minimumLatitude = minimumLatitude < coordinate.latitude
          ? minimumLatitude
          : coordinate.latitude;
      maximumLatitude = maximumLatitude > coordinate.latitude
          ? maximumLatitude
          : coordinate.latitude;
      minimumLongitude = minimumLongitude < coordinate.longitude
          ? minimumLongitude
          : coordinate.longitude;
      maximumLongitude = maximumLongitude > coordinate.longitude
          ? maximumLongitude
          : coordinate.longitude;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minimumLatitude, minimumLongitude),
          northeast: LatLng(maximumLatitude, maximumLongitude),
        ),
        left: 40,
        top: 40,
        right: 40,
        bottom: 40,
      ),
      duration: const Duration(milliseconds: 500),
    );
  }
}
