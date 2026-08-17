import 'location_recording_settings.dart';
import 'walk_distance.dart';
import 'walk_models.dart';

class LocationPointFilter {
  const LocationPointFilter();

  bool shouldAccept(LocationSample candidate, WalkPoint? previous) {
    if (!_hasValidCoordinates(candidate) ||
        !candidate.accuracyMeters.isFinite ||
        candidate.accuracyMeters < 0 ||
        candidate.accuracyMeters >
            LocationRecordingSettings.maximumAcceptedAccuracyMeters) {
      return false;
    }

    if (previous == null) {
      return true;
    }

    final elapsed = candidate.recordedAt.difference(previous.recordedAt);
    if (elapsed <= Duration.zero) {
      return false;
    }

    final displacement = WalkDistance.betweenCoordinates(
      latitudeA: previous.latitude,
      longitudeA: previous.longitude,
      latitudeB: candidate.latitude,
      longitudeB: candidate.longitude,
    );
    if (displacement <
        LocationRecordingSettings.minimumAcceptedDisplacementMeters) {
      return false;
    }

    final speed = displacement / (elapsed.inMilliseconds / 1000);
    return speed <=
        LocationRecordingSettings.maximumPlausibleSpeedMetersPerSecond;
  }

  bool _hasValidCoordinates(LocationSample sample) {
    return sample.latitude.isFinite &&
        sample.longitude.isFinite &&
        sample.latitude >= -90 &&
        sample.latitude <= 90 &&
        sample.longitude >= -180 &&
        sample.longitude <= 180;
  }
}
