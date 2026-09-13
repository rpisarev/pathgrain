# Product Decisions

This document records accepted product decisions. Long-term decisions do not
place a feature into the current milestone; current scope is defined by
[MVP 0.2-A](mvp-0.2-a.md).

## D001 — Do not expose live user locations

Status: accepted

We want users to feel that other barefoot walkers exist nearby, but we do not
want Pathgrain to become a people-tracking system.

A future community milestone may consider aggregated activity by a coarse area,
but must not expose another user's live location, distance, or direction.

## D002 — Temporary hazards expire

Status: accepted

If temporary hazard reporting is introduced in a future milestone, reports such
as broken glass must disappear after some time. A new confirmation resets
the expiration timer.

## D003 — Surface detection is correctable

Status: accepted

Automatically inferred surface information is useful but cannot be treated as
authoritative. Users must be able to correct it from the post-walk review.

## D004 — The interface language is changeable

Status: accepted

All user-visible strings must use the localization system. Do not hardcode
user-facing text in widgets.

## D005 — Prototype 0.0 is the implementation baseline

Status: accepted

The existing Android-first local walk recorder is the foundation for subsequent
milestones. It already provides SQLite walk and point persistence, GPS point
filtering, foreground-service recording, saved history, duration and distance,
and MapLibre route review.

MVP 0.1 must extend this recorder rather than recreate it. A replacement is
appropriate only when explicitly scoped and justified by a concrete need.

## D006 — MVP 0.1 is Android-first

Status: accepted

Android is the implementation and acceptance target for MVP 0.1. iOS remains an
intended platform, but iOS background-recording completion is not required for
this milestone.

## D007 — MVP 0.1 tests surface-aware walk review

Status: accepted

MVP 0.1 tests the value of deriving surface segments for a recorded walk,
showing a distance breakdown, and letting the user correct the result. It does
not test social discovery, community presence, or shared contributions.

## D008 — Unknown is preferable to unsupported classification

Status: accepted

Geographic data can be missing, ambiguous, conflicting, or stale. When
Pathgrain cannot make a defensible surface classification, it must show
`unknown` rather than guess a specific surface.

## D009 — MVP 0.1 corrections remain local

Status: accepted

A surface correction is stored on the user's device with the walk and remains
available after restart. MVP 0.1 does not publish, aggregate, or share the
correction globally.

## D010 — MVP 0.1 has no backend or community infrastructure

Status: accepted

MVP 0.1 does not introduce a backend, Supabase/PostGIS, accounts, cloud sync,
community storage, or APIs for future social features. Infrastructure for a
hypothetical later milestone is not needed to deliver the local surface-aware
journal.
