import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/l10n/app_localizations.dart';
import 'package:pathgrain/map/evidence/analysis_geojson.dart';
import 'package:pathgrain/map/evidence/evidence_debug_screen.dart';
import 'package:pathgrain/map/evidence/evidence_geojson.dart';
import 'package:pathgrain/map/evidence/evidence_inspector.dart';
import 'package:pathgrain/map/evidence/evidence_map.dart';
import 'package:pathgrain/map/evidence/evidence_repository.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';

import 'support/analysis_fixtures.dart';
import 'support/evidence_fakes.dart';

void main() {
  test('overlays retain original geometry, distinguish unknown edges and selected OSM', () {
    final points = straight();
    final routeBefore = EvidenceGeoJson.route(points);
    final analysis = RouteMatcher.analyze(points, [straightPath()]);
    final matches = AnalysisGeoJson.matches(analysis, 4)['features'] as List;
    expect(matches, hasLength(1));
    expect(matches.single['properties']['color'], '#AD1457');
    expect(
      matches.single['geometry']['coordinates'],
      straightPath().parts.single.map((p) => p.geoJson).toList(),
    );
    final unknown = AnalysisGeoJson.unknown(analysis)['features'] as List;
    final edges = unknown
        .where((f) => f['geometry']['type'] == 'LineString')
        .toList();
    expect(edges, hasLength(2));
    expect(edges.last['properties'], {'sequence': 2, 'fromSequence': 1});
    expect(edges.last['geometry']['coordinates'], [
      [points[1].longitude, points[1].latitude],
      [points[2].longitude, points[2].latitude],
    ]);
    expect(EvidenceGeoJson.route(points), routeBefore);
    expect(AnalysisGeoJson.matches(null, null)['features'], isEmpty);
    expect(AnalysisGeoJson.unknown(null)['features'], isEmpty);
  });

  for (final locale in ['en', 'uk']) {
    testWidgets(
      '$locale sample inspection shows analysis, scores and raw tags without extra fetches',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final l = await AppLocalizations.delegate.load(Locale(locale));
        final path = straightPath();
        final evidence = OsmEvidence(
          features: [path],
          raw: {
            'elements': [path.raw],
          },
          unparsedElements: 0,
        );
        final provider = FakeEvidenceProvider((_) async => evidence);
        final points = straight();
        var pointLoads = 0;
        EvidenceMap? latest;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EvidenceDebugScreen(
              loadPoints: () async {
                pointLoads++;
                return points;
              },
              evidenceRepository: EvidenceRepository(
                provider: provider,
                cache: MemoryEvidenceCache(),
              ),
              mapBuilder: (map) {
                latest = map;
                return TextButton(
                  onPressed: () => map.onInspect({}, {4}),
                  child: const Text('Select sample'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fetches = provider.calls.length;
        expect(
          latest!.analysis!.samples[4].surface.assignment,
          SurfaceAssignment.direct,
        );
        await tester.tap(find.text(l.analysisToggle));
        await tester.pumpAndSettle();
        expect(latest!.showAnalysis, isTrue);
        await tester.tap(find.text(l.evidenceAccuracyToggle));
        await tester.pumpAndSettle();
        expect(latest!.showAccuracy, isTrue);
        await tester.tap(find.text('Select sample'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.evidenceGpsPoint(4)));
        await tester.pumpAndSettle();
        expect(latest!.selectedSequence, 4);
        expect(find.text(l.analysisGpsState('stable')), findsOneWidget);
        expect(find.text(l.analysisSelected('way/1')), findsOneWidget);
        expect(
          find.text(
            l.analysisResult(
              l.analysisAssignment('direct'),
              l.analysisSurface('grass'),
            ),
          ),
          findsWidgets,
        );
        final scrollable = find
            .descendant(
              of: find.byType(EvidenceInspector),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text(l.evidenceFeatureTitle('way', 1)),
          180,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.evidenceFeatureTitle('way', 1)));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('surface = grass'),
          180,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(find.text('surface = grass'), findsOneWidget);
        final candidate = latest!.analysis!.samples[4].selected!;
        expect(
          find.text(
            l.analysisScoreComponents(
              candidate.proximityScore.toStringAsFixed(1),
              candidate.pedestrianScore.toStringAsFixed(1),
              candidate.directionScore.toStringAsFixed(1),
              candidate.gpsScore.toStringAsFixed(1),
              candidate.continuityScore.toStringAsFixed(1),
            ),
          ),
          findsOneWidget,
        );
        expect(provider.calls, hasLength(fetches));
        expect(pointLoads, 1);
        expect(latest!.points, same(points));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    test('$locale translates every analysis state and reason', () async {
      final l = await AppLocalizations.delegate.load(Locale(locale));
      for (final reason in AnalysisReason.values) {
        expect(
          l.analysisReason(reason.name),
          isNot(l.analysisReason('unrecognized')),
        );
      }
      for (final surface in CanonicalSurface.values) {
        expect(l.analysisSurface(surface.name), isNotEmpty);
      }
      expect(l.analysisSurface('other'), isNot(l.analysisSurface('unknown')));
    });
  }
}
