# Quick start

## Run the app

Run these commands from the repository root with Flutter installed and an
Android emulator or physical device connected:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -t lib/main.dart
```

| Configuration | Entry point |
| --- | --- |
| Development | [lib/main.dart](../lib/main.dart) |
| Staging | [lib/main_staging.dart](../lib/main_staging.dart) |
| Production | [lib/main_production.dart](../lib/main_production.dart) |

Each entry point selects `ConfigurationProfile.current` before calling
`initializeFlutterApp`. The app opens the SeeMate AI assistance screen.
Use the [Android evaluation build](evaluation/text_speech/n3-03-voice-commands.md)
to bundle the Zipformer and EfficientDet models for device testing.

On the first Android launch, the usage guide can read itself with an installed
offline Vietnamese voice. With accessibility navigation active, use the guide's
Listen button to start speech. Closing the guide stores a local flag. Open
**Settings → Usage guide** to read or hear it again.

On Windows, check the Java version reported by `flutter doctor -v`. If
Flutter selects Android Studio's Java 25, point Flutter at an installed
JDK 21 before running the app. Gradle 8.14.3 supports JDK 21.

```powershell
flutter config --jdk-dir "C:\Program Files\Java\jdk-21.0.11"
flutter doctor -v
flutter run -d 4b3fef9a
```

Use the path to your JDK 21 installation and the device ID from
`flutter devices`. The JDK setting applies to Flutter on this machine.

## Build a feature

Create the narrowest useful vertical slice:

1. Domain model
2. Repository contract
3. Use case
4. Data source and repository implementation
5. Riverpod provider/notifier in `presentation/<feature>_providers.dart`
6. `ConsumerWidget` screen and GoRouter route
7. Provider-state and widget tests

GetIt/Injectable composes use cases, repositories, and infrastructure. A
Riverpod provider bridges a dependency into presentation; Riverpod creates and
owns the notifier. Annotate dependency classes where appropriate, then
regenerate Injectable registrations. Do not register feature notifiers in
GetIt or pass them into screen constructors from routes.

The existing [Home providers](../lib/features/home/presentation/home_providers.dart)
show the pattern. This excerpt uses the imports and types from that file:

```dart
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

The initial `null` represents the explicit Load cities action; loading, data,
and error use `AsyncValue`. [HomeScreen](../lib/features/home/presentation/home_screen.dart)
is a `ConsumerWidget`: `ref.watch(homeCitiesProvider)` rebuilds for state
changes; event callbacks use
`ref.read(homeCitiesProvider.notifier).loadCities`. Render a localized error
and retry control at the widget boundary. For new features, choose an explicit
initial state that fits the flow rather than assuming every provider is nullable.

The current Home provider has no `autoDispose`; it retains state in the app's
`ProviderScope` when a route loses listeners. Choose provider lifetime
deliberately for new features and register cleanup for owned resources with
`ref.onDispose`. Shared GetIt services retain their own lifecycle ownership.

## Connect providers and routing

[App initialization](../lib/app.dart) calls `configureDependencies()` before
mounting the app with `runApp(const ProviderScope(child: App()))`. Tests can
override `getCitiesProvider` to supply a fake without initializing GetIt.

[GoRouter](../lib/core/router/router.dart) constructs the screen; the screen
reads its providers under the root `ProviderScope`:

```dart
GoRoute(
  path: '/',
  builder: (_, _) => const HomeScreen(),
)
```

Keep navigation, dialogs, and snackbars in widgets. See
[Code standards](code-standards.md) for state and disposal rules and
[System architecture](system-architecture.md) for the current dependency flow
and the separately labeled camera/AI target design.

## Generate and verify

```sh
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Run focused reference tests when changing this flow:

```sh
flutter test test/features/home/home_providers_test.dart test/widget_test.dart
```

[Provider tests](../test/features/home/home_providers_test.dart) override
`getCitiesProvider` through `ProviderContainer` and dispose the container.
[The widget test](../test/widget_test.dart) supplies the same override through
`ProviderScope` and verifies the routed Home screen.

Regenerate from source annotations/ARB files when needed; never manually edit
generated Injectable, Freezed, JSON, or localization output.
