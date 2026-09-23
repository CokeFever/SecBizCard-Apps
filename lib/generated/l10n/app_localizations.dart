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
