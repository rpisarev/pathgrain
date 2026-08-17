import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/notification_permission.dart';
import 'location_point_filter.dart';
import 'location_recorder.dart';
import 'walk_distance.dart';
import 'walk_models.dart';
import 'walk_repository.dart';

enum WalkRecordingPhase {
  initializing,
  idle,
  starting,
  recording,
  stopping,
  error,
}

enum WalkRecordingProblem {
  locationServicesDisabled,
  locationPermissionDenied,
  locationPermissionDeniedForever,
  recordingFailed,
  storageFailed,
}

class WalkRecordingController extends ChangeNotifier {
  factory WalkRecordingController({
    required WalkRepository repository,
    required LocationRecorder locationRecorder,
    required NotificationPermissionGateway notificationPermissionGateway,
    LocationPointFilter pointFilter = const LocationPointFilter(),
    DateTime Function()? now,
  }) {
    return WalkRecordingController._(
      repository,
      locationRecorder,
      notificationPermissionGateway,
      pointFilter,
      now ?? DateTime.now,
    );
  }

  WalkRecordingController._(
    this._repository,
    this._locationRecorder,
    this._notificationPermissionGateway,
    this._pointFilter,
    this._now,
  );

  final WalkRepository _repository;
  final LocationRecorder _locationRecorder;
  final NotificationPermissionGateway _notificationPermissionGateway;
  final LocationPointFilter _pointFilter;
  final DateTime Function() _now;

  WalkRecordingPhase _phase = WalkRecordingPhase.initializing;
  WalkRecordingProblem? _problem;
  NotificationPermissionState _notificationPermissionState =
      NotificationPermissionState.notRequired;
  List<Walk> _walks = const [];
  Walk? _activeWalk;
  List<WalkPoint> _activePoints = [];
  Duration _elapsed = Duration.zero;
  double _activeDistanceMeters = 0;
  bool _hasReducedLocationAccuracy = false;
  StreamSubscription<LocationSample>? _positionSubscription;
  Timer? _timer;
  Future<void> _pendingPointWrites = Future<void>.value();
  bool _interrupting = false;

  WalkRecordingPhase get phase => _phase;
  WalkRecordingProblem? get problem => _problem;
  NotificationPermissionState get notificationPermissionState =>
      _notificationPermissionState;
  List<Walk> get walks => List.unmodifiable(_walks);
  Walk? get activeWalk => _activeWalk;
  int get activePointCount => _activePoints.length;
  Duration get elapsed => _elapsed;
  double get activeDistanceMeters => _activeDistanceMeters;
  bool get hasReducedLocationAccuracy => _hasReducedLocationAccuracy;

  Future<void> initialize() async {
    _phase = WalkRecordingPhase.initializing;
    notifyListeners();
    try {
      await _repository.recoverInterruptedWalks();
      await _reloadWalks();
      _phase = WalkRecordingPhase.idle;
    } catch (_) {
      _problem = WalkRecordingProblem.storageFailed;
      _phase = WalkRecordingPhase.error;
    }
    notifyListeners();
  }

