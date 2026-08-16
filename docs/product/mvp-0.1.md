# MVP 0.1

## 1. Product idea

A mobile application for people who enjoy barefoot walking
or want to explore walking surfaces more consciously.

The app should help answer:

- Where can I comfortably walk?
- What surfaces will I encounter?
- How am I progressing?
- Are there other people with the same interest in my area?

The product should normalize the hobby without turning it
into a public real-time social tracking network.

## 2. Core user problems

Priority problems identified so far:

1. It is difficult to know whether there are other people nearby
   with the same interest.
2. Social judgement can make barefoot walking uncomfortable.
3. Surface conditions are uncertain.
4. Temporary hazards such as broken glass can make a route unpleasant
   or unsafe.

## 3. MVP core loop

The main loop is:

Discover → Walk → Record → Review → Improve map

A user:

1. Opens the map.
2. Finds an interesting area or route.
3. Starts a walk.
4. The application records the walk.
5. Surface types are inferred where possible.
6. After the walk, the user sees a summary.
7. The user may correct incorrectly detected surface information.
8. Useful corrections contribute to better surface information.

## 4. Walk recording

A walk is a distinct activity/session.

Record at minimum:

- route
- start/end
- duration
- distance
- encountered surfaces

Possible future statistics must not unnecessarily complicate MVP 0.1.

## 5. Surface map

The map can represent surface types such as:

- grass
- asphalt
- concrete
- soil
- gravel
- other/unknown

Surface information may initially come from external/geographic data
and may be corrected by users.

Example:

If an area is classified as grass but gravel has been spread there,
the user should be able to correct the walk summary/map information.

## 6. Temporary hazards

Users may report temporary hazards such as broken glass.

A hazard may be represented as a point or a small area.

Hazards must expire rather than remain permanently on the map.

If another user confirms that the hazard is still present,
its expiration timer starts again.

## 7. Community presence

MVP should show that other barefoot walkers exist without exposing
their real-time location.

Allowed direction:

- aggregated/anonymized indication that barefoot activity has occurred
  in a city or area
- anonymous community contributions

Not allowed in MVP:

- showing another user's live location
- showing distance to another barefoot user
- showing direction to another barefoot user
- turning the map into a people-tracking system

## 8. Identity and accounts

The app should provide useful functionality without requiring an account
where practical.

Some online/community functionality may require an account.

Community information should be anonymous by default.

## 9. Places useful for starting/ending barefoot walks

The product may eventually mark convenient transition/rest places.

Example:
a park bench can be a comfortable place to sit down, remove shoes,
and continue the walk barefoot.

Exact MVP 0.1 scope for these places remains to be decided.

## 10. Explicit non-goals for MVP 0.1

Do not build yet:

- real-time user tracking
- dating/social matching
- complex friend systems
- competitive gamification
- large achievement systems
- advanced route recommendation AI
- unnecessary backend complexity

## 11. Product principles

- Privacy before social discovery.
- Community without surveillance.
- Surfaces are observations, not permanent facts.
- Temporary hazards must decay.
- Users must be able to correct automation.
- Recording a walk should remain simple.
