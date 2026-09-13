# Current local recorder and surface pipeline

Current architecture/reference as of MVP 0.2-A. Implementation takes precedence
when auditing this document. [README](../../README.md) owns the project overview;
[0.2-A](../product/mvp-0.2-a.md) owns this milestone's scope. A–F development notes
record their completion states, not competing current schema specifications.

## Recording and Android acceptance

`WalkRecordingController` owns the location stream across Flutter lifecycle
events. `GeolocatorLocationRecorder` supplies fixes; `LocationPointFilter`
accepts them before ordered SQLite writes. Current recording settings request
high accuracy, a 5 m distance filter and a 5 s Android interval. The application
filter rejects accuracy above 50 m, displacement below 3 m and apparent speed
above 8 m/s, as well as invalid samples. These settings are distinct from the
stricter analysis confidence rules; the saved database cannot reconstruct fixes
that the recorder rejected.

Normal Stop cancels delivery and drains already admitted points through the
filter/write queue before completing the walk and calculating distance from
stored points. Startup recovery marks unfinished recordings interrupted and
retains stored points; it does not resume a dead process. Permissions and the
location foreground service remain behind the existing recorder interface.
There is no `ACCESS_BACKGROUND_LOCATION` permission. Recording is not promised
through force-stop, vendor process killing or reboot.

