# SeeMate AI documentation

SeeMate AI combines Clean Architecture with Riverpod 2 presentation state.

## Guides

- [Quick start](quick-start-guide.md)
- [System architecture](system-architecture.md)
- [Code standards](code-standards.md)
- [Module guides](module-guides.md)
- [Codebase summary](codebase-summary.md)
- [Product requirements](project-overview-pdr.md)
- [Development roadmap](development-roadmap.md)

## State model

- Feature state belongs to a Riverpod provider or notifier.
- Async work uses `AsyncValue<T>`.
- Derived state belongs in a provider rather than duplicated mutable state.
- Screens use `ConsumerWidget` or narrow `Consumer` boundaries.
- Streams, timers, and lifecycle observers are explicitly disposed.
- One-shot UI actions stay at the widget boundary.

Included skills: `flutter-agentic-starter`, `caveman`, and `frontend-design`.
