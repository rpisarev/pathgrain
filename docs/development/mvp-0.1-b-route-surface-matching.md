# MVP 0.1-B — Route and surface matching experiment

Status: implemented for development inspection and synthetic verification.
Physical-device verification of **0.1-B** is outstanding. The complete MVP 0.1
Record → Analyze surfaces → Review → Correct → Save loop remains unfinished.

## Scope and architecture

This extends [0.1-A](mvp-0.1-a-osm-map-evidence.md) inside the existing debug-only
**Surface evidence** view for an already saved walk. It makes provisional local
sample/edge assignments inspectable. It adds no packages.

The recorder, WalkPoint model, foreground service, permissions, distance
calculation, walk database schema and repository are unchanged. Every analysis
sample holds the **original immutable WalkPoint object**. No points are dropped,
moved, reordered, overwritten or inserted. Neither historical distance nor
duration is recalculated by analysis. The original blue track and accuracy
circles continue to use the stored sequence.

The implementation lives in `lib/walks/analysis/`:

- `route_analysis.dart`: immutable results for samples, original connecting
  edges, GPS assessments, scored candidates, selection, confidence and surface
  provenance.
- `gps_confidence.dart`: sample and edge assessment over the saved sequence.
- `route_geometry.dart`: small local meter-plane geometry operations.
- `route_matcher.dart`: deterministic candidate selection and edge checks.
- `surface_rules.dart`: explicit canonical mapping and one narrow inference.
- `analysis_settings.dart`: centralized provisional numerical settings.

The analysis entry point accepts only local points, already loaded OSM features
and an evidence-completeness flag. It has no database, provider, logger,
network client, wall-clock or persistence dependency. Widgets/localization and
local GeoJSON presentation stay in the existing evidence directory.

## Pipeline and evidence completeness

1. The existing read-only loader reads ordered points from WalkRepository.
2. The unchanged 0.1-A cell/cache/provider flow loads OSM evidence.
3. At the terminal evidence snapshot, the debug screen assesses GPS, generates
   candidates, finds independent winners, applies one bounded context pass,
   derives surfaces and assesses original edges.
4. The inspector and optional overlays display the in-memory result.

No analysis runs on Stop or in ordinary saved-walk details. Entering this
explicit development view runs the experiment; toggling overlays or selecting
samples makes no additional evidence requests. Manual evidence refresh clears
the previous analysis, then recomputes against the terminal snapshot.

The screen requires all requested cells to be available and no unparsed
elements before it allows assignments. A missing cell suppresses **all**
assignments for this experiment: competitors may be absent near cell edges.
Candidates and GPS assessments remain inspectable. This intentionally coarse
guard avoids inventing per-sample coverage semantics absent from 0.1-A.
A failed refresh can still analyze an entirely cached cell set; the existing
failure and cache-age notices remain visible. Availability does not establish
freshness or completeness of the OSM map itself.

## GPS confidence: both samples and edges

A sample describes whether its location is usable; an edge describes whether
the movement between two original samples is usable. Both matter: acceptable
reported accuracy alone cannot rule out a jump, and two individually matched
samples do not prove the intervening route.

These settings are **engineering hypotheses for field testing**, not thresholds
calibrated from one walk, probabilities, or changes to recorder filtering:

| Setting | Provisional value and behavior |
| --- | --- |
| Valid input | Finite coordinates; latitude within ±80° for this local experiment; finite accuracy strictly greater than zero |
| Stable accuracy range | At most 15 m |
| Reduced / poor accuracy | Above 15 through 25 m / above 25 m; both block matching and reset the stable run |
| Stable sequence | Three consecutive good samples connected by plausible edges |
| Apparent speed | Above 3.5 m/s marks **both** endpoints unreliable |
| Continuity gap | Nonpositive elapsed time, a gap above 30 s, nonconsecutive sequence numbers or a different walk ID breaks continuity |
| Isolated spike offset | Above max(10 m, 0.8 × middle-sample accuracy) from the previous-to-next chord |
| Isolated spike detour | Two-edge length above 1.8 × max(chord length, 1 m), with plausible bypass speed |

A spike requires both offset and detour conditions. The original triplet is
examined only across valid, bounded time/sequence intervals. It can be flagged
even when each leg is below the speed limit and accuracy is ordinary. The
middle sample and its adjacent edges stay UNKNOWN; speed violations may also
invalidate the neighbors.

