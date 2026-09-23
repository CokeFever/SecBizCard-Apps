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
  String get ocrTierBasic => 'Basic';

  @override
  String get ocrTierPlus => 'Plus';

  @override
  String get ocrTierPro => 'Pro';

  @override
  String get ocrTierVip => 'VIP';

  @override
  String get ocrTierFlex => 'Flex';

  @override
  String ocrTierUsageCount(int used, int cap) {
    return '$used/$cap this month';
  }

  @override
  String get ocrUsageByok => 'BYOK';

  @override
  String ocrTierBadge(String tier, String usage) {
    return '$tier · $usage';
  }

  @override
  String get ocrUsageUnknown => 'Usage unavailable';

  @override
  String get ocrYourPlan => 'Your plan';

  @override
  String get ocrSubscribe => 'Subscribe';

  @override
  String get ocrUpgradeToPro => 'Upgrade to Pro';

  @override
  String get ocrSubscribeComingSoon => 'Subscriptions are coming soon.';

  @override
  String get ocrAdminObservability => 'Admin · shared-key usage';

  @override
  String get ocrAdminShared800 => 'Free pool (Basic)';

  @override
  String get ocrAdminTotal => 'Total CV calls';

  @override
  String get ocrKeyFormatHint =>
      'A Google Cloud API key starts with \"AIza\" and is 39 characters long.';

  @override
  String get ocrPaywallPlanPlus => 'SecBizCard Plus';

  @override
  String get ocrPaywallPlanPro => 'SecBizCard Pro';

  @override
  String get qrScanToExchange => 'Scan to Exchange';

  @override
  String get navShare => 'Share';

  @override
  String get navCard => 'Card';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get unsavedChangesTitle => 'Unsaved Changes';

  @override
  String get unsavedChangesBody =>
      'You have unsaved changes. Are you sure you want to discard them and leave?';

  @override
  String get unsavedChangesStay => 'Stay';

  @override
  String get unsavedChangesDiscard => 'Discard';

  @override
  String get drawerNotLoggedIn => 'Not Logged In';

  @override
  String get drawerDefaultUser => 'User';

  @override
  String get drawerMyProfile => 'My Profile';

  @override
  String get drawerManageContexts => 'Manage Contexts';

  @override
  String get drawerErrorLoadingProfile => 'Error loading profile';

  @override
  String get drawerBackupRestore => 'Backup & Restore';

  @override
  String get drawerAiRecognition => 'AI Recognition';

  @override
  String get drawerImportVcard => 'Import vCard';

  @override
  String get drawerAppearance => 'Appearance';

  @override
  String get drawerThemeAuto => 'Auto';

  @override
  String get drawerThemeLight => 'Light';

  @override
  String get drawerThemeDark => 'Dark';

  @override
  String get drawerLogout => 'Logout';

  @override
  String get drawerConfirmLogoutTitle => 'Confirm Logout';

  @override
  String get drawerConfirmLogoutBody => 'Are you sure you want to log out?';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get drawerLinkPrivacy => 'Privacy';

  @override
  String get drawerLinkTerms => 'Terms';

  @override
  String get drawerLinkGuide => 'Guide';

  @override
  String loginSignInError(String error) {
    return 'Sign-in error: $error';
  }

  @override
  String contactsNoneFoundFor(String query) {
    return 'No contacts found for \"$query\"';
  }

  @override
  String get contactsNoneYet => 'No contacts yet';

  @override
  String get contactsEmptyHint => 'Exchanged or scanned cards will appear here';

  @override
  String contactsDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get contactsDeleted => 'Contact deleted';

  @override
  String get contactsDelete => 'Delete';

  @override
  String get contactsSearchHint => 'Search contacts…';

  @override
  String commonErrorWithDetail(String error) {
    return 'Error: $error';
  }

  @override
  String get onboardingSetupProfile => 'Setup Profile';

  @override
  String get onboardingGetStarted => 'Get Started Quickly';

  @override
  String get onboardingImportDesc =>
      'Import your profile from your Google Contact card to skip manual entry.';

  @override
  String get onboardingImportFromGoogle => 'Import from Google';

  @override
  String get onboardingEnterManually => 'Enter Manually';

  @override
  String get onboardingReviewInfo => 'Review Your Info';

  @override
  String get onboardingMasterProfileDesc =>
      'This info will be your \"Master Profile\". You can choose what to share later.';

  @override
  String get onboardingRecoveryTip =>
      'Tip: Using your Personal Phone & Gmail is recommended for account recovery and verified trust.';

  @override
  String get onboardingFieldName => 'Full Name (Required)';

  @override
  String get onboardingFieldPhone => 'Phone (Optional)';

  @override
  String get onboardingFieldEmail => 'Email (Optional)';

  @override
  String get onboardingFieldTitle => 'Job Title';

  @override
  String get onboardingFieldCompany => 'Company';

  @override
  String get onboardingNameRequired => 'Name is required';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingSmartContexts => 'Smart Contexts';

  @override
  String get onboardingContextsDesc =>
      'We have set up 3 default contexts for you. You can customize them anytime in Settings.';

  @override
  String get onboardingContextWorkShares =>
      'Shares: Name, Job Title, Company, Phone, Email';

  @override
  String get onboardingContextPersonalShares =>
      'Shares: Name, Personal Email, Avatar';

  @override
  String get onboardingContextQuickShares => 'Shares: Name only';

  @override
  String get onboardingLooksGood => 'Looks Good';

  @override
  String get onboardingAllSet => 'You are all set!';

  @override
  String get onboardingReadyDesc =>
      'Your digital business card is ready to share.';

  @override
  String get onboardingStartUsing => 'Start Using SecBizCard';

  @override
  String get profileNotFound => 'Profile not found';

  @override
  String get profileEdit => 'Edit Profile';

  @override
  String get profileDeleteAccount => 'Delete Account';

  @override
  String get profileContinueToDelete => 'Continue to Delete';

  @override
  String get profileAreYouSure => 'Are you sure?';

  @override
  String get profileDeleteLastChance =>
      'This is your last chance. Your account, profile, and all contacts will be permanently deleted.';

  @override
  String get profileDeleteForever => 'Delete Forever';

  @override
  String commonFailedWithDetail(String error) {
    return 'Failed: $error';
  }

  @override
  String get qrGenerating => 'Generating secured QR code…';

  @override
  String get qrBatchApproval => 'Batch Approval';

  @override
  String get qrBatchApprovalOn => 'Approve first request for all';

  @override
  String get qrBatchApprovalOff => 'Approve each request manually';

  @override
  String qrResetsIn(String time) {
    return 'Resets in $time';
  }

  @override
  String qrRefreshAvailableIn(int seconds) {
    return 'Available in ${seconds}s';
  }

  @override
  String get qrRefreshTooltip => 'Refresh QR Code';

  @override
  String get qrUrlCopied => 'URL copied to clipboard';

  @override
  String get qrCopyUrl => 'Copy URL';

  @override
  String get qrRetry => 'Retry';

  @override
  String get qrErrorSignInRequired =>
      'You must be signed in to share your info.';

  @override
  String qrErrorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get qrErrorNotAuthenticated => 'Not authenticated';

  @override
  String get qrErrorCompleteProfile => 'Please complete your profile first';

  @override
  String get qrCannotShare => 'Cannot Share';

  @override
  String get commonOk => 'OK';

  @override
  String get qrInfoSharedBack => 'Info Shared Back!';

  @override
  String qrAlsoSharedInfo(String name) {
    return '$name also shared their info.';
  }

  @override
  String get qrSaveToContacts => 'Save to Contacts';

  @override
  String get commonClose => 'Close';

  @override
  String get qrContactSaved => 'Contact Saved!';

  @override
  String qrSavedToContacts(String name) {
    return 'Saved $name to contacts';
  }

  @override
  String get qrInfoSharedSuccess => 'Info Shared Successfully!';

  @override
  String get ocrKeyLockedNote =>
      'Your own key is active. To change it, remove it first and add a new one.';

  @override
  String get ocrRemoveKeyAction => 'Remove key';

  @override
  String get ocrPaywallTitle => 'Upgrade cloud recognition';

  @override
  String get ocrPaywallSubtitle =>
      'Faster, more accurate card recognition — no key setup needed.';

  @override
  String get ocrPlanPlusPrice => 'US\$0.99/mo';

  @override
  String get ocrPlanPlusDesc => '20 cloud scans per month';

  @override
  String get ocrPlanProPrice => 'US\$4.99/mo';

  @override
  String get ocrPlanProDesc => '100 cloud scans per month';

  @override
  String get ocrRestorePurchases => 'Restore purchases';

  @override
  String get ocrSubscribeThanks => 'Thanks for subscribing!';

  @override
  String get ocrRestoreDone => 'Purchases restored.';

  @override
  String get ocrSubscribeFailed => 'Something went wrong. Please try again.';

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
      'Send this card\'s recognition data to help us improve. It is used only to improve recognition and is deleted after review, and in all cases within 30 days.';

  @override
  String get ocrFeedbackConsentIncludePhoto =>
      'Include the card photo (helps us fix the error — untick to skip)';

  @override
  String get ocrFeedbackViewTerms => 'View full terms';

  @override
  String get ocrFeedbackTermsBody =>
      'Who processes this: SecBizCard is the data controller for feedback you send. Contact us at privacy@ixo.app.\n\nWhat we collect: the card\'s recognized text and layout data, the recognition result, and — because it is essential to reproduce and fix recognition errors — the card photo. Sending is always optional and asked each time.\n\nWhy: solely to reproduce and improve recognition accuracy. We do not use it for any other purpose, and we do not sell it or share it for advertising.\n\nWho it reaches: to process your feedback we use service providers acting on our behalf — Google Cloud Vision and Firebase (Google) for recognition and storage. They may process it outside your country; where required for EU users we rely on Standard Contractual Clauses. We do not share it with anyone else.\n\nLegal basis: our legitimate interest in improving recognition quality, and your consent to this submission. Because a business card contains another person\'s personal data, you confirm you have a reasonable basis to share it for this purpose.\n\nRetention: we delete your submission as soon as we finish analyzing it, and in all cases within 30 days. It is encrypted in transit and at rest.\n\nYour rights: you can ask us to access or delete your submitted feedback, or raise a concern, at privacy@ixo.app. See our Privacy Policy for full details.';

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

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get editProfilePhoneResetWarn =>
      '⚠️ Verified phone modified. Verification will be reset on save.';

  @override
  String get editProfileReverifyHint =>
      '⚠️ Modifying this will require re-verification';

  @override
  String get editProfileEditPhoto => 'Edit Photo';

  @override
  String get editProfileChooseImageSource => 'Choose Image Source';

  @override
  String get editProfileGallery => 'Gallery';

  @override
  String get editProfileCamera => 'Camera';

  @override
  String get editProfileVerificationResetTitle => 'Verification Will Be Reset';

  @override
  String get editProfileVerificationResetBody =>
      'You are changing a verified phone number. This will reset the verification status and you will need to verify the new number.';

  @override
  String get editProfileContinue => 'Continue';

  @override
  String get editProfileFullName => 'Full Name';

  @override
  String get editProfileNameRequired => 'Name is required';

  @override
  String get editProfileJobTitle => 'Job Title';

  @override
  String get editProfileCompany => 'Company';

  @override
  String get editProfilePhone => 'Phone';

  @override
  String get editProfileAdditionalInfo => 'Additional Info';

  @override
  String get editProfileAddField => 'Add Field';

  @override
  String get editProfileTapToChangePhoto => 'Tap to change photo';

  @override
  String get editProfileBusinessCards => 'Business Cards';

  @override
  String get editProfileFrontSide => 'Front Side';

  @override
  String get editProfileBackSide => 'Back Side';

  @override
  String editProfileUpload(String label) {
    return 'Upload $label';
  }

  @override
  String get editProfileFieldTypeLabel => 'Type';

  @override
  String get editProfileFieldLabelLabel => 'Label';

  @override
  String get editProfileAdd => 'Add';

  @override
  String get handshakeTitle => 'Exchange Info';

  @override
  String handshakeSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get handshakeShareBackTitle => 'Share Back?';

  @override
  String get handshakeShareBackBody =>
      'Do you want to share your contact info back?';

  @override
  String get handshakeNo => 'No';

  @override
  String get handshakeYes => 'Yes';

  @override
  String handshakeShareFailed(String error) {
    return 'Failed to share: $error';
  }

  @override
  String get handshakeInvalidLink => 'Invalid or Expired Link';

  @override
  String handshakeParseError(String error) {
    return 'Error parsing data: $error';
  }

  @override
  String get handshakeFoundLink => 'Found Secure Link';

  @override
  String get handshakeRequestPrompt => 'Request to exchange info?';

  @override
  String get handshakeAbort => 'Abort';

  @override
  String get handshakeSendRequest => 'Send Request';

  @override
  String get handshakeRequestSent => 'Request Sent!';

  @override
  String get handshakeWaitingApproval => 'Waiting for approval...';

  @override
  String get handshakeRequestDeclined => 'Request Declined';

  @override
  String get handshakeSessionExpired => 'Session Expired';

  @override
  String get handshakeInfoReceived => 'Info Received!';

  @override
  String get handshakeSelectContext => 'Select Context to Share';

  @override
  String get handshakeContextBusiness => 'Business';

  @override
  String get handshakeContextSocial => 'Social';

  @override
  String get handshakeContextLite => 'Lite';

  @override
  String get handshakeShare => 'Share';

  @override
  String get incomingExpired => 'Expired';

  @override
  String get incomingUnknownUser => 'Unknown User';

  @override
  String get incomingTitle => 'Incoming Request';

  @override
  String incomingWantsToExchange(String name) {
    return '$name wants to exchange contact info.';
  }

  @override
  String get incomingAddToContacts => 'Add to my contacts';

  @override
  String get incomingChooseInfo => 'Choose info to share:';

  @override
  String get incomingDecline => 'Decline';

  @override
  String get incomingApprove => 'Approve';

  @override
  String get scannerInvalidQr => 'Invalid QR code';

  @override
  String get scannerInvalidQrFormat =>
      'Invalid QR code format. Expected: https://ixo.app/<id>';

  @override
  String get scannerTitle => 'Scan QR Code';

  @override
  String get scannerPlaceInFrame => 'Place QR code in frame';

  @override
  String get scannerPermissionTitle => 'Camera Permission Required';

  @override
  String get scannerPermissionBody =>
      'This feature requires camera access to scan QR codes for secure exchange.';

  @override
  String get scannerOpenSettings => 'Open Settings';

  @override
  String get scannerGrantPermission => 'Grant Permission';

  @override
  String get editContactTitle => 'Edit Contact';

  @override
  String get editContactUpdated => 'Contact updated';

  @override
  String get editContactBasicInfo => 'Basic Info';

  @override
  String get editContactDisplayName => 'Display Name';

  @override
  String get editContactNickname => 'Nickname (Only visible to you)';

  @override
  String get editContactJobInfo => 'Job Info';

  @override
  String get editContactContact => 'Contact';

  @override
  String get editContactEmail => 'Email';

  @override
  String get editContactOriginalScan => 'Original Scan';

  @override
  String editContactFieldRequired(String label) {
    return '$label is required';
  }

  @override
  String get contactDetailTitle => 'Contact Details';

  @override
  String contactDetailCopied(String label) {
    return '$label copied to clipboard';
  }

  @override
  String get contactDetailChooseGallery => 'Choose from Gallery';

  @override
  String get contactDetailTakePhoto => 'Take Photo';

  @override
  String get contactDetailRemovePhoto => 'Remove Photo';

  @override
  String get contactDetailPhotoUpdated => 'Photo updated';

  @override
  String get contactDetailCurrentAccount => 'current account';

  @override
  String get contactDetailExportTitle => 'Export to Google Contacts';

  @override
  String get contactDetailUseThisAccount => 'Use this account';

  @override
  String get contactDetailUseAnotherAccount => 'Or use another account';

  @override
  String contactDetailExportFailed(String error) {
    return 'Export Failed: $error';
  }

  @override
  String get contactDetailExportSuccess => 'Exported successfully!';

  @override
  String contactDetailShareVcardFailed(String error) {
    return 'Failed to share vCard: $error';
  }

  @override
  String contactDetailShareZipFailed(String error) {
    return 'Failed to share .zip: $error';
  }

  @override
  String get contactDetailMoreActions => 'More actions';

  @override
  String get contactDetailShareVcard => 'Text only (vCard .vcf)';

  @override
  String get contactDetailShareZip => 'Text + images (.zip)';

  @override
  String get contactDetailSaveToGoogle => 'Save to Google Contacts';

  @override
  String get contactDetailLabelEmail => 'Email';

  @override
  String get contactDetailLabelPhone => 'Phone';

  @override
  String get contactDetailLabelJobTitle => 'Job Title';

  @override
  String get contactDetailLabelCompany => 'Company';

  @override
  String get contactDetailLabelDepartment => 'Department';

  @override
  String get contactDetailLabelAddress => 'Address';

  @override
  String get contactDetailOcrResult => 'OCR Result';

  @override
  String get scanCapturing => 'Capturing...';

  @override
  String get scanDetectingEdges => 'Detecting card edges...';

  @override
  String get scanRecognizeFailed => 'Failed to recognize text on card';

  @override
  String get scanNoteOwnKeyNearLimit =>
      'Your Cloud Vision key is near its monthly free limit (80%).';

  @override
  String get scanNoteSharedNearLimit =>
      'Shared recognition quota is running low this month.';

  @override
  String get scanNoteUsedOnDevice =>
      'Used on-device recognition. Add a Cloud Vision key in Settings for best results.';

  @override
  String get scanToggleHorizontal => 'Horizontal';

  @override
  String get scanToggleVertical => 'Vertical';

  @override
  String get scanCameraUnavailableTitle => 'Camera Unavailable';

  @override
  String get scanCameraUnavailableBody =>
      'Could not access the camera. Please ensure it is not being used by another app.';

  @override
  String get scanRetry => 'Retry';

  @override
  String get scanPermissionBody =>
      'This feature requires camera access to scan and recognize business cards.';
}
