# Code standards

## Feature layout

```text
lib/features/<feature>/
├── data/
│   ├── repositories/
│   └── sources/
├── domain/
│   ├── models/
│   ├── repositories/
│   └── use_cases/
└── presentation/
    ├── <feature>_screen.dart
    └── <feature>_providers.dart
```

Dependencies point inward: presentation uses domain; data implements domain.
Infrastructure shared by features belongs in `lib/core/`.

## Riverpod 2

Use providers/notifiers for feature state. GetIt/Injectable composes use cases,
repositories, and infrastructure; Riverpod creates and owns notifiers. The
reference below is the existing
[Home provider implementation](../lib/features/home/presentation/home_providers.dart),
including imports relative to that file:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/get_it.dart';
import '../../../core/error.dart' as app_error;
import '../domain/models/city.dart';
import '../domain/use_cases/get_cities.dart';

final getCitiesProvider = Provider<GetCities>((ref) => getIt<GetCities>());

final homeCitiesProvider =
    NotifierProvider<HomeCitiesNotifier, AsyncValue<List<City>>?>(
      HomeCitiesNotifier.new,
    );

final class HomeCitiesNotifier extends Notifier<AsyncValue<List<City>>?> {
  @override
  AsyncValue<List<City>>? build() => null;

  Future<void> loadCities() async {
    if (state case AsyncLoading<List<City>>()) return;

    state = const AsyncLoading();
    final result = await ref.read(getCitiesProvider)();
    state = result.fold(
      (app_error.NetworkError error) => AsyncError(error, StackTrace.current),
      AsyncData.new,
    );
  }
}
```

Rules:

- Expose immutable state through a provider; update `state` inside its notifier.
- Use `AsyncValue<T>` for loading/data/error. Home uses `null` for its explicit
  not-yet-requested state; use this only when the UI needs that distinction.
- Derive reactive values in providers using `ref.watch` rather than duplicate
  mutable state. Use `ref.read` for user-triggered notifier actions.
- Keep ephemeral widget-only interaction state local to a `StatefulWidget`.
- Ignore duplicate load actions while loading unless concurrency is intentional.
- Keep Flutter navigation, dialogs, and snackbars at the widget boundary.
- Choose lifetime explicitly: Home's current provider has no `autoDispose`, so
  leaving its route does not dispose its state. For a new auto-disposed feature,
  use the matching Riverpod 2 auto-dispose provider/notifier types and plan
  request cancellation and cleanup; route creation alone does not define scope.

## Widgets and rebuilds

Use `ConsumerWidget` for a screen that watches feature state, or a focused
`Consumer` for a smaller subtree. Home calls `ref.watch(homeCitiesProvider)` in
`build`, and `ref.read(homeCitiesProvider.notifier).loadCities` from its Load
and Retry controls. See [HomeScreen](../lib/features/home/presentation/home_screen.dart).

Render initial, loading, data, and error states explicitly. When using pattern
matching, Home handles `AsyncData` and `AsyncError` before `AsyncLoading`, with
a final `AsyncValue` fallback. Define refresh behavior deliberately so existing
data or errors are not accidentally hidden.

One-shot actions such as navigation, dialogs, and snackbars remain widget
responsibilities. Prefer handling the result of a user action; use widget-level
`ref.listen` when a state transition must trigger a one-shot UI action. Any
explicitly owned subscription must be closed by its owner.

## Disposal

Every object that creates a timer, stream subscription, controller, or
`WidgetsBindingObserver` must release it. Use `ref.onDispose` for
provider-owned resources and widget/service `dispose` for resources owned
there. A provider that borrows a GetIt singleton must not dispose that shared
service when a screen closes. Handle cancellation or late results when an
async operation can outlive its owner.

Do not introduce a base view-model class solely for disposal. Add `dispose`
only to the concrete owner that needs it.

## Data and errors

- Current HTTP data sources translate transport failures into `NetworkError`.
- Current HTTP repositories return `Either<NetworkError, T>`.
- Use cases express domain operations.
- Notifiers map `Either` failures into `AsyncError(error, stackTrace)` and
  successful results into `AsyncData`.
- UI renders a localized generic message and never raw exceptions.
- Parse raw JSON only at data boundaries.

`NetworkError` is the current HTTP example's error type. Camera, model-resource,
OCR, and speech errors belong to the future assistance design; define suitable
typed failures at those boundaries rather than treating them all as HTTP errors.

## Dependency injection

Annotate use cases, repository implementations, and infrastructure, then
regenerate Injectable registrations. Follow existing lifetimes: `GetCities` is
an injectable factory; `CityRepositoryImpl` is registered as a lazy singleton.
Bridge these dependencies into Riverpod with a focused provider such as
`getCitiesProvider`. Keep GetIt lookups in composition/provider boundaries;
notifiers read those providers, and tests override them with fakes.

The root [bootstrap](../lib/app.dart) configures GetIt before mounting
`ProviderScope(child: App())`. The [router](../lib/core/router/router.dart)
builds `const HomeScreen()`; it does not resolve or pass a notifier. Do not
register a second notifier instance in GetIt. Plain provider/notifier
declarations do not require build runner; DI/Freezed/JSON annotation changes do.
Never edit generated files by hand.

## UI and localization

Use Material 3, `SafeArea`, lazy list/grid builders, accessible semantics, and
width-adaptive layouts. Route production text through ARB resources for every
supported locale.

For SeeMate AI's target UI, include Vietnamese TalkBack labels, reachable Stop
reading controls, and non-visual feedback as required by the
[PRD](../tasks/prd-seemate-ai.md). These assistance flows are not implemented
by the current Home example.

## Testing

Use small fakes. Test notifier state transitions with `ProviderContainer` and
dependency overrides, then the user-visible flow under `ProviderScope` with
the same overrides. Dispose test containers. Existing examples:
[Home provider tests](../test/features/home/home_providers_test.dart) and
[router/widget test](../test/widget_test.dart). Test cleanup and reconnection
behavior for long-lived services.

Required baseline:

```sh
flutter analyze
flutter test
```

The commands above are the baseline for app-code changes. Documentation-only
changes require source/example and link checks. See the
[quick start](quick-start-guide.md) for generation and focused test commands.
