import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_recording_settings.dart';
import 'walk_models.dart';

enum LocationRecordingFailure {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationRecordingException implements Exception {
  const LocationRecordingException(this.failure);

  final LocationRecordingFailure failure;
}

class LocationReadiness {
  const LocationReadiness({required this.hasReducedAccuracy});

  final bool hasReducedAccuracy;
}

abstract interface class LocationRecorder {
  Future<LocationReadiness> prepare();

  Stream<LocationSample> positionStream({
    required String notificationTitle,
    required String notificationText,
    required String notificationChannelName,
  });

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class GeolocatorLocationRecorder implements LocationRecorder {
  @override
  Future<LocationReadiness> prepare() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationRecordingException(
        LocationRecordingFailure.servicesDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationRecordingException(
        LocationRecordingFailure.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationRecordingException(
        LocationRecordingFailure.permissionDeniedForever,
      );
    }

    final accuracy = await Geolocator.getLocationAccuracy();
    return LocationReadiness(
      hasReducedAccuracy: accuracy == LocationAccuracyStatus.reduced,
    );
  }

  @override
  Stream<LocationSample> positionStream({
    required String notificationTitle,
    required String notificationText,
    required String notificationChannelName,
  }) {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationRecordingSettings.requestedAccuracy,
        distanceFilter: LocationRecordingSettings.distanceFilterMeters,
        intervalDuration: LocationRecordingSettings.androidUpdateInterval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          notificationChannelName: notificationChannelName,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationRecordingSettings.requestedAccuracy,
        distanceFilter: LocationRecordingSettings.distanceFilterMeters,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationRecordingSettings.requestedAccuracy,
        distanceFilter: LocationRecordingSettings.distanceFilterMeters,
      );
    }

    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => LocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: position.timestamp.toUtc(),
        accuracyMeters: position.accuracy,
      ),
    );
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
