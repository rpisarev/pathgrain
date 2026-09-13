# MVP 0.1-D — Surface corrections and local persistence

> **Later-status / document role**
>
> Historical completion note (0.1-D). Schema 2 and the original taxonomy below
> describe D's implementation. [F](mvp-0.1-f-barefoot-surface-taxonomy.md) subsequently
> migrated to schema 3 and the current 15 categories. E completed a new physical
> Android walk through the loop; F separately spot-checked its upgrade. The
> [current pipeline reference](../reference/surface-pipeline.md) owns present schema
> and journal behavior; [0.2-A](mvp-0.2-a-surface-diagnostics-replay.md) adds replay.

Status: implemented and physically spot-checked on a Pixel using an existing
saved walk. Automated verification and focused physical acceptance are recorded
below. This is not exhaustive production validation or final MVP 0.1 acceptance.

## Purpose and boundary

Complete the local Analyze → Review → Correct → Save slice for an already saved
walk. Extend the existing recorder and C review. Stopping a recording still only
saves the walk; evidence access remains an explicit action in Surface Review.
No matcher, GPS filtering, foreground-service or taxonomy behavior changes.
The retained crossing-node v2 correction is baseline behavior, not a D refinement.
No packages were added.

## Models and durable schema

`pathgrain.sqlite` advances from schema **1 to 2**. `AppDatabase` adds the following
three tables on both creation and upgrade, without rewriting walks or points:

| Table | Columns and purpose |
| --- | --- |
| `walk_surface_analyses` | `walk_id` primary key / cascading walk FK; `point_count`; `points_valid` (0/1). One current automatic snapshot header and its point-sequence integrity marker. |
| `walk_surface_segments` | `walk_id` cascading header FK; `ordinal`; `start_edge`, `end_edge`; `surface`, `assignment`, `surface_reason`, `edge_reason`; nullable `from_feature_key`, `to_feature_key`. Primary key `(walk_id, ordinal)`. |
| `walk_surface_corrections` | `walk_id` cascading header FK; `start_edge`, `end_edge`; `surface`. Primary key `(walk_id, start_edge, end_edge)`. Each row is a separate user observation. |

Range checks and foreign keys protect basic structure in SQLite; the repository
also validates complete coverage, ordering, enum names and correction overlap.
Old walks simply have no surface header until explicitly analyzed successfully.
No database reset or application-data clearing is needed.

`AutomaticSurfaceSnapshot` retains immutable original points and compact automatic
`SurfaceSegment` values in memory. Persistence stores ranges and automatic
provenance, never geometry or meters. Ordered endpoint OSM keys preserve C's
existing compatibility boundaries; candidates, scores, GPS assessments, raw OSM
objects and the diagnostic graph are not persisted. `RouteAnalysis` and
`WalkSurfaceSummary` remain the transient automatic/debug models.

`SurfaceCorrection` has a half-open original-edge range and a canonical label.
It has no fake DIRECT/INFERRED assignment. `SurfaceJournal` combines an automatic
snapshot and immutable corrections through `EffectiveSurfaceSummary`; widgets
do not overlay labels or mutate automatic objects.

## Original-edge identity and integrity

`[startEdgeIndex, endEdgeIndex)` refers to ordered recorded **edge list indices**,
not OSM geometry, GPS sequence numbers or an automatic segment ordinal. Geometry
uses recorded points `startEdgeIndex` through `endEdgeIndex`, inclusive. A point
sequence/time gap still retains its original connecting edge, as in C.

Three SQLite triggers mark an existing header `points_valid = 0` after any
INSERT, UPDATE or DELETE in its walk's `walk_points`. An UPDATE involving a
changed walk ID invalidates both affected headers. This detects point mutations
without copying a track, adding hashes or introducing analysis versions. It is
an integrity guard under normal SQLite operation, not tamper-proof authentication.

Loading and writing compare the supplied point sequence against every stored
point field inside the transaction. Loading additionally checks the header count
and validity marker. A snapshot requires ordered, nonoverlapping automatic
ranges covering every available edge exactly once; invalid enum values and
inconsistent UNKNOWN assignments are rejected. Corrections must be ordered,
nonempty, in bounds and nonoverlapping. Corrupt data is never filled with invented
surfaces or partially displayed as a saved journal.

Invalid surface data produces a localized message while preserving the walk.
Explicit re-analysis can rebuild corrupt automatic segments while retaining valid
corrections. If corrections themselves are corrupt, or points have changed under
existing corrections, D refuses to reassign or discard the observations. Those
cases require future explicit recovery tooling; retry cannot silently erase data.
With no corrections, explicit re-analysis can establish a fresh valid snapshot
for the current saved point sequence.

## Effective surfaces and precedence

The ordered domain overlay allocates every original edge once:

- Outside corrections, preserve automatic segment boundaries and labels.
- Inside a correction, use its chosen label over exactly its original range,
  even across several newly analyzed automatic segments.
- Keep each correction as one effective segment. Never merge it with automatic
  neighbors or another correction, even if their visible surface labels agree.
