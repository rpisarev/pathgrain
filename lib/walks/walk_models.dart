enum WalkStatus {
  recording,
  completed,
  interrupted;

  String get databaseValue => name;

  static WalkStatus fromDatabase(String value) {
    return WalkStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => throw FormatException('Unknown walk status: $value'),
    );
  }
}

class Walk {
  const Walk({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationMilliseconds,
    required this.distanceMeters,
    required this.status,
    required this.pointCount,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMilliseconds;
  final double distanceMeters;
  final WalkStatus status;
  final int pointCount;

  Duration get duration {
    final storedDuration = durationMilliseconds;
    if (storedDuration != null) {
      return Duration(milliseconds: storedDuration);
    }
    return (endedAt ?? DateTime.now().toUtc()).difference(startedAt);
  }
}

class WalkPoint {
  const WalkPoint({
    required this.walkId,
    required this.sequence,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
  });

  final int walkId;
  final int sequence;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double accuracyMeters;
}

class LocationSample {
  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double accuracyMeters;
}
