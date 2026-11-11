---
type: Project Memory
title: Major Changes
description: Significant repository changes agents should know before editing.
tags: [okf-memory, flutter-agentic-starter, major-changes]
timestamp: 2026-11-11T00:00:00+07:00
memory_category: major-changes
merged_through: 2026-11-10
---

# Current Major Changes

* On 2026-11-04, Signals was replaced with Flutter Riverpod 2. The app root now has `ProviderScope` and Home uses a `NotifierProvider`.
* The project is a production-ready Flutter Riverpod starter template with Clean Architecture, GetIt/Injectable DI, GoRouter, Dio, Hive, Firebase/PostHog facades, Material 3, and agent-ready rules.
* `lib/features/home` is the concrete `data/domain/presentation` feature template.
* build_runner generated files such as `*.g.dart`, `*.freezed.dart`, and `*.config.dart` must not be edited manually.
* On 2026-06-18, the project added an OKF v0.1 memory bundle at [okf-memory](/index.md).
* On 2026-06-21, Primitive Obsession / Type Safety guidance was added to agent rules, project skills, Cursor rules, and code standards.
* On 2026-07-01, current adaptive, accessibility, localization, performance, tablet, foldable, ChromeOS, iPad, and desktop-window guidance was aligned across project rules and docs.
* On 2026-07-27, the checked-in identity changed to `Flutter Agentic Starter`, `flutter_agentic_starter`, and `dev.example.flutteragenticstarter`.
* SeeMate AI MVP bootstrap registers analytics with no active providers and explicitly disables PostHog auto-initialization in the Android manifest. Device traffic audit remains pending.
* Android build configuration uses Gradle 8.14.3, AGP 8.13.1, and Kotlin 2.2.21 for compatibility with Flutter 3.47.1. Gradle runs with JDK 17 or 21 in the supported configuration.
* N2 inspected the official EfficientDet-Lite0 int8 v1 artifact and recorded its checksum, embedded labels, tensor shapes, and Realme 5i CPU inference benchmark in the baseline feasibility report.
* N1 connected the Android rear-camera preview through Flutter CameraX and added localized permission and camera error recovery. The driver exposes in-memory YUV420 planes for later adapters.
* Staging uses the production logger registration. Every configuration profile must resolve the startup logger before mounting the app.
* N2 connected YUV420 frames to Android MediaPipe Tasks Vision. The UI shows label, confidence and normalized box beneath the preview. Read text mode keeps the preview open and pauses detection. The feasibility report records Windows real-photo probes with the exact int8 model, with one qualifying bottle detection and two misses.
