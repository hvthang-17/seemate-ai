# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context and Sources

Product: SeeMate AI, an Android assistive app for blind and low-vision
Vietnamese-speaking users. The repository is currently a Flutter Agentic Starter
foundation with Home loading cities; camera/AI/voice flows are target features.
The Dart package remains `flutter_agentic_starter`, Android namespace/app ID
`dev.example.flutteragenticstarter`, and Android label `Flutter Agentic Starter`.

Read [README.md](README.md) first and follow [AGENTS.md](AGENTS.md), including
its sources of truth and build/verification commands. The
[PDR](docs/project-overview-pdr.md) owns scope, the
[PRD](tasks/prd-seemate-ai.md) owns detailed acceptance and decisions, and the
[codebase summary](docs/codebase-summary.md) records current implementation.
Explicit user instructions take precedence. Resolve conflicting requirements
before implementing the affected behavior; planned features are not completed work.

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

## Karpathy Guidelines

Behavioral guidelines to reduce common LLM coding mistakes:

- Think before coding. State assumptions, surface tradeoffs, ask when unclear.
- Simplicity first. Minimum code that solves the requested behavior.
- Surgical changes. Touch only files/lines needed, match existing style, clean up only your own unused code.
- Goal-driven execution. Define success criteria and verify with concrete checks.

## Hard Development Rules

- Minimal focused edits are mandatory. Touch only files and lines required for requested behavior.
- Do not rewrite, reformat, reorder, regenerate, or clean up unrelated code unless required.
- Never manually edit build_runner generated files, including `*.g.dart`, `*.freezed.dart`, `*.config.dart`, or files marked `GENERATED CODE - DO NOT MODIFY BY HAND`.
- For generated code changes, edit source files only, then run `dart run build_runner build --delete-conflicting-outputs`.
- Avoid primitive obsession. Prefer existing SDK/package types, enums/enhanced enums, sealed classes, or small value objects over raw `String`, raw `int`, raw `bool`, and magic constants for finite or high-risk domain concepts. Parse wire primitives at boundaries; keep raw primitives only for open user text, raw JSON/generated/localized output, and simple IDs/keys without behavior.
- Prefer maintained pub.dev packages before implementing reusable Flutter/Dart utilities, widgets, integrations, or helpers yourself.
- Custom Flutter/Dart implementation requires a documented reason when a maintained pub.dev package is not used.
- For Flutter source icons/images, find suitable existing internet assets instead of creating them yourself. Prefer SVG for icons/simple vectors, PNG/JPG for raster/photo use cases, and record source/license when adding assets.
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
- Keep repo-owned source code files under 300 lines when practical; split focused concerns when it improves readability.

## SeeMate AI Product Rules

Read and follow the [shared product rules](.claude/rules/development-rules.md#seemate-ai-product-rules).
Protect camera/OCR/speech data, prioritize Vietnamese TalkBack and interruptible
TTS, and verify camera/voice/offline behavior on Android. Missing offline STT
must leave accessible touch controls usable with no automatic cloud fallback.
Own and clean up camera/microphone/inference resources across mode and lifecycle
changes. GetIt composes dependencies; Riverpod owns notifiers; routes build screens.
Authentication and cloud synchronization are outside MVP scope.

## Project Skills

Claude Code project skills live in `.claude/skills/`.

Available skills:

Use `flutter-agentic-starter` only when implementing Flutter application code
under `lib/`, Flutter tests, or platform integration required by that code. Do
not activate it for documentation, setup tooling, repository automation, or
other non-app maintenance.

- `flutter-agentic-starter`: Flutter, Riverpod, Clean Architecture, DI, routing, models, tests, and design system guidance.
- `caveman`: terse technical communication mode for concise reports.
- `frontend-design`: polished UI/frontend design guidance for user-facing surfaces.

## Hook Response Protocol

### Privacy Block Hook (`@@PRIVACY_PROMPT@@`)

When a tool call is blocked by the privacy-block hook, the output contains a JSON marker between `@@PRIVACY_PROMPT_START@@` and `@@PRIVACY_PROMPT_END@@`. **You MUST use the `AskUserQuestion` tool** to get proper user approval.

**Required Flow:**

1. Parse the JSON from the hook output
2. Use `AskUserQuestion` with the question data from the JSON
3. Based on user's selection:
   - **"Yes, approve access"** → Use `bash cat "filepath"` to read the file (bash is auto-approved)
   - **"No, skip this file"** → Continue without accessing the file

**Example AskUserQuestion call:**
```json
{
  "questions": [{
    "question": "I need to read \".env\" which may contain sensitive data. Do you approve?",
    "header": "File Access",
    "options": [
      { "label": "Yes, approve access", "description": "Allow reading .env this time" },
      { "label": "No, skip this file", "description": "Continue without accessing this file" }
    ],
    "multiSelect": false
  }]
}
```

**IMPORTANT:** Always ask the user via `AskUserQuestion` first. Never try to work around the privacy block without explicit user approval.

## Python Scripts (Skills)

When running Python scripts from `.claude/skills/`, use the venv Python interpreter:
- **Linux/macOS:** `.claude/skills/.venv/bin/python3 scripts/xxx.py`
- **Windows:** `.claude\skills\.venv\Scripts\python.exe scripts\xxx.py`

This ensures packages installed by `install.sh` (google-genai, pypdf, etc.) are available.

**IMPORTANT:** Diagnose skill-script failures and fix them within the authorized task scope; preserve unrelated tooling and user changes.

## [IMPORTANT] Consider Modularization
- If a touched source code file exceeds 300 lines, consider modularizing it when it improves readability
- Check existing modules before creating new
- Analyze logical separation boundaries (functions, classes, concerns)
- Use lower_snake_case for Dart source filenames, matching the existing repository. Preserve established naming conventions for other file types.
- Write descriptive code comments
- After modularization, continue with main task
- When not to modularize: generated files, Markdown files, plain text files, bash scripts, configuration files, environment variables files, assets, lockfiles, build artifacts, etc.

## Documentation Management

Keep guides in `docs/` and detailed requirements in `tasks/prd-seemate-ai.md`.
Use the [documentation index](docs/README.md) and
[development roadmap](docs/development-roadmap.md). UI/accessibility guidance
is in [code standards](docs/code-standards.md) and the PRD design section.
Keep current implementation, target design, and benchmark evidence distinct.
Follow the shared documentation-management workflow when updating these files.

**IMPORTANT:** *MUST READ* and *MUST COMPLY* all *INSTRUCTIONS* in project `./CLAUDE.md`, especially *WORKFLOWS* section is *CRITICALLY IMPORTANT*, this rule is *MANDATORY. NON-NEGOTIABLE. NO EXCEPTIONS. MUST REMEMBER AT ALL TIMES!!!*
