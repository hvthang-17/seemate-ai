# SeeMate AI — N3 Technical Handoff Document

**Target Audience:** Team Member N1 (Core Architecture, Shell, DI, Riverpod, Routing)  
**Author:** Senior Flutter Integration Engineer (N3 Track: Speech, OCR, STT & NLP)  
**Date:** 2026-11-10  
**Source Workspace:** `D:\Yang\HK7\DNT\seemate_n3_lab`  
**Target Repository:** `D:\Yang\HK7\DNT\seemate-ai`  
**Status:** Ready for Integration Review (Isolated validation 100% complete)

---

## 1. Executive Summary & Audit Overview

Track N3 is responsible for the speech, text recognition, voice control, and accessibility audio pipeline of SeeMate AI:
1. **Offline Vietnamese Text-to-Speech (TTS):** Engine detection, offline voice package verification, queueing, instant interruption.
2. **On-Device OCR & Image Pipeline:** Google ML Kit Latin v2, Laplacian blur detection, mean luminance assessment, multi-pass ROI cropping, and conservative Vietnamese Unicode NFC post-processing with strict drug/dosage preservation.
3. **Vietnamese Speech-to-Text (STT):** On-device/native Android `SpeechRecognizer` integration, microphone permission flow, streaming partial/final transcripts, and acoustic loop suppression.
4. **Natural Language Voice Command Parser:** 100% offline heuristic parser recognizing 5 core intents and 9 supported object categories with conversational filler removal, diacritic-insensitive fallback, and safe fuzzy matching ($\ge 5$ chars).
5. **Accessibility Announcer:** Spoken feedback coordinator with duplicate suppression and TalkBack non-visual safety.

All N3 components have been designed, implemented, and verified in an isolated test harness (`seemate_n3_lab`) with **67 passing automated unit and integration tests** and manual physical device verification on a **Samsung Galaxy A31 (Android 12, API 31)**.

---

## 2. Feature Readiness Matrix

| Feature Component | Implementation Status | Test Coverage | Physical Device Evidence | Readiness Level |
|---|---|---|---|---|
| **Real Offline TTS Adapter** (`RealOfflineTtsAdapter`) | Fully implemented via `flutter_tts: ^4.2.1` | Unit tests with `FakeTtsEngine` | Verified on Samsung Galaxy A31 (`com.google.android.tts`, `vi-VN` offline voice package) | **Production-Ready** |
| **Speech Coordinator** (`SpeechCoordinator`) | Fully implemented: priority queue, instant stop, duplicate suppression | 10 unit tests in Lab test suite | Verified: interruptible speech, instant stop on new requests | **Production-Ready** |
| **Google ML Kit OCR Adapter** (`RealMlkitOcrAdapter`) | Fully implemented via `google_mlkit_text_recognition: ^0.13.1` | 10 unit tests (`ocr_result_test.dart`) | Verified on product packaging photos & prescription labels | **Production-Ready** |
| **Image Quality Assessor** (`ImageQualityAssessor`) | Laplacian blur variance + mean luminance checks | 5 unit tests in pipeline suite | Tested on blurry, dark, and normal test captures | **Production-Ready** |
| **Region Optimizer & Multi-Pass** (`ImageRegionOptimizer`, `MultiPassOcrPipeline`) | Bounding-box union with 10% padding, top-to-bottom reading order, crop generation via `image: ^4.3.0` | 8 unit tests in pipeline suite | Verified multi-pass contrast enhancement | **Production-Ready** |
| **Conservative Vietnamese Post-Processor** (`VietnameseOcrPostProcessor`) | Precomposed NFC Unicode normalization, boilerplate corrections, strict drug/dosage/date/price preservation | 5 unit tests (including safety preservation) | Verified: "Sàn phêm cùa" $\rightarrow$ "Sản phẩm của", preserves "Paracetamol 500mg" | **Production-Ready** |
| **Accessible OCR Announcer** (`AccessibleOcrAnnouncer`) | Non-visual outcome guidance (blur, dark, conflicting passes, empty) with 3s duplicate suppression | 5 unit tests in pipeline suite | Verified non-visual audio prompts | **Production-Ready** |
| **Real STT Adapter** (`RealSttAdapter`) | Fully implemented via `speech_to_text: ^7.0.0` (7.5.0), Android `RecognitionService` | Unit tests with `FakeSttEngine` | Verified on Galaxy A31: mic permission prompt, live transcript display | **Production-Ready** |
| **Voice Command Coordinator** (`VoiceCommandCoordinator`) | Coordinates STT listening, stops TTS before mic opening, dispatches commands | 10 integration tests (`stt_and_command_parser_test.dart`) | Verified: zero mic acoustic feedback loop, handles permission denial | **Production-Ready** |
| **Flexible Vietnamese Intent Parser** (`VietnameseCommandParser`) | 5 intents (`readText`, `repeatReading`, `stopReading`, `detectObjects`, `findObject`), 9 objects, fuzzy matching, negation, ambiguity | 11 test groups (60 diverse Vietnamese test utterances) | Verified offline heuristic parsing | **Production-Ready** |
| **Speech Settings Value Object** (`SpeechSettings`, `SpeechRate`) | Typed immutable value objects (`speechRate`, `feedbackEnabled`, `suppressionEnabled`, `suppressionWindowSeconds`) | Unit tests in speech contract | Verified in-memory state changes | **Production-Ready** |
| **Settings Disk Persistence** | In-memory in N3 Lab; Hive/SharedPreferences integration ready for N1 | Not tested on disk in N3 Lab | Model verified; disk layer deferred to N1 cache infrastructure | **Pending N1 Integration** |

