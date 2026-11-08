# Orchestration Protocol

- Keep tasks scoped to concrete files and acceptance criteria.
- Use parallel work only when file ownership is disjoint.
- Never let two workers edit same file without coordination.
- Reports should be concise and list unresolved questions at end.
- Respect project root as work context for reports and plans.
- Give workers the PDR/PRD sources and distinguish current implementation from target design. Coordinate changes to shared product requirements and agent rules before integration.
- Review combined changes for consistent camera-data policy, TalkBack/speech/lifecycle ownership, and Android verification evidence; shared rules live in development-rules.md.
