// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'SecBizCard';

  @override
  String get loginSlogan => '安全、專業、即時';

  @override
  String get signInWithGoogle => '使用 Google 登入';

  @override
  String get signInWithApple => '使用 Apple 登入';

  @override
  String orSignInWith(String provider) {
    return '或使用 $provider 登入';
  }

  @override
  String get profileTitle => '個人檔案';

  @override
  String get editProfile => '編輯檔案';

  @override
  String get onboardingWelcome => '歡迎使用 SecBizCard';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'SecBizCard';

  @override
  String get loginSlogan => '安全、專業、即時';

  @override
  String get signInWithGoogle => '使用 Google 登入';

  @override
  String get signInWithApple => '使用 Apple 登入';

  @override
  String orSignInWith(String provider) {
    return '或使用 $provider 登入';
  }

  @override
  String get profileTitle => '個人檔案';

  @override
  String get editProfile => '編輯檔案';

  @override
  String get onboardingWelcome => '歡迎使用 SecBizCard';
}