At startup, the first two otherwise good samples are **warming up**; only the
third qualifying sample becomes **stable**. An unreliable sample resets the
run. After a previously stable run, the first two new good samples are
**recovering**, and the third is stable. Results are not backfilled: later
stability never upgrades the earlier uncertain samples. A gap sample is
unreliable; recovery starts with subsequent samples.

There is no fixed initial time window, deletion of a prefix, smoothing, or
replacement track. A short walk may remain entirely UNKNOWN. Slow genuine
turnbacks can resemble spikes; a fast walk can exceed the provisional walking
limit. Those are visible conservative errors to assess on multiple field walks.

An edge is usable only when its timing/motion is acceptable and both endpoint
GPS assessments are stable. Heading and neighbor support never cross an
unusable edge.

## Candidate geometry and walking relevance

Every renderable nearby object within **40 m** is retained for inspection,
including rejected candidates. Objects with unavailable geometry remain in the
original raw inspector but cannot have a meaningful sample distance.

The initial matcher supports complete line ways and small **convex closed way
areas** with explicit area semantics. Nodes, relation outlines, incomplete ways,
concave/self-intersecting/degenerate rings, duplicate area vertices and areas
above 64 distinct vertices are rejected. Every vertex must be within 3 km of
the sample for the local projection to be accepted. These limits intentionally
avoid a general GIS engine or relation/ring repair.

Distance uses a local spherical equirectangular meter plane; longitude deltas
wrap at the antimeridian. For a supported containing area, distance is zero,
but the sample must be farther than accuracy + 2 m from every boundary.
Uncertain pedestrian area boundaries or unsupported pedestrian geometry within
max(accuracy, 6 m) act as unresolved rivals and block selection.

The match radius is clamp(accuracy + 5 m, 8 m, 20 m). Poor accuracy never widens
this into permission to snap farther away.

Walking relevance is an explicit allowlist:

- Footway, path, pedestrian, steps, living street and crossing receive walking
  support. Cycleway and bridleway require explicit permitted foot access.
- Residential, service, unclassified, track, tertiary, secondary and primary
  roads receive weaker support.
- A road carrying a sidewalk tag other than no/none is rejected as a
  carriageway proxy: its centerline cannot establish which sidewalk was walked.
  A separately mapped sidewalk is treated as its own footway.
- Explicit foot access must be yes/designated/permissive/official. Without
  that override, restrictive or unrecognized access values block matching.
  Conditional access is not interpreted. Other highway classes are unsupported.

This is evidence filtering, not a legal routing/access engine.

## Direction, scores, ambiguity and continuity

Heading uses up to **two stable neighbors on either side**. The endpoint span
must be at least max(8 m, 2 × maximum endpoint accuracy). Otherwise direction
is unavailable. Every intermediate sample in that span must also lie within
its own reported accuracy of the endpoint chord. A turn or deviation outside
that envelope disables the chord heading, preventing one unflagged deviation
from contaminating neighboring independent matches.

Way direction requires a unique nearest nonzero segment tangent. Equally near
segments with different tangents (for example, a bend vertex) provide no
direction. Segment endpoints and tied bearings use canonical order, so reversing
OSM node order cannot choose a different tangent. Areas and unsupported geometry
provide no direction score. Ordinary motor-vehicle oneway tags are not
interpreted as pedestrian direction. A difference above **55°** rejects a
candidate.

Numerical tolerances are centralized alongside the provisional settings:
distance ties use 10⁻⁶ m, tangent equality uses 10⁻⁵ degrees, and area cross
products use 10⁻⁶ m². These handle numerical precision; they do not enlarge GPS
accuracy envelopes. The spike chord floor (1 m) and reduced GPS score (5) are
also named settings.

| Component | Score |
| --- | --- |
| Proximity | 40 × clamp(1 − distance / match radius, 0, 1) |
| Walking relevance | 20 for the walking allowlist; 8 for the road allowlist |
| Direction | 20 × clamp(1 − angle / 55°, 0, 1); 0 if unavailable, including areas |
| GPS | 10 for stable accuracy ≤10 m; 5 for other stable samples; 0 otherwise |
| Context | +12 per independently matching immediate neighbor; −6 per neighbor assigned to another object |