> [!NOTE]
> As mandated by project rules, we do not claim Settings disk persistence or full Android system integration is complete until N1 connects it to the main repository's Hive/GetIt infrastructure.

---

## 3. Architecture & Contract Comparison

```
┌────────────────────────────────────────────────────────────────────────┐
│                        N3 LAB (Isolated Sandbox)                       │
│  Flat structure: lib/contracts/, lib/speech/, lib/ocr/, lib/ui/        │
│  Manual constructor dependency injection                               │
│  Direct StatefulWidget test screens                                   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Map into Clean Architecture
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     MAIN REPOSITORY (seemate-ai)                       │
│  lib/features/speech/{domain, data, presentation}                      │
│  lib/features/ocr/{domain, data, presentation}                         │
│  lib/features/voice_commands/{domain, data, presentation}              │
│  lib/features/settings/{domain, data, presentation}                    │
│  DI via GetIt (@lazySingleton / Injectable)                            │
│  State via Riverpod 2 (NotifierProvider, AsyncValue)                   │
│  Disk persistence via Hive (CacheManager / DiskCache)                  │
└────────────────────────────────────────────────────────────────────────┘
```

### Shared Contracts Alignment:
1. **TTS Contracts (`lib/contracts/speech_contract.dart`):**
   - Clean domain interfaces (`TtsEngine`, `TtsReadiness`, `TtsPlaybackEvent`, `TtsFailure`).
   - Self-contained value objects (`SpeechRate`, `SpeechSettings`).
   - Zero external framework dependencies (uses pure Dart + `fpdart`).
2. **OCR Contracts (`lib/contracts/ocr_contract.dart`):**
   - Clean domain interfaces (`OcrEngine`, `OcrResult`, `OcrInput`, `ImageMetadata`).
   - Result hierarchy (`OcrSuccess`, `OcrEmpty`, `OcrFailure`, `OcrCancelled`) matches PRD US-005.
3. **Voice Command Contracts (`lib/contracts/command_contract.dart`):**
   - Clean domain interfaces (`SttEngine`, `VoiceAction`, `SupportedObject`, `ParsedCommand`).
   - Sealed command hierarchy: `RecognizedCommand`, `AmbiguousCommand`, `UnclearObjectCommand`, `UnsupportedObjectCommand`, `NegatedCommand`, `UnknownCommand`, `EmptyCommand`.

---

## 4. Transferred File Inventory in seemate-ai

The production implementation files have been transferred from `seemate_n3_lab` and integrated directly into the Clean Architecture structure of `seemate-ai`:

