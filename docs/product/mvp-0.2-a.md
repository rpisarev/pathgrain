# MVP 0.2-A — Real-world surface diagnostics and replay

Status: implemented; host validation is recorded in the
[development note](../development/mvp-0.2-a-surface-diagnostics-replay.md).

## Starting point and purpose

MVP 0.1 and slices A–F are complete. The initial local Android
Record → Analyze surfaces → Review → Correct → Save cycle was physically
accepted on Pixel, with a separate F taxonomy upgrade spot-check. Those
acceptance records remain bounded; broader device and iOS validation is open.

Walk 8 exposed the next problem: 191 saved points across ~1.446 km produced
80 unknown surface segments. Frozen replay reproduced the persisted result.
The recorder/storage pipeline worked; reliable surface coverage needs evidence
and matching research. Missing OSM tags explain only part of that result.

0.2-A makes that failure maintainably observable before changing policy. For a
saved route and fixed local evidence, developers can distinguish source scarcity,
eligibility rejection, score/veto rejection, selected features without material,
and supported endpoint evidence that fails to reach final edges.

## Scope and acceptance

- Reuse production cell selection, evidence assembly, matcher, surface rules,
  edge gates and segmentation in deterministic offline replay.
- Export a versioned JSON report with candidate scores/gates, GPS state,
  endpoint selections, material mappings, final edge reasons and complete meter
  accounting. Define overlapping observations separately from final reasons.
- Define broad and eligible supported-evidence ceilings without claiming they
  establish the real walked surface or attainable coverage.
- Keep verbose diagnostics outside the user walk database. Raw captures and
  local replay exports stay ignored/untracked; normal tests use synthetic data.
  An explicit private walk-8 regression checks the full original failure.
- Reconcile current documentation against code and acceptance records. Preserve
  earlier milestone notes as history and link superseded current claims forward.
- Pass formatting, static analysis, focused and full tests, and a debug Android
  build when the toolchain is available. Host verification is separate from
  physical acceptance and matching accuracy.

## Non-goals and next decision

This slice changes no scores, margins, confidence thresholds, ambiguity vetoes,
geometry eligibility, footway/crossing exceptions, taxonomy mapping or endpoint
propagation. It adds no probabilistic/highway/weather guessing, backend inference,
product feature or Surface Review redesign. Unknown remains legitimate when
evidence is insufficient.

The next proposed slice is a bounded multi-walk policy/geometry evaluation using
these diagnostics and observed surfaces. Candidate topics include concave
pedestrian areas, heading availability and veto calibration. None is approved
as an implementation merely by appearing here. Provider changes, richer UX,
conditions, community and production hardening remain separate future work.

## Documentation roles

- [README](../../README.md): current project status and development entry points.
- [Current pipeline reference](../reference/surface-pipeline.md): implemented
  recorder/storage/evidence/matching/journal behavior.
- This document: 0.2-A scope and acceptance, not an algorithm specification.
- [Diagnostic guide and field record](../development/mvp-0.2-a-surface-diagnostics-replay.md):
  reproducible commands, JSON contracts, metrics, limitations and audit record.
- [MVP 0.1](mvp-0.1.md) and its A–F notes: completed scope and historical
  implementation/acceptance. F's explicit taxonomy/migration reference remains
  current while its execution/acceptance history remains historical.
- [Decisions](decisions.md): accepted product decisions;
  [vision](vision.md): long-term direction without implementation authorization.
