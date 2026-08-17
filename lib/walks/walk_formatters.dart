import '../l10n/app_localizations.dart';

String formatDuration(Duration duration) {
  final nonNegative = duration.isNegative ? Duration.zero : duration;
  final hours = nonNegative.inHours.toString().padLeft(2, '0');
  final minutes = (nonNegative.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (nonNegative.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String formatDistance(AppLocalizations localizations, double distanceMeters) {
  if (distanceMeters < 1000) {
    return localizations.distanceMeters(distanceMeters.round());
  }
  return localizations.distanceKilometers(
    double.parse((distanceMeters / 1000).toStringAsFixed(2)),
  );
}
