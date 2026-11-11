# SeeMate AI documentation

SeeMate AI combines Clean Architecture with Riverpod 2 presentation state.

## Document roles and sources of truth

| Document | Role | Authoritative for |
| --- | --- | --- |
| [Project overview (PDR)](project-overview-pdr.md) | Product overview | Problem, target users, MVP scope, and exclusions |
| [Product requirements (PRD)](../tasks/prd-seemate-ai.md) | Detailed requirements | User stories, functional requirements, acceptance criteria, and success metrics |
| [Codebase summary](codebase-summary.md) | Implementation snapshot | What exists in the repository and what remains unimplemented |

The PDR summarizes the PRD; it does not introduce separate acceptance criteria.
Keep both aligned when product scope or requirements change. Resolve any
conflict explicitly before implementing the affected behavior.

For current behavior, verify the implementation snapshot against source code
and tests. A requirement, roadmap item, or technical proposal is not evidence
that a feature is implemented or validated. Record implementation changes in
the codebase summary and keep proposed architecture distinct from current
architecture.

As of 2026-11-08, the project is in the foundation stage. The existing Home
feature loads cities as a starter example; the SeeMate AI recognition and voice
flows are not implemented. See the [implementation snapshot](codebase-summary.md#implementation-status)
and the [open decisions register](../tasks/prd-seemate-ai.md#96-open-decisions-and-validation-gaps).

## Guides

- [Quick start](quick-start-guide.md)
- [System architecture](system-architecture.md)
- [Code standards](code-standards.md)
- [Module guides](module-guides.md)
- [Codebase summary](codebase-summary.md)
- [Project overview (PDR)](project-overview-pdr.md)
- [Product requirements (PRD)](../tasks/prd-seemate-ai.md)
- [Development roadmap](development-roadmap.md)
- [Three-person work plan](team-work-plan.md): file ownership, task dependencies, and push/review/merge gates.
- Member guides: [N1 platform/UI](team-member-01-platform.md), [N2 detection](team-member-02-detection.md), [N3 OCR/speech](team-member-03-ocr-speech.md).
- [Evaluation protocol](evaluation-protocol.md): scoring and evidence procedure; execution and provisional-threshold confirmation are pending.
- [Zipformer voice commands on Android](evaluation/text_speech/n3-03-voice-commands.md): model files, APK build and Realme 5i evaluation.

## State model

- Feature state belongs to a Riverpod provider or notifier.
- Async work uses `AsyncValue<T>`.
- Derived state belongs in a provider rather than duplicated mutable state.
- Screens use `ConsumerWidget` or narrow `Consumer` boundaries.
- Streams, timers, and lifecycle observers are explicitly disposed.
- One-shot UI actions stay at the widget boundary.

Included skills: `flutter-agentic-starter`, `caveman`, and `frontend-design`.
