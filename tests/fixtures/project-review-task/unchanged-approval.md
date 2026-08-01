---
title: Add a visible status label
overview: Show a status label beside the fixture heading with a focused check.
status: ready
depends: []
release: fixture
---

## Purpose

Make the fixture status visible to keyboard and pointer users.

## Contract

- Render one status label beside the heading using the existing status value.
- Preserve the heading text, reading order, and existing status value.

## Verification

- Run the focused component check and confirm the label and heading order.
