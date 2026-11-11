---
type: Project Memory
title: Coding Patterns
description: Durable coding and architecture patterns agents should preserve in this Flutter starter.
tags: [okf-memory, flutter-agentic-starter, coding-patterns]
timestamp: 2026-11-11T00:00:00+07:00
memory_category: coding-patterns
merged_through: 2026-11-10
---

# Current Patterns

* Keep infrastructure and reusable app code in `lib/core/` and `lib/shared/`.
* Put feature code under `lib/features/<feature>/`.
* Use existing Clean Architecture with presentation, domain, and data layers.
* Use Riverpod 2 providers and `NotifierProvider` with `AsyncValue<T>` for presentation state; do not reintroduce Signals.
* Use `ConsumerWidget` or focused `Consumer` boundaries, derive state with `ref.watch`, and trigger notifier actions with `ref.read`.
* Keep one-shot UI effects at the widget boundary and explicitly dispose owned stream connections, timers, and lifecycle observers.
* Use repositories for data access and use cases for business logic.
* Use GetIt + Injectable for dependency injection.
* Edit source files before regenerating build_runner outputs; never manually edit generated files.
* Prefer maintained pub.dev packages before custom reusable Flutter/Dart utilities, widgets, integrations, or helpers.
* Future Flutter/Dart code should avoid primitive obsession: prefer existing SDK/package types, enums/enhanced enums, sealed classes, or small value objects over raw primitives for finite or high-risk domain concepts.
* Keep ephemeral widget-only state local and limit reactive rebuilds to the smallest useful widget subtree.
* Flutter UI should use `SafeArea`, size-based layouts, semantics, focus/keyboard/pointer affordances for custom controls, lazy builders for long lists/grids, state restoration IDs when needed, and ARB localization for production strings.
* Large-screen UI should use constraint-based layouts, adaptive navigation, useful supporting panes, foldable display-feature handling, and preserved list identity where resizing should retain state.
* OKF memory uses plain markdown concept files with YAML frontmatter and reserved `index.md` and `log.md` files.
* The camera session admits one in-flight consumer. Drop frames when the consumer is busy or the session ID is stale. Borrow frame planes until the adapter returns and release them even when discarding the result.
* Changing assistance mode or target, stopping speech, and disposing the notifier invalidate outstanding results. OCR also receives a cancellation token.
* Android assistance camera sessions open preview on mode selection and start image analysis only when a frame consumer exists. Resume checks permission without automatically prompting again.
* Android detection maps supported model labels and normalizes boxes to the upright frame. The pilot uses same-class association at IoU ≥ 0.50. Recognition requires two same-zone observations in up to three processed frames, and search requires three consecutive same-zone observations. The adapter distinguishes stabilizing, no qualifying match, stable matches, and typed failures.
* The assistance preview preserves aspect ratio inside the scrollable panel, up to 480 dp wide and the lesser of 390 dp or 50% of window height.
* OCR requests one in-memory YUV420 frame from the current camera owner. It stops the temporary image stream and keeps the preview open while bundled Latin ML Kit reads the frame.
* Android TTS selects an installed offline vi-VN voice and identifies each utterance across the platform channel. Stop clears active and queued speech and pauses automatic detection announcements until the user selects a mode or target again.
* N3-03 opens a foreground, user-initiated microphone session. Its command dispatcher shares the touch actions and the v1 target catalog. Capture only works in Read text mode. Evaluation builds bundle Zipformer Vietnamese 30M int8 through `seemateZipformerModelDir` and `seemateSherpaAar`.
* Assistance preferences persist in SharedPreferences and update the speech coordinator after load or save. Audio stays in memory. The voice service parses the transcript before returning the command result.
