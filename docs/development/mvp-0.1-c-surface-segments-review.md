# MVP 0.1-C — Surface segments and read-only walk review

Status: implemented; automated verification and focused physical Pixel review
observations are recorded below. This was not exhaustive production validation.
The complete MVP 0.1 correction/save loop was not complete at 0.1-C.

## Purpose and boundary

Turn the conservative [0.1-B edge analysis](mvp-0.1-b-route-surface-matching.md)
into an honest whole-walk journal: ordered original-route segments, distance
by surface, UNKNOWN distance by reason, and a normal read-only saved-walk review.
There is no new matching, smoothing, gap filling or surface inference.

The recorder, accepted points, filtering policy, foreground service, walk
models/repository, distance utility, walk schema and existing migrations remain
unchanged. No packages were added. No analysis data is persisted.

## Architecture

The local pipeline is:

```text
saved WalkPoint sequence
  + existing 0.1-A fixed-cell evidence/cache
  → unchanged RouteMatcher / RouteAnalysis
  → SurfaceSegmenter
  → WalkSurfaceSummary
  → normal surface review + separate debug diagnostics
```

- `lib/walks/analysis/surface_segmenter.dart` defines immutable
  `SurfaceSegment` values and deterministic segmentation.
- `lib/walks/analysis/walk_surface_summary.dart` aggregates unrounded meters by
  canonical surface and UNKNOWN surface reason. It retains the original
  immutable analysis, so per-edge/sample provenance remains available.
- `EvidenceSnapshot.hasCompleteCoverage` centralizes the existing terminal,
  all-cell, no-unparsed-elements guard. Both screens use the same guard.
- `WalkSurfaceReviewScreen` orchestrates the existing read-only points loader
  and evidence repository. Segmentation, distance allocation and aggregation
  remain outside widgets.
- `SurfaceRouteGeoJson` creates only local original-point slices;
  `WalkSurfaceMap` renders them with MapLibre.
- The debug inspector receives the same summary type through
  `SurfaceSummaryDetails`.

## Segment compatibility

A segment stores a half-open range of **edge list indices**
`[startEdgeIndex, endEdgeIndex)`, not GPS sequence numbers. Its original
geometry is samples `startEdgeIndex` through `endEdgeIndex`, inclusive.
Adjacent segments share their boundary point but never an edge. A sequence
number/time gap does not delete the original connecting edge.

Two adjacent edges merge if and only if all these values agree:

1. canonical surface;
2. surface assignment (DIRECT / INFERRED / UNKNOWN);
3. surface reason;
4. edge reason;
5. ordered pair of selected endpoint OSM keys, including nulls.

OSM keys contain type and ID. Equal keys across separate feature instances
compare equal. For example, `(way/1, way/2)`, `(way/2, way/1)`,
`(way/1, null)` and `(null, null)` are distinct provenance.
`sourceFeatureKey` returns the shared endpoint key only when the keys agree.
On an UNKNOWN segment this is evidence provenance, not proof that its entire
edge lies on the selected object; endpoint objects remain in the analysis.

This preserves object transitions and different UNKNOWN explanations without
splitting on fluctuating scores, confidence, accuracy, or sample-level
independent/context support. Those details remain on the original samples.
The implementation is one ordered pass, not a graph or generic framework.

An asphalt → UNKNOWN → asphalt sequence always stays three segments, including
when the UNKNOWN edge has zero distance. There is no minimum segment length,
snapping, interpolation, bridging, relabeling or taxonomy expansion.

## Distance allocation and reconciliation

Every input edge is allocated exactly once, in order, including UNKNOWN, GPS
warm-up, poor-accuracy, speed/spike, sequence-gap and stationary edges. An
analysis-unusable GPS edge can still have a valid original geometric distance.

Each edge uses `WalkDistance.betweenCoordinates`, the same spherical haversine
calculation and 6,371,000 m radius used by `WalkDistance.total` and
`WalkRepository.finishWalk`. No matcher meter-plane distance, OSM length,
projected point, probe or reconstructed path enters the totals.

A segment sums its original edge distances. The summary sums segments and
groups their meters by `CanonicalSurface`. Only categories present on edges
appear, including UNKNOWN even when its allocated distance is zero. Empty
analyses have no artificial segments or categories. Raw doubles remain
available; no percentage or rounding is applied in the domain model.

The only numeric difference from the saved total is floating-point addition
grouping. `reconcilesWith` allows max(10⁻⁶ m, |saved meters| × 10⁻¹²), not display
rounding. Tests compare each range to the original points, enumerate every
allocated edge, reconcile category and reason totals, and compare against
a walk completed through the actual SQLite repository. A differing saved
total is visibly disclosed; neither total is rescaled or rewritten.

Normal review reuses existing formatting: nearest whole meter below 1 km,
otherwise two decimal places in kilometers. Rows and totals round independently;
the UI explains why displayed numbers can differ slightly when added. Debug
totals use meters to one decimal place.

## UNKNOWN diagnostics

UNKNOWN is a normal segment, a normal breakdown category and a red map line.
Missing/incomplete evidence never becomes a guessed surface.

