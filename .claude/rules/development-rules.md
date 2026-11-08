# Development Rules

## Principles

- YAGNI, KISS, DRY.
- Karpathy Guidelines: think before coding, keep simple, edit surgically, verify concrete goals.

## Non-Negotiable Rules

- Minimal focused edits are mandatory: touch only files and lines required for the requested behavior.
- Do not rewrite, reformat, reorder, regenerate, or clean up unrelated code unless required by the task.
- Do not create enhanced replacement files; update existing files directly.
- Never manually edit build_runner generated files, including `*.g.dart`, `*.freezed.dart`, `*.config.dart`, or files marked `GENERATED CODE - DO NOT MODIFY BY HAND`.
- Avoid primitive obsession: prefer existing SDK/package types, enums/enhanced enums, sealed classes, or small value objects over raw `String`, raw `int`, raw `bool`, and magic constants for finite or high-risk domain concepts. Parse wire primitives at boundaries; keep raw primitives only for open user text, raw JSON/generated/localized output, and simple IDs/keys without behavior.
- Package-first is mandatory for Flutter/Dart: check and prefer maintained pub.dev packages before implementing reusable utilities, widgets, integrations, or helpers yourself.
- Custom Flutter/Dart implementation is allowed only when no suitable package exists, or when packages fail security, privacy, license, platform, size, performance, or architecture requirements.
- Document any package-first exception in the plan, report, PR, or code review summary.
- For Flutter source icons/images, find suitable existing internet assets instead of creating them yourself. Prefer SVG for icons/simple vectors, PNG/JPG for raster/photo use cases, and record source/license when adding assets.
- Keep ephemeral widget-only UI state local with `StatefulWidget`/`setState`; use Riverpod providers and notifiers for shared, persisted, business-critical, or asynchronous state.
- Use `ConsumerWidget` or focused `Consumer` boundaries. Use `AsyncValue<T>` for loading/data/error and keep derived state in providers.
- Keep navigation, dialogs, and snackbars at the widget boundary. Explicitly dispose every owned stream connection, timer, and lifecycle observer.
- Use `SafeArea`; honor text scaling and accessibility-aware `MediaQuery`.
- Use `LayoutBuilder` for parent constraints and `MediaQuery.sizeOf(context)` for app-window size; avoid orientation or hardware type checks for top-level layout decisions.
- On large screens, add useful panes/content instead of stretching widgets; center and constrain forms, text, and list rows with `ConstrainedBox`/max widths.
- Use lazy builders for long lists/grids. Use `GridView.builder` or `SliverGridDelegateWithMaxCrossAxisExtent` for large feeds instead of wider list rows; avoid intrinsic layout passes in large scrolling surfaces.
- Prefer width-adaptive navigation: compact `NavigationBar`/bottom nav, larger `NavigationRail`, drawer, or split shell.
- Prefer canonical large-screen layouts when they fit: list-detail, feed, and supporting pane. Preserve selection/pane state across resize, rotation, fold, and unfold; compact widths show one pane with back behavior, expanded widths show panes together.
- For foldables, do not lock orientation; use `MediaQuery.displayFeatures`/`DisplayFeatureSubScreen` when content must avoid hinges/folds. Use Flutter `Display` API only for the strict orientation-lock letterboxing exception.
- Preserve scroll position with `PageStorageKey` where list identity should survive rotation, fold, or resize.
- Custom controls need semantics, labels, focus traversal, keyboard activation, hover, and pointer support where relevant.
- Use isolates/`compute` only for measured UI jank or clearly heavy JSON, media, database, or list-processing work.
- Add `restorationScopeId`/`restorationId` for `MaterialApp.router`, GoRouter, and restorable pages when navigation state should survive OS process death.
- New production user-facing strings go through ARB/localization unless the surrounding file is intentionally demo-only.
- Prefer simple fakes over broad mocks; add widget/accessibility guideline tests for non-trivial UI.
- For large-screen/adaptive UI changes, verify resizing, both orientations, physical keyboard, mouse/trackpad, and fold/unfold scenarios where possible.

## Editing