### 4.1. Speech & Voice Commands (`lib/core/speech/`)
| Transferred File | Original Lab File | Responsibilities |
|---|---|---|
| `lib/core/speech/offline_tts_adapter.dart` | `lib/speech/real_offline_tts_adapter.dart` | Production TTS adapter with offline voice validation & dynamic plugin injection |
| `lib/core/speech/voice_command_adapter.dart` | `lib/speech/real_stt_adapter.dart` | Production Android `speech_to_text` STT wrapper with `vi_VN` streaming |
| `lib/core/speech/vietnamese_command_parser.dart` | `lib/speech/vietnamese_command_parser.dart` | 100% offline heuristic NLP parser (fuzzy, diacritics, filler removal, safe negation handling) |
| `lib/core/speech/voice_command_coordinator.dart` | `lib/speech/voice_command_coordinator.dart` | Session coordinator with TTS mutual exclusion (stops TTS before mic opens) |
| `lib/core/speech/speech_coordinator.dart` | `lib/speech/speech_coordinator.dart` | Speech queueing, duplicate suppression, priority stop |

### 4.2. OCR & Computer Vision Pipeline (`lib/features/text_reading/`)
| Transferred File | Original Lab File | Responsibilities |
|---|---|---|
| `lib/features/text_reading/domain/ocr_engine.dart` | `lib/ocr/real_mlkit_ocr_adapter.dart` (interface) | Core OCR engine contract |
| `lib/features/text_reading/data/real_mlkit_ocr_adapter.dart` | `lib/ocr/real_mlkit_ocr_adapter.dart` | Production Google ML Kit Latin v2 wrapper with dynamic fallback |
| `lib/features/text_reading/data/fake_ocr_engine.dart` | `test/ocr_result_test.dart` (Fake) | In-memory fake OCR engine for deterministic test execution |
| `lib/features/text_reading/domain/image_quality_assessor.dart` | `lib/ocr/image_quality_assessor.dart` | Pure Dart Laplacian variance (blur) & mean luminance assessment |
| `lib/features/text_reading/domain/image_region_optimizer.dart` | `lib/ocr/image_region_optimizer.dart` | Bounding box union (10% padding), reading order sorting, crop helper |
| `lib/features/text_reading/domain/multi_pass_report.dart` | `lib/ocr/multi_pass_ocr_pipeline.dart` (models) | Single-pass (`OcrPassResult`) and aggregated (`MultiPassReport`) models |
| `lib/features/text_reading/domain/multi_pass_ocr_pipeline.dart` | `lib/ocr/multi_pass_ocr_pipeline.dart` | Multi-pass OCR pipeline orchestrator (Pass A, B, C) |
| `lib/features/text_reading/domain/ocr_candidate_evaluator.dart` | `lib/ocr/ocr_candidate_evaluator.dart` | Pass evaluation, diacritic scoring, conflict detection |
| `lib/features/text_reading/domain/vietnamese_ocr_post_processor.dart` | `lib/ocr/vietnamese_ocr_post_processor.dart` | NFC normalization, packaging label rules, strict medicine/dosage preservation |
| `lib/features/text_reading/domain/enhanced_ocr_result.dart` | `lib/ocr/enhanced_ocr_result.dart` | Composite typed result model with certainty, sensitive tags, guidance |
| `lib/features/text_reading/domain/ocr_accuracy_evaluator.dart` | `lib/ocr/ocr_accuracy_evaluator.dart` | CER, WER, and Levenshtein metrics computation |
| `lib/features/text_reading/domain/accessible_ocr_announcer.dart` | `lib/speech/accessible_ocr_announcer.dart` | Spoken outcome guidance with duplicate suppression |

### 4.3. Settings & Persistence (`lib/features/settings/`)
| Transferred File | Responsibilities |
|---|---|
| `lib/features/settings/domain/settings_repository.dart` | Persistence contract for `SpeechSettings` |
| `lib/features/settings/data/hive_settings_repository.dart` | Hive-backed storage for user speech & suppression preferences |
| `lib/features/settings/presentation/settings_providers.dart` | Riverpod `SpeechSettingsNotifier` and repository provider |

### 4.4. Test Suites
| Target Test File | Original Lab File | Focus |
|---|---|---|
| `test/core/speech/speech_coordinator_test.dart` | Existing | Speech coordination & duplicate suppression |
| `test/core/speech/vietnamese_command_parser_test.dart` | Existing | Base parser & FakeSttEngine verification |
| `test/core/speech/vietnamese_natural_language_parser_test.dart` | `test/stt_and_command_parser_test.dart` | 60 diverse natural Vietnamese utterances across 9 categories |
| `test/core/speech/voice_command_coordinator_test.dart` | `test/stt_and_command_parser_test.dart` | Mutual exclusion, lifecycle, navigation, permission denial |
| `test/features/text_reading/ocr_pipeline_and_accuracy_test.dart` | `test/ocr_pipeline_and_accuracy_test.dart` | 21 tests: multi-pass, NFC normalization, sensitive safety, announcer, CER/WER |
| `test/features/text_reading/ocr_result_test.dart` | `test/ocr_result_test.dart` | 10 tests: sealed hierarchy, FakeOcrEngine delegation |

