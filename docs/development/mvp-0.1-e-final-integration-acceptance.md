# MVP 0.1-E — Final integration and Android acceptance

> **Later-status / document role**
>
> Historical integration/acceptance record (0.1-E). The schema-2 statements and
> test counts below describe E's completion. [F](mvp-0.1-f-barefoot-surface-taxonomy.md)
> later supplied schema 3, the expanded taxonomy and its own physical upgrade
> spot-check. E's new-walk Home/lock acceptance remains valid evidence. See the
> [current pipeline](../reference/surface-pipeline.md) and the later
> [walk-8 diagnostics](mvp-0.2-a-surface-diagnostics-replay.md); zero known surfaces
> on that walk do not imply recorder/storage failure.

Status: complete; final physical Pixel acceptance passed on a newly recorded
walk after automated verification.

## Purpose and audit

E connects and hardens the existing local loop:

**Record → Stop/save → explicitly Analyze surfaces → Review → Correct → Persist → Reopen**

The starting repository was clean at `16df383` (0.1-D). The audit read AGENTS,
the product specification, A–D development notes, recorder/platform integration,
walk/history/detail UI, schema and repositories, surface/evidence/map flow,
localization and tests. The retained crossing-node correction (`09ad04d`) is
existing matcher behavior, unchanged by E.

| Product acceptance criterion | A–D evidence and boundary at the initial E audit |
| --- | --- |
| 1. Record, stop, history, route and metadata | Implemented recorder foundation. A new final walk through the journal, including lifecycle transitions, had not yet been physically verified. |
| 2. Ordered derived surfaces | Implemented A/B/C; focused C Pixel saved-walk observations. No new matching work needed. |
| 3. Complete distance breakdown | C original-edge allocation and D effective overlay reconcile; saved-walk Pixel observations recorded in C/D. A check on the new final walk was still needed. |
| 4. Honest UNKNOWN | Matcher, review and diagnostics already retain uncertainty. Successful complete all-UNKNOWN analysis remains distinct from failed/incomplete evidence. |
| 5. Correction updates review | D implemented and physically spot-checked on an existing walk, including independent corrections and restore. |
| 6. Reopen durable walk/journal/correction | D SQLite reopen tests and physical Pixel restart/re-analysis observations. E connects this to a newly recorded synthetic walk. |
| 7. Local track/timestamp boundary | Existing fixed-cell request architecture; source and request tests audited again in E. No new network or logging code. |
| 8. Recorder regression on Android | Automated protection strengthened in E. Physical Home/screen-lock verification still required the final Pixel walk below. |

The genuine code gaps were recording-queue shutdown, actions delivered before
busy controls rebuilt, and a failed detail point read that never left its loading
state. Most journal requirements were already implemented and were verified
without rewriting them. Taxonomy and large segment-list usability are separate
product questions, deferred below.

## Small hardening changes

### Recorder completion

Previously, a sample already queued behind an SQLite write could be skipped when
Stop changed the phase to stopping: the queue checked for the recording phase
only when executing. A regression with three queued points reproduced a saved
walk containing only two. Admission now happens while recording; a normal Stop
cancels the subscription and drains the admitted queue through the same filter
and ordered writes before finishing the walk.

A pending point-write failure during Stop also started a competing interruption,
causing two finish attempts. The existing stopping phase now establishes one
completion owner. A failure marks that owner's result interrupted; it cannot
launch a second finish. Previously stored points remain available, and a storage
failure prevents subsequent queued writes from pretending to succeed. Ordinary
stream-error interruption still stops queued work and retains written points.

No foreground-service configuration, permissions, GPS filtering thresholds,
location settings, native code, point format or distance calculation changed.
The root controller still owns the stream across Flutter lifecycle events.
Startup recovery still retains unfinished recordings as interrupted walks; it
does not resume recording after process death. Stop remains local, with no
surface/evidence dependency.

### Surface actions and detail loading

- Analyze/Re-analyze and retry guard busy state before replacing the tracked
  loading future. Repeated actions cannot start overlapping analyses or lose
  the future used for disposable-cache cleanup after navigation.
