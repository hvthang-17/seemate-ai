# AGENTS.md

This file provides repository guidance to Codex, Claude Code, OpenCode, Cursor,
and other coding agents. Explicit user instructions take precedence.

## Project Overview

**Product:** SeeMate AI
**Type:** Flutter/Dart
**Purpose:** Android assistance for blind and low-vision Vietnamese-speaking users: object recognition/search, relative position, and OCR with spoken feedback.
**Current stage:** Starter foundation with a Home city-loading example; camera/AI/voice MVP flows are not implemented.
**Origin:** Flutter Agentic Starter. Current Dart package: `flutter_agentic_starter`; Android namespace/application ID: `dev.example.flutteragenticstarter`; Android app label: `Flutter Agentic Starter`. Do not describe a native/package rename as completed.

## Sources of Truth

Read [README.md](README.md) first, then the documents relevant to the task:

- [PDR](docs/project-overview-pdr.md): problem, users, MVP scope, and exclusions.
- [PRD](tasks/prd-seemate-ai.md): detailed requirements, acceptance, and section 9.6 decisions pending validation.
- [Codebase summary](docs/codebase-summary.md): current implementation; confirm claims against source/tests.
- [Code standards](docs/code-standards.md), [architecture](docs/system-architecture.md), and [quick start](docs/quick-start-guide.md): implementation patterns and commands.
- [Roadmap](docs/development-roadmap.md): sequence and completion evidence, not proof of implemented features.

Resolve requirement conflicts before implementing affected behavior. Keep PDR
summaries aligned with PRD changes and distinguish current code from target design.

## Role & Responsibilities

Your role is to analyze user requirements, delegate tasks to appropriate sub-agents, and ensure cohesive delivery of features that meet specifications and architectural standards.

## Workflows

- Primary workflow: `./.claude/rules/primary-workflow.md`
- Development rules: `./.claude/rules/development-rules.md`
- Orchestration protocols: `./.claude/rules/orchestration-protocol.md`
- Documentation management: `./.claude/rules/documentation-management.md`
- And other workflows: `./.claude/rules/*`

**IMPORTANT:** Analyze the skills catalog and activate the skills that are needed for the task during the process.
**IMPORTANT:** You must follow strictly the development rules in `./.claude/rules/development-rules.md` file.
**IMPORTANT:** Before you plan or proceed any implementation, always read the `./README.md` file first to get context.
**IMPORTANT:** Sacrifice grammar for the sake of concision when writing reports.
**IMPORTANT:** In reports, list any unresolved questions at the end, if any.

## Development Principles

- **YAGNI**: You Aren't Gonna Need It - avoid over-engineering
- **KISS**: Keep It Simple, Stupid - prefer simple solutions
- **DRY**: Don't Repeat Yourself - eliminate code duplication
- **Karpathy Guidelines**: Think before coding, keep changes simple, edit surgically, and define verifiable success criteria.

## Coding Agent Rules

- Read `README.md` and relevant docs before implementation.
- State assumptions when requirements are ambiguous; ask before risky guesses.
- **Hard rule:** Minimal focused edits only. Touch only files and lines required for requested behavior.
- **Hard rule:** Do not rewrite, reformat, reorder, regenerate, or clean up unrelated code unless required.
- **Hard rule:** Never manually edit build_runner generated files, including `*.g.dart`, `*.freezed.dart`, `*.config.dart`, or files marked `GENERATED CODE - DO NOT MODIFY BY HAND`.
- **Hard rule:** Avoid primitive obsession. Prefer existing SDK/package types, enums/enhanced enums, sealed classes, or small value objects over raw `String`, raw `int`, raw `bool`, and magic constants for finite or high-risk domain concepts. Parse wire primitives at boundaries; keep raw primitives only for open user text, raw JSON/generated/localized output, and simple IDs/keys without behavior.
- **Hard rule:** Prefer maintained pub.dev packages before implementing reusable Flutter/Dart utilities, widgets, integrations, or helpers yourself.
- **Hard rule:** For Flutter source icons/images, find suitable existing internet assets instead of creating them yourself. Prefer SVG for icons/simple vectors, PNG/JPG for raster/photo use cases, and record source/license when adding assets.
- Keep ephemeral widget-only UI state local with `StatefulWidget`/`setState`; use Riverpod providers and notifiers for shared, persisted, business-critical, or asynchronous state.
- Use `ConsumerWidget` or focused `Consumer` boundaries. Use `AsyncValue<T>` for loading/data/error and keep derived state in providers rather than duplicated mutable values.
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
- Document any pub.dev package-first exception with reason.
- Keep repo-owned source code files under 300 lines when practical; split focused concerns when it improves readability.
- Respect dirty worktrees. Never revert user changes unless explicitly asked.
- Verify changes with `flutter analyze` and `flutter test` when code changes.
- For generated code changes, edit source files only, then run `dart run build_runner build --delete-conflicting-outputs`.
- Treat `.env`, API keys, tokens, and platform secrets as confidential.

## SeeMate AI Priorities

Follow the [shared product rules](.claude/rules/development-rules.md#seemate-ai-product-rules)
for camera data, TalkBack, speech, lifecycle, model coverage, and Android checks.
These are implementation requirements; they do not imply the starter already
meets them. Keep core actions usable without sight, make Stop reading reachable,
and preserve accessible touch controls when offline speech recognition is absent.
GetIt composes dependencies; Riverpod owns notifiers and feature state; routes
create screens. Authentication and cloud synchronization are outside the MVP.

## Build and Verification Commands

Run from the repository root:

```sh
flutter pub get
flutter run -t lib/main.dart
flutter analyze
flutter test
flutter build apk --release -t lib/main_staging.dart
```

Generate only when relevant sources change: `flutter gen-l10n` for ARB changes;
`dart run build_runner build --delete-conflicting-outputs` for DI/model annotations.
Use focused tests from the quick start, then the required app-code baseline.
For documentation-only changes, check links, commands, examples, and consistency.
Report physical-device checks not performed as unverified; do not claim CI runs
tests while its `flutter test` step remains commented out.

## Documentation

Keep project guides in `docs/`; the detailed PRD currently lives in
`tasks/prd-seemate-ai.md`. Use the [documentation index](docs/README.md).
UI/accessibility guidance lives in the code standards and PRD design section;
use those existing sources instead of referring to a separate design guide.

Root workflow files live in `./.claude/rules/`. Keep `AGENTS.md`,
`CLAUDE.md`, `.cursor/rules/flutter.mdc`, and docs aligned when structure
changes.

## External Files

The existing [opencode.json](opencode.json) loads root agent files, shared
workflow rules, Cursor rules, and `docs/*.md`. Also read the linked PRD for
product work; do not assume that configuration automatically loads `tasks/`.

## Project Skills

Native project skills are provided for Claude Code, Codex, and OpenCode:

- Claude Code: `.claude/skills/`
- Codex: `.agents/skills/`
- OpenCode: `.opencode/skills/`

Available skills:

Use `flutter-agentic-starter` only when implementing Flutter application code
under `lib/`, Flutter tests, or platform integration required by that code. Do
not activate it for documentation, setup tooling, repository automation, or
other non-app maintenance.

- `flutter-agentic-starter`: Flutter, Riverpod, Clean Architecture, DI, routing, models, tests, and design system guidance.
- `caveman`: terse technical communication mode for concise reports.
- `frontend-design`: polished UI/frontend design guidance for user-facing surfaces.

---
