# SeeMate AI evaluation protocol

## Status and authority

Status: protocol defined, execution pending. No detection/OCR benchmark or
target-user acceptance result is recorded by this document. The
[PRD](../tasks/prd-seemate-ai.md#8-success-metrics) owns acceptance requirements;
[section 9.6](../tasks/prd-seemate-ai.md#96-open-decisions-and-validation-gaps)
owns selected directions and provisional targets. This guide defines how to
measure them, not a second set of release thresholds.

The PRD's position accuracy, task completion, offline, duplicate-suppression,
and accessibility criteria are specified requirements awaiting evidence.
Detection precision/recall, OCR CER, latency, session duration, resource budgets,
and the initial confidence/stability settings still need pilot confirmation.
All sample sizes and task time limits proposed below also need confirmation
before the final test manifest is locked. Missing evidence is **not evaluated**,
not a pass. Record an unmet measured criterion as **fail**, not as missing data.

## Freeze the evaluation inputs

Before final evaluation, record a protocol version, source commit, APK checksum,
Flutter/Dart versions, dependency lockfile, model checksum/label mapping,
confidence/NMS/stability/suppression settings, zone boundaries, and dataset
manifest version. Record build mode and execution backend/thread settings.
Use the same release-mode APK for physical-device comparison; keep debug or
profile diagnostics separate from acceptance measurements.

Use validation data for tuning. Separate train/validation/test by physical
object and capture session/room; adjacent video frames are not independent
test examples. Freeze scene membership, sample counts, supported vocabulary,
failure/time-out rules, and the approved final thresholds before evaluating.
If a test result drives a model change, record that iteration and use a fresh
holdout for final confirmation. Do not discard hard cases after seeing results.

## Scene manifest and ground truth

Assign each scene an ID and record its split, task, object class/count, physical
object/session group, background, lighting, camera orientation, distance/setup,
occlusion, expected outcome, and annotation version. Use reproducible marked
positions and document illumination/setup rather than assuming all rooms match.

| Scene family | Required coverage | Pilot collection proposal |
| --- | --- | --- |
| Detection positives | Every PRD object class; several physical examples, angles, left/center/right locations, and near-zone-boundary positions | At least 50 independent annotated held-out images per class; separate from the proposed training-image budget |
| Detection challenges | Clutter, similar objects, multiple same-class instances, partial occlusion, dim light, blur, rotation, and small objects | Tag each condition; report its counts and results separately |
| Negative/search scenes | Empty frame, target absent with other supported objects, and unsupported requests | At least 50 independent negative scenes across these cases |
| OCR clear print | Vietnamese labels and paragraphs with diacritics, numbers, punctuation, and varied fonts | At least 50 images, with both labels and paragraphs represented |
| OCR challenges | Small text, glare, curved packaging, perspective/rotation, blur, low light, and no text | At least 50 additional images, reported separately from clear print |
| Lifecycle/accessibility | Denied/permanently denied/revoked permissions, missing model/voice, background/resume, mode changes, text scaling, TalkBack | Script each case with expected resource and spoken/UI outcome |

Have a second annotator check held-out boxes, class labels, and Vietnamese
transcriptions; resolve disagreement before testing. Set explicit inclusion
rules for partly visible objects and ambiguous text. Do not invent unreadable
ground truth; document those cases separately as quality-guidance tests.

Training/evaluation media must be appropriately licensed or collected with
consent and held outside app diagnostics with documented access/retention.
Use synthetic/non-personal labels and documents. Do not enable production frame
capture, image history, OCR logging, or audio recording to build this dataset.
Offline fixture evaluation, when implemented, must remain separate from the
MVP camera flow and must not persist its input through app cache/logging.

## Detection and relative-position scoring

Score the final postprocessed detections at the frozen confidence threshold,
before temporal speech suppression. Evaluate the deployed model artifact, not
only its training-framework export. Apply coordinate rotation/crop transforms
consistently so predictions and ground truth refer to the same image plane.

For each image and class, sort predictions by descending confidence, using
stable output order for ties. Match each prediction to the highest-IoU unmatched
ground-truth box of that class when it meets the PRD IoU threshold. IoU is
intersection area divided by union area. A match is one true positive (TP);
an unmatched prediction is a false positive (FP); an unmatched ground-truth box
is a false negative (FN). Extra detections of the same object count as FP.
A wrong-class prediction produces an FP for its class and leaves the real
class unmatched. Define equal-IoU tie-breaking by annotation ID in the manifest.

- Precision = TP / (TP + FP); recall = TP / (TP + FN).
- Report TP/FP/FN, support, precision, and recall for every required class,
  plus micro totals and macro means. Report absent denominators as N/A and
  missing class coverage explicitly; do not average a required missing class
  away. Confirm before final testing whether the provisional quality targets
  apply per class or to a specified aggregate; that acceptance-aggregation
  decision remains pending. These fixed-threshold metrics are not COCO mAP.
- Report negatives separately: false detections and false successful-search
  announcements divided by negative scene/task counts.
- For each correctly matched qualifying detection, compare its computed
  pre-suppression zone with
  the zone of the ground-truth box center. Record numerator/denominator; do not
  calculate accuracy by comparing the algorithm with its own predicted center.
  Use the frozen zone boundaries; for an initial equal-thirds configuration,
  use normalized x in [0, 1/3), [1/3, 2/3), and [2/3, 1]. Test exact boundaries
  and display rotation/cropping explicitly.
- Evaluate live target search separately: a success requires the requested class
  and correct zone within the predeclared task limit. Count wrong announcements,
  misses, time-outs, and unsupported-target handling, not only successful frames.
  Report position accuracy separately from whole-task completion.

For temporal tests, replay a scripted stable target, jitter, temporary absence,
target reappearance, zone change, and rapid mode changes. Freeze the result-key
and significant-zone-change policy before testing. Count repeated announcements
within the configured suppression window, check the required stable processed
frames, and verify that canceled sessions never speak stale results. Use timing
and synthetic event IDs without logging camera/OCR/speech payloads.

## Vietnamese OCR scoring

Use a human-reviewed reference transcription in expected reading order. Normalize
reference and output to Unicode NFC, convert whitespace runs to one space, and
trim outer whitespace. Preserve case, punctuation, digits, and Vietnamese
diacritics. Count Unicode code points after normalization; record that choice
with the scorer version. Apply identical normalization to both sides.

Compute character-level edit distance using substitutions (S), deletions (D),
and insertions (I): CER = (S + D + I) / N, where N is the reference character
count. Report total edits / total reference characters as corpus CER, plus
per-image distribution and separate label/paragraph/condition results. CER can
exceed 100%; do not cap it. Missing output for nonempty text counts as deletions.
For empty-reference scenes, CER is N/A; count spurious text and verify accessible
no-text guidance separately. Include crashes/time-outs in task-failure counts
even if no OCR string is available for character scoring.

For short-text latency, initially define short print as 10–100 Vietnamese words
on a label or flat page; confirm the range during pilot and lock exact fixtures.
Measure printed-text recognition separately from TTS intelligibility. Validate
spoken names, numbers, diacritics, reading order, and stop behavior with listeners;
a good CER alone does not prove usable spoken feedback.

## Device matrix and latency procedure

Use the three physical-device profiles in PRD section 9.6. Actual device
assignment is pending; do not infer tested support from the proposed API 29+
target or the starter's inherited `flutter.minSdkVersion`.

| Device ID | Intended profile | Assignment and evidence |
| --- | --- | --- |
| D1 | ARM64, 4 GB, Android 10/11 where available | Unassigned; not evaluated |
| D2 | Mainstream Android 12+ development phone | Unassigned; not evaluated |
| D3 | Different manufacturer; Samsung/Xiaomi/OPPO coverage | Unassigned; not evaluated |

For each phone, record exact model, Android/API version, RAM, camera/resolution,
STT/TTS engine and offline language versions, TalkBack version/state, locale,
text scale, battery/charging state, and ambient/initial thermal condition.
Use consistent scenes and resource setup. Report unavailable profiles as coverage
gaps and assess emulator results separately.

Propose at least 30 warm trials per action/device and 10 process-cold trials per
action/device for the pilot; confirm the final counts before acceptance. Define
warm as initialized resources after one excluded setup trial. Define process-cold
as a fresh process with installed model/voice resources retained, not a fresh
installation. Report each group separately. Never drop a measured slow trial
as warm-up. Use monotonic timestamps within one clock domain.

| Action | Start | End |
| --- | --- | --- |
| Stable detection | First evaluable camera frame containing the target in the scripted scene | Actual onset of correct spoken feedback, including stability processing and audio scheduling |
| Short-text OCR | Activation of Read text | Correct request's OCR result displayed; report wrong/empty output separately |
| OCR spoken response | Activation of Read text | Actual onset of Vietnamese speech; report separately from the OCR display target |
| Touch stop | Stop control activation | Audible TTS playback ceases |
| Voice command | End of the user's utterance | Correct action starts; separately measure voice-stop audio cessation |

Do not equate an enqueued TTS request or plugin callback with audible onset or
cessation without validation. Use a documented synthetic non-personal bench
fixture and observer/external timing reference when necessary; do not turn on
app audio recording or store participant audio. If timing resolution cannot
assess the stop target, mark it not evaluated.

Report sample count, failures/time-outs, median, P95, and maximum per device,
action, and warm/cold group. Use nearest-rank P95: sorted sample at
ceil(0.95 * n), one-based. Successful-run latency must be accompanied by the
all-attempt success rate; time-outs and incorrect results cannot disappear from
the report. Document task-specific deadlines before running the benchmark.

Run the provisional continuous-session duration on each device with a repeatable
mode schedule. Record crashes, peak app-process memory with measurement method,
available thermal readings, and processed-frame throughput early/late in the run.
Distinguish app from system memory and state when a thermal sensor is unavailable.
Resource budgets and thermal/throughput degradation limits remain to be set
from pilot evidence; a crash-free session alone is not a performance pass.

## Offline, privacy, and lifecycle checks

Prepare the installed resources first and record setup downloads separately.
Then restart in airplane mode with Wi-Fi/mobile data disabled and repeat detection,
OCR, TTS, and touch controls. Test STT availability separately. Repeat with missing
resources and denied/revoked permissions; expected outcomes are accessible guidance
and usable alternatives, not cloud fallback.

Also test with connectivity enabled using a documented capture method that can
attribute requests to the app. Observe launch, recognition, stop, background/resume,
and mode changes. Verify the PRD telemetry-disabled configuration and absence of
camera/OCR/speech uploads and unexpected app requests. Airplane-mode success alone
does not prove no request was attempted; combine configuration/source review,
request instrumentation, and traffic observations, documenting blind spots.
Keep reports to counts, endpoints/categories, synthetic scene IDs, and timings;
exclude sensitive payloads, tokens, participant audio, and personal documents.

## Target-user and accessibility procedure

Run the PRD's 5–8-person pilot, fix issues, and freeze a confirmation protocol
before recruitment/testing for that round. State sample size, recruitment limits,
prior smartphone/TalkBack familiarity, permitted assistive settings, and whether
participants are blind, low-vision, or proxies. Report these groups separately.
Obtain voluntary accessible consent, use pseudonymous IDs, define access/retention
and deletion procedures, and allow withdrawal without treating the person as a
product failure. Withdrawal before a task starts is not a scored attempt. Retain
completed scored attempts only where consent permits; report attrition, deleted
records, and resulting denominator changes. Do not selectively remove failed
attempts. Report withdrawal reasons only where consent permits.

1. Explain scope and give the same onboarding plus a practice scene that is not
   scored. Do not coach during scored attempts; record any assistance needed.
2. Use safe stationary tasks: find a supported object on a table, read a prepared
   short label/paragraph, and stop active speech. Add unsupported/absent target,
   missing offline STT, and TalkBack navigation checks. Never require unsafe travel.
3. Counterbalance task order and use equivalent alternate scenes. For the pilot,
   propose one scored attempt per core task/participant with a 60-second search
   and text-reading limit; define stop-task limits separately before testing.
   These study time limits are not replacements for the PRD latency targets.
4. Define success before testing: correct requested object and zone for search;
   correct answers to predefined key-information questions after text reading;
   stopped speech that does not resume for the stop task. Test touch and available
   voice paths separately, including TTS/TalkBack overlap.
5. Classify success without help, success with help, incorrect outcome, time-out,
   or technical failure. For each task, divide unassisted successes by all scored
   participant attempts; assisted successes and technical failures are not passes.
   If repeats are added, report first-attempt results and per-person outcomes
   separately so extra attempts do not inflate participant completion rates.
6. Report absolute counts and percentages, completion times, error types,
   assistance, and qualitative feedback. Publish the denominator and missing-data
   handling. Do not pool proxy results to claim target-user success or generalize
   a small pilot to all users. Recheck P0/P1 issues after fixes; P0 blocks any core
   task or violates the data policy, P1 prevents independent task completion with
   no practical accessible workaround. Freeze defect severity rules before review.

## Evidence and acceptance report

Use one record per metric/device/condition/group with: requirement ID, protocol
and manifest version, configuration, sample count/denominator, measured result,
threshold and its status, pass/fail/not-evaluated, evidence location, limitations,
and follow-up owner/action. Include a class-coverage table, unresolved defects,
device gaps, and the frozen-threshold decision. No evidence files are claimed to
exist yet; select their controlled storage location before execution.

Keep non-personal numerical summaries in the project report; evaluation media
and participant records follow the access/retention plan, not repository commits.
Link evidence from PRD section 9.6 and close [roadmap milestones](development-roadmap.md)
only when their exit criteria are met. Current CI provides generation, analysis,
and a staging APK build, not physical-device or target-user validation; its test
step is commented out. See [quick start](quick-start-guide.md) for commands.