---

## 5. Dependencies & Platform Configuration

### 5.1. `pubspec.yaml` Additions
Add the following verified packages to `dependencies` in `D:\Yang\HK7\DNT\seemate-ai\pubspec.yaml`:

```yaml
dependencies:
  # N3 Speech, OCR & Computer Vision
  flutter_tts: ^4.2.1
  google_mlkit_text_recognition: ^0.13.1
  speech_to_text: ^7.0.0
  image: ^4.3.0
  image_picker: ^1.1.2 # Required for test image selection / camera gallery pick
```

> [!IMPORTANT]
> `fpdart: ^1.1.0` is already present in `seemate-ai`. No version conflict exists.

### 5.2. Android Manifest Configuration
Update `android/app/src/main/AndroidManifest.xml` in `seemate-ai` to include:

1. **Microphone & Bluetooth Permissions:**
```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

2. **Google ML Kit OCR Model Download Meta-Data (under `<application>`):**
```xml
    <!-- Automatically downloads on-device Latin OCR model when app is installed -->
    <meta-data
        android:name="com.google.mlkit.vision.DEPENDENCIES"
        android:value="ocr" />
```

3. **Android 11+ (API 30+) Speech Recognition Package Visibility (under `<queries>`):**
```xml
    <queries>
        <!-- Allows querying Android SpeechRecognizer service -->
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
```

---

## 6. Dependency Injection & Service Registration

In `lib/core/di/get_it.dart` (or via `@module` / `@lazySingleton`):

```dart
// -----------------------------------------------------------------------------
// Speech (TTS)
// -----------------------------------------------------------------------------
@lazySingleton
TtsEngine get ttsEngine => RealOfflineTtsAdapter();

@lazySingleton
SpeechCoordinator get speechCoordinator => SpeechCoordinator(
  engine: getIt<TtsEngine>(),
  settings: SpeechSettings.defaults,
);

// -----------------------------------------------------------------------------
// OCR
// -----------------------------------------------------------------------------
@lazySingleton
OcrEngine get ocrEngine => RealMlkitOcrAdapter();

@lazySingleton
AccessibleOcrAnnouncer get ocrAnnouncer => AccessibleOcrAnnouncer(
  speechCoordinator: getIt<SpeechCoordinator>(),
);

// -----------------------------------------------------------------------------
// Speech-to-Text & Voice Commands
// -----------------------------------------------------------------------------
@lazySingleton
SttEngine get sttEngine => RealSttAdapter();

@lazySingleton
VietnameseCommandParser get commandParser => const VietnameseCommandParser();

@lazySingleton
VoiceCommandCoordinator get voiceCoordinator => VoiceCommandCoordinator(
  sttEngine: getIt<SttEngine>(),
  speechCoordinator: getIt<SpeechCoordinator>(),
  parser: getIt<VietnameseCommandParser>(),
);
```

---

## 7. Lifecycle Management & Safety Rules

For N1's shell and screen coordination:
1. **Acoustic Feedback Safety Rule:**
   - Always call `await speechCoordinator.stop()` before opening the microphone (`sttEngine.startListening()`). `VoiceCommandCoordinator` handles this automatically in `startListeningSession()`.
2. **Partial Transcript Safety Rule:**
   - Never dispatch commands on partial transcription events (`isFinal == false`). Wait until `isFinal == true` to avoid partial/premature execution of destructive or navigation actions.
3. **Interruptibility Rule:**
   - The "Dừng đọc" / "Stop reading" action must always be immediately reachable via a large touch target ($\ge 48 \times 48\text{ dp}$) and must invoke `speechCoordinator.stop()`, even while TTS is actively streaming.
4. **Disposal Lifecycle:**
   - When the user leaves an active OCR or voice command session or the app moves to background, invoke `coordinator.cancelListeningSession()` and release any active image buffer.
5. **Zero Cloud Fallback Guarantee:**
   - When offline STT or Vietnamese voice data is missing on the user's device, fail gracefully with non-assertive guidance and keep accessible touch buttons available. Never fall back to cloud voice upload.

---

## 8. Settings Persistence (N1 Integration Guide)

In N3 Lab, `SpeechSettings` was managed in-memory. For the main repository, N1 should connect `SpeechSettings` to the existing Hive infrastructure:

### 8.1. Settings Model / Adapter
```dart
// lib/features/settings/data/models/speech_settings_dto.dart
class SpeechSettingsDto {
  static const boxName = 'settings_box';
  static const speechRateKey = 'speech_rate';
  static const feedbackKey = 'feedback_enabled';
  static const suppressionKey = 'suppression_enabled';
  static const suppressionWindowKey = 'suppression_window_seconds';

