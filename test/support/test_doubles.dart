import 'dart:async';

import 'package:pathgrain/platform/notification_permission.dart';
import 'package:pathgrain/walks/location_recorder.dart';
import 'package:pathgrain/walks/walk_models.dart';

class TestLocationRecorder implements LocationRecorder {
  TestLocationRecorder({
    this.readiness = const LocationReadiness(hasReducedAccuracy: false),
    this.prepareError,
  });

  final LocationReadiness readiness;
  final Object? prepareError;
  final StreamController<LocationSample> _samples =
      StreamController<LocationSample>.broadcast(sync: true);

  int positionStreamCalls = 0;

  @override
  Future<LocationReadiness> prepare() async {
    final error = prepareError;
    if (error != null) {
      throw error;
    }
    return readiness;
  }

  @override
  Stream<LocationSample> positionStream({
    required String notificationTitle,
    required String notificationText,
    required String notificationChannelName,
  }) {
    positionStreamCalls += 1;
    return _samples.stream;
  }

  void emit(LocationSample sample) {
    _samples.add(sample);
  }

  Future<void> close() => _samples.close();

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class TestNotificationPermissionGateway
    implements NotificationPermissionGateway {
  const TestNotificationPermissionGateway(this.result);

  final NotificationPermissionState result;

  @override
  Future<NotificationPermissionState> request() async => result;
}
