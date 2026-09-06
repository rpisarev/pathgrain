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

### Current target: MVP 0.1

The current target is MVP 0.1: turn the existing recorder into a surface-aware
barefoot walk journal. The milestone scope, acceptance criteria, non-goals, and
open technical decisions are defined in
[docs/product/mvp-0.1.md](docs/product/mvp-0.1.md).

The broader direction in [docs/product/vision.md](docs/product/vision.md) is not
current implementation scope. Accepted product choices are recorded in
[docs/product/decisions.md](docs/product/decisions.md).

## Source-of-truth roles

- `AGENTS.md` contains long-lived engineering, privacy, Git, quality, and scope
  rules for contributors and agents.
- `docs/product/vision.md` describes possible long-term product direction. It
  does not authorize implementation.
- `docs/product/mvp-0.1.md` defines the current milestone and its acceptance
  criteria.
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
  not part of MVP 0.1

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

MVP 0.1 may add only the local surface-analysis and correction data needed by
its specification. Do not add hazards, community data, accounts, social
features, or cloud synchronization as part of MVP 0.1.

## Definition of progress

Prefer a working end-to-end slice over many partially implemented layers.

The original 10-minute recorder goal belongs to Prototype 0.0. Its
implementation is the starting point, not the current milestone to rebuild.
Maintain and regression-test it as MVP 0.1 is added, including physical Android
device testing where required.

Measure current milestone progress against the concrete acceptance criteria in
`docs/product/mvp-0.1.md`. MVP 0.1 is not complete merely because recording
still works or because a surface data layer exists in isolation; the complete
Record → Analyze surfaces → Review → Correct → Save loop must work.

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

