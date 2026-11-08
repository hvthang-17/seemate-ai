# PRD: SeeMate AI

This document is the source of truth for detailed product requirements, user
stories, acceptance criteria, and success metrics. The
[PDR](../docs/project-overview-pdr.md) owns the product overview and MVP scope;
keep its summaries aligned with this PRD when requirements change. Resolve
conflicts explicitly before implementing affected behavior.

Status as of 2026-11-08: foundation stage. The MVP flows described below are
requirements for the target product, not completed features or measured
results. See the [codebase summary](../docs/codebase-summary.md#implementation-status)
for current implementation and section 9.6 for implementation decisions and
remaining validation work.

## 1. Introduction / Overview

SeeMate AI is an Android application that helps blind people and people with low vision perceive nearby objects and printed text through a phone camera and spoken feedback. It reduces dependence on another person for common tasks such as finding a water bottle, reading a product label, or understanding where a detected object appears in the camera view.

The MVP combines three AI-assisted flows in one accessible app: object detection, text reading (OCR), and relative-position guidance. Core recognition is designed to run on-device after required models and language data are present. The product is an assistive tool only; it does not replace a white cane, guide dog, or professional mobility aid.

## 2. Goals

- Let a Vietnamese-speaking user start an object-search, object-recognition, or text-reading task with a voice command or accessible touch control.
- Detect supported object classes on-device and announce a qualifying object's name and relative horizontal position: left, center, or right.
- Extract visible Vietnamese text from the camera on request and read the extracted text aloud.
- Keep the core object-detection and OCR flows usable without an Internet connection after required on-device resources are installed.
- Give actionable spoken guidance instead of asserting a low-confidence result.
- Validate the three core flows with target users or an equivalent accessibility test protocol before MVP acceptance.

## 3. User Stories

### US-001: Start an accessible assistance mode
**Description:** As a blind or low-vision user, I want to select a recognition mode with speech or an accessible control so that I can use the app without relying on precise visual touch targets.

**Acceptance Criteria:**
- [ ] The home screen exposes Object recognition, Find an object, Read text, and Stop reading as controls with Vietnamese accessibility labels.
- [ ] The app accepts the Vietnamese commands “Nhận diện đồ vật”, “Tìm [tên đồ vật]”, “Đọc văn bản”, and “Dừng đọc”, or announces that it could not understand the command.
- [ ] Every action has a touch alternative when speech recognition is unavailable.
- [ ] Voice input uses user-initiated short command sessions; unavailable offline recognition never triggers an automatic cloud fallback.
- [ ] Controls are reachable with Android TalkBack and have a minimum 48 x 48 dp touch target.
- [ ] `flutter analyze` and relevant widget tests pass.
- [ ] Verify in browser using dev-browser skill if a Flutter web build is enabled; otherwise verify on an Android emulator or physical device with TalkBack.

### US-002: Recognize nearby objects
**Description:** As a user, I want the app to identify supported objects in the camera view so that I can understand what is in front of me.

**Acceptance Criteria:**
- [ ] The app requests camera permission before starting a camera session and gives an accessible explanation if permission is denied.
- [ ] A captured frame is processed by the bundled on-device object-detection model without sending the frame to an application server.
- [ ] For each retained detection, the result includes a supported label and confidence score.
- [ ] The app speaks a result only when it meets the configured confidence threshold.
- [ ] When no detection qualifies, the app says that it cannot identify the object and suggests improving lighting, focus, or camera angle.
- [ ] `flutter analyze` and automated detection-result mapping tests pass.

### US-003: Find a requested object
**Description:** As a user, I want to ask for a specific supported object so that I can locate it more independently.

**Acceptance Criteria:**
- [ ] A command such as “Tìm chai nước” starts a search for the mapped supported object label.
- [ ] While the target is absent, the app does not announce unrelated detections as a successful match.
- [ ] When the target qualifies, the app announces its name and relative position.
- [ ] If the requested object is unsupported, the app states this in Vietnamese and does not start a misleading search.
- [ ] Repeated matching results within the configured suppression interval are not read again.
- [ ] `flutter analyze` and unit tests for target matching and duplicate suppression pass.

### US-004: Announce relative object position
**Description:** As a user, I want to hear whether a detected object is on the left, center, or right so that I can adjust the camera direction.

**Acceptance Criteria:**
- [ ] The app derives position from the horizontal center of the detected bounding box relative to the camera frame.
- [ ] The frame is partitioned into exactly three configurable horizontal zones: left, center, and right.
- [ ] A qualifying result produces a Vietnamese message such as “Chai nước ở bên trái”.
- [ ] The UI and spoken guidance describe position as relative to the camera frame, not as distance or navigational safety information.
- [ ] Boundary-zone mapping is covered by automated tests.

### US-005: Read printed Vietnamese text
**Description:** As a user, I want the app to extract and read visible text so that I can access labels and documents.

**Acceptance Criteria:**
- [ ] “Đọc văn bản” captures one suitable image for on-demand OCR using the bundled Google ML Kit Text Recognition v2 Latin-script model.
- [ ] The app displays the extracted text in a readable, selectable result area and passes it to Android Text-to-Speech in Vietnamese.
- [ ] “Dừng đọc” immediately stops active Text-to-Speech playback.
- [ ] The Stop reading touch control remains reachable during playback; voice-stop behavior is checked with TTS and TalkBack active.
- [ ] Empty or unusable OCR output produces a spoken suggestion to improve lighting, focus, framing, or distance.
- [ ] The app does not claim verbatim accuracy when OCR confidence or quality is insufficient.
- [ ] `flutter analyze` and OCR-state/widget tests pass.
- [ ] Verify in browser using dev-browser skill if a Flutter web build is enabled; otherwise verify on an Android emulator or physical device.

### US-006: Operate core functions offline
**Description:** As a user, I want the essential features to work without Internet so that I can use the app in more situations and keep camera content private.

**Acceptance Criteria:**
- [ ] With airplane mode enabled and required model/language resources already installed, object detection completes locally.
- [ ] With airplane mode enabled and the required ML Kit package installed, OCR completes locally.
- [ ] The app shows a clear local-resource setup state when a required model or Vietnamese TTS voice is unavailable.
- [ ] Object-detection and OCR models are bundled with the app; Vietnamese TTS uses an installed voice that does not require a network connection.
- [ ] Speech-to-Text offline support is detected or documented as device-dependent; touch controls remain usable if it is unavailable.
- [ ] No image frame is uploaded by an MVP recognition flow.
- [ ] Offline verification steps are documented and executed on physical Android devices using the matrix in section 9.6; emulator checks are supplementary.

### US-007: Persist user preferences locally
**Description:** As a user, I want my accessibility preferences retained on my phone so that I do not need to configure the app each time.

**Acceptance Criteria:**
- [ ] The app persists at least speech rate, spoken-feedback enabled state, and duplicate-announcement suppression setting locally.
- [ ] Settings are restored on the next application launch without requiring an account.
- [ ] The MVP does not send settings or recognition history to a remote service.
- [ ] `flutter analyze` and persistence tests pass.

## 4. Functional Requirements

1. **FR-1:** The system must run on Android and provide a Vietnamese-first accessible interface.
2. **FR-2:** The system must obtain camera frames only after Android camera permission is granted.
3. **FR-3:** The system must support object-recognition, target-object search, OCR reading, and stop-reading modes through both accessible touch controls and the defined Vietnamese voice commands.
4. **FR-4:** Object detection must use an on-device TensorFlow Lite/LiteRT model and only report labels included in the model's supported class list.
5. **FR-5:** The system must filter detections by a configurable confidence threshold before visual or spoken reporting.
6. **FR-6:** The system must classify a reported detection as left, center, or right from its bounding-box center; it must not expose this value as a distance measurement.
7. **FR-7:** In target-search mode, the system must announce success only for a detection mapped to the requested target.
8. **FR-8:** The system must suppress repeated spoken announcements of the same qualifying result over consecutive frames for a configurable interval.
9. **FR-9:** OCR must use Google ML Kit Text Recognition configured for on-device use and read extracted Vietnamese text through Text-to-Speech.
10. **FR-10:** The system must stop Text-to-Speech immediately on a Stop reading command or control.
11. **FR-11:** When recognition quality is inadequate, the system must provide a non-assertive Vietnamese corrective prompt rather than a confident label.
12. **FR-12:** The system must retain supported settings locally using SharedPreferences and/or SQLite/Drift; no account is required for MVP.
13. **FR-13:** The core object-detection and OCR flows must not require an Internet connection after their required on-device resources are installed.
14. **FR-14:** The system must continue to offer touch controls when device speech recognition cannot operate offline.
15. **FR-15:** The app must clearly state in onboarding and relevant result screens that it is not a mobility-navigation or obstacle-avoidance system.
16. **FR-16:** Voice-command sessions must be user-initiated and prefer on-device recognition; the app must not automatically fall back to cloud recognition when offline support is unavailable.
17. **FR-17:** The MVP configuration must disable Firebase Analytics, PostHog, Crashlytics, Remote Config, and Messaging, and must not log camera frames, extracted OCR content, or recorded speech.

## 5. Non-Goals (Out of Scope)

- Measuring exact distance, depth, object size, or safe walking paths.
- Replacing white canes, guide dogs, orientation-and-mobility training, or dedicated safety equipment.
- Guaranteeing detection of every object, obstacle, or Vietnamese text under all lighting and camera conditions.
- Cloud image processing, image storage, user accounts, cross-device sync, or recognition-history synchronization.
- A guarantee that Speech-to-Text works offline on every Android device.
- iOS, web, desktop, or wearable releases in the MVP.
- Identifying people, faces, emotions, currency authenticity, medical information, or hazardous objects as safety-critical decisions.

## 6. Design Considerations

- Design for non-visual operation first: TalkBack labels, clear focus order, large touch targets, concise Vietnamese spoken prompts, and an unambiguous Stop reading control.
- Avoid continuous or overly frequent speech. Announcements must be interruptible and duplicate suppression must be configurable.
- Show the camera preview and textual result for low-vision users and testers, but do not require visual interpretation to complete a core flow.
- Communicate uncertainty plainly: for example, “Không nhận diện rõ. Hãy đưa camera gần hơn hoặc tăng ánh sáng.”
- Do not use color alone to convey state. Respect Android text scaling and system accessibility settings.

## 7. Technical Considerations

- Target stack: Flutter with Dart 3 and Riverpod 2 for state management.
- Use a platform camera integration, TensorFlow Lite/LiteRT for object detection, Google ML Kit Text Recognition for OCR, Speech-to-Text for commands, and Text-to-Speech for feedback.
- Run inference asynchronously and throttle camera-frame processing so the UI remains responsive and spoken output stays intelligible.
- The supported object-label list, confidence threshold, position-zone boundaries, and duplicate-suppression interval must be represented as configurable application settings, not scattered magic values.
- Store preferences locally using SharedPreferences; use SQLite/Drift only if a defined local history or structured data feature requires it.
- Verify Android runtime permissions, behavior in airplane mode, and availability of Vietnamese offline TTS/STT resources on the selected test device.
- The product must not log, persist, or transmit raw camera frames in MVP diagnostics.
- Bundle detection and OCR models, use an installed offline Vietnamese TTS voice, and validate speech-recognition availability per device. Section 9.6 records the selected directions, rationale, and evidence still required.

## 8. Success Metrics

- On a target Android device in airplane mode with resources preinstalled, object detection and OCR complete without a network request in 100% of the defined acceptance test runs.
- In controlled representative test scenes, the app gives a correct left/center/right zone for qualifying detections in at least 90% of recorded trials.
- At least 80% of target-user or accessibility-proxy testers can complete each core flow—find a supported object, read a short text, and stop speech—without assistance after onboarding.
- The app announces no duplicate match more than once during the configured suppression interval in automated and manual test scenarios.
- No P0/P1 accessibility defect remains open at MVP release review.

Section 9.6 adds provisional detection/OCR quality and performance targets.
Confirm their feasibility in a pilot before adopting them as final acceptance
thresholds; no benchmark results have been recorded yet.
The existing section 8 targets are specified requirements awaiting validation,
not measured achievements. Use the [evaluation protocol](../docs/evaluation-protocol.md)
for scoring, scenes, devices, user testing, and evidence status.

## 9. Decisions, Assumptions, and Validation Plan

### 9.1. Supported Device Matrix

The proposed MVP target is Android API 29 or later (Android 10+), on ARM64 devices with at least 4 GB RAM and an autofocus-capable camera. The device must also have sufficient free storage for the application and its required AI models and language resources.

Representative testing should include Samsung, Xiaomi, OPPO, and other common Android devices. This is a target configuration, not a compatibility guarantee. The team must validate it on representative physical devices before making a support commitment.

### 9.2. Object Classes and Vietnamese Phrase Mapping

The MVP acceptance model must cover the following initial classes. A pretrained integration baseline may support a different or larger label set, but the app must report only supported MVP classes and must not be presented as meeting full MVP acceptance until this coverage is validated.

| Group | Object classes |
| --- | --- |
| Personal items | Phone, Wallet, Keys, Backpack |
| Drinks | Bottle, Cup |
| Food | Apple, Banana, Bread |
| Household items | Chair, Table, Book, Remote |
| Electronics | Laptop, Keyboard, Mouse |
| Other items | Clock, Scissors, Umbrella |

Initial Vietnamese target phrases map to application object keys as follows:

| Vietnamese command | Application object key |
| --- | --- |
| Tìm chai nước | Bottle |
| Tìm điện thoại | Phone |
| Tìm quyển sách | Book |
| Tìm chìa khóa | Keys |
| Tìm cái ghế | Chair |

The object-detection model recognizes only classes it was trained to recognize. A separate command parser maps supported Vietnamese phrases and synonyms to application object keys, which are mapped to actual model class IDs using the selected artifact's metadata/label file. The keys above are not numeric model IDs. This parser must not be represented as unrestricted Vietnamese language understanding.

### 9.3. Confidence Threshold and Duplicate Suppression

The following values are initial test configuration, not proven optimal values:

| Parameter | Initial value |
| --- | --- |
| Confidence threshold | 0.50 |
| Duplicate-suppression interval | 2 seconds |
| Stable-detection requirement | 3 consecutive frames |
| Spatial zones | Left, Center, Right |

For a bottle detected across ten consecutive frames, the app must not speak ten announcements. Before speaking, it must validate confidence, confirm stability across the required frames, compare the result with the last announcement, and speak only when the object is new or its relative position changes significantly. The team must benchmark these parameters and adjust them using recorded representative scenes and usability feedback.

### 9.4. Local Recognition History

Recognition history is out of scope for MVP. The MVP stores only local preferences such as volume, Text-to-Speech rate, language, and audio-feedback preference.

A future version may use SQLite/Drift for optional local history. If added, it must let the user delete individual records or all records, disable history, and understand the retention period. Raw camera images must not be saved by default.

### 9.5. User Testing and Validation

The team must conduct validation in three stages:

1. **Functional testing:** verify supported object classes, OCR output, voice-command recognition, Text-to-Speech, and offline operation.
2. **Usability testing:** where access is feasible and appropriate, invite blind or low-vision participants to find a bottle on a table, find a phone in the camera view, read a product label, and control the app with voice.
3. **Evaluation:** record task-completion rate, completion time, false recognitions, duplicate announcements, ease-of-use feedback, and satisfaction.

Participation must be voluntary and based on clear consent. The team must explain the testing purpose, protect personal data, and exclude tasks that require unsafe movement or navigation.

### 9.6. Open Decisions and Validation Gaps

The following implementation directions were selected on 2026-11-08. This is
the central decision and validation register; other documents should link here.
Selection does not imply implementation, measured quality, or compatibility.
All items remain pending validation until supporting evidence is recorded or
linked here. Follow the [evaluation protocol](../docs/evaluation-protocol.md)
for frozen scene manifests, detection/OCR scoring, device/latency measurements,
user studies, and acceptance records. Its proposed sample counts and task limits
also require pilot confirmation. Package candidates require compatibility and maintenance checks
before a version is pinned. Synchronize affected requirements and PDR summaries
when a validated decision changes scope or acceptance criteria.

| Item | Selected direction | Rationale | Evidence still required |
| --- | --- | --- | --- |
| Object-detection model and class mapping | EfficientDet-Lite0 in TensorFlow Lite format, CPU baseline; fine-tune or replace if needed to cover section 9.2 | Establish the camera-to-speech pipeline on mobile hardware while retaining the required object vocabulary | Exact artifact/version, source, license, checksum, label/ID mapping, full class coverage, and device benchmarks |
| Dataset and evaluation scenes | Combine appropriately licensed data with labeled images collected in representative indoor environments | Evaluate everyday objects and conditions relevant to Vietnamese users | Source/license or consent records, annotations, split manifest, and locked evaluation scenes |
| Vietnamese OCR | ML Kit Text Recognition v2, Latin script, bundled model; `google_mlkit_text_recognition` as Flutter integration candidate; one image per request | Keep OCR available locally and avoid repeated speech from continuous processing | Pinned package/native configuration, Vietnamese ground-truth results, and offline runs |
| Vietnamese voice resources | Installed offline `vi-VN` TTS voice; user-initiated short STT commands, with `speech_to_text` as integration candidate; no automatic cloud fallback | Reduce network dependence and unnecessary microphone use while preserving accessible touch controls | Per-device voice/resource availability, command accuracy, TTS/TalkBack coexistence, and stop behavior |
| Benchmark devices | Three physical device profiles defined below, prioritizing available phones | Cover minimum hardware and manufacturer differences without requiring new purchases | Named devices, Android/RAM/engine versions, resource setup, and benchmark reports |
| Quality and performance acceptance | Provisional targets and measurement rules below; retain section 9.3 values for the pilot | Measure recognition quality separately from position accuracy and end-to-end responsiveness | Pilot feasibility, fixed protocol and thresholds, per-class results, and latency/resource measurements |
| User/accessibility evaluation | Pilot with 5–8 target users, fix issues, then run a confirmation round | Find usability failures early and assess each core task | Participant counts, protocol, consent, per-task outcomes, and open-defect report |
| Telemetry and network scope | Disable Firebase Analytics, PostHog, Crashlytics, Remote Config, and Messaging in MVP; minimal local technical logs only | Reduce unnecessary network services and simplify privacy/offline verification | Configuration audit and airplane-mode/network-traffic checks; no images, OCR content, or speech in logs |

#### Model coverage and dataset protocol

EfficientDet-Lite0 pretrained on COCO is an integration baseline, not the final
acceptance model. COCO labels do not include Wallet, Keys, or Bread; these
require additional training data and model work. Map Phone to the actual
`cell phone` label where applicable, and verify all other mappings, including
Table, against the chosen model's semantics. Do not silently drop a required
class or relabel an unrelated detection to claim coverage.

Start the data pilot with approximately 200–300 labeled images per class that
needs additional training, then expand according to observed errors. This is
an initial collection budget, not evidence of sufficient training data. Include
different physical examples, angles, lighting, clutter, and occlusion.
Split training, validation, and test data by physical object, room, or capture
session; do not scatter adjacent frames from the same video across splits.
Lock the test set before tuning confidence and duplicate suppression.

#### Physical-device matrix

| Profile | Target coverage |
| --- | --- |
| Minimum-level phone | ARM64, 4 GB RAM, Android 10/11 where available |
| Primary development phone | Android 12 or later, representative mainstream hardware |
| Manufacturer-variation phone | A different manufacturer; prioritize Samsung, Xiaomi, or OPPO across the matrix |

Record exact phone model, Android version, RAM, STT/TTS engine, installed
language resources, and model/package versions. If a profile is unavailable,
record the coverage gap rather than claiming validation. Use physical phones
for camera/AI performance; emulator results supplement functional checks.

On-device STT support and Vietnamese availability must be checked independently
of TTS availability. Test Android 10/11 and Android 12+ separately where
available. Select an installed `vi-VN` TTS voice that reports no network
requirement. Provide accessible resource-setup guidance when unavailable;
touch/TalkBack controls remain usable when STT is unavailable. Verify voice
stop while TTS is speaking and TalkBack is active, and keep the touch stop
control reachable with priority handling.

#### Provisional quality and performance targets

These are pilot targets, not benchmark results or finalized release gates.
Retain section 8's existing acceptance targets. Document and agree any changes
to these provisional thresholds after the pilot and before final evaluation.

| Measure | Initial target | Measurement rule |
| --- | --- | --- |
| Detection | Precision ≥90%, recall ≥80% at IoU ≥0.5 | Match predictions to labeled boxes on the locked test set; report each class and aggregate results at the configured confidence threshold |
| Relative position | ≥90% correct left/center/right | Evaluate qualifying detections separately; also report full object-search task success |
| Vietnamese OCR | Character error rate (CER) ≤10% on clear printed text | Compare with human-transcribed ground truth; normalize Unicode/whitespace consistently while preserving Vietnamese diacritics; report labels and paragraphs separately |
| Stable detection feedback | P95 ≤2 seconds | From the first evaluable frame containing the target to the start of correct spoken feedback, including frame processing, stability checks, and audio scheduling |
| Short-text OCR | P95 ≤3 seconds | From the Read text action to the displayed OCR result; define text length and capture conditions before benchmarking |
| Touch stop | P95 ≤300 ms | From touch activation to cessation of TTS playback |
| Continuous session | 15 minutes without crash | Record peak RAM, temperature, and throughput degradation on each test phone; use results to set resource budgets |

P95 is the latency below which 95% of measured trials fall. Record sample
counts, cold/warm start conditions, and device configuration. Evaluate difficult
OCR conditions separately from the clear-print target. A confidence threshold
of 0.50 is not a claim of 50% accuracy. Tune the initial three-frame stability
and two-second suppression values on validation data, then freeze the
configuration for final evaluation.

#### User evaluation and network verification

Use a 5–8-person pilot with target users to find issues, then fix defects before
the confirmation round. Record the confirmation sample size before evaluation.
For each task in section 9.5, report absolute completions and percentages,
completion time, assistance required, and errors. Report accessibility-proxy
results separately from blind/low-vision participant results. An 80% completion
rate from five participants means four completions and must not be presented
as broad population-level evidence.

Bundle detection and OCR models with the app; disclose any one-time setup of
Vietnamese speech resources before offline use. Validate recognition in airplane
mode and inspect network traffic with connectivity enabled. Verify that the
disabled SDKs and recognition flows do not initiate unexpected network requests
or transmit camera, OCR, or speech content. Any later service activation needs
a recorded purpose and permitted data scope.

#### Technical references

- [Google AI Edge: Object Detector and EfficientDet-Lite0](https://developers.google.com/edge/mediapipe/solutions/vision/object_detector)
- [TensorFlow COCO label map](https://github.com/tensorflow/models/blob/master/research/object_detection/data/mscoco_label_map.pbtxt)
- [ML Kit supported languages](https://developers.google.com/ml-kit/vision/text-recognition/v2/languages)
- [ML Kit Android text recognition: bundled and unbundled models](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)
- [Flutter ML Kit text recognition integration](https://pub.dev/packages/google_mlkit_text_recognition)
- [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer)
- [Android TTS Voice network requirement](https://developer.android.com/reference/android/speech/tts/Voice)
- [Flutter speech_to_text integration](https://pub.dev/packages/speech_to_text)
