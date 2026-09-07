/// Provisional 0.1-B experiment settings, not calibrated probabilities or
/// recorder filters. See docs/development/mvp-0.1-b-route-surface-matching.md.
abstract final class AnalysisSettings {
  static const goodAccuracyMeters = 15.0;
  static const poorAccuracyMeters = 25.0;
  static const strongAccuracyMeters = 10.0;
  static const stableSamples = 3;
  static const maximumSpeedMetersPerSecond = 3.5;
  static const maximumGapSeconds = 30.0;
  static const spikeOffsetMeters = 10.0;
  static const spikeAccuracyFactor = 0.8;
  static const spikeDetourRatio = 1.8;

  static const candidateRadiusMeters = 40.0;
  static const minimumMatchRadiusMeters = 8.0;
  static const maximumMatchRadiusMeters = 20.0;
  static const accuracyAllowanceMeters = 5.0;
  static const headingWindowSamples = 2;
  static const minimumHeadingMeters = 8.0;
  static const headingAccuracyFactor = 2.0;
  static const maximumDirectionDegrees = 55.0;
  static const parallelDirectionDegrees = 20.0;
  static const minimumAmbiguityMeters = 6.0;
  static const areaBoundaryAllowanceMeters = 2.0;
  static const maximumLocalGeometryMeters = 3000.0;
  static const maximumLatitude = 80.0;
  static const maximumAreaVertices = 64;
  static const edgeProbeFractions = [0.25, 0.5, 0.75];

  static const proximityWeight = 40.0;
  static const pedestrianWeight = 20.0;
  static const roadWeight = 8.0;
  static const directionWeight = 20.0;
  static const areaDirectionWeight = 10.0;
  static const gpsWeight = 10.0;
  static const neighborSupportWeight = 12.0;
  static const neighborConflictWeight = 6.0;
  static const minimumScore = 62.0;
  static const minimumMargin = 12.0;
  static const strongMargin = 20.0;
}
