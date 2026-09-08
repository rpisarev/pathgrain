# MVP 0.1 — Surface-aware walk journal

Status: current milestone

## Goal

Turn the existing Prototype 0.0 walk recorder into a surface-aware barefoot
walk journal.

MVP 0.1 tests whether automatically derived, correctable surface information
makes a recorded walk more useful to review. It does not test community or
social functionality.

## Starting point

Prototype 0.0 already provides the Android-first local recording foundation:

- foreground-service location recording;
- GPS point filtering;
- SQLite persistence for walks and ordered points;
- saved walk history;
- duration and distance calculation;
- MapLibre review of a saved route.

MVP 0.1 must extend this implementation. Rebuilding the recorder is not part of
the milestone.

## Primary user loop

**Record → Analyze surfaces → Review → Correct → Save**

1. The user records and stops a walk with the existing recorder.
2. Pathgrain analyzes the saved route against geographic/OpenStreetMap surface
   data where possible.
3. The user reviews the route as surface segments and sees a surface breakdown
   by distance.
4. The user corrects a segment whose inferred surface is wrong.
5. Pathgrain saves the walk, derived surface information, and local correction
   so the same review is available after restart.

## Functional scope

### Record and stop

- Preserve the existing start, background-oriented recording, stop, history,
  duration, distance, and route-review behavior.
- Analyze only a saved walk. Live surface classification is not required.

### Analyze surfaces

- Derive surface information for the recorded route from geographic and/or
  OpenStreetMap data where the available evidence supports a classification.
- Divide the complete route into ordered surface segments suitable for review.
- Assign `unknown` to any portion for which Pathgrain cannot make a defensible
  classification. Missing, ambiguous, conflicting, or unavailable data must not
  be converted into a guessed surface.
- Keep the matching algorithm, confidence rules, and provider choice outside
  this product specification; they remain technical decisions listed below.

### Review

- Show the saved route divided into surface segments, with each segment's
  surface understandable from the map and/or an accompanying label.
- Show a simple breakdown of distance by surface.
- Include unknown distance in the breakdown rather than hiding or reallocating
  it.
- Keep the breakdown consistent with the saved walk distance, apart from
  explicitly documented display rounding.

### Correct and save

- Let the user select a reviewed segment and replace an incorrect surface label
  with another supported label.
- Update the route review and distance breakdown to reflect the correction.
- Store derived segments and user corrections locally with the walk.
- Preserve a correction across app restart and protect it from being silently
  overwritten by automatic re-analysis.

## Platform scope

MVP 0.1 is Android-first. The Android experience is the acceptance target.
iOS remains an intended platform, but completing iOS background recording is
not required for this milestone.

## Privacy and data boundary

- Ordered GPS points and per-point timestamps remain on the device.
- Walk history, surface segments, and user corrections remain local in MVP 0.1.
- No backend, account, cloud synchronization, or community infrastructure is
  required or permitted for this milestone.
- Surface-data access must not upload a stored ordered track or its timestamps.
  If a network source is selected, its request shape, caching, provider terms,
  attribution, and location-privacy implications must be reviewed explicitly
  before implementation.
- GPS coordinates must not be added to analytics, crash reporting, application
  logs, or telemetry.

## Explicit non-goals

MVP 0.1 does not include:

- accounts;
- a backend;
- Supabase/PostGIS;
- cloud synchronization;
- community activity;
- live or historical locations of other users;
- hazard reporting;
- weather;
- route recommendations;
- achievements or gamification;
- shared or global user corrections;
- a full pre-walk surface discovery map;
- iOS background-recording completion.

These ideas may appear in the [product vision](vision.md), but that does not put
them in the current milestone.

## Acceptance criteria

MVP 0.1 is complete only when all of the following have been demonstrated on
the Android target:

1. A user can record and stop a walk through the existing recorder, then open
   that saved walk from history and see its route, duration, and distance.
2. For a recorded route with supported geographic/OpenStreetMap surface
   evidence, Pathgrain derives surface information and displays the route as
   one or more ordered, understandable surface segments.
3. The same review shows a distance breakdown by surface. The breakdown covers
   the complete saved route, includes unknown distance, and reconciles with the
   saved walk distance apart from documented display rounding.
4. For a route portion without defensible source evidence, the corresponding
   segment and breakdown use `unknown`; the application does not invent a more
   specific label.
5. A user can choose a segment, change an incorrect classification, and
   immediately see the corrected route review and breakdown.
6. After the application is fully closed and reopened, the saved walk, derived
   segments, and correction are still present and the correction still affects
   the review and breakdown.
7. The ordered GPS point sequence and point timestamps have remained local;
   they have not been placed in a remote request, backend, analytics, crash
   report, log, or telemetry payload.
8. Existing recorder behavior has not regressed. Release verification includes
   a physical Android-device walk with Home/screen-lock behavior; record the
   result rather than assuming simulator or automated coverage proves it.

## Unresolved technical decisions

Development choices for source/cache access, provisional matching and
confidence rules, and surface taxonomy are already implemented in
[0.1-A](../development/mvp-0.1-a-osm-map-evidence.md) and
[0.1-B](../development/mvp-0.1-b-route-surface-matching.md). The following concern
remaining integration and final decisions for the complete journal workflow;
this product specification deliberately does not select them:

- which geographic/OpenStreetMap source and provider to use, including terms,
  attribution, availability, and rate limits;
- whether source data is downloaded, cached, queried on demand, or made
  available offline, and how any network query minimizes location disclosure;
- the on-device route-to-geography matching and segmentation algorithm,
  confidence thresholds, and behavior for conflicting source features;
- the initial user-visible surface taxonomy and its mapping from source tags;
- the local schema and migration for inferred segments, provenance, and user
  corrections;
- the correction-selection interaction and minimum editable segment size;
- analysis progress, failure, retry, caching, and re-analysis behavior,
  including how a saved correction retains precedence;
- the distance-allocation and display-rounding rules used by the surface
  breakdown.