  Future<void> startWalk({
    required String notificationTitle,
    required String notificationText,
    required String notificationChannelName,
  }) async {
    if (_phase != WalkRecordingPhase.idle &&
        _phase != WalkRecordingPhase.error) {
      return;
    }

    _phase = WalkRecordingPhase.starting;
    _problem = null;
    _hasReducedLocationAccuracy = false;
    _notificationPermissionState = NotificationPermissionState.notRequired;
    notifyListeners();

    try {
      final readiness = await _locationRecorder.prepare();
      _hasReducedLocationAccuracy = readiness.hasReducedAccuracy;
    } on LocationRecordingException catch (error) {
      _problem = switch (error.failure) {
        LocationRecordingFailure.servicesDisabled =>
          WalkRecordingProblem.locationServicesDisabled,
        LocationRecordingFailure.permissionDenied =>
          WalkRecordingProblem.locationPermissionDenied,
        LocationRecordingFailure.permissionDeniedForever =>
          WalkRecordingProblem.locationPermissionDeniedForever,
      };
      _phase = WalkRecordingPhase.error;
      notifyListeners();
      return;
    } catch (_) {
      _problem = WalkRecordingProblem.recordingFailed;
      _phase = WalkRecordingPhase.error;
      notifyListeners();
      return;
    }

    _notificationPermissionState = await _notificationPermissionGateway
        .request();

    try {
      _activeWalk = await _repository.createWalk(_now().toUtc());
    } catch (_) {
      _problem = WalkRecordingProblem.storageFailed;
      _phase = WalkRecordingPhase.error;
      notifyListeners();
      return;
    }

    _activePoints = [];
    _activeDistanceMeters = 0;
    _elapsed = Duration.zero;
    _pendingPointWrites = Future<void>.value();

    _phase = WalkRecordingPhase.recording;
    try {
      final stream = _locationRecorder.positionStream(
        notificationTitle: notificationTitle,
        notificationText: notificationText,
        notificationChannelName: notificationChannelName,
      );
      _positionSubscription = stream.listen(
        _enqueueSample,
        onError: (Object _, StackTrace _) {
          unawaited(_interrupt(WalkRecordingProblem.recordingFailed));
        },
      );
    } catch (_) {
      await _interrupt(WalkRecordingProblem.recordingFailed);
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final activeWalk = _activeWalk;
      if (activeWalk == null) {
        return;
      }
      _elapsed = _now().toUtc().difference(activeWalk.startedAt);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<Walk?> stopWalk() async {
    if (_phase != WalkRecordingPhase.recording || _activeWalk == null) {
      return null;
    }

    _phase = WalkRecordingPhase.stopping;
    notifyListeners();
    _timer?.cancel();
    _timer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _pendingPointWrites;

    final activeWalk = _activeWalk!;
    try {
      final completedWalk = await _repository.finishWalk(
        walkId: activeWalk.id,
        endedAt: _now().toUtc(),
        status: WalkStatus.completed,
      );
      await _reloadWalks();
      _clearActiveWalk();
      _phase = WalkRecordingPhase.idle;
      notifyListeners();
      return completedWalk;
    } catch (_) {
      _problem = WalkRecordingProblem.storageFailed;
      _clearActiveWalk();
      _phase = WalkRecordingPhase.error;
      notifyListeners();
      return null;
    }
  }

  void dismissProblem() {
    if (_phase != WalkRecordingPhase.error) {
      return;
    }
    _problem = null;
    _phase = WalkRecordingPhase.idle;
    notifyListeners();
  }

  Future<bool> openAppSettings() => _locationRecorder.openAppSettings();

  Future<bool> openLocationSettings() =>
      _locationRecorder.openLocationSettings();

  void _enqueueSample(LocationSample sample) {
    _pendingPointWrites = _pendingPointWrites.then((_) async {
      final activeWalk = _activeWalk;
      if (_phase != WalkRecordingPhase.recording || activeWalk == null) {
        return;
      }

      final previous = _activePoints.isEmpty ? null : _activePoints.last;
      if (!_pointFilter.shouldAccept(sample, previous)) {
        return;
      }

      try {
        final persistedPoint = await _repository.appendPoint(
          activeWalk.id,
          sample,
        );
        if (previous != null) {
          _activeDistanceMeters += WalkDistance.betweenCoordinates(
            latitudeA: previous.latitude,
            longitudeA: previous.longitude,
            latitudeB: persistedPoint.latitude,
            longitudeB: persistedPoint.longitude,
          );
        }
        _activePoints.add(persistedPoint);
        notifyListeners();
      } catch (_) {
        unawaited(
          _interrupt(
            WalkRecordingProblem.storageFailed,
            waitForPointWrites: false,
          ),
        );
      }
    });
  }

  Future<void> _interrupt(
    WalkRecordingProblem problem, {
    bool waitForPointWrites = true,
  }) async {
    if (_interrupting || _activeWalk == null) {
      return;
    }
    _interrupting = true;
    _phase = WalkRecordingPhase.stopping;
    notifyListeners();
    _timer?.cancel();
    _timer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (waitForPointWrites) {
      await _pendingPointWrites;
    }

    var finalProblem = problem;
    final activeWalk = _activeWalk!;
    try {
      await _repository.finishWalk(
        walkId: activeWalk.id,
        endedAt: _now().toUtc(),
        status: WalkStatus.interrupted,
      );
      await _reloadWalks();
    } catch (_) {
      finalProblem = WalkRecordingProblem.storageFailed;
    }

    _clearActiveWalk();
    _problem = finalProblem;
    _phase = WalkRecordingPhase.error;
    _interrupting = false;
    notifyListeners();
  }

  Future<void> _reloadWalks() async {
    _walks = await _repository.listWalks();
  }

  void _clearActiveWalk() {
    _activeWalk = null;
    _activePoints = [];
    _elapsed = Duration.zero;
    _activeDistanceMeters = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }
}
