---
type: Project Memory
title: Decision Changes
description: Accepted or superseded decisions that change future implementation choices.
tags: [okf-memory, flutter-agentic-starter, decisions]
timestamp: 2026-07-27T00:00:00+07:00
memory_category: decision-changes
merged_through: 2026-07-27
---

# Current Decisions

* Use a root [OKF memory bundle](/index.md) as the durable project memory source of truth.
* Organize consolidated long-term memory by category files under [base](/base/), not one monolithic base file.
* Manage daily rollover through agent skill instructions, not an app runtime change or automation script.
* Keep OKF memory docs-only: no Flutter app runtime or package dependency changes.
* Aggressive typing is a future-code guardrail first, not a retroactive app-wide refactor unless explicitly requested.
* Riverpod 2 supersedes Signals 7 for presentation state. Use providers/notifiers and `AsyncValue`; do not mix Signals with Riverpod in a feature.
* Session authentication is intentionally volatile until platform secure storage is implemented.
* `signals_lint` is enabled as an analyzer plugin. It requires the compatible Injectable 3 and Freezed 4 prerelease generator line until Freezed 4 is stable.
