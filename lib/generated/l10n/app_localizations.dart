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

  /// Free OCR tier name
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get ocrTierBasic;

  /// Paid OCR tier name (Plus)
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get ocrTierPlus;

  /// Paid OCR tier name (Pro)
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get ocrTierPro;

  /// Internal unlimited OCR tier name
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get ocrTierVip;

  /// BYOK OCR tier name (user's own key)
  ///
  /// In en, this message translates to:
  /// **'Flex'**
  String get ocrTierFlex;

  /// Monthly usage count for a finite OCR tier
  ///
  /// In en, this message translates to:
  /// **'{used}/{cap} this month'**
  String ocrTierUsageCount(int used, int cap);

  /// Usage label for the Flex/BYOK tier (own key, untracked)
  ///
  /// In en, this message translates to:
  /// **'BYOK'**
  String get ocrUsageByok;

  /// Combined tier badge, e.g. 'Plus · 12/20 this month' or 'VIP · ∞'
  ///
  /// In en, this message translates to:
  /// **'{tier} · {usage}'**
  String ocrTierBadge(String tier, String usage);

  /// Shown when the monthly usage count can't be loaded (offline)
  ///
  /// In en, this message translates to:
  /// **'Usage unavailable'**
  String get ocrUsageUnknown;

  /// Label above the current OCR tier name on the AI Recognition screen
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get ocrYourPlan;

  /// Button that opens the subscription options
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get ocrSubscribe;

  /// Button for Plus subscribers to upgrade to Pro
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get ocrUpgradeToPro;

  /// Temporary notice until RevenueCat purchases are live
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are coming soon.'**
  String get ocrSubscribeComingSoon;

  /// Header for the admin-only usage observability block
  ///
  /// In en, this message translates to:
  /// **'Admin · shared-key usage'**
  String get ocrAdminObservability;

  /// Admin label for the shared 800 free budget counter
  ///
  /// In en, this message translates to:
  /// **'Free pool (Basic)'**
  String get ocrAdminShared800;

  /// Admin label for the total monthly Cloud Vision usage counter
  ///
  /// In en, this message translates to:
  /// **'Total CV calls'**
  String get ocrAdminTotal;

  /// Hint under the BYOK key field explaining the expected key format
  ///
  /// In en, this message translates to:
  /// **'A Google Cloud API key starts with \"AIza\" and is 39 characters long.'**
  String get ocrKeyFormatHint;

  /// Paywall plan name for the Plus tier (brand name, kept in English)
  ///
  /// In en, this message translates to:
  /// **'SecBizCard Plus'**
  String get ocrPaywallPlanPlus;

  /// Paywall plan name for the Pro tier (brand name, kept in English)
  ///
  /// In en, this message translates to:
  /// **'SecBizCard Pro'**
  String get ocrPaywallPlanPro;

  /// Title above the QR code on the share screen
  ///
  /// In en, this message translates to:
  /// **'Scan to Exchange'**
  String get qrScanToExchange;

  /// Main screen title for the Share tab (kept in English across locales — brand/functional label)
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get navShare;

  /// Main screen title for the Card tab (kept in English across locales)
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get navCard;

  /// Notifications screen/section title (kept in English across locales)
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to discard them and leave?'**
  String get unsavedChangesBody;

  /// No description provided for @unsavedChangesStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get unsavedChangesStay;

  /// No description provided for @unsavedChangesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get unsavedChangesDiscard;

  /// No description provided for @drawerNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Logged In'**
  String get drawerNotLoggedIn;

  /// No description provided for @drawerDefaultUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get drawerDefaultUser;

  /// No description provided for @drawerMyProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get drawerMyProfile;

  /// No description provided for @drawerManageContexts.
  ///
  /// In en, this message translates to:
  /// **'Manage Contexts'**
  String get drawerManageContexts;

  /// No description provided for @drawerErrorLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error loading profile'**
  String get drawerErrorLoadingProfile;

  /// No description provided for @drawerBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get drawerBackupRestore;

  /// Drawer item for the AI Recognition (OCR) settings screen; 'AI' kept in English
  ///
  /// In en, this message translates to:
  /// **'AI Recognition'**
  String get drawerAiRecognition;

  /// 'vCard' kept in English (format name)
  ///
  /// In en, this message translates to:
  /// **'Import vCard'**
  String get drawerImportVcard;

  /// No description provided for @drawerAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get drawerAppearance;

  /// No description provided for @drawerThemeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get drawerThemeAuto;

  /// No description provided for @drawerThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get drawerThemeLight;

  /// No description provided for @drawerThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get drawerThemeDark;

  /// No description provided for @drawerLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get drawerLogout;

  /// No description provided for @drawerConfirmLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get drawerConfirmLogoutTitle;

  /// No description provided for @drawerConfirmLogoutBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get drawerConfirmLogoutBody;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @drawerLinkPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get drawerLinkPrivacy;

  /// No description provided for @drawerLinkTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get drawerLinkTerms;

  /// No description provided for @drawerLinkGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get drawerLinkGuide;

  /// No description provided for @loginSignInError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in error: {error}'**
  String loginSignInError(String error);

  /// No description provided for @contactsNoneFoundFor.
  ///
  /// In en, this message translates to:
  /// **'No contacts found for \"{query}\"'**
  String contactsNoneFoundFor(String query);

  /// No description provided for @contactsNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get contactsNoneYet;

  /// No description provided for @contactsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Exchanged or scanned cards will appear here'**
  String get contactsEmptyHint;

  /// No description provided for @contactsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String contactsDeleteFailed(String error);

  /// No description provided for @contactsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Contact deleted'**
  String get contactsDeleted;

  /// No description provided for @contactsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get contactsDelete;

  /// No description provided for @contactsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search contacts…'**
  String get contactsSearchHint;

  /// No description provided for @commonErrorWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonErrorWithDetail(String error);

  /// No description provided for @onboardingSetupProfile.
  ///
  /// In en, this message translates to:
  /// **'Setup Profile'**
  String get onboardingSetupProfile;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started Quickly'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingImportDesc.
  ///
  /// In en, this message translates to:
  /// **'Import your profile from your Google Contact card to skip manual entry.'**
  String get onboardingImportDesc;

  /// No description provided for @onboardingImportFromGoogle.
  ///
  /// In en, this message translates to:
  /// **'Import from Google'**
  String get onboardingImportFromGoogle;

  /// No description provided for @onboardingEnterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter Manually'**
  String get onboardingEnterManually;

  /// No description provided for @onboardingReviewInfo.
  ///
  /// In en, this message translates to:
  /// **'Review Your Info'**
  String get onboardingReviewInfo;

  /// No description provided for @onboardingMasterProfileDesc.
  ///
  /// In en, this message translates to:
  /// **'This info will be your \"Master Profile\". You can choose what to share later.'**
  String get onboardingMasterProfileDesc;

  /// No description provided for @onboardingRecoveryTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: Using your Personal Phone & Gmail is recommended for account recovery and verified trust.'**
  String get onboardingRecoveryTip;

  /// No description provided for @onboardingFieldName.
  ///
  /// In en, this message translates to:
  /// **'Full Name (Required)'**
  String get onboardingFieldName;

  /// No description provided for @onboardingFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone (Optional)'**
  String get onboardingFieldPhone;

  /// No description provided for @onboardingFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email (Optional)'**
  String get onboardingFieldEmail;

  /// No description provided for @onboardingFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get onboardingFieldTitle;

  /// No description provided for @onboardingFieldCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get onboardingFieldCompany;

  /// No description provided for @onboardingNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get onboardingNameRequired;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingSmartContexts.
  ///
  /// In en, this message translates to:
  /// **'Smart Contexts'**
  String get onboardingSmartContexts;

  /// No description provided for @onboardingContextsDesc.
  ///
  /// In en, this message translates to:
  /// **'We have set up 3 default contexts for you. You can customize them anytime in Settings.'**
  String get onboardingContextsDesc;

  /// No description provided for @onboardingContextWorkShares.
  ///
  /// In en, this message translates to:
  /// **'Shares: Name, Job Title, Company, Phone, Email'**
  String get onboardingContextWorkShares;

  /// No description provided for @onboardingContextPersonalShares.
  ///
  /// In en, this message translates to:
  /// **'Shares: Name, Personal Email, Avatar'**
  String get onboardingContextPersonalShares;

  /// No description provided for @onboardingContextQuickShares.
  ///
  /// In en, this message translates to:
  /// **'Shares: Name only'**
  String get onboardingContextQuickShares;

  /// No description provided for @onboardingLooksGood.
  ///
  /// In en, this message translates to:
  /// **'Looks Good'**
  String get onboardingLooksGood;

  /// No description provided for @onboardingAllSet.
  ///
  /// In en, this message translates to:
  /// **'You are all set!'**
  String get onboardingAllSet;

  /// No description provided for @onboardingReadyDesc.
  ///
  /// In en, this message translates to:
  /// **'Your digital business card is ready to share.'**
  String get onboardingReadyDesc;

  /// Final onboarding button; brand name kept in English
  ///
  /// In en, this message translates to:
  /// **'Start Using SecBizCard'**
  String get onboardingStartUsing;

  /// No description provided for @profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get profileNotFound;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEdit;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccount;

  /// No description provided for @profileContinueToDelete.
  ///
  /// In en, this message translates to:
  /// **'Continue to Delete'**
  String get profileContinueToDelete;

  /// No description provided for @profileAreYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get profileAreYouSure;

  /// No description provided for @profileDeleteLastChance.
  ///
  /// In en, this message translates to:
  /// **'This is your last chance. Your account, profile, and all contacts will be permanently deleted.'**
  String get profileDeleteLastChance;

  /// No description provided for @profileDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get profileDeleteForever;

  /// No description provided for @commonFailedWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String commonFailedWithDetail(String error);

  /// Shown inside the QR placeholder frame while the session is being created
  ///
  /// In en, this message translates to:
  /// **'Generating secured QR code…'**
  String get qrGenerating;

  /// No description provided for @qrBatchApproval.
  ///
  /// In en, this message translates to:
  /// **'Batch Approval'**
  String get qrBatchApproval;

  /// No description provided for @qrBatchApprovalOn.
  ///
  /// In en, this message translates to:
  /// **'Approve first request for all'**
  String get qrBatchApprovalOn;

  /// No description provided for @qrBatchApprovalOff.
  ///
  /// In en, this message translates to:
  /// **'Approve each request manually'**
  String get qrBatchApprovalOff;

  /// No description provided for @qrResetsIn.
  ///
  /// In en, this message translates to:
  /// **'Resets in {time}'**
  String qrResetsIn(String time);

  /// No description provided for @qrRefreshAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Available in {seconds}s'**
  String qrRefreshAvailableIn(int seconds);

  /// No description provided for @qrRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh QR Code'**
  String get qrRefreshTooltip;

  /// No description provided for @qrUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied to clipboard'**
  String get qrUrlCopied;

  /// No description provided for @qrCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get qrCopyUrl;

  /// No description provided for @qrRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get qrRetry;

  /// No description provided for @qrErrorSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in to share your info.'**
  String get qrErrorSignInRequired;

  /// No description provided for @qrErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String qrErrorPrefix(String message);

  /// No description provided for @qrErrorNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get qrErrorNotAuthenticated;

  /// No description provided for @qrErrorCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Please complete your profile first'**
  String get qrErrorCompleteProfile;

  /// No description provided for @qrCannotShare.
  ///
  /// In en, this message translates to:
  /// **'Cannot Share'**
  String get qrCannotShare;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @qrInfoSharedBack.
  ///
  /// In en, this message translates to:
  /// **'Info Shared Back!'**
  String get qrInfoSharedBack;

  /// No description provided for @qrAlsoSharedInfo.
  ///
  /// In en, this message translates to:
  /// **'{name} also shared their info.'**
  String qrAlsoSharedInfo(String name);

  /// No description provided for @qrSaveToContacts.
  ///
  /// In en, this message translates to:
  /// **'Save to Contacts'**
  String get qrSaveToContacts;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @qrContactSaved.
  ///
  /// In en, this message translates to:
  /// **'Contact Saved!'**
  String get qrContactSaved;

  /// No description provided for @qrSavedToContacts.
  ///
  /// In en, this message translates to:
  /// **'Saved {name} to contacts'**
  String qrSavedToContacts(String name);

  /// No description provided for @qrInfoSharedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Info Shared Successfully!'**
  String get qrInfoSharedSuccess;

  /// Explains why the key field is locked when a BYOK key is set
  ///
  /// In en, this message translates to:
  /// **'Your own key is active. To change it, remove it first and add a new one.'**
  String get ocrKeyLockedNote;

  /// Button to delete the saved BYOK key
  ///
  /// In en, this message translates to:
  /// **'Remove key'**
  String get ocrRemoveKeyAction;

  /// Title of the subscription options sheet
  ///
  /// In en, this message translates to:
  /// **'Upgrade cloud recognition'**
  String get ocrPaywallTitle;

  /// Subtitle of the subscription options sheet
  ///
  /// In en, this message translates to:
  /// **'Faster, more accurate card recognition — no key setup needed.'**
  String get ocrPaywallSubtitle;

  /// Plus plan price (placeholder until store pricing is live)
  ///
  /// In en, this message translates to:
  /// **'US\$0.99/mo'**
  String get ocrPlanPlusPrice;

  /// Plus plan description
  ///
  /// In en, this message translates to:
  /// **'20 cloud scans per month'**
  String get ocrPlanPlusDesc;

  /// Pro plan price (placeholder until store pricing is live)
  ///
  /// In en, this message translates to:
  /// **'US\$4.99/mo'**
  String get ocrPlanProPrice;

  /// Pro plan description
  ///
  /// In en, this message translates to:
  /// **'100 cloud scans per month'**
  String get ocrPlanProDesc;

  /// Button to restore previous subscription purchases
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get ocrRestorePurchases;

  /// Snackbar after a successful subscription purchase
  ///
  /// In en, this message translates to:
  /// **'Thanks for subscribing!'**
  String get ocrSubscribeThanks;

  /// Snackbar after restoring purchases
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get ocrRestoreDone;

  /// Snackbar when a purchase or restore fails
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get ocrSubscribeFailed;

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
  /// **'Send this card\'s recognition data to help us improve. It is used only to improve recognition and is deleted after review, and in all cases within 30 days.'**
  String get ocrFeedbackConsentSummary;

  /// Checkbox to additionally consent to sending the card image
  ///
  /// In en, this message translates to:
  /// **'Include the card photo (helps us fix the error — untick to skip)'**
  String get ocrFeedbackConsentIncludePhoto;

  /// Expander to show the full consent terms text
  ///
  /// In en, this message translates to:
  /// **'View full terms'**
  String get ocrFeedbackViewTerms;

  /// Full consent terms for the OCR feedback feature (includes card photo; 30-day retention).
  ///
  /// In en, this message translates to:
  /// **'Who processes this: SecBizCard is the data controller for feedback you send. Contact us at privacy@ixo.app.\n\nWhat we collect: the card\'s recognized text and layout data, the recognition result, and — because it is essential to reproduce and fix recognition errors — the card photo. Sending is always optional and asked each time.\n\nWhy: solely to reproduce and improve recognition accuracy. We do not use it for any other purpose, and we do not sell it or share it for advertising.\n\nWho it reaches: to process your feedback we use service providers acting on our behalf — Google Cloud Vision and Firebase (Google) for recognition and storage. They may process it outside your country; where required for EU users we rely on Standard Contractual Clauses. We do not share it with anyone else.\n\nLegal basis: our legitimate interest in improving recognition quality, and your consent to this submission. Because a business card contains another person\'s personal data, you confirm you have a reasonable basis to share it for this purpose.\n\nRetention: we delete your submission as soon as we finish analyzing it, and in all cases within 30 days. It is encrypted in transit and at rest.\n\nYour rights: you can ask us to access or delete your submitted feedback, or raise a concern, at privacy@ixo.app. See our Privacy Policy for full details.'**
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

  /// App bar title on the edit profile screen
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// Snackbar when a verified phone number is edited
  ///
  /// In en, this message translates to:
  /// **'⚠️ Verified phone modified. Verification will be reset on save.'**
  String get editProfilePhoneResetWarn;

  /// Inline hint under a verified field when focused
  ///
  /// In en, this message translates to:
  /// **'⚠️ Modifying this will require re-verification'**
  String get editProfileReverifyHint;

  /// Image cropper toolbar title
  ///
  /// In en, this message translates to:
  /// **'Edit Photo'**
  String get editProfileEditPhoto;

  /// Dialog title for picking image source
  ///
  /// In en, this message translates to:
  /// **'Choose Image Source'**
  String get editProfileChooseImageSource;

  /// Image source option: pick from gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get editProfileGallery;

  /// Image source option: take a photo
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get editProfileCamera;

  /// Dialog title when saving a changed verified phone
  ///
  /// In en, this message translates to:
  /// **'Verification Will Be Reset'**
  String get editProfileVerificationResetTitle;

  /// Dialog body when saving a changed verified phone
  ///
  /// In en, this message translates to:
  /// **'You are changing a verified phone number. This will reset the verification status and you will need to verify the new number.'**
  String get editProfileVerificationResetBody;

  /// Confirm button to proceed with resetting verification
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get editProfileContinue;

  /// Label for the full name field
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get editProfileFullName;

  /// Validation error when name is empty
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get editProfileNameRequired;

  /// Label for the job title field
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get editProfileJobTitle;

  /// Label for the company field
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get editProfileCompany;

  /// Label for the phone field
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get editProfilePhone;

  /// Section header for custom fields
  ///
  /// In en, this message translates to:
  /// **'Additional Info'**
  String get editProfileAdditionalInfo;

  /// Button and dialog title to add a custom field
  ///
  /// In en, this message translates to:
  /// **'Add Field'**
  String get editProfileAddField;

  /// Hint below the avatar
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get editProfileTapToChangePhoto;

  /// Section header for card images
  ///
  /// In en, this message translates to:
  /// **'Business Cards'**
  String get editProfileBusinessCards;

  /// Label for the front card image picker
  ///
  /// In en, this message translates to:
  /// **'Front Side'**
  String get editProfileFrontSide;

  /// Label for the back card image picker
  ///
  /// In en, this message translates to:
  /// **'Back Side'**
  String get editProfileBackSide;

  /// Placeholder text inside an empty card image picker
  ///
  /// In en, this message translates to:
  /// **'Upload {label}'**
  String editProfileUpload(String label);

  /// Label for the field-category dropdown in Add Field dialog
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get editProfileFieldTypeLabel;

  /// Label for the field-label dropdown in Add Field dialog
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get editProfileFieldLabelLabel;

  /// Confirm button in the Add Field dialog
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get editProfileAdd;

  /// App bar title on the handshake exchange screen
  ///
  /// In en, this message translates to:
  /// **'Exchange Info'**
  String get handshakeTitle;

  /// No description provided for @handshakeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String handshakeSaveFailed(String error);

  /// Dialog title asking whether to share info back
  ///
  /// In en, this message translates to:
  /// **'Share Back?'**
  String get handshakeShareBackTitle;

  /// No description provided for @handshakeShareBackBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to share your contact info back?'**
  String get handshakeShareBackBody;

  /// No description provided for @handshakeNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get handshakeNo;

  /// No description provided for @handshakeYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get handshakeYes;

  /// No description provided for @handshakeShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share: {error}'**
  String handshakeShareFailed(String error);

  /// No description provided for @handshakeInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid or Expired Link'**
  String get handshakeInvalidLink;

  /// No description provided for @handshakeParseError.
  ///
  /// In en, this message translates to:
  /// **'Error parsing data: {error}'**
  String handshakeParseError(String error);

  /// No description provided for @handshakeFoundLink.
  ///
  /// In en, this message translates to:
  /// **'Found Secure Link'**
  String get handshakeFoundLink;

  /// No description provided for @handshakeRequestPrompt.
  ///
  /// In en, this message translates to:
  /// **'Request to exchange info?'**
  String get handshakeRequestPrompt;

  /// No description provided for @handshakeAbort.
  ///
  /// In en, this message translates to:
  /// **'Abort'**
  String get handshakeAbort;

  /// No description provided for @handshakeSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get handshakeSendRequest;

  /// No description provided for @handshakeRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request Sent!'**
  String get handshakeRequestSent;

  /// No description provided for @handshakeWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval...'**
  String get handshakeWaitingApproval;

  /// No description provided for @handshakeRequestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Request Declined'**
  String get handshakeRequestDeclined;

  /// No description provided for @handshakeSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get handshakeSessionExpired;

  /// No description provided for @handshakeInfoReceived.
  ///
  /// In en, this message translates to:
  /// **'Info Received!'**
  String get handshakeInfoReceived;

  /// No description provided for @handshakeSelectContext.
  ///
  /// In en, this message translates to:
  /// **'Select Context to Share'**
  String get handshakeSelectContext;

  /// No description provided for @handshakeContextBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get handshakeContextBusiness;

  /// No description provided for @handshakeContextSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get handshakeContextSocial;

  /// No description provided for @handshakeContextLite.
  ///
  /// In en, this message translates to:
  /// **'Lite'**
  String get handshakeContextLite;

  /// Button to share info back with the selected context
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get handshakeShare;

  /// Timer badge when the request has expired
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get incomingExpired;

  /// Fallback name when the requester profile has no name
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get incomingUnknownUser;

  /// No description provided for @incomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming Request'**
  String get incomingTitle;

  /// No description provided for @incomingWantsToExchange.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to exchange contact info.'**
  String incomingWantsToExchange(String name);

  /// No description provided for @incomingAddToContacts.
  ///
  /// In en, this message translates to:
  /// **'Add to my contacts'**
  String get incomingAddToContacts;

  /// No description provided for @incomingChooseInfo.
  ///
  /// In en, this message translates to:
  /// **'Choose info to share:'**
  String get incomingChooseInfo;

  /// No description provided for @incomingDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get incomingDecline;

  /// No description provided for @incomingApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get incomingApprove;

  /// No description provided for @scannerInvalidQr.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code'**
  String get scannerInvalidQr;

  /// Error when the scanned QR does not match the expected link format; the URL is a literal example, kept in English
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code format. Expected: https://ixo.app/<id>'**
  String get scannerInvalidQrFormat;

  /// No description provided for @scannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scannerTitle;

  /// No description provided for @scannerPlaceInFrame.
  ///
  /// In en, this message translates to:
  /// **'Place QR code in frame'**
  String get scannerPlaceInFrame;

  /// No description provided for @scannerPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Permission Required'**
  String get scannerPermissionTitle;

  /// No description provided for @scannerPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'This feature requires camera access to scan QR codes for secure exchange.'**
  String get scannerPermissionBody;

  /// No description provided for @scannerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get scannerOpenSettings;

  /// No description provided for @scannerGrantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get scannerGrantPermission;

  /// No description provided for @editContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Contact'**
  String get editContactTitle;

  /// No description provided for @editContactUpdated.
  ///
  /// In en, this message translates to:
  /// **'Contact updated'**
  String get editContactUpdated;

  /// No description provided for @editContactBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get editContactBasicInfo;

  /// No description provided for @editContactDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get editContactDisplayName;

  /// No description provided for @editContactNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname (Only visible to you)'**
  String get editContactNickname;

  /// No description provided for @editContactJobInfo.
  ///
  /// In en, this message translates to:
  /// **'Job Info'**
  String get editContactJobInfo;

  /// Section header for phone/email fields
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get editContactContact;

  /// No description provided for @editContactEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get editContactEmail;

  /// No description provided for @editContactOriginalScan.
  ///
  /// In en, this message translates to:
  /// **'Original Scan'**
  String get editContactOriginalScan;

  /// No description provided for @editContactFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{label} is required'**
  String editContactFieldRequired(String label);

  /// No description provided for @contactDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Details'**
  String get contactDetailTitle;

  /// No description provided for @contactDetailCopied.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String contactDetailCopied(String label);

  /// No description provided for @contactDetailChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get contactDetailChooseGallery;

  /// No description provided for @contactDetailTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get contactDetailTakePhoto;

  /// No description provided for @contactDetailRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get contactDetailRemovePhoto;

  /// No description provided for @contactDetailPhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get contactDetailPhotoUpdated;

  /// Fallback label when the signed-in email is unavailable
  ///
  /// In en, this message translates to:
  /// **'current account'**
  String get contactDetailCurrentAccount;

  /// No description provided for @contactDetailExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export to Google Contacts'**
  String get contactDetailExportTitle;

  /// No description provided for @contactDetailUseThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Use this account'**
  String get contactDetailUseThisAccount;

  /// No description provided for @contactDetailUseAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Or use another account'**
  String get contactDetailUseAnotherAccount;

  /// No description provided for @contactDetailExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export Failed: {error}'**
  String contactDetailExportFailed(String error);

  /// No description provided for @contactDetailExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Exported successfully!'**
  String get contactDetailExportSuccess;

  /// 'vCard' kept in English
  ///
  /// In en, this message translates to:
  /// **'Failed to share vCard: {error}'**
  String contactDetailShareVcardFailed(String error);

  /// No description provided for @contactDetailShareZipFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share .zip: {error}'**
  String contactDetailShareZipFailed(String error);

  /// No description provided for @contactDetailMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get contactDetailMoreActions;

  /// 'vCard .vcf' kept in English (format names)
  ///
  /// In en, this message translates to:
  /// **'Text only (vCard .vcf)'**
  String get contactDetailShareVcard;

  /// '.zip' kept in English (format name)
  ///
  /// In en, this message translates to:
  /// **'Text + images (.zip)'**
  String get contactDetailShareZip;

  /// No description provided for @contactDetailSaveToGoogle.
  ///
  /// In en, this message translates to:
  /// **'Save to Google Contacts'**
  String get contactDetailSaveToGoogle;

  /// No description provided for @contactDetailLabelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactDetailLabelEmail;

  /// No description provided for @contactDetailLabelPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactDetailLabelPhone;

  /// No description provided for @contactDetailLabelJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get contactDetailLabelJobTitle;

  /// No description provided for @contactDetailLabelCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get contactDetailLabelCompany;

  /// No description provided for @contactDetailLabelDepartment.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get contactDetailLabelDepartment;

  /// No description provided for @contactDetailLabelAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get contactDetailLabelAddress;

  /// Label for the flattened OCR image; 'OCR' kept in English
  ///
  /// In en, this message translates to:
  /// **'OCR Result'**
  String get contactDetailOcrResult;

  /// No description provided for @scanCapturing.
  ///
  /// In en, this message translates to:
  /// **'Capturing...'**
  String get scanCapturing;

  /// No description provided for @scanDetectingEdges.
  ///
  /// In en, this message translates to:
  /// **'Detecting card edges...'**
  String get scanDetectingEdges;

  /// No description provided for @scanRecognizeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to recognize text on card'**
  String get scanRecognizeFailed;

  /// No description provided for @scanNoteOwnKeyNearLimit.
  ///
  /// In en, this message translates to:
  /// **'Your Cloud Vision key is near its monthly free limit (80%).'**
  String get scanNoteOwnKeyNearLimit;

  /// No description provided for @scanNoteSharedNearLimit.
  ///
  /// In en, this message translates to:
  /// **'Shared recognition quota is running low this month.'**
  String get scanNoteSharedNearLimit;

  /// No description provided for @scanNoteUsedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Used on-device recognition. Add a Cloud Vision key in Settings for best results.'**
  String get scanNoteUsedOnDevice;

  /// No description provided for @scanToggleHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get scanToggleHorizontal;

  /// No description provided for @scanToggleVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get scanToggleVertical;

  /// No description provided for @scanCameraUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Unavailable'**
  String get scanCameraUnavailableTitle;

  /// No description provided for @scanCameraUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Could not access the camera. Please ensure it is not being used by another app.'**
  String get scanCameraUnavailableBody;

  /// No description provided for @scanRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get scanRetry;

  /// No description provided for @scanPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'This feature requires camera access to scan and recognize business cards.'**
  String get scanPermissionBody;

  /// No description provided for @backupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating backup...'**
  String get backupCreating;

  /// No description provided for @backupCloudNewerStatus.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup is newer than this device'**
  String get backupCloudNewerStatus;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup Failed: {error}'**
  String backupFailed(String error);

  /// No description provided for @backupSuccessStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup Successful!'**
  String get backupSuccessStatus;

  /// No description provided for @backupSavedToDrive.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to Google Drive'**
  String get backupSavedToDrive;

  /// No description provided for @backupCloudNewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup is newer'**
  String get backupCloudNewerTitle;

  /// No description provided for @backupNeverChangedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'never changed on this device'**
  String get backupNeverChangedOnDevice;

  /// No description provided for @backupLastChanged.
  ///
  /// In en, this message translates to:
  /// **'last changed {time}'**
  String backupLastChanged(String time);

  /// No description provided for @backupCloudNewerBody.
  ///
  /// In en, this message translates to:
  /// **'The backup in Google Drive was updated {cloudTime}, which is newer than the data on this device ({localState}).\n\nBacking up now would overwrite that newer backup — likely a backup made from another device. If you want the newer data on this device, cancel and use Restore instead.\n\nOverwrite the newer backup anyway?'**
  String backupCloudNewerBody(String cloudTime, String localState);

  /// No description provided for @backupOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get backupOverwrite;

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup?'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current contacts and settings. Make sure you have a recent backup. Continue?'**
  String get backupRestoreConfirmBody;

  /// No description provided for @backupRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreAction;

  /// No description provided for @backupRestoringStatus.
  ///
  /// In en, this message translates to:
  /// **'Restoring from Drive...'**
  String get backupRestoringStatus;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore Failed: {error}'**
  String backupRestoreFailed(String error);

  /// No description provided for @backupRestoreCompletedStatus.
  ///
  /// In en, this message translates to:
  /// **'Restore Completed!'**
  String get backupRestoreCompletedStatus;

  /// No description provided for @backupRestoreSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Data restored successfully. Please restart app if needed.'**
  String get backupRestoreSuccessBody;

  /// No description provided for @backupDriveTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Drive Backup'**
  String get backupDriveTitle;

  /// No description provided for @backupDriveDesc.
  ///
  /// In en, this message translates to:
  /// **'Securely backup your contacts and settings to your Google Drive as an encrypted file.'**
  String get backupDriveDesc;

  /// No description provided for @backupProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get backupProcessing;

  /// No description provided for @backupLastBackupLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Backup'**
  String get backupLastBackupLabel;

  /// No description provided for @backupNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get backupNever;

  /// No description provided for @backupNowButton.
  ///
  /// In en, this message translates to:
  /// **'Back Up Now'**
  String get backupNowButton;

  /// No description provided for @backupChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get backupChecking;

  /// No description provided for @backupRestoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from Backup'**
  String get backupRestoreFromBackup;

  /// No description provided for @backupNoBackupFound.
  ///
  /// In en, this message translates to:
  /// **'No Backup Found'**
  String get backupNoBackupFound;

  /// No description provided for @vcardErrorReadingFile.
  ///
  /// In en, this message translates to:
  /// **'Error reading file: {error}'**
  String vcardErrorReadingFile(String error);

  /// No description provided for @vcardInvalidPackage.
  ///
  /// In en, this message translates to:
  /// **'Invalid package: {error}'**
  String vcardInvalidPackage(String error);

  /// No description provided for @vcardNoContactsInPackage.
  ///
  /// In en, this message translates to:
  /// **'No contacts found in the package'**
  String get vcardNoContactsInPackage;

  /// 'vCard' kept in English (format name)
  ///
  /// In en, this message translates to:
  /// **'Please paste vCard content first'**
  String get vcardPasteFirst;

  /// No description provided for @vcardNoContactsInContent.
  ///
  /// In en, this message translates to:
  /// **'No contacts found in vCard content'**
  String get vcardNoContactsInContent;

  /// No description provided for @vcardImportedCount.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} contact(s){skippedNote}'**
  String vcardImportedCount(int count, String skippedNote);

  /// No description provided for @vcardSkippedNote.
  ///
  /// In en, this message translates to:
  /// **' (skipped {count})'**
  String vcardSkippedNote(int count);

  /// No description provided for @vcardViewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get vcardViewAction;

  /// No description provided for @vcardImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String vcardImportFailed(String error);

  /// No description provided for @vcardPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Import {count} Contact(s)?'**
  String vcardPreviewTitle(int count);

  /// No description provided for @vcardNoContactInfo.
  ///
  /// In en, this message translates to:
  /// **'No contact info'**
  String get vcardNoContactInfo;

  /// No description provided for @vcardImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get vcardImportAction;

  /// No description provided for @vcardHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get vcardHowItWorks;

  /// AI app names and 'vCard 2.1' kept in English
  ///
  /// In en, this message translates to:
  /// **'Use your favorite AI app (ChatGPT, Gemini, Grok, etc.) to scan a business card photo and ask it to format the result as vCard 2.1.'**
  String get vcardHowItWorksDesc;

  /// 'AI' kept in English
  ///
  /// In en, this message translates to:
  /// **'Copy AI Prompt'**
  String get vcardCopyPrompt;

  /// No description provided for @vcardPromptCopied.
  ///
  /// In en, this message translates to:
  /// **'AI prompt copied to clipboard!'**
  String get vcardPromptCopied;

  /// No description provided for @vcardThen.
  ///
  /// In en, this message translates to:
  /// **'Then:'**
  String get vcardThen;

  /// '.vcf' kept in English (file extension)
  ///
  /// In en, this message translates to:
  /// **'Upload the exported .vcf file, or'**
  String get vcardStep1;

  /// No description provided for @vcardStep2.
  ///
  /// In en, this message translates to:
  /// **'Paste the vCard text directly below'**
  String get vcardStep2;

  /// No description provided for @vcardOption1.
  ///
  /// In en, this message translates to:
  /// **'Option 1: Upload File'**
  String get vcardOption1;

  /// '.vcf' kept in English (file extension)
  ///
  /// In en, this message translates to:
  /// **'Choose File (.vcf)'**
  String get vcardChooseFile;

  /// No description provided for @vcardOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get vcardOr;

  /// No description provided for @vcardOption2.
  ///
  /// In en, this message translates to:
  /// **'Option 2: Paste vCard Text'**
  String get vcardOption2;

  /// No description provided for @vcardImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get vcardImporting;

  /// No description provided for @vcardImportFromText.
  ///
  /// In en, this message translates to:
  /// **'Import from Text'**
  String get vcardImportFromText;

  /// No description provided for @historyClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear History?'**
  String get historyClearTitle;

  /// No description provided for @historyClearBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete all handshake records.'**
  String get historyClearBody;

  /// No description provided for @historyClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get historyClearAction;

  /// No description provided for @historyClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get historyClearTooltip;

  /// No description provided for @historyNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get historyNoActivity;

  /// Snackbar after approving an incoming request
  ///
  /// In en, this message translates to:
  /// **'Approved!'**
  String get historyApproved;

  /// Status badge
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get historyStatusApproved;

  /// No description provided for @historyStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get historyStatusRejected;

  /// No description provided for @historyStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get historyStatusPending;

  /// No description provided for @historyStatusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get historyStatusMissed;

  /// No description provided for @historyStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get historyStatusExpired;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailTitle;

  /// No description provided for @emailVerifyCustomSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent to {email}! Click the link to update your login email.'**
  String emailVerifyCustomSent(String email);

  /// No description provided for @emailVerifySent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent! Please check your inbox.'**
  String get emailVerifySent;

  /// No description provided for @emailNotVerifiedYet.
  ///
  /// In en, this message translates to:
  /// **'Email not verified yet. Please check your inbox and click the verification link.'**
  String get emailNotVerifiedYet;

  /// No description provided for @emailCheckYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get emailCheckYourEmail;

  /// No description provided for @emailVerifyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get emailVerifyYourEmail;

  /// No description provided for @emailSentBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to your email. Click the link to verify your email address.'**
  String get emailSentBody;

  /// No description provided for @emailWillSendBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a verification link to confirm your email address.'**
  String get emailWillSendBody;

  /// No description provided for @emailSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Email'**
  String get emailSendButton;

  /// No description provided for @emailIveVerified.
  ///
  /// In en, this message translates to:
  /// **'I\'ve Verified'**
  String get emailIveVerified;

  /// No description provided for @emailResend.
  ///
  /// In en, this message translates to:
  /// **'Resend Email'**
  String get emailResend;

  /// No description provided for @emailTips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get emailTips;

  /// No description provided for @emailTipsBody.
  ///
  /// In en, this message translates to:
  /// **'• Check your spam folder if you don\'t see the email\n• The verification link expires after 1 hour\n• You can resend the email if needed'**
  String get emailTipsBody;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone Number'**
  String get verifyPhoneTitle;

  /// No description provided for @phoneSmsTimeout.
  ///
  /// In en, this message translates to:
  /// **'SMS request timed out. The number might be already used, invalid, or blocked by the server.'**
  String get phoneSmsTimeout;

  /// No description provided for @phoneEnter6Digit.
  ///
  /// In en, this message translates to:
  /// **'Please enter 6-digit code'**
  String get phoneEnter6Digit;

  /// No description provided for @phoneVerifiedAuto.
  ///
  /// In en, this message translates to:
  /// **'Phone verified automatically!'**
  String get phoneVerifiedAuto;

  /// No description provided for @phoneEnterNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneEnterNumber;

  /// No description provided for @phoneWillSendSms.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a verification code via SMS'**
  String get phoneWillSendSms;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberLabel;

  /// No description provided for @phoneSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get phoneSendCode;

  /// No description provided for @phoneEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get phoneEnterCode;

  /// No description provided for @phoneSentCodeTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}'**
  String phoneSentCodeTo(String phone);

  /// No description provided for @phoneVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get phoneVerify;

  /// No description provided for @phoneDidntReceive.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? '**
  String get phoneDidntReceive;

  /// No description provided for @phoneResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String phoneResendIn(int seconds);

  /// No description provided for @phoneResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get phoneResendCode;

  /// No description provided for @phoneChangeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change phone number'**
  String get phoneChangeNumber;

  /// No description provided for @contextSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Card Contexts'**
  String get contextSettingsTitle;

  /// No description provided for @contextSettingsErrorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String contextSettingsErrorSaving(String error);

  /// No description provided for @contextSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Contexts saved successfully'**
  String get contextSettingsSaved;

  /// No description provided for @contextSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Customize what information to share in different contexts'**
  String get contextSettingsIntro;

  /// No description provided for @contextSettingsBusinessDesc.
  ///
  /// In en, this message translates to:
  /// **'Full professional information'**
  String get contextSettingsBusinessDesc;

  /// No description provided for @contextSettingsSocialDesc.
  ///
  /// In en, this message translates to:
  /// **'Personal contact without work details'**
  String get contextSettingsSocialDesc;

  /// No description provided for @contextSettingsLiteDesc.
  ///
  /// In en, this message translates to:
  /// **'Minimal information only'**
  String get contextSettingsLiteDesc;

  /// No description provided for @contextSettingsToggleName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contextSettingsToggleName;

  /// No description provided for @contextSettingsToggleEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contextSettingsToggleEmail;

  /// No description provided for @contextSettingsTogglePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contextSettingsTogglePhone;

  /// No description provided for @contextSettingsToggleJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get contextSettingsToggleJobTitle;

  /// No description provided for @contextSettingsToggleCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get contextSettingsToggleCompany;

  /// No description provided for @contextSettingsToggleAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get contextSettingsToggleAvatar;

  /// No description provided for @contextSettingsToggleCardFront.
  ///
  /// In en, this message translates to:
  /// **'Business Card Front'**
  String get contextSettingsToggleCardFront;

  /// No description provided for @contextSettingsToggleCardBack.
  ///
  /// In en, this message translates to:
  /// **'Business Card Back'**
  String get contextSettingsToggleCardBack;

  /// No description provided for @homeYourBusinessCard.
  ///
  /// In en, this message translates to:
  /// **'Your Business Card'**
  String get homeYourBusinessCard;

  /// Tagline kept in English across all locales (brand slogan)
  ///
  /// In en, this message translates to:
  /// **'Scan to exchange'**
  String get homeScanToExchange;

  /// No description provided for @homeShareMyInfo.
  ///
  /// In en, this message translates to:
  /// **'Share My Info'**
  String get homeShareMyInfo;

  /// No description provided for @manualCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust Area'**
  String get manualCropTitle;

  /// No description provided for @manualCropReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get manualCropReset;

  /// No description provided for @manualCropFailed.
  ///
  /// In en, this message translates to:
  /// **'Crop Failed'**
  String get manualCropFailed;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Contact'**
  String get reviewTitle;

  /// No description provided for @reviewSaved.
  ///
  /// In en, this message translates to:
  /// **'Contact saved!'**
  String get reviewSaved;

  /// No description provided for @reviewFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reviewFieldName;

  /// No description provided for @reviewFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get reviewFieldEmail;

  /// No description provided for @reviewFieldCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get reviewFieldCompany;

  /// No description provided for @reviewFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reviewFieldTitle;

  /// No description provided for @reviewFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get reviewFieldPhone;

  /// No description provided for @reviewFieldMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get reviewFieldMobile;

  /// No description provided for @reviewFieldFax.
  ///
  /// In en, this message translates to:
  /// **'Fax'**
  String get reviewFieldFax;

  /// No description provided for @reviewFieldWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get reviewFieldWebsite;

  /// No description provided for @reviewFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get reviewFieldAddress;

  /// No description provided for @reviewFieldTaxId.
  ///
  /// In en, this message translates to:
  /// **'VAT / Tax ID'**
  String get reviewFieldTaxId;

  /// No description provided for @landingStoreLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open store link'**
  String get landingStoreLinkFailed;

  /// Brand name kept in English
  ///
  /// In en, this message translates to:
  /// **'SecBizCard Invitation'**
  String get landingInvitationTitle;

  /// No description provided for @landingInvitationBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to connect via SecBizCard. To view this secure profile and exchange details, please use our mobile app.'**
  String get landingInvitationBody;

  /// No description provided for @landingDownloadApp.
  ///
  /// In en, this message translates to:
  /// **'Download App'**
  String get landingDownloadApp;

  /// No description provided for @landingContinueToApp.
  ///
  /// In en, this message translates to:
  /// **'Continue to App'**
  String get landingContinueToApp;

  /// No description provided for @landingHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'The New Standard for\nProfessional Identity.'**
  String get landingHeroTitle;

  /// No description provided for @landingHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure, instant, and verified contact exchange.\nPowered by the Cloud.'**
  String get landingHeroSubtitle;

  /// No description provided for @landingMockName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get landingMockName;

  /// No description provided for @landingMockTitle.
  ///
  /// In en, this message translates to:
  /// **'Chief Technology Officer'**
  String get landingMockTitle;

  /// 'QR' kept in English
  ///
  /// In en, this message translates to:
  /// **'QR Exchange'**
  String get landingFeatureQrTitle;

  /// No description provided for @landingFeatureQrDesc.
  ///
  /// In en, this message translates to:
  /// **'Simply show your dynamic QR code to share your business card instantly.'**
  String get landingFeatureQrDesc;

  /// No description provided for @landingFeaturePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy First'**
  String get landingFeaturePrivacyTitle;

  /// No description provided for @landingFeaturePrivacyDesc.
  ///
  /// In en, this message translates to:
  /// **'Your data lives in your own Google Drive. No centralized data harvesting.'**
  String get landingFeaturePrivacyDesc;

  /// No description provided for @landingFeatureOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Works Offline'**
  String get landingFeatureOfflineTitle;

  /// No description provided for @landingFeatureOfflineDesc.
  ///
  /// In en, this message translates to:
  /// **'Access and share your card even without an internet connection.'**
  String get landingFeatureOfflineDesc;

  /// No description provided for @landingFeatureVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified Identity'**
  String get landingFeatureVerifiedTitle;

  /// No description provided for @landingFeatureVerifiedDesc.
  ///
  /// In en, this message translates to:
  /// **'Build trust with email and phone verification signals on your profile.'**
  String get landingFeatureVerifiedDesc;

  /// No description provided for @landingDownloadHeadline.
  ///
  /// In en, this message translates to:
  /// **'Experience Secure & Fast\nBusiness Card Exchange'**
  String get landingDownloadHeadline;

  /// No description provided for @landingCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} SecBizCard. All rights reserved.'**
  String landingCopyright(int year);

  /// No description provided for @landingPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get landingPrivacyPolicy;

  /// Legal acronym kept in English
  ///
  /// In en, this message translates to:
  /// **'EULA'**
  String get landingEula;
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
