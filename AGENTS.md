# Agent Instructions

# Project instructions

## Product

This repository contains a mobile application currently called Pathgrain.

The product is primarily designed around comfortable barefoot walking,
surface awareness, walking routes, and gradual exploration of the environment.

Read `docs/product/mvp-0.1.md` before implementing product features.

## Product principles

- Privacy is a core requirement.
- Do not introduce real-time tracking of other users.
- Social features should remain deliberately lightweight in MVP 0.1.
- Prefer anonymous or aggregated community information where possible.
- Do not expand MVP scope without explicitly noting the proposed scope change.
- Surface and hazard information can become stale and must not be treated as permanently true.
- A user must be able to correct automatically inferred surface information.

## Development

- Keep solutions simple while the product is at MVP stage.
- Avoid adding dependencies without a clear reason.
- When product behavior is ambiguous, check `docs/product/mvp-0.1.md`
  and `docs/product/decisions.md` first.
- Update documentation when an implementation decision changes product behavior.