- Segment editing admits only one editor at a time and cannot start during
  analysis. Analysis cannot start behind an open editor.
- Save/Restore share the dialog's synchronous saving guard. Rapid duplicate or
  conflicting actions cannot submit multiple writes or pop multiple routes.
  The existing pending-save navigation block and recoverable failure UI remain.
- A failed saved-route point read now shows a localized English/Ukrainian error
  and local retry instead of an endless loading spinner. Metadata and the normal
  Surface Review entry remain available. Repeated retry is guarded as well.

No correction model, range identity, overlay/segmentation or re-analysis semantics
changed. Selecting the current automatic surface across the whole edited range
still uses D's restore semantics, with no separate user-confirmation state.
Corrections remain authoritative across changed automatic boundaries.

## Database integration

Schema remains **version 2**; E adds no migration, table, column or trigger.
The real SQLite workflow test establishes:

- Normal Start/point writes/Stop work with v2. Points retain their original
  sequence, coordinates, timestamps and accuracy; history and metadata remain
  valid. No premature surface snapshot is created.
- The surface repository rejects an attempted snapshot for an active recording.
- Explicit complete analysis can create a valid snapshot after completion.
- Recording another walk alongside a durable corrected journal does not trigger
  false invalidation of that journal. Its `points_valid` marker remains valid.
- Closing/reopening the database with fresh repositories/controller retains the
  saved walk, automatic snapshot and correction, without evidence access.
- Re-analysis preserves the exact correction range; failed/incomplete replacement
  preserves the last successful journal. Restore and redundant-selection behavior
  continue to work. All original saved walk/point fields remain unchanged.
- Walk deletion cascades through points, automatic snapshot and corrections,
  while another walk remains intact; SQLite foreign-key checks are clean.

D's realistic v1 → v2 migration, forced transaction rollback, corrupted-range,
point-integrity and separate evidence-cache deletion regressions are retained.
User observations never reside in the disposable evidence cache.

## Failure, offline and navigation audit

Opening detail/review does not require surface evidence. A review with no saved
snapshot offers explicit Analyze. Complete analysis becomes editable only after
the snapshot transaction succeeds. Existing successful journals remain visible
through incomplete evidence, analysis exceptions and snapshot-save failures;
retry is explicit. An unsaved incomplete UNKNOWN preview cannot be corrected.
A successful complete empty OSM response may legitimately persist UNKNOWN.

Correction failures retain the choice in the editor and allow Save/Restore retry;
no unsaved value is presented as committed. Navigation away from analysis prevents
later cell requests; an already running cell may finish its cache write. The
owned cache closes after the tracked operation. Navigating away during a snapshot
transaction does not undo that transaction; a subsequent open loads committed
local data. No automatic analysis runs on Stop, opening review or app upgrade.

Persisted journal reconstruction is independent of the evidence cache/provider.
The basemap remains network-backed; the existing Surface Review plain-map
fallback keeps local geometry and the list/totals usable if its style fails.
There are no offline tile packages. Existing debug duration/point count/route,
OSM evidence, automatic summary, UNKNOWN reasons and effective correction display
are sufficient for this handoff; E adds no diagnostic framework.

## Privacy audit

`EvidenceRepository.inspect` reduces local coordinates to sorted unique fixed
cells. `OverpassEvidenceProvider` accepts a cell and builds the existing padded
bbox query with static protocol headers. Requests contain no ordered recorded
track, timestamps, walk identity, accuracy values, automatic snapshots or
corrections. Existing request-shape and cell-order tests remain in the suite.

Only the provisional Overpass evidence endpoint and independent development
basemap are used. They can observe requested/viewed areas, IP addresses and
request times; fixed cells do not provide anonymity. Ordered point geometry
reaches MapLibre locally for drawing, not as an evidence request. App source
contains no introduced coordinate/correction logging, analytics, telemetry,
crash-reporting, backend, upload or sync path. No live provider request, real
track export or coordinate-bearing field artifact was used for E tests.

## Automated verification

New/extended coverage:

- `test/walk_journal_workflow_test.dart`: real recorder controller, filtering,
  schema-v2 file, evidence repository with a synthetic provider, real matcher,
  automatic persistence, correction, SQLite reopen, second recording, failed
  analysis/re-analysis, restore, redundant correction, unchanged original rows
  and deletion. No mocked surface repository or matcher.
- `test/walk_recording_controller_test.dart`: delayed point writes around Stop
  and stream interruption, including write failures and repeated Stop. Checks one
  completion, saved sequence, status, duration and retained history.
- `test/widget_test.dart`: Start/Stop through the actual Home UI and real SQLite,
  synthetic Flutter lifecycle events, ongoing stream ownership, route detail and
  saved history. These events do not simulate or prove physical Android delivery.
- `test/walk_surface_corrections_screen_test.dart`: repeated Analyze/Re-analyze,
  duplicate editor opening, conflicting/repeated Save/Restore and pending-save
  navigation protection, alongside all D correction regressions.
- `test/walk_surface_review_screen_test.dart`: recoverable detail point-read
  failure and repeated local retry in English/Ukrainian, alongside C/D loading,
  evidence failure, disposal and map-fallback coverage.

Verification on **2026-09-10**:

- `flutter gen-l10n`: succeeded for English/Ukrainian.
- `dart format`: all **13** changed/new Dart files clean on the final pass.
- Focused integration/repository/surface UI checks passed; final recorder and
  history/detail widget regressions passed after the test-harness corrections.
- Full `flutter test --no-pub`: **233 tests passed**, including the v1 migration,
  recorder, evidence, correction and retained crossing-node/parallel-road,
  pedestrian-rival, heading, GPS-confidence and continuity regressions.
- `flutter analyze --no-pub`: **no issues found**.
- Tracked and new-file whitespace checks: clean.
- `flutter build apk --debug --no-pub`: **succeeded**.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.

The existing Gradle Java native-access warning and `maplibre_gl` Kotlin Gradle
Plugin / future Built-in Kotlin migration warning remain. Neither blocked the
build. The first build invocation could not start because the environment's
sandbox helper failed; approved execution succeeded. No dependency, toolchain
configuration or Android platform file was changed.

The new regressions first reproduced the queued-point loss, double finish,
duplicate surface actions and indefinite detail loading in the baseline. During
implementation, tests caught an asynchronous return from a setState callback;
that callback was corrected. The new lifecycle test also needed explicit draining
of widget microtasks and real SQLite FFI work, and its interrupted-point expectation
was corrected. The first full-suite run exposed a missing native platform-view
implementation in the new host widget test (232 passed, one failed). That test
now stubs only native map channels and checks the SQLite-backed route data;
physical rendering remains unverified by host tests. Two test brace-style analyzer
findings were corrected as well. The final full suite and analyzer passed with
no remaining failures.

## Final physical Pixel acceptance

Physical result: **passed (user-reported)**. After E implementation and automated
verification, the user installed the 0.1-E debug APK over the existing Pixel app
without clearing application data and completed one **newly recorded walk**.
Existing application data survived the in-place upgrade. Verified behavior:

- A new walk started normally and recorded in the foreground.
- Recording remained active after pressing Home and later returning to the app.
- Recording remained active through screen lock/unlock.
- Stop completed normally; the new walk was saved and available afterward.
- Surface Review opened for the new walk and explicit surface analysis completed.
- The correction flow worked; force-close and app restart preserved the saved
  walk, persisted analysis and correction.
- Explicit re-analysis preserved correction precedence.
- Restore automatic worked correctly.

The user's final physical acceptance summary:

```text
Home — ok
lock — ok
Stop — ok
restart — ok
re-analyze — ok
restore — ok
```

The full local flow completed without clearing application data. C/D's earlier
Pixel spot-checks used existing saved walks; this subsequent new walk closes the
final E lifecycle/integration acceptance and MVP 0.1 acceptance for its defined
Android scope. This actual-device result is separate from synthetic Flutter
lifecycle tests, which do not establish physical Android background delivery.

This confirms the exercised lifecycle/integration behavior, not exhaustive
production validation, Play Store readiness, broader device coverage, iOS
acceptance, surface-classification accuracy/coverage or complete OSM coverage.

