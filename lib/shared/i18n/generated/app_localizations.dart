import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @helloWorld.
  ///
  /// In en, this message translates to:
  /// **'Hello World!'**
  String get helloWorld;

  /// No description provided for @displaySomeText.
  ///
  /// In en, this message translates to:
  /// **'Display some text!'**
  String get displaySomeText;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'SeeMate AI'**
  String get homeTitle;

  /// No description provided for @usageGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage guide'**
  String get usageGuideTitle;

  /// No description provided for @usageGuideListen.
  ///
  /// In en, this message translates to:
  /// **'Listen in Vietnamese'**
  String get usageGuideListen;

  /// No description provided for @usageGuideClose.
  ///
  /// In en, this message translates to:
  /// **'Close guide'**
  String get usageGuideClose;

  /// No description provided for @usageGuideText.
  ///
  /// In en, this message translates to:
  /// **'Welcome to SeeMate AI. Choose Object recognition to hear what the camera sees. Choose Find object and select an item to hear its position in the frame.\n\nTo read printed text, choose Read text, point the camera at the page, then choose Capture and read text. The Stop reading button stops speech.\n\nIf voice commands are available, tap Speak a command, wait for the vibration, then say your command. SeeMate AI is not for navigation or obstacle avoidance.'**
  String get usageGuideText;

  /// No description provided for @chooseAssistanceMode.
  ///
  /// In en, this message translates to:
  /// **'Choose an action'**
  String get chooseAssistanceMode;

  /// No description provided for @recognizeDescription.
  ///
  /// In en, this message translates to:
  /// **'Hear what is in front of you'**
  String get recognizeDescription;

  /// No description provided for @findDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an object and hear its position'**
  String get findDescription;

  /// No description provided for @readDescription.
  ///
  /// In en, this message translates to:
  /// **'Capture printed text and hear it aloud'**
  String get readDescription;

  /// No description provided for @detectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Detection details'**
  String get detectionDetails;

  /// No description provided for @homeLoadCities.
  ///
  /// In en, this message translates to:
  /// **'Load cities'**
  String get homeLoadCities;

  /// No description provided for @homeLoadError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the cities. Please try again.'**
  String get homeLoadError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @modeRecognize.
  ///
  /// In en, this message translates to:
  /// **'Object recognition'**
  String get modeRecognize;

  /// No description provided for @modeFind.
  ///
  /// In en, this message translates to:
  /// **'Find an object'**
  String get modeFind;

  /// No description provided for @modeRead.
  ///
  /// In en, this message translates to:
  /// **'Read text'**
  String get modeRead;

  /// No description provided for @modeStop.
  ///
  /// In en, this message translates to:
  /// **'Stop reading'**
  String get modeStop;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @selectTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select object to find'**
  String get selectTargetTitle;

  /// No description provided for @cameraPermissionPrompt.
  ///
  /// In en, this message translates to:
  /// **'SeeMate AI needs camera permission to recognize objects and read text.'**
  String get cameraPermissionPrompt;

  /// No description provided for @cameraPermissionDeniedPermanent.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is permanently denied. Please grant permission in device Settings.'**
  String get cameraPermissionDeniedPermanent;

  /// No description provided for @cameraOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening the camera.'**
  String get cameraOpening;

  /// No description provided for @cameraPreviewReady.
  ///
  /// In en, this message translates to:
  /// **'Camera preview is ready.'**
  String get cameraPreviewReady;

  /// No description provided for @captureText.
  ///
  /// In en, this message translates to:
  /// **'Capture and read text'**
  String get captureText;

  /// No description provided for @voiceListen.
  ///
  /// In en, this message translates to:
  /// **'Speak a command'**
  String get voiceListen;

  /// No description provided for @voicePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing microphone. Tap to cancel'**
  String get voicePreparing;

  /// No description provided for @voiceCancel.
  ///
  /// In en, this message translates to:
  /// **'Listening. Tap to cancel'**
  String get voiceCancel;

  /// No description provided for @voiceOfflineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Offline Vietnamese command recognition is unavailable in this build.'**
  String get voiceOfflineUnavailable;

  /// No description provided for @voiceMicrophoneDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for voice commands. You can enable it in Android settings.'**
  String get voiceMicrophoneDenied;

  /// No description provided for @voiceNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Command not understood. Try again.'**
  String get voiceNotUnderstood;

  /// No description provided for @voiceCaptureRequiresTextMode.
  ///
  /// In en, this message translates to:
  /// **'Open Read text before saying Capture.'**
  String get voiceCaptureRequiresTextMode;

  /// No description provided for @ocrCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not capture an image. Hold the phone steady and try again.'**
  String get ocrCaptureFailed;

  /// No description provided for @ocrReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read text from the image. Try again with clearer text.'**
  String get ocrReadFailed;

  /// No description provided for @offlineVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Offline Vietnamese speech is unavailable. Install a Vietnamese voice in your device\'s text-to-speech settings.'**
  String get offlineVoiceUnavailable;

  /// No description provided for @cameraDetectionReady.
  ///
  /// In en, this message translates to:
  /// **'The camera is running.'**
  String get cameraDetectionReady;

  /// No description provided for @detectionModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The local object detection model is unavailable in this build.'**
  String get detectionModelUnavailable;

  /// No description provided for @detectionInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'The object detector could not start. Restart the app to try again.'**
  String get detectionInitializationFailed;

  /// No description provided for @detectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Object detection is temporarily unavailable. Try pointing the camera again.'**
  String get detectionFailed;

  /// No description provided for @detectionWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first detection result.'**
  String get detectionWaiting;

  /// No description provided for @detectionBounds.
  ///
  /// In en, this message translates to:
  /// **'Model label: {label}. Frame box (left, top, right, bottom): {coordinates}'**
  String detectionBounds(String label, String coordinates);

  /// No description provided for @cameraPaused.
  ///
  /// In en, this message translates to:
  /// **'The camera is paused.'**
  String get cameraPaused;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is unavailable. Close other apps using it and try again.'**
  String get cameraUnavailable;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @noDetectionFeedback.
  ///
  /// In en, this message translates to:
  /// **'Cannot identify clearly. Please move closer or increase lighting.'**
  String get noDetectionFeedback;

  /// No description provided for @unsupportedObject.
  ///
  /// In en, this message translates to:
  /// **'This object is not currently supported for search.'**
  String get unsupportedObject;

  /// No description provided for @ocrEmptyFeedback.
  ///
  /// In en, this message translates to:
  /// **'No text detected in image. Please try again with clearer focus.'**
  String get ocrEmptyFeedback;

  /// No description provided for @speechRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get speechRateLabel;

  /// No description provided for @duplicateSuppressionLabel.
  ///
  /// In en, this message translates to:
  /// **'Duplicate announcement suppression (seconds)'**
  String get duplicateSuppressionLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @savedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully'**
  String get savedSuccess;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get saveError;

  /// No description provided for @settingsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved settings. Try again or save the settings shown here.'**
  String get settingsLoadError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