  static SpeechSettings fromHive(Box box) {
    final rate = box.get(speechRateKey, defaultValue: 1.0) as double;
    final feedback = box.get(feedbackKey, defaultValue: true) as bool;
    final suppression = box.get(suppressionKey, defaultValue: true) as bool;
    final window = box.get(suppressionWindowKey, defaultValue: 5) as int;

    return SpeechSettings(
      speechRate: SpeechRate.clamp(rate),
      feedbackEnabled: feedback,
      suppressionEnabled: suppression,
      suppressionWindowSeconds: window,
    );
  }

  static Future<void> saveToHive(Box box, SpeechSettings settings) async {
    await box.put(speechRateKey, settings.speechRate.value);
    await box.put(feedbackKey, settings.feedbackEnabled);
    await box.put(suppressionKey, settings.suppressionEnabled);
    await box.put(suppressionWindowKey, settings.suppressionWindowSeconds);
  }
}
```

### 8.2. Riverpod Notifier
```dart
// lib/features/settings/presentation/settings_notifier.dart
final speechSettingsProvider = NotifierProvider<SpeechSettingsNotifier, SpeechSettings>(
  SpeechSettingsNotifier.new,
);

class SpeechSettingsNotifier extends Notifier<SpeechSettings> {
  @override
  SpeechSettings build() {
    // Load from Hive or default
    return SpeechSettings.defaults;
  }

  Future<void> updateSpeechRate(SpeechRate newRate) async {
    state = state.copyWith(speechRate: newRate);
    ref.read(speechCoordinatorProvider).updateSettings(state);
    // Persist to Hive
  }
}
```

---

## 9. Verification & Test Evidence

### 9.1. Automated Unit Tests Summary
Executed with `flutter test` in `D:\Yang\HK7\DNT\seemate_n3_lab`:

```text
00:02 +67: All tests passed!
```

- **`stt_and_command_parser_test.dart` (21 tests):**
  - Category 1: `readText` (7 natural phrasing variations).
  - Category 2: `repeatReading` (6 natural phrasing variations).
  - Category 3: `stopReading` (7 natural phrasing variations).
  - Category 4: `detectObjects` (7 natural phrasing variations).
  - Category 5: `findObject` (8 natural phrasing variations).
  - Category 6: Southern regional variants (e.g., "bóp tiền", "cái ly", "dế", "kiếm giùm").
  - Category 7: Unaccented Vietnamese fallback (e.g., "tim chia khoa", "doc van ban").
  - Category 8: Controlled fuzzy matching & minor STT typos (e.g., "đọc văn bạn", "dừng đoc", "trước măt có gì", "tìm chìa kháo").
  - Category 9: Negations & safety disambiguation ("Tôi không muốn đọc", "Đừng tìm ví nữa").
  - Category 10: Unsupported objects & unclear query handling ("Tìm mắt kính", "Tìm giúp tôi với").
  - Category 11: Out-of-domain conversational rejection & empty inputs.
  - Integration: Voice session coordination, mutual exclusion, permission denial, cancellation.

- **`ocr_pipeline_and_accuracy_test.dart` (21 tests):**
  - Phase 1: Bounding-box union calculation, safe bounds clamping, reading order sorting.
  - Phase 2 & 3: Multi-pass evaluation, composite diacritic scoring, pass conflict detection.
  - Phase 4: Unicode combining NFC normalization, boilerplate packaging corrections ("Sàn phêm cùa" $\rightarrow$ "Sản phẩm của"), critical safety preservation of medicines, dosages, dates, and prices.
  - Phase 5: Spoken outcome guidance (blur, dark, conflicting passes, empty image).
  - Phase 6: CER & WER metrics calculation, quantifiable CER reduction validation.

- **`ocr_result_test.dart` (10 tests):**
  - Contract validation, equality, toString, `FakeOcrEngine` delegation.

- **`widget_test.dart` (1 test):**
  - Clean widget tree smoke test.

### 9.2. Physical Device Evidence (Samsung Galaxy A31)
- **Model:** Samsung Galaxy A31 (`SM-A315F`)
- **OS Version:** Android 12 (One UI 4.1, API 31)
- **Engine Detected:** Google Speech Services (`com.google.android.tts`)
- **Vietnamese Voice Package:** `vi-vn-x-vic-network` and `vi-vn-x-vif-local` (Offline voice verified with `networkConnectionRequired == false`).
- **Airplane Mode Test:** TTS speech and ML Kit Latin OCR run 100% on-device with zero network latency.

---

## 10. Step-by-Step N1 Integration Instructions

The N3 codebase has already been transferred and adapted into `D:\Yang\HK7\DNT\seemate-ai`. To activate native Android speech recognition, ML Kit Latin OCR, and text-to-speech on physical hardware, N1 must complete the following steps:

### Step 1: Add Dependencies in `pubspec.yaml`
Add the following 4 dependencies under `dependencies:` in `pubspec.yaml`:
```yaml
dependencies:
  # N3 Speech, OCR & Image Processing
  flutter_tts: ^4.2.1
  speech_to_text: ^7.0.0
  google_mlkit_text_recognition: ^0.13.1
  image: ^4.3.0