### Original handoff checklist (reference)

The checklist below is retained for future regression checks. Only the reported
observations above are acceptance evidence; optional scenarios and requested
measurements below are not additional recorded results.

Install `build/app/outputs/flutter-apk/app-debug.apk` **over the existing app**.
Do not uninstall or clear data. Confirm existing saved walks and a previously
corrected journal still open. Note the APK tested and Pixel/Android version in
the eventual acceptance report. Keep real tracks and coordinate-bearing artifacts
out of the repository.

Record one **new ordinary 5–15 minute walk**; no particular material mix or surface
accuracy benchmark is required:

1. Start outdoors with the app visible. Confirm active recording, increasing
   plausible point count/duration and the foreground recording notification
   according to the granted notification permission.
2. Walk in the foreground, press Home and continue walking for a period, then
   return. Verify the same recording remains active and counters have advanced.
3. Lock the screen and continue walking for a period, then unlock and return.
   Preferably include another foreground/background transition. Do not force-stop
   the app during recording.
4. Stop normally. Confirm the new walk appears in history and opens in detail.
   Check plausible duration/distance and nonzero plausible stored point count.
   Inspect the original route for obvious gaps corresponding to Home/screen lock.
   Note duration, distance and point count for comparison later.
5. Open Surface Review. With no saved snapshot, verify Analyze surfaces is
   offered; Stop must not have requested analysis. Explicitly Analyze. Loading
   must complete or report failure honestly with a recoverable retry. If evidence
   fails, verify the saved walk remains intact, restore connectivity/cooldown as
   needed and explicitly retry before continuing the successful journal loop.
6. Check complete original colored geometry and total surface distance against
   saved distance, including UNKNOWN and the documented display rounding.
7. Select a segment, choose a different supported label and Save. Confirm
   Corrected provenance, the effective map/breakdown change and unchanged total.
8. Force-close **after saving**, reopen the app and the same walk. Verify its
   metadata, saved analysis and exact corrected range remain, with Re-analyze
   available and no requirement to analyze again.
9. Explicitly Re-analyze. Check the correction remains authoritative over the
   same range, even if automatic boundaries change. Re-analysis reuses available
   evidence cache; it does not force a fresh OSM download.
10. Restore automatic. Verify automatic provenance and the current automatic
    surface return. Spot-check D's regression by correcting a known segment, then
    choosing its automatic value and saving: no Corrected label or applicable
    Restore action should remain. If the automatic range now contains several
    different labels, use Restore rather than assuming one label matches all.
11. If possible, disable networking and reopen the persisted journal. Verify
    list/totals/corrections load locally; use the plain map if the basemap fails.
    Offline re-analysis can succeed from fully cached evidence; a failed attempt
    must retain the previous saved journal. Re-enable networking afterward.
12. Recheck the saved duration, distance, point count and original route against
    step 4. None may be changed by analysis, correction, restore or reopening.
    Return to history/Home normally.

## Limitations and deliberately deferred work

The provider, conservative matcher and performance limits from A–D remain.
Long/dense routes and native map behavior need broader device evaluation.
Recording remained active across Home and screen lock on the final Pixel walk;
broader device/vendor coverage remains unverified. Force-stop, process
termination, vendor battery killing and
reboot are not promises of uninterrupted recording; written points retain the
existing interrupted-recovery contract. Persistent storage failure cannot promise
new writes; malformed user corrections still have no destructive automatic
recovery. iOS background-recording acceptance is outside scope.

Deferred beyond MVP 0.1; not blockers for this milestone's completion:

- barefoot-oriented surface taxonomy redesign;
- mapping richer raw OSM values into user-facing categories;
- replacing broad OTHER;
- locating/editing routes with very many small segments;
- map-based segment selection;
- smarter grouping/presentation of correction targets.

Also unchanged/deferred: automatic post-Stop analysis, broader matcher research
and heuristic changes, provider/performance hardening, freehand/sub-edge editing,
analysis history, offline map packages, backend, accounts, sync, community data,
weather, hazards, recommendations and broader production validation.