Eligibility is checked separately from scores; a rejected candidate cannot win.
Surface tags never affect candidate ranking. Candidates are ordered by
eligibility, descending score and OSM type/ID key for reproducible inspection.
A tie in scores remains ambiguous; the key tie-break does not create a winner.

An independent winner needs score **≥62**, margin **≥12** over the next eligible
candidate, and no ambiguity veto. Nearby candidates remain indistinguishable
when their distance difference is ≤max(accuracy, 6 m) and their direction
differences differ by ≤20°, or either direction is unavailable. This veto also
applies when their surfaces agree; shared labels do not prove object identity.

The second pass considers only the immediate previous/next **independent**
winners across stable edges. This is a frozen first-pass array, not earlier
results from the second pass. It never propagates a context-derived winner or
feeds final selections back into the anchors. Independent here means independent
of other assignments; nearby headings still share GPS observations, subject to
the chord-consistency guard above. Determinism assumes the original stored
sequence: GPS warm-up and recovery intentionally follow chronological order.
Evidence-list order and OSM node orientation do not choose the winner.
Both independent neighbors must select the same object to resolve the
parallel-candidate veto. Different independent winners on opposite sides
produce UNKNOWN. Context cannot bypass the distance, geometry, GPS, direction
or minimum-margin gates. One neighbor can strengthen a nonambiguous weak
candidate, but cannot resolve a parallel tie.

Match confidence is **none**, **supported**, or **strong**. Strong requires an
independent winner, accuracy ≤10 m, independent score margin ≥20, and usable
direction or a supported area. A winner relying on context is only supported.
These labels and component scores express provisional evidence support, never
a probability of correctness.

## Original edges, not final surface segments

An original edge gets a surface only if both endpoints have stable GPS, select
the same OSM object and have a known surface. Local probes at 25%, 50% and 75%
of the original edge must also stay inside the smaller endpoint match radius
(or safely inside the matched area). A chord that cuts away from a bent way is
therefore UNKNOWN even with matching endpoints.

Probes are transient local geometry checks, never stored WalkPoints or provider
inputs. Object transitions remain UNKNOWN; no graph routing or interpolation
through a junction is attempted. Edges retain reasons and apparent speed.
There is no distance allocation, merging into final segments, or claim that
three probes establish every location between samples.

## Canonical taxonomy and surface provenance

The initial experiment taxonomy is grass, asphalt, concrete, soil/ground,
gravel, paving stones, other known material, and unknown. It is provisional for
this slice; it does not finalize the future correction UI.

**DIRECT** means the defensibly matched object has an explicit supported
`surface=*` value. It describes source provenance, not surveyed ground truth.
**INFERRED** means the single documented non-surface rule below applies.
**UNKNOWN** covers GPS uncertainty, incomplete coverage, unsupported geometry,
weak/tied/conflicting candidates, and missing, broad or conflicting surface
evidence. A selected OSM object can still have an UNKNOWN surface.

Centralized direct mapping (trimmed, lowercase exact values):

| OSM surface value | Canonical surface |
| --- | --- |
| grass | grass |
| asphalt | asphalt |
| concrete, concrete:plates | concrete |
| ground, dirt, earth, soil | soil/ground |
| gravel, fine_gravel, pebblestone | gravel |
| paving_stones, sett | paving stones |
| cobblestone, unhewn_cobblestone, wood, metal, sand, mud, rock, rubber | other known material |

All other values remain UNKNOWN, including paved, unpaved, compacted,
concrete:lanes, paving_stones:lanes, grass_paver, empty strings and typos.
Semicolon mixtures remain UNKNOWN even if all members are recognized.
Directional, side-specific, lane-specific and conditional surface tags are
not resolved. OTHER is an allowlist of explicit materials outside the initial
taxonomy; it is never a fallback for an unknown tag.

The only inference is **grass from `landcover=grass` on the same matched,
complete, convex pedestrian/footway area**, with the accuracy envelope safely
inside the area. It requires `surface` to be absent. A line carrying landcover,
a neighboring park, landuse, highway class, tracktype, material or smoothness
does not trigger it. An explicit unsupported surface prevents fallback.
Explicit non-grass surface conflicting with grass landcover on the same area
also remains UNKNOWN. This inference is intentionally narrow and may be rare
in the currently fetched evidence.

