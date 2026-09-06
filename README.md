# Pathgrain

Pathgrain is a privacy-first Flutter app for people who walk barefoot and want
to understand the surfaces they encounter. Personal walk history, ordered GPS
tracks, and point timestamps remain on the user's device.

## Current status

Prototype 0.0 is implemented as an Android-first local walk recorder. It records
filtered GPS points through an Android foreground service, saves walks in
SQLite, calculates duration and distance, retains walk history, and displays
saved routes with MapLibre. Its implementation notes and physical-device
verification boundary are documented in the Android recording note below.

The current milestone is MVP 0.1: extend that recorder into a surface-aware
barefoot walk journal. Its user loop is **Record → Analyze surfaces → Review →
Correct → Save**. MVP 0.1 is deliberately local and Android-first; it does not
include accounts, backend or community infrastructure, cloud sync, hazards,
weather, or route recommendations.

## Documentation

- [Agent and engineering rules](AGENTS.md) — long-lived privacy, engineering,
  Git, quality, and scope rules.
- [Product vision](docs/product/vision.md) — long-term direction, not current
  implementation scope.
- [MVP 0.1 specification](docs/product/mvp-0.1.md) — current milestone scope,
  acceptance criteria, non-goals, and unresolved technical decisions.
- [Product decisions](docs/product/decisions.md) — accepted product choices.
- [Prototype 0.0 Android walk recording](docs/development/android-walk-recording.md)
  — recorder implementation notes and verification limits.

