import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'walk_formatters.dart';
import 'walk_map.dart';
import 'walk_models.dart';
import 'walk_repository.dart';

class WalkDetailScreen extends StatefulWidget {
  const WalkDetailScreen({
    super.key,
    required this.walk,
    required this.repository,
  });

  final Walk walk;
  final WalkRepository repository;

  @override
  State<WalkDetailScreen> createState() => _WalkDetailScreenState();
}

class _WalkDetailScreenState extends State<WalkDetailScreen> {
  late final Future<List<WalkPoint>> _points = widget.repository.pointsForWalk(
    widget.walk.id,
  );

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localizations.walkDetails)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _WalkSummary(walk: widget.walk),
          ),
          Expanded(
            child: FutureBuilder<List<WalkPoint>>(
              future: _points,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(localizations.mapLoading),
                      ],
                    ),
                  );
                }
                final points = snapshot.data!;
                if (points.length < 2) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        localizations.routeUnavailable,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    Positioned.fill(child: WalkRouteMap(points: points)),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Chip(
                        avatar: const Icon(Icons.science_outlined, size: 18),
                        label: Text(localizations.developmentMapNotice),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkSummary extends StatelessWidget {
  const _WalkSummary({required this.walk});

  final Walk walk;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _SummaryValue(
            label: localizations.durationLabel,
            value: formatDuration(walk.duration),
          ),
        ),
        Expanded(
          child: _SummaryValue(
            label: localizations.distanceLabel,
            value: formatDistance(localizations, walk.distanceMeters),
          ),
        ),
        Expanded(
          child: _SummaryValue(
            label: localizations.pointsLabel,
            value: walk.pointCount.toString(),
          ),
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
