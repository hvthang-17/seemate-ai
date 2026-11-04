# Module guides

## Home

Home is the reference feature:

```text
CityApi -> CityRepositoryImpl -> GetCities -> HomeCitiesNotifier -> HomeScreen
```

`homeCitiesProvider` starts as `null` so the screen can show an explicit
"Load cities" action. `loadCities()` then publishes `AsyncLoading`,
`AsyncData`, or `AsyncError`. The screen localizes errors and exposes retry.

## Session

`SessionManager.isActive` is the source of truth for the current session. A new
process starts signed out. `startSession`, explicit logout, and inactivity
expiry update it synchronously; the event stream remains for one-shot
expiry/logout coordination.

## Connectivity and offline writes

`ConnectivityService.isOnline` reflects network-interface availability and
`isOffline` is its inverse. This is not an internet-reachability guarantee.

`OfflineQueueService` stores eligible failed writes in Hive. It subscribes to
online changes, replays FIFO on reconnect with a fresh token, exposes
`pendingCount`, and disposes its subscription and box.

## Permissions

`PermissionViewModel.statuses` maps app permission enums to current status.
The view model checks, requests, and rechecks known permissions when the app
resumes. Consumers that create it must call `dispose` so its lifecycle observer
is removed.

## Request cancellation

Use `RequestCancellationMixin` only on a concrete view model that issues
cancellable Dio requests. Call its `dispose` from the owning widget or scope.
Do not add a base view-model hierarchy.

## Adding a Riverpod-backed feature

1. Define a provider or notifier with the narrowest necessary lifetime.
2. Expose immutable state, using `AsyncValue` for asynchronous work.
3. Derive values in providers rather than duplicating mutable state.
4. Dispose every owned connection with `ref.onDispose` or its service owner.
5. Add a focused test for state transitions and cleanup.
