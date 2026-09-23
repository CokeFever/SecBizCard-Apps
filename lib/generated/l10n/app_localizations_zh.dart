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
    return '本月 $used/$cap';
  }

  @override
  String get ocrUsageByok => 'BYOK';

  @override
  String ocrTierBadge(String tier, String usage) {
    return '$tier · $usage';
  }

  @override
  String get ocrUsageUnknown => '无法获取用量';

  @override
  String get ocrYourPlan => '你的方案';

  @override
  String get ocrSubscribe => '订阅';

  @override
  String get ocrUpgradeToPro => '升级到 Pro';

  @override
  String get ocrSubscribeComingSoon => '订阅功能即将推出。';

  @override
  String get ocrAdminObservability => '管理者 · 共享密钥用量';

  @override
  String get ocrAdminShared800 => '免费额度池（Basic）';

  @override
  String get ocrAdminTotal => 'CV 总调用次数';

  @override
  String get ocrKeyFormatHint => 'Google Cloud API 密钥以「AIza」开头,长度为 39 个字符。';

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
  String get unsavedChangesTitle => '尚未保存的更改';

  @override
  String get unsavedChangesBody => '你有尚未保存的更改。确定要放弃并离开吗?';

  @override
  String get unsavedChangesStay => '留下';

  @override
  String get unsavedChangesDiscard => '放弃';

  @override
  String get drawerNotLoggedIn => '尚未登录';

  @override
  String get drawerDefaultUser => '用户';

  @override
  String get drawerMyProfile => '我的个人资料';

  @override
  String get drawerManageContexts => '管理情境';

  @override
  String get drawerErrorLoadingProfile => '加载个人资料时出错';

  @override
  String get drawerBackupRestore => '备份与恢复';

  @override
  String get drawerAiRecognition => 'AI 识别';

  @override
  String get drawerImportVcard => '导入 vCard';

  @override
  String get drawerAppearance => '外观';

  @override
  String get drawerThemeAuto => '自动';

  @override
  String get drawerThemeLight => '浅色';

  @override
  String get drawerThemeDark => '深色';

  @override
  String get drawerLogout => '登出';

  @override
  String get drawerConfirmLogoutTitle => '确认登出';

  @override
  String get drawerConfirmLogoutBody => '确定要登出吗?';

  @override
  String get commonCancel => '取消';

  @override
  String get drawerLinkPrivacy => '隐私权';

  @override
  String get drawerLinkTerms => '条款';

  @override
  String get drawerLinkGuide => '指南';

  @override
  String loginSignInError(String error) {
    return '登录错误:$error';
  }

  @override
  String contactsNoneFoundFor(String query) {
    return '找不到符合「$query」的联系人';
  }

  @override
  String get contactsNoneYet => '尚无联系人';

  @override
  String get contactsEmptyHint => '交换或扫描的名片会显示在这里';

  @override
  String contactsDeleteFailed(String error) {
    return '删除失败:$error';
  }

  @override
  String get contactsDeleted => '已删除联系人';

  @override
  String get contactsDelete => '删除';

  @override
  String get contactsSearchHint => '搜索联系人…';

  @override
  String commonErrorWithDetail(String error) {
    return '错误:$error';
  }

  @override
  String get onboardingSetupProfile => '设置个人资料';

  @override
  String get onboardingGetStarted => '快速开始';

  @override
  String get onboardingImportDesc => '从你的 Google 联系人名片导入个人资料,省去手动输入。';

  @override
  String get onboardingImportFromGoogle => '从 Google 导入';

  @override
  String get onboardingEnterManually => '手动输入';

  @override
  String get onboardingReviewInfo => '查看你的信息';

  @override
  String get onboardingMasterProfileDesc => '这些信息会成为你的「主要个人资料」。你可以稍后选择要分享哪些内容。';

  @override
  String get onboardingRecoveryTip => '提示:建议使用你的个人电话与 Gmail,以便账号恢复与可信验证。';

  @override
  String get onboardingFieldName => '全名(必填)';

  @override
  String get onboardingFieldPhone => '电话(选填)';

  @override
  String get onboardingFieldEmail => '电子邮件(选填)';

  @override
  String get onboardingFieldTitle => '职称';

  @override
  String get onboardingFieldCompany => '公司';

  @override
  String get onboardingNameRequired => '姓名为必填';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingSmartContexts => '智能情境';

  @override
  String get onboardingContextsDesc => '我们已为你设置 3 个默认情境。你可以随时在设置中自定义。';

  @override
  String get onboardingContextWorkShares => '分享:姓名、职称、公司、电话、电子邮件';

  @override
  String get onboardingContextPersonalShares => '分享:姓名、个人电子邮件、头像';

  @override
  String get onboardingContextQuickShares => '分享:仅姓名';

  @override
  String get onboardingLooksGood => '看起来不错';

  @override
  String get onboardingAllSet => '一切就绪!';

  @override
  String get onboardingReadyDesc => '你的数字名片已准备好可以分享。';

  @override
  String get onboardingStartUsing => '开始使用 SecBizCard';

  @override
  String get profileNotFound => '找不到个人资料';

  @override
  String get profileEdit => '编辑个人资料';

  @override
  String get profileDeleteAccount => '删除账号';

  @override
  String get profileContinueToDelete => '继续删除';

  @override
  String get profileAreYouSure => '你确定吗?';

  @override
  String get profileDeleteLastChance => '这是你最后的机会。你的账号、个人资料与所有联系人将被永久删除。';

  @override
  String get profileDeleteForever => '永久删除';

  @override
  String commonFailedWithDetail(String error) {
    return '失败:$error';
  }

  @override
  String get qrGenerating => '生成安全的 QRCode 中…';

  @override
  String get qrBatchApproval => '批量批准';

  @override
  String get qrBatchApprovalOn => '自动批准所有请求';

  @override
  String get qrBatchApprovalOff => '逐一手动批准请求';

  @override
  String qrResetsIn(String time) {
    return '$time 后重置';
  }

  @override
  String qrRefreshAvailableIn(int seconds) {
    return '$seconds 秒后可用';
  }

  @override
  String get qrRefreshTooltip => '重新生成 QRCode';

  @override
  String get qrUrlCopied => '已复制网址到剪贴板';

  @override
  String get qrCopyUrl => '复制网址';

  @override
  String get qrRetry => '重试';

  @override
  String get qrErrorSignInRequired => '你必须先登录才能分享信息。';

  @override
  String qrErrorPrefix(String message) {
    return '错误:$message';
  }

  @override
  String get qrErrorNotAuthenticated => '尚未验证身份';

  @override
  String get qrErrorCompleteProfile => '请先完成你的个人资料';

  @override
  String get qrCannotShare => '无法分享';

  @override
  String get commonOk => '确定';

  @override
  String get qrInfoSharedBack => '对方也分享了信息!';

  @override
  String qrAlsoSharedInfo(String name) {
    return '$name 也分享了他们的信息。';
  }

  @override
  String get qrSaveToContacts => '保存到联系人';

  @override
  String get commonClose => '关闭';

  @override
  String get qrContactSaved => '已保存联系人!';

  @override
  String qrSavedToContacts(String name) {
    return '已将 $name 保存到联系人';
  }

  @override
  String get qrInfoSharedSuccess => '信息分享成功!';

  @override
  String get ocrKeyLockedNote => '已启用你自己的密钥。若要更换，请先移除再新增。';

  @override
  String get ocrRemoveKeyAction => '移除密钥';

  @override
  String get ocrPaywallTitle => '升级云端识别';

  @override
  String get ocrPaywallSubtitle => '更快、更准的名片识别，免设置密钥。';

  @override
  String get ocrPlanPlusPrice => 'US\$0.99/月';

  @override
  String get ocrPlanPlusDesc => '每月 20 次云端识别';

  @override
  String get ocrPlanProPrice => 'US\$4.99/月';

  @override
  String get ocrPlanProDesc => '每月 100 次云端识别';

  @override
  String get ocrRestorePurchases => '恢复购买';

  @override
  String get ocrSubscribeThanks => '感谢订阅！';

  @override
  String get ocrRestoreDone => '购买已恢复。';

  @override
  String get ocrSubscribeFailed => '发生错误，请再试一次。';

  @override
  String get scanCardHint => '将名片放入框内';

  @override
  String get scanCardBackgroundTip => '请放在单色、无花纹的背景上';

  @override
  String get ocrFeedbackPromptTitle => '识别结果不理想吗？';

  @override
  String get ocrFeedbackPromptBody => '如果这张名片识别得不好，你可以协助我们改善。我们会退还你本月的一次扫描次数。';

  @override
  String get ocrFeedbackReport => '协助改善';

  @override
  String get ocrFeedbackDismiss => '不用了';

  @override
  String get ocrFeedbackDontAsk24h => '24 小时内不再询问';

  @override
  String get ocrFeedbackConsentTitle => '协助我们改善识别';

  @override
  String get ocrFeedbackConsentSummary =>
      '发送这张名片的识别数据以协助改善。仅用于改善识别，分析后即删除，且一律于 30 天内删除。';

  @override
  String get ocrFeedbackConsentIncludePhoto => '附上名片照片（有助我们修正识别，取消勾选可略过）';

  @override
  String get ocrFeedbackViewTerms => '查看完整条款';

  @override
  String get ocrFeedbackTermsBody =>
      '数据控管者：SecBizCard 为你发送之反馈的数据控管者。联系邮箱：privacy@ixo.app。\n\n收集内容：名片的识别文字与版面数据、识别结果，以及名片照片——因为要重现并修正识别错误，照片是必要的。发送一律为可选，且每次都会询问。\n\n用途：仅用于重现并改善识别准确度。我们不作其他用途，也不会出售或为广告目的分享。\n\n数据会经过哪些对象：为处理你的反馈，我们会委由代为处理的服务供应商——Google Cloud Vision 与 Firebase（Google）进行识别与存储。这些数据可能在你所在国家以外处理；对欧盟用户，在必要时我们采用标准合同条款（SCC）。除此之外我们不会与任何其他人分享。\n\n法律依据：我们改善识别质量的正当利益，以及你对本次发送的同意。由于名片包含他人的个人数据，你确认你有合理依据为此用途分享该数据。\n\n保留期限：我们在完成分析后即删除你发送的数据，且一律于 30 天内删除。数据在传输与存储过程中均经加密。\n\n你的权利：你可通过 privacy@ixo.app 要求访问或删除你发送的反馈，或提出疑虑。完整说明请见我们的隐私政策。';

  @override
  String get ocrFeedbackSubmit => '同意并发送';

  @override
  String get ocrFeedbackCancel => '取消';

  @override
  String get ocrFeedbackThanks => '感谢！你的反馈有助于改善识别。';

  @override
  String get ocrFeedbackThanksRefunded => '感谢！我们已退还你一次扫描次数。';

  @override
  String get ocrFeedbackLimitReached => '你已达本月反馈上限。感谢你的协助！';

  @override
  String get ocrFeedbackFailed => '反馈发送失败，请稍后再试。';

  @override
  String get editProfileTitle => '编辑个人资料';

  @override
  String get editProfilePhoneResetWarn => '⚠️ 已修改已验证的电话，保存后验证将被重置。';

  @override
  String get editProfileReverifyHint => '⚠️ 修改此项后需要重新验证';

  @override
  String get editProfileEditPhoto => '编辑照片';

  @override
  String get editProfileChooseImageSource => '选择图片来源';

  @override
  String get editProfileGallery => '相册';

  @override
  String get editProfileCamera => '相机';

  @override
  String get editProfileVerificationResetTitle => '验证将被重置';

  @override
  String get editProfileVerificationResetBody =>
      '您正在更改已验证的电话号码，这会重置验证状态，您需要重新验证新的号码。';

  @override
  String get editProfileContinue => '继续';

  @override
  String get editProfileFullName => '姓名';

  @override
  String get editProfileNameRequired => '姓名为必填';

  @override
  String get editProfileJobTitle => '职务';

  @override
  String get editProfileCompany => '公司';

  @override
  String get editProfilePhone => '电话';

  @override
  String get editProfileAdditionalInfo => '其他信息';

  @override
  String get editProfileAddField => '添加字段';

  @override
  String get editProfileTapToChangePhoto => '点击以更换照片';

  @override
  String get editProfileBusinessCards => '名片';

  @override
  String get editProfileFrontSide => '正面';

  @override
  String get editProfileBackSide => '背面';

  @override
  String editProfileUpload(String label) {
    return '上传$label';
  }

  @override
  String get editProfileFieldTypeLabel => '类型';

  @override
  String get editProfileFieldLabelLabel => '标签';

  @override
  String get editProfileAdd => '添加';

  @override
  String get handshakeTitle => '交换信息';

  @override
  String handshakeSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get handshakeShareBackTitle => '回传您的信息？';

  @override
  String get handshakeShareBackBody => '您要将自己的联系信息回传给对方吗？';

  @override
  String get handshakeNo => '否';

  @override
  String get handshakeYes => '是';

  @override
  String handshakeShareFailed(String error) {
    return '分享失败：$error';
  }

  @override
  String get handshakeInvalidLink => '链接无效或已过期';

  @override
  String handshakeParseError(String error) {
    return '解析数据时出错：$error';
  }

  @override
  String get handshakeFoundLink => '已找到安全链接';

  @override
  String get handshakeRequestPrompt => '要请求交换信息吗？';

  @override
  String get handshakeAbort => '中止';

  @override
  String get handshakeSendRequest => '发送请求';

  @override
  String get handshakeRequestSent => '请求已发送！';

  @override
  String get handshakeWaitingApproval => '等待对方批准…';

  @override
  String get handshakeRequestDeclined => '请求已被拒绝';

  @override
  String get handshakeSessionExpired => '会话已过期';

  @override
  String get handshakeInfoReceived => '已收到信息！';

  @override
  String get handshakeSelectContext => '选择要分享的情境';

  @override
  String get handshakeContextBusiness => '商务';

  @override
  String get handshakeContextSocial => '社交';

  @override
  String get handshakeContextLite => '精简';

  @override
  String get handshakeShare => '分享';

  @override
  String get incomingExpired => '已过期';

  @override
  String get incomingUnknownUser => '未知用户';

  @override
  String get incomingTitle => '收到请求';

  @override
  String incomingWantsToExchange(String name) {
    return '$name 想与您交换联系信息。';
  }

  @override
  String get incomingAddToContacts => '加入我的联系人';

  @override
  String get incomingChooseInfo => '选择要分享的信息：';

  @override
  String get incomingDecline => '拒绝';

  @override
  String get incomingApprove => '批准';

  @override
  String get scannerInvalidQr => 'QR code 无效';

  @override
  String get scannerInvalidQrFormat => 'QR code 格式无效。应为：https://ixo.app/<id>';

  @override
  String get scannerTitle => '扫描 QR code';

  @override
  String get scannerPlaceInFrame => '将 QR code 对准框内';

  @override
  String get scannerPermissionTitle => '需要相机权限';

  @override
  String get scannerPermissionBody => '此功能需要相机访问权限，以扫描 QR code 进行安全交换。';

  @override
  String get scannerOpenSettings => '打开设置';

  @override
  String get scannerGrantPermission => '授予权限';

  @override
  String get editContactTitle => '编辑联系人';

  @override
  String get editContactUpdated => '联系人已更新';

  @override
  String get editContactBasicInfo => '基本信息';

  @override
  String get editContactDisplayName => '显示名称';

  @override
  String get editContactNickname => '昵称（仅您可见）';

  @override
  String get editContactJobInfo => '工作信息';

  @override
  String get editContactContact => '联系方式';

  @override
  String get editContactEmail => '电子邮件';

  @override
  String get editContactOriginalScan => '原始扫描';

  @override
  String editContactFieldRequired(String label) {
    return '$label 为必填';
  }
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
    return '本月 $used/$cap';
  }

  @override
  String get ocrUsageByok => 'BYOK';

  @override
  String ocrTierBadge(String tier, String usage) {
    return '$tier · $usage';
  }

  @override
  String get ocrUsageUnknown => '無法取得用量';

  @override
  String get ocrYourPlan => '你的方案';

  @override
  String get ocrSubscribe => '訂閱';

  @override
  String get ocrUpgradeToPro => '升級到 Pro';

  @override
  String get ocrSubscribeComingSoon => '訂閱功能即將推出。';

  @override
  String get ocrAdminObservability => '管理者 · 共用金鑰用量';

  @override
  String get ocrAdminShared800 => '免費額度池（Basic）';

  @override
  String get ocrAdminTotal => 'CV 總呼叫次數';

  @override
  String get ocrKeyFormatHint => 'Google Cloud API 金鑰以「AIza」開頭,長度為 39 個字元。';

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
  String get unsavedChangesTitle => '尚未儲存的變更';

  @override
  String get unsavedChangesBody => '你有尚未儲存的變更。確定要捨棄並離開嗎?';

  @override
  String get unsavedChangesStay => '留下';

  @override
  String get unsavedChangesDiscard => '捨棄';

  @override
  String get drawerNotLoggedIn => '尚未登入';

  @override
  String get drawerDefaultUser => '使用者';

  @override
  String get drawerMyProfile => '我的個人資料';

  @override
  String get drawerManageContexts => '管理情境';

  @override
  String get drawerErrorLoadingProfile => '載入個人資料時發生錯誤';

  @override
  String get drawerBackupRestore => '備份與還原';

  @override
  String get drawerAiRecognition => 'AI 辨識';

  @override
  String get drawerImportVcard => '匯入 vCard';

  @override
  String get drawerAppearance => '外觀';

  @override
  String get drawerThemeAuto => '自動';

  @override
  String get drawerThemeLight => '淺色';

  @override
  String get drawerThemeDark => '深色';

  @override
  String get drawerLogout => '登出';

  @override
  String get drawerConfirmLogoutTitle => '確認登出';

  @override
  String get drawerConfirmLogoutBody => '確定要登出嗎?';

  @override
  String get commonCancel => '取消';

  @override
  String get drawerLinkPrivacy => '隱私權';

  @override
  String get drawerLinkTerms => '條款';

  @override
  String get drawerLinkGuide => '指南';

  @override
  String loginSignInError(String error) {
    return '登入錯誤:$error';
  }

  @override
  String contactsNoneFoundFor(String query) {
    return '找不到符合「$query」的聯絡人';
  }

  @override
  String get contactsNoneYet => '尚無聯絡人';

  @override
  String get contactsEmptyHint => '交換或掃描的名片會顯示在這裡';

  @override
  String contactsDeleteFailed(String error) {
    return '刪除失敗:$error';
  }

  @override
  String get contactsDeleted => '已刪除聯絡人';

  @override
  String get contactsDelete => '刪除';

  @override
  String get contactsSearchHint => '搜尋聯絡人…';

  @override
  String commonErrorWithDetail(String error) {
    return '錯誤:$error';
  }

  @override
  String get onboardingSetupProfile => '設定個人資料';

  @override
  String get onboardingGetStarted => '快速開始';

  @override
  String get onboardingImportDesc => '從你的 Google 聯絡人名片匯入個人資料,省去手動輸入。';

  @override
  String get onboardingImportFromGoogle => '從 Google 匯入';

  @override
  String get onboardingEnterManually => '手動輸入';

  @override
  String get onboardingReviewInfo => '檢視你的資訊';

  @override
  String get onboardingMasterProfileDesc => '這些資訊會成為你的「主要個人資料」。你可以稍後選擇要分享哪些內容。';

  @override
  String get onboardingRecoveryTip => '提示:建議使用你的個人電話與 Gmail,以利帳號復原與可信驗證。';

  @override
  String get onboardingFieldName => '全名(必填)';

  @override
  String get onboardingFieldPhone => '電話(選填)';

  @override
  String get onboardingFieldEmail => '電子郵件(選填)';

  @override
  String get onboardingFieldTitle => '職稱';

  @override
  String get onboardingFieldCompany => '公司';

  @override
  String get onboardingNameRequired => '姓名為必填';

  @override
  String get onboardingContinue => '繼續';

  @override
  String get onboardingSmartContexts => '智慧情境';

  @override
  String get onboardingContextsDesc => '我們已為你設定 3 個預設情境。你可以隨時在設定中自訂。';

  @override
  String get onboardingContextWorkShares => '分享:姓名、職稱、公司、電話、電子郵件';

  @override
  String get onboardingContextPersonalShares => '分享:姓名、個人電子郵件、頭像';

  @override
  String get onboardingContextQuickShares => '分享:僅姓名';

  @override
  String get onboardingLooksGood => '看起來不錯';

  @override
  String get onboardingAllSet => '一切就緒!';

  @override
  String get onboardingReadyDesc => '你的數位名片已準備好可以分享。';

  @override
  String get onboardingStartUsing => '開始使用 SecBizCard';

  @override
  String get profileNotFound => '找不到個人資料';

  @override
  String get profileEdit => '編輯個人資料';

  @override
  String get profileDeleteAccount => '刪除帳號';

  @override
  String get profileContinueToDelete => '繼續刪除';

  @override
  String get profileAreYouSure => '你確定嗎?';

  @override
  String get profileDeleteLastChance => '這是你最後的機會。你的帳號、個人資料與所有聯絡人將被永久刪除。';

  @override
  String get profileDeleteForever => '永久刪除';

  @override
  String commonFailedWithDetail(String error) {
    return '失敗:$error';
  }

  @override
  String get qrGenerating => '產生安全的 QRCode 中…';

  @override
  String get qrBatchApproval => '批次核准';

  @override
  String get qrBatchApprovalOn => '自動核准所有請求';

  @override
  String get qrBatchApprovalOff => '逐一手動核准請求';

  @override
  String qrResetsIn(String time) {
    return '$time 後重設';
  }

  @override
  String qrRefreshAvailableIn(int seconds) {
    return '$seconds 秒後可用';
  }

  @override
  String get qrRefreshTooltip => '重新產生 QRCode';

  @override
  String get qrUrlCopied => '已複製網址到剪貼簿';

  @override
  String get qrCopyUrl => '複製網址';

  @override
  String get qrRetry => '重試';

  @override
  String get qrErrorSignInRequired => '你必須先登入才能分享資訊。';

  @override
  String qrErrorPrefix(String message) {
    return '錯誤:$message';
  }

  @override
  String get qrErrorNotAuthenticated => '尚未驗證身分';

  @override
  String get qrErrorCompleteProfile => '請先完成你的個人資料';

  @override
  String get qrCannotShare => '無法分享';

  @override
  String get commonOk => '確定';

  @override
  String get qrInfoSharedBack => '對方也分享了資訊!';

  @override
  String qrAlsoSharedInfo(String name) {
    return '$name 也分享了他們的資訊。';
  }

  @override
  String get qrSaveToContacts => '儲存到聯絡人';

  @override
  String get commonClose => '關閉';

  @override
  String get qrContactSaved => '已儲存聯絡人!';

  @override
  String qrSavedToContacts(String name) {
    return '已將 $name 儲存到聯絡人';
  }

  @override
  String get qrInfoSharedSuccess => '資訊分享成功!';

  @override
  String get ocrKeyLockedNote => '已啟用你自己的金鑰。若要更換，請先移除再新增。';

  @override
  String get ocrRemoveKeyAction => '移除金鑰';

  @override
  String get ocrPaywallTitle => '升級雲端辨識';

  @override
  String get ocrPaywallSubtitle => '更快、更準的名片辨識，免設定金鑰。';

  @override
  String get ocrPlanPlusPrice => 'US\$0.99/月';

  @override
  String get ocrPlanPlusDesc => '每月 20 次雲端辨識';

  @override
  String get ocrPlanProPrice => 'US\$4.99/月';

  @override
  String get ocrPlanProDesc => '每月 100 次雲端辨識';

  @override
  String get ocrRestorePurchases => '還原購買';

  @override
  String get ocrSubscribeThanks => '感謝訂閱！';

  @override
  String get ocrRestoreDone => '購買已還原。';

  @override
  String get ocrSubscribeFailed => '發生錯誤，請再試一次。';

  @override
  String get scanCardHint => '將名片放入框內';

  @override
  String get scanCardBackgroundTip => '請放在單色、無花紋的背景上';

  @override
  String get ocrFeedbackPromptTitle => '辨識結果不理想嗎？';

  @override
  String get ocrFeedbackPromptBody => '如果這張名片辨識得不好，你可以協助我們改善。我們會退還你本月的一次掃描次數。';

  @override
  String get ocrFeedbackReport => '協助改善';

  @override
  String get ocrFeedbackDismiss => '不用了';

  @override
  String get ocrFeedbackDontAsk24h => '24 小時內不再詢問';

  @override
  String get ocrFeedbackConsentTitle => '協助我們改善辨識';

  @override
  String get ocrFeedbackConsentSummary =>
      '送出這張名片的辨識資料以協助改善。僅用於改善辨識，分析後即刪除，且一律於 30 天內刪除。';

  @override
  String get ocrFeedbackConsentIncludePhoto => '附上名片照片（有助我們修正辨識，取消勾選可略過）';

  @override
  String get ocrFeedbackViewTerms => '查看完整條款';

  @override
  String get ocrFeedbackTermsBody =>
      '資料控管者：SecBizCard 為你送出之回饋的資料控管者。聯絡信箱：privacy@ixo.app。\n\n收集內容：名片的辨識文字與版面資料、辨識結果，以及名片照片——因為要重現並修正辨識錯誤，照片是必要的。送出一律為選擇性，且每次都會詢問。\n\n用途：僅用於重現並改善辨識準確度。我們不作其他用途，也不會出售或為廣告目的分享。\n\n資料會經過哪些對象：為處理你的回饋，我們會委由代為處理的服務供應商——Google Cloud Vision 與 Firebase（Google）進行辨識與儲存。這些資料可能於你所在國家以外處理；對歐盟使用者，於必要時我們採用標準契約條款（SCC）。除此之外我們不會與任何其他人分享。\n\n法律依據：我們改善辨識品質的正當利益，以及你對本次送出的同意。由於名片包含他人的個人資料，你確認你有合理依據為此用途分享該資料。\n\n保留期限：我們在完成分析後即刪除你送出的資料，且一律於 30 天內刪除。資料在傳輸與儲存過程中均經加密。\n\n你的權利：你可透過 privacy@ixo.app 要求存取或刪除你送出的回饋，或提出疑慮。完整說明請見我們的隱私權政策。';

  @override
  String get ocrFeedbackSubmit => '同意並送出';

  @override
  String get ocrFeedbackCancel => '取消';

  @override
  String get ocrFeedbackThanks => '感謝！你的回饋有助於改善辨識。';

  @override
  String get ocrFeedbackThanksRefunded => '感謝！我們已退還你一次掃描次數。';

  @override
  String get ocrFeedbackLimitReached => '你已達本月回饋上限。感謝你的協助！';

  @override
  String get ocrFeedbackFailed => '回饋送出失敗，請稍後再試。';

  @override
  String get editProfileTitle => '編輯個人資料';

  @override
  String get editProfilePhoneResetWarn => '⚠️ 已修改已驗證的電話，儲存後驗證將被重設。';

  @override
  String get editProfileReverifyHint => '⚠️ 修改此項後需要重新驗證';

  @override
  String get editProfileEditPhoto => '編輯相片';

  @override
  String get editProfileChooseImageSource => '選擇圖片來源';

  @override
  String get editProfileGallery => '相簿';

  @override
  String get editProfileCamera => '相機';

  @override
  String get editProfileVerificationResetTitle => '驗證將被重設';

  @override
  String get editProfileVerificationResetBody =>
      '您正在變更已驗證的電話號碼，這會重設驗證狀態，您需要重新驗證新的號碼。';

  @override
  String get editProfileContinue => '繼續';

  @override
  String get editProfileFullName => '姓名';

  @override
  String get editProfileNameRequired => '姓名為必填';

  @override
  String get editProfileJobTitle => '職稱';

  @override
  String get editProfileCompany => '公司';

  @override
  String get editProfilePhone => '電話';

  @override
  String get editProfileAdditionalInfo => '其他資訊';

  @override
  String get editProfileAddField => '新增欄位';

  @override
  String get editProfileTapToChangePhoto => '點擊以更換相片';

  @override
  String get editProfileBusinessCards => '名片';

  @override
  String get editProfileFrontSide => '正面';

  @override
  String get editProfileBackSide => '背面';

  @override
  String editProfileUpload(String label) {
    return '上傳$label';
  }

  @override
  String get editProfileFieldTypeLabel => '類型';

  @override
  String get editProfileFieldLabelLabel => '標籤';

  @override
  String get editProfileAdd => '新增';

  @override
  String get handshakeTitle => '交換資訊';

  @override
  String handshakeSaveFailed(String error) {
    return '儲存失敗：$error';
  }

  @override
  String get handshakeShareBackTitle => '回傳您的資訊？';

  @override
  String get handshakeShareBackBody => '您要將自己的聯絡資訊回傳給對方嗎？';

  @override
  String get handshakeNo => '否';

  @override
  String get handshakeYes => '是';

  @override
  String handshakeShareFailed(String error) {
    return '分享失敗：$error';
  }

  @override
  String get handshakeInvalidLink => '連結無效或已過期';

  @override
  String handshakeParseError(String error) {
    return '解析資料時發生錯誤：$error';
  }

  @override
  String get handshakeFoundLink => '已找到安全連結';

  @override
  String get handshakeRequestPrompt => '要請求交換資訊嗎？';

  @override
  String get handshakeAbort => '中止';

  @override
  String get handshakeSendRequest => '傳送請求';

  @override
  String get handshakeRequestSent => '請求已送出！';

  @override
  String get handshakeWaitingApproval => '等待對方核准…';

  @override
  String get handshakeRequestDeclined => '請求已被拒絕';

  @override
  String get handshakeSessionExpired => '工作階段已過期';

  @override
  String get handshakeInfoReceived => '已收到資訊！';

  @override
  String get handshakeSelectContext => '選擇要分享的情境';

  @override
  String get handshakeContextBusiness => '商務';

  @override
  String get handshakeContextSocial => '社交';

  @override
  String get handshakeContextLite => '精簡';

  @override
  String get handshakeShare => '分享';

  @override
  String get incomingExpired => '已過期';

  @override
  String get incomingUnknownUser => '未知使用者';

  @override
  String get incomingTitle => '收到請求';

  @override
  String incomingWantsToExchange(String name) {
    return '$name 想與您交換聯絡資訊。';
  }

  @override
  String get incomingAddToContacts => '加入我的聯絡人';

  @override
  String get incomingChooseInfo => '選擇要分享的資訊：';

  @override
  String get incomingDecline => '拒絕';

  @override
  String get incomingApprove => '核准';

  @override
  String get scannerInvalidQr => 'QR code 無效';

  @override
  String get scannerInvalidQrFormat => 'QR code 格式無效。應為：https://ixo.app/<id>';

  @override
  String get scannerTitle => '掃描 QR code';

  @override
  String get scannerPlaceInFrame => '將 QR code 對準框內';

  @override
  String get scannerPermissionTitle => '需要相機權限';

  @override
  String get scannerPermissionBody => '此功能需要相機存取權，以掃描 QR code 進行安全交換。';

  @override
  String get scannerOpenSettings => '開啟設定';

  @override
  String get scannerGrantPermission => '授予權限';

  @override
  String get editContactTitle => '編輯聯絡人';

  @override
  String get editContactUpdated => '聯絡人已更新';

  @override
  String get editContactBasicInfo => '基本資訊';

  @override
  String get editContactDisplayName => '顯示名稱';

  @override
  String get editContactNickname => '暱稱（僅您可見）';

  @override
  String get editContactJobInfo => '工作資訊';

  @override
  String get editContactContact => '聯絡方式';

  @override
  String get editContactEmail => '電子郵件';

  @override
  String get editContactOriginalScan => '原始掃描';

  @override
  String editContactFieldRequired(String label) {
    return '$label 為必填';
  }
}
