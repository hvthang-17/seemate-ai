---
type: Project Memory
title: Roadmap
description: Current roadmap facts and future direction.
tags: [okf-memory, flutter-agentic-starter, roadmap]
timestamp: 2026-11-09T00:00:00+07:00
memory_category: roadmap
merged_through: 2026-11-08
---

# Current Roadmap

* Migrate future SeeMate AI feature state directly to Riverpod 2; do not extend Signals-based patterns.
* Replace memory-only token storage with platform secure storage when a real authentication feature is added.
* Add integration tests against an owned staging API and CI release builds when deployment is configured.
* Replace the Freezed prerelease with its stable 4.x release when it is available while keeping `signals_lint` enabled.
* Add database, performance, advanced recovery, experimentation, or realtime modules only when product requirements need them.
* Keep agent docs, rules, skills, and OKF memory aligned as the repository evolves.
* Future agents should merge unmerged daily logs into base category files when the latest daily file is not today's date.
* N2 to prepare dataset collection budget and annotation manifest (approx 200-300 images per missing class) for Wallet, Keys, and Bread.
* N1/N3 to verify Android 10 offline TTS/STT capabilities and TalkBack coexistence specifically on the Realme 5i test device.
