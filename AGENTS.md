# Pathgrain — Agent Instructions

## Project and current milestone

Pathgrain is a privacy-first mobile app for barefoot walking.

Build the product incrementally through small, technically useful vertical
slices. Do not try to implement the complete product architecture at once.

### Implemented baseline: Prototype 0.0

Prototype 0.0 is already implemented. It is an Android-first, local walk
recorder with SQLite persistence, GPS point filtering, foreground-service
location recording, saved walk history, duration and distance calculation, and
MapLibre route review.

Treat this recorder as the implementation foundation. Future work must inspect
and extend the existing `lib/walks` implementation and its platform integration
rather than rewrite, re-scaffold, or independently reimplement it. Replace part
of the foundation only when a requested change requires it and the reason is
made explicit.

The implementation and verification boundary of this foundation is documented
in [docs/development/android-walk-recording.md](docs/development/android-walk-recording.md).

### Completed MVP 0.1; current slice MVP 0.2-A

MVP 0.1 and slices 0.1-A through 0.1-F are complete. The initial local Android
Record → Analyze surfaces → Review → Correct → Save cycle was physically
accepted on a Pixel, including Home and screen lock; F separately records its
taxonomy upgrade spot-check. See [the completed specification](docs/product/mvp-0.1.md)
and its E/F acceptance links. This does not imply exhaustive device or iOS acceptance.

[MVP 0.2-A](docs/product/mvp-0.2-a.md) adds real-world diagnostics and deterministic
offline replay, with documentation reconciliation. The all-unknown walk-8 field
result exposes surface-coverage limitations, not a failed recorder/storage loop.
This slice must preserve matching/classification policy. The
[current pipeline reference](docs/reference/surface-pipeline.md) describes the
implemented architecture and schema.

The broader direction in [docs/product/vision.md](docs/product/vision.md) is not
current implementation scope. Accepted product choices are recorded in
[docs/product/decisions.md](docs/product/decisions.md).

## Source-of-truth roles

- `AGENTS.md` contains long-lived engineering, privacy, Git, quality, and scope
  rules for contributors and agents.
- `docs/product/vision.md` describes possible long-term product direction. It
  does not authorize implementation.
- `README.md` owns the current project overview and developer entry points.
- `docs/product/mvp-0.2-a.md` defines the current slice and acceptance criteria.
- `docs/product/mvp-0.1.md` preserves the completed Android milestone scope.
- `docs/reference/surface-pipeline.md` is the current architecture/schema reference.
- `docs/development/mvp-0.2-a-surface-diagnostics-replay.md` owns replay usage,
  export contracts, the field finding and the 0.2-A validation record.
- A–F development notes preserve implementation/acceptance history. F also owns
  the current complete taxonomy/migration reference; later changes must update
  or explicitly supersede that reference rather than create conflicting lists.
- `docs/product/decisions.md` records accepted product decisions that remain in
  force until explicitly superseded.
- `docs/development/android-walk-recording.md` explains the Prototype 0.0
  Android recorder foundation and its verification limits.

## Current technology direction

- Flutter
- Dart
- Android and iOS are the intended mobile platforms
- SQLite is the local source of truth for walks
- MapLibre is the preferred map renderer
- Supabase/PostGIS may be considered later for minimized community data, but is
  not part of MVP 0.1 or 0.2-A

Do not introduce Supabase, a custom backend, authentication, cloud sync,
analytics, or community features unless explicitly requested by a later
milestone.

## Core privacy invariants

These rules are architectural requirements.

- Full ordered GPS walk tracks and per-point timestamps must remain on the
  user's device.
- Do not create backend APIs, database tables, or sync mechanisms capable of
  uploading full walk tracks.
- Do not send GPS coordinates to analytics, crash reporting, logging, or
  telemetry services.
- Walk history and personal statistics are local data.
- Community data, if introduced later, must be explicitly minimized before
  leaving the device.