- Automatic ranges split at correction boundaries. They never expand a
  correction to the rest of an overlapping automatic segment.

For example, a correction on `[100,120)` survives automatic segments `[100,110)`
and `[110,130)`: the correction remains `[100,120)` and the automatic result is
visible again on `[120,130)`. Restoring that observation reveals both current
automatic ranges. Automatic UNKNOWN reasons remain unchanged in the separate
debug inspector; the normal map and breakdown describe effective results.

## Save, restore and re-analysis transactions

`WalkSurfaceRepository` owns durable reads/writes through the existing
`AppDatabase`. Each correction Save validates the current snapshot and observation
ranges, then inserts or replaces only an exact-range correction in one transaction.
Partially overlapping edits are rejected. Restore automatic deletes only that
exact correction and returns the current automatic result beneath it.

The UI updates only after transaction success. Failure leaves the editor open,
retains its choice and shows a localized retryable error; no unsaved label is
presented as saved. Restore failures behave the same way.

A complete successful analysis saves its compact snapshot automatically after
the user's explicit Analyze action. Re-analysis validates its input, updates the
existing header and replaces only automatic segment rows transactionally. It
never uses SQLite REPLACE on the header, which would cascade-delete corrections.
There is one current snapshot, no history or algorithm-version infrastructure.

Failed/incomplete evidence, invalid analysis or a failed database transaction
cannot replace the last successful snapshot or its corrections. C's all-UNKNOWN
incomplete preview remains available when there is no saved snapshot, visibly
marked unsaved and without editing controls. It cannot become a durable result.
A complete empty OSM result can still validly persist an all-UNKNOWN route.

Re-analysis follows the existing evidence-cache policy: reuse cached cells and
fetch missing cells explicitly. It does not force an evidence refresh. The
existing debug refresh can replace evidence independently; this does not modify
the saved journal until explicit successful re-analysis.

## User interaction and map

Saved walk → Surface review loads local data. With no snapshot, use Analyze
surfaces. With a snapshot, the review appears immediately after local loading,
with Re-analyze surfaces available explicitly.

An ordered list below the map shows segment number, length, effective label,
Automatic/Corrected provenance and distance from the walk's start. Tap any row
to open the localized editor, choose a supported label and Save. Corrected rows
also offer Restore automatic. Whole displayed ranges are edited; there is no
minimum length, freehand painting, sub-edge selection or precise map-line tapping.

The chooser uses all eight existing canonical labels, including UNKNOWN. Known
surfaces can change to other known surfaces or UNKNOWN; UNKNOWN can become known.
A user selection equal to the current automatic surface removes/avoids a redundant
correction rather than creating a separate confirmation state.
OTHER remains broad; barefoot-specific
taxonomy design and new top-level materials are deferred.

GeoJSON uses original point slices and effective labels/colors with an explicit
corrected flag. Committed edits update the existing MapLibre source; they retain
the user's camera/plain-map choice. The native style-loading path also catches
up with corrections committed during loading. The segment list supplies selection
and provenance; no map picking or inspector redesign is added.

## Distances

Every original edge, including stationary edges, gaps and UNKNOWN, uses
`WalkDistance`'s existing haversine convention. Segment and effective totals are
reconstructed from original points; SQLite stores neither duplicated geometry
nor a second distance total. No GPS coordinate or timestamp is changed.

Every edge is allocated exactly once with no dropped or double-counted meters.
Correction changes only category allocation. Reconciliation retains C's tolerance
max(10^-6 m, |saved meters| × 10^-12) for floating-point grouping differences.
The existing independently rounded displays and saved-distance mismatch warning
remain; D never rescales or rewrites saved distance.

## Restart, offline, deletion and privacy

After successful persistence, closing/reopening SQLite or restarting the app
loads the same automatic segments and corrections without `RouteMatcher` or
`EvidenceRepository` access. Clearing/deleting the separate disposable
`pathgrain_osm_evidence_cache.sqlite` cannot delete the durable journal.

The basemap remains independently network-backed. Offline review retains local
list/totals and the existing Use plain map fallback for local route geometry;
this is not an offline tile package.

`WalkRepository.deleteWalk` deletes a walk through SQLite. Cascading foreign keys
remove that walk's points, header, automatic segments and corrections, leaving
other walks intact. D adds no separate deletion UI.

Tracks, timestamps, automatic snapshots and corrections stay local. No backend,
sync, correction uploads, analytics, telemetry, logging or track export was added.
Explicit evidence requests retain A/C's fixed-cell privacy boundary and the same
provisional provider/cooldown policy. Basemap requests still disclose viewed areas
independently. Opening review does not request evidence; stopping a walk is unchanged.

## Automated verification

Focused tests cover:

- `surface_journal_test.dart`: exact range precedence, UNKNOWN/known changes,
  split/merge rules, immutable provenance, invalid coverage/ranges, distance
  invariants and effective GeoJSON.
- `walk_surface_persistence_test.dart`: a realistic exact schema-v1 fixture with
  completed/interrupted/recording walks; ordered provenance round trips; real
  SQLite close/reopen; corrections/restore; changed automatic boundaries;
  malformed snapshots/corrections; exact point-mutation invalidation; forced
  transaction failures; walk cascade deletion; disposable cache-file deletion.