- Use smallest correct patch.
- Preserve existing structure, comments, naming, and formatting unless change requires it.
- Do not revert user changes in dirty worktrees.
- Do not commit secrets, `.env`, API keys, or credentials.
- Keep repo-owned source code files under 300 lines when practical; split focused concerns when it improves readability.
- Do not split generated files, docs, configs, assets, lockfiles, or build artifacts for line count alone.
- Use lower_snake_case for Dart source filenames and preserve established naming for other file types.

## SeeMate AI Product Rules

- Read the PDR for scope and `tasks/prd-seemate-ai.md` for requirements and section 9.6 decisions. Check the codebase summary/source for current behavior. Camera/AI/voice flows and telemetry disabling remain implementation work; do not claim acceptance from a roadmap or a selected package alone.
- Target Android and Vietnamese-first non-visual operation. Provide localized TalkBack labels, logical focus order, at least 48 x 48 dp action targets, text scaling, and feedback that does not rely only on color or the camera preview.
- Keep all core actions accessible by touch. Keep Stop reading reachable during TTS and prioritize interruption. Coordinate app TTS, user-initiated STT sessions, and TalkBack to avoid overlapping speech or recognition of the app's own output.
- Obtain camera/microphone permission before opening their resources. Handle denial, permanent denial, revoked permission, and missing local resources with accessible guidance. Do not require account setup for MVP.
- Do not log, persist, or transmit raw camera frames in MVP flows; do not put them in HTTP cache/offline-write queues. Do not log OCR content or recorded speech. Keep only the local preferences permitted by the PRD; recognition history is outside MVP.
- Bundle detection/OCR models; check installed offline Vietnamese TTS resources and device-specific STT support. Do not automatically fall back to cloud recognition. Missing offline STT must not block touch/TalkBack controls.
- Implement the PRD's telemetry policy: disable Firebase Analytics, PostHog, Crashlytics, Remote Config, and Messaging in the MVP configuration. Any later activation needs a recorded purpose and permitted data scope. Current starter initialization is not proof of compliance.
- Keep GetIt/Injectable at dependency-composition boundaries, bridge dependencies through providers, and let Riverpod own notifiers/state. Routes build screens. Home currently has no automatic disposal on route exit; choose lifetimes explicitly for new features. Plain service getters are not reactive subscriptions.
- Model modes, object keys/class mappings, frame positions, and failures with appropriate types. Validate all required object classes against the final model. EfficientDet-Lite0/COCO is an integration baseline; never silently drop required classes or relabel unrelated detections. Preserve the distinction between frame-relative position and distance/navigation safety.
- Bound camera-frame processing and handle low-confidence/unstable results without confident assertions. Keep speech interruptible with duplicate suppression. Treat the section 9.3 defaults and provisional quality/performance targets as configurations to validate, not measured guarantees.
- Give camera sessions, microphone/STT sessions, TTS playback, inference resources, subscriptions, and observers explicit owners. Stop/release or suspend them appropriately on mode changes, backgrounding, and disposal; reject stale async results. Use `ref.onDispose` for provider-owned resources and never dispose a borrowed GetIt singleton on route exit. Automatic provider disposal does not handle backgrounding by itself.
- Authentication, cloud sync, stored camera images, and recognition history are outside MVP. Add them only after an explicit product-requirement change and update PDR/PRD together.

## Verification

- Run `flutter analyze` after code changes.
- Run `flutter test` after behavior/test changes.
- For injectable, Freezed, or JSON model changes, edit source files only, then run `dart run build_runner build --delete-conflicting-outputs`.
- For ARB changes, run `flutter gen-l10n`; never edit generated localization output by hand.
- For assistance UI/platform changes, verify camera/microphone permission denial and revocation, mode switching, background/resume, missing models/voices, TalkBack/focus/text scaling, stop-TTS behavior, and airplane-mode operation on physical Android devices using the PRD matrix. Emulator and automated tests supplement these checks.
- Report tested devices/configurations and checks not performed. Keep pilot thresholds separate from measured results; do not claim CI test execution while its test step is commented out.
- For documentation/agent-instruction changes only, verify source facts, relative links/anchors, commands, and cross-document consistency; Flutter analysis/tests are required when application code or behavior changes.
