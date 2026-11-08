# Codebase summary

This document records the current repository implementation. The
[PDR](project-overview-pdr.md) defines product scope; the
[PRD](../tasks/prd-seemate-ai.md) defines detailed requirements and acceptance.
Requirements and planned technologies do not imply implementation or validation.

## Implementation status

Snapshot: 2026-11-08. SeeMate AI is in the foundation stage, built from Flutter
Agentic Starter. MVP acceptance has not been demonstrated.

| Area | Current repository state | Evidence |
| --- | --- | --- |
| Reference feature | Home loads cities from an HTTP API with loading, data, error, and retry UI | [Home screen](../lib/features/home/presentation/home_screen.dart), [City API](../lib/features/home/data/sources/city_api.dart) |
| Presentation state | Riverpod 2 provider/notifier; GetIt supplies the use case | [Home providers](../lib/features/home/presentation/home_providers.dart) |
| Localization | English ARB resources only; Vietnamese UI is pending | [English resources](../lib/shared/i18n/arb/app_en.arb) |
| MVP assistance flows | Camera capture, object detection/search, relative-position guidance, OCR, STT/TTS, and accessibility preferences are not implemented | [Feature directory](../lib/features/), [Dependencies](../pubspec.yaml) |
| Product validation | Offline recognition, Vietnamese voice resources, model performance, and target-user accessibility acceptance remain unverified | [PRD acceptance criteria](../tasks/prd-seemate-ai.md#3-user-stories) |

The MVP aims to help Vietnamese-speaking blind/low-vision users find everyday
objects and read printed text using local recognition and spoken feedback.
The existing city-loading feature demonstrates architectural boundaries; it
does not perform an assistance task. Selected technical directions and remaining
evidence are tracked in the [PRD decision register](../tasks/prd-seemate-ai.md#96-open-decisions-and-validation-gaps).

## Inherited infrastructure and product gaps

- GetIt/Injectable composes use cases, repositories, and services. Focused
  providers expose dependencies to Riverpod; GoRouter constructs `HomeScreen`
  under the app's `ProviderScope`.
- Dio, cache/Hive, connectivity, and an offline HTTP-write queue are available.
  Queue replay is not offline object detection or OCR, and camera frames must
  not be routed through it.
- Session and token helpers exist, but there is no authentication feature.
  `SecureStorageService` currently uses an in-memory map, not platform-backed
  persistent secure storage. Accounts are outside the MVP scope.
- Permission wrappers and resume rechecks exist; camera capture, microphone
  sessions, AI models, and speech-resource setup have not been integrated.
- Shared widgets, design tokens, English localization, and a Widgetbook catalog
  are present. Vietnamese non-visual task completion and TalkBack acceptance
  have not been demonstrated.
- [Bootstrap](../lib/app.dart) initializes inherited Firebase/analytics services.
  The PRD's telemetry-disabled MVP configuration remains to be implemented.

See [module guides](module-guides.md) for the actual service APIs and
[system architecture](system-architecture.md) for the separately labeled
camera/AI target design.

## Existing verification coverage

The repository contains Home provider-state and router/widget tests, selected
service/shared-widget tests, and setup-tooling tests. Their presence is not a
claim of a passing current test run or coverage of the unimplemented MVP.
The [CI workflow](../.github/workflows/dart.yml) generates code, runs `dart analyze`,
and builds a staging APK; `flutter test` is commented out. Release builds
currently use debug signing in [Android configuration](../android/app/build.gradle).
CI triggers on pushes to `development` or tags matching `v1.*`; no pull-request
trigger is configured. The [evaluation protocol](evaluation-protocol.md) now
defines the planned scoring and evidence procedure; it has not been executed
and does not establish MVP validation.

## Identity

- Product: SeeMate AI
- Starter origin and current Android app label: `Flutter Agentic Starter`
- Dart package: `flutter_agentic_starter`
- App ID: `dev.example.flutteragenticstarter`
- Organization: `Example`

These values describe the current checkout; the product name does not imply
that the Dart package, Android identity, or launcher label has been renamed.
Android currently inherits `flutter.minSdkVersion` rather than explicitly
pinning the proposed API 29 minimum; target-device support still needs validation.

## Structure

```text
lib/
├── app.dart
├── main.dart
├── main_staging.dart
├── main_production.dart
├── core/
│   ├── analytics/
│   ├── auth/
│   ├── cache/
│   ├── connectivity/
│   ├── di/
│   ├── network/
│   ├── permissions/
│   └── router/
├── features/
│   └── home/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── shared/
    ├── i18n/
    └── widgets/
```

## Reactive owners

| Owner | Public state / updates | Lifetime |
| --- | --- | --- |
| `HomeCitiesNotifier` | `homeCitiesProvider`: `AsyncValue<List<City>>?` | App `ProviderScope`; no automatic disposal on route exit |
| `SessionManager` | `isActive`, `events` | App singleton |
| `ConnectivityService` | `isOnline`, `isOffline`, `onlineChanges` | App singleton |
| `OfflineQueueService` | `pendingCount` | App singleton |
| `PermissionViewModel` | `statuses` | Consumer-owned |

The Home feature demonstrates the complete flow from Dio data source through a
repository and use case to `homeCitiesProvider`, a Riverpod `NotifierProvider` with `AsyncValue` state.

Generated registration lives in `lib/core/di/get_it.config.dart` and must only
be changed through source annotations plus build runner.

Shared service getters such as `isActive`, `pendingCount`, and `statuses` are
not Riverpod subscriptions. Only their explicitly exposed streams emit updates;
UI adapters must use an appropriate event source or explicit state owner.
