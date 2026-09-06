import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../walks/walk_models.dart';
import 'osm_evidence.dart';

class EvidenceInspector extends StatelessWidget {
  const EvidenceInspector({
    super.key,
    required this.points,
    required this.features,
  });

  final List<WalkPoint> points;
  final List<OsmFeature> features;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SafeArea(
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: 1 + points.length + features.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.evidenceInspectorHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            if (index <= points.length) {
              final point = points[index - 1];
              return ListTile(
                leading: const Icon(Icons.gps_fixed),
                title: Text(l.evidenceGpsPoint(point.sequence)),
                subtitle: Text(l.evidenceAccuracy(point.accuracyMeters)),
              );
            }
            return _FeatureDetails(
              feature: features[index - points.length - 1],
              initiallyExpanded: features.length == 1,
            );
          },
        ),
      ),
    );
  }
}

class _FeatureDetails extends StatelessWidget {
  const _FeatureDetails({
    required this.feature,
    required this.initiallyExpanded,
  });

  final OsmFeature feature;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tags = feature.tags;
    final otherKeys =
        tags.keys.where((key) => key != 'highway' && key != 'surface').toList()
          ..sort();
    return ExpansionTile(
      key: ValueKey(feature.key),
      initiallyExpanded: initiallyExpanded,
      title: Text(l.evidenceFeatureTitle(feature.type.name, feature.id)),
      subtitle: Text(
        'highway: ${tags['highway'] ?? l.evidenceTagMissing}\n'
        'surface: ${tags['surface'] ?? l.evidenceTagMissing}',
      ),
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(switch (feature.geometryKind) {
          OsmGeometryKind.point => l.evidenceGeometryPoint,
          OsmGeometryKind.line => l.evidenceGeometryLine,
          OsmGeometryKind.closedArea => l.evidenceGeometryArea,
          OsmGeometryKind.relation => l.evidenceGeometryRelation,
          OsmGeometryKind.unavailable => l.evidenceGeometryUnavailable,
        }),
        Text(feature.isArea ? l.evidenceAreaTagged : l.evidenceAreaNotTagged),
        if (feature.limitations.contains(
          OsmGeometryLimitation.relationOutlinesOnly,
        ))
          Text(l.evidenceRelationLimitation),
        if (feature.limitations.contains(
          OsmGeometryLimitation.incompleteGeometry,
        ))
          Text(l.evidenceIncompleteGeometry),
        const SizedBox(height: 8),
        for (final key in ['highway', 'surface', ...otherKeys])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: SelectableText(
              '$key = ${tags[key] ?? l.evidenceTagMissing}',
            ),
          ),
        if (feature.raw['members'] case final List members) ...[
          const Divider(),
          Text(l.evidenceRelationMembers(members.length)),
          for (final member in members)
            if (member is Map)
              SelectableText(
                '${member['type']} ${member['ref']} · '
                '${member['role'] ?? ''}',
              ),
        ],
      ],
    );
  }
}