- `walk_surface_corrections_screen_test.dart`: English/Ukrainian selection,
  chooser, known/UNKNOWN changes, map/breakdown/provenance, restore and failure
  retry, local reopen without evidence, explicit re-analysis and corrupt-data
  recovery states. Existing C review/GeoJSON tests consume the effective model.

Verification on **2026-09-10**:

- `flutter gen-l10n`: succeeded for English and Ukrainian.
- `dart format`: all 19 changed/new Dart files clean on the final pass.
- Focused domain, SQLite, correction UI and existing C review/GeoJSON run:
  **71 tests passed**.
- Full `flutter test --no-pub`: **209 tests passed**, including recorder,
  evidence, retained crossing-node, parallel-road, pedestrian-rival, heading,
  GPS-confidence and non-propagating-continuity regressions.
- `flutter analyze --no-pub`: **no issues found**.
- Tracked and new-file whitespace checks: clean.
- `flutter build apk --debug --no-pub`: **succeeded**.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.

Development tests exposed and fixed a stale local-read failure flag that hid
explicit corrupt-snapshot recovery, plus an overly strict floating-point test
assertion. A temporary test-edit compilation error and brace-style analyzer
findings were also corrected. No test or analyzer failures remain.

The build emitted the existing Gradle Java native-access warning and
`maplibre_gl` Kotlin Gradle Plugin / future Built-in Kotlin migration warning.
Neither blocked the build. Some commands initially could not start because the
environment's sandbox helper failed; approved execution completed verification.
No dependencies or toolchain configuration were changed.

Widget substitutes verify map data and Flutter interaction, not native drawing
or physical Android process restart. Repository tests reopen a real SQLite file.
No live Overpass request or physical 0.1-D test was performed during implementation.
Subsequent physical acceptance is recorded below.

## Physical Pixel acceptance

A focused physical Pixel acceptance check succeeded on an existing saved walk
after installing over the existing app without clearing data. Verified behavior:

- Existing walks survived the v1 → v2 database migration.
- A persisted Surface Review reopened correctly.
- A user correction changed the effective map and distance breakdown.
- The correction survived app restart.
- The correction survived explicit re-analysis.
- Restore automatic restored the automatic surface.
- Another correction on a different original-edge range remained independent.
- The final regression fix was verified: automatic concrete → correction grass
  → selecting concrete again and saving removed the redundant correction and
  returned the segment to `Concrete · Automatic`.
- Total walk and surface distance remained consistent.
- No application data clearing was required.

These observations establish the exercised 0.1-D journal flow on that walk,
not exhaustive production validation. Broader limitations and final recorder
regression verification remain.

## Limitations and deferred work

The provider and taxonomy are provisional. Matching quality, dense evidence,
long-route responsiveness, native map rendering and coincident route geometry
retain earlier limitations. The ordered segment list is intended for small MVP
walk reviews; large-list performance needs field evaluation. Corrupt user-data
recovery has no destructive automatic fallback. iOS recording acceptance remains
deferred. No automatic post-Stop analysis, matcher tuning, analysis history,
global propagation, freehand editing, backend, accounts or community features.

The C note now records the actual focused Pixel review observations separately
from frozen-dataset verification of the later retained crossing-node refinement.
It does not claim physical acceptance of that exact final matcher APK or the D loop.

## Pixel upgrade and field checklist

Install `build/app/outputs/flutter-apk/app-debug.apk` over the existing Pixel app.
**Do not uninstall or clear application data**: upgrading the existing database
is part of acceptance. Keep real tracks and coordinate-bearing artifacts out of
the repository.

1. Note an old saved walk's distance, duration and point count. Open Surface
   review and explicitly analyze; check the original colored geometry and totals.
2. Force-close and restart. Reopen the walk; the persisted review must appear
   without Analyze or a new evidence request.
3. Change an incorrect known segment to a real supported surface. Correct an
   UNKNOWN segment to a known real surface. Check Corrected labels, map colors,
   category distances and unchanged total distance.
4. Force-close/reopen again. Confirm both exact corrected ranges and totals remain.
5. Restore automatic on a corrected segment. Verify the automatic label returns,
   then correct it again.
6. Explicitly Re-analyze. Confirm corrections retain the same range and remain
   authoritative; restoring afterward must expose the current automatic result.
7. Disable the network after successful persistence. Reopen, edit, save and
   restore offline; use the plain map if the basemap cannot load. An unsuccessful
   re-analysis must retain the prior saved review and corrections. With every
   evidence cell cached, offline re-analysis may succeed locally.
8. Recheck the old recorded walk's distance, duration and point count. Confirm
   its original route is unchanged; use local-only inspection if point-level
   verification is needed. Check English and Ukrainian, including long labels.
9. For final MVP acceptance, record an ordinary walk with Home and screen-lock
   intervals, then stop/review it. Report actual device behavior separately;
   automated tests do not establish background-recording acceptance.
