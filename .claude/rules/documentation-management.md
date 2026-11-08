# Documentation Management

- Keep `README.md`, `docs/`, `AGENTS.md`, `CLAUDE.md`, and `.cursor/rules/` aligned.
- Update docs after feature structure, setup, command, or workflow changes.
- Prefer short, current examples over long stale walkthroughs.
- Remove references to files that do not exist.
- Use `docs/README.md` as the documentation index. PDR owns product scope; `tasks/prd-seemate-ai.md` owns detailed acceptance/decisions; `docs/codebase-summary.md` owns the implementation snapshot; roadmap records delivery sequence and completion evidence.
- Keep PDR summaries aligned with PRD changes and resolve conflicts explicitly. Link to PRD section 9.6 for decisions and validation rather than creating competing lists.
- Label camera/AI target architecture as unimplemented until source and verification evidence support a status change. Keep actual package/app identity and starter infrastructure distinct from product requirements.
- UI/accessibility guidance currently lives in `docs/code-standards.md` and the PRD design section. Do not reference nonexistent design/deployment guides; add a new guide only when its content is needed and maintain links if introduced.
