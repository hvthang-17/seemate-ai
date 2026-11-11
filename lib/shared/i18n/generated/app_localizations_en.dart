// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get helloWorld => 'Hello World!';

  @override
  String get displaySomeText => 'Display some text!';

  @override
  String get homeTitle => 'SeeMate AI';

  @override
  String get usageGuideTitle => 'Usage guide';

  @override
  String get usageGuideListen => 'Listen in Vietnamese';

  @override
  String get usageGuideClose => 'Close guide';

  @override
  String get usageGuideText =>
      'Welcome to SeeMate AI. Choose Object recognition to hear what the camera sees. Choose Find object and select an item to hear its position in the frame.\n\nTo read printed text, choose Read text, point the camera at the page, then choose Capture and read text. The Stop reading button stops speech.\n\nIf voice commands are available, tap Speak a command, wait for the vibration, then say your command. SeeMate AI is not for navigation or obstacle avoidance.';

  @override
  String get chooseAssistanceMode => 'Choose an action';

  @override
  String get recognizeDescription => 'Hear what is in front of you';

  @override
  String get findDescription => 'Choose an object and hear its position';

  @override
  String get readDescription => 'Capture printed text and hear it aloud';

  @override
  String get detectionDetails => 'Detection details';

  @override
  String get homeLoadCities => 'Load cities';

  @override
  String get homeLoadError => 'We couldn\'t load the cities. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get modeRecognize => 'Object recognition';

  @override
  String get modeFind => 'Find an object';

  @override
  String get modeRead => 'Read text';

  @override
  String get modeStop => 'Stop reading';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get selectTargetTitle => 'Select object to find';

  @override
  String get cameraPermissionPrompt =>
      'SeeMate AI needs camera permission to recognize objects and read text.';

  @override
  String get cameraPermissionDeniedPermanent =>
      'Camera permission is permanently denied. Please grant permission in device Settings.';

  @override
  String get cameraOpening => 'Opening the camera.';

  @override
  String get cameraPreviewReady => 'Camera preview is ready.';

  @override
  String get captureText => 'Capture and read text';

  @override
  String get voiceListen => 'Speak a command';

  @override
  String get voicePreparing => 'Preparing microphone. Tap to cancel';

  @override
  String get voiceCancel => 'Listening. Tap to cancel';

  @override
  String get voiceOfflineUnavailable =>
      'Offline Vietnamese command recognition is unavailable in this build.';

  @override
  String get voiceMicrophoneDenied =>
      'Microphone permission is required for voice commands. You can enable it in Android settings.';

  @override
  String get voiceNotUnderstood => 'Command not understood. Try again.';

  @override
  String get voiceCaptureRequiresTextMode =>
      'Open Read text before saying Capture.';

  @override
  String get ocrCaptureFailed =>
      'Could not capture an image. Hold the phone steady and try again.';

  @override
  String get ocrReadFailed =>
      'Could not read text from the image. Try again with clearer text.';

  @override
  String get offlineVoiceUnavailable =>
      'Offline Vietnamese speech is unavailable. Install a Vietnamese voice in your device\'s text-to-speech settings.';

  @override
  String get cameraDetectionReady => 'The camera is running.';

  @override
  String get detectionModelUnavailable =>
      'The local object detection model is unavailable in this build.';

  @override
  String get detectionInitializationFailed =>
      'The object detector could not start. Restart the app to try again.';

  @override
  String get detectionFailed =>
      'Object detection is temporarily unavailable. Try pointing the camera again.';

  @override
  String get detectionWaiting => 'Waiting for the first detection result.';

  @override
  String detectionBounds(String label, String coordinates) {
    return 'Model label: $label. Frame box (left, top, right, bottom): $coordinates';
  }

  @override
  String get cameraPaused => 'The camera is paused.';

  @override
  String get cameraUnavailable =>
      'The camera is unavailable. Close other apps using it and try again.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get noDetectionFeedback =>
      'Cannot identify clearly. Please move closer or increase lighting.';

  @override
  String get unsupportedObject =>
      'This object is not currently supported for search.';

  @override
  String get ocrEmptyFeedback =>
      'No text detected in image. Please try again with clearer focus.';

  @override
  String get speechRateLabel => 'Speech rate';

  @override
  String get duplicateSuppressionLabel =>
      'Duplicate announcement suppression (seconds)';

  @override
  String get save => 'Save';

  @override
  String get savedSuccess => 'Settings saved successfully';

  @override
  String get saveError => 'Failed to save settings';

  @override
  String get settingsLoadError =>
      'Could not load saved settings. Try again or save the settings shown here.';
}
