import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'SecBizCard'**
  String get appTitle;

  /// Slogan displayed on login screen
  ///
  /// In en, this message translates to:
  /// **'Secure. Professional. Instant.'**
  String get loginSlogan;

  /// Text for the Google sign-in button
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// Text for the Apple sign-in button
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get signInWithApple;

  /// Text for the secondary sign-in option link
  ///
  /// In en, this message translates to:
  /// **'or sign in with {provider}'**
  String orSignInWith(String provider);

  /// Title for the profile screen
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Text for the edit profile button
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Welcome message on onboarding
  ///
  /// In en, this message translates to:
  /// **'Welcome to SecBizCard'**
  String get onboardingWelcome;

  /// Shown while recognizing a card via Cloud Vision
  ///
  /// In en, this message translates to:
  /// **'Recognizing with Cloud Vision…'**
  String get ocrRecognizingCloudVision;

  /// Shown while recognizing a card via on-device ML Kit
  ///
  /// In en, this message translates to:
  /// **'Recognizing on-device…'**
  String get ocrRecognizingOnDevice;

  /// Result badge: recognized using the user's own Cloud Vision key
  ///
  /// In en, this message translates to:
  /// **'Cloud Vision · Your key'**
  String get ocrSourceCloudVisionOwn;

  /// Result badge: recognized using shared Cloud Vision with monthly usage
  ///
  /// In en, this message translates to:
  /// **'Cloud Vision · {used}/{cap} this month'**
  String ocrSourceCloudVisionShared(int used, int cap);

  /// Result badge: recognized using on-device ML Kit
  ///
  /// In en, this message translates to:
  /// **'On-device recognition'**
  String get ocrSourceOnDevice;

  /// No description provided for @aiRecognitionTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Recognition'**
  String get aiRecognitionTitle;

  /// No description provided for @ocrUsingOwnKey.
  ///
  /// In en, this message translates to:
  /// **'Using your Cloud Vision key'**
  String get ocrUsingOwnKey;

  /// No description provided for @ocrUsingOwnKeyDesc.
  ///
  /// In en, this message translates to:
  /// **'Best quality. Billed to your own Google Cloud account.'**
  String get ocrUsingOwnKeyDesc;

  /// No description provided for @ocrUsingSharedQuota.
  ///
  /// In en, this message translates to:
  /// **'Using shared quota'**
  String get ocrUsingSharedQuota;

  /// No description provided for @ocrUsingSharedQuotaDesc.
  ///
  /// In en, this message translates to:
  /// **'Up to {perUser} free AI scans per month, then it falls back to fast on-device recognition. Add your own key below for unlimited best-quality scans.'**
  String ocrUsingSharedQuotaDesc(int perUser);

  /// No description provided for @ocrUsageThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month: {used} / {cap}'**
  String ocrUsageThisMonth(int used, int cap);

  /// No description provided for @ocrOwnKeyNearLimitWarn.
  ///
  /// In en, this message translates to:
  /// **'You have used 80%+ of the monthly free tier. Further scans this month may incur charges on your Google Cloud account.'**
  String get ocrOwnKeyNearLimitWarn;

  /// No description provided for @ocrUseOwnKeyHeading.
  ///
  /// In en, this message translates to:
  /// **'Use your own API key'**
  String get ocrUseOwnKeyHeading;

  /// No description provided for @ocrUpdateOwnKeyHeading.
  ///
  /// In en, this message translates to:
  /// **'Update your API key'**
  String get ocrUpdateOwnKeyHeading;

  /// No description provided for @ocrKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Paste your Cloud Vision API key'**
  String get ocrKeyHint;

  /// No description provided for @ocrKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Cloud Vision key saved securely on this device.'**
  String get ocrKeySaved;

  /// No description provided for @ocrKeyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Cloud Vision key removed from this device.'**
  String get ocrKeyRemoved;

  /// No description provided for @ocrKeyMasked.
  ///
  /// In en, this message translates to:
  /// **'A key is saved on this device.'**
  String get ocrKeyMasked;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ocrReplaceKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace saved key?'**
  String get ocrReplaceKeyTitle;

  /// No description provided for @ocrReplaceKeyBody.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite the API key currently stored on this device.'**
  String get ocrReplaceKeyBody;

  /// No description provided for @ocrRemoveKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove saved key?'**
  String get ocrRemoveKeyTitle;

  /// No description provided for @ocrRemoveKeyBody.
  ///
  /// In en, this message translates to:
  /// **'This device will go back to using the shared monthly quota. You can add your key again anytime.'**
  String get ocrRemoveKeyBody;

  /// No description provided for @ocrHowToTitle.
  ///
  /// In en, this message translates to:
  /// **'How to get a Cloud Vision API key'**
  String get ocrHowToTitle;

  /// No description provided for @ocrHowTo1.
  ///
  /// In en, this message translates to:
  /// **'1. Go to Google Cloud Console and create (or pick) a project.'**
  String get ocrHowTo1;

  /// No description provided for @ocrHowTo2.
  ///
  /// In en, this message translates to:
  /// **'2. Enable the \"Cloud Vision API\" for that project.'**
  String get ocrHowTo2;

  /// No description provided for @ocrHowTo3.
  ///
  /// In en, this message translates to:
  /// **'3. Under APIs & Services → Credentials, create an API key.'**
  String get ocrHowTo3;

  /// No description provided for @ocrHowTo4.
  ///
  /// In en, this message translates to:
  /// **'4. Copy the key and paste it above.'**
  String get ocrHowTo4;

  /// No description provided for @ocrOpenConsole.
  ///
  /// In en, this message translates to:
  /// **'Open Google Cloud Console'**
  String get ocrOpenConsole;

  /// No description provided for @ocrSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your key stays on your device'**
  String get ocrSafetyTitle;

  /// No description provided for @ocrSafety1.
  ///
  /// In en, this message translates to:
  /// **'• Your key is saved only in this device\'s secure keychain — it is never uploaded to our servers, never synced, and never leaves your phone.'**
  String get ocrSafety1;

  /// No description provided for @ocrSafety2.
  ///
  /// In en, this message translates to:
  /// **'• The app sends card images straight to Google Cloud Vision using your key, so recognition is billed to your own account.'**
  String get ocrSafety2;

  /// No description provided for @ocrSafety3.
  ///
  /// In en, this message translates to:
  /// **'• In Google Cloud, restrict the key to the Cloud Vision API only, and set a budget/quota limit to cap spending.'**
  String get ocrSafety3;

  /// No description provided for @ocrSafety4.
  ///
  /// In en, this message translates to:
  /// **'• If a key ever leaks, delete it in the Cloud Console and paste a new one here.'**
  String get ocrSafety4;

  /// Admin/owner view: global usage of the shared Cloud Vision key
  ///
  /// In en, this message translates to:
  /// **'Cloud Vision · shared key {used}/{cap} this month'**
  String ocrSharedKeyUsage(int used, int cap);

  /// Primary instruction on the card scanning screen
  ///
  /// In en, this message translates to:
  /// **'Place business card in frame'**
  String get scanCardHint;

  /// Secondary tip: a plain background improves card edge detection
  ///
  /// In en, this message translates to:
  /// **'Use a plain, non-patterned background'**
  String get scanCardBackgroundTip;

  /// Title of the dialog shown on Back when a result looks poor
  ///
  /// In en, this message translates to:
  /// **'Was the recognition off?'**
  String get ocrFeedbackPromptTitle;

  /// Body explaining the optional bad-result report and refund
  ///
  /// In en, this message translates to:
  /// **'If this card wasn\'t recognized well, you can help us improve. This uses one fewer of your monthly scans back.'**
  String get ocrFeedbackPromptBody;

  /// Button to proceed to report a poor recognition
  ///
  /// In en, this message translates to:
  /// **'Help improve'**
  String get ocrFeedbackReport;

  /// Button to dismiss the report prompt
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get ocrFeedbackDismiss;

  /// Checkbox to suppress the report prompt for a rolling 24 hours
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again for 24 hours'**
  String get ocrFeedbackDontAsk24h;

  /// Title of the consent dialog before submitting a sample
  ///
  /// In en, this message translates to:
  /// **'Help us improve recognition'**
  String get ocrFeedbackConsentTitle;

  /// One-line consent summary shown by default
  ///
  /// In en, this message translates to:
  /// **'Send this card\'s recognition data to help us improve. It is used only to improve recognition and is deleted after review (and within 90 days otherwise).'**
  String get ocrFeedbackConsentSummary;

  /// Checkbox to additionally consent to sending the card image
  ///
  /// In en, this message translates to:
  /// **'Also include the card photo (optional)'**
  String get ocrFeedbackConsentIncludePhoto;

  /// Expander to show the full consent terms text
  ///
  /// In en, this message translates to:
  /// **'View full terms'**
  String get ocrFeedbackViewTerms;

  /// Full consent terms. PLACEHOLDER text pending legal review.
  ///
  /// In en, this message translates to:
  /// **'PLACEHOLDER — pending legal review. We collect the card\'s recognized text and layout data, the recognition result, and (only if you tick the option) the card photo. Purpose: to reproduce and improve recognition accuracy. We do not use it for any other purpose and do not share it. Data is deleted immediately after we analyze it, and any unused data is automatically deleted within 90 days. Submitting is always optional and asked each time. The card may contain another person\'s personal data; by submitting you confirm you\'re comfortable sharing it for this purpose.'**
  String get ocrFeedbackTermsBody;

  /// Button to consent and submit the sample
  ///
  /// In en, this message translates to:
  /// **'Agree and send'**
  String get ocrFeedbackSubmit;

  /// Button to cancel the consent dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ocrFeedbackCancel;

  /// Snackbar shown after a successful feedback submission
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your feedback helps improve recognition.'**
  String get ocrFeedbackThanks;

  /// Snackbar after a successful submission that also refunded a scan
  ///
  /// In en, this message translates to:
  /// **'Thanks! We\'ve credited one scan back to you.'**
  String get ocrFeedbackThanksRefunded;

  /// Snackbar when the monthly submit cap is reached
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached this month\'s feedback limit. Thanks for helping!'**
  String get ocrFeedbackLimitReached;

  /// Snackbar when the submission failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send feedback. Please try again later.'**
  String get ocrFeedbackFailed;
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
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