`unknownDistanceByReason` uses exactly the existing
`edge.surface.reason` / `AnalysisReason` enum. Current matcher outcomes include
`uncertainEndpoint`, `invalidSample`, `fastMotion`, `isolatedSpike`,
`sequenceGap`, `evidenceIncomplete`, `noCandidate`, `weakScore`,
`ambiguousCandidates`, `conflictingNeighbors`, `differentObjects`,
`edgeOffGeometry`, `missingSurface`, `unsupportedSurface` and
`conflictingSurface`. No alternate reason taxonomy or diagnostic inference
was added.

Each UNKNOWN edge contributes to exactly one primary reason. Secondary causes
are not summed again. In particular, `uncertainEndpoint` may cover warming up,
recovery or poor accuracy: expand its endpoint GPS samples to distinguish them.
`noCandidate` does not by itself prove absent OSM surface tags; rejected
candidate details remain in the existing inspector.

Saved walk → overflow → **Surface evidence** → **Open development view** →
**Inspect data** → **UNKNOWN distance by reason** shows the whole-walk UNKNOWN
total, total analyzed distance, segment count and meters per reason. The title
explicitly indicates the whole walk even when inspecting one selected sample.
Expanding this section does not issue evidence requests. Matcher internals
remain in the debug-only flow.

## Normal review and network access

Saved walk → **Surface review** → **Analyze surfaces**.
The review entry is available outside debug builds. Entering it reads only the
saved points. A localized explanation precedes the explicit analysis action;
that action loads the existing evidence cache and fetches missing fixed cells.
Stopping a walk and opening ordinary details do not start evidence requests.

The review shows date/time, status, saved distance, duration, point count,
surface distances, total surface distance, a matching color legend and the map.
All strings use the English/Ukrainian localization infrastructure. There are
no scores, OSM IDs, candidate margins or correction controls in this view.

The map uses one LineString for each segment's exact original-point slice.
A white halo and distinct surface colors separate it from the basemap. UNKNOWN
uses red. OSM ways are never drawn as the walked route. The camera fits the
original route; pan/zoom gestures work independently inside the scrolling
review. Degenerate stationary bounds do not trigger a native bounds fit.

If the style/layers fail or do not finish within 20 seconds, the user can choose
**Use plain map**, which replaces the basemap with a local background and keeps
the original surface geometry. The distance table remains usable. This does not
provide offline tiles. MapLibre owns its native controller; stale callbacks
after a fallback switch cannot initialize the replacement map.

The Overpass endpoint, request payloads/order, shared cooldown, no-automatic-
retry policy and disposable evidence cache are unchanged from
[0.1-A](mvp-0.1-a-osm-map-evidence.md). This extends explicit use of that
**provisional field-test provider** to the normal review; it does not select a
production provider or authorize broad deployment. Basemap and evidence
attribution remain visible.

No ordered track, timestamps, walk IDs or analysis geometry enter evidence
requests. Full tracks and analysis stay local. Remote providers still observe
requested areas, IP addresses and request times, as the review explains.
No new logging, telemetry, backend, sync or export was added.

## Empty, unavailable and malformed states

- Zero/one saved point: basic walk information and an insufficient-points
  message; no evidence fetch or fabricated surface.
- Two points, repeated points and near-zero edges: retain original distance and
  UNKNOWN as emitted by the matcher. Poor accuracy never causes distance loss.
- No OSM features: complete route retained as UNKNOWN.
- Missing cells or unparsed elements: unchanged coarse 0.1-B guard suppresses
  classifications for the whole route; the review explains unavailable data.
  GPS reasons can take precedence over incomplete-evidence reasons.
- Manual retry reuses cached successful cells and asks only for missing ones;
  the provider cooldown still applies. Existing debug refresh can replace cache.
- Local/evidence-loading exceptions: a localized error and explicit retry.
  Leaving the view stops later cell requests; an in-flight cell can finish its
  cache write before the owned connection closes.
- Missing/extra/reordered/duplicated analysis edges, inconsistent UNKNOWN
  assignment or invalid geographic coordinates: reject the summary rather than
  drop edges or publish partial meters. The debug screen preserves low-level
  analysis when a summary cannot be built. Valid coordinates outside the
  matcher's supported latitude still retain their original UNKNOWN distance.

## Automated verification

New focused coverage lives in:

- `test/walk_surface_summary_test.dart`: merge boundaries, ordered provenance,
  reason aggregation, gaps, zero/near-zero edges, long and alternating routes,
  deterministic output, invalid input, immutability and all distance invariants.
- `test/surface_route_geojson_test.dart`: exact original coordinate slices,
  complete ordered edge coverage, UNKNOWN color, empty routes and no OSM
  geometry/provenance/timestamps in the presentation data.
- `test/walk_surface_review_screen_test.dart`: multiple surfaces in both
  locales, UNKNOWN diagnostics, saved-detail navigation, empty routes,
  loading/failure/retry, unavailable/unparsed evidence, cache reuse, disposal,
  saved-distance mismatch, invalid coordinates and timeout/fallback UI.
