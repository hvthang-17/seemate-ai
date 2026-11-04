# Development roadmap

## Complete

- [x] Breaking cutover to Riverpod 2 presentation state
- [x] Home uses `NotifierProvider` and `AsyncValue`
- [x] Session, connectivity, offline queue, and permissions have no Signals dependency
- [x] Home `data/domain/presentation` reference feature
- [x] Typed async state and localized retry UI
- [x] GetIt/Injectable composition and GoRouter route-boundary injection
- [x] New Dart/native identity and setup-wizard expectations
- [x] Focused view-model, service, widget, and setup tests

## Next

- [ ] Replace memory-only token storage with platform secure storage
- [ ] Add a real authentication feature and session-aware redirects
- [ ] Add feature examples only when product requirements need them
- [ ] Add integration tests against an owned staging API
- [ ] Add CI release builds and signed deployment workflows

## Dependency note

Riverpod manages presentation state. GetIt/Injectable remains only the
composition mechanism for infrastructure dependencies.
