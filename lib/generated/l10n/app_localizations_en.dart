// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SecBizCard';

  @override
  String get loginSlogan => 'Secure. Professional. Instant.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String orSignInWith(String provider) {
    return 'or sign in with $provider';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get onboardingWelcome => 'Welcome to SecBizCard';

  @override
  String get ocrRecognizingCloudVision => 'Recognizing with Cloud Vision…';

  @override
  String get ocrRecognizingOnDevice => 'Recognizing on-device…';

  @override
  String get ocrSourceCloudVisionOwn => 'Cloud Vision · Your key';

  @override
  String ocrSourceCloudVisionShared(int used, int cap) {
    return 'Cloud Vision · $used/$cap this month';
  }

  @override
  String get ocrSourceOnDevice => 'On-device recognition';

  @override
  String get aiRecognitionTitle => 'AI Recognition';

  @override
  String get ocrUsingOwnKey => 'Using your Cloud Vision key';

  @override
  String get ocrUsingOwnKeyDesc =>
      'Best quality. Billed to your own Google Cloud account.';

  @override
  String get ocrUsingSharedQuota => 'Using shared quota';

  @override
  String ocrUsingSharedQuotaDesc(int perUser) {
    return 'Up to $perUser free AI scans per month, then it falls back to fast on-device recognition. Add your own key below for unlimited best-quality scans.';
  }

  @override
  String ocrUsageThisMonth(int used, int cap) {
    return 'This month: $used / $cap';
  }

  @override
  String get ocrOwnKeyNearLimitWarn =>
      'You have used 80%+ of the monthly free tier. Further scans this month may incur charges on your Google Cloud account.';

  @override
  String get ocrUseOwnKeyHeading => 'Use your own API key';

  @override
  String get ocrUpdateOwnKeyHeading => 'Update your API key';

  @override
  String get ocrKeyHint => 'Paste your Cloud Vision API key';

  @override
  String get ocrKeySaved => 'Cloud Vision key saved securely on this device.';

  @override
  String get ocrKeyRemoved => 'Cloud Vision key removed from this device.';

  @override
  String get ocrKeyMasked => 'A key is saved on this device.';

  @override
  String get save => 'Save';

  @override
  String get update => 'Update';

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

  @override
  String get ocrReplaceKeyTitle => 'Replace saved key?';

  @override
  String get ocrReplaceKeyBody =>
      'This will overwrite the API key currently stored on this device.';

  @override
  String get ocrRemoveKeyTitle => 'Remove saved key?';

  @override
  String get ocrRemoveKeyBody =>
      'This device will go back to using the shared monthly quota. You can add your key again anytime.';

  @override
  String get ocrHowToTitle => 'How to get a Cloud Vision API key';

  @override
  String get ocrHowTo1 =>
      '1. Go to Google Cloud Console and create (or pick) a project.';

  @override
  String get ocrHowTo2 =>
      '2. Enable the \"Cloud Vision API\" for that project.';

  @override
  String get ocrHowTo3 =>
      '3. Under APIs & Services → Credentials, create an API key.';

  @override
  String get ocrHowTo4 => '4. Copy the key and paste it above.';

  @override
  String get ocrOpenConsole => 'Open Google Cloud Console';

  @override
  String get ocrSafetyTitle => 'Your key stays on your device';

  @override
  String get ocrSafety1 =>
      '• Your key is saved only in this device\'s secure keychain — it is never uploaded to our servers, never synced, and never leaves your phone.';

  @override
  String get ocrSafety2 =>
      '• The app sends card images straight to Google Cloud Vision using your key, so recognition is billed to your own account.';

  @override
  String get ocrSafety3 =>
      '• In Google Cloud, restrict the key to the Cloud Vision API only, and set a budget/quota limit to cap spending.';

  @override
  String get ocrSafety4 =>
      '• If a key ever leaks, delete it in the Cloud Console and paste a new one here.';

  @override
  String ocrSharedKeyUsage(int used, int cap) {
    return 'Cloud Vision · shared key $used/$cap this month';
  }

  @override
  String get scanCardHint => 'Place business card in frame';

  @override
  String get scanCardBackgroundTip => 'Use a plain, non-patterned background';

  @override
  String get ocrFeedbackPromptTitle => 'Was the recognition off?';

  @override
  String get ocrFeedbackPromptBody =>
      'If this card wasn\'t recognized well, you can help us improve. This uses one fewer of your monthly scans back.';

  @override
  String get ocrFeedbackReport => 'Help improve';

  @override
  String get ocrFeedbackDismiss => 'No thanks';

  @override
  String get ocrFeedbackDontAsk24h => 'Don\'t ask again for 24 hours';

  @override
  String get ocrFeedbackConsentTitle => 'Help us improve recognition';

  @override
  String get ocrFeedbackConsentSummary =>
      'Send this card\'s recognition data to help us improve. It is used only to improve recognition and is deleted after review (and within 90 days otherwise).';

  @override
  String get ocrFeedbackConsentIncludePhoto =>
      'Also include the card photo (optional)';

  @override
  String get ocrFeedbackViewTerms => 'View full terms';

  @override
  String get ocrFeedbackTermsBody =>
      'PLACEHOLDER — pending legal review. We collect the card\'s recognized text and layout data, the recognition result, and (only if you tick the option) the card photo. Purpose: to reproduce and improve recognition accuracy. We do not use it for any other purpose and do not share it. Data is deleted immediately after we analyze it, and any unused data is automatically deleted within 90 days. Submitting is always optional and asked each time. The card may contain another person\'s personal data; by submitting you confirm you\'re comfortable sharing it for this purpose.';

  @override
  String get ocrFeedbackSubmit => 'Agree and send';

  @override
  String get ocrFeedbackCancel => 'Cancel';

  @override
  String get ocrFeedbackThanks =>
      'Thanks! Your feedback helps improve recognition.';

  @override
  String get ocrFeedbackThanksRefunded =>
      'Thanks! We\'ve credited one scan back to you.';

  @override
  String get ocrFeedbackLimitReached =>
      'You\'ve reached this month\'s feedback limit. Thanks for helping!';

  @override
  String get ocrFeedbackFailed =>
      'Couldn\'t send feedback. Please try again later.';
}
