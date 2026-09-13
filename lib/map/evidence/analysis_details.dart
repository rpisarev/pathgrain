import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../walks/analysis/route_analysis.dart';

class AnalysisDetails extends StatelessWidget {
  const AnalysisDetails({super.key, required this.sample, required this.edges});
  final SampleAnalysis sample;
  final List<EdgeAnalysis> edges;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String reason(AnalysisReason value) => l.analysisReason(value.name);
    String result(SurfaceAssessment value) => l.analysisResult(
      l.analysisAssignment(value.assignment.name),
      l.analysisSurface(value.surface.name),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.analysisGpsState(sample.gps.state.name)),
          for (final value in sample.gps.reasons) Text(reason(value)),
          Text(
            l.analysisSelected(
              sample.selected?.feature.key ?? l.analysisNoObject,
            ),
          ),
          Text(l.analysisConfidence(sample.confidence.name)),
          Text(reason(sample.reason)),
          if (sample.selected case final MatchCandidate selected)
            Text(
              l.analysisOsmSurface(
                selected.feature.tags['surface'] ?? l.evidenceTagMissing,
              ),
            ),
          Text(result(sample.surface)),
          Text(reason(sample.surface.reason)),
          if (edges.isNotEmpty) ...[
            const Divider(),
            for (final edge in edges) ...[
              Text(
                l.analysisEdge(
                  edge.from.original.sequence,
                  edge.to.original.sequence,
                  edge.gps.speed?.toStringAsFixed(2) ?? '—',
                ),
              ),
              Text(l.analysisEdgeGps(reason(edge.gps.reason))),
              Text(result(edge.surface)),
              Text(reason(edge.reason)),
            ],
          ],
          const Divider(),
          Text(l.analysisCandidates(sample.candidates.length)),
          for (final candidate in sample.candidates)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                l.evidenceFeatureTitle(
                  candidate.feature.type.name,
                  candidate.feature.id,
                ),
              ),
              subtitle: Text(
                l.analysisCandidateSummary(
                  candidate.score.toStringAsFixed(1),
                  candidate.distanceMeters.toStringAsFixed(1),
                ),
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason(candidate.reason)),
                Text(
                  l.analysisScoreComponents(
                    candidate.proximityScore.toStringAsFixed(1),
                    candidate.pedestrianScore.toStringAsFixed(1),
                    candidate.directionScore.toStringAsFixed(1),
                    candidate.gpsScore.toStringAsFixed(1),
                    candidate.continuityScore.toStringAsFixed(1),
                  ),
                ),
                Text(
                  candidate.directionDegrees == null
                      ? l.analysisDirectionUnavailable
                      : l.analysisDirection(
                          candidate.directionDegrees!.toStringAsFixed(1),
                        ),
                ),
                for (final key
                    in (candidate.feature.tags.keys.toList()..sort()))
                  SelectableText('$key = ${candidate.feature.tags[key]}'),
              ],
            ),
        ],
      ),
    );
  }
}