- `test/walk_surface_repository_test.dart`: actual SQLite saved-distance
  reconciliation and unchanged saved walk/point values.
- `test/support/surface_fixtures.dart`: fabricated edge outputs and synthetic
  OSM features, using the existing artificial meter grid.

Verification on **2026-09-08**:

- `flutter gen-l10n`: succeeded for English and Ukrainian.
- `dart format`: all 18 changed/new Dart files clean on the final pass.
- `flutter analyze`: **no issues found**.
- New focused coverage: **33 passing tests**, including SQLite reconciliation.
- `flutter test`: **125 tests passed**, including all existing 0.0/0.1-A/0.1-B
  tests. A syntax error in a new test fixture was corrected during development;
  no test failures remain.
- `flutter build apk --debug`: **succeeded**.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Tracked and new-file whitespace checks: clean.

The build emitted the existing Gradle Java native-access warning and the
`maplibre_gl` Kotlin Gradle Plugin / future Built-in Kotlin migration warning.
Neither prevented the debug build.

The automated implementation checks above did not themselves establish
physical-device acceptance. Widget tests use substitute maps for review
integration; the fallback test exercises Flutter timeout/switch controls without
native drawing or remote tiles. The subsequent focused Pixel observations are
recorded separately below; Home/screen-lock recorder behavior is not established
by these review checks.

## Physical Pixel observations and later frozen-data verification

The real 0.1-C read-only review was exercised on a physical Pixel using existing
saved walks. Observed behavior included:

- Surface Review opened and analyzed real saved walks.
- Surface distance reconciled with saved walk distance.
- Original GPS geometry appeared as surface-colored segments.
- Known concrete, paving-stones and asphalt examples were correctly represented.
- A particularly useful example selected a paving-stones pedestrian sidewalk
  rather than a nearby parallel asphalt vehicle road.
- UNKNOWN remained visible rather than being filled; UNKNOWN-by-reason
  diagnostics were exercised.

A frozen export of the **3,775.4 m** walk subsequently reproduced the phone
analysis exactly at display precision. This field work exposed matcher ambiguity
patterns and supported the later narrow retained crossing-node correction.

The final retained crossing-node v2 refinement was verified against the frozen
Pixel dataset and automated tests, as recorded in the
[0.1-B note](mvp-0.1-b-route-surface-matching.md). The repository does not establish
that a new APK containing that exact final patch was separately exercised on the
Pixel. Frozen-data verification must not be described as new physical acceptance
of that patch.

These observations establish focused real-device review behavior, not exhaustive
matching quality, production readiness, broad native-map/cache coverage or
recorder Home/screen-lock acceptance. Corrections and durable analysis/save were
still absent at 0.1-C.

## Intentional limits and next milestones

Matcher conservatism and all existing 0.1-A/0.1-B limitations remain. Analysis
still runs synchronously on small walks; dense evidence and long-route
responsiveness need device testing. Coincident outbound/return geometry can
overlap on the map, even though all traveled edges count independently.
Antimeridian camera fitting and extreme latitudes retain the existing map
limitations. Colors and edge-sized transition boundaries are provisional.

The existing taxonomy is unchanged. OTHER still groups known materials such as
sand, wood, metal, mud and rock; unsupported/broad values remain UNKNOWN.
Whether those categories are useful for barefoot journals is a later product
decision informed by these field results.

Deferred: derived-result persistence/migrations, user corrections and overrides,
correction selection/propagation, re-analysis versioning, automatic post-Stop
workflow, production provider decisions, graph matching, final visual design
and full MVP 0.1 acceptance. Backend, accounts, sync and community features
remain outside scope.

## Pixel field handoff

Install the debug APK over the existing app without uninstalling or clearing
data. Keep real tracks, timestamps, database exports and coordinate-bearing
screenshots out of repository artifacts.

1. Open a saved walk and note its saved distance/duration/point count. Open
   Surface review and Analyze surfaces. Does total surface distance reconcile
   with the saved distance, allowing the stated display rounding?
2. Compare colored transitions with the actual walk and the original route.
   Are short red UNKNOWN gaps visible between repeated equal surfaces?
3. Does the breakdown, including UNKNOWN, look plausible for the surfaces
   walked? Try a largely known route, an all-UNKNOWN/short route and a route
   with repeated transitions.
4. Pan and zoom the map, scroll between it and the breakdown, and revisit a
   long or overlapping route. Check both locales. With cached evidence and
   connectivity disabled, test the plain-map fallback and readable totals.
5. Use the separate debug inspector's UNKNOWN distance section. Is uncertainty
   dominated by missing tags, unsupported/conflicting tags, GPS/sequence issues,
   ambiguous candidates, object transitions, geometry or unavailable cells?
   Expand relevant samples for causes hidden behind uncertainEndpoint.
6. Reopen the review to check evidence-cache reuse; analysis itself recomputes.
   Reopen ordinary details and old walks to verify their original values.
7. Record a new walk with Home/screen-lock intervals as a recorder regression
   check. Report actual Pixel observations separately from automated results.
