# PRD: SeeMate AI

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
- [ ] “Đọc văn bản” starts OCR from the camera using the configured on-device Google ML Kit text-recognition package.
- [ ] The app displays the extracted text in a readable, selectable result area and passes it to Android Text-to-Speech in Vietnamese.
- [ ] “Dừng đọc” immediately stops active Text-to-Speech playback.
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
- [ ] Speech-to-Text offline support is detected or documented as device-dependent; touch controls remain usable if it is unavailable.
- [ ] No image frame is uploaded by an MVP recognition flow.
- [ ] Offline verification steps are documented and executed on at least one target Android device or emulator.

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

## 8. Success Metrics

- On a target Android device in airplane mode with resources preinstalled, object detection and OCR complete without a network request in 100% of the defined acceptance test runs.
- In controlled representative test scenes, the app gives a correct left/center/right zone for qualifying detections in at least 90% of recorded trials.
- At least 80% of target-user or accessibility-proxy testers can complete each core flow—find a supported object, read a short text, and stop speech—without assistance after onboarding.
- The app announces no duplicate match more than once during the configured suppression interval in automated and manual test scenarios.
- No P0/P1 accessibility defect remains open at MVP release review.

## 9. Decisions, Assumptions, and Validation Plan

### 9.1. Supported Device Matrix

The proposed MVP target is Android API 29 or later (Android 10+), on ARM64 devices with at least 4 GB RAM and an autofocus-capable camera. The device must also have sufficient free storage for the application and its required AI models and language resources.

Representative testing should include Samsung, Xiaomi, OPPO, and other common Android devices. This is a target configuration, not a compatibility guarantee. The team must validate it on representative physical devices before making a support commitment.

### 9.2. Object Classes and Vietnamese Phrase Mapping

The first object-detection model must support only the following initial classes. The app must not claim to find an object outside this supported list.

| Group | Object classes |
| --- | --- |
| Personal items | Phone, Wallet, Keys, Backpack |
| Drinks | Bottle, Cup |
| Food | Apple, Banana, Bread |
| Household items | Chair, Table, Book, Remote |
| Electronics | Laptop, Keyboard, Mouse |
| Other items | Clock, Scissors, Umbrella |

Initial Vietnamese target phrases map to model labels as follows:

| Vietnamese command | Model class ID |
| --- | --- |
| Tìm chai nước | Bottle |
| Tìm điện thoại | Phone |
| Tìm quyển sách | Book |
| Tìm chìa khóa | Keys |
| Tìm cái ghế | Chair |

The object-detection model recognizes only classes it was trained to recognize. A separate command parser maps supported Vietnamese phrases and synonyms to those class IDs; it must not be represented as unrestricted Vietnamese language understanding.

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