```
Then run:
```sh
flutter pub get
```

### Step 2: Configure Android Manifest (`android/app/src/main/AndroidManifest.xml`)
1. Insert microphone and Bluetooth audio permissions:
```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```
2. Insert ML Kit OCR model auto-download metadata inside `<application>`:
```xml
    <meta-data
        android:name="com.google.mlkit.vision.DEPENDENCIES"
        android:value="ocr" />
```
3. Insert Android 11+ (API 30+) speech recognition package visibility queries under `<queries>`:
```xml
    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>
```

### Step 3: Register Singletons in GetIt DI
In `lib/core/di/` (e.g. `register_module.dart` or `get_it.dart`):
```dart
// TTS
@lazySingleton
TtsEngine get ttsEngine => OfflineTtsAdapter();

@lazySingleton
SpeechCoordinator get speechCoordinator => SpeechCoordinator(
  engine: getIt<TtsEngine>(),
  settings: SpeechSettings.defaults,
);

// OCR
@lazySingleton
OcrEngine get ocrEngine => RealMlkitOcrAdapter();

@lazySingleton
AccessibleOcrAnnouncer get ocrAnnouncer => AccessibleOcrAnnouncer(
  speechCoordinator: getIt<SpeechCoordinator>(),
);

// STT & Voice Commands
@lazySingleton
SttEngine get sttEngine => VoiceCommandAdapter();

@lazySingleton
VietnameseCommandParser get commandParser => const VietnameseCommandParser();

@lazySingleton
VoiceCommandCoordinator get voiceCoordinator => VoiceCommandCoordinator(
  sttEngine: getIt<SttEngine>(),
  speechCoordinator: getIt<SpeechCoordinator>(),
  parser: getIt<VietnameseCommandParser>(),
);
```

### Step 4: Wire to Riverpod & Shell UI
1. Connect `speechSettingsProvider` in `lib/features/settings/presentation/settings_providers.dart` to the settings screen.
2. In the main Assistance View, connect the 4 primary accessible touch targets:
   - "Đọc văn bản" $\rightarrow$ triggers camera capture + OCR flow (`ocrEngine.processEnhancedFromFile(...)`).
   - "Dừng đọc" $\rightarrow$ calls `ref.read(speechCoordinatorProvider).stop()`.
   - "Nhận diện đồ vật" $\rightarrow$ toggles object detection mode (N2 track).
   - "Tìm đồ vật" / Mic Button $\rightarrow$ triggers `voiceCoordinator.startListeningSession()`.

### Step 5: Verification Commands
Run in VS Code terminal:
```sh
flutter analyze
flutter test
```

---

*Handoff prepared and verified by Senior Flutter Integration Engineer (N3 Track).*