- Prefer privacy by architecture rather than privacy by policy.
- Keep `captures/` and local `diagnostics/` exports untracked. Do not copy raw
  field tracks, logs, screenshots or database history into tracked fixtures.
  Prefer synthetic regressions plus explicit local private-capture replay.
  Moving/rotating a real track is not sufficient anonymization. Diagnostic
  reports can reveal location through OSM IDs even without point coordinates.

## Development philosophy

Pathgrain is developed as a sequence of small MVP milestones.

Prefer:

1. simple implementations;
2. small vertical slices;
3. code that can be tested on a real device;
4. clear interfaces between platform-specific and application code;
5. maintainability over premature abstraction.

Avoid:

- speculative architecture;
- unnecessary packages;
- generic frameworks built for hypothetical future requirements;
- microservices;
- custom backend servers;
- complex synchronization engines;
- CRDTs;
- premature optimization.

When choosing between a simple implementation that satisfies the current
requirement and a more extensible implementation for hypothetical future needs,
prefer the simple implementation unless the future requirement is already
confirmed.

## Working rules for Codex

When the user asks for analysis, architecture, investigation, or a plan:

- do not modify files unless explicitly asked;
- inspect the existing repository first;
- explain important tradeoffs;
- identify unknowns rather than silently guessing.

When asked to implement something:

1. inspect the relevant existing files first;
2. keep the change limited to the requested milestone;
3. reuse the existing project structure where reasonable;
4. extend the Prototype 0.0 recorder instead of rebuilding it;
5. do not perform unrelated refactors;
6. do not add unrelated features;
7. run relevant formatting, static analysis, and tests after changes;
8. report what was changed and what was verified.

Before introducing a significant new dependency, explain why it is needed.

Do not replace working project configuration merely to match a preferred
template.

Do not delete user code or data unless explicitly instructed.

## Git and change safety

Keep changes small and reviewable.

Do not:

- rewrite Git history;
- force push;
- delete branches;
- remove large groups of files;
- reset or discard existing user changes;

unless explicitly instructed.

If the working tree already contains unrelated user changes, preserve them.

## Mobile location recording

Background GPS recording remains a critical technical risk even though the
Prototype 0.0 recorder is implemented.

Treat actual-device behavior as more important than simulator-only behavior.
Do not claim Home, screen-lock, or vendor battery-management behavior has been
verified unless the repository contains that evidence or it was verified as
part of the current task.

Platform-specific code is acceptable when Flutter APIs or packages cannot
reliably satisfy background location requirements, but keep native/platform-
specific functionality behind a small interface rather than splitting the
application into separate implementations.

Location permissions must be requested only when required and explained
clearly in the UI.

## Walk data

The existing recorder models and locally persists a walk identifier, start and
end times, ordered GPS points with timestamps, calculated distance and duration,
and completion status. Preserve this local foundation.

The completed MVP 0.1 adds local automatic snapshots and durable corrections.
MVP 0.2-A adds opt-in replay/export diagnostics, without expanding the normal
walk schema or changing classification. Hazards, community data, accounts,
social features and cloud synchronization remain outside this slice.

## Definition of progress

Prefer a working end-to-end slice over many partially implemented layers.

The original 10-minute recorder goal belongs to Prototype 0.0. Its
implementation is the starting point, not the current milestone to rebuild.
Maintain and regression-test this foundation while extending the local journal.

Measure this slice against `docs/product/mvp-0.2-a.md`: deterministic production
replay, explainable loss of surface evidence, correct accounting, privacy-safe
regression coverage and reconciled documentation. Passing tests demonstrates
behavior, not that the provisional matching policy is calibrated for real walks.
Future policy changes must identify a new diagnostic policy version and compare
field outcomes, including incorrect known assignments and legitimate unknowns.

## Quality expectations

Before declaring an implementation complete:

- run `dart format` on changed Dart files;
- run `flutter analyze`;
- run relevant tests;
- report any warnings or failures instead of hiding them.

For behavior that cannot be verified without a physical device, say so
explicitly and provide concise manual verification steps.

## Scope discipline

If completing a request would require solving a substantially larger problem
than requested, stop at the smallest useful boundary and explain the remaining
dependency.

Do not silently expand an MVP task into production infrastructure.