The initial Android MVP cycle was physically accepted on a new Pixel walk,
including Home, screen lock/unlock and Stop/save; see
[E's physical acceptance record](../development/mvp-0.1-e-final-integration-acceptance.md#final-physical-pixel-acceptance).
[F](../development/mvp-0.1-f-barefoot-surface-taxonomy.md#physical-pixel-acceptance)
separately records the taxonomy upgrade and journal spot-check. These are
bounded acceptance records, not exhaustive Android/iOS validation. 0.2-A adds
host replay verification, not another physical-device acceptance claim.

## Authoritative SQLite storage

`lib/walks/app_database.dart` defines **schema version 3** in `pathgrain.sqlite`.

| Table | Stored fields and purpose |
| --- | --- |
| `walks` | `id`, `started_at_ms`, nullable `ended_at_ms`/`duration_ms`, `distance_meters`, `status` (`recording`, `completed`, `interrupted`) |
| `walk_points` | `id`, `walk_id`, `sequence`, `latitude`, `longitude`, `recorded_at_ms`, `accuracy_meters`; unique `(walk_id, sequence)` and ordered lookup index |
| `walk_surface_analyses` | One automatic snapshot header per `walk_id`: `point_count`, `points_valid` |
| `walk_surface_segments` | `walk_id`, `ordinal`, half-open `start_edge`/`end_edge`, `surface`, `assignment`, `surface_reason`, `edge_reason`, nullable `from_feature_key`/`to_feature_key` |
| `walk_surface_corrections` | `walk_id`, original `start_edge`/`end_edge`, canonical `surface`; primary key `(walk_id, start_edge, end_edge)` |

Foreign keys cascade walk deletion through points and the journal. Point insert,
update and delete triggers invalidate the associated snapshot's `points_valid`
marker. **`points_valid=1` establishes snapshot point-sequence integrity, not
accurate GPS or successful surface matching.** Segment meters/geometry are
reconstructed from the original points; they are not separate stored tracks.

Schema 1→2 added the surface tables. Schema 2→3 conservatively converted legacy
`pavingStones`, `gravel` and `other` automatic/corrected values to `unknown`;
automatic rows use `legacySurfaceAmbiguous`. It preserves correction ranges and
precedence. Fresh databases use v3; migration never queries the evidence cache.
The exact conversions and current taxonomy are maintained in
[F's mapping and migration reference](../development/mvp-0.1-f-barefoot-surface-taxonomy.md).

`WalkSurfaceRepository` checks the exact point sequence transactionally before
saving. Automatic segments and corrections remain separate. Re-analysis
replaces automatic segments and preserves corrections; effective surfaces overlay
corrections by original edge range. Save of the current automatic label removes
a redundant correction; Restore automatic removes the override explicitly.
Opening the saved journal and editing corrections need neither OSM cache nor
network access. Failures preserve the last successful journal.

## Explicit analysis and evidence

Saved walk → **Surface Review** → **Analyze surfaces** (or **Re-analyze surfaces**).
Opening review loads the local journal; it does not itself trigger analysis.
Stopping a walk, reopening a journal and upgrading the app do not automatically
analyze. “Automatic” describes how labels are derived after the explicit action.
The separate debug-only Surface evidence view starts an in-memory analysis when
entered and exposes raw candidates/tags; its refresh is explicit.

1. `GeographicCell.covering` selects sorted unique zoom-15 cells occupied by
   saved samples. There is no interpolation/corridor cell selection. Each query
   has fixed 30 m padding, independent of accuracy and route order.
2. `EvidenceRepository` reads every required cell from the disposable cache
   before sequentially fetching missing cells with `OsmEvidenceProvider`.
   Failed fetches stop the batch; successful cached evidence remains available.
3. The provisional Overpass query requests highway nodes/ways/relations and
   `area:highway` ways/relations, with body geometry. It does not filter for
   material. `OsmEvidence.parse` retains raw tags, geometry, node memberships
   and parser limitations. A response with `remark` is rejected as incomplete.
4. `EvidenceAssembly` deduplicates type/ID identities. Newest fetched cell wins;
   numeric cell order breaks equal-time ties. Features are sorted by key. This
   is the same assembly used by fixed-input replay.
5. Matching requires a terminal snapshot with at least one required cell, every
   required cell available, and zero unparsed elements. This whole-walk gate
   establishes captured coverage, not freshness or completeness of OSM itself.
   Normal review persists only a successful complete analysis; incomplete or
   failed evidence cannot replace a saved journal.

The separate `pathgrain_osm_evidence_cache.sqlite` has schema version 1 and
`evidence_cells(namespace, cell, fetched_at_ms, evidence_json)`, keyed by
`(namespace, cell)`. The namespace includes endpoint, query version, zoom and
padding. Successful cells, including empty results, remain reusable until
explicit refresh; there is no automatic expiry/eviction. It contains no walk
IDs or journal/correction tables. Raw snapshots can overlap and differ in age.

Overpass receives fixed cell bounds, not ordered points, timestamps or walk IDs.
OpenFreeMap/MapLibre basemap access is separate. Providers can observe requested
areas and network metadata. These remain provisional providers, with no backend,
analytics, sync or community infrastructure. Provider protocol details and the
dated original terms review remain in [A](../development/mvp-0.1-a-osm-map-evidence.md).

## Matching, materials, edges and review

`RouteMatcher.analyze` is synchronous and pure. It preserves every original
sample/edge; it never smooths, drops, resamples or replaces recorded geometry.

- `GpsConfidence` assesses invalid/reduced/poor accuracy, gaps, speed and spikes,
  then warming-up/recovery/stability. Normal stable accuracy is ≤15 m; three
  good samples are required; apparent speed >3.5 m/s blocks analysis. Thus a
  point accepted by the recorder can legitimately be unreliable for matching.
- `RouteGeometry` generates candidates in a **40 m** envelope. Complete local
  line ways and small convex closed way areas are supported. Concave areas,
  relation topology, incomplete/oversized geometry and nodes are not generally
  matchable. Unsupported nearby pedestrian geometry can still veto a winner.
- Eligibility applies walking/access/sidewalk rules, distance within
  clamp(accuracy + 5 m, 8 m, 20 m), area boundary clearance and direction ≤55°.
  A supported containing area needs clearance greater than accuracy + 2 m.
- Scores use proximity, walking relevance, available heading and GPS support.
  Independent choices require score ≥62, margin ≥12 and no ambiguity veto.
  The parallel veto can reject a much weaker pedestrian rival within the
  uncertainty envelope. The narrow independent footway-over-road and redundant
  crossing-node exceptions remain unchanged. Material tags never rank candidates.
- Frozen independent winners supply one immediate-neighbor context pass (+12
  for the same feature, −6 for another). Context winners never become recursive
  anchors. GPS, incomplete evidence and conflicting neighbors override choices.
- Only selected features receive automatic material assignments.
  `SurfaceRules.directMapping` maps 29 explicit raw values to 14 known barefoot
  categories; `unknown` is the fifteenth category. See F for the single complete
  mapping table. Missing tags, unsupported values (including generic `gravel`),
  mixtures and scoped conflicts remain unknown. The existing narrow safely
  containing pedestrian grass-area inference is retained; no highway-to-material
  inference exists.
- Each original edge requires stable GPS, both endpoint selections, the same
  feature key, successful interior probes at ¼, ½ and ¾, and known endpoint
  surfaces. The first failing edge gate determines its reason. A lone known
  sample does not establish adjacent known meters.
- `SurfaceSegmenter` merges only adjacent edges with identical surface,
  assignment, surface reason, edge reason and ordered endpoint feature keys.
  `WalkSurfaceSummary` accounts for all original haversine meters, including
  unknowns. Segmentation does not invent/reject assignments.
- `SurfaceJournal` applies persisted user corrections for the effective review.
  MapLibre renders original point slices; unknown is red. The surface list and
  distance breakdown remain available when the basemap fails. No confidence
  gate exists in persistence or map coloring that relabels valid known edges.

`AnalysisSettings` and the production matcher are the numerical source of truth;
[B](../development/mvp-0.1-b-route-surface-matching.md) records the scoring
development and existing exceptions. Passing regression tests does not establish
that this provisional pedestrian matching policy is well calibrated.

## Diagnostics and the next boundary

0.2-A adds opt-in chooser traces, deterministic offline replay, per-sample/edge
audits and versioned JSON. It adds no walk schema, storage, UI, matching or
classification policy changes. See the
[0.2-A diagnostic guide](../development/mvp-0.2-a-surface-diagnostics-replay.md)
for export contracts, commands, privacy handling and walk-8 evidence.

The new ~1.45 km field walk has zero known meters because source sparsity and
matcher limitations coexist. Recorder/storage acceptance remains valid; reliable
surface coverage is now the main technical/product problem. Future policy work
must compare additional field walks and unsupported assignments, not optimize
only for a larger known-meter total on walk 8.
