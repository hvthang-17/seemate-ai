# Development roadmap

## Scope and status

As of 2026-11-08, SeeMate AI is in the foundation stage. This roadmap plans
delivery of the Android assistive MVP; it does not mark product flows or
acceptance results as complete. The [PDR](project-overview-pdr.md) defines
scope, the [PRD](../tasks/prd-seemate-ai.md) defines requirements and acceptance,
and the [codebase summary](codebase-summary.md) records current implementation.

Milestones below are ordered by dependency. Close a milestone only when its
outputs and completion evidence are recorded, including relevant automated and
physical-device checks. Keep the [PRD decision register](../tasks/prd-seemate-ai.md#96-open-decisions-and-validation-gaps)
current. Its quality/performance thresholds remain provisional until the pilot
confirms feasibility; do not silently change scope or final acceptance targets.
The [evaluation protocol](evaluation-protocol.md) defines scoring, scene/device
manifests, latency endpoints, user-task outcomes, and evidence reporting. Writing
the protocol does not complete any MVP milestone; execution remains pending.

## Foundation already present

- [x] Home `data/domain/presentation` example loads cities with Riverpod 2
  `NotifierProvider`, `AsyncValue`, and localized retry UI.
- [x] GetIt/Injectable composes dependencies; a provider resolves `GetCities`,
  while GoRouter constructs `HomeScreen` under the app's `ProviderScope`.
- [x] Starter network/cache/connectivity/offline-write queue, session, permission,
  localization, theme, and Widgetbook infrastructure exists.
- [x] Provider, service, widget, and setup test sources exist. This records their
  presence, not a claim that tests have run or passed for the MVP.
- [x] CI includes analysis and a release-mode staging APK build. Its test step
  is currently commented out; signed distribution is not established here.

The package and Android identity still belong to the starter. Camera, model
inference, OCR, speech, Vietnamese UI, and product accessibility validation are
pending. Existing Firebase/analytics initialization must be changed before the
MVP can meet its telemetry policy.

## MVP milestones

### 1. Model, Vietnamese OCR, and voice feasibility

- [ ] **Outputs:** record model artifact/source/license/labels, dataset plan,
  bundled OCR configuration, Vietnamese OCR samples, available STT/TTS resources,
  and named benchmark phones against PRD section 9.6. Use EfficientDet-Lite0 as
  an integration baseline and pilot installed offline Vietnamese TTS.
- **Complete when:** experiments on physical Android hardware demonstrate local
  model execution, Vietnamese OCR and speech-resource readiness, or document
  specific gaps and the work needed to close them. Use the 16-class v1
  vocabulary in PRD section 9.2. Wallet, Keys, and Bread are deferred beyond v1.
  Select package versions after compatibility checks and confirm protocol sample counts,
  task limits, and pilot thresholds before locking independent test data.
- **Dependency:** this establishes the adapters, resources, and feasibility
  evidence needed by milestones 2–5; it does not certify final model quality.

### 2. Accessible shell, camera, and permission lifecycle

- [ ] **Outputs:** Vietnamese accessible mode controls, TalkBack labels/focus,
  touch alternatives, permission-gated camera preview/capture, typed resource
  states, and camera/microphone lifecycle ownership. Apply the MVP policy that
  disables Firebase Analytics, PostHog, Crashlytics, Remote Config, and Messaging.
- **Complete when:** TalkBack users can reach each mode; controls honor text
  scaling and 48 x 48 dp targets; denied/permanently denied permissions and
  app background/resume have accessible outcomes. Camera access starts only
  after permission, owned resources stop/release correctly, and sensitive media
  does not enter logs, storage, network cache, or offline-write queues.
- **Dependency:** milestone 1 resource decisions; this is the shared foundation
  for camera-based detection and OCR.

### 3. Object detection → relative position → target search

- [ ] **Outputs:** bounded on-device frame processing, confidence filtering,
  stable results, left/center/right mapping, supported-object matching, and
  interruptible Vietnamese announcements with a reachable stop control using
  the TTS adapter piloted in milestone 1. Include basic duplicate suppression before continuous speech;
  user-configurable preferences are completed in milestone 5.
- **Complete when:** tests cover class/ID mapping, position boundaries, stability,
  target absence/unsupported targets, and suppression. Physical-device runs
  announce only qualifying matches, provide uncertainty guidance, and avoid
  repeated speech or stale-session results. Record coverage and quality for all
  16 required classes on independent data using the integrated build and
  physical Android devices. This evidence is pending. Position output is
  relative to the camera frame.
- **Dependency:** milestones 1–2; fine-tune or replace the baseline as needed
  to meet the 16-class v1 vocabulary and agreed evaluation thresholds.

### 4. On-demand OCR → Vietnamese reading → stop playback

- [ ] **Outputs:** single-image bundled Latin-script OCR, readable/selectable
  result text, offline Vietnamese TTS, accessible empty/poor-image guidance,
  and a prioritized Stop reading touch control.
- **Complete when:** printed Vietnamese ground-truth samples and airplane-mode
  checks demonstrate the flow; tests cover OCR states and empty results, speech
  cancellation, and missing voice resources. Stop remains reachable during
  playback, does not resume canceled speech, and works with TalkBack active.
  Measure OCR quality and end-to-end latency using the PRD pilot protocol.
- **Dependency:** milestones 1–3; reuse the speech ownership established for
  detection. Voice-triggered stopping is completed with commands in milestone 5.

### 5. Voice commands, local preferences, and announcement policy

- [ ] **Outputs:** user-initiated short Vietnamese command sessions for each
  supported action, local accessibility preferences, restored settings, and
  configurable duplicate suppression shared with detection feedback.
- **Complete when:** commands select the intended mode/target or report an
  unsupported/unrecognized request; offline STT absence keeps touch/TalkBack
  usable without automatic cloud fallback. Voice stop is checked with TTS and
  TalkBack active; settings survive restart without an account or remote sync.
  Automated tests cover parsing, persistence, suppression, and session cleanup.
- **Dependency:** milestones 3–4 provide the actions and playback being controlled;
  this milestone completes the command/preference integration, not the first
  protection against repeated speech.

### 6. Offline, performance, and user acceptance

- [ ] **Outputs:** reproducible acceptance scenes, device/resource/version matrix,
  network audit, per-class detection/OCR results, latency and 15-minute session
  measurements, and per-task user/accessibility evaluation reports. Enable the
  CI test step and retain analysis plus staging APK build checks.
- **Complete when:** milestones 1–5 are integrated; installed-resource flows pass
  airplane-mode checks on the physical-device matrix, with any unavailable
  profile recorded as a coverage gap. Verify telemetry is disabled and no
  camera/OCR/speech content is logged or transmitted. Relevant automated checks
  pass; measured results meet section 8 and the thresholds agreed after the
  pilot. Complete the 5–8-target-user pilot, fixes, and a confirmation round with
  its sample size recorded in advance. Report absolute task completions and
  percentages, separate proxy results, and leave no P0/P1 accessibility defect.
- **Dependency:** all preceding milestones. A staging release-mode APK build
  alone is not evidence of product acceptance or signed distribution readiness.

## Scope boundaries

Authentication, remote session redirects, account token-storage upgrades,
recognition history, and cloud synchronization are not MVP milestones. Add
them only after an explicit product requirement and aligned PDR/PRD change.
Existing starter infrastructure is not a reason to expand the product scope.

Follow [code standards](code-standards.md) and the
[current/target architecture](system-architecture.md): Riverpod owns feature
state, GetIt/Injectable composes dependencies, and router/widget boundaries own
navigation and one-shot UI effects.
