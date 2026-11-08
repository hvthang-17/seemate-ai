# Module guides

These guides describe the current starter-derived foundation, not completed
SeeMate AI assistance features. Product requirements are in the
[PRD](../tasks/prd-seemate-ai.md); current gaps are listed in the
[codebase summary](codebase-summary.md#implementation-status).

## Home

Home is the reference feature:

```text
CityApi -> CityRepositoryImpl -> GetCities -> HomeCitiesNotifier -> HomeScreen
```

`homeCitiesProvider` starts as `null` so the screen can show an explicit
"Load cities" action. `loadCities()` then publishes `AsyncLoading`,
`AsyncData`, or `AsyncError`. The screen localizes errors and exposes retry.
The dependency path is GetIt → `getCitiesProvider` → `HomeCitiesNotifier`;
GoRouter builds `const HomeScreen()` under the root `ProviderScope`. The current
provider is not auto-disposed when leaving the route. Home is an HTTP example,
not object recognition or OCR.

## Session

`SessionManager.isActive` is the source of truth for the current session. A new
process starts with no active session. `startSession`, explicit logout, and inactivity
expiry update it synchronously; the event stream remains for one-shot
expiry/logout coordination.

There is no sign-in screen or account workflow. `TokenManager` delegates to
`SecureStorageService`, whose current implementation is an in-memory map cleared
on process restart, despite its name. It is not persistent platform secure
storage. Authentication is outside the SeeMate AI MVP.

## Connectivity and offline writes

`ConnectivityService.isOnline` reflects network-interface availability and
`isOffline` is its inverse. This is not an internet-reachability guarantee.

`OfflineQueueService` stores eligible failed writes in Hive. It subscribes to
online changes, replays FIFO on reconnect with a fresh token, exposes
`pendingCount`, and disposes its subscription and box.

`isOnline`, `isOffline`, and `pendingCount` are plain getters; connectivity
changes are exposed through `onlineChanges`. Reading a mutable getter in a
provider does not make it reactive. The queue supports HTTP writes, not offline
AI; do not enqueue camera images, OCR output, or recorded speech.

## Permissions

`PermissionViewModel.statuses` maps app permission enums to current status.
The view model checks, requests, and rechecks known permissions when the app
resumes. Consumers that create it must call `dispose` so its lifecycle observer
is removed.

`statuses` is a plain map getter. The wrapper does not provide a camera preview,
microphone session, or inference lifecycle. Those integrations and their Android
permission declarations are pending MVP work.

## Bootstrap, telemetry, and local data

The [bootstrap](../lib/app.dart) initializes inherited Hive/cache, connectivity,
offline queue, Firebase/error reporting, and analytics before mounting the app.
Firebase services have configuration-dependent fallbacks; their presence does
not demonstrate an offline-only app. The PRD requires an MVP configuration that
disables Firebase Analytics, PostHog, Crashlytics, Remote Config, and Messaging;
this policy is not implemented yet.

Hive cache/queue storage is existing infrastructure. Persistent accessibility
preferences using SharedPreferences are a target integration, not an existing
settings feature. See [PRD section 9.6](../tasks/prd-seemate-ai.md#96-open-decisions-and-validation-gaps).

## Request cancellation

Use `RequestCancellationMixin` only on a concrete view model that issues
cancellable Dio requests. Call its `dispose` from the owning widget or scope.
Do not add a base view-model hierarchy.

The mixin is an inherited Dio helper and is not used by Home's notifier. It is
not a ready-made Riverpod cancellation solution: provider-owned async work
needs explicit cancellation/late-result handling tied to its lifetime.

## Adding a Riverpod-backed feature

1. Define a provider or notifier with the narrowest necessary lifetime.
2. Expose immutable state, using `AsyncValue` for asynchronous work.
3. Derive values in providers rather than duplicating mutable state.
4. Dispose every owned connection with `ref.onDispose` or its service owner.
5. Add a focused test for state transitions and cleanup.
