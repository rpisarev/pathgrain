# Pathgrain — Agent Instructions

## Project

Pathgrain is a privacy-first mobile app for barefoot walking.

The current goal is to build the product incrementally, starting with the smallest technically useful vertical slice.

Do not try to implement the complete product architecture at once.

## Current technology direction

* Flutter
* Dart
* Android and iOS are the intended mobile platforms
* SQLite will be the local source of truth for walks
* MapLibre is the preferred map renderer
* Supabase/PostGIS may be introduced later for community data

Do not introduce Supabase, a custom backend, authentication, cloud sync, analytics, or community features unless explicitly requested.

## Core privacy invariants

These rules are architectural requirements.

* Full GPS walk tracks must remain on the user's device.
* Do not create backend APIs, database tables, or sync mechanisms capable of uploading full walk tracks.
* Do not send GPS coordinates to analytics, crash reporting, logging, or telemetry services.
* Walk history and personal statistics are local data.
* Community data, if introduced later, must be explicitly minimized before leaving the device.
* Prefer privacy by architecture rather than privacy by policy.

## Development philosophy

Pathgrain is currently an MVP.

Prefer:

1. simple implementations;
2. small vertical slices;
3. code that can be tested on a real device;
4. clear interfaces between platform-specific and application code;
5. maintainability over premature abstraction.

Avoid:

* speculative architecture;
* unnecessary packages;
* generic frameworks built for hypothetical future requirements;
* microservices;
* custom backend servers;
* complex synchronization engines;
* CRDTs;
* premature optimization.

When choosing between a simple implementation that satisfies the current requirement and a more extensible implementation for hypothetical future needs, prefer the simple implementation unless the future requirement is already confirmed.

## Working rules for Codex

When the user asks for analysis, architecture, investigation, or a plan:

* do not modify files unless explicitly asked;
* inspect the existing repository first;
* explain important tradeoffs;
* identify unknowns rather than silently guessing.

When asked to implement something:

1. inspect the relevant existing files first;
2. keep the change limited to the requested milestone;
3. reuse the existing project structure where reasonable;
4. do not perform unrelated refactors;
5. do not add unrelated features;
6. run relevant formatting, static analysis, and tests after changes;
7. report what was changed and what was verified.

Before introducing a significant new dependency, explain why it is needed.

Do not replace working project configuration merely to match a preferred template.

Do not delete user code or data unless explicitly instructed.

## Git and change safety

Keep changes small and reviewable.

Do not:

* rewrite Git history;
* force push;
* delete branches;
* remove large groups of files;
* reset or discard existing user changes;

unless explicitly instructed.

If the working tree already contains unrelated user changes, preserve them.

## Mobile location recording

Background GPS recording is a critical technical risk for Pathgrain.

Treat actual-device behavior as more important than simulator-only behavior.

Platform-specific code is acceptable when Flutter APIs or packages cannot reliably satisfy background location requirements, but keep native/platform-specific functionality behind a small interface rather than splitting the application into separate implementations.

Location permissions must be requested only when required and explained clearly in the UI.

## Walk data

For a recorded walk, the application will eventually need data such as:

* walk identifier;
* start time;
* end time;
* ordered GPS points;
* timestamp for each point;
* calculated distance;
* duration.

This data should be modeled so it can be persisted locally.

Do not implement surface detection, surface corrections, hazards, community data, accounts, social features, or cloud synchronization as part of the initial walk-recording milestone unless explicitly requested.

## Definition of progress

Prefer a working end-to-end slice over many partially implemented layers.

For the initial walk-recording milestone, success means a real user can:

1. start a walk;
2. put the phone in their pocket or lock the screen;
3. walk for approximately 10 minutes;
4. stop the walk;
5. see the recorded route;
6. see its duration and distance;
7. close and reopen the application;
8. still see the saved walk locally.

The milestone is not complete merely because GPS works while the app remains open.

## Quality expectations

Before declaring an implementation complete:

* run `dart format` on changed Dart files;
* run `flutter analyze`;
* run relevant tests;
* report any warnings or failures instead of hiding them.

For behavior that cannot be verified without a physical device, say so explicitly and provide concise manual verification steps.

## Scope discipline

If completing a request would require solving a substantially larger problem than requested, stop at the smallest useful boundary and explain the remaining dependency.

Do not silently expand an MVP task into production infrastructure.

