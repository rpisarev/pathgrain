# Pathgrain Product Vision

## Purpose of this document

This document describes Pathgrain's long-term product direction. It collects
problems and ideas that may shape later milestones; it is not a specification
of what is implemented now or authorization to build all of these features.

The current implementation scope is defined separately in
[MVP 0.1](mvp-0.1.md).

## Product idea

Pathgrain is a mobile app for people who enjoy barefoot walking or want to
explore walking surfaces more consciously. Over time, it should help answer:

- Where can I comfortably walk?
- What surfaces and conditions am I likely to encounter?
- What did I experience on my walks, and how am I progressing?
- Is there a community of people with the same interest in my area?

The product should make barefoot walking easier to explore and feel less
socially isolating without becoming a public, real-time people-tracking
network.

## Long-term experience

A possible mature product loop is:

**Discover → Walk → Record → Review → Improve knowledge**

Users could discover promising areas or routes, record a private walk, review
the surfaces they encountered, correct imperfect information, and choose
whether a deliberately minimized observation can improve shared surface
knowledge. Each part of that loop must be introduced only in a milestone that
defines its privacy boundary and acceptance criteria.

## Surface discovery and a barefoot map

Pathgrain may eventually offer a pre-walk map focused on qualities that matter
to barefoot walkers. Geographic and OpenStreetMap data, local observations, and
other defensible sources could identify surfaces such as grass, asphalt,
concrete, soil, or gravel.

Surface information is an observation, not a permanent fact. Data can be
missing, ambiguous, stale, or locally wrong. The product should display
unknown rather than pretend to know, expose useful provenance where practical,
and let people correct automation. A future shared correction system would
need safeguards before a local observation becomes global data.

## Temporary hazards

A later community milestone may support temporary hazards such as broken glass.
A report could refer to a point or small area, should expire rather than become
a permanent warning, and could remain visible longer when independently
confirmed.

Hazard reporting requires its own decisions about expiry, moderation, abuse,
precision, and privacy. It is not part of the current milestone.

## Anonymous community presence

Pathgrain may help users see that other barefoot walkers exist without exposing
where any individual is now or exactly where they walked. Possible directions
include coarse, aggregated indications that barefoot activity has occurred in a
city or broad area and anonymous, minimized contributions to shared surface
knowledge.

The product must not show another user's live location, distance, direction,
exact route, or a history that makes an individual traceable. Community should
reduce isolation without creating surveillance.

## Privacy and identity

Ordered GPS tracks and their timestamps are personal data and must remain on
the device. Walk history and personal statistics should remain useful without
an account. Any future data leaving the device must have a specific product
purpose and be minimized before transmission.

Accounts may be introduced only where an online capability genuinely needs
identity, such as managing a contribution or preventing abuse. An account
should not become a prerequisite for the private walk journal merely because
community features exist, and community participation should be anonymous by
default where practical.

## Transition and rest locations

Some places are valuable to barefoot walkers even though they are not route
surfaces. A bench, quiet park entrance, washing point, or similar location can
be useful for resting, removing or putting on shoes, or transitioning between
parts of a walk. A future discovery experience may identify these places when
the source data is reliable enough.

## Weather-related surface conditions

Weather can change how a surface feels and whether it is comfortable: pavement
can become hot, grass wet, soil muddy, and paths icy. A future milestone may
combine forecasts or recent conditions with surface information, while clearly
separating predictions from direct observations and avoiding unnecessary
location disclosure.

Weather and condition modeling require separate data-source, freshness,
liability, and privacy decisions.

## Future route discovery

Pathgrain may eventually help users find or plan routes based on surface mix,
comfort preferences, temporary conditions, and useful transition or rest
locations. Route discovery should explain uncertainty and avoid presenting an
inferred condition as guaranteed.

Recommendations must not require uploading a user's full recorded walks. The
data model, routing source, personalization boundary, and offline behavior are
future decisions.

## Product principles

- Privacy before social discovery.
- Community without surveillance.
- A useful local journal should not require an account.
- Surfaces and conditions are observations, not permanent facts.
- Unknown is better than unsupported certainty.
- Temporary hazards must decay.
- Users must be able to correct automation.
- Recording a walk should remain simple.
- Future discovery features must earn their complexity one milestone at a
  time.
