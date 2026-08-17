import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/location_point_filter.dart';
import 'package:pathgrain/walks/location_recording_settings.dart';
import 'package:pathgrain/walks/walk_models.dart';

void main() {
  const filter = LocationPointFilter();
  final recordedAt = DateTime.utc(2026, 8, 16, 8);

  WalkPoint previousPoint() {
    return WalkPoint(
      walkId: 1,
      sequence: 0,
      latitude: 50.4501,
      longitude: 30.5234,
      recordedAt: recordedAt,
      accuracyMeters: 5,
    );
  }

  test('accepts the first valid accurate point', () {
    final sample = LocationSample(
      latitude: 50.4501,
      longitude: 30.5234,
      recordedAt: recordedAt,
      accuracyMeters: 5,
    );

    expect(filter.shouldAccept(sample, null), isTrue);
  });

  test('rejects a point outside the centralized accuracy threshold', () {
    final sample = LocationSample(
      latitude: 50.4501,
      longitude: 30.5234,
      recordedAt: recordedAt,
      accuracyMeters:
          LocationRecordingSettings.maximumAcceptedAccuracyMeters + 0.1,
    );

    expect(filter.shouldAccept(sample, null), isFalse);
  });

  test('rejects a displacement below the centralized minimum', () {
    final sample = LocationSample(
      latitude: 50.45011,
      longitude: 30.5234,
      recordedAt: recordedAt.add(const Duration(seconds: 5)),
      accuracyMeters: 5,
    );

    expect(filter.shouldAccept(sample, previousPoint()), isFalse);
  });

  test('rejects an implausibly fast segment', () {
    final sample = LocationSample(
      latitude: 50.4511,
      longitude: 30.5234,
      recordedAt: recordedAt.add(const Duration(seconds: 1)),
      accuracyMeters: 5,
    );

    expect(filter.shouldAccept(sample, previousPoint()), isFalse);
  });

  test('accepts a plausible walking segment', () {
    final sample = LocationSample(
      latitude: 50.45015,
      longitude: 30.5234,
      recordedAt: recordedAt.add(const Duration(seconds: 5)),
      accuracyMeters: 5,
    );

    expect(filter.shouldAccept(sample, previousPoint()), isTrue);
  });
}
