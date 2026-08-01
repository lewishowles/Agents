---
title: Rename the fixture action
overview: Rename the action while preserving its result.
status: ready
depends: []
release: fixture
---

## Purpose

Give the fixture action a clearer name.

## Contract

- Rename `oldAction` to `newAction`.
- Preserve the action result and its existing callers.

## Verification

- Run the focused action test and confirm the old name has no callers.
