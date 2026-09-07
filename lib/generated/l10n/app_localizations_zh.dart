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

  @override
  String get ocrRecognizingCloudVision => '使用 Cloud Vision 辨识中…';

  @override
  String get ocrRecognizingOnDevice => '使用设备端辨识中…';

  @override
  String get ocrSourceCloudVisionOwn => 'Cloud Vision · 你的密钥';

  @override
  String ocrSourceCloudVisionShared(int used, int cap) {
    return 'Cloud Vision · 本月 $used/$cap';
  }

  @override
  String get ocrSourceOnDevice => '设备端辨识';

  @override
  String get aiRecognitionTitle => 'AI 辨识';

  @override
  String get ocrUsingOwnKey => '使用你的 Cloud Vision 密钥';

  @override
  String get ocrUsingOwnKeyDesc => '最佳质量，费用计入你自己的 Google Cloud 账号。';

  @override
  String get ocrUsingSharedQuota => '使用共享额度';

  @override
  String ocrUsingSharedQuotaDesc(int perUser) {
    return '每月最多 $perUser 次免费 AI 辨识，用完后自动改用快速的设备端辨识。在下方加入自己的密钥即可享有无限次最佳质量辨识。';
  }

  @override
  String ocrUsageThisMonth(int used, int cap) {
    return '本月：$used / $cap';
  }

  @override
  String get ocrOwnKeyNearLimitWarn =>
      '你已使用超过每月免费额度的 80%，本月后续辨识可能会对你的 Google Cloud 账号产生费用。';

  @override
  String get ocrUseOwnKeyHeading => '使用你自己的 API 密钥';

  @override
  String get ocrUpdateOwnKeyHeading => '更新你的 API 密钥';

  @override
  String get ocrKeyHint => '粘贴你的 Cloud Vision API 密钥';

  @override
  String get ocrKeySaved => '密钥已安全保存在此设备。';

  @override
  String get ocrKeyRemoved => '已从此设备移除密钥。';

  @override
  String get ocrKeyMasked => '此设备已保存一组密钥。';

  @override
  String get save => '保存';

  @override
  String get update => '更新';

  @override
  String get remove => '移除';

  @override
  String get cancel => '取消';

  @override
  String get ocrReplaceKeyTitle => '替换已保存的密钥？';

  @override
  String get ocrReplaceKeyBody => '这将覆盖当前保存在此设备的 API 密钥。';

  @override
  String get ocrRemoveKeyTitle => '移除已保存的密钥？';

  @override
  String get ocrRemoveKeyBody => '此设备将改回使用共享的每月额度。你随时可以再次加入密钥。';

  @override
  String get ocrHowToTitle => '如何获取 Cloud Vision API 密钥';

  @override
  String get ocrHowTo1 => '1. 前往 Google Cloud Console，创建（或选择）一个项目。';

  @override
  String get ocrHowTo2 => '2. 为该项目启用「Cloud Vision API」。';

  @override
  String get ocrHowTo3 => '3. 在「API 与服务 → 凭据」中创建 API 密钥。';

  @override
  String get ocrHowTo4 => '4. 复制密钥并粘贴到上方。';

  @override
  String get ocrOpenConsole => '打开 Google Cloud Console';

  @override
  String get ocrSafetyTitle => '你的密钥只留在你的设备上';

  @override
  String get ocrSafety1 =>
      '• 密钥只保存在此设备的安全钥匙串（Keychain）中，绝不会上传到我们的服务器、不会同步、也不会离开你的手机。';

  @override
  String get ocrSafety2 =>
      '• App 会用你的密钥把名片图像直接发送到 Google Cloud Vision，因此辨识费用计入你自己的账号。';

  @override
  String get ocrSafety3 =>
      '• 建议在 Google Cloud 将此密钥限制为仅能使用 Cloud Vision API，并设定预算／配额上限以控制花费。';

  @override
  String get ocrSafety4 => '• 万一密钥外泄，请到 Cloud Console 删除它，再在此处粘贴新的密钥。';

  @override
  String ocrSharedKeyUsage(int used, int cap) {
    return 'Cloud Vision · 共享密钥本月 $used/$cap';
  }

  @override
  String get scanCardHint => '将名片放入框内';

  @override
  String get scanCardBackgroundTip => '请放在单色、无花纹的背景上';
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

  @override
  String get ocrRecognizingCloudVision => '使用 Cloud Vision 辨識中…';

  @override
  String get ocrRecognizingOnDevice => '使用裝置端辨識中…';

  @override
  String get ocrSourceCloudVisionOwn => 'Cloud Vision · 你的金鑰';

  @override
  String ocrSourceCloudVisionShared(int used, int cap) {
    return 'Cloud Vision · 本月 $used/$cap';
  }

  @override
  String get ocrSourceOnDevice => '裝置端辨識';

  @override
  String get aiRecognitionTitle => 'AI 辨識';

  @override
  String get ocrUsingOwnKey => '使用你的 Cloud Vision 金鑰';

  @override
  String get ocrUsingOwnKeyDesc => '最佳品質，費用計入你自己的 Google Cloud 帳號。';

  @override
  String get ocrUsingSharedQuota => '使用共用額度';

  @override
  String ocrUsingSharedQuotaDesc(int perUser) {
    return '每月最多 $perUser 次免費 AI 辨識，用完後自動改用快速的裝置端辨識。在下方加入自己的金鑰即可享有無限次最佳品質辨識。';
  }

  @override
  String ocrUsageThisMonth(int used, int cap) {
    return '本月：$used / $cap';
  }

  @override
  String get ocrOwnKeyNearLimitWarn =>
      '你已使用超過每月免費額度的 80%，本月後續辨識可能會對你的 Google Cloud 帳號產生費用。';

  @override
  String get ocrUseOwnKeyHeading => '使用你自己的 API 金鑰';

  @override
  String get ocrUpdateOwnKeyHeading => '更新你的 API 金鑰';

  @override
  String get ocrKeyHint => '貼上你的 Cloud Vision API 金鑰';

  @override
  String get ocrKeySaved => '金鑰已安全儲存在此裝置。';

  @override
  String get ocrKeyRemoved => '已從此裝置移除金鑰。';

  @override
  String get ocrKeyMasked => '此裝置已儲存一組金鑰。';

  @override
  String get save => '儲存';

  @override
  String get update => '更新';

  @override
  String get remove => '移除';

  @override
  String get cancel => '取消';

  @override
  String get ocrReplaceKeyTitle => '取代已儲存的金鑰？';

  @override
  String get ocrReplaceKeyBody => '這會覆蓋目前儲存在此裝置的 API 金鑰。';

  @override
  String get ocrRemoveKeyTitle => '移除已儲存的金鑰？';

  @override
  String get ocrRemoveKeyBody => '此裝置將改回使用共用的每月額度。你隨時可以再次加入金鑰。';

  @override
  String get ocrHowToTitle => '如何取得 Cloud Vision API 金鑰';

  @override
  String get ocrHowTo1 => '1. 前往 Google Cloud Console，建立（或選擇）一個專案。';

  @override
  String get ocrHowTo2 => '2. 為該專案啟用「Cloud Vision API」。';

  @override
  String get ocrHowTo3 => '3. 在「API 與服務 → 憑證」中建立 API 金鑰。';

  @override
  String get ocrHowTo4 => '4. 複製金鑰並貼到上方。';

  @override
  String get ocrOpenConsole => '開啟 Google Cloud Console';

  @override
  String get ocrSafetyTitle => '你的金鑰只留在你的裝置上';

  @override
  String get ocrSafety1 =>
      '• 金鑰只儲存在此裝置的安全金鑰鏈（Keychain）中，絕不會上傳到我們的伺服器、不會同步、也不會離開你的手機。';

  @override
  String get ocrSafety2 =>
      '• App 會用你的金鑰把名片影像直接送到 Google Cloud Vision，因此辨識費用計入你自己的帳號。';

  @override
  String get ocrSafety3 =>
      '• 建議在 Google Cloud 將此金鑰限制為僅能使用 Cloud Vision API，並設定預算／配額上限以控制花費。';

  @override
  String get ocrSafety4 => '• 萬一金鑰外洩，請到 Cloud Console 刪除它，再於此處貼上新的金鑰。';

  @override
  String ocrSharedKeyUsage(int used, int cap) {
    return 'Cloud Vision · 共用金鑰本月 $used/$cap';
  }

  @override
  String get scanCardHint => '將名片放入框內';

  @override
  String get scanCardBackgroundTip => '請放在單色、無花紋的背景上';
}