The tag meanings were checked on 2026-09-07 against the OSM
[surface documentation](https://wiki.openstreetmap.org/wiki/Key:surface) and
[grass landcover documentation](https://wiki.openstreetmap.org/wiki/Tag:landcover%3Dgrass).
The latter describes area coverage. Using it to infer a walking surface after
strict same-area matching is **this experiment's inference**, not an OSM
guarantee. No surface is inferred from what a road usually looks like.

## Diagnostic use and privacy

The existing raw OSM inspector, GPS samples, accuracy circles, provider/cache
status, attribution and plain-map fallback remain available in English and
Ukrainian. Expand a GPS sample to see:

- sequence and original reported accuracy;
- GPS state and reasons;
- selected OSM key or none, match confidence and assignment reason;
- DIRECT / INFERRED / UNKNOWN, canonical surface and surface reason;
- adjoining original edges, apparent speed, GPS/assignment reasons and surfaces;
- nearby candidates, score components, direction difference, rejection reason
  and expandable raw tags.

Expanding a sample selects it and enables the analysis overlay. Close the sheet
to compare the map. **Matching / UNKNOWN** can also be toggled independently:

- cyan shows the entire matched OSM object geometry;
- magenta highlights the selected sample and its chosen object, if any;
- red sample rings and offset dashed original edges mark UNKNOWN surfaces;
- the original blue route remains visible; GPS accuracy circles are independent.

Whole-object highlighting is not a claim that the entire OSM way was walked.
UNKNOWN includes both unmatched locations and matched locations lacking a
defensible surface. The sheet's reason distinguishes these cases.

Matching sends nothing anywhere. The 0.1-A cell-only Overpass interface,
request order, cache namespace and basemap privacy disclosures are unchanged.
Neither ordered points nor timestamps enter requests. Derived scores and
GeoJSON remain local, with no logging, telemetry, export, database writes or
new cache fields. No real field coordinates are in source, tests or this note.

## How the Pixel walk informed the design

The user reported a physical Pixel walk on **2026-09-07** with duration **10:28**,
**130** stored samples and saved distance **1105.2 m**. Accuracy was median
**8.82 m**, p90 approximately **14.9 m**, and maximum **38.74 m**.

The first five reported accuracies were **33.3, 38.7, 25.7, 14.8, 7.6 m**.
The first apparent movement was **53.5 m in 12.4 s**. Omitting the first three
samples would change geometric length by approximately **74 m**. A later
movement was approximately **17.5 m in 4.5 s** despite accuracy around
**13–15 m**.

Those observations motivate accuracy-dependent stabilization, motion checks
independent of reported accuracy, retention of original data, and explicit
UNKNOWN edges. They do not establish final thresholds. Synthetic fixtures use
a fabricated meter grid near (1°, 2°), including similar accuracy/time/geometric
patterns; they do not reconstruct the field route.

The supplied aggregates do not establish native 0.1-B rendering, matching
correctness, Home/screen-lock behavior, or 0.1-A cache/map interaction results.
No physical device test was performed during this implementation.

## Known failure modes and deferred work

Urban multipath, persistent bias and slowly drifting but plausible GPS can evade
the rules. Real fast walking, sharp turns and turnbacks can be conservatively
flagged. Sparse samples, pauses, short walks, weak headings, close parallel
paths and intersections can yield extensive UNKNOWN results. Context uses OSM
identity rather than network topology, so split ways and legitimate transitions
are often unresolved.

OSM can be stale, incomplete, wrongly tagged or offset. Nearby bridges, tunnels
and stacked features are not resolved using vertical topology. Relation
interiors, large/concave areas, missing geometry and long ways exceed current
support. Missing OSM objects cannot be discovered from a complete cell response.
The 0.1-A bbox/node-selection limitations still apply. Three edge probes can
miss narrow competing features or complex intermediate geometry.

The analyzer runs synchronously for small development walks; dense evidence
and large walks need physical responsiveness checks. No spatial index,
map-matching framework or production-scale performance claim is included.

Deferred: final segmentation UI, surface distance breakdown/reconciliation,
derived-segment persistence/migrations, user corrections and persistence,
automatic post-Stop analysis, robust graph matching, production provider/map
infrastructure, backend, accounts, cloud and community features.

## Concrete next physical-device procedure

1. Install the debug APK over the existing app without uninstalling or clearing
   data. Open a previously saved walk and note its duration, distance and point
   count. Do not copy/export coordinates or tracks into repository artifacts.
2. Open its overflow menu → Surface evidence → Open development view. Wait for
   the terminal evidence status. Check cell counts, cache age and any failures.
   In a partial result, verify that assignments remain UNKNOWN.
3. Use Inspect data to expand the earliest samples. Check reported accuracies,
   warming/unreliable states, speed/spike reasons and the transition through
   three consecutive good samples. Confirm earlier uncertain samples stay
   UNKNOWN once later samples stabilize.
4. Enable Matching / UNKNOWN and GPS accuracy circles. Expand/select a sample,
   close the sheet, and inspect the magenta sample/object, cyan OSM geometry,
   red UNKNOWN rings/offset dashes and unchanged blue track. Test native map
   taps on overlapping GPS/OSM features and UNKNOWN edges. Scroll the top
   notice area for the legend if needed; repeat in Ukrainian.
5. Record a new varied walk: an unambiguous path, a sidewalk parallel to a road,
   a crossing, a turnback, and a pedestrian area where available. Include Home
   and screen-lock intervals. Safely note the observed surface changes and
   approximate elapsed times for personal local comparison.
6. After Stop, verify ordinary history/review still works and does not start
   analysis. Open the development view and inspect stable straight samples,
   startup recovery, sharp shapes with ordinary accuracy, parallel candidates,
   rejected directions and UNKNOWN object transitions.
7. Check explicit surface tags produce DIRECT only after matching; missing,
   broad and conflicting tags stay UNKNOWN. Inspect an INFERRED result only if
   a qualifying same-object grass area actually exists. Do not expect a nearby
   park to supply the path's surface.
8. Close/reopen the view to test cache reuse. Toggle overlays and inspect
   samples without increasing fetched counts. Disable connectivity and use
   cached evidence / the existing plain map fallback. Missing coverage must
   remain UNKNOWN; a fully cached result can still be analyzed locally.
9. Reopen ordinary saved details and compare duration, distance, point count
   and the raw route with step 1. Reopen old walks after app restart. Record
   actual Home/screen-lock and native-map results separately from unit tests.
10. Report aggregate counts of matching/UNKNOWN cases, reasons, observed
    surface mismatches and responsiveness across several walks. Keep real
    coordinates, ordered timestamps, database exports and coordinate-bearing
    screenshots out of repository docs, fixtures and logs.

## Automated verification

Synthetic tests cover warm-up and recovery, ordinary-accuracy speed anomalies
and lateral spikes, good paths, parallel/crossing candidates, deterministic
ordering, missing/ambiguous/conflicting surfaces, explicit aliases, narrow area
inference, incomplete geometry, bend-cutting edges, local overlays, both
locales and inspector interactions without additional provider calls.

The full 0.1-A cache/provider/privacy and Prototype 0.0 recorder/database suite
must also pass. Widget tests substitute for the native map and contact neither
Overpass nor basemap services. They do not verify native rendering or physical
background recording.

Verified on **2026-09-07**:

- Localization generation succeeded and changed Dart files were formatted.
- `flutter analyze`: **no issues found**.
- `flutter test`: **74 tests passed**, including the unchanged evidence
  cache/provider/privacy and recorder/database regression tests.
- `flutter build apk --debug`: **succeeded**.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: clean.

The Android build emitted the existing Gradle Java native-access warning and
the `maplibre_gl` Kotlin Gradle Plugin / future Built-in Kotlin migration
warning. Neither prevented the debug build. No live Overpass query or physical
device verification was performed during this implementation.

Changed files: six pure-Dart files in `lib/walks/analysis/`; the existing
`evidence_debug_screen.dart`, `evidence_inspector.dart` and `evidence_map.dart`;
new `analysis_details.dart` and `analysis_geojson.dart` beside them; English and
Ukrainian ARBs plus their three generated localization files;
`test/route_matcher_test.dart`, `test/route_geometry_test.dart`,
`test/surface_rules_test.dart`, `test/analysis_diagnostics_test.dart` and
`test/support/analysis_fixtures.dart`; this note and the narrowly updated
0.1-A status note.
