# Primary Workflow

1. Read `README.md`, `AGENTS.md` and tool-specific instructions. Use the PDR for scope, `tasks/prd-seemate-ai.md` for detailed acceptance/decisions, and codebase summary/source for current implementation. Read relevant code standards and architecture sections.
2. Define assumptions and verifiable success criteria before implementation. Resolve conflicting requirements for affected behavior; identify resource ownership, accessibility, privacy, and offline implications for assistance work.
3. Implement minimal code that satisfies requested behavior.
4. Update docs when structure, workflow, or public usage changes.
5. For app-code changes run `flutter analyze` and `flutter test`, plus relevant Android device checks from development rules/PRD. Generate from source only when applicable. For documentation-only changes check facts, commands, examples, and links.
6. Report changed behavior, verification evidence and limitations, and unresolved questions. Distinguish selected directions, implemented features, and measured validation; never mark a milestone complete without its exit evidence.
