# Product Decisions

# Product decisions

## D001 — Do not expose live user locations

Status: accepted

We want users to feel that other barefoot walkers exist nearby,
but we do not want the app to become a people-tracking system.

Therefore MVP may show aggregated activity by area,
but not distance or direction to another user.


## D002 — Temporary hazards expire

Status: accepted

Reports such as broken glass should disappear after some time.

A new confirmation resets the expiration timer.


## D003 — Surface detection is correctable

Status: accepted

Automatically inferred surface information is useful but cannot be
treated as authoritative.

Users can correct it from the post-walk summary.

## 0004 - Interface language should be changeble

Status: accepted

All user-visible strings must use the localization system. Do not hardcode user-facing text in widgets.
